'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
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
    },
  })

  // Calculate stats
  const stats = promoData?.campaigns
    ? {
        active: promoData.campaigns.filter((c) => c.is_active && !c.is_expired).length,
        totalRedemptions: promoData.campaigns.reduce((sum, c) => sum + c.current_uses, 0),
        expiringSoon: promoData.campaigns.filter((c) => {
          const daysUntilExpiry = Math.ceil(
            (new Date(c.end_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24)
          )
          return daysUntilExpiry <= 7 && daysUntilExpiry > 0 && c.is_active
        }).length,
        inactive: promoData.campaigns.filter((c) => !c.is_active).length,
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
        <div className="flex gap-2">
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

      {/* Toggle Success Message */}
      {toggleMutation.isSuccess && (
        <div className="fixed bottom-4 right-4 rounded-lg bg-green-50 p-4 text-green-800 shadow-lg dark:bg-green-900/20 dark:text-green-300">
          <p className="font-medium">✅ Promo code status updated!</p>
        </div>
      )}
    </div>
  )
}
