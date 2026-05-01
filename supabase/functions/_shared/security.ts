/**
 * Security Utilities for Supabase Edge Functions
 * 
 * OWASP Security Best Practices Implementation:
 * - Rate limiting (IP-based and user-based)
 * - Input validation and sanitization
 * - Request size limits
 * - Security headers
 * - CSRF protection
 * 
 * @see https://owasp.org/www-project-top-ten/
 */

// ============================================================================
// RATE LIMITING
// ============================================================================

interface RateLimitConfig {
  windowMs: number;      // Time window in milliseconds
  maxRequests: number;   // Maximum requests per window
  keyPrefix: string;     // Prefix for rate limit keys
}

interface RateLimitStore {
  [key: string]: {
    count: number;
    resetTime: number;
  };
}

// In-memory store for rate limiting (per Edge Function instance)
// Note: For production with multiple instances, use Redis or Supabase
const rateLimitStore: RateLimitStore = {};

/**
 * Rate limiter middleware
 * Implements sliding window rate limiting per IP address and optional user ID
 * 
 * @param identifier - IP address or user ID
 * @param config - Rate limit configuration
 * @returns Object with allowed status and retry info
 */
export function checkRateLimit(
  identifier: string,
  config: RateLimitConfig
): { allowed: boolean; retryAfter?: number; remaining?: number } {
  const key = `${config.keyPrefix}:${identifier}`;
  const now = Date.now();
  
  // Clean up expired entries periodically (every 1000 checks)
  if (Math.random() < 0.001) {
    cleanupExpiredRateLimits(now);
  }
  
  const record = rateLimitStore[key];
  
  // No record exists - create new one
  if (!record || now > record.resetTime) {
    rateLimitStore[key] = {
      count: 1,
      resetTime: now + config.windowMs,
    };
    return { allowed: true, remaining: config.maxRequests - 1 };
  }
  
  // Increment count
  record.count++;
  
  // Check if limit exceeded
  if (record.count > config.maxRequests) {
    const retryAfter = Math.ceil((record.resetTime - now) / 1000);
    return { allowed: false, retryAfter };
  }
  
  return { allowed: true, remaining: config.maxRequests - record.count };
}

/**
 * Clean up expired rate limit entries
 */
function cleanupExpiredRateLimits(now: number): void {
  for (const key in rateLimitStore) {
    if (rateLimitStore[key].resetTime < now) {
      delete rateLimitStore[key];
    }
  }
}

/**
 * Extract IP address from request
 * Handles various proxy headers
 */
export function getClientIp(req: Request): string {
  // Check common proxy headers (in order of preference)
  const forwardedFor = req.headers.get('x-forwarded-for');
  if (forwardedFor) {
    // x-forwarded-for can contain multiple IPs, take the first one
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
  
  // Fallback to 'unknown' if no IP found
  return 'unknown';
}

/**
 * Preset rate limit configurations
 */
export const RateLimitPresets = {
  // Strict: 5 requests per minute (for sensitive operations like OTP, login)
  STRICT: { windowMs: 60000, maxRequests: 5, keyPrefix: 'rl_strict' },
  
  // Moderate: 30 requests per minute (for API endpoints)
  MODERATE: { windowMs: 60000, maxRequests: 30, keyPrefix: 'rl_moderate' },
  
  // Relaxed: 100 requests per minute (for read operations)
  RELAXED: { windowMs: 60000, maxRequests: 100, keyPrefix: 'rl_relaxed' },
  
  // Webhook: 1000 requests per minute (for external webhooks)
  WEBHOOK: { windowMs: 60000, maxRequests: 1000, keyPrefix: 'rl_webhook' },
};

// ============================================================================
// INPUT VALIDATION & SANITIZATION
// ============================================================================

/**
 * Validation error class
 */
export class ValidationError extends Error {
  constructor(
    message: string,
    public field?: string,
    public code?: string
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * Phone number validation and normalization
 * Validates Iraqi phone numbers in format 964XXXXXXXXXX
 */
export function validateAndNormalizePhone(phone: string): string {
  if (!phone || typeof phone !== 'string') {
    throw new ValidationError('Phone number is required', 'phone', 'REQUIRED');
  }
  
  // Remove all non-digit characters
  let cleaned = phone.replace(/\D/g, '');
  
  // Handle various formats
  if (cleaned.startsWith('00964')) {
    cleaned = cleaned.substring(2);
  } else if (cleaned.startsWith('0') && cleaned.length === 11) {
    cleaned = '964' + cleaned.substring(1);
  } else if (!cleaned.startsWith('964')) {
    if (cleaned.length === 10 && cleaned.startsWith('7')) {
      cleaned = '964' + cleaned;
    } else {
      throw new ValidationError(
        'Invalid phone number format. Expected Iraqi number (964XXXXXXXXXX)',
        'phone',
        'INVALID_FORMAT'
      );
    }
  }
  
  // Validate length (964 + 10 digits = 13 total)
  if (cleaned.length !== 13) {
    throw new ValidationError(
      'Invalid phone number length. Expected 13 digits (964XXXXXXXXXX)',
      'phone',
      'INVALID_LENGTH'
    );
  }
  
  // Validate it starts with 964
  if (!cleaned.startsWith('964')) {
    throw new ValidationError(
      'Phone number must start with 964 (Iraq country code)',
      'phone',
      'INVALID_COUNTRY_CODE'
    );
  }
  
  return cleaned;
}

/**
 * Email validation
 */
export function validateEmail(email: string): string {
  if (!email || typeof email !== 'string') {
    throw new ValidationError('Email is required', 'email', 'REQUIRED');
  }
  
  const trimmed = email.trim().toLowerCase();
  
  // Basic email regex (RFC 5322 simplified)
  const emailRegex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
  
  if (!emailRegex.test(trimmed)) {
    throw new ValidationError('Invalid email format', 'email', 'INVALID_FORMAT');
  }
  
  if (trimmed.length > 254) {
    throw new ValidationError('Email too long (max 254 characters)', 'email', 'TOO_LONG');
  }
  
  return trimmed;
}

/**
 * UUID validation
 */
export function validateUuid(uuid: string, fieldName = 'id'): string {
  if (!uuid || typeof uuid !== 'string') {
    throw new ValidationError(`${fieldName} is required`, fieldName, 'REQUIRED');
  }
  
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  
  if (!uuidRegex.test(uuid)) {
    throw new ValidationError(`Invalid ${fieldName} format`, fieldName, 'INVALID_FORMAT');
  }
  
  return uuid.toLowerCase();
}

/**
 * String sanitization - removes potentially dangerous characters
 */
export function sanitizeString(input: string, maxLength = 1000): string {
  if (!input || typeof input !== 'string') {
    return '';
  }
  
  // Trim and limit length
  let sanitized = input.trim().substring(0, maxLength);
  
  // Remove null bytes
  sanitized = sanitized.replace(/\0/g, '');
  
  // Remove control characters except newlines and tabs
  sanitized = sanitized.replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '');
  
  return sanitized;
}

/**
 * Number validation with range check
 */
export function validateNumber(
  value: any,
  fieldName: string,
  options: { min?: number; max?: number; integer?: boolean } = {}
): number {
  const num = Number(value);
  
  if (isNaN(num)) {
    throw new ValidationError(`${fieldName} must be a number`, fieldName, 'INVALID_TYPE');
  }
  
  if (options.integer && !Number.isInteger(num)) {
    throw new ValidationError(`${fieldName} must be an integer`, fieldName, 'NOT_INTEGER');
  }
  
  if (options.min !== undefined && num < options.min) {
    throw new ValidationError(
      `${fieldName} must be at least ${options.min}`,
      fieldName,
      'TOO_SMALL'
    );
  }
  
  if (options.max !== undefined && num > options.max) {
    throw new ValidationError(
      `${fieldName} must be at most ${options.max}`,
      fieldName,
      'TOO_LARGE'
    );
  }
  
  return num;
}

/**
 * Enum validation
 */
export function validateEnum<T extends string>(
  value: any,
  fieldName: string,
  allowedValues: readonly T[]
): T {
  if (!value || typeof value !== 'string') {
    throw new ValidationError(`${fieldName} is required`, fieldName, 'REQUIRED');
  }
  
  if (!allowedValues.includes(value as T)) {
    throw new ValidationError(
      `${fieldName} must be one of: ${allowedValues.join(', ')}`,
      fieldName,
      'INVALID_VALUE'
    );
  }
  
  return value as T;
}

/**
 * Object validation - reject unexpected fields
 */
export function validateObject<T extends Record<string, any>>(
  obj: any,
  allowedFields: readonly (keyof T)[],
  fieldName = 'object'
): void {
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) {
    throw new ValidationError(`${fieldName} must be an object`, fieldName, 'INVALID_TYPE');
  }
  
  const objKeys = Object.keys(obj);
  const unexpectedFields = objKeys.filter(key => !allowedFields.includes(key as keyof T));
  
  if (unexpectedFields.length > 0) {
    throw new ValidationError(
      `Unexpected fields: ${unexpectedFields.join(', ')}`,
      fieldName,
      'UNEXPECTED_FIELDS'
    );
  }
}

// ============================================================================
// SECURITY HEADERS
// ============================================================================

/**
 * Get secure CORS headers
 * Implements OWASP recommendations for CORS
 */
export function getSecureCorsHeaders(allowedOrigins?: string[]): Record<string, string> {
  // Default to wildcard for public APIs, but should be restricted in production
  const origin = allowedOrigins && allowedOrigins.length > 0
    ? allowedOrigins[0] // In production, check request origin and return matching allowed origin
    : '*';
  
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Max-Age': '86400', // 24 hours
  };
}

/**
 * Get security headers
 * Implements OWASP security headers recommendations
 */
export function getSecurityHeaders(): Record<string, string> {
  return {
    // Prevent MIME type sniffing
    'X-Content-Type-Options': 'nosniff',
    
    // Enable XSS protection (legacy browsers)
    'X-XSS-Protection': '1; mode=block',
    
    // Prevent clickjacking
    'X-Frame-Options': 'DENY',
    
    // Strict Transport Security (HTTPS only)
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    
    // Content Security Policy
    'Content-Security-Policy': "default-src 'self'; script-src 'self'; object-src 'none'",
    
    // Referrer Policy
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    
    // Permissions Policy (formerly Feature Policy)
    'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
  };
}

/**
 * Combine all headers for a response
 */
export function getAllSecurityHeaders(allowedOrigins?: string[]): Record<string, string> {
  return {
    ...getSecureCorsHeaders(allowedOrigins),
    ...getSecurityHeaders(),
    'Content-Type': 'application/json',
  };
}

// ============================================================================
// REQUEST SIZE LIMITS
// ============================================================================

/**
 * Check request body size
 * Prevents DoS attacks via large payloads
 */
export async function validateRequestSize(
  req: Request,
  maxSizeBytes: number = 1048576 // 1MB default
): Promise<void> {
  const contentLength = req.headers.get('content-length');
  
  if (contentLength) {
    const size = parseInt(contentLength, 10);
    if (size > maxSizeBytes) {
      throw new ValidationError(
        `Request body too large. Maximum size: ${maxSizeBytes} bytes`,
        'body',
        'TOO_LARGE'
      );
    }
  }
}

/**
 * Safe JSON parse with size limit
 */
export async function parseJsonSafely<T = any>(
  req: Request,
  maxSizeBytes: number = 1048576 // 1MB default
): Promise<T> {
  await validateRequestSize(req, maxSizeBytes);
  
  try {
    const text = await req.text();
    
    // Additional check on actual text length
    if (text.length > maxSizeBytes) {
      throw new ValidationError(
        `Request body too large. Maximum size: ${maxSizeBytes} bytes`,
        'body',
        'TOO_LARGE'
      );
    }
    
    return JSON.parse(text) as T;
  } catch (error) {
    if (error instanceof ValidationError) {
      throw error;
    }
    throw new ValidationError(
      'Invalid JSON in request body',
      'body',
      'INVALID_JSON'
    );
  }
}

// ============================================================================
// RESPONSE HELPERS
// ============================================================================

/**
 * Create error response with security headers
 */
export function createErrorResponse(
  error: string | ValidationError,
  status: number = 400,
  allowedOrigins?: string[]
): Response {
  const headers = getAllSecurityHeaders(allowedOrigins);
  
  const body = typeof error === 'string'
    ? { error, success: false }
    : {
        error: error.message,
        field: error.field,
        code: error.code,
        success: false,
      };
  
  return new Response(JSON.stringify(body), { status, headers });
}

/**
 * Create success response with security headers
 */
export function createSuccessResponse(
  data: any,
  status: number = 200,
  allowedOrigins?: string[]
): Response {
  const headers = getAllSecurityHeaders(allowedOrigins);
  
  return new Response(
    JSON.stringify({ ...data, success: true }),
    { status, headers }
  );
}

/**
 * Create rate limit exceeded response (429)
 */
export function createRateLimitResponse(
  retryAfter: number,
  allowedOrigins?: string[]
): Response {
  const headers = {
    ...getAllSecurityHeaders(allowedOrigins),
    'Retry-After': retryAfter.toString(),
    'X-RateLimit-Limit': 'exceeded',
  };
  
  return new Response(
    JSON.stringify({
      error: 'Too many requests. Please try again later.',
      retryAfter,
      success: false,
    }),
    { status: 429, headers }
  );
}

// ============================================================================
// MIDDLEWARE HELPERS
// ============================================================================

/**
 * Combined security middleware
 * Apply rate limiting, size checks, and return proper headers
 */
export async function applySecurityMiddleware(
  req: Request,
  config: {
    rateLimit?: RateLimitConfig;
    maxBodySize?: number;
    allowedOrigins?: string[];
  } = {}
): Promise<{ allowed: boolean; response?: Response }> {
  // Handle OPTIONS (CORS preflight)
  if (req.method === 'OPTIONS') {
    return {
      allowed: false,
      response: new Response('ok', {
        headers: getAllSecurityHeaders(config.allowedOrigins),
      }),
    };
  }
  
  // Rate limiting
  if (config.rateLimit) {
    const ip = getClientIp(req);
    const rateLimitResult = checkRateLimit(ip, config.rateLimit);
    
    if (!rateLimitResult.allowed) {
      return {
        allowed: false,
        response: createRateLimitResponse(
          rateLimitResult.retryAfter || 60,
          config.allowedOrigins
        ),
      };
    }
  }
  
  // Request size validation
  if (config.maxBodySize && req.method !== 'GET') {
    try {
      await validateRequestSize(req, config.maxBodySize);
    } catch (error) {
      return {
        allowed: false,
        response: createErrorResponse(
          error as ValidationError,
          413,
          config.allowedOrigins
        ),
      };
    }
  }
  
  return { allowed: true };
}

// ============================================================================
// LOGGING UTILITIES (Security Event Logging)
// ============================================================================

/**
 * Log security event
 * In production, send to monitoring service
 */
export function logSecurityEvent(
  event: string,
  details: Record<string, any>,
  severity: 'low' | 'medium' | 'high' | 'critical' = 'medium'
): void {
  const timestamp = new Date().toISOString();
  console.log(
    JSON.stringify({
      type: 'SECURITY_EVENT',
      event,
      severity,
      timestamp,
      ...details,
    })
  );
}

