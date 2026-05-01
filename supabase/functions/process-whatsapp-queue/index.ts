import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  applySecurityMiddleware,
  RateLimitPresets,
  createErrorResponse,
  createSuccessResponse,
} from "../_shared/security.ts"

serve(async (req) => {
  // Apply security middleware
  const securityCheck = await applySecurityMiddleware(req, {
    rateLimit: RateLimitPresets.MODERATE,
    maxBodySize: 10 * 1024, // 10KB max
  });

  if (!securityCheck.allowed) {
    return securityCheck.response!;
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('🔄 WHATSAPP QUEUE PROCESSOR - EDGE FUNCTION');
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

    const wassoApiKey = Deno.env.get('WASSO_API_KEY');
    if (!wassoApiKey) {
      return createErrorResponse('WASSO_API_KEY not configured', 500);
    }

    const MAX_EXECUTION_TIME = 50000; // 50 seconds
    const BATCH_SIZE = 20; // Process 20 messages per batch
    const DELAY_MS = 1000 + Math.random() * 1000; // 1-2 seconds (reduced for faster processing)
    const startTime = Date.now();

    let processed = 0;
    let successful = 0;
    let failed = 0;
    let hasMore = false;

    while (Date.now() - startTime < MAX_EXECUTION_TIME) {
      // Get next batch from queue
      const { data: batch, error: batchError } = await supabaseClient.rpc(
        'get_next_announcement_batch',
        { p_batch_size: BATCH_SIZE }
      );

      if (batchError) {
        console.error('❌ Error getting batch from queue:', batchError);
        break;
      }

      if (!batch || batch.length === 0) {
        console.log('✅ Queue is empty');
        hasMore = false;
        break;
      }

      console.log(`📦 Processing batch of ${batch.length} messages...`);

      // Process each message in the batch
      for (const item of batch) {
        const elapsed = Date.now() - startTime;
        if (elapsed > MAX_EXECUTION_TIME - 3000) { // Leave 3 second buffer
          console.log('⏰ Time limit reached');
          hasMore = true; // Indicate there might be more
          break;
        }

        processed++;

        // Send message via Wasso
        const cleanPhone = item.phone.replace('+', '');
        const response = await fetch('https://wasso.up.railway.app/api/v1/messages/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': wassoApiKey,
          },
          body: JSON.stringify({
            recipient: cleanPhone,
            message: item.message_content,
          }),
        });

        if (response.ok) {
          const result = await response.json();
          if (result.success || result.status === 'sent' || result.message_id) {
            successful++;
            await supabaseClient.rpc('mark_announcement_sent', {
              p_queue_id: item.id,
              p_wasso_message_id: result.message_id || null
            });
            console.log(`✅ [${processed}] Sent to ${item.phone}`);
          } else {
            failed++;
            await supabaseClient.rpc('mark_announcement_failed', {
              p_queue_id: item.id,
              p_error_message: result.error || 'Unknown error'
            });
          }
        } else {
          failed++;
          const errorText = await response.text();
          await supabaseClient.rpc('mark_announcement_failed', {
            p_queue_id: item.id,
            p_error_message: `Wasso API error: ${response.status} - ${errorText}`
          });
          console.error(`❌ [${processed}] Failed to send to ${item.phone}`);
        }

        // Wait before next message (only if not last in batch and time allows)
        const elapsedAfter = Date.now() - startTime;
        if (processed < batch.length && elapsedAfter < MAX_EXECUTION_TIME - 2000) {
          const actualDelay = DELAY_MS;
          await new Promise(resolve => setTimeout(resolve, actualDelay));
        }
      }

      // Check if there are more pending messages
      if (batch.length === BATCH_SIZE) {
        // If we got a full batch, there might be more
        const { count } = await supabaseClient
          .from('whatsapp_announcement_queue')
          .select('*', { count: 'exact', head: true })
          .eq('status', 'pending');
        
        hasMore = (count || 0) > 0;
        if (!hasMore) {
          break; // No more messages
        }
      } else {
        // Partial batch means we're done
        hasMore = false;
        break;
      }
    }

    console.log(`\n📊 Processed: ${processed}, Successful: ${successful}, Failed: ${failed}\n`);

    return createSuccessResponse({
      message: hasMore ? 'Queue processing paused (more messages available)' : 'Queue processing completed',
      processed,
      successful,
      failed,
      hasMore,
      remaining: hasMore ? 'more available' : 0
    });

  } catch (error: any) {
    console.error('❌ Unexpected error:', error);
    return createErrorResponse(`Internal server error: ${error.message}`, 500);
  }
});

