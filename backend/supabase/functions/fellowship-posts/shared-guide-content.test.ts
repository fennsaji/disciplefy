// Run with: deno test --allow-read shared-guide-content.test.ts
import { assert } from 'https://deno.land/std@0.208.0/assert/mod.ts'

/**
 * A shared study guide is content on its own — the guide card the client
 * renders from study_guide_id/guide_title — so the share sheet's message
 * field is genuinely optional, matching its own "optional" label. Sharing a
 * guide with no message used to fail with a generic "Something went wrong":
 * the edge function rejected an empty `content` for every post type, and
 * even after that check is relaxed, the table's own CHECK constraint
 * (`char_length(content) >= 1`) still rejected the insert with a raw 500.
 *
 * This reads the source rather than calling the handler: reaching either
 * code path needs a live Supabase client, an authenticated fellowship
 * member, and a real study guide row, which is disproportionate to what
 * regressed here — a validation rule.
 */
const source = await Deno.readTextFile(new URL('./index.ts', import.meta.url))

Deno.test('an empty message is accepted for a shared guide post', () => {
  assert(
    source.includes('isBareSharedGuide'),
    'the required-content check must have a carve-out for shared_guide posts',
  )
})

Deno.test('every other post type still requires non-empty content', () => {
  assert(
    source.includes("if (!body.content?.trim()) throw new AppError('VALIDATION_ERROR', 'content is required', 400)"),
    'the required-content check must still exist for posts that are not a bare shared guide',
  )
})

Deno.test('the content-length check does not crash on a missing content field', () => {
  // The old check (`body.content.length > 2000`) throws a TypeError when
  // body.content is undefined, rather than the intended validation error.
  assert(
    !source.includes('if (body.content.length > 2000)'),
    'the length check must guard against a missing content field',
  )
})
