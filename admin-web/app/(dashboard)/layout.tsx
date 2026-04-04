// admin-web/app/(dashboard)/layout.tsx
import type { ReactNode } from 'react'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { redirect } from 'next/navigation'
import DashboardShell from '@/components/dashboard-shell'

export default async function DashboardLayout({
  children,
}: {
  children: ReactNode
}) {
  console.log('🟣 [LAYOUT] Dashboard layout rendering')

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  console.log('🟣 [LAYOUT] User check:', { hasUser: !!user, email: user?.email })

  if (!user) {
    console.log('🟣 [LAYOUT] No user, redirecting to login')
    redirect('/login')
  }

  console.log('🟣 [LAYOUT] Checking admin status with service role...')
  const supabaseAdmin = await createAdminClient()
  const { data: profile, error } = await supabaseAdmin
    .from('user_profiles')
    .select('is_admin, first_name, last_name')
    .eq('id', user.id)
    .single()

  console.log('🟣 [LAYOUT] Admin check result:', {
    profileFound: !!profile,
    isAdmin: profile?.is_admin,
    firstName: profile?.first_name,
    lastName: profile?.last_name,
    error: error?.message
  })

  if (!profile?.is_admin) {
    console.log('🟣 [LAYOUT] Not admin, redirecting to unauthorized')
    redirect('/unauthorized')
  }

  console.log('🟣 [LAYOUT] Admin access granted, rendering dashboard')

  const displayName = profile.first_name && profile.last_name
    ? `${profile.first_name} ${profile.last_name}`
    : profile.first_name || user.email || 'Admin'

  return (
    <DashboardShell user={{ name: displayName }}>
      {children}
    </DashboardShell>
  )
}
