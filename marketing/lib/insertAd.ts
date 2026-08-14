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
export function insertAd(content: string, ads: HouseAd[], slug: string): string {
  if (ads.length === 0) return content;

  const paragraphs = content.split("\n\n");
  if (paragraphs.length < 4) return content;

  const targetIndex = Math.floor(paragraphs.length * 0.4);
  const ad = ads[hashSlug(slug) % ads.length];
  const marker = `<AdSlot id="${ad.id}" />`;

  return [
    ...paragraphs.slice(0, targetIndex),
    marker,
    ...paragraphs.slice(targetIndex),
  ].join("\n\n");
}
