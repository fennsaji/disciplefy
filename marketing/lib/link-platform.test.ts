import { describe, expect, it } from "vitest";
import { PLATFORM_SCRIPT } from "./link-platform";

type FakeNavigator = {
  userAgent: string;
  maxTouchPoints?: number;
  userAgentData?: { platform: string };
};

/** Runs the shipped inline script against a fake navigator and document. */
function run(nav: FakeNavigator): string | undefined {
  const attrs: Record<string, string> = {};
  const document = {
    documentElement: {
      setAttribute: (k: string, v: string) => {
        attrs[k] = v;
      },
    },
  };
  new Function("navigator", "document", PLATFORM_SCRIPT)(
    { maxTouchPoints: 0, ...nav },
    document,
  );
  return attrs["data-platform"];
}

const UA = {
  iphoneSafari:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
  iphoneInstagram:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 339.0.3.12.91 (iPhone15,3; iOS 17_5; en_IN; en-IN; scale=3.00; 1290x2796; 618023787)",
  iphoneFacebook:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 [FBAN/FBIOS;FBAV/470.0.0.40.97;FBBV/602838744;FBDV/iPhone15,3;FBMD/iPhone;FBSN/iOS;FBSV/17.5]",
  ipadOld:
    "Mozilla/5.0 (iPad; CPU OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Mobile/15E148 Safari/604.1",
  ipadDesktopMode:
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
  androidChrome:
    "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
  androidInstagram:
    "Mozilla/5.0 (Linux; Android 14; SM-S918B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.6478.71 Mobile Safari/537.36 Instagram 339.0.0.33.88 Android (34/14; 450dpi; 1080x2340; samsung; SM-S918B; dm3q; qcom; en_IN; 618023787)",
  androidFacebook:
    "Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP2A.240605.024; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.0.0 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/470.0.0.43.108;]",
  androidReduced:
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
  macChrome:
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
  windowsEdge:
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0",
};

describe("PLATFORM_SCRIPT", () => {
  it.each([
    ["iPhone Safari", UA.iphoneSafari],
    ["Instagram in-app browser on iPhone", UA.iphoneInstagram],
    ["Facebook in-app browser on iPhone", UA.iphoneFacebook],
    ["older iPad", UA.ipadOld],
  ])("sends %s to the App Store", (_, userAgent) => {
    expect(run({ userAgent })).toBe("ios");
  });

  it("treats a touch Mac user agent (iPadOS desktop mode) as iOS", () => {
    expect(run({ userAgent: UA.ipadDesktopMode, maxTouchPoints: 5 })).toBe("ios");
  });

  it.each([
    ["Android Chrome", UA.androidChrome],
    ["Instagram in-app browser on Android", UA.androidInstagram],
    ["Facebook in-app browser on Android", UA.androidFacebook],
    ["reduced Chrome user agent", UA.androidReduced],
  ])("sends %s to Google Play", (_, userAgent) => {
    expect(run({ userAgent })).toBe("android");
  });

  it("uses userAgentData when the UA string hides the OS", () => {
    expect(
      run({ userAgent: "Mozilla/5.0", userAgentData: { platform: "Android" } }),
    ).toBe("android");
  });

  it.each([
    ["Mac Chrome", UA.macChrome],
    ["Mac Safari without touch", UA.ipadDesktopMode],
    ["Windows Edge", UA.windowsEdge],
  ])("offers the web app on %s", (_, userAgent) => {
    expect(run({ userAgent })).toBe("other");
  });

  it("never throws when navigator is unusable", () => {
    expect(() =>
      new Function("navigator", "document", PLATFORM_SCRIPT)(undefined, undefined),
    ).not.toThrow();
  });
});
