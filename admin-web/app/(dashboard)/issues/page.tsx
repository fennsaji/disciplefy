'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { FeedbackTable } from '@/components/tables/feedback-table'
import { PurchaseIssuesTable } from '@/components/tables/purchase-issues-table'

type TabType = 'purchase-issues' | 'feedback'

export default function IssuesPage() {
  const [activeTab, setActiveTab] = useState<TabType>('purchase-issues')

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">⚠️ Issues & Feedback</h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          Manage purchase issues and user feedback
        </p>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200 dark:border-gray-700">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('purchase-issues')}
            className={`flex items-center gap-2 whitespace-nowrap border-b-2 px-1 py-4 text-sm font-medium ${
              activeTab === 'purchase-issues'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            <span className="text-lg">💳</span>
            Purchase Issues
          </button>
          <button
            onClick={() => setActiveTab('feedback')}
            className={`flex items-center gap-2 whitespace-nowrap border-b-2 px-1 py-4 text-sm font-medium ${
              activeTab === 'feedback'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            <span className="text-lg">💬</span>
            User Feedback
          </button>
        </nav>
      </div>

      {/* Tab Content */}
      <div className="mt-6">
        {activeTab === 'purchase-issues' && <PurchaseIssuesTab />}
        {activeTab === 'feedback' && <FeedbackTab />}
      </div>
    </div>
  )
}

function PurchaseIssuesTab() {
  const [statusFilter, setStatusFilter] = useState('all')

  const { data: issues, isLoading } = useQuery({
    queryKey: ['purchase-issues', statusFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (statusFilter !== 'all') params.append('status', statusFilter)

      const response = await fetch(`/api/admin/purchase-issues?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch issues')
      return response.json()
    },
  })

  return (
    <div className="space-y-6">
      {/* Filter */}
      <div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="all">All Status</option>
          <option value="pending">Pending</option>
          <option value="investigating">Investigating</option>
          <option value="resolved">Resolved</option>
          <option value="closed">Closed</option>
        </select>
      </div>

      {/* Purchase Issues Table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">Purchase Issues</h2>

        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading issues...</div>
          </div>
        ) : (
          <PurchaseIssuesTable issues={issues || []} />
        )}
      </div>
    </div>
  )
}

function FeedbackTab() {
  const [categoryFilter, setCategoryFilter] = useState('all')
  const [helpfulFilter, setHelpfulFilter] = useState('all')

  const { data: feedback, isLoading } = useQuery({
    queryKey: ['feedback', categoryFilter, helpfulFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (categoryFilter !== 'all') params.append('category', categoryFilter)
      if (helpfulFilter !== 'all') params.append('helpful', helpfulFilter)

      const response = await fetch(`/api/admin/feedback?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch feedback')
      return response.json()
    },
  })

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex items-center gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Category:
          </label>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="all">All Categories</option>
            <option value="general">General</option>
            <option value="bug_report">Bug Report</option>
            <option value="feature_request">Feature Request</option>
            <option value="content_feedback">Content Feedback</option>
            <option value="study_guide">Study Guide</option>
            <option value="memory_verse">Memory Verse</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Helpful:
          </label>
          <select
            value={helpfulFilter}
            onChange={(e) => setHelpfulFilter(e.target.value)}
            className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="all">All Feedback</option>
            <option value="true">👍 Helpful</option>
            <option value="false">👎 Not Helpful</option>
          </select>
        </div>
      </div>

      {/* Stats Summary */}
      {feedback && feedback.length > 0 && (
        <div className="grid gap-4 md:grid-cols-4">
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Feedback</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
              {feedback.length}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Helpful</p>
            <p className="mt-1 text-2xl font-bold text-green-600 dark:text-green-400">
              {feedback.filter((f: any) => f.was_helpful).length}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Not Helpful</p>
            <p className="mt-1 text-2xl font-bold text-red-600 dark:text-red-400">
              {feedback.filter((f: any) => !f.was_helpful).length}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Avg Sentiment</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
              {(feedback
                .filter((f: any) => f.sentiment_score !== null)
                .reduce((sum: number, f: any) => sum + f.sentiment_score, 0) /
                feedback.filter((f: any) => f.sentiment_score !== null).length || 0
              ).toFixed(2)}
            </p>
          </div>
        </div>
      )}

      {/* Feedback Table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">User Feedback</h2>

        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading feedback...</div>
          </div>
        ) : (
          <FeedbackTable feedback={feedback || []} />
        )}
      </div>
    </div>
  )
}
