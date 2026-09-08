import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildSharePreview } from './share-preview.ts'
import { DISCIPLER_USER_ID } from './discipler.ts'

const post = {
  id: 'p1',
  fellowship_id: 'f1',
  content: 'How do I forgive someone who never apologised?',
  post_type: 'question',
  author_user_id: 'u1',
  is_deleted: false,
  created_at: '2026-09-08T00:00:00.000Z',
}

const publicFellowship = { id: 'f1', name: 'Just Us', is_public: true }
const privateFellowship = { id: 'f1', name: 'Just Us', is_public: false }

Deno.test('a private fellowship leaks nothing at all', () => {
  const preview = buildSharePreview({
    post,
    fellowship: privateFellowship,
    authorName: 'Deepa Fenn',
  })

  assertEquals(preview.is_public, false)
  // A link preview is fetched by every chat the link reaches. None of this
  // may travel with it.
  assertEquals(preview.content, undefined)
  assertEquals(preview.fellowship_name, undefined)
  assertEquals(preview.author_name, undefined)
  assertEquals(preview.post_type, undefined)
})

Deno.test('a public fellowship exposes the post for the card', () => {
  const preview = buildSharePreview({
    post,
    fellowship: publicFellowship,
    authorName: 'Deepa Fenn',
  })

  assertEquals(preview.is_public, true)
  assertEquals(preview.content, post.content)
  assertEquals(preview.fellowship_name, 'Just Us')
  assertEquals(preview.author_name, 'Deepa Fenn')
})

Deno.test('a deleted post is indistinguishable from an unknown one', () => {
  const deleted = buildSharePreview({
    post: { ...post, is_deleted: true },
    fellowship: publicFellowship,
    authorName: 'Deepa Fenn',
  })
  const unknown = buildSharePreview({ post: null, fellowship: null, authorName: '' })

  assertEquals(deleted, unknown)
  assertEquals(deleted.found, false)
})

Deno.test('a missing fellowship reveals nothing, even with a post row', () => {
  const preview = buildSharePreview({ post, fellowship: null, authorName: 'Deepa Fenn' })

  assertEquals(preview.found, false)
  assertEquals(preview.content, undefined)
})

Deno.test('the Discipler byline is used for its own posts', () => {
  const preview = buildSharePreview({
    post: { ...post, author_user_id: DISCIPLER_USER_ID },
    fellowship: publicFellowship,
    authorName: 'ignored',
  })

  assertEquals(preview.author_name, 'Discipler')
})
