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
  // CORS headers for backward compatibility
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  // Apply moderate rate limiting
  const securityCheck = await applySecurityMiddleware(req, {
    rateLimit: RateLimitPresets.MODERATE, // 30 requests per minute
    maxBodySize: 50 * 1024, // 50KB max (for message content)
  });

  if (!securityCheck.allowed) {
    return securityCheck.response!;
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📱 WASSO SUPPORT REQUEST NOTIFICATION - EDGE FUNCTION');
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
    const requestBody = await req.json()
    console.log('📥 Request received:');
    console.log('   Conversation ID:', requestBody.conversation_id);
    console.log('   Message ID:', requestBody.message_id);
    console.log('   Sender ID:', requestBody.sender_id);
    
    const { conversation_id, message_id, sender_id, message_body, sender_name, sender_role } = requestBody
    
    // Validate required fields
    if (!conversation_id || !message_id || !sender_id) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: conversation_id, message_id, and sender_id are required'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get admin phone number from environment
    const adminPhone = Deno.env.get('ADMIN_PHONE');
    if (!adminPhone) {
      console.error('❌ ADMIN_PHONE environment variable not set');
      return new Response(
        JSON.stringify({ error: 'ADMIN_PHONE not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Validation passed');
    console.log('📞 Admin phone:', adminPhone);

    // Get sender information if not provided
    let senderInfo = {
      name: sender_name || 'مستخدم',
      role: sender_role || 'user',
      phone: null as string | null
    };

    if (sender_id) {
      const { data: userData, error: userError } = await supabaseClient
        .from('users')
        .select('name, role, phone')
        .eq('id', sender_id)
        .maybeSingle();

      if (!userError && userData) {
        senderInfo.name = userData.name || senderInfo.name;
        senderInfo.role = userData.role || senderInfo.role;
        senderInfo.phone = userData.phone || null;
      }
    }

    // Get conversation information
    const { data: conversationData, error: convError } = await supabaseClient
      .from('conversations')
      .select('id, is_support, order_id')
      .eq('id', conversation_id)
      .maybeSingle();

    if (convError || !conversationData) {
      console.error('❌ Failed to fetch conversation:', convError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch conversation' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Build message content
    let messageContent = '🔔 طلب دعم جديد / New Support Request\n\n';
    messageContent += `👤 المرسل / Sender: ${senderInfo.name}\n`;
    messageContent += `📱 الهاتف / Phone: ${senderInfo.phone || 'غير متوفر / N/A'}\n`;
    messageContent += `🏷️ النوع / Type: ${senderInfo.role === 'merchant' ? 'تاجر / Merchant' : senderInfo.role === 'driver' ? 'سائق / Driver' : 'مستخدم / User'}\n\n`;

    if (message_body) {
      const preview = message_body.length > 200 
        ? message_body.substring(0, 200) + '...' 
        : message_body;
      messageContent += `📝 الرسالة / Message:\n${preview}\n\n`;
    }

    if (conversationData.order_id) {
      messageContent += `🛒 رقم الطلب / Order ID: ${conversationData.order_id.substring(0, 8)}...\n`;
    }

    messageContent += `\n🔗 معرف المحادثة / Conversation ID: ${conversation_id.substring(0, 8)}...`;

    console.log('📨 Sending WhatsApp message to admin...');
    console.log('   Message preview:', messageContent.substring(0, 100) + '...');

    // Send WhatsApp message via Wasso API
    const wassoResult = await sendWassoMessage(adminPhone, messageContent);

    if (!wassoResult.success) {
      console.error('❌ Failed to send WhatsApp message:', wassoResult.error);
      return new Response(
        JSON.stringify({ 
          success: false,
          error: wassoResult.error 
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ WhatsApp message sent successfully');
    console.log('   Message ID:', wassoResult.message_id);

    // Log security event
    await logSecurityEvent(supabaseClient, {
      event_type: 'support_notification_sent',
      user_id: sender_id,
      metadata: {
        conversation_id,
        message_id,
        admin_phone: adminPhone,
        wasso_message_id: wassoResult.message_id
      }
    });

    return new Response(
      JSON.stringify({
        success: true,
        message_id: wassoResult.message_id,
        admin_phone: adminPhone
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ Unexpected error:', error);
    console.error('   Error stack:', error.stack);
    return createErrorResponse(
      'Internal server error',
      500,
      corsHeaders,
      { details: error.message }
    );
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















