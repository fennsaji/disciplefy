/**
 * Correlation ID Utility
 *
 * Generates unique correlation IDs for request tracking and error correlation.
 * Used for logging and support to trace requests without exposing sensitive data.
 */

/**
 * Generates a unique correlation ID
 * Format: timestamp-random (e.g., 1704636800000-a1b2c3d4)
 */
export function generateCorrelationId(): string {
  const timestamp = Date.now();
  const randomPart = Math.random().toString(36).substring(2, 10);
  return `${timestamp}-${randomPart}`;
}

/**
 * Generates a short correlation ID (for compact logging)
 * Format: random string (e.g., x7y9z2w5)
 */
export function generateShortCorrelationId(): string {
  return Math.random().toString(36).substring(2, 10);
}
