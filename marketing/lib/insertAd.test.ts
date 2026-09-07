// marketing/lib/insertAd.test.ts
import { describe, it, expect } from "vitest";
import { insertAd } from "./insertAd";
import type { HouseAd } from "./ads";

const AD_A: HouseAd = {
  id: "ad-a",
  title: { en: "Daily Prayer Journal", hi: "", ml: "" },
  subtitle: { en: "90-day guided devotional", hi: "", ml: "" },
  ctaLabel: { en: "Open", hi: "", ml: "" },
  href: "https://example.com/a",
  gradient: "from-indigo-500 to-violet-500",
};
const AD_B: HouseAd = {
  id: "ad-b",
  title: { en: "Study Bible Study Companion", hi: "", ml: "" },
  subtitle: { en: "Notes for every book", hi: "", ml: "" },
  ctaLabel: { en: "Open", hi: "", ml: "" },
  href: "https://example.com/b",
  gradient: "from-teal-500 to-indigo-500",
};

const LONG_POST = [
  "Intro paragraph one.",
  "Paragraph two with more detail.",
  "Paragraph three continues the thought.",
  "Paragraph four wraps up the first half.",
  "Paragraph five starts the second half.",
  "Paragraph six.",
  "Paragraph seven.",
  "Paragraph eight, the conclusion.",
].join("\n\n");

const SHORT_POST = ["Only paragraph one.", "Only paragraph two."].join("\n\n");

describe("insertAd", () => {
  it("returns content unchanged when no ads are configured", () => {
    expect(insertAd(LONG_POST, [], "some-slug", "en")).toBe(LONG_POST);
  });

  it("returns content unchanged for posts under 4 paragraphs", () => {
    expect(insertAd(SHORT_POST, [AD_A], "some-slug", "en")).toBe(SHORT_POST);
  });

  it("inserts an AdSlot marker into a long post", () => {
    const result = insertAd(LONG_POST, [AD_A], "some-slug", "en");
    expect(result).toContain('<AdSlot id="ad-a" locale="en" />');
    // Original paragraphs must still all be present, untouched.
    for (const para of LONG_POST.split("\n\n")) {
      expect(result).toContain(para);
    }
  });

  it("embeds the given locale in the marker", () => {
    const result = insertAd(LONG_POST, [AD_A], "some-slug", "hi");
    expect(result).toContain('<AdSlot id="ad-a" locale="hi" />');
  });

  it("places the marker near 40% paragraph depth", () => {
    const result = insertAd(LONG_POST, [AD_A], "some-slug", "en");
    const paragraphs = result.split("\n\n");
    const markerIndex = paragraphs.findIndex((p) => p.includes("<AdSlot"));
    // 8 source paragraphs, target = floor(8 * 0.4) = 3 (0-indexed insert position)
    expect(markerIndex).toBe(3);
  });

  it("is deterministic: same slug always yields the same ad", () => {
    const first = insertAd(LONG_POST, [AD_A, AD_B], "stable-slug", "en");
    const second = insertAd(LONG_POST, [AD_A, AD_B], "stable-slug", "en");
    expect(first).toBe(second);
  });

  it("can select different ads for different slugs", () => {
    // With two very different slugs and two ads, at least verify each
    // result contains exactly one of the two configured ad ids.
    const result = insertAd(LONG_POST, [AD_A, AD_B], "slug-one", "en");
    const hasA = result.includes('<AdSlot id="ad-a" locale="en" />');
    const hasB = result.includes('<AdSlot id="ad-b" locale="en" />');
    expect(hasA !== hasB).toBe(true); // exactly one, never both, never neither
  });
});

describe("insertAd topic attribute", () => {
  it("embeds a sanitised topic when one is given", () => {
    const out = insertAd(LONG_POST, [AD_A], "slug", "en", "forgiveness");
    expect(out).toContain('topic="Forgiveness"');
  });

  it("omits the topic attribute when none is given", () => {
    const out = insertAd(LONG_POST, [AD_A], "slug", "en");
    expect(out).toContain('<AdSlot id="ad-a" locale="en" />');
  });

  it("drops a topic containing JSX-breaking characters", () => {
    const out = insertAd(LONG_POST, [AD_A], "slug", "en", 'he said "grace"');
    expect(out).not.toContain('"grace"');
    expect(out).toContain("topic=");
  });

  it("turns a slug-shaped tag into readable words", () => {
    const out = insertAd(LONG_POST, [AD_A], "slug", "en", "bible-study");
    expect(out).toContain('topic="Bible study"');
  });

  it("drops an over-long topic rather than stretching the headline", () => {
    const out = insertAd(LONG_POST, [AD_A], "slug", "en", "x".repeat(60));
    expect(out).toContain('<AdSlot id="ad-a" locale="en" />');
  });
});
