'use client'

import { formatCurrency, formatCompactNumber } from '@/lib/utils/date'
import type {
  FeatureBreakdown,
  TierBreakdown,
  ProviderBreakdown,
  ModelBreakdown,
} from '@/types/admin'

interface BreakdownTablesProps {
  byFeature: Record<string, FeatureBreakdown>
  byTier: Record<string, TierBreakdown>
  byProvider: Record<string, ProviderBreakdown>
  byModel: Record<string, ModelBreakdown>
}

export function BreakdownTables({
  byFeature,
  byTier,
  byProvider,
  byModel,
}: BreakdownTablesProps) {
  return (
    <div className="grid gap-6 md:grid-cols-2">
      {/* By Feature */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
          Cost by Feature
        </h2>
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="border-b border-gray-200 dark:border-gray-700">
              <tr>
                <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                  Feature
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Operations
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Cost
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Avg/Op
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {Object.entries(byFeature).map(([feature, data]) => (
                <tr key={feature}>
                  <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                    {formatFeatureName(feature)}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCompactNumber(data.operations)}
                  </td>
                  <td className="py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    {formatCurrency(data.cost_usd)}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCurrency(data.avg_cost_per_operation)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* By Tier */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
          Cost by Tier
        </h2>
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="border-b border-gray-200 dark:border-gray-700">
              <tr>
                <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                  Tier
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Users
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Cost
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Avg/User
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {Object.entries(byTier).map(([tier, data]) => (
                <tr key={tier}>
                  <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                    <span className={`inline-flex items-center gap-2`}>
                      {getTierBadge(tier)}
                      {formatTierName(tier)}
                    </span>
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCompactNumber(data.unique_users)}
                  </td>
                  <td className="py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    {formatCurrency(data.cost_usd)}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCurrency(data.avg_cost_per_user)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* By Provider */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
          Cost by Provider
        </h2>
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="border-b border-gray-200 dark:border-gray-700">
              <tr>
                <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                  Provider
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Operations
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Tokens
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Cost
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {Object.entries(byProvider).map(([provider, data]) => (
                <tr key={provider}>
                  <td className="py-3 text-sm font-medium text-gray-900 dark:text-gray-100">
                    {formatProviderName(provider)}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCompactNumber(data.operations)}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCompactNumber(data.input_tokens + data.output_tokens)}
                  </td>
                  <td className="py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    {formatCurrency(data.cost_usd)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* By Model */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
          Cost by Model
        </h2>
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="border-b border-gray-200 dark:border-gray-700">
              <tr>
                <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                  Model
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Operations
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Tokens
                </th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                  Cost
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {Object.entries(byModel).map(([model, data]) => (
                <tr key={model}>
                  <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                    <div className="flex flex-col">
                      <span className="font-medium">{formatModelName(model)}</span>
                      <span className="text-xs text-gray-500 dark:text-gray-400">
                        {formatProviderName(data.provider)}
                      </span>
                    </div>
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCompactNumber(data.operations)}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {formatCompactNumber(data.input_tokens + data.output_tokens)}
                  </td>
                  <td className="py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    {formatCurrency(data.cost_usd)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

// Helper functions
function formatFeatureName(feature: string): string {
  const names: Record<string, string> = {
    study_generate: 'Study Generation',
    study_followup: 'Follow-up Questions',
    voice_conversation: 'Voice Conversations',
  }
  return names[feature] || feature
}

function formatTierName(tier: string): string {
  return tier.charAt(0).toUpperCase() + tier.slice(1)
}

function getTierBadge(tier: string): string {
  const badges: Record<string, string> = {
    free: '🆓',
    standard: '⭐',
    plus: '✨',
    premium: '👑',
  }
  return badges[tier] || '📊'
}

function formatProviderName(provider: string): string {
  const names: Record<string, string> = {
    openai: 'OpenAI',
    anthropic: 'Anthropic',
  }
  return names[provider] || provider
}

function formatModelName(model: string): string {
  // Shorten long model names for display
  if (model.length > 30) {
    return model.substring(0, 27) + '...'
  }
  return model
}
