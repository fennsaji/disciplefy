'use client'

import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function UnauthorizedPage() {
  const router = useRouter()
  const supabase = createClient()

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/login')
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-red-50 via-white to-red-100">
      <div className="w-full max-w-md rounded-2xl bg-white p-10 text-center shadow-2xl">
        <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-red-600 to-red-400 shadow-lg shadow-red-300/30">
          <svg className="h-10 w-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        </div>
        <h1 className="mb-2 text-3xl font-bold text-gray-900">Access Denied</h1>
        <p className="mb-6 text-base leading-relaxed text-gray-500">
          You don&apos;t have permission to access the admin dashboard.
        </p>
        <button
          onClick={handleSignOut}
          className="w-full rounded-lg bg-gradient-to-r from-red-600 to-red-400 px-6 py-3 text-base font-medium text-white shadow-md hover:from-red-700 hover:to-red-500 transition-all"
        >
          Sign Out
        </button>
      </div>
    </div>
  )
}
