/** Shape returned by the fellowship-posts `/share` route. */
export interface SharePreview {
  found: boolean;
  is_public: boolean;
  fellowship_id?: string;
  fellowship_name?: string;
  post_id?: string;
  post_type?: string;
  content?: string;
  author_name?: string;
  created_at?: string;
}

const NOT_FOUND: SharePreview = { found: false, is_public: false };

/**
 * Fetches the preview for a shared post.
 *
 * The endpoint is deliberately unauthenticated and returns nothing but
 * `is_public: false` for a private fellowship, so this can be called while
 * rendering a page for a stranger. Any failure degrades to "not found" rather
 * than throwing: a link that cannot be resolved should still render a page
 * offering the app, not a 500.
 */
export async function fetchSharePreview(postId: string): Promise<SharePreview> {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!base || !key) return NOT_FOUND;

  try {
    const res = await fetch(
      `${base}/functions/v1/fellowship-posts/share?post_id=${encodeURIComponent(postId)}`,
      {
        headers: { apikey: key, Authorization: `Bearer ${key}` },
        // Previews are re-fetched by every chat app that sees the link; a
        // short cache keeps that off the database without going stale.
        next: { revalidate: 300 },
      },
    );
    if (!res.ok) return NOT_FOUND;
    const body = (await res.json()) as { data?: SharePreview };
    return body.data ?? NOT_FOUND;
  } catch {
    return NOT_FOUND;
  }
}

/** Trims post text to something that fits a link preview card. */
export function previewSnippet(content: string, max = 160): string {
  const flat = content.replace(/\s+/g, " ").trim();
  return flat.length <= max ? flat : `${flat.slice(0, max - 1).trimEnd()}…`;
}

/** One block of a shared post, classified by the marker it starts with. */
export interface PostBlock {
  kind: "topic" | "scripture" | "question" | "body";
  text: string;
}

const MARKERS: ReadonlyArray<[RegExp, PostBlock["kind"]]> = [
  [/^📖\s*/, "topic"],
  [/^✝️?\s*/, "scripture"],
  [/^💬\s*/, "question"],
];

/**
 * Splits a post into its blocks, keeping the shape the author gave it.
 *
 * Posts written by Discipler follow a loose convention — a 📖 topic line, a
 * hook, the body, a ✝️ reference and a 💬 question — and the app renders those
 * distinctly. Collapsing the whitespace for the page turned all of it into one
 * run-on paragraph, so the structure is preserved here and only the Open Graph
 * description gets the flattened form.
 *
 * The post is rendered whole: someone arriving from a shared link came to read
 * it, and cutting the question off the end left the page ending mid-thought.
 * `max` only guards against a pathological post; it is not an excerpt length.
 */
export function postBlocks(content: string, max = 20000): PostBlock[] {
  const trimmed = content.length <= max
    ? content
    : `${content.slice(0, max - 1).trimEnd()}…`;

  return trimmed
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter(Boolean)
    .map((block) => {
      for (const [marker, kind] of MARKERS) {
        if (marker.test(block)) {
          return { kind, text: block.replace(marker, "").trim() };
        }
      }
      // A leading ✨ marks the hook, which reads as ordinary lead text.
      return { kind: "body" as const, text: block.replace(/^✨\s*/, "").trim() };
    });
}
