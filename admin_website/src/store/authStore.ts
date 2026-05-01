import { create } from 'zustand';
import { supabase, type User } from '../lib/supabase-admin';
import type { Session } from '@supabase/supabase-js';
import type { AdminAuthority } from '../lib/permissions';

interface AuthState {
  session: Session | null;
  user: User | null;
  loading: boolean;
  isAdmin: boolean;
  adminAuthority: AdminAuthority | null;
  setSession: (session: Session | null) => void;
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
  sendOtp: (phoneNumber: string) => Promise<void>;
  verifyOtp: (phoneNumber: string, code: string) => Promise<void>;
  signOut: () => Promise<void>;
  checkAuth: () => Promise<void>;
}

// Initialize state from localStorage to avoid loading screen on page reload
const initializeState = () => {
  try {
    const storedUser = localStorage.getItem('hur_admin_user');
    if (storedUser) {
      const userData = JSON.parse(storedUser);
      if (userData?.role === 'admin') {
        return {
          user: userData,
          isAdmin: true,
          adminAuthority: (userData.admin_authority as AdminAuthority) || 'viewer',
          loading: false,
        };
      }
    }
  } catch (error) {
    console.error('[AuthStore] Error initializing from localStorage:', error);
  }
  return {
    user: null,
    isAdmin: false,
    adminAuthority: null,
    loading: false,
  };
};

const initialState = initializeState();

export const useAuthStore = create<AuthState>((set, get) => ({
  session: null,
  ...initialState,

  setSession: (session) => {
    set({ session });
    // Persist session to localStorage when it changes
    if (session) {
      const sessionData = {
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_at: session.expires_at,
        expires_in: session.expires_in,
        token_type: session.token_type,
        user: session.user,
      };
      localStorage.setItem('hur_admin_session', JSON.stringify(sessionData));
    } else {
      localStorage.removeItem('hur_admin_session');
    }
  },
  
  setUser: (user) => {
    const isAdmin = user?.role === 'admin';
    const adminAuthority = (user?.admin_authority as AdminAuthority) || null;
    
    set({ 
    user, 
      isAdmin,
      adminAuthority,
    });
    
    // If user is not admin, logout immediately
    if (user && !isAdmin) {
      console.warn('User is not an admin, logging out...');
      get().signOut();
    }
  },
  
  setLoading: (loading) => set({ loading }),

  sendOtp: async (phoneNumber: string) => {
    // DON'T set loading: true here - it causes the Login component to unmount
    // The Login component has its own loading state from useAuthStore
    try {
      const response = await supabase.functions.invoke('otp-handler-clean', {
        body: {
          action: 'send',
          phoneNumber,
          purpose: 'admin_login',
        },
      });

      const { data, error } = response;

      if (error) {
        console.error('[AuthStore] OTP send error:', error);
        throw new Error(error.message || 'Failed to send OTP');
      }
      
      // Check if response has success field or if it's just a message
      if (data) {
        if (data.success === true || data.message || data.success === 'true') {
          return; // Success - exit early
        }
        
        // If no success field, check for error
        if (data.error) {
          console.error('[AuthStore] Error in response:', data.error);
          throw new Error(data.error);
        }
      }
    } catch (error: any) {
      console.error('[AuthStore] Send OTP error:', error);
      throw error; // Re-throw to let Login component handle it
    }
  },

  verifyOtp: async (phoneNumber: string, code: string) => {
    set({ loading: true });
    try {
      // Call the same OTP handler edge function as user login
      const { data, error } = await supabase.functions.invoke('otp-handler-clean', {
        body: {
          action: 'authenticate',
          phoneNumber,
          code,
        },
      });

      if (error) throw error;
      if (!data?.success) throw new Error(data?.error || 'Invalid OTP code');

      // Set the session from the Edge Function response
      const { session: sessionData } = data;
      
      if (sessionData?.access_token) {
        // Set the session in Supabase client
        const { data: sessionResult, error: sessionError } = await supabase.auth.setSession({
          access_token: sessionData.access_token,
          refresh_token: sessionData.refresh_token,
        });

        if (sessionError) throw sessionError;

        // Fetch user details to check if admin
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', sessionResult.session?.user.id)
          .single();

        if (userError) throw userError;

        // Check if user is admin
        if (userData.role !== 'admin') {
          await get().signOut();
          throw new Error('Access denied. Admin role required.');
        }

        const adminAuthority = (userData.admin_authority as AdminAuthority) || 'viewer';

        const session = sessionResult.session;
        set({ 
          session,
          user: userData as User,
          isAdmin: true,
          adminAuthority,
        });

        // Store session and user in localStorage for persistence
        if (session) {
          const sessionData = {
            access_token: session.access_token,
            refresh_token: session.refresh_token,
            expires_at: session.expires_at,
            expires_in: session.expires_in,
            token_type: session.token_type,
            user: session.user,
          };
        localStorage.setItem('hur_admin_session', JSON.stringify(sessionData));
        }
        localStorage.setItem('hur_admin_user', JSON.stringify(userData));
      } else {
        throw new Error('Invalid session data received');
      }
    } catch (error: any) {
      console.error('Verify OTP error:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  signOut: async () => {
    await supabase.auth.signOut();
    localStorage.removeItem('hur_admin_session');
    localStorage.removeItem('hur_admin_user');
    set({ session: null, user: null, isAdmin: false, adminAuthority: null, loading: false });
  },

  checkAuth: async () => {
    // Don't start a new check if we're already loading
    const currentState = get();
    if (currentState.loading && currentState.user && currentState.isAdmin) {
      return;
    }
    
    // Check if we already have user data and session
    if (currentState.user && currentState.session && currentState.isAdmin) {
      if (currentState.loading) {
        set({ loading: false });
      }
      return;
    }
    
    // Only set loading to true if we don't have a user yet
    if (!currentState.user) {
      set({ loading: true });
    }
    try {
      // Check Supabase's built-in session (it handles persistence automatically)
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      
      if (session && !sessionError) {
        // Load user data directly - no waiting for SIGNED_IN
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single();

        if (!userError && userData?.role === 'admin') {
          const adminAuthority = (userData.admin_authority as AdminAuthority) || 'viewer';
          
          set({ 
            session,
            user: userData as User,
            isAdmin: true,
            adminAuthority,
            loading: false, // Set loading to false immediately
          });
          
          // Update localStorage
          const sessionData = {
            access_token: session.access_token,
            refresh_token: session.refresh_token,
            expires_at: session.expires_at,
            expires_in: session.expires_in,
            token_type: session.token_type,
            user: session.user,
          };
          localStorage.setItem('hur_admin_session', JSON.stringify(sessionData));
          localStorage.setItem('hur_admin_user', JSON.stringify(userData));
          
          return;
        } else {
          await get().signOut();
          return;
        }
      }

      // Fallback: Try to restore from localStorage if Supabase session is missing
      const storedSession = localStorage.getItem('hur_admin_session');
      const storedUser = localStorage.getItem('hur_admin_user');

      if (storedSession && storedUser) {
        try {
          const sessionData = JSON.parse(storedSession);
          
          // Always attempt to refresh to ensure sessions last indefinitely
          // Refresh tokens don't expire, so we can keep refreshing indefinitely
          if (sessionData.refresh_token) {
            // Try to refresh using the refresh token - retry multiple times for reliability
            let refreshData: any = null;
            let refreshError: any = null;
            let attempts = 0;
            const maxAttempts = 3;
            
            while (attempts < maxAttempts && !refreshData?.session) {
              attempts++;
              const result = await supabase.auth.refreshSession({
                refresh_token: sessionData.refresh_token,
              });
              refreshData = result.data;
              refreshError = result.error;
              
              if (refreshError && attempts < maxAttempts) {
                await new Promise(resolve => setTimeout(resolve, 1000 * attempts)); // Exponential backoff
              }
            }
            
            if (refreshError || !refreshData?.session) {
              // Only log out if refresh completely fails after retries
              await get().signOut();
              isInitializing = false;
              set({ loading: false });
              return;
            }
            
            const refreshedSession = refreshData.session;
            
            // Verify user is still admin
            const { data: currentUserData, error: userError } = await supabase
              .from('users')
              .select('*')
              .eq('id', refreshedSession.user.id)
              .single();

            if (userError || !currentUserData || currentUserData.role !== 'admin') {
              await get().signOut();
              isInitializing = false;
              set({ loading: false });
              return;
            }

            const adminAuthority = (currentUserData.admin_authority as AdminAuthority) || 'viewer';

            set({ 
              session: refreshedSession,
              user: currentUserData as User,
              isAdmin: true,
              adminAuthority,
            });
            
            // Update localStorage with refreshed session
            const updatedSessionData = {
              access_token: refreshedSession.access_token,
              refresh_token: refreshedSession.refresh_token,
              expires_at: refreshedSession.expires_at,
              expires_in: refreshedSession.expires_in,
              token_type: refreshedSession.token_type,
              user: refreshedSession.user,
            };
            localStorage.setItem('hur_admin_session', JSON.stringify(updatedSessionData));
            localStorage.setItem('hur_admin_user', JSON.stringify(currentUserData));
            isInitializing = false;
            set({ loading: false });
            return;
          }
          
          // Stored session is still valid, restore it
          const { data: sessionResult, error: sessionError } = await supabase.auth.setSession({
            access_token: sessionData.access_token,
            refresh_token: sessionData.refresh_token,
          });

          if (!sessionError && sessionResult.session) {
            // Verify user is still admin
            const { data: currentUserData, error: userError } = await supabase
              .from('users')
              .select('*')
              .eq('id', sessionResult.session.user.id)
              .single();

            if (userError || !currentUserData || currentUserData.role !== 'admin') {
              await get().signOut();
              isInitializing = false;
              set({ loading: false });
              return;
            }

            const adminAuthority = (currentUserData.admin_authority as AdminAuthority) || 'viewer';

            set({ 
              session: sessionResult.session,
              user: currentUserData as User,
              isAdmin: true,
              adminAuthority,
            });
            
            // Update localStorage
            const updatedSessionData = {
              access_token: sessionResult.session.access_token,
              refresh_token: sessionResult.session.refresh_token,
              expires_at: sessionResult.session.expires_at,
              expires_in: sessionResult.session.expires_in,
              token_type: sessionResult.session.token_type,
              user: sessionResult.session.user,
            };
            localStorage.setItem('hur_admin_session', JSON.stringify(updatedSessionData));
            localStorage.setItem('hur_admin_user', JSON.stringify(currentUserData));
            isInitializing = false;
            set({ loading: false });
            return;
          }
        } catch (error) {
          console.error('[AuthStore] Error restoring from localStorage:', error);
          // If restoration fails, clear localStorage
          localStorage.removeItem('hur_admin_session');
          localStorage.removeItem('hur_admin_user');
        }
      }

      // No valid session found - set loading to false
      isInitializing = false;
      set({ loading: false });
    } catch (error) {
      console.error('[AuthStore] Auth check error:', error);
      await get().signOut();
      isInitializing = false;
      set({ loading: false });
    } finally {
      // Ensure loading is always set to false
      isInitializing = false;
      set({ loading: false });
    }
  },
}));

// Subscribe to auth changes and update store + localStorage
// Use a flag to prevent processing TOKEN_REFRESHED during initial checkAuth
let isInitializing = false;

supabase.auth.onAuthStateChange(async (event, session) => {
  const state = useAuthStore.getState();
  
  // Don't process TOKEN_REFRESHED if we already have user data and session
  if (event === 'TOKEN_REFRESHED' && state.user && state.isAdmin && state.session && session) {
    state.setSession(session);
    // Just update the session in localStorage
    const sessionData = {
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_at: session.expires_at,
      expires_in: session.expires_in,
      token_type: session.token_type,
      user: session.user,
    };
    localStorage.setItem('hur_admin_session', JSON.stringify(sessionData));
    return;
  }
  
  // During initialization, skip TOKEN_REFRESHED but allow SIGNED_IN
  if (isInitializing && event === 'TOKEN_REFRESHED') {
    return;
  }
  
  // Handle INITIAL_SESSION event FIRST - if no session, ensure loading is false
  if (event === 'INITIAL_SESSION' && !session) {
    isInitializing = false;
    useAuthStore.setState({ loading: false });
    return;
  }
  
  state.setSession(session);
  
  // If session is set, fetch and update user data (only for SIGNED_IN)
  if (session && event === 'SIGNED_IN') {
    try {
      // If we already have user data and it matches, just update session
      if (state.user && state.user.id === session.user.id && state.isAdmin) {
        const sessionData = {
          access_token: session.access_token,
          refresh_token: session.refresh_token,
          expires_at: session.expires_at,
          expires_in: session.expires_in,
          token_type: session.token_type,
          user: session.user,
        };
        localStorage.setItem('hur_admin_session', JSON.stringify(sessionData));
        // Ensure loading is false
        useAuthStore.setState({ loading: false });
        return;
      }
      
      // Skip user fetch on SIGNED_IN - let checkAuth handle it
      // This prevents hanging when the user fetch is slow
      return;
    } catch (error) {
      console.error('[AuthStore] Error in SIGNED_IN handler:', error);
    }
  } else if (event === 'SIGNED_OUT') {
    // Clear localStorage on sign out
    localStorage.removeItem('hur_admin_session');
    localStorage.removeItem('hur_admin_user');
    state.setUser(null);
  }
});

// Periodic token refresh mechanism to ensure sessions last indefinitely
// Checks every 5 minutes and refreshes tokens before they expire
let tokenRefreshInterval: ReturnType<typeof setInterval> | null = null;

const startTokenRefreshInterval = () => {
  // Clear any existing interval
  if (tokenRefreshInterval) {
    clearInterval(tokenRefreshInterval);
  }
  
  // Check every 2 minutes and refresh proactively to ensure sessions last indefinitely
  // Refresh tokens don't expire, so we can keep refreshing indefinitely
  tokenRefreshInterval = setInterval(async () => {
    const state = useAuthStore.getState();
    const session = state.session;
    
    if (!session || !state.isAdmin) {
      // No active session, stop checking
      if (tokenRefreshInterval) {
        clearInterval(tokenRefreshInterval);
        tokenRefreshInterval = null;
      }
      return;
    }
    
    // Always refresh tokens proactively to ensure sessions last indefinitely
    // Refresh tokens don't expire, so we can keep refreshing indefinitely
    if (session.refresh_token) {
      try {
        // Check if token is about to expire (within 5 minutes) or already expired
        const expiresAt = session.expires_at;
        const now = Math.floor(Date.now() / 1000);
        const timeUntilExpiry = expiresAt ? expiresAt - now : 0;
        
        // Refresh if token expires within 5 minutes or is already expired
        if (timeUntilExpiry < 300 || !expiresAt) {
          const { data: refreshData, error: refreshError } = await supabase.auth.refreshSession({
            refresh_token: session.refresh_token,
          });
          
          if (!refreshError && refreshData?.session) {
            state.setSession(refreshData.session);
            
            // Update localStorage
            const sessionData = {
              access_token: refreshData.session.access_token,
              refresh_token: refreshData.session.refresh_token,
              expires_at: refreshData.session.expires_at,
              expires_in: refreshData.session.expires_in,
              token_type: refreshData.session.token_type,
              user: refreshData.session.user,
            };
            localStorage.setItem('hur_admin_session', JSON.stringify(sessionData));
            console.log('[AuthStore] Token refreshed successfully - session extended indefinitely');
          } else if (refreshError) {
            console.error('[AuthStore] Periodic refresh: Error refreshing token', refreshError);
            // Don't log out on refresh error - retry on next interval
          }
        }
      } catch (error) {
        console.error('[AuthStore] Periodic refresh: Error refreshing token', error);
        // Don't log out on error - retry on next interval
      }
    }
  }, 2 * 60 * 1000); // Check every 2 minutes for more aggressive refresh
};

// Start the interval when a session is detected
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN' && session) {
    // Start periodic refresh when signed in
    startTokenRefreshInterval();
  } else if (event === 'SIGNED_OUT') {
    // Stop periodic refresh when signed out
    if (tokenRefreshInterval) {
      clearInterval(tokenRefreshInterval);
      tokenRefreshInterval = null;
    }
  } else if (event === 'TOKEN_REFRESHED' && session) {
    // Token was refreshed, restart interval to ensure it keeps running
    startTokenRefreshInterval();
  }
});

// Start interval on initial load if session exists
if (typeof window !== 'undefined') {
  window.addEventListener('load', () => {
    const state = useAuthStore.getState();
    if (state.session && state.isAdmin) {
      startTokenRefreshInterval();
    }
  });
}

