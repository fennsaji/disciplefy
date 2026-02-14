'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

const navigation = [
  { name: 'Overview', href: '/', icon: '📊' },
  { name: 'Analytics', href: '/analytics', icon: '📈' },
  { name: 'Security', href: '/security', icon: '🔒' },
  { name: 'LLM Costs', href: '/llm-costs', icon: '💰' },
  { name: 'Subscriptions', href: '/subscriptions', icon: '👥' },
  { name: 'Token Management', href: '/token-management', icon: '🪙' },
  { name: 'Promo Codes', href: '/promo-codes', icon: '🎟️' },
  { name: 'Learning Paths', href: '/learning-paths', icon: '🎓' },
  { name: 'Study Guides', href: '/topics', icon: '📚' },
  { name: 'Content Management', href: '/content-management', icon: '📝' },
  { name: 'Gamification', href: '/gamification', icon: '🎮' },
  { name: 'System Config', href: '/system-config', icon: '⚙️' },
  { name: 'Study Generator', href: '/study-generator', icon: '✨' },
  { name: 'Issues & Feedback', href: '/issues', icon: '⚠️' },
]

export default function Sidebar() {
  const pathname = usePathname()

  return (
    <div className="flex w-64 flex-col bg-white shadow-lg dark:bg-gray-900 dark:shadow-gray-800">
      <div className="flex h-16 items-center justify-center border-b border-gray-200 bg-primary dark:border-gray-700">
        <h1 className="text-xl font-bold text-white">Disciplefy Admin</h1>
      </div>

      <nav className="flex-1 space-y-1 px-3 py-4">
        {navigation.map((item) => {
          const isActive = pathname === item.href
          return (
            <Link
              key={item.name}
              href={item.href}
              className={`flex items-center gap-3 rounded-lg px-4 py-3 text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-primary text-white'
                  : 'text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800'
              }`}
            >
              <span className="text-xl">{item.icon}</span>
              <span>{item.name}</span>
            </Link>
          )
        })}
      </nav>

      <div className="border-t border-gray-200 p-4 dark:border-gray-700">
        <div className="text-xs text-gray-500 dark:text-gray-400">
          <p>v1.0.0</p>
          <p className="mt-1">© 2026 Disciplefy</p>
        </div>
      </div>
    </div>
  )
}
