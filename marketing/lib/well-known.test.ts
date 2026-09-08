import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

/**
 * go.disciplefy.in is the host on every shared link, so its verification files
 * are what decide whether a tapped link opens the app or the browser. They are
 * static files under public/, easy to break silently: iOS disables Universal
 * Links without a word if the association file is not JSON, and Android stops
 * verifying if the signing certificate is missing.
 */
const read = (name: string) =>
  readFileSync(new URL(`../public/.well-known/${name}`, import.meta.url), "utf8");

describe("android asset links", () => {
  const assetlinks = JSON.parse(read("assetlinks.json"));

  it("names the app and both signing certificates", () => {
    const target = assetlinks[0].target;
    expect(target.package_name).toBe("com.disciplefy.bible_study");
    // Play App Signing re-signs the upload, so the installed app presents the
    // first certificate; the second is for builds signed with the upload key.
    expect(target.sha256_cert_fingerprints).toHaveLength(2);
    expect(target.sha256_cert_fingerprints[0]).toMatch(/^24:DE:DC:/);
  });

  it("keeps credential sharing, which Play Console's association requires", () => {
    expect(assetlinks[0].relation).toContain(
      "delegate_permission/common.get_login_creds",
    );
  });
});

describe("apple app site association", () => {
  const raw = read("apple-app-site-association");

  it("is JSON, not HTML", () => {
    // A page served here is the classic silent failure: iOS just stops opening
    // links, with no error anywhere.
    expect(raw.trimStart().startsWith("<")).toBe(false);
    expect(() => JSON.parse(raw)).not.toThrow();
  });

  it("claims the paths shared links actually use", () => {
    const details = JSON.parse(raw).applinks.details;
    const paths = details.flatMap(
      (d: { components?: Array<{ "/": string }>; paths?: string[] }) =>
        d.components?.map((c) => c["/"]) ?? d.paths ?? [],
    );

    for (const path of ["/fellowship/*/post/*", "/fellowship/join/*", "/learning-path/*"]) {
      expect(paths).toContain(path);
    }
    expect(details[0].appIDs[0]).toBe("4V6VA2U9MW.com.disciplefy.biblestudy");
  });
});
