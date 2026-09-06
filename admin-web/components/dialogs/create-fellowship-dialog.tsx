'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface CreateFellowshipDialogProps {
  isOpen: boolean
  onClose: () => void
  onCreated: () => void
}

const initialForm = {
  name: '',
  description: '',
  language: 'en',
  is_public: false,
  unlimited_members: false,
  is_official: false,
  discipler_allowed: false,
  daily_post_allowed: false,
  mentor_email: '',
}

export default function CreateFellowshipDialog({ isOpen, onClose, onCreated }: CreateFellowshipDialogProps) {
  const [form, setForm] = useState(initialForm)
  const [isSubmitting, setIsSubmitting] = useState(false)

  if (!isOpen) return null

  const handleClose = () => {
    setForm(initialForm)
    onClose()
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)
    try {
      const response = await fetch('/api/admin/fellowships', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(form),
      })
      const json = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(json.error || 'Failed to create fellowship')
      toast.success('Fellowship created')
      setForm(initialForm)
      onCreated()
      onClose()
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to create fellowship')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-xl font-bold text-gray-900 dark:text-gray-100">Create fellowship</h2>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4 max-h-[80vh] overflow-y-auto">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Name</label>
            <input
              type="text"
              required
              minLength={3}
              maxLength={60}
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Description</label>
            <textarea
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              maxLength={500}
              rows={3}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Language</label>
            <select
              value={form.language}
              onChange={(e) => setForm({ ...form, language: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            >
              <option value="en">English</option>
              <option value="hi">Hindi</option>
              <option value="ml">Malayalam</option>
            </select>
          </div>

          <label className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={form.is_public}
              onChange={(e) => setForm({ ...form, is_public: e.target.checked })}
              className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary"
            />
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Public</span>
          </label>

          <label className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={form.unlimited_members}
              onChange={(e) => setForm({ ...form, unlimited_members: e.target.checked })}
              className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary"
            />
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Unlimited members</span>
          </label>

          <label className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={form.is_official}
              onChange={(e) => {
                const isOfficial = e.target.checked
                setForm({
                  ...form,
                  is_official: isOfficial,
                  discipler_allowed: isOfficial ? form.discipler_allowed : false,
                  daily_post_allowed: isOfficial ? form.daily_post_allowed : false,
                })
              }}
              className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary"
            />
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Official</span>
          </label>

          <label className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={form.discipler_allowed}
              disabled={!form.is_official}
              onChange={(e) => setForm({ ...form, discipler_allowed: e.target.checked })}
              className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50"
            />
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Allow Discipler replies</span>
          </label>

          <label className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={form.daily_post_allowed}
              disabled={!form.is_official}
              onChange={(e) => setForm({ ...form, daily_post_allowed: e.target.checked })}
              className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50"
            />
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Allow daily study post</span>
          </label>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Mentor email</label>
            <input
              type="email"
              required
              value={form.mentor_email}
              onChange={(e) => setForm({ ...form, mentor_email: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
          </div>

          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={handleClose}
              className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex-1 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isSubmitting ? 'Creating...' : 'Create'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
