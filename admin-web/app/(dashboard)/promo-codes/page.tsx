'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { format } from 'date-fns'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { PageHeader } from '@/components/ui/page-header'
import { StatsCard } from '@/components/ui/stats-card'
import { PromoCodeTable } from '@/components/tables/promo-code-table'
import { listPromoCodes, togglePromoCode } from '@/lib/api/admin'
import { formatCompactNumber } from '@/lib/utils/date'
import type { PromoCodeCampaign } from '@/types/admin'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'

export default function PromoCodesPage() {
  const router = useRouter()
  const [selectedCampaign, setSelectedCampaign] = useState<PromoCodeCampaign | null>(null)
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive' | 'expired'>('all')
  const queryClient = useQueryClient()

  // Fetch promo codes
  const {
    data: promoData,
    isLoading,
    error,
  } = useQuery({
    queryKey: ['promo-codes', statusFilter],
    queryFn: () => listPromoCodes({ status: statusFilter }),
    refetchInterval: 60000, // Refetch every minute
  })

  // Toggle status mutation
  const toggleMutation = useMutation({
    mutationFn: ({ campaignId, isActive }: { campaignId: string; isActive: boolean }) =>
      togglePromoCode({ campaign_id: campaignId, is_active: isActive }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['promo-codes'] })
      toast.success('Promo code status updated!')
    },
    onError: (error) => {
      toast.error(`Failed to update promo code status: ${error instanceof Error ? error.message : 'Unknown error'}`)
    },
  })

  // Counted by the database over every campaign — not just the loaded page
  const stats = promoData?.stats
    ? {
        active: promoData.stats.active,
        totalRedemptions: promoData.stats.total_redemptions,
        expiringSoon: promoData.stats.expiring_soon,
        inactive: promoData.stats.inactive,
      }
    : null

  return (
    <div className="space-y-6">
      <PageHeader
        title="Promotional Campaigns"
        description="Create and manage promotional codes for user acquisition and retention"
        actions={
          <button
            type="button"
            onClick={() => router.push('/promo-codes/create')}
            className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
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
                d="M12 4v16m8-8H4"
              />
            </svg>
            Create Promo Code
          </button>
        }
      />

      {/* Error State */}
      {error && (
        <ErrorState title="Error loading promo codes" message={error instanceof Error ? error.message : 'Unknown error'} />
      )}

      {/* Loading State */}
      {isLoading && <LoadingState label="Loading promo codes..." />}

      {/* Stats Cards */}
      {stats && (
        <div className="grid gap-6 md:grid-cols-4">
          <StatsCard
            title="Active Campaigns"
            value={formatCompactNumber(stats.active)}
            subtitle="Currently running"
            icon="✅"
          />
          <StatsCard
            title="Total Redemptions"
            value={formatCompactNumber(stats.totalRedemptions)}
            subtitle="All time"
            icon="🎫"
          />
          <StatsCard
            title="Expiring Soon"
            value={formatCompactNumber(stats.expiringSoon)}
            subtitle="Within 7 days"
            icon="⏰"
          />
          <StatsCard
            title="Inactive"
            value={formatCompactNumber(stats.inactive)}
            subtitle="Deactivated"
            icon="⏸️"
          />
        </div>
      )}

      {/* Filter Buttons */}
      {promoData && (
        <div className="flex flex-wrap gap-2">
          {[
            { value: 'all', label: 'All' },
            { value: 'active', label: 'Active' },
            { value: 'inactive', label: 'Inactive' },
            { value: 'expired', label: 'Expired' },
          ].map((filter) => (
            <button
              key={filter.value}
              onClick={() => setStatusFilter(filter.value as any)}
              className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
                statusFilter === filter.value
                  ? 'bg-primary text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
              }`}
            >
              {filter.label}
            </button>
          ))}
        </div>
      )}

      {/* Promo Codes Table */}
      {promoData && (
        <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
          <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
            {statusFilter === 'all' ? 'All Campaigns' : `${statusFilter.charAt(0).toUpperCase() + statusFilter.slice(1)} Campaigns`}
          </h2>
          <PromoCodeTable
            campaigns={promoData.campaigns}
            onToggleStatus={(campaignId, isActive) =>
              toggleMutation.mutate({ campaignId, isActive })
            }
            onViewDetails={setSelectedCampaign}
          />
        </div>
      )}

      {/* Info Card */}
      {!isLoading && !error && promoData?.campaigns.length === 0 && (
        <div className="rounded-lg bg-blue-50 p-6 dark:bg-blue-900/20">
          <div className="flex gap-4">
            <div className="flex-shrink-0">
              <svg className="h-6 w-6 text-blue-600 dark:text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 className="font-medium text-blue-900 dark:text-blue-300">Create Your First Promo Code</h3>
              <ul className="mt-2 space-y-1 text-sm text-blue-800 dark:text-blue-300">
                <li>• Percentage or fixed amount discounts</li>
                <li>• Flexible eligibility rules (all users, new users, specific tiers)</li>
                <li>• Usage limits and expiry dates</li>
                <li>• Per-user redemption tracking</li>
              </ul>
            </div>
          </div>
        </div>
      )}

      {/* Campaign Details Modal */}
      {selectedCampaign && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4">
          <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-lg bg-white p-6 shadow-xl dark:bg-gray-800">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Campaign Details</h2>
              <button
                onClick={() => setSelectedCampaign(null)}
                className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
              >
                <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Promo Code</p>
                <p className="mt-1 font-mono font-semibold text-gray-900 dark:text-gray-100">{selectedCampaign.code}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Campaign Name</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">{selectedCampaign.campaign_name}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Discount</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {selectedCampaign.discount_type === 'percentage'
                    ? `${selectedCampaign.discount_value}%`
                    : `₹${selectedCampaign.discount_value}`}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Status</p>
                <p className="mt-1">
                  <span
                    className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                      selectedCampaign.is_expired
                        ? 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
                        : selectedCampaign.is_active
                        ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300'
                        : 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300'
                    }`}
                  >
                    {selectedCampaign.is_expired ? 'Expired' : selectedCampaign.is_active ? 'Active' : 'Inactive'}
                  </span>
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Usage</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {selectedCampaign.current_uses} / {selectedCampaign.max_total_uses ?? 'Unlimited'}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Max Uses Per User</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">{selectedCampaign.max_uses_per_user}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Campaign Period</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {format(new Date(selectedCampaign.start_date), 'MMM dd, yyyy')} –{' '}
                  {format(new Date(selectedCampaign.end_date), 'MMM dd, yyyy')}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Applies to Plans</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {selectedCampaign.applies_to_plan?.length ? selectedCampaign.applies_to_plan.join(', ') : '-'}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Eligibility</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">{selectedCampaign.eligible_for}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Created</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {format(new Date(selectedCampaign.created_at), 'MMM dd, yyyy')}
                </p>
              </div>
              {selectedCampaign.eligible_for === 'specific_tiers' && (
                <div className="sm:col-span-2">
                  <p className="text-sm text-gray-500 dark:text-gray-400">Eligible Tiers</p>
                  <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                    {selectedCampaign.eligible_tiers?.length ? selectedCampaign.eligible_tiers.join(', ') : '-'}
                  </p>
                </div>
              )}
              {selectedCampaign.eligible_for === 'specific_users' && (
                <div className="sm:col-span-2">
                  <p className="text-sm text-gray-500 dark:text-gray-400">Eligible User IDs</p>
                  <p className="mt-1 break-all font-mono text-sm text-gray-900 dark:text-gray-100">
                    {selectedCampaign.eligible_user_ids?.length ? selectedCampaign.eligible_user_ids.join(', ') : '-'}
                  </p>
                </div>
              )}
              {selectedCampaign.description && (
                <div className="sm:col-span-2">
                  <p className="text-sm text-gray-500 dark:text-gray-400">Description</p>
                  <p className="mt-1 text-gray-900 dark:text-gray-100">{selectedCampaign.description}</p>
                </div>
              )}
            </div>

            <div className="mt-6 flex justify-end">
              <button
                onClick={() => setSelectedCampaign(null)}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
