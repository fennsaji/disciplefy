// admin-web/components/sidebar.tsx
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
      { name: 'Blog Posts', href: '/blogs', emoji: '✍️' },
      { name: 'Daily Verses', href: '/content-management', emoji: '📅' },
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
      { name: 'Cron Jobs', href: '/crons', emoji: '⏰' },
    ],
  },
]

interface SidebarProps {
  isOpen: boolean
  /** Called when the sidebar should close. On desktop this prop is a no-op. */
  onClose: () => void
}

export default function Sidebar({ isOpen, onClose }: SidebarProps) {
  const pathname = usePathname()

  return (
    <div
      className={`
        fixed inset-y-0 left-0 z-50 flex w-64 flex-col
        bg-gradient-to-b from-[#090818] to-[#161240]
        max-md:transition-transform max-md:duration-200 max-md:ease-in-out
        md:relative md:translate-x-0 md:z-auto
        ${isOpen ? 'translate-x-0' : '-translate-x-full'}
      `}
    >
      {/* Logo + close button */}
      <div className="flex h-16 shrink-0 items-center justify-between border-b border-white/10 px-5">
        <div className="flex items-center gap-3">
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
        {/* Close button — mobile only */}
        <button
          onClick={onClose}
          className="md:hidden flex h-8 w-8 items-center justify-center rounded-lg text-white/60 hover:bg-white/10 hover:text-white"
          aria-label="Close navigation"
        >
          <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
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
                      onClick={onClose}
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
