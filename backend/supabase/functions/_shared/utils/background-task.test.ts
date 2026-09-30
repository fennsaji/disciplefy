// Run with: deno test background-task.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { runInBackground } from './background-task.ts'

type Global = { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }

Deno.test('runInBackground hands the task to EdgeRuntime.waitUntil when present', async () => {
  const g = globalThis as Global
  const previous = g.EdgeRuntime
  const handed: Promise<unknown>[] = []
  g.EdgeRuntime = { waitUntil: (p) => { handed.push(p) } }
  try {
    let ran = false
    runInBackground((async () => { ran = true })(), 'test')
    assertEquals(handed.length, 1)
    await handed[0]
    assertEquals(ran, true)
  } finally {
    g.EdgeRuntime = previous
  }
})

Deno.test('runInBackground swallows a failing task instead of rejecting', async () => {
  const g = globalThis as Global
  const previous = g.EdgeRuntime
  const handed: Promise<unknown>[] = []
  g.EdgeRuntime = { waitUntil: (p) => { handed.push(p) } }
  const originalError = console.error
  console.error = () => {}
  try {
    runInBackground(Promise.reject(new Error('boom')), 'test')
    // Resolves (does not throw), so no unhandled rejection escapes.
    await handed[0]
  } finally {
    console.error = originalError
    g.EdgeRuntime = previous
  }
})

Deno.test('runInBackground still runs the task without an edge runtime', async () => {
  const g = globalThis as Global
  const previous = g.EdgeRuntime
  delete g.EdgeRuntime
  try {
    let ran = false
    const task = (async () => { ran = true })()
    runInBackground(task, 'test')
    await task
    assertEquals(ran, true)
  } finally {
    g.EdgeRuntime = previous
  }
})
