// marketing/components/links/link-data.tsx
// Every destination on the /links page, in one place.
import { AppleIcon, GlobeIcon, GooglePlayIcon, MailIcon } from "@/components/links/PlatformIcons";
import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL, type StorePlatform } from "@/lib/app-links";
import { SOCIAL } from "@/lib/social-links";

export type IconComponent = (props: { className?: string }) => JSX.Element;

export type AppTarget = "ios" | "android" | "web";

export type AppTargetLink = {
  id: AppTarget;
  href: string;
  /** Full button label, read by screen readers. */
  label: string;
  /** Small first line on a two-line store button. */
  kicker: string;
  /** Large second line on a two-line store button. */
  name: string;
  Icon: IconComponent;
};

export const APP_TARGETS: Record<AppTarget, AppTargetLink> = {
  ios: {
    id: "ios",
    href: APP_STORE_URL ?? WEB_APP_URL,
    label: "Download on the App Store",
    kicker: "Download on the",
    name: "App Store",
    Icon: AppleIcon,
  },
  android: {
    id: "android",
    href: PLAY_STORE_URL,
    label: "Get it on Google Play",
    kicker: "Get it on",
    name: "Google Play",
    Icon: GooglePlayIcon,
  },
  web: {
    id: "web",
    href: WEB_APP_URL,
    label: "Open in your browser",
    kicker: "No download needed",
    name: "Open in browser",
    Icon: GlobeIcon,
  },
};

/** Which destination leads on each device, and the rest in order. */
export const CTA_ORDER: Record<StorePlatform, { primary: AppTarget; secondary: AppTarget[] }> = {
  ios: { primary: "ios", secondary: ["android", "web"] },
  android: { primary: "android", secondary: ["ios", "web"] },
  other: { primary: "web", secondary: ["ios", "android"] },
};

export type FollowLink = {
  /** Full name, used as the accessible label. */
  label: string;
  /** Short caption under the round icon. */
  caption: string;
  href: string;
  Icon: IconComponent;
};

export const FOLLOW_LINKS: FollowLink[] = [
  { ...SOCIAL.instagram, caption: "Instagram" },
  { ...SOCIAL.youtube, caption: "YouTube" },
  { ...SOCIAL.whatsapp, label: "WhatsApp Community", caption: "WhatsApp" },
  { ...SOCIAL.telegram, label: "Telegram Channel", caption: "Telegram" },
  { ...SOCIAL.facebook, caption: "Facebook" },
];

export type ContactLink = {
  label: string;
  detail: string;
  href: string;
  Icon: IconComponent;
};

export const CONTACT_LINKS: ContactLink[] = [
  {
    label: "disciplefy.in",
    detail: "Features, plans and the blog",
    href: "https://www.disciplefy.in",
    Icon: GlobeIcon,
  },
  {
    label: "hello@disciplefy.in",
    detail: "Questions, feedback, or just to say hello",
    href: "mailto:hello@disciplefy.in",
    Icon: MailIcon,
  },
];

/** QR code for go.disciplefy.in/download, which redirects to the visitor's store. */
export const DOWNLOAD_QR_SRC = "/links/download-qr.svg";

/** Opens http(s) links in a new tab; mailto stays in place. */
export function linkProps(href: string) {
  return href.startsWith("http") ? { href, target: "_blank", rel: "noopener noreferrer" } : { href };
}

/** Shared keyboard focus ring; colour comes from the page theme. */
export const FOCUS_RING =
  "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[3px] focus-visible:outline-[color:var(--gold-ink)]";
