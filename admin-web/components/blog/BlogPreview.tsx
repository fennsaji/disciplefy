'use client'

import ReactMarkdown from 'react-markdown'
import { blogPreviewComponents } from './blog-mdx-components'

export function BlogPreview({
  content,
  title,
  tags,
  status,
}: {
  content: string
  title: string
  tags: string[]
  status: string
}) {
  return (
    <div className="blog-preview">
      <header className="mb-8">
        {tags.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-4">
            {tags.map((t) => (
              <span key={t} className="text-xs font-semibold text-primary dark:text-indigo-300 bg-primary/10 px-2.5 py-1 rounded-full">{t}</span>
            ))}
          </div>
        )}
        <h1 className="font-display font-extrabold text-3xl sm:text-4xl leading-tight text-gray-900 dark:text-white mb-3">
          {title || 'Untitled post'}
        </h1>
        <p className="text-sm text-gray-500">Preview · status: {status}</p>
      </header>
      <article className="min-w-0 max-w-[68ch]">
        <ReactMarkdown components={blogPreviewComponents}>{content}</ReactMarkdown>
      </article>
    </div>
  )
}
