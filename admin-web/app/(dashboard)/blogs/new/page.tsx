'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { BlogPreview } from '@/components/blog/BlogPreview'
import { createBlogPost } from '@/lib/api/admin'
import type { BlogLocale, BlogPostStatus } from '@/types/admin'

function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
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
  const [scheduledFor, setScheduledFor] = useState('')
  const [showSchedule, setShowSchedule] = useState(false)
  const [showPanel, setShowPanel] = useState(true)

  // Dirty when the user has entered any content that would be lost
  const isDirty = Boolean(title.trim() || excerpt.trim() || content.trim() || tagsInput.trim())

  // Warn before losing unsaved changes on tab close / hard navigation
  useEffect(() => {
    if (!isDirty || isSaving) return
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault()
      e.returnValue = ''
    }
    window.addEventListener('beforeunload', handleBeforeUnload)
    return () => window.removeEventListener('beforeunload', handleBeforeUnload)
  }, [isDirty, isSaving])

  const handleBack = () => {
    if (isDirty && !confirm('You have unsaved changes. Leave without saving?')) return
    router.push('/blogs')
  }

  const handleTitleChange = (v: string) => {
    setTitle(v)
    if (!slugManual) setSlug(slugify(v) + (locale !== 'en' ? `-${locale}` : ''))
  }

  const handleLocaleChange = (v: BlogLocale) => {
    setLocale(v)
    if (!slugManual) setSlug(slugify(title) + (v !== 'en' ? `-${v}` : ''))
  }

  const handleSave = async (saveStatus: BlogPostStatus) => {
    if (isSaving) return
    if (!title.trim()) { toast.error('Title is required'); return }
    if (!content.trim()) { toast.error('Content is required'); return }

    let scheduledIso: string | undefined
    if (saveStatus === 'scheduled') {
      if (!scheduledFor) { toast.error('Pick a date & time to schedule'); return }
      const when = new Date(scheduledFor) // datetime-local is local time
      if (when.getTime() <= Date.now()) { toast.error('Scheduled time must be in the future'); return }
      scheduledIso = when.toISOString() // → UTC
    }

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
        scheduled_for: scheduledIso,
      })
      toast.success(
        saveStatus === 'published'
          ? 'Post published!'
          : saveStatus === 'scheduled'
            ? 'Post scheduled!'
            : 'Saved as draft'
      )
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
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowPanel(p => !p)}
              className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-sm text-white hover:bg-white/10 transition-colors"
            >
              {showPanel ? 'Hide panel ›' : '‹ Options'}
            </button>
            <button
              onClick={handleBack}
              className="text-sm text-indigo-400/70 hover:text-white transition-colors"
            >
              ← Back to Posts
            </button>
          </div>
        }
      />

      <div className="flex flex-col gap-6 lg:flex-row lg:items-start">
        {/* Main content */}
        <div className="flex-1 min-w-0 space-y-4">
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
          </div>

          {/* Content editor + live preview */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-5">
            <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
              Content (Markdown) <span className="text-red-400">*</span>
            </label>
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
              <div>
                <textarea
                  value={content}
                  onChange={e => setContent(e.target.value)}
                  rows={28}
                  placeholder="Write your post in Markdown…"
                  className="w-full resize-y rounded-lg border border-white/10 bg-white/5 px-3 py-2 font-mono text-sm text-white placeholder-indigo-400/50 outline-none focus:border-indigo-500"
                />
                <p className="mt-1 text-xs text-indigo-400/50">
                  {content.split(/\s+/).filter(Boolean).length} words · ~{Math.max(1, Math.ceil(content.split(/\s+/).filter(Boolean).length / 200))} min read
                </p>
              </div>
              <div className="dark rounded-lg border border-white/10 bg-[#0F172A] p-6 overflow-auto max-h-[80vh]">
                <BlogPreview
                  content={content}
                  title={title}
                  tags={tagsInput.split(',').map(t => t.trim()).filter(Boolean)}
                  status={showSchedule ? 'scheduled' : status}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Sidebar options (collapsible) */}
        {showPanel && (
        <aside className="w-full lg:w-80 shrink-0 space-y-4">
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
            <button
              type="button"
              onClick={() => setShowSchedule(s => !s)}
              disabled={isSaving}
              className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-white/10 disabled:opacity-50"
            >
              🗓️ Schedule
            </button>
            {showSchedule && (
              <div className="space-y-2">
                <input
                  type="datetime-local"
                  value={scheduledFor}
                  onChange={e => setScheduledFor(e.target.value)}
                  className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-indigo-400/50 outline-none focus:border-indigo-500"
                />
                <button
                  type="button"
                  onClick={() => handleSave('scheduled')}
                  disabled={isSaving || !scheduledFor}
                  className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-indigo-500 disabled:opacity-50"
                >
                  {isSaving ? 'Saving…' : 'Schedule Post'}
                </button>
              </div>
            )}
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
        </aside>
        )}
      </div>
    </div>
  )
}
