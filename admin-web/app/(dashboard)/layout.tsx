import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { redirect } from 'next/navigation'
import Sidebar from '@/components/sidebar'
import Header from '@/components/header'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  console.log('🟣 [LAYOUT] Dashboard layout rendering')

  // Check authentication with regular client
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  console.log('🟣 [LAYOUT] User check:', { hasUser: !!user, email: user?.email })

  if (!user) {
    console.log('🟣 [LAYOUT] No user, redirecting to login')
    redirect('/login')
  }

  // Get user profile with admin check using service role (bypasses RLS)
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

  // Construct display name from available data
  const displayName = profile.first_name && profile.last_name
    ? `${profile.first_name} ${profile.last_name}`
    : profile.first_name || user.email || 'Admin'

  return (
    <div className="flex h-screen bg-background dark:bg-gray-950">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header user={{ name: displayName }} />
        <main className="flex-1 overflow-y-auto bg-gray-50 p-6 dark:bg-gray-900">
          {children}
        </main>
      </div>
    </div>
  )
}
