import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

const RS_BACKEND_URL = process.env.RS_BACKEND_URL || 'http://localhost:8080'

export async function POST(_request: NextRequest) {
  try {
    const supabase = await createClient()
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

    const supabaseAdmin = await createAdminClient()
    const { data: profile } = await supabaseAdmin
      .from('user_profiles').select('is_admin').eq('id', user.id).single()
    if (!profile?.is_admin) return NextResponse.json({ error: 'Unauthorized - Admin access required' }, { status: 403 })

    const { data: { session } } = await supabase.auth.getSession()
    const token = session?.access_token
    if (!token) return NextResponse.json({ error: 'No session token' }, { status: 401 })

    const rsResponse = await fetch(`${RS_BACKEND_URL}/api/v1/admin/cron/trigger`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}` },
    })

    const data = await rsResponse.json().catch(() => ({ error: 'Unknown error' }))
    if (!rsResponse.ok) {
      return NextResponse.json({ error: data.message || 'Failed to trigger blog generation' }, { status: rsResponse.status })
    }

    return NextResponse.json({ message: data.message || 'Blog generation triggered' })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
