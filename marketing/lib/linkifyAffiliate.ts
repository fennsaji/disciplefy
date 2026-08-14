// Wraps the first occurrence of admin-curated keywords in Amazon.in
// affiliate search links. Pure — no I/O; keywords come from the caller
// (fetched from Supabase in lib/affiliateKeywords.ts).

export const AFFILIATE_TAG = "disciplefy-21";
export const MAX_AFFILIATE_LINKS_PER_POST = 3;

const affiliateUrl = (keyword: string) =>
  `https://www.amazon.in/s?k=${encodeURIComponent(keyword)}&tag=${AFFILIATE_TAG}`;

const escapeRegExp = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// A line is eligible for linkification unless it's a heading, blockquote,
// or inside a code fence. Inline code and existing links are excluded per
// match via the regex below.
function isProseLine(line: string, inFence: boolean): boolean {
  if (inFence) return false;
  const trimmed = line.trimStart();
  return !trimmed.startsWith("#") && !trimmed.startsWith(">");
}

export function linkifyAffiliate(
  content: string,
  keywords: string[],
): { content: string; linkCount: number } {
  if (keywords.length === 0) return { content, linkCount: 0 };

  // Longest first so "ESV Study Bible" wins over "study Bible".
  const ordered = [...keywords].sort((a, b) => b.length - a.length);
  const linked = new Set<string>(); // lowercased keywords already linked
  let linkCount = 0;
  let inFence = false;

  const lines = content.split("\n").map((line) => {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      return line;
    }
    if (!isProseLine(line, inFence) || linkCount >= MAX_AFFILIATE_LINKS_PER_POST) {
      return line;
    }

    let out = line;
    for (const keyword of ordered) {
      if (linkCount >= MAX_AFFILIATE_LINKS_PER_POST) break;
      const lower = keyword.toLowerCase();
      if (linked.has(lower)) continue;

      // Word-boundary, case-insensitive; skip matches inside inline code
      // (`...`) or markdown links ([...](...)) by rejecting matches whose
      // surrounding context is a code span or link syntax.
      const re = new RegExp(`\\b${escapeRegExp(keyword)}\\b`, "i");
      const m = re.exec(out);
      if (!m) continue;

      const start = m.index;
      const before = out.slice(0, start);
      const matched = m[0];

      // Inside inline code: odd number of backticks before the match.
      const backticks = (before.match(/`/g) ?? []).length;
      if (backticks % 2 === 1) continue;

      // Inside an existing link label or URL: an unclosed "[" not yet
      // closed by "]" before the match means we're inside the label; and
      // if we're past "](" without a closing ")" yet, we're inside the URL.
      const openBracket = before.lastIndexOf("[");
      const closeBracket = before.lastIndexOf("]");
      if (openBracket !== -1 && openBracket > closeBracket) continue;
      const openParenAfterBracket = before.lastIndexOf("](");
      const closeParen = before.lastIndexOf(")");
      if (openParenAfterBracket !== -1 && openParenAfterBracket > closeParen) continue;

      out =
        before +
        `[${matched}](${affiliateUrl(keyword)})` +
        out.slice(start + matched.length);
      linked.add(lower);
      linkCount++;
    }
    return out;
  });

  return { content: lines.join("\n"), linkCount };
}
