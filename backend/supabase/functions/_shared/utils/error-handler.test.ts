import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { AppError, ErrorHandler } from './error-handler.ts'

Deno.test('AppError details are sent as error.details in the standard envelope', async () => {
  const res = ErrorHandler.handleError(
    ErrorHandler.createAccountRequiredError('Create an account.', { reason: 'second_path' }),
    {},
    'req-1',
  )
  assertEquals(res.status, 403)
  const body = await res.json()
  assertEquals(body.success, false)
  assertEquals(body.error.code, 'ACCOUNT_REQUIRED')
  assertEquals(body.error.message, 'Create an account.')
  assertEquals(body.error.requestId, 'req-1')
  assertEquals(body.error.details, { reason: 'second_path' })
})

Deno.test('AppError without details leaves error.details out', async () => {
  const body = await ErrorHandler.handleError(new AppError('NOT_FOUND', 'x', 404), {}).json()
  assertEquals('details' in body.error, false)
})
