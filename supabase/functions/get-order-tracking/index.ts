import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
import { decryptTrackingCode } from "../_shared/encryption.ts"

serve(async (req) => {
  // CORS headers - public endpoint
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "content-type",
  };

  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📍 GET ORDER TRACKING - EDGE FUNCTION');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Initialize Supabase client with service role key
    // This allows controlled access to order data without RLS complexity
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

    // Get encrypted code from URL query params
    const url = new URL(req.url);
    const encryptedCode = url.searchParams.get('code');
    
    console.log('📥 Request received');
    
    if (!encryptedCode) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required parameter: code'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Decrypt the tracking code
    let userFriendlyCode: string;
    try {
      userFriendlyCode = await decryptTrackingCode(encryptedCode);
      console.log('🔓 Tracking code decrypted successfully');
    } catch (decryptError: any) {
      console.error('❌ Failed to decrypt tracking code:', decryptError);
      return new Response(
        JSON.stringify({ 
          error: 'Invalid or corrupted tracking link'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get order by user_friendly_code
    const { data: orderData, error: orderError } = await supabaseClient
      .from('orders')
      .select(`
        id,
        user_friendly_code,
        customer_name,
        customer_phone,
        pickup_address,
        pickup_latitude,
        pickup_longitude,
        delivery_address,
        delivery_latitude,
        delivery_longitude,
        status,
        total_amount,
        delivery_fee,
        driver_id,
        driver:users!orders_driver_id_fkey(
          name,
          phone
        )
      `)
      .eq('user_friendly_code', userFriendlyCode.toUpperCase())
      .single();

    if (orderError || !orderData) {
      console.error('❌ Order not found:', orderError);
      return new Response(
        JSON.stringify({ 
          error: 'Order not found'
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get latest driver location if driver is assigned AND order is on_the_way or delivered
    // Driver location only shown when order is actively being delivered
    let driverLocation = null;
    if (orderData.driver_id && ['on_the_way', 'delivered'].includes(orderData.status)) {
      const { data: locationData } = await supabaseClient
        .from('driver_locations')
        .select('latitude, longitude, created_at')
        .eq('driver_id', orderData.driver_id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      
      if (locationData) {
        driverLocation = {
          latitude: parseFloat(locationData.latitude),
          longitude: parseFloat(locationData.longitude),
          timestamp: locationData.created_at
        };
      }
    }

    // Calculate total fee
    const totalFee = parseFloat(orderData.total_amount) + parseFloat(orderData.delivery_fee);

    // Build response
    const response = {
      order: {
        code: orderData.user_friendly_code,
        status: orderData.status,
        total_fee: totalFee,
        pickup: {
          address: orderData.pickup_address,
          latitude: parseFloat(orderData.pickup_latitude),
          longitude: parseFloat(orderData.pickup_longitude),
        },
        delivery: {
          address: orderData.delivery_address,
          latitude: parseFloat(orderData.delivery_latitude),
          longitude: parseFloat(orderData.delivery_longitude),
        },
        driver: orderData.driver ? {
          name: orderData.driver.name,
          phone: orderData.driver.phone,
        } : null,
        driver_location: driverLocation,
      }
    };

    console.log('✅ Order tracking data retrieved successfully');
    console.log('═══════════════════════════════════════════════════════\n');

    return new Response(
      JSON.stringify(response),
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

