'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { createBlogPost } from '@/lib/api/admin'
import type { BlogLocale } from '@/types/admin'

function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, '')
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

export default function NewBlogPostPage() {
  const router = useRouter()
  const [isSaving, setIsSaving] = useState(false)

  const [title, setTitle] = useState('')
  const [slug, setSlug] = useState('')
  const [slugManual, setSlugManual] = useState(false)
  const [excerpt, setExcerpt] = useState('')
  const [content, setContent] = useState('')
  const [locale, setLocale] = useState<BlogLocale>('en')
  const [tagsInput, setTagsInput] = useState('')
  const [featured, setFeatured] = useState(false)
  const [status, setStatus] = useState<'draft' | 'published'>('draft')

  const handleTitleChange = (v: string) => {
    setTitle(v)
    if (!slugManual) setSlug(slugify(v) + (locale !== 'en' ? `-${locale}` : ''))
  }

  const handleLocaleChange = (v: BlogLocale) => {
    setLocale(v)
    if (!slugManual) setSlug(slugify(title) + (v !== 'en' ? `-${v}` : ''))
  }

  const handleSave = async (saveStatus: 'draft' | 'published') => {
    if (!title.trim()) { toast.error('Title is required'); return }
    if (!content.trim()) { toast.error('Content is required'); return }

    setIsSaving(true)
    try {
      const tags = tagsInput.split(',').map(t => t.trim()).filter(Boolean)
      const post = await createBlogPost({
        title: title.trim(),
        content: content.trim(),
        excerpt: excerpt.trim(),
        locale,
        tags,
        featured,
        status: saveStatus,
        slug: slug.trim() || undefined,
      })
      toast.success(saveStatus === 'published' ? 'Post published!' : 'Saved as draft')
      router.push(`/blogs/${post.post.id}`)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to save post')
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="New Blog Post"
        description="Create a new blog post"
        actions={
          <button
            onClick={() => router.push('/blogs')}
            className="text-sm text-indigo-400/70 hover:text-white transition-colors"
          >
            ← Back to Posts
          </button>
        }
      />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main content */}
        <div className="lg:col-span-2 space-y-4">
          <div className="rounded-xl border border-white/10 bg-white/5 p-5 space-y-4">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
                Title <span className="text-red-400">*</span>
              </label>
              <input
                type="text"
                value={title}
                onChange={e => handleTitleChange(e.target.value)}
                placeholder="Post title…"
                className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-indigo-400/50 outline-none focus:border-indigo-500"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
                Slug
              </label>
              <input
                type="text"
                value={slug}
                onChange={e => { setSlug(e.target.value); setSlugManual(true) }}
                placeholder="auto-generated-from-title"
                className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-mono text-indigo-300 placeholder-indigo-400/50 outline-none focus:border-indigo-500"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
                Excerpt
              </label>
              <textarea
                value={excerpt}
                onChange={e => setExcerpt(e.target.value)}
                rows={2}
                placeholder="Short description shown in post listings…"
                className="w-full resize-none rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-indigo-400/50 outline-none focus:border-indigo-500"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
                Content (Markdown) <span className="text-red-400">*</span>
              </label>
              <textarea
                value={content}
                onChange={e => setContent(e.target.value)}
                rows={20}
                placeholder="Write your post in Markdown…"
                className="w-full resize-y rounded-lg border border-white/10 bg-white/5 px-3 py-2 font-mono text-sm text-white placeholder-indigo-400/50 outline-none focus:border-indigo-500"
              />
              <p className="mt-1 text-xs text-indigo-400/50">
                {content.split(/\s+/).filter(Boolean).length} words · ~{Math.max(1, Math.ceil(content.split(/\s+/).filter(Boolean).length / 200))} min read
              </p>
            </div>
          </div>
        </div>

        {/* Sidebar options */}
        <div className="space-y-4">
          {/* Publish actions */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-5 space-y-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Publish</p>
            <button
              onClick={() => handleSave('published')}
              disabled={isSaving}
              className="w-full rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-emerald-500 disabled:opacity-50"
            >
              {isSaving ? 'Saving…' : '🚀 Publish Now'}
            </button>
            <button
              onClick={() => handleSave('draft')}
              disabled={isSaving}
              className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-white/10 disabled:opacity-50"
            >
              💾 Save as Draft
            </button>
          </div>

          {/* Locale */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-5">
            <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-3">
              Language
            </label>
            <div className="flex gap-2">
              {(['en', 'hi', 'ml'] as BlogLocale[]).map(loc => (
                <button
                  key={loc}
                  onClick={() => handleLocaleChange(loc)}
                  className={`flex-1 rounded-lg py-2 text-sm font-medium transition-colors ${
                    locale === loc
                      ? 'bg-indigo-600 text-white'
                      : 'border border-white/10 bg-white/5 text-indigo-300 hover:bg-white/10'
                  }`}
                >
                  {loc.toUpperCase()}
                </button>
              ))}
            </div>
          </div>

          {/* Tags */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-5">
            <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
              Tags
            </label>
            <input
              type="text"
              value={tagsInput}
              onChange={e => setTagsInput(e.target.value)}
              placeholder="prayer, faith, bible-study"
              className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-indigo-400/50 outline-none focus:border-indigo-500"
            />
            <p className="mt-1 text-xs text-indigo-400/50">Comma-separated</p>
          </div>

          {/* Featured */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-5">
            <label className="flex items-center justify-between cursor-pointer">
              <div>
                <p className="text-sm font-medium text-white">Featured Post</p>
                <p className="text-xs text-indigo-400/60">Highlighted in listings</p>
              </div>
              <button
                onClick={() => setFeatured(!featured)}
                className={`relative inline-flex h-6 w-11 shrink-0 rounded-full transition-colors ${
                  featured ? 'bg-amber-500' : 'bg-white/10'
                }`}
              >
                <span className={`inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform mt-0.5 ${
                  featured ? 'translate-x-5' : 'translate-x-0.5'
                }`} />
              </button>
            </label>
          </div>
        </div>
      </div>
    </div>
  )
}
