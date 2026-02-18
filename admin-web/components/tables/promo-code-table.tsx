'use client'

import { format } from 'date-fns'
import type { PromoCodeCampaign } from '@/types/admin'
import { ManageIcon, ToggleIcon, actionButtonStyles } from '@/components/ui/action-icons'

interface PromoCodeTableProps {
  campaigns: PromoCodeCampaign[]
  onToggleStatus: (campaignId: string, isActive: boolean) => void
  onViewDetails: (campaign: PromoCodeCampaign) => void
}

export function PromoCodeTable({ campaigns, onToggleStatus, onViewDetails }: PromoCodeTableProps) {
  if (campaigns.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-12 text-center dark:border-gray-700 dark:bg-gray-800">
        <p className="text-gray-500 dark:text-gray-400">No promo codes found. Create your first campaign to get started.</p>
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-md dark:border-gray-700 dark:bg-gray-800 dark:shadow-gray-900">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead className="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Code
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Campaign Name
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Discount
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Usage
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Expiry
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-800">
            {campaigns.map((campaign) => (
              <tr key={campaign.id} className="hover:bg-gray-50 dark:hover:bg-gray-700">
                <td className="px-6 py-4">
                  <span className="font-mono font-bold text-primary">{campaign.code}</span>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-col">
                    <span className="font-medium text-gray-900 dark:text-gray-100">{campaign.campaign_name}</span>
                    {campaign.description && (
                      <span className="text-sm text-gray-500 dark:text-gray-400">{campaign.description}</span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4">
                  <span className="font-medium text-gray-900 dark:text-gray-100">
                    {campaign.discount_type === 'percentage'
                      ? `${campaign.discount_value}%`
                      : `₹${campaign.discount_value}`}
                  </span>
                  <span className="ml-1 text-sm text-gray-500 dark:text-gray-400">off</span>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-col">
                    <span className="font-medium text-gray-900 dark:text-gray-100">
                      {campaign.current_uses}
                      {campaign.max_total_uses && ` / ${campaign.max_total_uses}`}
                    </span>
                    <span className="text-xs text-gray-500 dark:text-gray-400">
                      {campaign.max_uses_per_user} per user
                    </span>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-col gap-1">
                    <span
                      className={`inline-flex w-fit rounded-full px-2 py-1 text-xs font-semibold ${
                        campaign.is_active
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {campaign.is_active ? 'Active' : 'Inactive'}
                    </span>
                    {campaign.is_expired && (
                      <span className="inline-flex w-fit rounded-full bg-red-100 px-2 py-1 text-xs font-semibold text-red-800">
                        Expired
                      </span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-col text-sm text-gray-600 dark:text-gray-400">
                    <span>Ends: {format(new Date(campaign.end_date), 'MMM dd, yyyy')}</span>
                    <span className="text-xs text-gray-400 dark:text-gray-500">
                      Started: {format(new Date(campaign.start_date), 'MMM dd, yyyy')}
                    </span>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex gap-3">
                    <button
                      onClick={() => onViewDetails(campaign)}
                      className={actionButtonStyles.manage}
                      title="View Details"
                    >
                      <ManageIcon />
                    </button>
                    {!campaign.is_expired && (
                      <button
                        onClick={() => onToggleStatus(campaign.id, !campaign.is_active)}
                        className={campaign.is_active ? actionButtonStyles.toggleInactive : actionButtonStyles.toggleActive}
                        title={campaign.is_active ? 'Deactivate' : 'Activate'}
                      >
                        <ToggleIcon />
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
