'use client'

import { useState } from 'react'

interface StudyGuide {
  id: string
  input_type: string
  input_value: string
  study_mode: string | null
  language: string
  summary: string
  interpretation: string | null
  total_users: number
  completed_count: number
  in_progress_count: number
  created_at: string
}

interface StudyGuidesTableProps {
  guides: StudyGuide[]
  onEdit: (guide: StudyGuide) => void
  onDelete: (id: string) => void
}

export default function StudyGuidesTable({
  guides,
  onEdit,
  onDelete
}: StudyGuidesTableProps) {
  const [expandedId, setExpandedId] = useState<string | null>(null)

  const getInputTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      verse: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
      topic: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
      passage: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
      question: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
    }
    return colors[type] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
  }

  const getStudyModeColor = (mode: string | null) => {
    const colors: Record<string, string> = {
      standard: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200',
      deep: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200',
      lectio: 'bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-200',
      sermon: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200',
      recommended: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
    }
    return colors[mode || 'standard'] || colors.standard
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Input
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Mode
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Language
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Usage
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Created
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
          {guides.map((guide) => (
            <>
              <tr key={guide.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                <td className="px-6 py-4">
                  <div className="flex flex-col gap-1">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getInputTypeColor(guide.input_type)} w-fit`}>
                      {guide.input_type}
                    </span>
                    <span className="text-sm text-gray-900 dark:text-gray-100 font-medium">
                      {guide.input_value.length > 50 ? guide.input_value.substring(0, 50) + '...' : guide.input_value}
                    </span>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStudyModeColor(guide.study_mode)}`}>
                    {guide.study_mode || 'standard'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                  {guide.language?.toUpperCase() || 'N/A'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm text-gray-900 dark:text-gray-100">
                    <div className="font-medium">{guide.total_users} users</div>
                    <div className="text-gray-500 dark:text-gray-400">
                      {guide.completed_count} completed, {guide.in_progress_count} in progress
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                  {new Date(guide.created_at).toLocaleDateString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    onClick={() => setExpandedId(expandedId === guide.id ? null : guide.id)}
                    className="text-primary hover:text-primary/80 mr-4"
                  >
                    {expandedId === guide.id ? 'Collapse' : 'Expand'}
                  </button>
                  <button
                    onClick={() => onEdit(guide)}
                    className="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300 mr-4"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => {
                      if (confirm('Are you sure you want to delete this study guide? This will remove it for all users.')) {
                        onDelete(guide.id)
                      }
                    }}
                    className="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              {expandedId === guide.id && (
                <tr>
                  <td colSpan={6} className="px-6 py-4 bg-gray-50 dark:bg-gray-800">
                    <div className="space-y-4">
                      <div>
                        <h4 className="text-sm font-semibold text-gray-900 dark:text-gray-100 mb-2">Summary</h4>
                        <p className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                          {guide.summary}
                        </p>
                      </div>
                      {guide.interpretation && (
                        <div>
                          <h4 className="text-sm font-semibold text-gray-900 dark:text-gray-100 mb-2">Interpretation</h4>
                          <p className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                            {guide.interpretation}
                          </p>
                        </div>
                      )}
                    </div>
                  </td>
                </tr>
              )}
            </>
          ))}
        </tbody>
      </table>

      {guides.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 dark:text-gray-400">No study guides found</p>
        </div>
      )}
    </div>
  )
}
