// marketing/components/blog/MDXComponents.tsx
import type { MDXComponents } from "mdx/types";

// Body text: slate-300 in dark (softer than pure white), gray-700 in light
// Headings:  white/gray-900 — strong hierarchy
// h2 accent: indigo-300 dark, primary light — with left border

export const mdxComponents: MDXComponents = {
  h1: (props) => (
    <h1
      className="font-display font-extrabold text-3xl mt-12 mb-5 text-gray-900 dark:text-white leading-tight"
      {...props}
    />
  ),
  h2: (props) => (
    <h2
      className="font-display font-bold text-2xl mt-12 mb-4 leading-snug
                 text-primary dark:text-indigo-300
                 border-l-[3px] border-primary dark:border-indigo-400 pl-4"
      {...props}
    />
  ),
  h3: (props) => (
    <h3
      className="font-display font-semibold text-xl mt-8 mb-3 leading-snug text-gray-800 dark:text-slate-100"
      {...props}
    />
  ),
  h4: (props) => (
    <h4
      className="font-display font-semibold text-lg mt-6 mb-2 text-gray-700 dark:text-slate-300"
      {...props}
    />
  ),
  // Body: 18px / line-height 2.0 — standard for Devanagari/Malayalam scripts
  p: (props) => (
    <p
      className="text-gray-700 dark:text-slate-300 leading-[2.0] mb-5 text-[18px]"
      {...props}
    />
  ),
  ul: (props) => (
    <ul
      className="list-disc pl-6 space-y-2.5 mb-5 text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]"
      {...props}
    />
  ),
  ol: (props) => (
    <ol
      className="list-decimal pl-6 space-y-2.5 mb-5 text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]"
      {...props}
    />
  ),
  li: (props) => (
    <li className="leading-[1.9]" {...props} />
  ),
  a: (props) => (
    <a
      className="text-primary dark:text-indigo-300 underline decoration-primary/30 dark:decoration-indigo-400/40 underline-offset-2 hover:decoration-primary dark:hover:decoration-indigo-300 transition-all"
      {...props}
    />
  ),
  // Scripture / quote block — amber accent to feel like a Bible verse callout
  blockquote: (props) => (
    <blockquote
      className="relative border-l-4 border-amber-400 dark:border-amber-500 pl-5 pr-4 py-3 my-7 rounded-r-lg
                 bg-amber-50/60 dark:bg-amber-500/8 italic
                 text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]"
      {...props}
    />
  ),
  strong: (props) => (
    <strong
      className="font-semibold text-gray-900 dark:text-slate-100"
      {...props}
    />
  ),
  em: (props) => (
    <em className="italic text-gray-600 dark:text-slate-400" {...props} />
  ),
  hr: () => (
    <hr className="my-10 border-none h-px bg-gradient-to-r from-transparent via-gray-300 dark:via-slate-600 to-transparent" />
  ),
  code: (props) => (
    <code
      className="text-sm font-mono bg-primary/10 dark:bg-indigo-500/15 text-primary dark:text-indigo-300 px-1.5 py-0.5 rounded"
      {...props}
    />
  ),
  pre: (props) => (
    <pre
      className="overflow-x-auto rounded-xl bg-gray-100 dark:bg-slate-800/60 border border-gray-200 dark:border-slate-700 p-5 my-6 text-sm font-mono text-gray-800 dark:text-slate-200"
      {...props}
    />
  ),
};
