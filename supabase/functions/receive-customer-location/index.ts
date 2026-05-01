import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📍 RECEIVE CUSTOMER LOCATION - EDGE FUNCTION');
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
    console.log('   Keys:', Object.keys(requestBody));
    
    const { order_id, customer_phone, latitude, longitude, address } = requestBody
    
    // Validate required fields
    if (!order_id || !customer_phone || !latitude || !longitude) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: order_id, customer_phone, latitude, and longitude are required'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validate coordinates
    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    
    if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      console.error('❌ Invalid coordinates');
      return new Response(
        JSON.stringify({ 
          error: 'Invalid coordinates: latitude must be between -90 and 90, longitude must be between -180 and 180'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Validation passed');
    console.log('   Order ID:', order_id);
    console.log('   Customer Phone:', customer_phone);
    console.log('   Coordinates:', lat, lng);

    // Check if order exists and belongs to the customer
    const { data: orderData, error: orderError } = await supabaseClient
      .from('orders')
      .select('id, customer_phone, status')
      .eq('id', order_id)
      .eq('customer_phone', customer_phone)
      .single();

    if (orderError || !orderData) {
      console.error('❌ Order not found or phone mismatch');
      return new Response(
        JSON.stringify({ 
          error: 'Order not found or phone number does not match'
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Order found and verified');

    // Update the order with customer location
    const { error: updateError } = await supabaseClient.rpc('update_customer_location', {
      p_order_id: order_id,
      p_latitude: lat,
      p_longitude: lng,
      p_is_auto_update: false // This is a real customer location
    });

    if (updateError) {
      console.error('❌ Failed to update customer location:', updateError);
      return new Response(
        JSON.stringify({ 
          error: 'Failed to update customer location',
          details: updateError.message
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Customer location updated successfully');

    // Send confirmation WhatsApp message to customer
    try {
      const confirmationMessage = `شكراً لك! تم استلام موقعك بنجاح.

سيتم توصيل طلبك إلى الموقع المحدد.

رقم الطلب: ${order_id.substring(0, 8)}...
وقت الاستلام: ${new Date().toLocaleString('ar-IQ')}`;

      await sendConfirmationWhatsApp(customer_phone, confirmationMessage);
      console.log('✅ Confirmation message sent to customer');
    } catch (whatsappError) {
      console.error('⚠️ Failed to send confirmation message:', whatsappError);
      // Don't fail the whole request if confirmation fails
    }

    // Send notification to merchant about location received
    try {
      const { data: merchantData } = await supabaseClient
        .from('orders')
        .select('merchant_id, customer_name')
        .eq('id', order_id)
        .single();

      if (merchantData) {
        // Create notification for merchant
        await supabaseClient
          .from('notifications')
          .insert({
            user_id: merchantData.merchant_id,
            title: 'تم استلام موقع العميل',
            body: `تم استلام موقع العميل ${merchantData.customer_name} بنجاح`,
            type: 'location_received',
            data: {
              order_id: order_id,
              customer_phone: customer_phone,
              latitude: lat,
              longitude: lng
            }
          });
        
        console.log('✅ Merchant notification created');
      }
    } catch (notificationError) {
      console.error('⚠️ Failed to create merchant notification:', notificationError);
      // Don't fail the whole request if notification fails
    }

    console.log('\n✅ Customer location processing complete!');
    console.log('═══════════════════════════════════════════════════════\n');

    return new Response(
      JSON.stringify({ 
        success: true,
        message: 'Customer location updated successfully',
        order_id: order_id,
        coordinates: { latitude: lat, longitude: lng },
        updated_at: new Date().toISOString()
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

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
// SEND CONFIRMATION WHATSAPP MESSAGE VIA RAILWAY WHATSAPP SERVER
// ═══════════════════════════════════════════════════════════════════════════════
async function sendConfirmationWhatsApp(phoneNumber: string, message: string) {
  const whatsappServerUrl = Deno.env.get('WHATSAPP_SERVER_URL') || 'https://striking-enthusiasm-production.up.railway.app';
  
  // Remove the + prefix for the phone number
  const cleanPhone = phoneNumber.replace('+', '');

  const response = await fetch(`${whatsappServerUrl}/send-message`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      phoneNumber: cleanPhone,
      message: message,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`WhatsApp API error: ${response.status} - ${errorText}`);
  }

  return await response.json();
}
