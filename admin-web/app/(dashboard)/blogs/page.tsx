'use client'

import { useState, useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import {
  listBlogPosts,
  publishBlogPost,
  unpublishBlogPost,
  deleteBlogPost,
  triggerBlogCron,
} from '@/lib/api/admin'
import type { BlogPostListItem, BlogLocale } from '@/types/admin'

const LOCALE_LABELS: Record<BlogLocale, string> = { en: 'EN', hi: 'HI', ml: 'ML' }
const LOCALE_COLORS: Record<BlogLocale, string> = {
  en: 'bg-blue-500/20 text-blue-300',
  hi: 'bg-orange-500/20 text-orange-300',
  ml: 'bg-green-500/20 text-green-300',
}

export default function BlogsPage() {
  const router = useRouter()
  const [posts, setPosts] = useState<BlogPostListItem[]>([])
  const [filtered, setFiltered] = useState<BlogPostListItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [localeFilter, setLocaleFilter] = useState<string>('all')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [search, setSearch] = useState('')
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [togglingId, setTogglingId] = useState<string | null>(null)
  const [triggeringCron, setTriggeringCron] = useState(false)

  const loadPosts = useCallback(async () => {
    setIsLoading(true)
    setError(null)
    try {
      const data = await listBlogPosts({ limit: 100 })
      setPosts(data.posts)
    } catch (err) {
      console.error(err)
      setError('Failed to load blog posts.')
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => { loadPosts() }, [loadPosts])

  useEffect(() => {
    let result = posts
    if (localeFilter !== 'all') result = result.filter(p => p.locale === localeFilter)
    if (statusFilter !== 'all') result = result.filter(p => p.status === statusFilter)
    if (search.trim()) {
      const q = search.toLowerCase()
      result = result.filter(p =>
        p.title.toLowerCase().includes(q) ||
        p.excerpt.toLowerCase().includes(q) ||
        p.tags.some(t => t.toLowerCase().includes(q))
      )
    }
    setFiltered(result)
  }, [posts, localeFilter, statusFilter, search])

  const handleToggleStatus = async (post: BlogPostListItem) => {
    setTogglingId(post.id)
    try {
      if (post.status === 'published') {
        await unpublishBlogPost(post.id)
        toast.success(`"${post.title}" unpublished`)
      } else {
        await publishBlogPost(post.id)
        toast.success(`"${post.title}" published`)
      }
      await loadPosts()
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to update status')
    } finally {
      setTogglingId(null)
    }
  }

  const handleDelete = async (post: BlogPostListItem) => {
    if (!confirm(`Delete "${post.title}"? This cannot be undone.`)) return
    setDeletingId(post.id)
    try {
      await deleteBlogPost(post.id)
      toast.success('Post deleted')
      await loadPosts()
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to delete post')
    } finally {
      setDeletingId(null)
    }
  }

  const handleTriggerCron = async () => {
    setTriggeringCron(true)
    try {
      await triggerBlogCron()
      toast.success('AI blog generation triggered — posts will appear shortly')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to trigger generation')
    } finally {
      setTriggeringCron(false)
    }
  }

  const published = posts.filter(p => p.status === 'published').length
  const drafts = posts.filter(p => p.status === 'draft').length

  return (
    <div className="space-y-6">
      <PageHeader
        title="Blog Posts"
        description="Manage all blog posts across languages"
        actions={
          <div className="flex gap-2">
            <button
              onClick={handleTriggerCron}
              disabled={triggeringCron}
              className="flex items-center gap-2 rounded-lg border border-amber-400/30 bg-amber-400/10 px-3 py-2 text-sm font-medium text-amber-300 transition-colors hover:bg-amber-400/20 disabled:opacity-50"
            >
              {triggeringCron ? '⏳ Generating…' : '✨ Generate AI Posts'}
            </button>
            <button
              onClick={() => router.push('/blogs/new')}
              className="flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-indigo-500"
            >
              + New Post
            </button>
          </div>
        }
      />

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Total Posts', value: posts.length, color: 'text-indigo-300' },
          { label: 'Published', value: published, color: 'text-emerald-300' },
          { label: 'Drafts', value: drafts, color: 'text-amber-300' },
        ].map(stat => (
          <div key={stat.label} className="rounded-xl border border-white/10 bg-white/5 p-4">
            <p className="text-xs text-indigo-400/70">{stat.label}</p>
            <p className={`mt-1 text-2xl font-bold ${stat.color}`}>{stat.value}</p>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <input
          type="text"
          placeholder="Search title, excerpt, tags…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="flex-1 min-w-48 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-indigo-400/50 outline-none focus:border-indigo-500"
        />
        <select
          value={localeFilter}
          onChange={e => setLocaleFilter(e.target.value)}
          className="rounded-lg border border-white/10 bg-[#161240] px-3 py-2 text-sm text-white outline-none"
        >
          <option value="all">All Languages</option>
          <option value="en">English</option>
          <option value="hi">Hindi</option>
          <option value="ml">Malayalam</option>
        </select>
        <select
          value={statusFilter}
          onChange={e => setStatusFilter(e.target.value)}
          className="rounded-lg border border-white/10 bg-[#161240] px-3 py-2 text-sm text-white outline-none"
        >
          <option value="all">All Statuses</option>
          <option value="published">Published</option>
          <option value="draft">Draft</option>
        </select>
        <span className="text-xs text-indigo-400/60">{filtered.length} posts</span>
      </div>

      {/* Table */}
      {isLoading ? (
        <div className="py-12 text-center text-sm text-indigo-400/60">Loading…</div>
      ) : error ? (
        <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-6 text-center text-sm text-red-400">
          {error}
          <button onClick={loadPosts} className="ml-3 underline">Retry</button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="rounded-xl border border-white/10 bg-white/5 py-16 text-center text-sm text-indigo-400/60">
          No posts found.
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-white/10">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Title</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Lang</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Status</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70 hidden md:table-cell">Source</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70 hidden lg:table-cell">Date</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {filtered.map(post => (
                <tr key={post.id} className="group transition-colors hover:bg-white/5">
                  <td className="px-4 py-3">
                    <div className="flex items-start gap-2">
                      {post.featured && (
                        <span className="mt-0.5 shrink-0 text-amber-400" title="Featured">★</span>
                      )}
                      <div>
                        <button
                          onClick={() => router.push(`/blogs/${post.id}`)}
                          className="text-left font-medium text-white hover:text-indigo-300 transition-colors line-clamp-1"
                        >
                          {post.title}
                        </button>
                        <p className="mt-0.5 text-xs text-indigo-400/60 line-clamp-1">{post.excerpt}</p>
                        {post.tags.length > 0 && (
                          <div className="mt-1 flex flex-wrap gap-1">
                            {post.tags.slice(0, 3).map(tag => (
                              <span key={tag} className="rounded px-1.5 py-0.5 text-[10px] bg-white/5 text-indigo-400/70">
                                {tag}
                              </span>
                            ))}
                            {post.tags.length > 3 && (
                              <span className="text-[10px] text-indigo-400/50">+{post.tags.length - 3}</span>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded px-2 py-0.5 text-xs font-semibold ${LOCALE_COLORS[post.locale]}`}>
                      {LOCALE_LABELS[post.locale]}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      post.status === 'published'
                        ? 'bg-emerald-500/20 text-emerald-300'
                        : 'bg-amber-500/20 text-amber-300'
                    }`}>
                      {post.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 hidden md:table-cell">
                    <span className="text-xs text-indigo-400/60 capitalize">{post.source_type ?? 'manual'}</span>
                  </td>
                  <td className="px-4 py-3 hidden lg:table-cell">
                    <span className="text-xs text-indigo-400/60">
                      {post.published_at
                        ? new Date(post.published_at).toLocaleDateString()
                        : new Date(post.created_at).toLocaleDateString()}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={() => router.push(`/blogs/${post.id}`)}
                        className="rounded px-2 py-1 text-xs text-indigo-300 hover:bg-white/10 transition-colors"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleToggleStatus(post)}
                        disabled={togglingId === post.id}
                        className={`rounded px-2 py-1 text-xs transition-colors disabled:opacity-50 ${
                          post.status === 'published'
                            ? 'text-amber-300 hover:bg-amber-500/10'
                            : 'text-emerald-300 hover:bg-emerald-500/10'
                        }`}
                      >
                        {togglingId === post.id ? '…' : post.status === 'published' ? 'Unpublish' : 'Publish'}
                      </button>
                      <button
                        onClick={() => handleDelete(post)}
                        disabled={deletingId === post.id}
                        className="rounded px-2 py-1 text-xs text-red-400 hover:bg-red-500/10 transition-colors disabled:opacity-50"
                      >
                        {deletingId === post.id ? '…' : 'Delete'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
