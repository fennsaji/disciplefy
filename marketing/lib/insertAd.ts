// marketing/lib/insertAd.ts
import type { HouseAd } from "./ads";

// Deterministic string hash (djb2) — used only to pick a stable ad per
// slug, not for any security purpose.
function hashSlug(slug: string): number {
  let hash = 5381;
  for (let i = 0; i < slug.length; i++) {
    hash = (hash * 33) ^ slug.charCodeAt(i);
  }
  return Math.abs(hash);
}

// Splices an `<AdSlot id="..." />` marker into markdown at ~40% paragraph
// depth. No-op when there are no ads configured or the post is too short
// to interrupt. Selection is deterministic per slug so ISR revalidations
// never flicker between different ads on the same post.
// `locale` is embedded as-is into the marker attribute (AdSlot resolves it
// defensively at render time) — not typed to AdLocale since callers may
// pass through an arbitrary post/route locale string.
// `topic` is the post's own subject (its first tag). It is embedded in the
// marker so the card can lead with what the reader is already reading about.
// Sanitised hard: MDX attributes are parsed as JSX, so a stray quote, angle
// bracket or newline would break the whole post body, not just the ad.
function sanitizeTopic(topic?: string): string {
  if (!topic) return "";
  const cleaned = topic
    // Tags arrive slug-shaped ("bible-study"), which reads wrong inside a
    // sentence, so hyphens and underscores become spaces.
    .replace(/[-_]+/g, " ")
    .replace(/[<>"'{}\n\r]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!cleaned || cleaned.length > 40) return "";
  return cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
}

export function insertAd(
  content: string,
  ads: HouseAd[],
  slug: string,
  locale: string,
  topic?: string,
): string {
  if (ads.length === 0) return content;

  const paragraphs = content.split("\n\n");
  if (paragraphs.length < 4) return content;

  const targetIndex = Math.floor(paragraphs.length * 0.4);
  const ad = ads[hashSlug(slug) % ads.length];
  const safeTopic = sanitizeTopic(topic);
  const marker = safeTopic
    ? `<AdSlot id="${ad.id}" locale="${locale}" topic="${safeTopic}" />`
    : `<AdSlot id="${ad.id}" locale="${locale}" />`;

  return [
    ...paragraphs.slice(0, targetIndex),
    marker,
    ...paragraphs.slice(targetIndex),
  ].join("\n\n");
}
