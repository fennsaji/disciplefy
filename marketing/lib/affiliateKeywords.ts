// marketing/lib/affiliateKeywords.ts
// Fetches admin-curated affiliate keywords from Supabase REST. RLS restricts
// the anon key to is_active = true rows. Cached 5 min (keyword edits are
// low-urgency). On any failure returns [] — blog posts render without
// affiliate links rather than erroring.
//
// The timeout is load-bearing. Affiliate links are decoration on a blog post,
// but this call sits in that page's render path, so a Supabase that accepts a
// connection and then never answers would block the post indefinitely — the
// catch below only ever saw errors, never a hang. Observed: with Supabase
// unreachable, every blog post stopped responding while the post list, which
// does not call this, kept serving.
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export async function getActiveAffiliateKeywords(): Promise<string[]> {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return [];
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/affiliate_keywords?select=keyword&is_active=eq.true&limit=50`,
      {
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
        },
        next: { revalidate: 300 },
        signal: AbortSignal.timeout(3000),
      },
    );
    if (!res.ok) return [];
    const rows: { keyword: string }[] = await res.json();
    return rows.map((r) => r.keyword);
  } catch (err) {
    console.error("Failed to fetch affiliate keywords:", err);
    return [];
  }
}
