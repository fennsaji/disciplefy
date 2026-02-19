import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

export async function GET() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: userError } = await supabase.auth.getUser()

    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )

    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { data: admins, error } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name, created_at')
      .eq('is_admin', true)
      .order('created_at', { ascending: true })

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 })
    }

    const adminIds = (admins || []).map((a) => a.id)

    // Fetch emails from auth
    let emailsMap: Record<string, string> = {}
    try {
      const { data: authData } = await supabaseAdmin.auth.admin.listUsers()
      emailsMap = Object.fromEntries(
        authData.users
          .filter((u) => adminIds.includes(u.id))
          .map((u) => [u.id, u.email || ''])
      )
    } catch (_) {}

    const result = (admins || []).map((a) => ({
      id: a.id,
      full_name: [a.first_name, a.last_name].filter(Boolean).join(' ') || 'Unknown',
      email: emailsMap[a.id] || null,
      created_at: a.created_at,
      is_self: a.id === user.id,
    }))

    return NextResponse.json({ admins: result })
  } catch (err) {
    console.error('[list-admins]', err)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
