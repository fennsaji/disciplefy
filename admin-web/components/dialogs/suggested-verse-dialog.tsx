'use client'

import { useState, useEffect } from 'react'

const CATEGORIES = [
  'salvation',
  'comfort',
  'strength',
  'wisdom',
  'promise',
  'guidance',
  'faith',
  'love',
]

interface Translation {
  reference: string
  text: string
}

interface SuggestedVerse {
  id: string
  category: string
  display_order: number
  created_at: string
  translations: Record<string, Translation>
}

interface SuggestedVerseDialogProps {
  isOpen: boolean
  verse: SuggestedVerse | null
  onClose: () => void
  onSave: (data: {
    id?: string
    category: string
    display_order: number
    translations: Record<string, Translation>
  }) => Promise<void>
}

const EMPTY_TRANSLATION: Translation = { reference: '', text: '' }

const LANGUAGE_LABELS: Record<string, string> = {
  en: 'English',
  hi: 'Hindi (हिन्दी)',
  ml: 'Malayalam (മലയാളം)',
}

export default function SuggestedVerseDialog({
  isOpen,
  verse,
  onClose,
  onSave,
}: SuggestedVerseDialogProps) {
  const [category, setCategory] = useState('salvation')
  const [displayOrder, setDisplayOrder] = useState(0)
  const [translations, setTranslations] = useState<Record<string, Translation>>({
    en: { ...EMPTY_TRANSLATION },
    hi: { ...EMPTY_TRANSLATION },
    ml: { ...EMPTY_TRANSLATION },
  })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (verse) {
      setCategory(verse.category)
      setDisplayOrder(verse.display_order)
      setTranslations({
        en: verse.translations.en ? { ...verse.translations.en } : { ...EMPTY_TRANSLATION },
        hi: verse.translations.hi ? { ...verse.translations.hi } : { ...EMPTY_TRANSLATION },
        ml: verse.translations.ml ? { ...verse.translations.ml } : { ...EMPTY_TRANSLATION },
      })
    } else {
      setCategory('salvation')
      setDisplayOrder(0)
      setTranslations({
        en: { ...EMPTY_TRANSLATION },
        hi: { ...EMPTY_TRANSLATION },
        ml: { ...EMPTY_TRANSLATION },
      })
    }
    setError(null)
  }, [verse, isOpen])

  const handleTranslationChange = (
    lang: string,
    field: keyof Translation,
    value: string
  ) => {
    setTranslations((prev) => ({
      ...prev,
      [lang]: { ...prev[lang], [field]: value },
    }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!translations.en.reference.trim() || !translations.en.text.trim()) {
      setError('English reference and text are required.')
      return
    }

    // Only include translations that have at least a reference
    const filteredTranslations: Record<string, Translation> = {}
    for (const lang of ['en', 'hi', 'ml']) {
      if (translations[lang].reference.trim()) {
        filteredTranslations[lang] = translations[lang]
      }
    }

    setSaving(true)
    try {
      await onSave({
        id: verse?.id,
        category,
        display_order: displayOrder,
        translations: filteredTranslations,
      })
    } catch (err: any) {
      setError(err.message || 'Failed to save. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="mx-4 w-full max-w-2xl rounded-lg bg-white shadow-xl dark:bg-gray-900">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4 dark:border-gray-700">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white">
            {verse ? 'Edit Suggested Verse' : 'Add Suggested Verse'}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            disabled={saving}
          >
            <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit}>
          <div className="max-h-[70vh] overflow-y-auto px-6 py-4">
            {error && (
              <div className="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-400">
                {error}
              </div>
            )}

            {/* Category + Display Order row */}
            <div className="mb-5 grid grid-cols-2 gap-4">
              <div>
                <label className="mb-1.5 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Category <span className="text-red-500">*</span>
                </label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                  required
                >
                  {CATEGORIES.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat.charAt(0).toUpperCase() + cat.slice(1)}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="mb-1.5 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Display Order
                </label>
                <input
                  type="number"
                  value={displayOrder}
                  onChange={(e) => setDisplayOrder(parseInt(e.target.value) || 0)}
                  min={0}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                />
              </div>
            </div>

            {/* Translation fields */}
            {(['en', 'hi', 'ml'] as const).map((lang) => (
              <div
                key={lang}
                className="mb-5 rounded-lg border border-gray-200 p-4 dark:border-gray-700"
              >
                <div className="mb-3 flex items-center gap-2">
                  <span className="rounded bg-primary px-2 py-0.5 text-xs font-semibold text-white">
                    {lang.toUpperCase()}
                  </span>
                  <span className="text-sm font-semibold text-gray-700 dark:text-gray-300">
                    {LANGUAGE_LABELS[lang]}
                    {lang === 'en' && <span className="ml-1 text-red-500">*</span>}
                  </span>
                  {lang !== 'en' && (
                    <span className="ml-auto text-xs text-gray-400 dark:text-gray-500">Optional</span>
                  )}
                </div>
                <div className="space-y-3">
                  <div>
                    <label className="mb-1 block text-xs text-gray-500 dark:text-gray-400">
                      Reference (e.g., John 3:16)
                    </label>
                    <input
                      type="text"
                      value={translations[lang].reference}
                      onChange={(e) => handleTranslationChange(lang, 'reference', e.target.value)}
                      placeholder="Book Chapter:Verse"
                      required={lang === 'en'}
                      className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-xs text-gray-500 dark:text-gray-400">
                      Verse Text
                    </label>
                    <textarea
                      value={translations[lang].text}
                      onChange={(e) => handleTranslationChange(lang, 'text', e.target.value)}
                      placeholder="Enter verse text..."
                      required={lang === 'en'}
                      rows={4}
                      className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Actions */}
          <div className="flex justify-end gap-3 border-t border-gray-200 px-6 py-4 dark:border-gray-700">
            <button
              type="button"
              onClick={onClose}
              disabled={saving}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-800"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90 disabled:opacity-50"
            >
              {saving ? 'Saving...' : verse ? 'Save Changes' : 'Add Verse'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
