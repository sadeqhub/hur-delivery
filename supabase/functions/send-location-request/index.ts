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
import { encryptTrackingCode } from "../_shared/encryption.ts"

serve(async (req) => {
  // CORS headers for backward compatibility with existing code
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  // Apply moderate rate limiting for location requests
  const securityCheck = await applySecurityMiddleware(req, {
    rateLimit: RateLimitPresets.MODERATE, // 30 requests per minute
    maxBodySize: 10 * 1024, // 10KB max
  });

  if (!securityCheck.allowed) {
    return securityCheck.response!;
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📱 WHATSAPP LOCATION REQUEST - EDGE FUNCTION (OTPIQ)');
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
    console.log('   Order ID:', requestBody.order_id);
    console.log('   Customer Phone:', requestBody.customer_phone);
    console.log('   Customer Name:', requestBody.customer_name);
    
    const { order_id, customer_phone, customer_name } = requestBody
    
    // Validate required fields
    if (!order_id || !customer_phone) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: order_id and customer_phone are required'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Validation passed');

    // Check if message was already sent for this order (duplicate prevention)
    // IMPORTANT: Only block if message was actually delivered (has delivered_at timestamp)
    const { data: existingRequest, error: checkError } = await supabaseClient
      .from('whatsapp_location_requests')
      .select('status, delivered_at, sent_at, message_sid')
      .eq('order_id', order_id)
      .maybeSingle();

    // Only block if message was actually delivered (has delivered_at timestamp)
    // This ensures we don't block retries for failed or incomplete sends
    if (existingRequest && existingRequest.delivered_at) {
      console.log('⏭️  Message already delivered for this order, skipping duplicate send');
      console.log('   Previous delivery:', existingRequest.delivered_at);
      console.log('   Status:', existingRequest.status);
      console.log('   Message SID:', existingRequest.message_sid || 'N/A');
      return new Response(
        JSON.stringify({ 
          success: true,
          message: 'Message already sent',
          already_sent: true,
          delivered_at: existingRequest.delivered_at
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // If status is 'sent' but no delivered_at, the message wasn't actually sent successfully
    // Only block if it's a very recent attempt (<15 seconds) to prevent rapid duplicates
    // Otherwise, allow retry since the previous attempt clearly didn't complete
    if (existingRequest && existingRequest.status === 'sent' && !existingRequest.delivered_at) {
      const sentAt = existingRequest.sent_at ? new Date(existingRequest.sent_at) : null;
      const now = new Date();
      const fifteenSecondsInMs = 15 * 1000; // 15 seconds - only block very recent attempts
      
      if (sentAt && (now.getTime() - sentAt.getTime()) < fifteenSecondsInMs) {
        // Very recent attempt (<15 seconds), might still be in progress
        const secondsAgo = ((now.getTime() - sentAt.getTime()) / 1000).toFixed(1);
        console.log(`⏭️  Very recent send attempt (${secondsAgo}s ago), might still be processing`);
        console.log('   Previous sent_at:', existingRequest.sent_at);
        console.log('   No delivery confirmation yet - blocking to prevent rapid duplicate');
        return new Response(
          JSON.stringify({ 
            success: true,
            message: 'Message send attempt very recent, waiting for completion',
            already_sent: false,
            in_progress: true
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      } else {
        // Old attempt (>15 seconds) with no delivery confirmation = failed/incomplete
        // Allow retry immediately
        if (sentAt) {
          const timeSince = (now.getTime() - sentAt.getTime()) / 1000;
          console.log('⚠️  Previous send attempt failed or incomplete (no delivered_at), allowing retry');
          console.log('   Previous sent_at:', existingRequest.sent_at);
          console.log('   Time since attempt:', timeSince < 60 ? `${timeSince.toFixed(1)}s` : `${(timeSince / 60).toFixed(1)} minutes`);
          console.log('   → Proceeding with new send attempt');
        } else {
          console.log('⚠️  Previous attempt has no sent_at timestamp, allowing retry');
          console.log('   → Proceeding with new send attempt');
        }
        // Continue with the send attempt - don't return early
      }
    }

    // If status is 'failed', allow retry
    if (existingRequest && existingRequest.status === 'failed') {
      console.log('🔄 Previous attempt failed, allowing retry');
      console.log('   Previous status: failed');
    }
    
    // Log current request state for debugging
    if (existingRequest) {
      console.log('📊 Existing request found:');
      console.log('   Status:', existingRequest.status);
      console.log('   Sent at:', existingRequest.sent_at || 'N/A');
      console.log('   Delivered at:', existingRequest.delivered_at || 'N/A (NOT DELIVERED)');
      console.log('   Message SID:', existingRequest.message_sid || 'N/A');
      if (!existingRequest.delivered_at) {
        console.log('   ⚠️  No delivery confirmation - will allow retry if needed');
      }
    } else {
      console.log('📊 No existing request found, creating new one');
    }

    // Get order details to fetch merchant's store name, user_friendly_code, and driver info
    const { data: orderData, error: orderError } = await supabaseClient
      .from('orders')
      .select(`
        merchant_id,
        user_friendly_code,
        total_amount,
        delivery_fee,
        driver_id,
        merchant:users!orders_merchant_id_fkey(store_name, name),
        driver:users!orders_driver_id_fkey(phone)
      `)
      .eq('id', order_id)
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
    console.log('🏪 Store name:', storeName);

    // Build encrypted tracking code if user_friendly_code exists
    let encryptedTrackingCode: string | null = null;
    if (orderData.user_friendly_code) {
      try {
        encryptedTrackingCode = await encryptTrackingCode(orderData.user_friendly_code);
        console.log('🔐 Secure tracking code generated for location request');
      } catch (encryptError: any) {
        console.error('❌ Failed to encrypt tracking code for location request:', encryptError);
      }
    }

    // Format phone number for WhatsApp (ensure it's in 964XXXXXXXXX format)
    let formattedPhone = customer_phone.trim();
    // Remove + if present
    formattedPhone = formattedPhone.replace('+', '');
    // Add 964 prefix if not present
    if (!formattedPhone.startsWith('964')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '964' + formattedPhone.substring(1);
      } else {
        formattedPhone = '964' + formattedPhone;
      }
    }

    console.log('📞 Formatted phone number:', formattedPhone);

    console.log('📝 Using OTPIQ order_tracking_location template');
    console.log('   Store name used:', storeName);
    console.log('   Encrypted tracking code:', encryptedTrackingCode || 'N/A');

    // Insert or update record to mark as 'sent' (prevents concurrent duplicate sends)
    const { error: upsertError } = await supabaseClient
      .from('whatsapp_location_requests')
      .upsert({
        order_id: order_id,
        customer_phone: customer_phone,
        status: 'sent',
        sent_at: new Date().toISOString()
      }, {
        onConflict: 'order_id',
        ignoreDuplicates: false
      });

    if (upsertError) {
      console.error('❌ Failed to create/update request record:', upsertError);
      // Continue anyway - don't block sending
    } else {
      console.log('✅ Request record created/updated');
    }

    console.log('\n🔄═══════════════════════════════════════════════════════');
    console.log('🔄 ATTEMPTING TO SEND VIA OTPIQ');
    console.log('🔄═══════════════════════════════════════════════════════');
    console.log('   Order ID:', order_id);
    console.log('   Customer Phone:', customer_phone);
    console.log('   Formatted Phone:', formattedPhone);
    console.log('═══════════════════════════════════════════════════════\n');

    let wassoResult;
    try {
      wassoResult = await sendOtpiqMessage(formattedPhone, storeName, encryptedTrackingCode);
      console.log('\n📊 OTPIQ API call completed');
      console.log('📊 Result success:', wassoResult.success);
      console.log('📊 Result:', JSON.stringify(wassoResult));
      console.log('═══════════════════════════════════════════════════════\n');
    } catch (error: any) {
      console.error('\n❌═══════════════════════════════════════════════════════');
      console.error('❌ EXCEPTION CAUGHT WHILE CALLING sendOtpiqMessage');
      console.error('❌═══════════════════════════════════════════════════════');
      console.error('   Error message:', error.message);
      console.error('   Error type:', error.constructor.name);
      console.error('   Error stack:', error.stack);
      console.error('═══════════════════════════════════════════════════════\n');
      wassoResult = {
        success: false,
        error: `Exception: ${error.message}`
      };
    }
    
    if (wassoResult.success) {
      // Update the database record
      const { error: updateError } = await supabaseClient
        .from('whatsapp_location_requests')
        .update({
          status: 'delivered',
          delivered_at: new Date().toISOString(),
          message_sid: wassoResult.message_id || null
        })
        .eq('order_id', order_id);

      if (updateError) {
        console.error('❌ Failed to update database:', updateError);
      } else {
        console.log('✅ Database updated successfully');
      }

      console.log('\n✅ WhatsApp message sent successfully via OTPIQ!');
      console.log('═══════════════════════════════════════════════════════\n');

      return new Response(
        JSON.stringify({ 
          success: true,
          sent_to: formattedPhone,
          message_id: wassoResult.message_id,
          delivered_at: new Date().toISOString()
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } else {
      console.error('\n❌═══════════════════════════════════════════════════════');
      console.error('❌ WHATSAPP MESSAGE FAILED');
      console.error('❌═══════════════════════════════════════════════════════');
      console.error('   Order ID:', order_id);
      console.error('   Customer Phone:', customer_phone);
      console.error('   Formatted Phone:', formattedPhone);
      console.error('   Error:', wassoResult.error);
      console.error('═══════════════════════════════════════════════════════\n');
      
      // Update database with failure status
      let requestData = null;
      try {
        const { data, error: fetchError } = await supabaseClient
          .from('whatsapp_location_requests')
          .select('last_error_email_sent_at')
          .eq('order_id', order_id)
          .single();
        
        if (fetchError) {
          console.error('❌ Failed to fetch request data:', fetchError);
        } else {
          requestData = data;
          console.log('📊 Last error email sent at:', requestData?.last_error_email_sent_at || 'Never');
        }
      } catch (error: any) {
        console.error('❌ Exception fetching request data:', error.message);
      }

      try {
        await supabaseClient
          .from('whatsapp_location_requests')
          .update({ status: 'failed' })
          .eq('order_id', order_id);
        console.log('✅ Updated request status to "failed"');
      } catch (error: any) {
        console.error('❌ Failed to update request status:', error.message);
      }

      // Send error email to admin if 6 hours have passed since last email
      try {
        const shouldSendEmail = await shouldSendErrorEmail(requestData?.last_error_email_sent_at);
        console.log('📧 Should send error email?', shouldSendEmail);
        
        if (shouldSendEmail) {
          console.log('📧 Sending error notification email to admin...');
          await sendErrorEmailToAdmin({
            orderId: order_id,
            customerPhone: customer_phone,
            customerName: customer_name || 'Unknown',
            storeName: storeName,
            error: wassoResult.error || 'Unknown error',
            formattedPhone: formattedPhone
          });

          // Update the last_error_email_sent_at timestamp
          try {
            await supabaseClient
              .from('whatsapp_location_requests')
              .update({ last_error_email_sent_at: new Date().toISOString() })
              .eq('order_id', order_id);
            console.log('✅ Updated last_error_email_sent_at timestamp');
          } catch (error: any) {
            console.error('❌ Failed to update error email timestamp:', error.message);
          }
        } else {
          const lastSent = requestData?.last_error_email_sent_at 
            ? new Date(requestData.last_error_email_sent_at)
            : null;
          const hoursSince = lastSent 
            ? ((new Date().getTime() - lastSent.getTime()) / (1000 * 60 * 60)).toFixed(2)
            : 'N/A';
          console.log(`⏭️  Skipping error email (rate limited - last sent ${hoursSince} hours ago)`);
        }
      } catch (error: any) {
        console.error('❌ Exception in error email handling:', error.message);
        console.error('   Stack:', error.stack);
      }

      return new Response(
        JSON.stringify({ 
          error: 'WhatsApp message failed',
          details: wassoResult.error
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

  } catch (error: any) {
    console.error('\n❌ EDGE FUNCTION ERROR:', error.message);
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
          <p><strong>تفاصيل الخطأ:</strong></p>
          <p style="background-color: #ffebee; padding: 15px; border-radius: 4px; border-left: 4px solid #d32f2f; color: #c62828; font-family: monospace; white-space: pre-wrap;">${params.error}</p>
        </div>

        <div style="margin: 30px 0; padding-top: 20px; border-top: 1px solid #e0e0e0;">
          <p style="color: #666; font-size: 12px;">
            تم إرسال هذا البريد الإلكتروني تلقائياً عند فشل إرسال رسالة WhatsApp إلى العميل.<br>
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

// ═══════════════════════════════════════════════════════════════════════════════
// SEND WHATSAPP TEMPLATE VIA OTPIQ API
// ═══════════════════════════════════════════════════════════════════════════════
async function sendOtpiqMessage(
  phoneNumber: string,
  storeName: string,
  trackingUrl: string | null,
): Promise<{ success: boolean; message_id?: string | null; error?: string }> {
  const apiKey = Deno.env.get('OTPIQ_API_KEY');
  const whatsappAccountId = Deno.env.get('OTPIQ_WHATSAPP_ACCOUNT_ID');
  const whatsappPhoneId = Deno.env.get('OTPIQ_WHATSAPP_PHONE_ID');

  if (!apiKey || !whatsappAccountId || !whatsappPhoneId) {
    console.error('❌ Missing OTPIQ env vars (OTPIQ_API_KEY, OTPIQ_WHATSAPP_ACCOUNT_ID, OTPIQ_WHATSAPP_PHONE_ID)');
    return { success: false, error: 'OTPIQ credentials not configured' };
  }

  console.log('📱 Sending WhatsApp template via OTPIQ...');
  console.log('   To:', phoneNumber);
  console.log('   Store name:', storeName);
  console.log('   Tracking URL:', trackingUrl || 'N/A');

  try {
    const body: Record<string, unknown> = {
      phoneNumber,
      smsType: 'whatsapp-template',
      provider: 'whatsapp',
      templateName: 'order_tracking_location',
      whatsappAccountId,
      whatsappPhoneId,
      templateParameters: {
        body: { '1': storeName },
        ...(trackingUrl ? { buttons: { '0': { '1': trackingUrl } } } : {}),
      },
    };

    const response = await fetch('https://api.otpiq.com/api/sms', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    console.log('📨 OTPIQ response status:', response.status);

    const responseText = await response.text();
    console.log('📨 OTPIQ raw response:', responseText);

    if (!response.ok) {
      return { success: false, error: `OTPIQ error: ${response.status} - ${responseText}` };
    }

    let result: any = {};
    try {
      result = JSON.parse(responseText);
    } catch (_) {
      // non-JSON success response is still OK if status was 2xx
    }

    const messageId = result.id || result.message_id || result.messageId || null;
    return { success: true, message_id: messageId };
  } catch (fetchError: any) {
    console.error('❌ OTPIQ fetch error:', fetchError.message);
    return { success: false, error: `Network error: ${fetchError.message}` };
  }
}

