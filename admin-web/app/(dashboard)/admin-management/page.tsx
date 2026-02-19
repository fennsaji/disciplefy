'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'

interface AdminUser {
  id: string
  full_name: string
  email: string | null
  created_at: string
  is_self: boolean
}

interface SearchResult {
  id: string
  full_name: string
  email: string | null
  is_admin: boolean
}

function AdminBadge() {
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-semibold text-amber-800 dark:bg-amber-400/15 dark:text-amber-300">
      <span className="h-1.5 w-1.5 rounded-full bg-amber-500" />
      Admin
    </span>
  )
}

export default function AdminManagementPage() {
  const queryClient = useQueryClient()
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState<SearchResult[]>([])
  const [isSearching, setIsSearching] = useState(false)
  const [confirmDialog, setConfirmDialog] = useState<{
    userId: string
    userName: string
    action: 'grant' | 'revoke'
  } | null>(null)

  // Fetch current admins
  const { data: adminsData, isLoading: adminsLoading } = useQuery({
    queryKey: ['admins'],
    queryFn: async () => {
      const res = await fetch('/api/admin/list-admins', { credentials: 'include' })
      if (!res.ok) throw new Error('Failed to load admins')
      return res.json() as Promise<{ admins: AdminUser[] }>
    },
  })

  // Set / revoke admin mutation
  const setAdminMutation = useMutation({
    mutationFn: async ({ userId, isAdmin }: { userId: string; isAdmin: boolean }) => {
      const res = await fetch('/api/admin/set-admin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ userId, isAdmin }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Request failed')
      return data
    },
    onSuccess: (data, { isAdmin }) => {
      toast.success(data.message)
      queryClient.invalidateQueries({ queryKey: ['admins'] })
      // Refresh search results to reflect updated admin status
      if (searchResults.length > 0) {
        setSearchResults((prev) =>
          prev.map((u) =>
            u.id === (confirmDialog?.userId ?? '') ? { ...u, is_admin: isAdmin } : u
          )
        )
      }
      setConfirmDialog(null)
    },
    onError: (err: Error) => {
      toast.error(err.message)
      setConfirmDialog(null)
    },
  })

  const handleSearch = async () => {
    if (!searchQuery.trim()) return
    setIsSearching(true)
    try {
      const res = await fetch('/api/admin/search-users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ query: searchQuery }),
      })
      const data = await res.json()
      setSearchResults(
        (data.users || []).map((u: any) => ({
          id: u.id,
          full_name: u.full_name,
          email: u.email,
          is_admin: u.is_admin ?? false,
        }))
      )
    } catch {
      toast.error('Search failed')
    } finally {
      setIsSearching(false)
    }
  }

  const admins = adminsData?.admins ?? []

  return (
    <div className="space-y-8">
      <PageHeader
        title="Admin Management"
        description="Grant or revoke admin access for users"
      />

      {/* Current admins */}
      <section>
        <h2 className="mb-4 text-base font-semibold text-gray-900 dark:text-gray-100">
          Current Admins
          <span className="ml-2 rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-700 dark:bg-indigo-400/15 dark:text-indigo-300">
            {admins.length}
          </span>
        </h2>

        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white dark:border-white/10 dark:bg-gray-900">
          {adminsLoading ? (
            <div className="flex items-center justify-center py-12 text-sm text-gray-500 dark:text-gray-400">
              Loading admins…
            </div>
          ) : admins.length === 0 ? (
            <div className="py-12 text-center text-sm text-gray-500 dark:text-gray-400">
              No admins found.
            </div>
          ) : (
            <table className="min-w-full divide-y divide-gray-200 dark:divide-white/10">
              <thead>
                <tr className="bg-gray-50 dark:bg-white/5">
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    User
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Email
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Added
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-white/5">
                {admins.map((admin) => (
                  <tr key={admin.id} className="hover:bg-gray-50 dark:hover:bg-white/5">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-indigo-700 text-xs font-bold text-white">
                          {admin.full_name.charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                            {admin.full_name}
                          </p>
                          {admin.is_self && (
                            <p className="text-xs text-gray-400 dark:text-gray-500">You</p>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-600 dark:text-gray-300">
                      {admin.email || '—'}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                      {new Date(admin.created_at).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 text-right">
                      {admin.is_self ? (
                        <span className="text-xs text-gray-400 dark:text-gray-500">
                          Cannot remove self
                        </span>
                      ) : (
                        <button
                          onClick={() =>
                            setConfirmDialog({
                              userId: admin.id,
                              userName: admin.full_name,
                              action: 'revoke',
                            })
                          }
                          className="rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 transition-colors hover:bg-red-100 dark:border-red-400/20 dark:bg-red-400/10 dark:text-red-400 dark:hover:bg-red-400/20"
                        >
                          Revoke Admin
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>

      {/* Grant admin */}
      <section>
        <h2 className="mb-4 text-base font-semibold text-gray-900 dark:text-gray-100">
          Grant Admin Access
        </h2>

        <div className="rounded-xl border border-gray-200 bg-white p-6 dark:border-white/10 dark:bg-gray-900">
          <div className="flex gap-3">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
              placeholder="Search by name, email or user ID…"
              className="flex-1 rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-white/10 dark:bg-white/5 dark:text-gray-100 dark:placeholder-gray-500"
            />
            <button
              onClick={handleSearch}
              disabled={isSearching || !searchQuery.trim()}
              className="rounded-lg bg-primary px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isSearching ? 'Searching…' : 'Search'}
            </button>
          </div>

          {searchResults.length > 0 && (
            <div className="mt-4 overflow-hidden rounded-lg border border-gray-200 dark:border-white/10">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-white/10">
                <thead>
                  <tr className="bg-gray-50 dark:bg-white/5">
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      User
                    </th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Email
                    </th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Status
                    </th>
                    <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 bg-white dark:divide-white/5 dark:bg-transparent">
                  {searchResults.map((u) => (
                    <tr key={u.id} className="hover:bg-gray-50 dark:hover:bg-white/5">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2.5">
                          <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-indigo-700 text-xs font-bold text-white">
                            {u.full_name.charAt(0).toUpperCase()}
                          </div>
                          <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                            {u.full_name}
                          </span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">
                        {u.email || '—'}
                      </td>
                      <td className="px-4 py-3">
                        {u.is_admin ? <AdminBadge /> : (
                          <span className="text-xs text-gray-400 dark:text-gray-500">User</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        {u.is_admin ? (
                          <button
                            onClick={() =>
                              setConfirmDialog({
                                userId: u.id,
                                userName: u.full_name,
                                action: 'revoke',
                              })
                            }
                            className="rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 transition-colors hover:bg-red-100 dark:border-red-400/20 dark:bg-red-400/10 dark:text-red-400 dark:hover:bg-red-400/20"
                          >
                            Revoke Admin
                          </button>
                        ) : (
                          <button
                            onClick={() =>
                              setConfirmDialog({
                                userId: u.id,
                                userName: u.full_name,
                                action: 'grant',
                              })
                            }
                            className="rounded-lg border border-indigo-200 bg-indigo-50 px-3 py-1.5 text-xs font-medium text-indigo-700 transition-colors hover:bg-indigo-100 dark:border-indigo-400/20 dark:bg-indigo-400/10 dark:text-indigo-300 dark:hover:bg-indigo-400/20"
                          >
                            Grant Admin
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {searchResults.length === 0 && searchQuery && !isSearching && (
            <p className="mt-4 text-sm text-gray-500 dark:text-gray-400">
              No users found. Try a different search term.
            </p>
          )}
        </div>
      </section>

      {/* Confirm dialog */}
      {confirmDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl border border-gray-200 bg-white p-6 shadow-2xl dark:border-white/10 dark:bg-gray-900">
            <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-400/15">
              <span className="text-2xl">
                {confirmDialog.action === 'grant' ? '🛡️' : '⚠️'}
              </span>
            </div>
            <h3 className="mb-2 text-base font-semibold text-gray-900 dark:text-gray-100">
              {confirmDialog.action === 'grant' ? 'Grant Admin Access' : 'Revoke Admin Access'}
            </h3>
            <p className="mb-6 text-sm text-gray-500 dark:text-gray-400">
              {confirmDialog.action === 'grant' ? (
                <>
                  Are you sure you want to grant admin access to{' '}
                  <strong className="text-gray-900 dark:text-gray-100">
                    {confirmDialog.userName}
                  </strong>
                  ? They will have full access to this admin panel.
                </>
              ) : (
                <>
                  Are you sure you want to revoke admin access from{' '}
                  <strong className="text-gray-900 dark:text-gray-100">
                    {confirmDialog.userName}
                  </strong>
                  ?
                </>
              )}
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setConfirmDialog(null)}
                className="flex-1 rounded-lg border border-gray-200 bg-gray-50 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-100 dark:border-white/10 dark:bg-white/5 dark:text-gray-300 dark:hover:bg-white/10"
              >
                Cancel
              </button>
              <button
                onClick={() =>
                  setAdminMutation.mutate({
                    userId: confirmDialog.userId,
                    isAdmin: confirmDialog.action === 'grant',
                  })
                }
                disabled={setAdminMutation.isPending}
                className={`flex-1 rounded-lg px-4 py-2.5 text-sm font-medium text-white disabled:opacity-50 ${
                  confirmDialog.action === 'grant'
                    ? 'bg-primary hover:bg-primary/90'
                    : 'bg-red-600 hover:bg-red-700'
                }`}
              >
                {setAdminMutation.isPending
                  ? 'Saving…'
                  : confirmDialog.action === 'grant'
                  ? 'Grant Access'
                  : 'Revoke Access'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
