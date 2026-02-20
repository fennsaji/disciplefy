'use client'

import { use, useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import type { StudyGuide, StudyGuideContent } from '@/types/admin'

interface PageProps {
  params: Promise<{ id: string }>
}

// ── Section editor helpers ──────────────────────────────────────────────────

function SectionCard({
  title,
  emoji,
  children,
}: {
  title: string
  emoji: string
  children: React.ReactNode
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white dark:border-white/10 dark:bg-gray-900">
      <div className="flex items-center gap-2 border-b border-gray-100 px-5 py-3 dark:border-white/5">
        <span className="text-base">{emoji}</span>
        <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200">{title}</h3>
      </div>
      <div className="px-5 py-4">{children}</div>
    </div>
  )
}

function TextareaField({
  value,
  onChange,
  rows = 4,
  placeholder,
}: {
  value: string
  onChange: (v: string) => void
  rows?: number
  placeholder?: string
}) {
  return (
    <textarea
      rows={rows}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full resize-y rounded-lg border border-gray-200 bg-gray-50 px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-white/10 dark:bg-white/5 dark:text-gray-100 dark:placeholder-gray-500"
    />
  )
}

function StringListEditor({
  items,
  onChange,
  placeholder,
}: {
  items: string[]
  onChange: (items: string[]) => void
  placeholder?: string
}) {
  const update = (index: number, value: string) => {
    const next = [...items]
    next[index] = value
    onChange(next)
  }

  const remove = (index: number) => {
    onChange(items.filter((_, i) => i !== index))
  }

  const add = () => onChange([...items, ''])

  return (
    <div className="space-y-2">
      {items.map((item, i) => (
        <div key={i} className="flex gap-2">
          <span className="mt-2.5 shrink-0 text-xs font-medium text-gray-400">{i + 1}.</span>
          <textarea
            rows={2}
            value={item}
            onChange={(e) => update(i, e.target.value)}
            placeholder={placeholder}
            className="flex-1 resize-y rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-white/10 dark:bg-white/5 dark:text-gray-100 dark:placeholder-gray-500"
          />
          <button
            type="button"
            onClick={() => remove(i)}
            className="mt-1 self-start rounded-lg p-1.5 text-red-400 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-400/10"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      ))}
      <button
        type="button"
        onClick={add}
        className="flex items-center gap-1.5 rounded-lg border border-dashed border-gray-300 px-3 py-2 text-xs font-medium text-gray-500 hover:border-primary hover:text-primary dark:border-white/20 dark:text-gray-400 dark:hover:border-indigo-400 dark:hover:text-indigo-400"
      >
        <svg className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        Add item
      </button>
    </div>
  )
}

// ── Badges ──────────────────────────────────────────────────────────────────

function Badge({ label, color }: { label: string; color: string }) {
  const cls: Record<string, string> = {
    indigo: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-400/15 dark:text-indigo-300',
    amber: 'bg-amber-100 text-amber-800 dark:bg-amber-400/15 dark:text-amber-300',
    green: 'bg-green-100 text-green-800 dark:bg-green-400/15 dark:text-green-300',
    blue: 'bg-blue-100 text-blue-800 dark:bg-blue-400/15 dark:text-blue-300',
  }
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ${cls[color] ?? cls.indigo}`}>
      {label}
    </span>
  )
}

// ── Page ────────────────────────────────────────────────────────────────────

export default function StudyGuideViewPage({ params }: PageProps) {
  const { id } = use(params)
  const router = useRouter()

  const [guide, setGuide] = useState<StudyGuide | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [isDirty, setIsDirty] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Editable content state
  const [content, setContent] = useState<StudyGuideContent>({})

  useEffect(() => {
    loadGuide()
  }, [id])

  const loadGuide = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await fetch(`/api/admin/study-guide/${id}`, { credentials: 'include' })
      if (!res.ok) throw new Error('Study guide not found')
      const data = await res.json()
      const g: StudyGuide = data.study_guide
      setGuide(g)
      // Merge content + flat fields into editable state
      setContent({
        summary: g.content?.summary ?? g.summary ?? '',
        context: g.content?.context ?? g.context ?? '',
        interpretation: g.content?.interpretation ?? g.interpretation ?? '',
        passage: g.content?.passage ?? g.passage ?? '',
        reflectionQuestions:
          g.content?.reflectionQuestions ??
          g.content?.reflection_questions ??
          g.reflection_questions ??
          [],
        prayerPoints:
          g.content?.prayerPoints ??
          g.content?.prayer_points ??
          [],
        relatedVerses:
          g.content?.relatedVerses ??
          g.content?.related_verses ??
          g.related_verses ??
          [],
      })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load study guide')
    } finally {
      setIsLoading(false)
    }
  }

  const patch = (updates: Partial<StudyGuideContent>) => {
    setContent((prev) => ({ ...prev, ...updates }))
    setIsDirty(true)
  }

  const handleSave = async () => {
    setIsSaving(true)
    try {
      const res = await fetch(`/api/admin/study-guide/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ content }),
      })
      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error || 'Failed to save')
      }
      toast.success('Study guide saved')
      setIsDirty(false)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to save')
    } finally {
      setIsSaving(false)
    }
  }

  // ── Loading / Error ──────────────────────────────────────────────────────

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
      </div>
    )
  }

  if (error || !guide) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 dark:border-red-400/20 dark:bg-red-400/10">
        <p className="text-sm text-red-800 dark:text-red-300">{error ?? 'Guide not found'}</p>
        <button
          onClick={() => router.back()}
          className="mt-3 text-sm font-medium text-red-700 underline dark:text-red-400"
        >
          Go back
        </button>
      </div>
    )
  }

  const reflectionQuestions = (content.reflectionQuestions ?? content.reflection_questions ?? []) as string[]
  const prayerPoints = (content.prayerPoints ?? content.prayer_points ?? []) as string[]
  const relatedVerses = (content.relatedVerses ?? content.related_verses ?? []) as any[]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-3">
          <button
            onClick={() => router.back()}
            className="mt-0.5 rounded-lg border border-gray-200 p-2 text-gray-500 hover:bg-gray-50 dark:border-white/10 dark:text-gray-400 dark:hover:bg-white/5"
            title="Back"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <div>
            <h1 className="text-xl font-bold text-gray-900 dark:text-gray-100">
              {guide.title || guide.input_value}
            </h1>
            <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
              View and edit this study guide's content
            </p>
            {/* Metadata badges */}
            <div className="mt-2 flex flex-wrap items-center gap-2">
              <Badge label={guide.input_type} color="blue" />
              <Badge label={guide.study_mode} color="indigo" />
              <Badge label={guide.language.toUpperCase()} color="green" />
              <span className="text-xs text-gray-400 dark:text-gray-500">
                Created {new Date(guide.created_at).toLocaleDateString()}
              </span>
              {guide.creator_name && (
                <span className="text-xs text-gray-400 dark:text-gray-500">
                  · by {guide.creator_name}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Save button */}
        <div className="flex items-center gap-2 shrink-0">
          {isDirty && (
            <span className="text-xs text-amber-600 dark:text-amber-400">Unsaved changes</span>
          )}
          <button
            onClick={handleSave}
            disabled={isSaving || !isDirty}
            className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {isSaving ? (
              <>
                <div className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-white border-t-transparent" />
                Saving…
              </>
            ) : (
              <>
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                Save Changes
              </>
            )}
          </button>
        </div>
      </div>

      {/* Input value (read-only context) */}
      <div className="rounded-xl border border-amber-200 bg-amber-50 px-5 py-3 dark:border-amber-400/20 dark:bg-amber-400/10">
        <p className="text-xs font-semibold uppercase tracking-wider text-amber-700 dark:text-amber-400">
          Input
        </p>
        <p className="mt-0.5 text-sm text-amber-900 dark:text-amber-200">{guide.input_value}</p>
      </div>

      {/* Editable content sections */}
      <div className="space-y-4">
        <SectionCard title="Summary" emoji="📋">
          <TextareaField
            value={(content.summary as string) ?? ''}
            onChange={(v) => patch({ summary: v })}
            rows={4}
            placeholder="A concise summary of this study guide…"
          />
        </SectionCard>

        <SectionCard title="Context / Background" emoji="🌍">
          <TextareaField
            value={(content.context as string) ?? ''}
            onChange={(v) => patch({ context: v })}
            rows={4}
            placeholder="Historical and cultural context…"
          />
        </SectionCard>

        {(content.passage !== undefined && content.passage !== null) && (
          <SectionCard title="Passage" emoji="📖">
            <TextareaField
              value={(content.passage as string) ?? ''}
              onChange={(v) => patch({ passage: v })}
              rows={3}
              placeholder="Scripture passage text…"
            />
          </SectionCard>
        )}

        <SectionCard title="Interpretation" emoji="🔍">
          <TextareaField
            value={(content.interpretation as string) ?? ''}
            onChange={(v) => patch({ interpretation: v })}
            rows={5}
            placeholder="Theological interpretation and meaning…"
          />
        </SectionCard>

        <SectionCard title="Reflection Questions" emoji="💭">
          <StringListEditor
            items={reflectionQuestions}
            onChange={(items) => patch({ reflectionQuestions: items, reflection_questions: items })}
            placeholder="Enter a reflection question…"
          />
        </SectionCard>

        <SectionCard title="Prayer Points" emoji="🙏">
          <StringListEditor
            items={prayerPoints}
            onChange={(items) => patch({ prayerPoints: items, prayer_points: items })}
            placeholder="Enter a prayer point…"
          />
        </SectionCard>

        {relatedVerses.length > 0 && (
          <SectionCard title="Related Verses" emoji="📜">
            <div className="space-y-2">
              {relatedVerses.map((v: any, i: number) => (
                <div
                  key={i}
                  className="rounded-lg border border-gray-100 bg-gray-50 px-3 py-2 text-sm dark:border-white/5 dark:bg-white/5"
                >
                  {typeof v === 'string' ? (
                    <span className="text-gray-700 dark:text-gray-300">{v}</span>
                  ) : (
                    <>
                      <span className="font-semibold text-gray-900 dark:text-gray-100">
                        {v.reference}
                      </span>
                      {v.text && (
                        <p className="mt-0.5 text-gray-600 dark:text-gray-400">{v.text}</p>
                      )}
                    </>
                  )}
                </div>
              ))}
            </div>
          </SectionCard>
        )}
      </div>

      {/* Sticky save bar when dirty */}
      {isDirty && (
        <div className="sticky bottom-0 flex items-center justify-between rounded-xl border border-amber-200 bg-amber-50 px-5 py-3 shadow-lg dark:border-amber-400/20 dark:bg-[#1a1600]">
          <p className="text-sm text-amber-800 dark:text-amber-300">
            You have unsaved changes
          </p>
          <div className="flex gap-2">
            <button
              onClick={() => { loadGuide(); setIsDirty(false) }}
              className="rounded-lg border border-amber-300 px-3 py-1.5 text-xs font-medium text-amber-700 hover:bg-amber-100 dark:border-amber-400/30 dark:text-amber-400"
            >
              Discard
            </button>
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-white hover:bg-primary/90 disabled:opacity-50"
            >
              {isSaving ? 'Saving…' : 'Save'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
