'use client'

interface AdminLog {
  id: string
  admin_user_id: string
  admin_email: string
  admin_name: string
  action: string
  action_type: string
  target_table: string | null
  target_id: string | null
  target_user_id: string | null
  ip_address: string | null
  user_agent: string | null
  details: any
  created_at: string
  source: string
}

interface AdminLogsTableProps {
  logs: AdminLog[]
}

export function AdminLogsTable({ logs }: AdminLogsTableProps) {
  const getActionColor = (action: string) => {
    const actionLower = action.toLowerCase()
    if (actionLower.includes('delete') || actionLower.includes('remove')) {
      return 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300'
    }
    if (actionLower.includes('update') || actionLower.includes('edit') || actionLower.includes('adjust')) {
      return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300'
    }
    if (actionLower.includes('create') || actionLower.includes('add')) {
      return 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300'
    }
    if (actionLower.includes('view') || actionLower.includes('read')) {
      return 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300'
    }
    return 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
  }

  if (logs.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
        <p className="text-gray-500 dark:text-gray-400">No admin logs found</p>
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
              Admin
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Action
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Target
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
          {logs.map((log) => (
            <tr key={log.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {new Date(log.created_at).toLocaleDateString()}<br />
                {new Date(log.created_at).toLocaleTimeString()}
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="text-sm">
                  <div className="font-medium text-gray-900 dark:text-gray-100">
                    {log.admin_name}
                  </div>
                  <div className="text-gray-500 dark:text-gray-400">
                    {log.admin_email}
                  </div>
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${getActionColor(log.action)}`}>
                  {log.action.replace(/_/g, ' ')}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="text-sm">
                  {log.target_table && (
                    <div className="font-medium text-gray-900 dark:text-gray-100">
                      {log.target_table}
                    </div>
                  )}
                  {log.target_user_id && (
                    <div className="text-gray-500 dark:text-gray-400">
                      User: {log.target_user_id}
                    </div>
                  )}
                  {log.target_id && (
                    <div className="text-xs text-gray-500 dark:text-gray-400">
                      ID: {log.target_id.substring(0, 8)}...
                    </div>
                  )}
                  {!log.target_table && !log.target_user_id && !log.target_id && (
                    <span className="italic text-gray-400">—</span>
                  )}
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {log.ip_address || '—'}
              </td>
              <td className="px-6 py-4">
                <div className="max-w-xs text-sm">
                  {log.details && Object.keys(log.details).length > 0 ? (
                    <details className="cursor-pointer">
                      <summary className="font-medium text-gray-900 dark:text-gray-100">
                        View details
                      </summary>
                      <pre className="mt-2 overflow-auto rounded bg-gray-50 p-2 text-xs dark:bg-gray-800">
                        {JSON.stringify(log.details, null, 2)}
                      </pre>
                    </details>
                  ) : (
                    <span className="italic text-gray-400">No details</span>
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
