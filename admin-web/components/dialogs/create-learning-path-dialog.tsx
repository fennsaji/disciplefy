'use client'

import { useState } from 'react'
import { TranslationEditor } from '@/components/ui/translation-editor'
import { IconColorPicker } from '@/components/ui/icon-color-picker'
import { StudyModeSelector } from '@/components/ui/study-mode-selector'
import type {
  CreateLearningPathRequest,
  DifficultyLevel,
  DiscipleLevel,
  StudyMode,
} from '@/types/admin'

interface CreateLearningPathDialogProps {
  isOpen: boolean
  onClose: () => void
  onSubmit: (data: CreateLearningPathRequest) => Promise<void>
}

type TabType = 'basic' | 'visual' | 'settings' | 'translations'

export function CreateLearningPathDialog({
  isOpen,
  onClose,
  onSubmit,
}: CreateLearningPathDialogProps) {
  const [activeTab, setActiveTab] = useState<TabType>('basic')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  // Form state
  const [formData, setFormData] = useState<CreateLearningPathRequest>({
    slug: '',
    title: '',
    description: '',
    icon_name: 'book',
    color: '#6A4FB6',
    estimated_days: 7,
    difficulty_level: 'beginner',
    disciple_level: 'seeker',
    recommended_mode: 'standard',
    is_featured: false,
    is_active: true,
    allow_non_sequential_access: false,
    translations: {
      en: { title: '', description: '' },
    },
  })

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {}

    if (!formData.slug) newErrors.slug = 'Slug is required'
    if (!formData.title) newErrors.title = 'Title is required'
    if (!formData.description) newErrors.description = 'Description is required'
    if (formData.estimated_days < 1)
      newErrors.estimated_days = 'Must be at least 1 day'

    // Validate slug format (lowercase, hyphens only)
    if (formData.slug && !/^[a-z0-9-]+$/.test(formData.slug)) {
      newErrors.slug = 'Slug must contain only lowercase letters, numbers, and hyphens'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) {
      return
    }

    setIsSubmitting(true)
    try {
      await onSubmit(formData)
      onClose()
      // Reset form
      setFormData({
        slug: '',
        title: '',
        description: '',
        icon_name: 'book',
        color: '#6A4FB6',
        estimated_days: 7,
        difficulty_level: 'beginner',
        disciple_level: 'seeker',
        recommended_mode: 'standard',
        is_featured: false,
        is_active: true,
        allow_non_sequential_access: false,
        translations: {
          en: { title: '', description: '' },
        },
      })
      setActiveTab('basic')
      setErrors({})
    } catch (error) {
      console.error('Failed to create learning path:', error)
      setErrors({ submit: 'Failed to create learning path. Please try again.' })
    } finally {
      setIsSubmitting(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="max-h-[90vh] w-full max-w-3xl overflow-hidden rounded-lg bg-white shadow-xl">
        {/* Header */}
        <div className="border-b border-gray-200 px-6 py-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold text-gray-900">
              Create Learning Path
            </h2>
            <button
              type="button"
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600"
            >
              <svg
                className="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="border-b border-gray-200 bg-gray-50 px-6">
          <nav className="flex gap-4">
            {[
              { id: 'basic', label: 'Basic Info' },
              { id: 'visual', label: 'Visual' },
              { id: 'settings', label: 'Settings' },
              { id: 'translations', label: 'Translations' },
            ].map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id as TabType)}
                className={`border-b-2 px-4 py-3 text-sm font-medium transition-colors ${
                  activeTab === tab.id
                    ? 'border-primary text-primary'
                    : 'border-transparent text-gray-600 hover:text-gray-900'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </nav>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="max-h-[60vh] overflow-y-auto p-6">
          {/* Basic Info Tab */}
          {activeTab === 'basic' && (
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Slug <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.slug}
                  onChange={(e) =>
                    setFormData({ ...formData, slug: e.target.value.toLowerCase() })
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                  placeholder="faith-foundations"
                />
                <p className="mt-1 text-xs text-gray-500">
                  Lowercase letters, numbers, and hyphens only
                </p>
                {errors.slug && (
                  <p className="mt-1 text-xs text-red-600">{errors.slug}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Title <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) =>
                    setFormData({ ...formData, title: e.target.value })
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                  placeholder="Faith Foundations"
                />
                {errors.title && (
                  <p className="mt-1 text-xs text-red-600">{errors.title}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Description <span className="text-red-500">*</span>
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) =>
                    setFormData({ ...formData, description: e.target.value })
                  }
                  rows={4}
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                  placeholder="Build strong foundations in Christian faith..."
                />
                {errors.description && (
                  <p className="mt-1 text-xs text-red-600">{errors.description}</p>
                )}
              </div>
            </div>
          )}

          {/* Visual Tab */}
          {activeTab === 'visual' && (
            <div>
              <IconColorPicker
                selectedIcon={formData.icon_name}
                selectedColor={formData.color}
                onIconChange={(icon) =>
                  setFormData({ ...formData, icon_name: icon })
                }
                onColorChange={(color) =>
                  setFormData({ ...formData, color })
                }
              />
            </div>
          )}

          {/* Settings Tab */}
          {activeTab === 'settings' && (
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Estimated Days
                </label>
                <input
                  type="number"
                  min="1"
                  value={formData.estimated_days}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      estimated_days: parseInt(e.target.value) || 1,
                    })
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                />
                {errors.estimated_days && (
                  <p className="mt-1 text-xs text-red-600">
                    {errors.estimated_days}
                  </p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Difficulty Level
                </label>
                <select
                  value={formData.difficulty_level}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      difficulty_level: e.target.value as DifficultyLevel,
                    })
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  <option value="beginner">Beginner</option>
                  <option value="intermediate">Intermediate</option>
                  <option value="advanced">Advanced</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Disciple Level
                </label>
                <select
                  value={formData.disciple_level}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      disciple_level: e.target.value as DiscipleLevel,
                    })
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  <option value="seeker">Seeker</option>
                  <option value="follower">Follower</option>
                  <option value="disciple">Disciple</option>
                  <option value="leader">Leader</option>
                </select>
              </div>

              <StudyModeSelector
                selectedMode={formData.recommended_mode}
                onChange={(mode) =>
                  setFormData({ ...formData, recommended_mode: mode })
                }
              />

              <div className="space-y-3">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_featured}
                    onChange={(e) =>
                      setFormData({ ...formData, is_featured: e.target.checked })
                    }
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                  />
                  <span className="text-sm text-gray-700">Featured Path</span>
                </label>

                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={(e) =>
                      setFormData({ ...formData, is_active: e.target.checked })
                    }
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                  />
                  <span className="text-sm text-gray-700">Active</span>
                </label>

                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.allow_non_sequential_access}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        allow_non_sequential_access: e.target.checked,
                      })
                    }
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                  />
                  <span className="text-sm text-gray-700">
                    Allow Non-Sequential Access
                  </span>
                </label>
              </div>
            </div>
          )}

          {/* Translations Tab */}
          {activeTab === 'translations' && (
            <div>
              <TranslationEditor
                translations={formData.translations || {}}
                onChange={(translations) =>
                  setFormData({ ...formData, translations })
                }
              />
            </div>
          )}

          {/* Error Message */}
          {errors.submit && (
            <div className="mt-4 rounded-lg bg-red-50 p-4">
              <p className="text-sm text-red-800">{errors.submit}</p>
            </div>
          )}
        </form>

        {/* Footer */}
        <div className="border-t border-gray-200 bg-gray-50 px-6 py-4">
          <div className="flex justify-end gap-3">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              onClick={handleSubmit}
              disabled={isSubmitting}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isSubmitting ? 'Creating...' : 'Create Path'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
