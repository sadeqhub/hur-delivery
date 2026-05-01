import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  applySecurityMiddleware,
  RateLimitPresets,
  createErrorResponse,
  createSuccessResponse,
  parseJsonSafely,
  validateUuid,
  logSecurityEvent,
} from "../_shared/security.ts"

serve(async (req) => {
  // Apply security middleware
  const securityCheck = await applySecurityMiddleware(req, {
    rateLimit: RateLimitPresets.MODERATE,
    maxBodySize: 100 * 1024, // 100KB max
  });

  if (!securityCheck.allowed) {
    return securityCheck.response!;
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📢 MASS WHATSAPP ANNOUNCEMENT - EDGE FUNCTION');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Initialize Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Parse request body
    const requestBody = await parseJsonSafely(req);
    if (!requestBody) {
      return createErrorResponse('Invalid JSON body', 400);
    }

    const { message, targetRoles, userIds, delayBetweenMessages } = requestBody;

    // Validate required fields
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return createErrorResponse('Message is required and must be a non-empty string', 400);
    }

    if (!targetRoles && !userIds) {
      return createErrorResponse('Either targetRoles or userIds must be provided', 400);
    }

    // Validate targetRoles if provided
    if (targetRoles && (!Array.isArray(targetRoles) || targetRoles.length === 0)) {
      return createErrorResponse('targetRoles must be a non-empty array', 400);
    }

    // Validate userIds if provided
    if (userIds && (!Array.isArray(userIds) || userIds.length === 0)) {
      return createErrorResponse('userIds must be a non-empty array', 400);
    }

    // Set default delay (2-5 seconds between messages to avoid rate limiting)
    const delayMs = delayBetweenMessages || (2000 + Math.random() * 3000); // 2-5 seconds random delay

    console.log('📥 Request received:');
    console.log('   Message length:', message.length);
    console.log('   Target roles:', targetRoles || 'none');
    console.log('   User IDs:', userIds ? userIds.length : 'none');
    console.log('   Delay between messages:', delayMs, 'ms');

    // Fetch users based on criteria
    let usersQuery = supabaseClient
      .from('users')
      .select('id, phone, name, role')
      .not('phone', 'is', null)
      .neq('phone', '');

    if (userIds && userIds.length > 0) {
      // Filter by specific user IDs
      usersQuery = usersQuery.in('id', userIds);
    } else if (targetRoles && targetRoles.length > 0) {
      // Filter by roles
      usersQuery = usersQuery.in('role', targetRoles);
    }

    const { data: users, error: usersError } = await usersQuery;

    if (usersError) {
      console.error('❌ Error fetching users:', usersError);
      return createErrorResponse(`Failed to fetch users: ${usersError.message}`, 500);
    }

    if (!users || users.length === 0) {
      return createErrorResponse('No users found matching the criteria', 404);
    }

    console.log(`✅ Found ${users.length} users to send messages to`);

    // Generate message hash for duplicate detection
    const messageHash = await hashMessage(message);
    console.log(`🔑 Message hash: ${messageHash.substring(0, 16)}...`);

    // Batch check for recent notifications upfront (more efficient than checking one by one)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const fetchedUserIds = users.map(u => u.id);
    
    console.log(`🔍 Checking for recent notifications for ${fetchedUserIds.length} users...`);
    const { data: recentNotifications, error: checkError } = await supabaseClient
      .from('whatsapp_announcements')
      .select('user_id')
      .in('user_id', fetchedUserIds)
      .eq('message_hash', messageHash)
      .gt('sent_at', oneHourAgo);

    if (checkError) {
      console.error(`⚠️ Error checking recent notifications:`, checkError);
      // Continue anyway - don't block on check errors
    }

    // Create a Set of user IDs who were recently notified for fast lookup
    const recentlyNotifiedUserIds = new Set(
      (recentNotifications || []).map((n: any) => n.user_id)
    );
    console.log(`⏭️ Found ${recentlyNotifiedUserIds.size} users who were recently notified`);

    // Filter out users who were recently notified
    const usersToNotify = users.filter(user => !recentlyNotifiedUserIds.has(user.id));
    const skippedCount = users.length - usersToNotify.length;

    console.log(`📊 Filtered users: ${usersToNotify.length} to notify, ${skippedCount} skipped`);

    // Check if we should use queue mode (for large batches) or direct mode
    const useQueue = usersToNotify.length > 20; // Use queue for more than 20 users
    
    if (useQueue) {
      // Queue-based approach: Add all messages to queue and return immediately
      console.log('📦 Using queue-based processing for large batch...');
      
      // Prepare queue entries
      const queueEntries = usersToNotify
        .filter(user => user.phone && user.phone.trim().length > 0)
        .map(user => ({
          user_id: user.id,
          phone: user.phone,
          message_hash: messageHash,
          message_content: message,
          status: 'pending' as const,
        }));

      // Insert into queue
      const { data: queueData, error: queueError } = await supabaseClient
        .from('whatsapp_announcement_queue')
        .insert(queueEntries)
        .select('id');

      if (queueError) {
        console.error('❌ Error adding messages to queue:', queueError);
        return createErrorResponse(`Failed to queue messages: ${queueError.message}`, 500);
      }

      console.log(`✅ Queued ${queueEntries.length} messages for processing`);

      // Trigger queue processor asynchronously (don't wait)
      // The frontend will also call the processor to ensure it runs
      const supabaseUrl = Deno.env.get('SUPABASE_URL');
      const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
      if (supabaseUrl && serviceKey) {
        const queueUrl = `${supabaseUrl}/functions/v1/process-whatsapp-queue`;
        fetch(queueUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${serviceKey}`,
            'apikey': Deno.env.get('SUPABASE_ANON_KEY') || serviceKey,
          },
          body: JSON.stringify({}),
        }).catch(err => {
          console.error('⚠️ Error triggering queue processor:', err);
          // Don't fail - frontend will also trigger it
        });
      }

      return createSuccessResponse({
        message: 'Messages queued for processing',
        results: {
          total: users.length,
          queued: queueEntries.length,
          skipped: skippedCount,
          successful: 0,
          failed: 0,
          processed: 0,
          errors: [],
        },
        isComplete: false,
        queued: true,
        queueCount: queueEntries.length
      });
    } else {
      // Direct processing for small batches (≤20 users)
      console.log('📤 Processing directly (small batch)...');
      
      const MAX_EXECUTION_TIME = 50000; // 50 seconds max
      const startTime = Date.now();

      const results = {
        total: users.length,
        successful: 0,
        failed: 0,
        processed: 0,
        skipped: skippedCount,
        errors: [] as Array<{ userId: string; phone: string; error: string }>,
      };

      // Process messages with timeout protection
      for (let i = 0; i < usersToNotify.length; i++) {
        const elapsed = Date.now() - startTime;
        if (elapsed > MAX_EXECUTION_TIME) {
          console.log(`⏰ Approaching timeout (${elapsed}ms elapsed). Processed ${i}/${usersToNotify.length} messages.`);
          break;
        }

        const user = usersToNotify[i];
        results.processed++;
        
        if (!user.phone || user.phone.trim().length === 0) {
          results.failed++;
          results.errors.push({
            userId: user.id,
            phone: user.phone || 'N/A',
            error: 'Invalid phone number'
          });
          continue;
        }

        const sendResult = await sendWassoMessage(user.phone, message);

        if (sendResult.success) {
          results.successful++;
          console.log(`✅ [${i + 1}/${usersToNotify.length}] Sent to ${user.name || user.phone}`);
          
          // Record the announcement
          await supabaseClient
            .from('whatsapp_announcements')
            .insert({
              user_id: user.id,
              phone: user.phone,
              message_hash: messageHash,
              message_content: message,
              wasso_message_id: sendResult.message_id || null,
            });
        } else {
          results.failed++;
          results.errors.push({
            userId: user.id,
            phone: user.phone,
            error: sendResult.error || 'Unknown error'
          });
        }

        // Wait before next message
        if (i < usersToNotify.length - 1) {
          const actualDelay = delayMs + (Math.random() * 1000);
          await new Promise(resolve => setTimeout(resolve, actualDelay));
        }
      }

      const isComplete = results.processed >= usersToNotify.length;
      
      return createSuccessResponse({
        message: isComplete ? 'Mass announcement completed' : 'Mass announcement partially completed',
        results: results,
        isComplete: isComplete,
        remainingCount: usersToNotify.length - results.processed
      });
    }

  } catch (error: any) {
    console.error('❌ Unexpected error:', error);
    logSecurityEvent('mass_whatsapp_announcement_error', { error: error.message });
    return createErrorResponse(`Internal server error: ${error.message}`, 500);
  }
});

// ═══════════════════════════════════════════════════════════════
// SEND WHATSAPP MESSAGE VIA WASSO API
// ═══════════════════════════════════════════════════════════════
async function sendWassoMessage(phoneNumber: string, message: string) {
  const wassoApiKey = Deno.env.get('WASSO_API_KEY');
  const wassoApiUrl = 'https://wasso.up.railway.app/api/v1/messages/send';
  
  if (!wassoApiKey) {
    console.error('❌ WASSO_API_KEY not configured');
    return {
      success: false,
      error: 'WASSO_API_KEY environment variable not set'
    };
  }

  console.log('📱 Sending WhatsApp message via Wasso API...');
  console.log('   API URL:', wassoApiUrl);
  console.log('   To:', phoneNumber);
  console.log('   Message length:', message.length);

  // Ensure phone number is in correct format (without +)
  const cleanPhone = phoneNumber.replace('+', '');

  try {
    const response = await fetch(wassoApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': wassoApiKey,
      },
      body: JSON.stringify({
        recipient: cleanPhone,
        message: message,
      }),
    });

    console.log('📨 Wasso API response status:', response.status);

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ Wasso API error:', errorText);
      return {
        success: false,
        error: `Wasso API error: ${response.status} - ${errorText}`
      };
    }

    const result = await response.json();
    console.log('✅ Wasso response:', JSON.stringify(result));
    
    if (result.success || result.status === 'sent' || result.message_id) {
      return {
        success: true,
        message_id: result.message_id || result.id || null
      };
    } else {
      return {
        success: false,
        error: result.error || result.message || 'Unknown error'
      };
    }
  } catch (fetchError: any) {
    console.error('❌ Fetch error:', fetchError.message);
    return {
      success: false,
      error: `Network error: ${fetchError.message}`
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// HASH MESSAGE FOR DUPLICATE DETECTION
// ═══════════════════════════════════════════════════════════════
async function hashMessage(message: string): Promise<string> {
  // Use Web Crypto API to create SHA-256 hash
  const encoder = new TextEncoder();
  const data = encoder.encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return hashHex;
}

