import { describe, it, expect } from "vitest";
import { linkifyAffiliate, AFFILIATE_TAG } from "./linkifyAffiliate";

const url = (kw: string) =>
  `https://www.amazon.in/s?k=${encodeURIComponent(kw)}&tag=${AFFILIATE_TAG}`;

describe("linkifyAffiliate", () => {
  it("no-ops with an empty keyword list", () => {
    const content = "Read your study Bible daily.";
    expect(linkifyAffiliate(content, [])).toEqual({ content, linkCount: 0 });
  });

  it("links the first occurrence only, preserving original casing", () => {
    const content = "A Study Bible helps.\n\nEvery study Bible differs.";
    const { content: out, linkCount } = linkifyAffiliate(content, ["study Bible"]);
    expect(linkCount).toBe(1);
    expect(out).toContain(`[Study Bible](${url("study Bible")})`);
    // second occurrence untouched
    expect(out).toContain("Every study Bible differs.");
  });

  it("matches case-insensitively on word boundaries only", () => {
    const { content: out, linkCount } = linkifyAffiliate(
      "The wordstudy Biblesuffix should not match.",
      ["study Bible"],
    );
    expect(linkCount).toBe(0);
    expect(out).toBe("The wordstudy Biblesuffix should not match.");
  });

  it("prefers the longest keyword when keywords overlap", () => {
    const { content: out } = linkifyAffiliate(
      "Get the ESV Study Bible today.",
      ["study Bible", "ESV Study Bible"],
    );
    expect(out).toContain(`[ESV Study Bible](${url("ESV Study Bible")})`);
    expect(out).not.toContain(`[study Bible]`);
  });

  it("caps at 3 links per post", () => {
    const content = "prayer journal one.\n\nBible commentary two.\n\nstudy Bible three.\n\nChristian devotional four.";
    const { linkCount } = linkifyAffiliate(content, [
      "prayer journal",
      "Bible commentary",
      "study Bible",
      "Christian devotional",
    ]);
    expect(linkCount).toBe(3);
  });

  it("skips headings, code fences, inline code, blockquotes and existing links", () => {
    const content = [
      "# The study Bible heading",
      "",
      "> A study Bible quote line.",
      "",
      "```",
      "study Bible in code fence",
      "```",
      "",
      "Inline `study Bible` code.",
      "",
      "[study Bible](https://example.com) already linked.",
      "",
      "Finally a real study Bible mention.",
    ].join("\n");
    const { content: out, linkCount } = linkifyAffiliate(content, ["study Bible"]);
    expect(linkCount).toBe(1);
    expect(out).toContain(`[study Bible](${url("study Bible")})`);
    expect(out).toContain("# The study Bible heading");
    expect(out).toContain("> A study Bible quote line.");
    expect(out).toContain("[study Bible](https://example.com) already linked.");
  });

  it("never touches an existing <AdSlot /> marker line, even when the keyword appears elsewhere in prose", () => {
    const content = [
      "A study Bible helps you dig deeper.",
      "",
      '<AdSlot id="study Bible" />',
      "",
      "More text here.",
    ].join("\n\n");
    const { content: out, linkCount } = linkifyAffiliate(content, ["study Bible"]);
    expect(linkCount).toBe(1);
    expect(out).toContain(`[study Bible](${url("study Bible")})`);
    // The AdSlot marker line must be byte-identical in the output.
    expect(out).toContain('<AdSlot id="study Bible" />');
  });

  it("url-encodes keywords in the href", () => {
    const { content: out } = linkifyAffiliate("Buy Strong's Concordance now.", [
      "Strong's Concordance",
    ]);
    expect(out).toContain(
      `(https://www.amazon.in/s?k=${encodeURIComponent("Strong's Concordance")}&tag=${AFFILIATE_TAG})`,
    );
  });
});
