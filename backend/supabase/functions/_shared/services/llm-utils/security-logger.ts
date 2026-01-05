/**
 * LLM Security Event Logger
 *
 * Logs security events to the llm_security_events table.
 * Implements privacy-preserving logging per LLM Development Guide.
 *
 * NEVER LOGS:
 * - Raw user input content
 * - Personal prayer requests
 * - LLM response content
 * - Any personally identifiable information
 *
 * SAFE TO LOG:
 * - Event type and timestamp
 * - Risk scores
 * - Violation patterns (without actual content)
 * - IP addresses and session IDs
 * - Action taken
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import type { SecurityValidationResult, SecurityViolation } from './security-validator.ts'

export interface SecurityEventData {
  userId?: string
  sessionId?: string
  ipAddress?: string
  eventType: string
  inputText?: string  // Only metadata, never full content
  riskScore: number
  actionTaken: string
  detectionDetails: {
    violations: SecurityViolation[]
    timestamp: string
    inputLength?: number
  }
}

/**
 * Logs a security event to the database
 */
export async function logSecurityEvent(
  supabaseClient: SupabaseClient,
  eventData: SecurityEventData
): Promise<void> {
  try {
    const { error } = await supabaseClient
      .from('llm_security_events')
      .insert({
        user_id: eventData.userId || null,
        session_id: eventData.sessionId || null,
        ip_address: eventData.ipAddress || null,
        event_type: eventData.eventType,
        input_text: eventData.inputText || null, // Only metadata
        risk_score: eventData.riskScore,
        action_taken: eventData.actionTaken,
        detection_details: eventData.detectionDetails,
        created_at: new Date().toISOString()
      })

    if (error) {
      console.error('[Security Logger] Failed to log security event:', error)
      // Don't throw - logging failures should not break the application
    } else {
      console.log(`[Security Logger] Logged ${eventData.eventType} event (risk: ${eventData.riskScore.toFixed(2)})`)
    }
  } catch (error) {
    console.error('[Security Logger] Exception while logging security event:', error)
    // Don't throw - logging failures should not break the application
  }
}

/**
 * Logs a prompt injection attempt
 */
export async function logPromptInjectionAttempt(
  supabaseClient: SupabaseClient,
  validation: SecurityValidationResult,
  metadata: {
    userId?: string
    sessionId?: string
    ipAddress?: string
    inputLength: number
    actionTaken: string
  }
): Promise<void> {
  await logSecurityEvent(supabaseClient, {
    userId: metadata.userId,
    sessionId: metadata.sessionId,
    ipAddress: metadata.ipAddress,
    eventType: 'prompt_injection_attempt',
    inputText: `Input length: ${metadata.inputLength} chars`, // Privacy-safe metadata
    riskScore: validation.riskScore,
    actionTaken: metadata.actionTaken,
    detectionDetails: {
      violations: validation.violations,
      timestamp: new Date().toISOString(),
      inputLength: metadata.inputLength
    }
  })
}

/**
 * Logs a jailbreak attempt
 */
export async function logJailbreakAttempt(
  supabaseClient: SupabaseClient,
  validation: SecurityValidationResult,
  metadata: {
    userId?: string
    sessionId?: string
    ipAddress?: string
    inputLength: number
    actionTaken: string
  }
): Promise<void> {
  await logSecurityEvent(supabaseClient, {
    userId: metadata.userId,
    sessionId: metadata.sessionId,
    ipAddress: metadata.ipAddress,
    eventType: 'jailbreak_attempt',
    inputText: `Input length: ${metadata.inputLength} chars`,
    riskScore: validation.riskScore,
    actionTaken: metadata.actionTaken,
    detectionDetails: {
      violations: validation.violations,
      timestamp: new Date().toISOString(),
      inputLength: metadata.inputLength
    }
  })
}

/**
 * Logs input validation failure
 */
export async function logInputValidationFailure(
  supabaseClient: SupabaseClient,
  validation: SecurityValidationResult,
  metadata: {
    userId?: string
    sessionId?: string
    ipAddress?: string
    inputLength: number
    actionTaken: string
  }
): Promise<void> {
  await logSecurityEvent(supabaseClient, {
    userId: metadata.userId,
    sessionId: metadata.sessionId,
    ipAddress: metadata.ipAddress,
    eventType: 'input_validation_failure',
    inputText: `Input length: ${metadata.inputLength} chars`,
    riskScore: validation.riskScore,
    actionTaken: metadata.actionTaken,
    detectionDetails: {
      violations: validation.violations,
      timestamp: new Date().toISOString(),
      inputLength: metadata.inputLength
    }
  })
}

/**
 * Logs rate limit abuse
 */
export async function logRateLimitAbuse(
  supabaseClient: SupabaseClient,
  metadata: {
    userId?: string
    sessionId?: string
    ipAddress?: string
    requestCount: number
    timeWindow: string
    actionTaken: string
  }
): Promise<void> {
  await logSecurityEvent(supabaseClient, {
    userId: metadata.userId,
    sessionId: metadata.sessionId,
    ipAddress: metadata.ipAddress,
    eventType: 'rate_limit_abuse',
    inputText: undefined,
    riskScore: 0.5, // Medium risk for rate limit violations
    actionTaken: metadata.actionTaken,
    detectionDetails: {
      violations: [{
        type: 'rate_limit_exceeded',
        pattern: `${metadata.requestCount} requests in ${metadata.timeWindow}`,
        severity: 'medium' as const,
        description: 'Excessive requests in short time window'
      }],
      timestamp: new Date().toISOString(),
      inputLength: 0
    }
  })
}

/**
 * Logs content policy violation
 */
export async function logContentPolicyViolation(
  supabaseClient: SupabaseClient,
  metadata: {
    userId?: string
    sessionId?: string
    ipAddress?: string
    violationType: string
    actionTaken: string
  }
): Promise<void> {
  await logSecurityEvent(supabaseClient, {
    userId: metadata.userId,
    sessionId: metadata.sessionId,
    ipAddress: metadata.ipAddress,
    eventType: 'content_policy_violation',
    inputText: undefined,
    riskScore: 0.7, // High risk for policy violations
    actionTaken: metadata.actionTaken,
    detectionDetails: {
      violations: [{
        type: 'inappropriate_content',
        pattern: metadata.violationType,
        severity: 'high' as const,
        description: 'Content policy violation detected'
      }],
      timestamp: new Date().toISOString()
    }
  })
}
