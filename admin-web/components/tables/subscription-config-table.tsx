'use client'

interface SubscriptionConfig {
  id: string
  plan_code: string
  plan_name: string
  tier: number
  interval: string
  razorpay_plan_id: string
  price_inr: number
  billing_period: string
  daily_tokens: number
  features: {
    daily_tokens: number
    voice_conversations_monthly: number
    memory_verses: number
    practice_modes: number
    practice_limit: number
    study_modes: string[]
    [key: string]: any
  }
  active_users: number
  is_active: boolean
}

interface SubscriptionConfigTableProps {
  configs: SubscriptionConfig[]
  onEdit: (config: SubscriptionConfig) => void
}

export default function SubscriptionConfigTable({
  configs,
  onEdit
}: SubscriptionConfigTableProps) {
  const getPlanColor = (planCode: string) => {
    const colors: Record<string, string> = {
      free: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200',
      standard: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
      premium: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
      plus: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
    }
    return colors[planCode] || colors.free
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      minimumFractionDigits: 0,
    }).format(price)
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Plan
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Pricing
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Daily Tokens
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Voice Conversations
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Memory Verses
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Active Users
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
          {configs.map((config) => (
            <tr key={config.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="flex flex-col gap-1">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getPlanColor(config.plan_code)} w-fit`}>
                    {config.plan_name}
                  </span>
                  <span className="text-xs text-gray-500 dark:text-gray-400">
                    {config.razorpay_plan_id || 'No Razorpay ID'}
                  </span>
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm">
                  <div className="font-bold text-gray-900 dark:text-gray-100">
                    {formatPrice(config.price_inr)}
                  </div>
                  <div className="text-gray-500 dark:text-gray-400 capitalize">
                    {config.billing_period}
                  </div>
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm font-medium text-primary">
                  {config.daily_tokens === 999999999 ? '∞ Unlimited' : `${config.daily_tokens} tokens`}
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                  {config.features.voice_conversations_monthly === -1 ? '∞ Unlimited' : `${config.features.voice_conversations_monthly}/month`}
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                  {config.features.memory_verses === -1 ? '∞ Unlimited' : `${config.features.memory_verses} verses`}
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm font-semibold text-gray-900 dark:text-gray-100">
                  {config.active_users} users
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <button
                  onClick={() => onEdit(config)}
                  className="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300"
                >
                  Edit
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {configs.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 dark:text-gray-400">No subscription plans found</p>
        </div>
      )}
    </div>
  )
}
