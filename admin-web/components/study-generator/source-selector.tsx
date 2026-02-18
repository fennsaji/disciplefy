'use client'

import { useState, useEffect } from 'react'
import { StudyModeSelector } from '@/components/ui/study-mode-selector'
import type { RecommendedTopic, StudyMode, InputType } from '@/types/admin'
import { listTopicsWithGuides } from '@/lib/api/admin'

interface SourceSelectorProps {
  onGenerate: (config: GenerationConfig) => void
  disabled?: boolean
  initialTopicId?: string
  initialPathId?: string
  initialInputType?: InputType
  initialInputValue?: string
  initialStudyMode?: StudyMode
  initialLanguage?: 'en' | 'hi' | 'ml'
}

export interface GenerationConfig {
  source: 'topic' | 'custom'
  topic_id?: string
  input_type?: InputType
  input_value?: string
  study_mode: StudyMode
  language: 'en' | 'hi' | 'ml'
  learning_path_id?: string
}

type SourceType = 'topic' | 'custom'

export function SourceSelector({
  onGenerate,
  disabled = false,
  initialTopicId,
  initialPathId,
  initialInputType,
  initialInputValue,
  initialStudyMode,
  initialLanguage,
}: SourceSelectorProps) {
  // Determine initial source type: if we have custom input params, use 'custom', otherwise 'topic'
  const hasCustomInput = initialInputType && initialInputValue
  const [sourceType, setSourceType] = useState<SourceType>(hasCustomInput ? 'custom' : 'topic')
  const [topics, setTopics] = useState<RecommendedTopic[]>([])
  const [selectedTopicId, setSelectedTopicId] = useState<string>(initialTopicId || '')
  const [searchQuery, setSearchQuery] = useState('')
  const [isLoadingTopics, setIsLoadingTopics] = useState(false)
  const [pathId] = useState<string | undefined>(initialPathId)
  const [isTopicLocked, setIsTopicLocked] = useState<boolean>(!!initialTopicId) // Lock topic if provided via URL

  // Custom input fields - use initial values from URL if provided
  const [inputType, setInputType] = useState<InputType>(initialInputType || 'topic')
  const [inputValue, setInputValue] = useState(initialInputValue || '')

  // Study configuration - use initial values from URL if provided
  const [studyMode, setStudyMode] = useState<StudyMode>(initialStudyMode || 'standard')
  const [language, setLanguage] = useState<'en' | 'hi' | 'ml'>(initialLanguage || 'en')

  const [errors, setErrors] = useState<Record<string, string>>({})

  // Load topics
  useEffect(() => {
    if (sourceType === 'topic') {
      loadTopics()
    }
  }, [sourceType])

  const loadTopics = async () => {
    setIsLoadingTopics(true)
    try {
      const response = await listTopicsWithGuides({ is_active: true })
      setTopics(response.topics || [])
    } catch (err) {
      console.error('Failed to load topics:', err)
    } finally {
      setIsLoadingTopics(false)
    }
  }

  const filteredTopics = topics.filter((topic) =>
    topic.title.toLowerCase().includes(searchQuery.toLowerCase())
  )

  const selectedTopic = topics.find((t) => t.id === selectedTopicId)

  const handleClearTopic = () => {
    setIsTopicLocked(false)
    setSelectedTopicId('')
  }

  const validateAndGenerate = () => {
    const newErrors: Record<string, string> = {}

    if (sourceType === 'topic') {
      if (!selectedTopicId) {
        newErrors.topic = 'Please select a topic'
      }
    } else {
      if (!inputValue.trim()) {
        newErrors.input = 'Please enter an input value'
      }
    }

    setErrors(newErrors)

    if (Object.keys(newErrors).length === 0) {
      const config: GenerationConfig = {
        source: sourceType,
        study_mode: studyMode,
        language,
      }

      if (sourceType === 'topic') {
        config.topic_id = selectedTopicId
      } else {
        config.input_type = inputType
        config.input_value = inputValue.trim()
      }

      // Include path ID if provided
      if (pathId) {
        config.learning_path_id = pathId
      }

      onGenerate(config)
    }
  }

  return (
    <div className="space-y-6 rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
      <div>
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Study Guide Source</h2>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Choose to generate from an existing topic or create a custom study guide
        </p>
      </div>


      {/* Source Type Selection */}
      <div className="space-y-3">
        <label className="flex cursor-pointer items-start gap-3 rounded-lg border-2 border-gray-200 p-4 transition-colors hover:border-gray-300 dark:border-gray-600 dark:hover:border-gray-500">
          <input
            type="radio"
            name="source-type"
            value="topic"
            checked={sourceType === 'topic'}
            onChange={(e) => setSourceType(e.target.value as SourceType)}
            disabled={disabled}
            className="mt-1 h-4 w-4 text-primary focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50"
          />
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <span className="text-xl">📚</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">Existing Topic</span>
            </div>
            <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
              Generate a study guide from a pre-configured topic in your library
            </p>
          </div>
        </label>

        <label className="flex cursor-pointer items-start gap-3 rounded-lg border-2 border-gray-200 p-4 transition-colors hover:border-gray-300 dark:border-gray-600 dark:hover:border-gray-500">
          <input
            type="radio"
            name="source-type"
            value="custom"
            checked={sourceType === 'custom'}
            onChange={(e) => setSourceType(e.target.value as SourceType)}
            disabled={disabled}
            className="mt-1 h-4 w-4 text-primary focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50"
          />
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <span className="text-xl">✨</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">Custom Input</span>
            </div>
            <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
              Create a one-time study guide with custom input (topic, verse, or question)
            </p>
          </div>
        </label>
      </div>

      {/* Topic Selection */}
      {sourceType === 'topic' && (
        <div className="space-y-3">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
            Select Topic <span className="text-red-500">*</span>
          </label>

          {/* Show selected topic if locked */}
          {isTopicLocked && selectedTopic ? (
            <div className="rounded-lg border-2 border-primary bg-primary-50 p-4 dark:border-primary-600 dark:bg-primary-900/20">
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">📚</span>
                    <p className="font-semibold text-gray-900 dark:text-gray-100">{selectedTopic.title}</p>
                  </div>
                  <div className="mt-2 flex flex-wrap items-center gap-2 text-xs">
                    <span className="rounded-full bg-purple-100 px-2 py-0.5 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300">
                      {selectedTopic.category}
                    </span>
                    <span className="rounded-full bg-yellow-100 px-2 py-0.5 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300">
                      {selectedTopic.xp_value} XP
                    </span>
                    {(selectedTopic as any).has_guides && (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-300">
                        📚 {(selectedTopic as any).generated_guides_count} {(selectedTopic as any).generated_guides_count === 1 ? 'guide' : 'guides'}
                      </span>
                    )}
                  </div>
                  {selectedTopic.description && (
                    <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">{selectedTopic.description}</p>
                  )}
                </div>
                <button
                  type="button"
                  onClick={handleClearTopic}
                  disabled={disabled}
                  className="rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
                  title="Choose a different topic"
                >
                  Change
                </button>
              </div>
            </div>
          ) : (
            <>
              {/* Search */}
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search topics..."
                disabled={disabled}
                className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 disabled:text-gray-500 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400 dark:disabled:bg-gray-800"
              />

              {/* Topics List */}
              {isLoadingTopics ? (
                <div className="flex items-center justify-center py-8">
                  <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
                </div>
              ) : (
                <div className="max-h-64 space-y-2 overflow-y-auto rounded-lg border border-gray-200 bg-gray-50 p-3 dark:border-gray-600 dark:bg-gray-700">
                  {filteredTopics.length === 0 ? (
                    <p className="py-4 text-center text-sm text-gray-500 dark:text-gray-400">
                      {searchQuery ? 'No topics found' : 'No active topics available'}
                    </p>
                  ) : (
                    filteredTopics.map((topic) => (
                      <label
                        key={topic.id}
                        className={`flex cursor-pointer items-start gap-3 rounded-lg border-2 p-3 transition-colors ${
                          selectedTopicId === topic.id
                            ? 'border-primary bg-primary-50 dark:bg-primary-900/20'
                            : 'border-gray-200 bg-white hover:border-gray-300 dark:border-gray-600 dark:bg-gray-800 dark:hover:border-gray-500'
                        } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
                      >
                        <input
                          type="radio"
                          name="topic"
                          value={topic.id}
                          checked={selectedTopicId === topic.id}
                          onChange={(e) => setSelectedTopicId(e.target.value)}
                          disabled={disabled}
                          className="mt-1 h-4 w-4 text-primary focus:ring-primary disabled:cursor-not-allowed"
                        />
                        <div className="flex-1">
                          <p className="font-medium text-gray-900 dark:text-gray-100">{topic.title}</p>
                          <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-gray-500">
                            <span className="rounded-full bg-purple-100 px-2 py-0.5 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300">
                              {topic.category}
                            </span>
                            <span className="rounded-full bg-yellow-100 px-2 py-0.5 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300">
                              {topic.xp_value} XP
                            </span>
                        <span
                          className={`rounded-full px-2 py-0.5 ${
                            topic.input_type === 'topic'
                              ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300'
                              : topic.input_type === 'verse'
                                ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300'
                                : 'bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-300'
                          }`}
                        >
                          {topic.input_type}
                        </span>
                        {(topic as any).has_guides && (
                          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-300">
                            📚 {(topic as any).generated_guides_count} {(topic as any).generated_guides_count === 1 ? 'guide' : 'guides'}
                          </span>
                        )}
                      </div>
                    </div>
                  </label>
                ))
              )}
            </div>
          )}
            </>
          )}

          {errors.topic && (
            <p className="text-xs text-red-600 dark:text-red-400">{errors.topic}</p>
          )}
        </div>
      )}

      {/* Custom Input */}
      {sourceType === 'custom' && (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Input Type
            </label>
            <div className="mt-2 grid gap-2 md:grid-cols-3">
              {[
                { value: 'topic', icon: '📖', label: 'Topic' },
                { value: 'verse', icon: '📜', label: 'Verse' },
                { value: 'question', icon: '❓', label: 'Question' },
              ].map((type) => (
                <label
                  key={type.value}
                  className={`flex cursor-pointer items-center gap-2 rounded-lg border-2 p-3 transition-colors ${
                    inputType === type.value
                      ? 'border-primary bg-primary-50 dark:bg-primary-900/20'
                      : 'border-gray-200 hover:border-gray-300 dark:border-gray-600 dark:hover:border-gray-500'
                  } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
                >
                  <input
                    type="radio"
                    name="input-type"
                    value={type.value}
                    checked={inputType === type.value}
                    onChange={(e) => setInputType(e.target.value as InputType)}
                    disabled={disabled}
                    className="h-4 w-4 text-primary focus:ring-primary disabled:cursor-not-allowed"
                  />
                  <span className="text-xl">{type.icon}</span>
                  <span className="font-medium text-gray-900 dark:text-gray-100">{type.label}</span>
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Input Value <span className="text-red-500">*</span>
            </label>
            <textarea
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              rows={3}
              disabled={disabled}
              placeholder={
                inputType === 'topic'
                  ? 'e.g., The Trinity, Salvation by Grace'
                  : inputType === 'verse'
                    ? 'e.g., John 3:16, Romans 8:28-39'
                    : 'e.g., What is the meaning of faith?'
              }
              className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 disabled:text-gray-500 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400 dark:disabled:bg-gray-800"
            />
            {errors.input && (
              <p className="mt-1 text-xs text-red-600 dark:text-red-400">{errors.input}</p>
            )}
          </div>
        </div>
      )}

      {/* Study Mode */}
      <div>
        <StudyModeSelector
          selectedMode={studyMode}
          onChange={setStudyMode}
          disabled={disabled}
        />
      </div>

      {/* Language Selection */}
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Language
        </label>
        <div className="mt-2 flex gap-2">
          {[
            { value: 'en', label: '🇺🇸 English' },
            { value: 'hi', label: '🇮🇳 हिन्दी' },
            { value: 'ml', label: '🇮🇳 മലയാളം' },
          ].map((lang) => (
            <label
              key={lang.value}
              className={`flex flex-1 cursor-pointer items-center justify-center gap-2 rounded-lg border-2 p-3 transition-colors ${
                language === lang.value
                  ? 'border-primary bg-primary-50 dark:bg-primary-900/20'
                  : 'border-gray-200 hover:border-gray-300 dark:border-gray-600 dark:hover:border-gray-500'
              } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
            >
              <input
                type="radio"
                name="language"
                value={lang.value}
                checked={language === lang.value}
                onChange={(e) =>
                  setLanguage(e.target.value as 'en' | 'hi' | 'ml')
                }
                disabled={disabled}
                className="sr-only"
              />
              <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                {lang.label}
              </span>
            </label>
          ))}
        </div>
      </div>

      {/* Generate Button */}
      <button
        type="button"
        onClick={validateAndGenerate}
        disabled={disabled}
        className="flex w-full items-center justify-center gap-2 rounded-lg bg-primary px-6 py-3 text-base font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50 dark:hover:bg-primary-700"
      >
        <svg
          className="h-5 w-5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M13 10V3L4 14h7v7l9-11h-7z"
          />
        </svg>
        {disabled ? 'Generating...' : 'Generate Study Guide'}
      </button>
    </div>
  )
}
