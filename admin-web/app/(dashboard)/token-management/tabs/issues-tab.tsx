'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

interface PurchaseIssue {
  id: string
  user_id: string
  user_email?: string
  order_id?: string
  payment_id?: string
  issue_type: string
  description: string
  status: string
  admin_notes?: string
  resolved_at?: string
  created_at: string
}

export default function IssuesTab() {
  const [statusFilter, setStatusFilter] = useState('all')
  const [selectedIssue, setSelectedIssue] = useState<PurchaseIssue | null>(null)
  const [adminNotes, setAdminNotes] = useState('')
  const [newStatus, setNewStatus] = useState('pending')
  const queryClient = useQueryClient()

  const { data: issues, isLoading } = useQuery<PurchaseIssue[]>({
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

  const updateIssueMutation = useMutation({
    mutationFn: async (data: { issue_id: string; status: string; admin_notes: string }) => {
      const response = await fetch('/api/admin/update-purchase-issue', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(data),
      })
      if (!response.ok) throw new Error('Failed to update issue')
      return response.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['purchase-issues'] })
      setSelectedIssue(null)
      setAdminNotes('')
    },
  })

  const handleUpdateIssue = () => {
    if (!selectedIssue) return

    updateIssueMutation.mutate({
      issue_id: selectedIssue.id,
      status: newStatus,
      admin_notes: adminNotes,
    })
  }

  const formatDateTime = (date: string) => {
    return new Date(date).toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex items-center gap-4">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="all">All Issues</option>
          <option value="pending">Pending</option>
          <option value="investigating">Investigating</option>
          <option value="resolved">Resolved</option>
          <option value="closed">Closed</option>
        </select>

        {issues && (
          <div className="text-sm text-gray-600 dark:text-gray-400">
            {issues.length} issue{issues.length !== 1 ? 's' : ''} found
          </div>
        )}
      </div>

      {/* Issues List */}
      {isLoading ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-gray-500">Loading issues...</div>
        </div>
      ) : !issues || issues.length === 0 ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-center">
            <div className="text-gray-500">No issues found</div>
            <p className="mt-1 text-sm text-gray-400">Great! No purchase problems reported.</p>
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          {issues.map((issue) => (
            <div
              key={issue.id}
              className="rounded-lg border border-gray-200 bg-white p-4 hover:border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:hover:border-gray-600"
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  {/* Header */}
                  <div className="flex items-center gap-3">
                    <span className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                      issue.status === 'resolved' ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' :
                      issue.status === 'investigating' ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' :
                      issue.status === 'closed' ? 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200' :
                      'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                    }`}>
                      {issue.status}
                    </span>
                    <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                      {issue.issue_type.replace(/_/g, ' ')}
                    </span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">
                      {formatDateTime(issue.created_at)}
                    </span>
                  </div>

                  {/* User Info */}
                  <div className="mt-2 text-sm text-gray-600 dark:text-gray-400">
                    <span className="font-medium">User:</span> {issue.user_email || issue.user_id}
                  </div>

                  {/* Payment IDs */}
                  {(issue.payment_id || issue.order_id) && (
                    <div className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                      {issue.payment_id && <span className="mr-4">Payment: {issue.payment_id}</span>}
                      {issue.order_id && <span>Order: {issue.order_id}</span>}
                    </div>
                  )}

                  {/* Description */}
                  <div className="mt-3 text-sm text-gray-900 dark:text-gray-100">
                    <p className="font-medium">Description:</p>
                    <p className="mt-1 whitespace-pre-wrap">{issue.description}</p>
                  </div>

                  {/* Admin Notes */}
                  {issue.admin_notes && (
                    <div className="mt-3 rounded bg-blue-50 p-3 dark:bg-blue-900/20">
                      <p className="text-sm font-medium text-blue-900 dark:text-blue-100">Admin Notes:</p>
                      <p className="mt-1 text-sm text-blue-800 dark:text-blue-200">{issue.admin_notes}</p>
                    </div>
                  )}

                  {/* Resolved At */}
                  {issue.resolved_at && (
                    <div className="mt-2 text-sm text-gray-500 dark:text-gray-400">
                      Resolved: {formatDateTime(issue.resolved_at)}
                    </div>
                  )}
                </div>

                {/* Action Button */}
                <button
                  onClick={() => {
                    setSelectedIssue(issue)
                    setNewStatus(issue.status)
                    setAdminNotes(issue.admin_notes || '')
                  }}
                  className="ml-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
                >
                  Update
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Update Modal */}
      {selectedIssue && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div className="w-full max-w-2xl rounded-lg bg-white p-6 dark:bg-gray-800">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              Update Issue
            </h3>

            <div className="mt-4 space-y-4">
              {/* Issue Summary */}
              <div className="rounded-lg bg-gray-50 p-4 dark:bg-gray-900">
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  <span className="font-medium">User:</span> {selectedIssue.user_email || selectedIssue.user_id}
                </p>
                <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                  <span className="font-medium">Type:</span> {selectedIssue.issue_type.replace(/_/g, ' ')}
                </p>
                <p className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {selectedIssue.description}
                </p>
              </div>

              {/* New Status */}
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Status
                </label>
                <select
                  value={newStatus}
                  onChange={(e) => setNewStatus(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                >
                  <option value="pending">Pending</option>
                  <option value="investigating">Investigating</option>
                  <option value="resolved">Resolved</option>
                  <option value="closed">Closed</option>
                </select>
              </div>

              {/* Admin Notes */}
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Admin Notes
                </label>
                <textarea
                  value={adminNotes}
                  onChange={(e) => setAdminNotes(e.target.value)}
                  rows={4}
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                  placeholder="Add notes about how this was resolved..."
                />
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-3">
              <button
                onClick={() => {
                  setSelectedIssue(null)
                  setAdminNotes('')
                }}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleUpdateIssue}
                disabled={updateIssueMutation.isPending}
                className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50"
              >
                {updateIssueMutation.isPending ? 'Updating...' : 'Update Issue'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
