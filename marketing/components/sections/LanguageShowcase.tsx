// marketing/components/sections/LanguageShowcase.tsx
"use client";
import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useTranslations } from "next-intl";

const tabs = [
  { label: "English", lang: "en" },
  { label: "हिन्दी", lang: "hi" },
  { label: "മലയാളം", lang: "ml" },
];

const sampleVerse = {
  en: {
    ref: "John 3:16",
    text: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
    summary: "God's ultimate act of love — offering salvation to all of humanity through Jesus Christ.",
  },
  hi: {
    ref: "यूहन्ना 3:16",
    text: "क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे वह नष्ट न हो परन्तु अनन्त जीवन पाए।",
    summary: "परमेश्वर का परम प्रेम — यीशु मसीह के द्वारा सभी मनुष्यों को उद्धार प्रदान करना।",
  },
  ml: {
    ref: "യോഹന്നാൻ 3:16",
    text: "ദൈവം ലോകത്തെ അത്ര സ്നേഹിച്ചു, അവൻ തന്റെ ഏകജാതനായ പുത്രനെ നൽകി, അവനിൽ വിശ്വസിക്കുന്ന ഏവനും നശിച്ചുപോകാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്.",
    summary: "ദൈവത്തിന്റെ അത്യുന്നത സ്നേഹം — യേശുക്രിസ്തുവിലൂടെ എല്ലാ മനുഷ്യർക്കും രക്ഷ നൽകൽ.",
  },
};

export function LanguageShowcase() {
  const t = useTranslations("languageShowcase");
  const [active, setActive] = useState(0);
  const intervalRef = useRef<ReturnType<typeof setInterval>>();

  function resetInterval() {
    clearInterval(intervalRef.current);
    intervalRef.current = setInterval(() => setActive((i) => (i + 1) % tabs.length), 4000);
  }

  useEffect(() => {
    resetInterval();
    return () => clearInterval(intervalRef.current);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const verse = sampleVerse[tabs[active].lang as keyof typeof sampleVerse];
  const fontClass = tabs[active].lang === "hi" ? "font-devanagari" : tabs[active].lang === "ml" ? "font-malayalam" : "";

  return (
    <section className="py-24">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="font-display font-bold text-3xl sm:text-4xl mb-4">{t("title")}</h2>
          <p className="text-[var(--muted)] mb-12 max-w-xl mx-auto">{t("subtitle")}</p>
        </motion.div>

        {/* Language tabs */}
        <div className="flex justify-center gap-2 mb-8">
          {tabs.map((tab, i) => (
            <button
              key={tab.lang}
              onClick={() => { setActive(i); resetInterval(); }}
              className={`relative px-5 py-2 rounded-full text-sm font-semibold transition-colors ${
                active === i
                  ? "text-white"
                  : "bg-[var(--surface)] text-[var(--muted)] border border-[var(--border)]"
              }`}
            >
              {active === i && (
                <motion.div
                  layoutId="activeLanguageTab"
                  className="absolute inset-0 bg-primary rounded-full shadow-lg shadow-primary/30"
                  transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
                />
              )}
              <span className="relative z-10">{tab.label}</span>
            </button>
          ))}
        </div>

        {/* Verse card */}
        <div className="bg-[var(--surface)] border border-[var(--border)] rounded-3xl p-8 shadow-xl text-left">
          <AnimatePresence mode="wait">
            <motion.div
              key={active}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              transition={{ duration: 0.3 }}
            >
              <p className="text-xs font-semibold text-primary uppercase tracking-widest mb-3">{verse.ref}</p>
              <p className={`text-xl leading-relaxed mb-4 ${fontClass}`}>{verse.text}</p>
              <div className="border-t border-[var(--border)] pt-4">
                <p className="text-xs font-semibold text-[var(--muted)] uppercase mb-1">Summary</p>
                <p className={`text-sm text-[var(--muted)] ${fontClass}`}>{verse.summary}</p>
              </div>
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </section>
  );
}
