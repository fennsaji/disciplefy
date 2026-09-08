import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";
import { fetchSharePreview, postBlocks, previewSnippet } from "./share-preview";

describe("previewSnippet", () => {
  it("collapses whitespace so a multi-line post fits one card line", () => {
    expect(previewSnippet("line one\n\n  line two")).toBe("line one line two");
  });

  it("truncates with an ellipsis at the limit", () => {
    expect(previewSnippet("a".repeat(200), 10)).toBe(`${"a".repeat(9)}…`);
  });

  it("leaves short text untouched", () => {
    expect(previewSnippet("short", 10)).toBe("short");
  });
});

describe("fetchSharePreview", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon-key";
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("returns the preview the endpoint sends", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ data: { found: true, is_public: true, content: "hi" } }),
      }),
    );

    await expect(fetchSharePreview("p1")).resolves.toMatchObject({
      is_public: true,
      content: "hi",
    });
  });

  it("degrades to not-found when the endpoint fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false }));

    // The landing page must still render and offer the app.
    await expect(fetchSharePreview("p1")).resolves.toEqual({
      found: false,
      is_public: false,
    });
  });

  it("degrades to not-found when the network throws", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));

    await expect(fetchSharePreview("p1")).resolves.toEqual({
      found: false,
      is_public: false,
    });
  });

  it("makes no request when the environment is not configured", async () => {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(fetchSharePreview("p1")).resolves.toEqual({
      found: false,
      is_public: false,
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("postBlocks", () => {
  const post = [
    "📖 The Nature and Wages of Sin",
    "",
    "✨ What you think is a small choice costs more than you know.",
    "",
    "Romans 8:28 reminds us that God sees the full weight of it.",
    "",
    "✝️ Romans 8:28",
    "",
    "💬 How does this passage speak to your situation?",
  ].join("\n");

  it("keeps the author's structure instead of one run-on paragraph", () => {
    expect(postBlocks(post).map((b) => b.kind)).toEqual([
      "topic",
      "body",
      "body",
      "scripture",
      "question",
    ]);
  });

  it("strips the marker from the text it labels", () => {
    const blocks = postBlocks(post);

    expect(blocks[0].text).toBe("The Nature and Wages of Sin");
    expect(blocks[3].text).toBe("Romans 8:28");
    expect(blocks[4].text).toBe("How does this passage speak to your situation?");
    // The ✨ hook reads as ordinary lead text, not its own label.
    expect(blocks[1].text.startsWith("What you think")).toBe(true);
  });

  it("keeps a long post whole, question and all", () => {
    const long = [
      "📖 A long study",
      "",
      "b".repeat(3000),
      "",
      "💬 Does the question survive to the end?",
    ].join("\n");

    const blocks = postBlocks(long);

    expect(blocks.at(-1)).toEqual({
      kind: "question",
      text: "Does the question survive to the end?",
    });
    expect(blocks.some((b) => b.text.endsWith("…"))).toBe(false);
  });

  it("still caps a pathological post", () => {
    const blocks = postBlocks("a".repeat(50), 10);

    expect(blocks[0].text).toBe(`${"a".repeat(9)}…`);
  });

  it("drops blank blocks", () => {
    expect(postBlocks("one\n\n\n\ntwo")).toHaveLength(2);
  });

  it("treats an unmarked post as a single body block", () => {
    expect(postBlocks("Just a plain thought.")).toEqual([
      { kind: "body", text: "Just a plain thought." },
    ]);
  });
});
