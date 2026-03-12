// marketing/components/blog/MDXComponents.tsx
import type { MDXComponents } from "mdx/types";

export const mdxComponents: MDXComponents = {
  h1: (props) => <h1 className="font-display font-extrabold text-3xl mb-6 mt-8" {...props} />,
  h2: (props) => <h2 className="font-display font-bold text-2xl mb-4 mt-8 text-primary" {...props} />,
  h3: (props) => <h3 className="font-display font-semibold text-xl mb-3 mt-6" {...props} />,
  p: (props) => <p className="text-[var(--muted)] leading-relaxed mb-4" {...props} />,
  ul: (props) => <ul className="list-disc pl-6 space-y-2 mb-4 text-[var(--muted)]" {...props} />,
  a: (props) => <a className="text-primary underline hover:text-primary-hover" {...props} />,
  blockquote: (props) => (
    <blockquote className="border-l-4 border-primary pl-6 my-6 italic text-[var(--muted)]" {...props} />
  ),
};
