import { DISCIPLER_USER_ID } from './discipler.ts'

/** What the link landing page needs to render a post's Open Graph card. */
export interface SharePreview {
  found: boolean
  is_public: boolean
  fellowship_id?: string
  fellowship_name?: string
  post_id?: string
  post_type?: string
  content?: string
  author_name?: string
  created_at?: string
}

/**
 * Decides what a shared link may reveal about a post, with no I/O so the rule
 * is unit-testable.
 *
 * Only a public fellowship exposes content. A private one yields
 * `is_public: false` and nothing else — not the fellowship's name, not the
 * author, not a single character of the post. Link previews are fetched by
 * WhatsApp and every chat the link is forwarded into, so anything returned
 * here should be considered published to strangers.
 *
 * A missing or deleted post returns the same shape as an unknown id, so the
 * endpoint cannot be used to discover which posts exist.
 */
export function buildSharePreview(args: {
  post: {
    id: string
    fellowship_id: string
    content: string
    post_type: string
    author_user_id: string
    is_deleted: boolean
    created_at: string
  } | null
  fellowship: { id: string; name: string; is_public: boolean } | null
  authorName: string
}): SharePreview {
  const { post, fellowship, authorName } = args
  if (!post || post.is_deleted || !fellowship) {
    return { found: false, is_public: false }
  }
  if (!fellowship.is_public) {
    return { found: true, is_public: false, fellowship_id: fellowship.id }
  }
  return {
    found: true,
    is_public: true,
    fellowship_id: fellowship.id,
    fellowship_name: fellowship.name,
    post_id: post.id,
    post_type: post.post_type,
    content: post.content,
    author_name: post.author_user_id === DISCIPLER_USER_ID ? 'Discipler' : authorName,
    created_at: post.created_at,
  }
}
