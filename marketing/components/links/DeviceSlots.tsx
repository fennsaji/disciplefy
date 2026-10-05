// marketing/components/links/DeviceSlots.tsx
// Device-aware rendering for the statically generated /links page.
import type { ReactNode } from "react";
import type { StorePlatform } from "@/lib/app-links";
import { PLATFORM_SCRIPT, PLATFORM_STYLES, PLATFORMS } from "@/lib/link-platform";
import { APP_TARGETS, CTA_ORDER, type AppTargetLink } from "@/components/links/link-data";

export type CtaSet = {
  platform: StorePlatform;
  primary: AppTargetLink;
  secondary: AppTargetLink[];
};

/**
 * Must render once, above any <DeviceSlots>. Classifies the device before
 * the slots below are painted (see lib/link-platform.ts).
 */
export function PlatformDetector() {
  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: PLATFORM_STYLES }} />
      <script dangerouslySetInnerHTML={{ __html: PLATFORM_SCRIPT }} />
    </>
  );
}

/**
 * Renders its children once per platform; CSS shows only the slot that
 * matches the visitor's device. All three are in the static HTML, so the
 * page stays static and the right one is visible on first paint.
 */
export function DeviceSlots({ children }: { children: (cta: CtaSet) => ReactNode }) {
  return (
    <>
      {PLATFORMS.map((platform) => {
        const order = CTA_ORDER[platform];
        return (
          <div key={platform} data-platform-slot={platform}>
            {children({
              platform,
              primary: APP_TARGETS[order.primary],
              secondary: order.secondary.map((id) => APP_TARGETS[id]),
            })}
          </div>
        );
      })}
    </>
  );
}
