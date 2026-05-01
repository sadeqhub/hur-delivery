/**
 * OTP Handler for Hur Delivery
 * Uses OTPIQ directly for sending OTPs via WhatsApp
 *
 * Flow:
 * 1. Send OTP via OTPIQ
 * 2. Verify OTP in database
 * 3. Create/update Supabase user with secure random password
 * 4. Return authenticated session to client
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';

console.log("[otp-handler-clean] Module loaded at:", new Date().toISOString());

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Helper: Normalize phone number
function normalizePhone(phone: string): string {
  return phone.replace(/^\+/, "").replace(/[^\d]/g, "");
}

// Helper: Generate 6-digit OTP
function generateOtpCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Helper: Generate secure random password
function generateSecurePassword(): string {
  return crypto.randomUUID() + crypto.randomUUID(); // 72 chars, highly secure
}

// Helper: Extract IP address from request
function getClientIp(req: Request, body?: any): string {
  // First, check if IP is provided in request body (for rate limiting)
  if (body?.antiFraud?.requesterIp) {
    return body.antiFraud.requesterIp.trim();
  }
  
  // Fallback to headers
  const forwardedFor = req.headers.get('x-forwarded-for');
  if (forwardedFor) {
    return forwardedFor.split(',')[0].trim();
  }
  
  const realIp = req.headers.get('x-real-ip');
  if (realIp) {
    return realIp.trim();
  }
  
  const cfConnectingIp = req.headers.get('cf-connecting-ip');
  if (cfConnectingIp) {
    return cfConnectingIp.trim();
  }
  
  return 'unknown';
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Create admin client (for database operations)
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Create regular client (for sign-in operations)
    const supabaseClient = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { action, phoneNumber, code, purpose = "signup" } = body;
    
    // Extract IP address for rate limiting
    const requesterIp = getClientIp(req, body);

    if (!action) {
      return Response.json(
        { error: 'action is required' },
        { status: 400, headers: corsHeaders }
      );
    }

    console.log(`[otp-handler-clean] Action: ${action}`);

    // ============================================================
    // ACTION: SEND OTP
    // ============================================================
    if (action === "send") {
      if (!phoneNumber) {
        return Response.json(
          { error: 'phoneNumber is required' },
          { status: 400, headers: corsHeaders }
        );
      }

      const phone = normalizePhone(phoneNumber);
      const otpCode = generateOtpCode();
      const expiresAt = new Date(Date.now() + 3 * 60 * 1000); // 3 minutes

      console.log(`[otp-handler-clean] Sending OTP to: ${phone}`);

      // Store OTP in database
      const { error: dbError } = await supabaseAdmin
        .from('otp_verifications')
        .insert({
          phone,
          code: otpCode,
          purpose,
          expires_at: expiresAt.toISOString(),
          consumed: false,
        });

      if (dbError) {
        console.error('[otp-handler-clean] Failed to store OTP:', dbError);
        return Response.json(
          { error: 'Failed to generate OTP' },
          { status: 500, headers: corsHeaders }
        );
      }

      // Send OTP via OTPIQ
      const otpiqApiKey = Deno.env.get('OTPIQ_API_KEY');
      if (!otpiqApiKey) {
        console.error('[otp-handler-clean] OTPIQ_API_KEY not configured');
        return Response.json(
          { error: 'Failed to send OTP' },
          { status: 500, headers: corsHeaders }
        );
      }

      const otpiqPayload: any = {
        phoneNumber: phone,
        smsType: 'verification',
        provider: 'whatsapp-sms',
        verificationCode: otpCode,
      };
      if (requesterIp && requesterIp !== 'unknown') {
        otpiqPayload.antiFraud = { requesterIp };
      }

      const otpiqResponse = await fetch('https://api.otpiq.com/api/sms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${otpiqApiKey}`,
        },
        body: JSON.stringify(otpiqPayload),
      });

      if (!otpiqResponse.ok) {
        let errorText = '';
        let errorData: any = null;
        try {
          errorText = await otpiqResponse.text();
          try { errorData = JSON.parse(errorText); } catch { /* */ }
        } catch { errorText = 'Unknown error'; }

        const errorMessage = (errorData?.message || errorData?.error || errorText || '').toLowerCase();
        const isRateLimit = otpiqResponse.status === 429 ||
          errorMessage.includes('rate limit') || errorMessage.includes('too many requests') ||
          errorMessage.includes('rate_limit') || errorMessage.includes('exceeded') ||
          errorMessage.includes('limit exceeded') || errorMessage.includes('quota exceeded');

        if (isRateLimit) {
          return Response.json(
            { error: 'عذرًا لقد تجاوزت الحد المسموح من المحاولات. يرجى اعادة المحاولة لاحقًا.' },
            { status: 429, headers: corsHeaders }
          );
        }

        console.error('[otp-handler-clean] OTPIQ error:', otpiqResponse.status, errorText);
        return Response.json(
          { error: 'Failed to send OTP' },
          { status: 500, headers: corsHeaders }
        );
      }

      console.log('[otp-handler-clean] ✅ OTP sent successfully via OTPIQ');
      return Response.json(
        { success: true, message: 'OTP sent successfully' },
        { status: 200, headers: corsHeaders }
      );
    }

    // ============================================================
    // ACTION: CHECK_USER (Check if user exists by phone - for client-side validation)
    // ============================================================
    if (action === "check_user") {
      if (!phoneNumber) {
        return Response.json(
          { error: 'phoneNumber is required' },
          { status: 400, headers: corsHeaders }
        );
      }

      const phone = normalizePhone(phoneNumber);
      const phoneWithPlus = phone.startsWith('+') ? phone : `+${phone}`;
      const phoneWithoutPlus = phone.startsWith('+') ? phone.substring(1) : phone;

      // Use service_role to bypass RLS
      const { data: existingProfile, error: profileError } = await supabaseAdmin
        .from('users')
        .select('id, role, phone, name')
        .or(`phone.eq.${phoneWithoutPlus},phone.eq.${phoneWithPlus}`)
        .maybeSingle();

      if (profileError) {
        console.error('[otp-handler-clean] Error checking user:', profileError);
        return Response.json(
          { exists: false, error: 'Error checking user existence' },
          { status: 500, headers: corsHeaders }
        );
      }

      return Response.json(
        {
          exists: !!existingProfile,
          user: existingProfile || null,
        },
        { status: 200, headers: corsHeaders }
      );
    }

    // ============================================================
    // ACTION: AUTHENTICATE (Verify OTP + Create Session)
    // ============================================================
    if (action === "authenticate") {
      if (!phoneNumber || !code) {
        return Response.json(
          { error: 'phoneNumber and code are required' },
          { status: 400, headers: corsHeaders }
        );
      }

      const phone = normalizePhone(phoneNumber);
      console.log(`[otp-handler-clean] Authenticating: ${phone}`);

      // 1. Verify OTP
      const { data: otpRecords, error: otpError } = await supabaseAdmin
        .from('otp_verifications')
        .select('*')
        .eq('phone', phone)
        .eq('consumed', false)
        .order('created_at', { ascending: false })
        .limit(1);

      if (otpError || !otpRecords || otpRecords.length === 0) {
        console.error('[otp-handler-clean] No valid OTP found');
        return Response.json(
          { error: 'No valid OTP found. Please request a new code.' },
          { status: 400, headers: corsHeaders }
        );
      }

      const otpRecord = otpRecords[0];

      // Check expiration
      if (new Date(otpRecord.expires_at) < new Date()) {
        console.error('[otp-handler-clean] OTP expired');
        return Response.json(
          { error: 'OTP expired. Please request a new code.' },
          { status: 400, headers: corsHeaders }
        );
      }

      // Verify code
      if (String(otpRecord.code) !== String(code)) {
        console.error('[otp-handler-clean] Invalid OTP code');
        return Response.json(
          { error: 'Invalid OTP code' },
          { status: 400, headers: corsHeaders }
        );
      }

      console.log('[otp-handler-clean] ✅ OTP verified');

      // 2. Mark OTP as consumed
      await supabaseAdmin
        .from('otp_verifications')
        .update({ consumed: true })
        .eq('id', otpRecord.id);

      // 3. Find existing user profile
      // Use service_role (supabaseAdmin) which bypasses RLS completely
      // Try both with and without the + prefix to handle different formats
      const phoneWithPlus = phone.startsWith('+') ? phone : `+${phone}`;
      const phoneWithoutPlus = phone.startsWith('+') ? phone.substring(1) : phone;
      
      // Query using service_role (bypasses RLS completely)
      // Use OR query to check both phone formats at once
      const { data: existingProfile, error: profileError } = await supabaseAdmin
        .from('users')
        .select('id, phone, role, name')
        .or(`phone.eq.${phoneWithoutPlus},phone.eq.${phoneWithPlus}`)
        .maybeSingle();
      
      if (profileError) {
        console.error('[otp-handler-clean] ❌ Error finding profile:', profileError);
        // Don't fail on error - just log it and continue as if no profile exists
      }

      const email = `${phone}@hur.delivery`;
      const password = generateSecurePassword();
      let userId: string;
      let hasProfile: boolean;
      let role: string;

      // Check if auth user exists (orphaned auth without profile)
      const { data: { users: authUsers }, error: listError } = await supabaseAdmin.auth.admin.listUsers();
      const orphanedAuthUser = authUsers?.find(u => 
        u.phone === phoneWithoutPlus || u.phone === phoneWithPlus || u.email === email
      );

      if (existingProfile) {
        // CASE 1: Profile exists - just log them in
        userId = existingProfile.id;
        role = existingProfile.role || 'user';
        hasProfile = true;

        console.log(`[otp-handler-clean] ✅ Found existing profile: ${userId} (${role})`);

        // Check if auth user exists with the profile's ID
        const { data: authUser, error: getUserError } = await supabaseAdmin.auth.admin.getUserById(userId);

        if (getUserError || !authUser.user) {
          // Auth user doesn't exist for this profile ID
          // But there might be an orphaned auth user with the same email/phone but different ID
          // We need to clean it up first before creating a new one
          console.log('[otp-handler-clean] Auth user not found for profile, checking for orphaned auth user');
          
          if (orphanedAuthUser && orphanedAuthUser.id !== userId) {
            console.log(`[otp-handler-clean] 🗑️  Found mismatched auth user (${orphanedAuthUser.id}), deleting before creating correct one`);
            const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(orphanedAuthUser.id);
            
            if (deleteError) {
              console.error('[otp-handler-clean] Failed to delete orphaned auth user:', deleteError);
            } else {
              console.log('[otp-handler-clean] ✅ Deleted orphaned auth user');
            }
          }
          
          // Now create auth user with the profile's ID
          console.log('[otp-handler-clean] Creating auth user for existing profile');
          const { error: createError } = await supabaseAdmin.auth.admin.createUser({
            id: userId,
            email,
            phone,
            password,
            email_confirm: true,
            phone_confirm: true,
            user_metadata: { phone, role, secure_password: password },
          });

          if (createError) {
            console.error('[otp-handler-clean] Failed to create auth user:', createError);
            return Response.json(
              { error: 'Failed to create authentication' },
              { status: 500, headers: corsHeaders }
            );
          }
        } else {
          // Update existing auth user
          console.log('[otp-handler-clean] Updating auth user password');
          const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
            password,
            phone_confirm: true,
            email_confirm: true,
            user_metadata: { phone, role, secure_password: password },
          });

          if (updateError) {
            console.error('[otp-handler-clean] Failed to update password:', updateError);
            return Response.json(
              { error: 'Failed to update authentication' },
              { status: 500, headers: corsHeaders }
            );
          }
        }
      } else if (orphanedAuthUser) {
        // CASE 2: Auth user exists but NO profile - DELETE and recreate
        console.log(`[otp-handler-clean] ⚠️  Found orphaned auth user (no profile): ${orphanedAuthUser.id}`);
        console.log('[otp-handler-clean] 🗑️  Deleting orphaned auth user to allow fresh signup');
        
        const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(orphanedAuthUser.id);
        
        if (deleteError) {
          console.error('[otp-handler-clean] Failed to delete orphaned auth user:', deleteError);
          return Response.json(
            { error: 'Account exists but is incomplete. Please contact support.' },
            { status: 500, headers: corsHeaders }
          );
        }
        
        console.log('[otp-handler-clean] ✅ Orphaned auth user deleted, creating fresh user');
        
        // Now create a fresh auth user (profile will be created in signup flow)
        role = 'user';
        hasProfile = false;

        const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email,
          phone,
          password,
          email_confirm: true,
          phone_confirm: true,
          user_metadata: { phone, role, secure_password: password },
        });

        if (createError || !newUser.user) {
          console.error('[otp-handler-clean] Failed to create user after cleanup:', createError);
          return Response.json(
            { error: 'Failed to create user' },
            { status: 500, headers: corsHeaders }
          );
        }

        userId = newUser.user.id;
        console.log(`[otp-handler-clean] ✅ Created fresh user after cleanup: ${userId}`);
      } else {
        // CASE 3: Completely new user - create auth user
        role = 'user';
        hasProfile = false;

        console.log('[otp-handler-clean] 📝 Creating new user (no existing profile or auth)');

        const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email,
          phone,
          password,
          email_confirm: true,
          phone_confirm: true,
          user_metadata: { phone, role, secure_password: password },
        });

        if (createError || !newUser.user) {
          console.error('[otp-handler-clean] Failed to create user:', createError);
          return Response.json(
            { error: 'Failed to create user' },
            { status: 500, headers: corsHeaders }
          );
        }

        userId = newUser.user.id;
        console.log(`[otp-handler-clean] ✅ Created new user: ${userId}`);
      }

      // 4. Sign in to get session tokens
      console.log('[otp-handler-clean] Creating authenticated session');
      
      const { data: signInData, error: signInError } = await supabaseClient.auth.signInWithPassword({
        email,
        password,
      });

      if (signInError || !signInData.session) {
        console.error('[otp-handler-clean] Failed to sign in:', signInError);
        return Response.json(
          { error: 'Failed to create session' },
          { status: 500, headers: corsHeaders }
        );
      }

      console.log('[otp-handler-clean] ✅ Session created successfully');

      // 5. Return authenticated session
      return Response.json(
        {
          success: true,
          authUserId: userId,
          email,
          phone,
          role,
          hasProfile,
          session: {
            access_token: signInData.session.access_token,
            refresh_token: signInData.session.refresh_token,
            expires_in: signInData.session.expires_in,
            expires_at: signInData.session.expires_at,
            token_type: signInData.session.token_type,
          },
          user: signInData.user,
        },
        { status: 200, headers: corsHeaders }
      );
    }

    // Unknown action
    return Response.json(
      { error: 'Invalid action. Supported actions: send, authenticate, check_user' },
      { status: 400, headers: corsHeaders }
    );

  } catch (error: any) {
    console.error('[otp-handler-clean] Error:', error);
    return Response.json(
      { error: 'Internal server error', message: error.message },
      { status: 500, headers: corsHeaders }
    );
  }
});

