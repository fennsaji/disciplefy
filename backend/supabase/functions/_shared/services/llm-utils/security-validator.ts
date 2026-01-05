/**
 * LLM Security Validator
 *
 * Validates user inputs for security threats including:
 * - Prompt injection attempts
 * - Jailbreak attempts
 * - Inappropriate content
 * - Input length violations
 *
 * Implements security guidelines from LLM Development Guide.
 */

export interface SecurityValidationResult {
  isValid: boolean
  violations: SecurityViolation[]
  riskScore: number
}

export interface SecurityViolation {
  type: SecurityViolationType
  pattern: string
  severity: 'low' | 'medium' | 'high' | 'critical'
  description: string
}

export type SecurityViolationType =
  | 'prompt_injection'
  | 'jailbreak_attempt'
  | 'instruction_override'
  | 'system_prompt_access'
  | 'excessive_length'
  | 'special_character_attack'
  | 'inappropriate_content'

const MAX_INPUT_LENGTH = 10000 // 10k characters max

/**
 * Prompt injection patterns that attempt to override system instructions
 */
const PROMPT_INJECTION_PATTERNS = [
  {
    pattern: /ignore\s+(all\s+)?(previous|prior|earlier)\s+instructions/i,
    type: 'prompt_injection' as SecurityViolationType,
    severity: 'critical' as const,
    description: 'Attempt to ignore previous instructions'
  },
  {
    pattern: /forget\s+(all\s+)?(previous|prior|earlier)\s+(instructions|prompts)/i,
    type: 'prompt_injection' as SecurityViolationType,
    severity: 'critical' as const,
    description: 'Attempt to forget previous instructions'
  },
  {
    pattern: /disregard\s+(all\s+)?(previous|prior|earlier)\s+instructions/i,
    type: 'prompt_injection' as SecurityViolationType,
    severity: 'critical' as const,
    description: 'Attempt to disregard instructions'
  },
  {
    pattern: /override\s+(system|previous)\s+(prompt|instructions)/i,
    type: 'instruction_override' as SecurityViolationType,
    severity: 'critical' as const,
    description: 'Attempt to override system instructions'
  }
]

/**
 * System prompt access attempts
 */
const SYSTEM_PROMPT_PATTERNS = [
  {
    pattern: /show\s+(me\s+)?(your\s+)?(system\s+)?(prompt|instructions)/i,
    type: 'system_prompt_access' as SecurityViolationType,
    severity: 'high' as const,
    description: 'Attempt to access system prompt'
  },
  {
    pattern: /reveal\s+(your\s+)?(system\s+)?(prompt|instructions)/i,
    type: 'system_prompt_access' as SecurityViolationType,
    severity: 'high' as const,
    description: 'Attempt to reveal system instructions'
  },
  {
    pattern: /what\s+(is|are)\s+(your\s+)?(system\s+)?(prompt|instructions)/i,
    type: 'system_prompt_access' as SecurityViolationType,
    severity: 'high' as const,
    description: 'Attempt to query system prompt'
  }
]

/**
 * Jailbreak attempts using special tags or formatting
 */
const JAILBREAK_PATTERNS = [
  {
    pattern: /jailbreak/i,
    type: 'jailbreak_attempt' as SecurityViolationType,
    severity: 'critical' as const,
    description: 'Explicit jailbreak attempt'
  },
  {
    pattern: /\[INST\]|\[\/INST\]/i,
    type: 'jailbreak_attempt' as SecurityViolationType,
    severity: 'high' as const,
    description: 'Llama/Mistral instruction tag injection'
  },
  {
    pattern: /<\|.*?\|>/g,
    type: 'jailbreak_attempt' as SecurityViolationType,
    severity: 'high' as const,
    description: 'ChatML tag injection'
  },
  {
    pattern: /\{\{.*?\}\}/g,
    type: 'jailbreak_attempt' as SecurityViolationType,
    severity: 'medium' as const,
    description: 'Template injection attempt'
  },
  {
    pattern: /act\s+as\s+if\s+you\s+(are|were)/i,
    type: 'jailbreak_attempt' as SecurityViolationType,
    severity: 'high' as const,
    description: 'Role override attempt'
  },
  {
    pattern: /pretend\s+(you\s+)?(are|to\s+be)/i,
    type: 'jailbreak_attempt' as SecurityViolationType,
    severity: 'high' as const,
    description: 'Role impersonation attempt'
  }
]

/**
 * Special character attack patterns
 */
const SPECIAL_CHAR_PATTERNS = [
  {
    pattern: /\n{10,}/,
    type: 'special_character_attack' as SecurityViolationType,
    severity: 'medium' as const,
    description: 'Excessive newlines (context overflow attempt)'
  },
  {
    pattern: /[\x00-\x08\x0B\x0C\x0E-\x1F]/,
    type: 'special_character_attack' as SecurityViolationType,
    severity: 'medium' as const,
    description: 'Control characters detected'
  }
]

/**
 * All security patterns combined
 */
const ALL_PATTERNS = [
  ...PROMPT_INJECTION_PATTERNS,
  ...SYSTEM_PROMPT_PATTERNS,
  ...JAILBREAK_PATTERNS,
  ...SPECIAL_CHAR_PATTERNS
]

/**
 * Validates user input for security threats
 */
export function validateInputSecurity(input: string): SecurityValidationResult {
  const violations: SecurityViolation[] = []

  // Check input length
  if (input.length > MAX_INPUT_LENGTH) {
    violations.push({
      type: 'excessive_length',
      pattern: `Length: ${input.length} > ${MAX_INPUT_LENGTH}`,
      severity: 'high',
      description: `Input exceeds maximum length (${input.length} > ${MAX_INPUT_LENGTH})`
    })
  }

  // Check all security patterns
  for (const { pattern, type, severity, description } of ALL_PATTERNS) {
    if (pattern.test(input)) {
      violations.push({
        type,
        pattern: pattern.toString(),
        severity,
        description
      })
    }
  }

  // Calculate risk score (0-1 scale)
  const riskScore = calculateRiskScore(violations)

  return {
    isValid: violations.length === 0,
    violations,
    riskScore
  }
}

/**
 * Calculate risk score based on violations
 * Returns 0-1 scale where:
 * - 0.0-0.2: Low risk
 * - 0.2-0.5: Medium risk
 * - 0.5-0.8: High risk
 * - 0.8-1.0: Critical risk
 */
function calculateRiskScore(violations: SecurityViolation[]): number {
  if (violations.length === 0) return 0

  const severityWeights = {
    low: 0.1,
    medium: 0.3,
    high: 0.6,
    critical: 1.0
  }

  const totalWeight = violations.reduce(
    (sum, v) => sum + severityWeights[v.severity],
    0
  )

  // Normalize to 0-1 scale
  const maxPossibleWeight = violations.length * 1.0 // All critical
  return Math.min(totalWeight / maxPossibleWeight, 1.0)
}

/**
 * Sanitizes user input by removing/escaping dangerous characters
 */
export function sanitizeInput(input: string): string {
  // Trim excessive whitespace
  let sanitized = input.trim()

  // Limit consecutive newlines to 2
  sanitized = sanitized.replace(/\n{3,}/g, '\n\n')

  // Remove control characters
  sanitized = sanitized.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '')

  // Truncate to max length
  if (sanitized.length > MAX_INPUT_LENGTH) {
    sanitized = sanitized.substring(0, MAX_INPUT_LENGTH)
  }

  return sanitized
}

/**
 * Determines action to take based on risk score
 */
export function determineAction(riskScore: number): string {
  if (riskScore >= 0.8) return 'blocked'
  if (riskScore >= 0.5) return 'flagged_high'
  if (riskScore >= 0.2) return 'flagged_medium'
  return 'allowed'
}
