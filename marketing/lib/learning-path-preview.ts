/** Shape returned by the learning-paths detail endpoint, trimmed to what a preview needs. */
export interface LearningPathPreview {
  found: boolean;
  title?: string;
  description?: string;
  disciple_level?: string;
  topics_count?: number;
}

const NOT_FOUND: LearningPathPreview = { found: false };

/**
 * Fetches the preview for a shared learning path.
 *
 * Learning paths are curated public content — unlike a fellowship post, there
 * is no private variant to guard against, so this can always show the real
 * title and description. The endpoint accepts anonymous callers already (the
 * app lets guests browse paths before signing in), so no service key or
 * auth header is needed here beyond the anon key the Data API requires.
 */
export async function fetchLearningPathPreview(
  pathId: string,
): Promise<LearningPathPreview> {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!base || !key) return NOT_FOUND;

  try {
    const res = await fetch(
      `${base}/functions/v1/learning-paths?pathId=${encodeURIComponent(pathId)}`,
      {
        headers: { apikey: key, Authorization: `Bearer ${key}` },
        // Re-fetched by every chat app that sees the link; a short cache
        // keeps that off the database without going stale.
        next: { revalidate: 300 },
      },
    );
    if (!res.ok) return NOT_FOUND;
    const body = (await res.json()) as {
      success?: boolean;
      data?: {
        title?: string;
        description?: string;
        disciple_level?: string;
        topics_count?: number;
      };
    };
    if (!body.success || !body.data) return NOT_FOUND;
    return { found: true, ...body.data };
  } catch {
    return NOT_FOUND;
  }
}
