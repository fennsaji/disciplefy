import { AppError } from './error-handler.ts'

/**
 * Validation result structure.
 */
interface ValidationResult {
  readonly isValid: boolean
  readonly errors: readonly string[]
}

/**
 * Configuration for validation rules.
 */
interface ValidationConfig {
  readonly required?: boolean
  readonly minLength?: number
  readonly maxLength?: number
  readonly pattern?: RegExp
  readonly allowedValues?: readonly string[]
  readonly customValidator?: (value: any) => string | null
}

/**
 * Request validation utilities for Edge Functions.
 * 
 * Provides a centralized way to validate request parameters and data
 * following clean code principles and consistent error handling.
 */
export class RequestValidator {

  /**
   * Validates a single field against the provided configuration.
   * 
   * @param fieldName - Name of the field being validated
   * @param value - Value to validate
   * @param config - Validation configuration
   * @returns Validation result with errors if any
   */
  static validateField(
    fieldName: string, 
    value: any, 
    config: ValidationConfig
  ): ValidationResult {
    const errors: string[] = []

    // Check if field is required
    if (config.required && (value === null || value === undefined || value === '')) {
      errors.push(`${fieldName} is required`)
      return { isValid: false, errors }
    }

    // Skip further validation if value is empty and not required
    if (!config.required && (value === null || value === undefined || value === '')) {
      return { isValid: true, errors: [] }
    }

    // Convert to string for length and pattern validation
    const stringValue = String(value)

    // Validate minimum length
    if (config.minLength !== undefined && stringValue.length < config.minLength) {
      errors.push(`${fieldName} must be at least ${config.minLength} characters long`)
    }

    // Validate maximum length
    if (config.maxLength !== undefined && stringValue.length > config.maxLength) {
      errors.push(`${fieldName} must be no more than ${config.maxLength} characters long`)
    }

    // Validate pattern
    if (config.pattern && !config.pattern.test(stringValue)) {
      errors.push(`${fieldName} format is invalid`)
    }

    // Validate allowed values
    if (config.allowedValues && !config.allowedValues.includes(stringValue)) {
      errors.push(`${fieldName} must be one of: ${config.allowedValues.join(', ')}`)
    }

    // Custom validation
    if (config.customValidator) {
      const customError = config.customValidator(value)
      if (customError) {
        errors.push(customError)
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    }
  }

  /**
   * Validates multiple fields at once.
   * 
   * @param data - Object containing field values
   * @param rules - Object containing validation rules for each field
   * @returns Combined validation result
   */
  static validateFields(
    data: Record<string, any>, 
    rules: Record<string, ValidationConfig>
  ): ValidationResult {
    const allErrors: string[] = []

    for (const [fieldName, config] of Object.entries(rules)) {
      const fieldValue = data[fieldName]
      const result = this.validateField(fieldName, fieldValue, config)
      
      if (!result.isValid) {
        allErrors.push(...result.errors)
      }
    }

    return {
      isValid: allErrors.length === 0,
      errors: allErrors
    }
  }

  /**
   * Validates and sanitizes query parameters.
   * 
   * @param searchParams - URLSearchParams object
   * @param rules - Validation rules for parameters
   * @returns Validated and typed parameters
   * @throws {AppError} When validation fails
   */
  static validateQueryParams(
    searchParams: URLSearchParams,
    rules: Record<string, ValidationConfig>
  ): Record<string, any> {
    const data: Record<string, any> = {}

    // Extract parameters
    for (const [key] of Object.entries(rules)) {
      data[key] = searchParams.get(key)
    }

    // Validate parameters
    const result = this.validateFields(data, rules)

    if (!result.isValid) {
      throw new AppError(
        'VALIDATION_ERROR',
        `Invalid parameters: ${result.errors.join(', ')}`,
        400
      )
    }

    return data
  }

  /**
   * Validates JSON request body.
   * 
   * @param body - Request body object
   * @param rules - Validation rules for body fields
   * @returns Validated body data
   * @throws {AppError} When validation fails
   */
  static validateRequestBody(
    body: Record<string, any>,
    rules: Record<string, ValidationConfig>
  ): Record<string, any> {
    const result = this.validateFields(body, rules)

    if (!result.isValid) {
      throw new AppError(
        'VALIDATION_ERROR',
        `Invalid request body: ${result.errors.join(', ')}`,
        400
      )
    }

    return body
  }

  /**
   * Validates HTTP method against allowed methods.
   * 
   * @param method - HTTP method from request
   * @param allowedMethods - Array of allowed methods
   * @throws {AppError} When method is not allowed
   */
  static validateHttpMethod(method: string, allowedMethods: readonly string[]): void {
    if (!allowedMethods.includes(method)) {
      throw new AppError(
        'METHOD_NOT_ALLOWED',
        `Method ${method} not allowed. Allowed methods: ${allowedMethods.join(', ')}`,
        405
      )
    }
  }


  /**
   * Validates numeric parameters with range checking.
   * 
   * @param value - Value to validate
   * @param fieldName - Name of the field
   * @param min - Minimum allowed value (inclusive)
   * @param max - Maximum allowed value (inclusive)
   * @returns Validated numeric value
   * @throws {AppError} When validation fails
   */
  static validateNumericRange(
    value: string | number, 
    fieldName: string, 
    min?: number, 
    max?: number
  ): number {
    const numericValue = typeof value === 'number' ? value : parseInt(String(value))

    if (isNaN(numericValue)) {
      throw new AppError(
        'VALIDATION_ERROR',
        `${fieldName} must be a valid number`,
        400
      )
    }

    if (min !== undefined && numericValue < min) {
      throw new AppError(
        'VALIDATION_ERROR',
        `${fieldName} must be at least ${min}`,
        400
      )
    }

    if (max !== undefined && numericValue > max) {
      throw new AppError(
        'VALIDATION_ERROR',
        `${fieldName} must be no more than ${max}`,
        400
      )
    }

    return numericValue
  }

  /**
   * Validates and parses pagination parameters.
   * 
   * @param searchParams - URL search parameters
   * @param defaultLimit - Default limit value
   * @param maxLimit - Maximum allowed limit
   * @returns Validated pagination parameters
   */
  static validatePaginationParams(
    searchParams: URLSearchParams,
    defaultLimit = 20,
    maxLimit = 100
  ): { limit: number; offset: number } {
    const limitParam = searchParams.get('limit')
    const offsetParam = searchParams.get('offset')

    const limit = limitParam ? 
      this.validateNumericRange(limitParam, 'limit', 1, maxLimit) : 
      defaultLimit

    const offset = offsetParam ? 
      this.validateNumericRange(offsetParam, 'offset', 0) : 
      0

    return { limit, offset }
  }
}