'use client'

import { useState } from 'react'

interface Translation {
  title: string
  description: string
}

interface TranslationEditorProps {
  translations: {
    en?: Translation
    hi?: Translation
    ml?: Translation
  }
  onChange: (translations: {
    en?: Translation
    hi?: Translation
    ml?: Translation
  }) => void
  disabled?: boolean
}

const LANGUAGES = [
  { code: 'hi' as const, name: 'हिन्दी', flag: '🇮🇳' },
  { code: 'ml' as const, name: 'മലയാളം', flag: '🇮🇳' },
]

export function TranslationEditor({
  translations,
  onChange,
  disabled = false,
}: TranslationEditorProps) {
  const [activeTab, setActiveTab] = useState<'hi' | 'ml'>('hi')

  const handleTranslationChange = (
    lang: 'hi' | 'ml',
    field: 'title' | 'description',
    value: string
  ) => {
    onChange({
      ...translations,
      [lang]: {
        ...translations[lang],
        [field]: value,
      },
    })
  }

  const currentTranslation = translations[activeTab] || { title: '', description: '' }

  return (
    <div className="space-y-4">
      {/* Language Tabs */}
      <div className="flex gap-2 border-b border-gray-200">
        {LANGUAGES.map((lang) => (
          <button
            key={lang.code}
            type="button"
            onClick={() => setActiveTab(lang.code)}
            disabled={disabled}
            className={`flex items-center gap-2 px-4 py-2 font-medium transition-colors ${
              activeTab === lang.code
                ? 'border-b-2 border-primary text-primary'
                : 'text-gray-600 hover:text-gray-900'
            } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
          >
            <span className="text-xl">{lang.flag}</span>
            <span>{lang.name}</span>
          </button>
        ))}
      </div>

      {/* Translation Form */}
      <div className="space-y-4">
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-700">
            Title ({LANGUAGES.find((l) => l.code === activeTab)?.name})
          </label>
          <input
            type="text"
            value={currentTranslation.title}
            onChange={(e) =>
              handleTranslationChange(activeTab, 'title', e.target.value)
            }
            placeholder={`Enter title in ${
              LANGUAGES.find((l) => l.code === activeTab)?.name
            }`}
            disabled={disabled}
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 disabled:text-gray-500"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-gray-700">
            Description ({LANGUAGES.find((l) => l.code === activeTab)?.name})
          </label>
          <textarea
            value={currentTranslation.description}
            onChange={(e) =>
              handleTranslationChange(activeTab, 'description', e.target.value)
            }
            placeholder={`Enter description in ${
              LANGUAGES.find((l) => l.code === activeTab)?.name
            }`}
            rows={4}
            disabled={disabled}
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 disabled:text-gray-500"
          />
        </div>

        {/* Translation Status */}
        <div className="flex gap-4 text-sm">
          {LANGUAGES.map((lang) => {
            const hasTranslation =
              translations[lang.code]?.title && translations[lang.code]?.description
            return (
              <div
                key={lang.code}
                className={`flex items-center gap-1 ${
                  hasTranslation ? 'text-green-600' : 'text-gray-400'
                }`}
              >
                <span>{lang.flag}</span>
                <span>{hasTranslation ? 'Complete' : 'Missing'}</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
