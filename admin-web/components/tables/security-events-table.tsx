'use client'

interface SecurityEvent {
  id: string
  user_id: string | null
  user_email: string
  session_id: string | null
  ip_address: string | null
  event_type: string
  input_text: string | null
  risk_score: number | null
  action_taken: string
  detection_details: any
  created_at: string
}

interface SecurityEventsTableProps {
  events: SecurityEvent[]
}

export function SecurityEventsTable({ events }: SecurityEventsTableProps) {
  const getEventTypeColor = (eventType: string) => {
    const colors: Record<string, string> = {
      prompt_injection: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300',
      rate_limit_exceeded: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300',
      toxic_content: 'bg-orange-100 text-orange-800 dark:bg-orange-900/20 dark:text-orange-300',
      excessive_length: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300',
      unauthorized_access: 'bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-300',
      malicious_pattern: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300',
    }
    return colors[eventType] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
  }

  const getRiskColor = (score: number | null) => {
    if (score === null) return 'text-gray-500'
    if (score >= 0.7) return 'text-red-600 dark:text-red-400'
    if (score >= 0.4) return 'text-yellow-600 dark:text-yellow-400'
    return 'text-green-600 dark:text-green-400'
  }

  const getActionColor = (action: string) => {
    const colors: Record<string, string> = {
      blocked: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300',
      sanitized: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300',
      logged: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300',
      rate_limited: 'bg-orange-100 text-orange-800 dark:bg-orange-900/20 dark:text-orange-300',
    }
    return colors[action] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
  }

  if (events.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
        <p className="text-gray-500 dark:text-gray-400">No security events found</p>
      </div>
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Time
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              User
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Event Type
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Risk Score
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Action
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              IP Address
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Details
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
          {events.map((event) => (
            <tr key={event.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {new Date(event.created_at).toLocaleDateString()}<br />
                {new Date(event.created_at).toLocaleTimeString()}
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="text-sm">
                  <div className="font-medium text-gray-900 dark:text-gray-100">
                    {event.user_email}
                  </div>
                  {event.session_id && (
                    <div className="text-xs text-gray-500 dark:text-gray-400">
                      Session: {event.session_id.substring(0, 8)}...
                    </div>
                  )}
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${getEventTypeColor(event.event_type)}`}>
                  {event.event_type.replace('_', ' ')}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span className={`text-lg font-bold ${getRiskColor(event.risk_score)}`}>
                  {event.risk_score !== null ? (event.risk_score * 100).toFixed(0) + '%' : '—'}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${getActionColor(event.action_taken)}`}>
                  {event.action_taken}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {event.ip_address || '—'}
              </td>
              <td className="px-6 py-4">
                <div className="max-w-xs text-sm text-gray-900 dark:text-gray-100">
                  {event.input_text ? (
                    <div className="truncate" title={event.input_text}>
                      {event.input_text.substring(0, 50)}...
                    </div>
                  ) : (
                    <span className="italic text-gray-400">No input captured</span>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
