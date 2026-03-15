'use client'

import { useState, useEffect, use } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import {
  getBlogPost,
  updateBlogPost,
  deleteBlogPost,
  publishBlogPost,
  unpublishBlogPost,
} from '@/lib/api/admin'
import type { BlogPost, BlogLocale } from '@/types/admin'

export default function EditBlogPostPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const router = useRouter()

  const [post, setPost] = useState<BlogPost | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)
  const [isToggling, setIsToggling] = useState(false)

  const [title, setTitle] = useState('')
  const [excerpt, setExcerpt] = useState('')
  const [content, setContent] = useState('')
  const [tagsInput, setTagsInput] = useState('')
  const [featured, setFeatured] = useState(false)
  const [isDirty, setIsDirty] = useState(false)

  useEffect(() => {
    const load = async () => {
      try {
        const data = await getBlogPost(id)
        setPost(data.post)
        setTitle(data.post.title)
        setExcerpt(data.post.excerpt)
        setContent(data.post.content)
        setTagsInput(data.post.tags.join(', '))
        setFeatured(data.post.featured)
      } catch (err) {
        toast.error('Failed to load post')
        router.push('/blogs')
      } finally {
        setIsLoading(false)
      }
    }
    load()
  }, [id, router])

  const markDirty = () => setIsDirty(true)

  const handleSave = async () => {
    if (!title.trim()) { toast.error('Title is required'); return }
    if (!content.trim()) { toast.error('Content is required'); return }

    setIsSaving(true)
    try {
      const tags = tagsInput.split(',').map(t => t.trim()).filter(Boolean)
      const updated = await updateBlogPost(id, {
        title: title.trim(),
        content: content.trim(),
        excerpt: excerpt.trim(),
        tags,
        featured,
      })
      setPost(updated.post)
      setIsDirty(false)
      toast.success('Post saved')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to save post')
    } finally {
      setIsSaving(false)
    }
  }

  const handleToggleStatus = async () => {
    if (!post) return
    setIsToggling(true)
    try {
      const updated = post.status === 'published'
        ? await unpublishBlogPost(id)
        : await publishBlogPost(id)
      setPost(updated.post)
      toast.success(updated.post.status === 'published' ? 'Post published!' : 'Post unpublished')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to update status')
    } finally {
      setIsToggling(false)
    }
  }

  const handleDelete = async () => {
    if (!confirm(`Delete "${post?.title}"? This cannot be undone.`)) return
    setIsDeleting(true)
    try {
      await deleteBlogPost(id)
      toast.success('Post deleted')
      router.push('/blogs')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to delete post')
      setIsDeleting(false)
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-24 text-indigo-400/60 text-sm">
        Loading post…
      </div>
    )
  }

  if (!post) return null

  const LOCALE_LABELS: Record<BlogLocale, string> = { en: 'English', hi: 'Hindi', ml: 'Malayalam' }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Edit Blog Post"
        description={`/${post.locale}/${post.slug}`}
        actions={
          <div className="flex items-center gap-2">
            {isDirty && (
              <span className="text-xs text-amber-400">Unsaved changes</span>
            )}
            <button
              onClick={() => router.push('/blogs')}
              className="text-sm text-indigo-400/70 hover:text-white transition-colors"
            >
              ← Back to Posts
            </button>
          </div>
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
                onChange={e => { setTitle(e.target.value); markDirty() }}
                className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
                Slug <span className="text-indigo-400/40 font-normal normal-case">(read-only)</span>
              </label>
              <input
                type="text"
                value={post.slug}
                readOnly
                className="w-full rounded-lg border border-white/5 bg-white/3 px-3 py-2 font-mono text-sm text-indigo-400/60 outline-none cursor-not-allowed"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
                Excerpt
              </label>
              <textarea
                value={excerpt}
                onChange={e => { setExcerpt(e.target.value); markDirty() }}
                rows={2}
                className="w-full resize-none rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wide text-indigo-400/70 mb-1.5">
                Content (Markdown) <span className="text-red-400">*</span>
              </label>
              <textarea
                value={content}
                onChange={e => { setContent(e.target.value); markDirty() }}
                rows={24}
                className="w-full resize-y rounded-lg border border-white/10 bg-white/5 px-3 py-2 font-mono text-sm text-white outline-none focus:border-indigo-500"
              />
              <p className="mt-1 text-xs text-indigo-400/50">
                {content.split(/\s+/).filter(Boolean).length} words · ~{Math.max(1, Math.ceil(content.split(/\s+/).filter(Boolean).length / 200))} min read
              </p>
            </div>
          </div>
        </div>

        {/* Sidebar */}
        <div className="space-y-4">
          {/* Save actions */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-5 space-y-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Actions</p>
            <button
              onClick={handleSave}
              disabled={isSaving || !isDirty}
              className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-indigo-500 disabled:opacity-50"
            >
              {isSaving ? 'Saving…' : '💾 Save Changes'}
            </button>
            <button
              onClick={handleToggleStatus}
              disabled={isToggling}
              className={`w-full rounded-lg px-4 py-2.5 text-sm font-medium transition-colors disabled:opacity-50 ${
                post.status === 'published'
                  ? 'border border-amber-400/30 bg-amber-400/10 text-amber-300 hover:bg-amber-400/20'
                  : 'bg-emerald-600 text-white hover:bg-emerald-500'
              }`}
            >
              {isToggling ? '…' : post.status === 'published' ? '📥 Unpublish' : '🚀 Publish'}
            </button>
          </div>

          {/* Post info */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-5 space-y-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Post Info</p>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-indigo-400/60">Status</span>
                <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                  post.status === 'published'
                    ? 'bg-emerald-500/20 text-emerald-300'
                    : 'bg-amber-500/20 text-amber-300'
                }`}>{post.status}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-indigo-400/60">Language</span>
                <span className="text-white">{LOCALE_LABELS[post.locale]}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-indigo-400/60">Source</span>
                <span className="text-white capitalize">{post.source_type ?? 'manual'}</span>
              </div>
              {post.published_at && (
                <div className="flex justify-between">
                  <span className="text-indigo-400/60">Published</span>
                  <span className="text-white">{new Date(post.published_at).toLocaleDateString()}</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-indigo-400/60">Updated</span>
                <span className="text-white">{new Date(post.updated_at).toLocaleDateString()}</span>
              </div>
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
              onChange={e => { setTagsInput(e.target.value); markDirty() }}
              placeholder="prayer, faith, bible-study"
              className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
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
                onClick={() => { setFeatured(!featured); markDirty() }}
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

          {/* Danger zone */}
          <div className="rounded-xl border border-red-500/20 bg-red-500/5 p-5">
            <p className="text-xs font-semibold uppercase tracking-wide text-red-400/70 mb-3">Danger Zone</p>
            <button
              onClick={handleDelete}
              disabled={isDeleting}
              className="w-full rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-2.5 text-sm font-medium text-red-400 transition-colors hover:bg-red-500/20 disabled:opacity-50"
            >
              {isDeleting ? 'Deleting…' : '🗑️ Delete Post'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
