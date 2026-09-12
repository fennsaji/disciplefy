import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

const RS_BACKEND_URL = process.env.RS_BACKEND_URL || 'http://localhost:8080'

async function getAdminToken() {
  const supabase = await createClient()
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return null
  const supabaseAdmin = await createAdminClient()
  const { data: profile } = await supabaseAdmin.from('user_profiles').select('is_admin').eq('id', user.id).single()
  if (!profile?.is_admin) return null
  const { data: { session } } = await supabase.auth.getSession()
  return session?.access_token ?? null
}

export async function GET(_request: NextRequest, { params }: { params: Promise<{ job: string }> }) {
  const token = await getAdminToken()
  if (!token) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { job } = await params
  const res = await fetch(`${RS_BACKEND_URL}/api/v1/admin/content-pipeline/${encodeURIComponent(job)}`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  })
  const data = await res.json().catch(() => ({ error: 'Unknown error' }))
  return NextResponse.json(data, { status: res.status })
}
