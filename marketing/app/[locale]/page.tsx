// marketing/app/[locale]/page.tsx
// Each locale has its own page component so next-intl generates correct static params per locale.
import { HomePage } from "@/app/_home";
export default function LocalePage() { return <HomePage />; }
