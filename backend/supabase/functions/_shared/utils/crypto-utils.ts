/**
 * Crypto Utilities for Deno
 *
 * Provides cryptographic functions using Web Crypto API
 * Compatible with Deno's security model
 */

/**
 * Generate HMAC SHA-256 signature
 *
 * @param secret - Secret key for HMAC
 * @param data - Data to sign
 * @returns Hex-encoded signature
 */
export async function generateHmacSha256(secret: string, data: string): Promise<string> {
  // Convert secret and data to Uint8Array
  const encoder = new TextEncoder()
  const keyData = encoder.encode(secret)
  const messageData = encoder.encode(data)

  // Import the key
  const key = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )

  // Sign the data
  const signature = await crypto.subtle.sign('HMAC', key, messageData)

  // Convert to hex string
  return Array.from(new Uint8Array(signature))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

/**
 * Verify HMAC SHA-256 signature (constant-time comparison)
 *
 * @param secret - Secret key for HMAC
 * @param data - Data that was signed
 * @param expectedSignature - Signature to verify against
 * @returns true if signature is valid
 */
export async function verifyHmacSha256(
  secret: string,
  data: string,
  expectedSignature: string
): Promise<boolean> {
  const actualSignature = await generateHmacSha256(secret, data)

  // Constant-time comparison to prevent timing attacks
  if (actualSignature.length !== expectedSignature.length) {
    return false
  }

  let result = 0
  for (let i = 0; i < actualSignature.length; i++) {
    result |= actualSignature.charCodeAt(i) ^ expectedSignature.charCodeAt(i)
  }

  return result === 0
}
