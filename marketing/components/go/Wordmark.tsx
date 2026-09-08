import Image from "next/image";
import { WEB_APP_URL } from "@/lib/app-links";

/** Identity on the shared-link pages: who handed you this, quietly stated. */
export function Wordmark() {
  return (
    <a
      href={WEB_APP_URL}
      className="inline-flex items-center gap-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[#8B84F0]"
    >
      <Image
        src="/logo-dark.png"
        alt="Disciplefy"
        width={156}
        height={36}
        priority
        className="h-9 w-auto"
      />
    </a>
  );
}
