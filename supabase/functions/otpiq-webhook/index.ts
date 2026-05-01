import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-otpiq-webhook-secret, x-otpiq-webhook-signature, x-otpiq-webhook-timestamp, x-otpiq-webhook-event, x-otpiq-webhook-event-id',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Read raw body first (needed for signature verification)
  const rawBody = await req.text()

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📍 LOCATION WEBHOOK - Incoming Request (OTPIQ)');
  console.log('   Method:', req.method);
  console.log('   URL:', req.url);
  console.log('   Headers:', JSON.stringify(Object.fromEntries(req.headers.entries()), null, 2));
  console.log('   Raw Body:', rawBody);
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // ── Signature verification (warn-only until payload format is confirmed) ──
    const webhookSecret   = Deno.env.get('OTPIQ_WEBHOOK_SECRET')
    const simpleSecret    = req.headers.get('x-otpiq-webhook-secret')
    const timestamp       = req.headers.get('x-otpiq-webhook-timestamp')
    const signatureHeader = req.headers.get('x-otpiq-webhook-signature') // sha256=<hex>

    if (webhookSecret) {
      if (signatureHeader && timestamp) {
        // HMAC-SHA256 verification (inbound webhook style)
        const signingInput = `${timestamp}.${rawBody}`
        const key = await crypto.subtle.importKey(
          'raw',
          new TextEncoder().encode(webhookSecret),
          { name: 'HMAC', hash: 'SHA-256' },
          false,
          ['sign']
        )
        const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signingInput))
        const computed = 'sha256=' + Array.from(new Uint8Array(mac)).map(b => b.toString(16).padStart(2, '0')).join('')
        // Constant-time comparison to prevent timing attacks (as required by OTPIQ docs)
        const encoder = new TextEncoder()
        const a = encoder.encode(computed)
        const b = encoder.encode(signatureHeader)
        const match = a.length === b.length && crypto.subtle.timingSafeEqual
          ? crypto.subtle.timingSafeEqual(a, b)
          : computed === signatureHeader
        if (!match) {
          console.warn('⚠️ HMAC signature mismatch — proceeding anyway until format confirmed');
          console.warn('   Expected:', computed);
          console.warn('   Received:', signatureHeader);
        } else {
          console.log('✅ HMAC signature verified');
        }
      } else if (simpleSecret) {
        // Simple secret header verification (delivery webhook style)
        if (simpleSecret !== webhookSecret) {
          console.warn('⚠️ Webhook secret mismatch — proceeding anyway until format confirmed');
        } else {
          console.log('✅ Webhook secret verified');
        }
      } else {
        console.warn('⚠️ No signature headers present');
      }
    } else {
      console.warn('⚠️ OTPIQ_WEBHOOK_SECRET not set — skipping verification');
    }

    // ── Parse body ──
    let requestBody: any
    try {
      requestBody = JSON.parse(rawBody)
    } catch (_) {
      console.error('❌ Failed to parse JSON body');
      return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('📥 Parsed payload:', JSON.stringify(requestBody, null, 2));

    // ── Extract phone + location from payload ──
    let phoneNumber: string | undefined
    let location: { latitude: number; longitude: number } | undefined
    let message_id: string | undefined

    // OTPIQ inbound webhook format:
    // { contact: { phoneNumber }, message: { id, type, content: { latitude, longitude } }, eventId }
    if (requestBody.contact?.phoneNumber && requestBody.message) {
      phoneNumber = requestBody.contact.phoneNumber
      message_id = requestBody.message.id || requestBody.eventId
      const type = requestBody.message.type
      const content = requestBody.message.content
      if ((type === 'location' || type === 'live_location') && content) {
        const loc = content.location ?? content
        location = {
          latitude: loc.latitude ?? loc.lat,
          longitude: loc.longitude ?? loc.lng ?? loc.lon
        }
      }
    }

    if (!phoneNumber || !location) {
      console.log('⚠️ Could not extract phone/location from payload — check logs above for format');
      return new Response(
        JSON.stringify({ success: true, message: 'Payload received but no location extracted — check function logs' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('📞 Raw phone:', phoneNumber);
    console.log('📍 Raw location:', location);

    // ── Normalize phone ──
    phoneNumber = phoneNumber.split('@')[0].trim()
    let formattedPhone = phoneNumber.replace('+', '')
    if (!formattedPhone.startsWith('964')) {
      formattedPhone = formattedPhone.startsWith('0')
        ? '964' + formattedPhone.substring(1)
        : '964' + formattedPhone
    }
    formattedPhone = '+' + formattedPhone
    console.log('📞 Formatted phone:', formattedPhone);

    // ── Validate coordinates ──
    const lat = parseFloat(String(location.latitude))
    const lng = parseFloat(String(location.longitude))
    if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      console.error('❌ Invalid coordinates:', lat, lng);
      return new Response(JSON.stringify({ error: 'Invalid coordinates' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ── Supabase ──
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Find the most recent pending location request for this phone
    const { data: locationRequest, error: requestError } = await supabaseClient
      .from('whatsapp_location_requests')
      .select('order_id, status, location_received_at, customer_latitude, customer_longitude')
      .eq('customer_phone', formattedPhone)
      .in('status', ['sent', 'delivered', 'location_received'])
      .order('sent_at', { ascending: false })
      .limit(1)
      .single()

    if (requestError || !locationRequest) {
      console.error('❌ No pending location request found for:', formattedPhone);
      return new Response(
        JSON.stringify({ error: 'No location request found', phone: formattedPhone }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const orderId = locationRequest.order_id
    console.log('✅ Found location request for order:', orderId);

    // ── Deduplication ──
    if (locationRequest.status === 'location_received') {
      const existingLat = locationRequest.customer_latitude
      const existingLng = locationRequest.customer_longitude
      if (existingLat && existingLng &&
          Math.abs(existingLat - lat) < 0.0001 &&
          Math.abs(existingLng - lng) < 0.0001) {
        console.log('⚠️ Duplicate location — already processed');
        return new Response(
          JSON.stringify({ success: true, message: 'Already processed', already_processed: true }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    if (locationRequest.status !== 'sent' && locationRequest.status !== 'delivered') {
      return new Response(
        JSON.stringify({ success: true, message: 'Already processed', status: locationRequest.status }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── Atomic status update ──
    const { data: updatedRequest, error: statusUpdateError } = await supabaseClient
      .from('whatsapp_location_requests')
      .update({
        status: 'location_received',
        customer_latitude: lat,
        customer_longitude: lng,
        location_received_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('order_id', orderId)
      .in('status', ['sent', 'delivered'])
      .select('id')
      .maybeSingle()

    if (statusUpdateError) {
      console.error('⚠️ Status update error:', statusUpdateError);
    }

    // ── Update order coordinates ──
    const { error: orderUpdateError } = await supabaseClient.rpc('update_customer_location', {
      p_order_id: orderId,
      p_latitude: lat,
      p_longitude: lng,
      p_is_auto_update: false
    })

    if (orderUpdateError) {
      console.error('❌ Failed to update order location:', orderUpdateError);
      await supabaseClient
        .from('whatsapp_location_requests')
        .update({ status: locationRequest.status })
        .eq('order_id', orderId)
      return new Response(
        JSON.stringify({ error: 'Failed to update order location', details: orderUpdateError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('✅ Customer location updated for order:', orderId);
    console.log('✅ Driver will be notified via database trigger');

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Customer location updated successfully',
        order_id: orderId,
        coordinates: { latitude: lat, longitude: lng },
        updated_at: new Date().toISOString()
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('❌ WEBHOOK ERROR:', error.message);
    console.error('Stack:', error.stack);
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
