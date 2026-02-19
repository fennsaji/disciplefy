'use client'

import Image from 'next/image'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

const navGroups = [
  {
    label: 'Core',
    items: [
      { name: 'Overview', href: '/', emoji: '📊' },
      { name: 'Analytics', href: '/analytics', emoji: '📈' },
      { name: 'Security', href: '/security', emoji: '🔒' },
    ],
  },
  {
    label: 'Content',
    items: [
      { name: 'Learning Paths', href: '/learning-paths', emoji: '🎓' },
      { name: 'Study Guides', href: '/topics', emoji: '📚' },
      { name: 'Memory Verses', href: '/memory-verses', emoji: '📖' },
      { name: 'Content Mgmt', href: '/content-management', emoji: '📝' },
      { name: 'Study Generator', href: '/study-generator', emoji: '✨' },
    ],
  },
  {
    label: 'Finance',
    items: [
      { name: 'Subscriptions', href: '/subscriptions', emoji: '👥' },
      { name: 'LLM Costs', href: '/llm-costs', emoji: '💰' },
      { name: 'Token Management', href: '/token-management', emoji: '🪙' },
      { name: 'Promo Codes', href: '/promo-codes', emoji: '🎟️' },
    ],
  },
  {
    label: 'System',
    items: [
      { name: 'Gamification', href: '/gamification', emoji: '🎮' },
      { name: 'System Config', href: '/system-config', emoji: '⚙️' },
      { name: 'Admin Management', href: '/admin-management', emoji: '🛡️' },
      { name: 'Issues & Feedback', href: '/issues', emoji: '⚠️' },
    ],
  },
]

export default function Sidebar() {
  const pathname = usePathname()

  return (
    <div className="flex w-64 flex-col bg-gradient-to-b from-[#090818] to-[#161240]">
      {/* Logo */}
      <div className="flex h-16 shrink-0 items-center gap-3 border-b border-white/10 px-5">
        <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-[#1e1a40] shadow-lg shadow-black/30">
          <Image src="/logo.png" alt="Disciplefy" width={28} height={28} className="object-contain" />
        </div>
        <div className="leading-none">
          <span className="block text-[15px] font-bold tracking-wide text-white">Disciplefy</span>
          <span className="mt-0.5 block text-[10px] font-semibold uppercase tracking-[0.22em] text-amber-400">
            Admin
          </span>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 py-5">
        <div className="space-y-6">
          {navGroups.map((group) => (
            <div key={group.label}>
              <p className="mb-2 px-3 text-[10px] font-semibold uppercase tracking-[0.18em] text-indigo-400/70">
                {group.label}
              </p>
              <div className="space-y-0.5">
                {group.items.map((item) => {
                  const isActive = pathname === item.href
                  return (
                    <Link
                      key={item.name}
                      href={item.href}
                      className={`group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-all duration-150 ${
                        isActive
                          ? 'border border-amber-400/25 bg-amber-400/10 text-amber-300'
                          : 'border border-transparent text-indigo-200/80 hover:border-white/5 hover:bg-white/5 hover:text-white'
                      }`}
                    >
                      <span className="text-base leading-none">{item.emoji}</span>
                      <span className="flex-1">{item.name}</span>
                      {isActive && (
                        <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-amber-400" />
                      )}
                    </Link>
                  )
                })}
              </div>
            </div>
          ))}
        </div>
      </nav>

      {/* Footer */}
      <div className="shrink-0 border-t border-white/10 px-5 py-3">
        <p className="text-[10px] text-indigo-400/60">v1.0.0 · © 2026 Disciplefy</p>
      </div>
    </div>
  )
}
