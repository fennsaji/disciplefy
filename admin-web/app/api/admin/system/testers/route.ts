import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

const CONFIG_KEY = 'feature_tester_emails'
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

async function requireAdmin() {
  const supabaseUser = await createClient()
  const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
  if (userError || !user) {
    return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
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
    return { error: NextResponse.json({ error: 'Unauthorized - Admin access required' }, { status: 403 }) }
  }

  return { user, supabaseAdmin }
}

/**
 * GET - Fetch the feature tester email list
 */
export async function GET(_request: NextRequest) {
  try {
    const auth = await requireAdmin()
    if ('error' in auth) return auth.error

    const { data, error } = await auth.supabaseAdmin
      .from('system_config')
      .select('value')
      .eq('key', CONFIG_KEY)
      .maybeSingle()

    if (error) throw error

    const emails = ((data?.value as string) || '')
      .split(',')
      .map(e => e.trim().toLowerCase())
      .filter(Boolean)

    return NextResponse.json({ emails })
  } catch (error) {
    console.error('[Testers API] GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

/**
 * POST - Replace the feature tester email list
 */
export async function POST(request: NextRequest) {
  try {
    const auth = await requireAdmin()
    if ('error' in auth) return auth.error

    const body = await request.json()
    if (!Array.isArray(body.emails)) {
      return NextResponse.json({ error: 'emails must be an array' }, { status: 400 })
    }

    const normalized = Array.from(new Set(
      (body.emails as string[]).map(e => String(e).trim().toLowerCase()).filter(Boolean)
    ))

    const invalid = normalized.filter(e => !EMAIL_RE.test(e))
    if (invalid.length > 0) {
      return NextResponse.json(
        { error: `Invalid email(s): ${invalid.join(', ')}` },
        { status: 400 }
      )
    }

    const { error } = await auth.supabaseAdmin
      .from('system_config')
      .upsert({
        key: CONFIG_KEY,
        value: normalized.join(','),
        description: 'Comma-separated emails allowed to bypass feature flags that have allow_tester_bypass=true. Server-side only — never expose to clients.',
        is_active: false,
        updated_at: new Date().toISOString()
      }, { onConflict: 'key' })

    if (error) throw error

    return NextResponse.json({ message: 'Feature tester list updated', emails: normalized })
  } catch (error) {
    console.error('[Testers API] POST error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
