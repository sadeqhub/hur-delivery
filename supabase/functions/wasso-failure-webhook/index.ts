import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  applySecurityMiddleware,
  RateLimitPresets,
  createErrorResponse,
  createSuccessResponse,
  parseJsonSafely,
  validateUuid,
  validateAndNormalizePhone,
  ValidationError,
  logSecurityEvent,
} from "../_shared/security.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key, x-wasso-signature',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Apply moderate rate limiting
  const securityCheck = await applySecurityMiddleware(req, {
    rateLimit: RateLimitPresets.MODERATE, // 30 requests per minute
    maxBodySize: 50 * 1024, // 50KB max
  });

  if (!securityCheck.allowed) {
    return securityCheck.response!;
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('❌ WASSO FAILURE WEBHOOK - EDGE FUNCTION');
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
    console.log('📥 Failure webhook received:');
    console.log('   Payload:', JSON.stringify(requestBody, null, 2));
    
    // Wasso failure webhook structure (adjust based on actual webhook format)
    // Expected format might be:
    // {
    //   "type": "message_failed" | "error" | "failed",
    //   "message_id": "msg_123",
    //   "recipient": "9647812345678",
    //   "error": "Error message",
    //   "reason": "Failed reason",
    //   "timestamp": "2025-01-12T12:00:00Z",
    //   "order_id": "uuid" (if we include it in the original message)
    // }
    
    const { 
      type, 
      message_id, 
      recipient, 
      error, 
      reason, 
      timestamp,
      order_id,
      status,
      message
    } = requestBody;
    
    // Check if this is a failure notification
    const isFailure = type === 'message_failed' || 
                     type === 'error' || 
                     type === 'failed' ||
                     status === 'failed' ||
                     status === 'error' ||
                     error ||
                     reason;

    if (!isFailure) {
      console.log('⚠️ Not a failure notification, ignoring');
      return new Response(
        JSON.stringify({ 
          success: true,
          message: 'Not a failure notification, ignored'
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Extract error message
    const errorMessage = error || reason || message || 'Unknown error';
    const phoneNumber = recipient;
    
    console.log('📊 Failure details:');
    console.log('   Type:', type);
    console.log('   Message ID:', message_id);
    console.log('   Recipient:', phoneNumber);
    console.log('   Error:', errorMessage);
    console.log('   Order ID (from payload):', order_id || 'Not provided');

    // If order_id is in the payload, use it directly
    // Otherwise, try to find it by phone number and message_id
    let orderId = order_id;
    
    if (!orderId && phoneNumber) {
      console.log('🔍 Searching for order by phone number and message_id...');
      
      // Format phone number for search
      let formattedPhone = phoneNumber.trim();
      formattedPhone = formattedPhone.replace('+', '');
      if (!formattedPhone.startsWith('964')) {
        if (formattedPhone.startsWith('0')) {
          formattedPhone = '964' + formattedPhone.substring(1);
        } else {
          formattedPhone = '964' + formattedPhone;
        }
      }
      
      // Also try with + prefix
      const phoneWithPlus = '+' + formattedPhone;
      
      // Search for the order by phone number and message_sid
      const { data: requestData, error: searchError } = await supabaseClient
        .from('whatsapp_location_requests')
        .select('order_id, customer_phone, order:orders(user_friendly_code, merchant:users!orders_merchant_id_fkey(store_name, name))')
        .or(`customer_phone.eq.${formattedPhone},customer_phone.eq.${phoneWithPlus}`)
        .eq('message_sid', message_id || '')
        .order('sent_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      
      if (requestData && requestData.order_id) {
        orderId = requestData.order_id;
        console.log('✅ Found order by phone and message_id:', orderId);
      } else {
        // Try without message_id match (in case message_sid wasn't saved)
        const { data: recentRequest } = await supabaseClient
          .from('whatsapp_location_requests')
          .select('order_id, customer_phone, order:orders(user_friendly_code, merchant:users!orders_merchant_id_fkey(store_name, name))')
          .or(`customer_phone.eq.${formattedPhone},customer_phone.eq.${phoneWithPlus}`)
          .order('sent_at', { ascending: false })
          .limit(1)
          .maybeSingle();
        
        if (recentRequest && recentRequest.order_id) {
          orderId = recentRequest.order_id;
          console.log('✅ Found order by phone (most recent):', orderId);
        } else {
          console.error('❌ Could not find order for phone:', formattedPhone);
        }
      }
    }

    if (!orderId) {
      console.error('❌ No order ID found, cannot send error email');
      return new Response(
        JSON.stringify({ 
          error: 'Order ID not found',
          message: 'Could not determine which order this failure is for'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('📦 Processing failure for order:', orderId);

    // Get order details
    const { data: orderData, error: orderError } = await supabaseClient
      .from('orders')
      .select(`
        id,
        customer_phone,
        customer_name,
        user_friendly_code,
        merchant:users!orders_merchant_id_fkey(store_name, name)
      `)
      .eq('id', orderId)
      .single();

    if (orderError || !orderData) {
      console.error('❌ Failed to fetch order:', orderError);
      return new Response(
        JSON.stringify({ 
          error: 'Order not found',
          details: orderError?.message
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Use store_name if available, fallback to merchant name, then generic
    const storeName = orderData.merchant?.store_name || orderData.merchant?.name || 'متجرنا';
    const customerName = orderData.customer_name || 'Unknown';
    const customerPhone = orderData.customer_phone || phoneNumber || 'Unknown';

    // Format phone for display
    let formattedPhone = customerPhone.trim();
    formattedPhone = formattedPhone.replace('+', '');
    if (!formattedPhone.startsWith('964')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '964' + formattedPhone.substring(1);
      } else {
        formattedPhone = '964' + formattedPhone;
      }
    }

    // Update database with failure status
    await supabaseClient
      .from('whatsapp_location_requests')
      .update({ status: 'failed' })
      .eq('order_id', orderId);

    console.log('✅ Updated request status to "failed"');

    // Check if error email should be sent (rate limit: 6 hours)
    const { data: requestData } = await supabaseClient
      .from('whatsapp_location_requests')
      .select('last_error_email_sent_at')
      .eq('order_id', orderId)
      .single();

    const shouldSendEmail = await shouldSendErrorEmail(requestData?.last_error_email_sent_at);
    
    if (shouldSendEmail) {
      console.log('📧 Sending error notification email to admin...');
      await sendErrorEmailToAdmin({
        orderId: orderId,
        customerPhone: customerPhone,
        customerName: customerName,
        storeName: storeName,
        error: errorMessage,
        formattedPhone: formattedPhone,
        messageId: message_id || 'N/A',
        webhookTimestamp: timestamp || new Date().toISOString()
      });

      // Update the last_error_email_sent_at timestamp
      await supabaseClient
        .from('whatsapp_location_requests')
        .update({ last_error_email_sent_at: new Date().toISOString() })
        .eq('order_id', orderId);
      
      console.log('✅ Error email sent and timestamp updated');
    } else {
      const lastSent = requestData?.last_error_email_sent_at 
        ? new Date(requestData.last_error_email_sent_at)
        : null;
      const hoursSince = lastSent 
        ? ((new Date().getTime() - lastSent.getTime()) / (1000 * 60 * 60)).toFixed(2)
        : 'N/A';
      console.log(`⏭️  Skipping error email (rate limited - last sent ${hoursSince} hours ago)`);
    }

    console.log('\n✅ Failure webhook processed successfully');
    console.log('═══════════════════════════════════════════════════════\n');

    return new Response(
      JSON.stringify({ 
        success: true,
        message: 'Failure webhook processed',
        order_id: orderId,
        email_sent: shouldSendEmail
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('\n❌ WEBHOOK ERROR:', error.message);
    console.error('Stack:', error.stack);
    console.error('═══════════════════════════════════════════════════════\n');
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// CHECK IF ERROR EMAIL SHOULD BE SENT (RATE LIMIT: 6 HOURS)
// ═══════════════════════════════════════════════════════════════════════════════
async function shouldSendErrorEmail(lastErrorEmailSentAt: string | null | undefined): Promise<boolean> {
  if (!lastErrorEmailSentAt) {
    return true; // Never sent before, send it
  }

  const lastSent = new Date(lastErrorEmailSentAt);
  const now = new Date();
  const sixHoursInMs = 6 * 60 * 60 * 1000; // 6 hours in milliseconds
  const timeSinceLastEmail = now.getTime() - lastSent.getTime();

  return timeSinceLastEmail >= sixHoursInMs;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEND ERROR EMAIL TO ADMIN VIA RESEND API
// ═══════════════════════════════════════════════════════════════════════════════
async function sendErrorEmailToAdmin(params: {
  orderId: string;
  customerPhone: string;
  customerName: string;
  storeName: string;
  error: string;
  formattedPhone: string;
  messageId: string;
  webhookTimestamp: string;
}) {
  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  const adminEmail = Deno.env.get('ADMIN_EMAIL');
  const fromEmail = Deno.env.get('RESEND_FROM_EMAIL');

  if (!resendApiKey || !adminEmail || !fromEmail) {
    console.error('❌ Resend email configuration missing');
    console.error('   RESEND_API_KEY:', resendApiKey ? '✓' : '✗');
    console.error('   ADMIN_EMAIL:', adminEmail ? '✓' : '✗');
    console.error('   RESEND_FROM_EMAIL:', fromEmail ? '✓' : '✗');
    return;
  }

  const emailSubject = `⚠️ فشل إرسال رسالة WhatsApp - طلب ${params.orderId}`;
  const emailBody = `
    <div dir="rtl" style="font-family: Arial, sans-serif; padding: 20px; background-color: #f5f5f5;">
      <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h2 style="color: #d32f2f; margin-top: 0;">⚠️ فشل إرسال رسالة WhatsApp</h2>
        
        <div style="margin: 20px 0;">
          <p><strong>معرف الطلب:</strong></p>
          <p style="background-color: #f5f5f5; padding: 10px; border-radius: 4px; font-family: monospace;">${params.orderId}</p>
        </div>

        <div style="margin: 20px 0;">
          <p><strong>اسم المتجر:</strong></p>
          <p>${params.storeName}</p>
        </div>

        <div style="margin: 20px 0;">
          <p><strong>اسم العميل:</strong></p>
          <p>${params.customerName}</p>
        </div>

        <div style="margin: 20px 0;">
          <p><strong>رقم هاتف العميل:</strong></p>
          <p style="background-color: #f5f5f5; padding: 10px; border-radius: 4px; font-family: monospace;">${params.customerPhone}</p>
          <p style="color: #666; font-size: 12px;">(مُنسق للإرسال: ${params.formattedPhone})</p>
        </div>

        <div style="margin: 20px 0;">
          <p><strong>معرف الرسالة:</strong></p>
          <p style="background-color: #f5f5f5; padding: 10px; border-radius: 4px; font-family: monospace; font-size: 12px;">${params.messageId}</p>
        </div>

        <div style="margin: 20px 0;">
          <p><strong>وقت الإشعار:</strong></p>
          <p style="color: #666; font-size: 12px;">${new Date(params.webhookTimestamp).toLocaleString('ar-IQ')}</p>
        </div>

        <div style="margin: 20px 0;">
          <p><strong>تفاصيل الخطأ:</strong></p>
          <p style="background-color: #ffebee; padding: 15px; border-radius: 4px; border-left: 4px solid #d32f2f; color: #c62828; font-family: monospace; white-space: pre-wrap;">${params.error}</p>
        </div>

        <div style="margin: 30px 0; padding-top: 20px; border-top: 1px solid #e0e0e0;">
          <p style="color: #666; font-size: 12px;">
            تم إرسال هذا البريد الإلكتروني تلقائياً من Webhook عند فشل إرسال رسالة WhatsApp إلى العميل.<br>
            سيتم إرسال إشعارات الخطأ مرة واحدة كل 6 ساعات لتجنب الإزعاج.
          </p>
        </div>
      </div>
    </div>
  `;

  try {
    console.log('📧 Preparing to send error email via Resend...');
    console.log('   From:', fromEmail);
    console.log('   To:', adminEmail);
    console.log('   Subject:', emailSubject);
    
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: fromEmail,
        to: adminEmail,
        subject: emailSubject,
        html: emailBody,
      }),
    });

    console.log('📧 Resend API response status:', response.status);
    console.log('📧 Resend API response headers:', Object.fromEntries(response.headers.entries()));

    if (!response.ok) {
      let errorText = '';
      try {
        errorText = await response.text();
        console.error('❌ Resend API error response:', errorText);
      } catch (textError: any) {
        console.error('❌ Failed to read Resend error response:', textError.message);
        errorText = `HTTP ${response.status} ${response.statusText}`;
      }
      console.error('❌ Resend API error:', response.status, errorText);
      return;
    }

    let result;
    try {
      const responseText = await response.text();
      console.log('📧 Resend API raw response:', responseText);
      
      if (!responseText || responseText.trim() === '') {
        console.error('❌ Resend API returned empty response');
        return;
      }
      
      result = JSON.parse(responseText);
      console.log('✅ Error email sent successfully via Resend');
      console.log('   Email ID:', result.id);
      console.log('   Full response:', JSON.stringify(result));
    } catch (parseError: any) {
      console.error('❌ Failed to parse Resend API response:', parseError.message);
      return;
    }
  } catch (error: any) {
    console.error('❌ Exception caught while sending error email:', error.message);
    console.error('   Error type:', error.constructor.name);
    console.error('   Error stack:', error.stack);
  }
}
















