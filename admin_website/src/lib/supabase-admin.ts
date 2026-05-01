import { createClient } from '@supabase/supabase-js';
import { config } from './config';

/**
 * Supabase Client for Admin Panel
 * Uses RLS policies to grant admin access based on user role
 * Admin users are identified via auth.uid() in the session
 * 
 * Session Configuration:
 * - persistSession: true - Sessions are persisted to localStorage
 * - autoRefreshToken: true - Automatically refresh tokens before they expire
 * - Sessions are configured to last indefinitely by always attempting refresh
 *   when tokens expire or are about to expire (see authStore.ts for details)
 */
export const supabase = createClient(
  config.supabaseUrl,
  config.supabaseAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      storageKey: 'hur-admin-auth',
      // Ensure sessions last indefinitely by:
      // 1. Auto-refreshing tokens before they expire
      // 2. Using refresh tokens which don't expire
      // 3. Storing sessions in localStorage for persistence across browser sessions
      detectSessionInUrl: false, // Don't detect sessions in URL to avoid conflicts
      flowType: 'pkce', // Use PKCE flow for better security
    },
  }
);

// Alias for backward compatibility during migration
export const supabaseAdmin = supabase;

// Export types
export * from './supabase';

