// =====================================================================================
// CALCULATE ROUTE TIME USING MAPBOX API
// =====================================================================================
// This edge function calculates the estimated route time from pickup to dropoff
// using Mapbox Directions API and returns the time multiplied by 1.5x
// =====================================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { pickupLatitude, pickupLongitude, dropoffLatitude, dropoffLongitude } = await req.json();

    // Validate input
    if (
      !pickupLatitude ||
      !pickupLongitude ||
      !dropoffLatitude ||
      !dropoffLongitude
    ) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'MISSING_COORDINATES',
          message: 'All coordinates are required',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Get Mapbox access token from environment
    const mapboxToken = Deno.env.get('MAPBOX_ACCESS_TOKEN');
    if (!mapboxToken) {
      console.error('❌ MAPBOX_ACCESS_TOKEN not configured');
      return new Response(
        JSON.stringify({
          success: false,
          error: 'MAPBOX_NOT_CONFIGURED',
          message: 'Mapbox access token not configured',
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Build Mapbox Directions API URL
    const coordinatesPath = `${pickupLongitude},${pickupLatitude};${dropoffLongitude},${dropoffLatitude}`;
    const mapboxUrl = `https://api.mapbox.com/directions/v5/mapbox/driving/${coordinatesPath}?access_token=${mapboxToken}&geometries=geojson&overview=simplified`;

    console.log('🌐 Calling Mapbox Directions API...');
    console.log(`   URL: ${mapboxUrl.replace(mapboxToken, 'TOKEN_HIDDEN')}`);

    // Call Mapbox API
    const response = await fetch(mapboxUrl);

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ Mapbox API error:', response.status, errorText);
      return new Response(
        JSON.stringify({
          success: false,
          error: 'MAPBOX_API_ERROR',
          message: `Mapbox API error: ${response.status}`,
          details: errorText,
        }),
        {
          status: response.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const data = await response.json();

    // Check if routes exist
    if (!data.routes || data.routes.length === 0) {
      console.error('❌ No routes returned from Mapbox');
      return new Response(
        JSON.stringify({
          success: false,
          error: 'NO_ROUTES',
          message: 'No routes found between pickup and dropoff locations',
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Get the first route (best route)
    const route = data.routes[0];
    const durationSeconds = route.duration; // Duration in seconds
    const distanceMeters = route.distance; // Distance in meters

    // Multiply by 1.5x as requested
    const timeLimitSeconds = Math.ceil(durationSeconds * 1.5);

    console.log('✅ Route calculated:');
    console.log(`   Duration: ${durationSeconds}s (${Math.round(durationSeconds / 60)} min)`);
    console.log(`   Distance: ${Math.round(distanceMeters)}m`);
    console.log(`   Time limit (1.5x): ${timeLimitSeconds}s (${Math.round(timeLimitSeconds / 60)} min)`);

    return new Response(
      JSON.stringify({
        success: true,
        durationSeconds: Math.round(durationSeconds),
        distanceMeters: Math.round(distanceMeters),
        timeLimitSeconds: timeLimitSeconds,
        durationMinutes: Math.round(durationSeconds / 60),
        timeLimitMinutes: Math.round(timeLimitSeconds / 60),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: any) {
    console.error('❌ Error calculating route time:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'INTERNAL_ERROR',
        message: error.message || 'Failed to calculate route time',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

