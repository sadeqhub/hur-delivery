import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  applySecurityMiddleware,
  RateLimitPresets,
} from "../_shared/security.ts"
import { encryptTrackingCode } from "../_shared/encryption.ts"

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  // Apply moderate rate limiting
  const securityCheck = await applySecurityMiddleware(req, {
    rateLimit: RateLimitPresets.MODERATE,
    maxBodySize: 10 * 1024,
  });

  if (!securityCheck.allowed) {
    return securityCheck.response!;
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📱 WASSO SEND TRACKING LINK - EDGE FUNCTION');
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
    
    const { order_id } = requestBody
    
    // Validate required fields
    if (!order_id) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: order_id is required'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Validation passed');

    // Get order details including customer info, driver info, and user_friendly_code
    const { data: orderData, error: orderError } = await supabaseClient
      .from('orders')
      .select(`
        id,
        user_friendly_code,
        customer_name,
        customer_phone,
        total_amount,
        delivery_fee,
        driver_id,
        driver:users!orders_driver_id_fkey(
          name,
          phone
        )
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

    // Check if order has user_friendly_code
    if (!orderData.user_friendly_code) {
      console.error('❌ Order missing user_friendly_code');
      return new Response(
        JSON.stringify({ 
          error: 'Order missing user_friendly_code'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Driver is optional - order might not have driver assigned yet

    // Encrypt the order code for secure tracking link
    let encryptedCode: string;
    try {
      encryptedCode = await encryptTrackingCode(orderData.user_friendly_code);
      console.log('🔐 Order code encrypted successfully');
    } catch (encryptError: any) {
      console.error('❌ Failed to encrypt tracking code:', encryptError);
      return new Response(
        JSON.stringify({ 
          error: 'Failed to generate secure tracking link',
          details: encryptError.message
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Build tracking URL with encrypted code
    // Use environment variable for website URL, fallback to hur.delivery
    const websiteUrl = Deno.env.get('WEBSITE_URL') || 'https://hur.delivery';
    const trackingUrl = `${websiteUrl}/track/${encryptedCode}`;
    
    console.log('🔗 Secure tracking URL generated');

    // Format phone number for WhatsApp (ensure it's in 964XXXXXXXXX format)
    let formattedPhone = orderData.customer_phone.trim();
    formattedPhone = formattedPhone.replace('+', '');
    if (!formattedPhone.startsWith('964')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '964' + formattedPhone.substring(1);
      } else {
        formattedPhone = '964' + formattedPhone;
      }
    }

    console.log('📞 Formatted phone number:', formattedPhone);

    // Calculate total fee (order + delivery)
    const totalFee = (parseFloat(orderData.total_amount) + parseFloat(orderData.delivery_fee)).toFixed(0);
    const driverPhone = orderData.driver?.phone || '';
    
    // Create WhatsApp message with tracking link
    const displayName = orderData.customer_name || 'عميلنا العزيز';
    
    // Build message - driver phone only shown if driver is assigned
    let message = `مرحباً ${displayName} 👋

تم استلام طلبك 🛒

📍 تتبع طلبك مباشرة:
${trackingUrl}

💰 إجمالي المبلغ: ${totalFee} دينار عراقي`;

    if (driverPhone) {
      message += `\n📞 رقم السائق: ${driverPhone}`;
    }

    message += `\n\nشكراً لاستخدامك تطبيق حر 🚚`;

    console.log('📝 WhatsApp message prepared');

    // Send WhatsApp message via Wasso API
    const wassoResult = await sendWassoMessage(formattedPhone, message);
    
    if (wassoResult.success) {
      console.log('\n✅ WhatsApp tracking link sent successfully via Wasso!');
      console.log('═══════════════════════════════════════════════════════\n');

      return new Response(
        JSON.stringify({ 
          success: true,
          sent_to: formattedPhone,
          message_id: wassoResult.message_id,
          tracking_url: trackingUrl,
          sent_at: new Date().toISOString()
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } else {
      console.error('❌ Wasso message failed:', wassoResult.error);

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
// SEND WHATSAPP MESSAGE VIA WASSO API
// ═══════════════════════════════════════════════════════════════════════════════
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

  try {
    const response = await fetch(wassoApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': wassoApiKey,
      },
      body: JSON.stringify({
        recipient: phoneNumber,
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

