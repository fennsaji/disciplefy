// Run with: deno test join-url-domain.test.ts
import { assert, assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'

/**
 * An invite's join_url used to point at app.disciplefy.in — the client-side
 * Flutter web app, which has no Open Graph tags and nothing to show someone
 * who has not installed the app. go.disciplefy.in is the server-rendered
 * landing page built for exactly that recipient, and every other
 * invite-sharing path in the app already used it — this endpoint was the one
 * inconsistency.
 *
 * The check reads the source rather than calling the handler: the handler
 * needs a live Supabase client and an authenticated fellowship mentor to
 * reach either code path, which is disproportionate to what regressed here —
 * a literal string.
 */
const source = await Deno.readTextFile(new URL('./index.ts', import.meta.url))

Deno.test('the list endpoint builds an invite URL on go.disciplefy.in', () => {
  assert(
    source.includes('join_url: `https://go.disciplefy.in/fellowship/join/${inv.token}`'),
    'join_url must use go.disciplefy.in, the landing page with an app-store fallback',
  )
})

Deno.test('the create endpoint builds an invite URL on go.disciplefy.in', () => {
  assert(
    source.includes(
      'join_url: `https://go.disciplefy.in/fellowship/join/${invite.token}`',
    ),
  )
})

Deno.test('no invite URL still points at the bare client app', () => {
  const matches = source.match(/join_url:\s*`[^`]*`/g) ?? []
  assertEquals(matches.length, 2, 'expected exactly two join_url templates')
  for (const m of matches) {
    assert(!m.includes('app.disciplefy.in'), `found app.disciplefy.in in: ${m}`)
    assert(m.includes('go.disciplefy.in'), `missing go.disciplefy.in in: ${m}`)
  }
})
