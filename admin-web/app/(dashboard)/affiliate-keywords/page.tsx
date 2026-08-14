'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { format } from 'date-fns'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { PageHeader } from '@/components/ui/page-header'
import {
  listAffiliateKeywords,
  createAffiliateKeyword,
  toggleAffiliateKeyword,
  deleteAffiliateKeyword,
} from '@/lib/api/admin'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'

export default function AffiliateKeywordsPage() {
  const [newKeyword, setNewKeyword] = useState('')
  const queryClient = useQueryClient()

  const { data, isLoading, error } = useQuery({
    queryKey: ['affiliate-keywords'],
    queryFn: listAffiliateKeywords,
  })

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['affiliate-keywords'] })

  const createMutation = useMutation({
    mutationFn: createAffiliateKeyword,
    onSuccess: () => {
      invalidate()
      setNewKeyword('')
      toast.success('Keyword added')
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Failed to add keyword'),
  })

  const toggleMutation = useMutation({
    mutationFn: toggleAffiliateKeyword,
    onSuccess: () => {
      invalidate()
      toast.success('Keyword updated')
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Failed to update keyword'),
  })

  const deleteMutation = useMutation({
    mutationFn: deleteAffiliateKeyword,
    onSuccess: () => {
      invalidate()
      toast.success('Keyword deleted')
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Failed to delete keyword'),
  })

  const submit = () => {
    const keyword = newKeyword.trim()
    if (!keyword) return
    createMutation.mutate({ keyword })
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Affiliate Keywords"
        description="Terms auto-linked to Amazon affiliate search results in marketing blog posts (max 3 links per post, first occurrence only)"
      />

      {error && (
        <ErrorState
          title="Error loading affiliate keywords"
          message={error instanceof Error ? error.message : 'Unknown error'}
        />
      )}
      {isLoading && <LoadingState label="Loading affiliate keywords..." />}

      {data && (
        <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
          {/* Inline add row */}
          <div className="mb-6 flex gap-2">
            <input
              type="text"
              value={newKeyword}
              onChange={(e) => setNewKeyword(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && submit()}
              placeholder="e.g. ESV Study Bible"
              maxLength={80}
              className="flex-1 rounded-lg border border-gray-300 px-4 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            />
            <button
              type="button"
              onClick={submit}
              disabled={createMutation.isPending || !newKeyword.trim()}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50"
            >
              Add Keyword
            </button>
          </div>

          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-gray-200 text-gray-500 dark:border-gray-700 dark:text-gray-400">
                <th className="pb-2 font-medium">Keyword</th>
                <th className="pb-2 font-medium">Active</th>
                <th className="pb-2 font-medium">Created</th>
                <th className="pb-2 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.keywords.map((kw) => (
                <tr key={kw.id} className="border-b border-gray-100 last:border-0 dark:border-gray-700">
                  <td className="py-3 font-medium text-gray-900 dark:text-gray-100">{kw.keyword}</td>
                  <td className="py-3">
                    <button
                      type="button"
                      role="switch"
                      aria-checked={kw.is_active}
                      onClick={() => toggleMutation.mutate({ id: kw.id, is_active: !kw.is_active })}
                      className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                        kw.is_active ? 'bg-primary' : 'bg-gray-300 dark:bg-gray-600'
                      }`}
                    >
                      <span
                        className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                          kw.is_active ? 'translate-x-6' : 'translate-x-1'
                        }`}
                      />
                    </button>
                  </td>
                  <td className="py-3 text-gray-500 dark:text-gray-400">
                    {format(new Date(kw.created_at), 'MMM dd, yyyy')}
                  </td>
                  <td className="py-3 text-right">
                    <button
                      type="button"
                      onClick={() => {
                        if (confirm(`Delete keyword "${kw.keyword}"?`)) {
                          deleteMutation.mutate({ id: kw.id })
                        }
                      }}
                      className="text-sm font-medium text-red-600 hover:text-red-700 dark:text-red-400"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
              {data.keywords.length === 0 && (
                <tr>
                  <td colSpan={4} className="py-6 text-center text-gray-500 dark:text-gray-400">
                    No keywords yet — add one above.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
