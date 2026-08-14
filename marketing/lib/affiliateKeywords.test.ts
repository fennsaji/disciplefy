import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

const ORIGINAL_ENV = { ...process.env };

describe("getActiveAffiliateKeywords", () => {
  beforeEach(() => {
    vi.resetModules();
    process.env = { ...ORIGINAL_ENV };
  });

  afterEach(() => {
    process.env = { ...ORIGINAL_ENV };
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("returns [] when Supabase env vars are unset", async () => {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    const { getActiveAffiliateKeywords } = await import("./affiliateKeywords");
    const result = await getActiveAffiliateKeywords();
    expect(result).toEqual([]);
  });

  it("returns [] when the fetch response is not ok", async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon-key";
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false }),
    );
    const { getActiveAffiliateKeywords } = await import("./affiliateKeywords");
    const result = await getActiveAffiliateKeywords();
    expect(result).toEqual([]);
  });

  it("returns [] when fetch throws", async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon-key";
    vi.stubGlobal(
      "fetch",
      vi.fn().mockRejectedValue(new Error("network error")),
    );
    const { getActiveAffiliateKeywords } = await import("./affiliateKeywords");
    const result = await getActiveAffiliateKeywords();
    expect(result).toEqual([]);
  });

  it("returns the mapped keyword array on a successful response", async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon-key";
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => [{ keyword: "foo" }, { keyword: "bar" }],
      }),
    );
    const { getActiveAffiliateKeywords } = await import("./affiliateKeywords");
    const result = await getActiveAffiliateKeywords();
    expect(result).toEqual(["foo", "bar"]);
  });
});
