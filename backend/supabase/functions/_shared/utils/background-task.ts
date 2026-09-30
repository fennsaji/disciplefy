/**
 * Runs work after the response has been sent.
 *
 * On Supabase's edge runtime, `EdgeRuntime.waitUntil` keeps the worker alive
 * until the promise settles, so the response is not held back by the task and
 * the task is not cut off when the response goes out
 * (https://supabase.com/docs/guides/functions/background-tasks).
 * Outside that runtime (tests, plain Deno) the promise simply runs on its own.
 *
 * The task never rejects into the caller: a failure is logged by label only,
 * never with the payload, so no user input reaches the logs.
 */

interface EdgeRuntimeLike {
  waitUntil?: (promise: Promise<unknown>) => void
}

export function runInBackground(task: Promise<unknown>, label: string): void {
  const guarded = task.catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error)
    console.error(`[Background] ${label} failed:`, message)
  })

  const runtime = (globalThis as { EdgeRuntime?: EdgeRuntimeLike }).EdgeRuntime
  if (runtime && typeof runtime.waitUntil === 'function') {
    try {
      runtime.waitUntil(guarded)
    } catch (error) {
      // waitUntil can refuse once the worker is shutting down; the task is
      // already running, so it is left to finish on its own.
      console.warn(`[Background] waitUntil unavailable for ${label}:`, error instanceof Error ? error.message : error)
    }
  }
}
