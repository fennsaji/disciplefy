'use client'

import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { useState } from 'react'
import ThemeToggle from './theme-toggle'

interface HeaderProps {
  user: {
    name: string
  }
}

export default function Header({ user }: HeaderProps) {
  const router = useRouter()
  const supabase = createClient()
  const [isLoading, setIsLoading] = useState(false)

  const handleLogout = async () => {
    try {
      setIsLoading(true)
      await supabase.auth.signOut()
      router.push('/login')
    } catch (error) {
      console.error('Error signing out:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const initials = user.name
    .split(' ')
    .map((n) => n.charAt(0))
    .slice(0, 2)
    .join('')
    .toUpperCase()

  return (
    <header className="flex h-16 shrink-0 items-center justify-between border-b border-gray-200/80 bg-white px-6 shadow-sm dark:border-white/5 dark:bg-[#0f0e1a]">
      {/* Left — wordmark echo */}
      <div className="flex items-center gap-2">
        <span className="text-sm font-semibold text-gray-400 dark:text-indigo-300/50">Dashboard</span>
      </div>

      {/* Right */}
      <div className="flex items-center gap-3">
        <ThemeToggle />

        {/* Divider */}
        <div className="h-6 w-px bg-gray-200 dark:bg-white/10" />

        {/* User */}
        <div className="flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-indigo-700 text-xs font-bold text-white shadow shadow-indigo-500/30">
            {initials}
          </div>
          <div className="hidden text-sm sm:block">
            <p className="font-medium leading-none text-gray-900 dark:text-gray-100">{user.name}</p>
            <p className="mt-0.5 text-[11px] leading-none text-amber-500 dark:text-amber-400">Admin</p>
          </div>
        </div>

        {/* Divider */}
        <div className="h-6 w-px bg-gray-200 dark:bg-white/10" />

        <button
          onClick={handleLogout}
          disabled={isLoading}
          className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-1.5 text-xs font-medium text-gray-600 transition-colors hover:border-gray-300 hover:bg-gray-100 disabled:opacity-50 dark:border-white/10 dark:bg-white/5 dark:text-gray-300 dark:hover:bg-white/10"
        >
          {isLoading ? 'Signing out…' : 'Sign out'}
        </button>
      </div>
    </header>
  )
}
