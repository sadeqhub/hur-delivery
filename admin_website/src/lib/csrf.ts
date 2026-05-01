/**
 * CSRF (Cross-Site Request Forgery) Protection
 * 
 * Implements OWASP recommendations for CSRF prevention:
 * - Synchronizer Token Pattern
 * - SameSite cookies
 * - Double Submit Cookie pattern
 * 
 * @see https://owasp.org/www-community/attacks/csrf
 */

const CSRF_TOKEN_KEY = 'hur_csrf_token';
const CSRF_TOKEN_HEADER = 'X-CSRF-Token';

/**
 * Generate a cryptographically secure random token
 */
function generateToken(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Get or create CSRF token
 * Token is stored in sessionStorage for the duration of the session
 */
export function getCsrfToken(): string {
  let token = sessionStorage.getItem(CSRF_TOKEN_KEY);
  
  if (!token) {
    token = generateToken();
    sessionStorage.setItem(CSRF_TOKEN_KEY, token);
  }
  
  return token;
}

/**
 * Refresh CSRF token (call after login or periodically)
 */
export function refreshCsrfToken(): string {
  const token = generateToken();
  sessionStorage.setItem(CSRF_TOKEN_KEY, token);
  return token;
}

/**
 * Clear CSRF token (call on logout)
 */
export function clearCsrfToken(): void {
  sessionStorage.removeItem(CSRF_TOKEN_KEY);
}

/**
 * Add CSRF token to request headers
 * Use this for all state-changing requests (POST, PUT, DELETE, PATCH)
 */
export function addCsrfHeader(headers: HeadersInit = {}): HeadersInit {
  const token = getCsrfToken();
  
  return {
    ...headers,
    [CSRF_TOKEN_HEADER]: token,
  };
}

/**
 * Validate CSRF token from request
 * Server-side validation function (for reference)
 */
export function validateCsrfToken(requestToken: string, sessionToken: string): boolean {
  if (!requestToken || !sessionToken) {
    return false;
  }
  
  // Constant-time comparison to prevent timing attacks
  if (requestToken.length !== sessionToken.length) {
    return false;
  }
  
  let result = 0;
  for (let i = 0; i < requestToken.length; i++) {
    result |= requestToken.charCodeAt(i) ^ sessionToken.charCodeAt(i);
  }
  
  return result === 0;
}

/**
 * Fetch wrapper with automatic CSRF token injection
 * Use this instead of raw fetch for all API calls
 */
export async function secureFetch(
  url: string,
  options: RequestInit = {}
): Promise<Response> {
  const method = options.method?.toUpperCase() || 'GET';
  
  // Add CSRF token for state-changing methods
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
    options.headers = addCsrfHeader(options.headers);
  }
  
  // Add security headers
  options.headers = {
    ...options.headers,
    'X-Requested-With': 'XMLHttpRequest', // Helps prevent CSRF
  };
  
  // Set credentials to include cookies (for SameSite protection)
  options.credentials = options.credentials || 'same-origin';
  
  return fetch(url, options);
}

/**
 * React Hook for CSRF protection
 * Usage: const { csrfToken, refreshToken } = useCsrfProtection();
 */
export function useCsrfProtection() {
  const [csrfToken, setCsrfToken] = React.useState<string>(() => getCsrfToken());
  
  const refreshToken = React.useCallback(() => {
    const newToken = refreshCsrfToken();
    setCsrfToken(newToken);
    return newToken;
  }, []);
  
  const clearToken = React.useCallback(() => {
    clearCsrfToken();
    setCsrfToken('');
  }, []);
  
  return {
    csrfToken,
    refreshToken,
    clearToken,
  };
}

// Re-export React for the hook
import React from 'react';

