'use client'

import { useState } from 'react'
import Sidebar from '@/components/sidebar'
import Header from '@/components/header'

interface DashboardShellProps {
  user: { name: string }
  children: React.ReactNode
}

export default function DashboardShell({ user, children }: DashboardShellProps) {
  const [isMobileOpen, setIsMobileOpen] = useState(false)

  return (
    <div className="flex h-screen bg-background dark:bg-gray-950">
      {/* Mobile backdrop — tap to close drawer */}
      {isMobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 md:hidden"
          onClick={() => setIsMobileOpen(false)}
        />
      )}

      <Sidebar isOpen={isMobileOpen} onClose={() => setIsMobileOpen(false)} />

      <div className="flex flex-1 flex-col overflow-hidden">
        <Header user={user} onMenuOpen={() => setIsMobileOpen(true)} />
        <main className="flex-1 overflow-y-auto bg-gray-50 p-3 md:p-6 dark:bg-gray-900">
          {children}
        </main>
      </div>
    </div>
  )
}
