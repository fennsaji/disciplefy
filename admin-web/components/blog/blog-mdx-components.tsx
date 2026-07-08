// Ported from marketing/components/blog/MDXComponents.tsx.
// Renders react-markdown output to match the live blog article's typography exactly,
// so admin editors get a faithful preview of published posts.
import type { Components } from 'react-markdown'

export const blogPreviewComponents: Components = {
  h1: ({ node, ...p }) => <h1 className="scroll-mt-24 font-display font-extrabold text-3xl mt-12 mb-5 text-gray-900 dark:text-white leading-tight" {...p} />,
  h2: ({ node, ...p }) => <h2 className="scroll-mt-24 font-display font-bold text-2xl mt-12 mb-4 leading-snug text-primary dark:text-indigo-300 border-l-[3px] border-primary dark:border-indigo-400 pl-4" {...p} />,
  h3: ({ node, ...p }) => <h3 className="scroll-mt-24 font-display font-semibold text-xl mt-8 mb-3 leading-snug text-gray-800 dark:text-slate-100" {...p} />,
  h4: ({ node, ...p }) => <h4 className="scroll-mt-24 font-display font-semibold text-lg mt-6 mb-2 text-gray-700 dark:text-slate-300" {...p} />,
  p: ({ node, ...p }) => <p className="text-gray-700 dark:text-slate-300 leading-[2.0] mb-5 text-[18px]" {...p} />,
  ul: ({ node, ...p }) => <ul className="list-disc pl-6 space-y-2.5 mb-5 text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]" {...p} />,
  ol: ({ node, ...p }) => <ol className="list-decimal pl-6 space-y-2.5 mb-5 text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]" {...p} />,
  li: ({ node, ...p }) => <li className="leading-[1.9]" {...p} />,
  a: ({ node, ...p }) => <a className="text-primary dark:text-indigo-300 underline decoration-primary/30 underline-offset-2 hover:decoration-primary transition-all" {...p} />,
  blockquote: ({ node, ...p }) => <blockquote className="relative border-l-4 border-amber-400 dark:border-amber-500 pl-5 pr-4 py-3 my-7 rounded-r-lg bg-amber-50/60 dark:bg-amber-500/8 italic text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]" {...p} />,
  strong: ({ node, ...p }) => <strong className="font-semibold text-gray-900 dark:text-slate-100" {...p} />,
  em: ({ node, ...p }) => <em className="italic text-gray-600 dark:text-slate-400" {...p} />,
  hr: () => <hr className="my-10 border-none h-px bg-gradient-to-r from-transparent via-gray-300 dark:via-slate-600 to-transparent" />,
  code: ({ node, ...p }) => <code className="text-sm font-mono bg-primary/10 dark:bg-indigo-500/15 text-primary dark:text-indigo-300 px-1.5 py-0.5 rounded" {...p} />,
  pre: ({ node, ...p }) => <pre className="overflow-x-auto rounded-xl bg-gray-100 dark:bg-slate-800/60 border border-gray-200 dark:border-slate-700 p-5 my-6 text-sm font-mono text-gray-800 dark:text-slate-200" {...p} />,
}
