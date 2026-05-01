/**
 * Encryption Utilities for Tracking Links
 * 
 * Uses AES-256-GCM encryption to secure tracking links and prevent
 * unauthorized access by guessing order codes.
 * 
 * The encryption key should be stored in environment variable:
 * TRACKING_LINK_ENCRYPTION_KEY (32 bytes base64 encoded)
 */

/**
 * Get encryption key from environment variable
 * Falls back to a default key if not set (for development only)
 * In production, this MUST be set via environment variable
 */
function getEncryptionKey(): Uint8Array {
  const keyString = Deno.env.get('TRACKING_LINK_ENCRYPTION_KEY');
  
  if (!keyString) {
    console.warn('⚠️  TRACKING_LINK_ENCRYPTION_KEY not set. Using default key (NOT SECURE FOR PRODUCTION)');
    // Default key for development - MUST be changed in production
    const defaultKey = '01234567890123456789012345678901'; // 32 bytes
    return new TextEncoder().encode(defaultKey);
  }
  
  try {
    // Try to decode as base64 first
    const decoded = atob(keyString);
    const keyBytes = new Uint8Array(decoded.length);
    for (let i = 0; i < decoded.length; i++) {
      keyBytes[i] = decoded.charCodeAt(i);
    }
    
    // Ensure key is 32 bytes (256 bits) for AES-256
    if (keyBytes.length !== 32) {
      throw new Error('Encryption key must be exactly 32 bytes (256 bits)');
    }
    
    return keyBytes;
  } catch (error) {
    // If base64 decode fails, use the string directly (truncate/pad to 32 bytes)
    const encoder = new TextEncoder();
    const keyBytes = encoder.encode(keyString);
    
    if (keyBytes.length < 32) {
      // Pad with zeros if too short
      const padded = new Uint8Array(32);
      padded.set(keyBytes);
      return padded;
    } else if (keyBytes.length > 32) {
      // Truncate if too long
      return keyBytes.slice(0, 32);
    }
    
    return keyBytes;
  }
}

/**
 * Derive a CryptoKey from the raw key bytes
 */
async function getCryptoKey(): Promise<CryptoKey> {
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    getEncryptionKey(),
    { name: 'PBKDF2' },
    false,
    ['deriveBits', 'deriveKey']
  );
  
  // Derive a proper AES-GCM key using PBKDF2
  const salt = new TextEncoder().encode('hur-delivery-tracking-salt'); // Fixed salt for consistency
  const derivedKey = await crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: salt,
      iterations: 100000,
      hash: 'SHA-256',
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
  
  return derivedKey;
}

/**
 * Encrypt a tracking code (order code or order ID)
 * Returns a URL-safe base64 encoded string
 * 
 * @param plaintext - The order code or order ID to encrypt
 * @returns Encrypted string (URL-safe base64)
 */
export async function encryptTrackingCode(plaintext: string): Promise<string> {
  if (!plaintext || typeof plaintext !== 'string') {
    throw new Error('Plaintext must be a non-empty string');
  }
  
  try {
    const key = await getCryptoKey();
    const encoder = new TextEncoder();
    const data = encoder.encode(plaintext);
    
    // Generate a random IV (12 bytes for GCM)
    const iv = crypto.getRandomValues(new Uint8Array(12));
    
    // Encrypt the data
    const encrypted = await crypto.subtle.encrypt(
      {
        name: 'AES-GCM',
        iv: iv,
      },
      key,
      data
    );
    
    // Combine IV and encrypted data
    const combined = new Uint8Array(iv.length + encrypted.byteLength);
    combined.set(iv, 0);
    combined.set(new Uint8Array(encrypted), iv.length);
    
    // Convert to base64 and make URL-safe
    const base64 = btoa(String.fromCharCode(...combined));
    return base64
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, ''); // Remove padding for shorter URLs
  } catch (error) {
    console.error('Encryption error:', error);
    throw new Error('Failed to encrypt tracking code');
  }
}

/**
 * Decrypt a tracking code
 * 
 * @param ciphertext - The encrypted string (URL-safe base64)
 * @returns Decrypted order code or order ID
 */
export async function decryptTrackingCode(ciphertext: string): Promise<string> {
  if (!ciphertext || typeof ciphertext !== 'string') {
    throw new Error('Ciphertext must be a non-empty string');
  }
  
  try {
    const key = await getCryptoKey();
    
    // Convert from URL-safe base64 to regular base64
    let base64 = ciphertext
      .replace(/-/g, '+')
      .replace(/_/g, '/');
    
    // Add padding if needed
    while (base64.length % 4) {
      base64 += '=';
    }
    
    // Decode base64
    const binaryString = atob(base64);
    const combined = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      combined[i] = binaryString.charCodeAt(i);
    }
    
    // Extract IV (first 12 bytes) and encrypted data
    const iv = combined.slice(0, 12);
    const encrypted = combined.slice(12);
    
    // Decrypt the data
    const decrypted = await crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: iv,
      },
      key,
      encrypted
    );
    
    // Convert back to string
    const decoder = new TextDecoder();
    return decoder.decode(decrypted);
  } catch (error) {
    console.error('Decryption error:', error);
    throw new Error('Failed to decrypt tracking code. Invalid or corrupted ciphertext.');
  }
}
















