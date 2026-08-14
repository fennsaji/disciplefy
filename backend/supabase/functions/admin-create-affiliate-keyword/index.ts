import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

// Returns the admin client, or a Response if auth failed.
async function requireAdmin(req: Request): Promise<
  { adminSupabase: ReturnType<typeof createClient>; adminUserId: string } | Response
> {
  const authHeader = req.headers.get('Authorization')
  const adminUserId = req.headers.get('x-admin-user-id')
  if (!authHeader || !adminUserId) return json({ error: 'Unauthorized - Missing credentials' }, 401)

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (authHeader.replace('Bearer ', '') !== serviceRoleKey)
    return json({ error: 'Unauthorized - Invalid credentials' }, 401)

  const adminSupabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceRoleKey)
  const { data: profile, error } = await adminSupabase
    .from('user_profiles')
    .select('is_admin')
    .eq('id', adminUserId)
    .single() as any
  if (error || !(profile as any)?.is_admin) return json({ error: 'Forbidden - Admin access required' }, 403)

  return { adminSupabase, adminUserId } as any
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const body: { keyword?: string } = await req.json()
    const keyword = (body.keyword ?? '').trim()
    if (!keyword) return json({ error: 'Missing keyword' }, 400)
    if (keyword.length > 80) return json({ error: 'Keyword too long (max 80 characters)' }, 400)
    if (/[\[\]()`]/.test(keyword)) {
      return json({ error: 'Keyword cannot contain [ ] ( ) or ` characters' }, 400)
    }

    const { data, error } = await ((auth.adminSupabase as any)
      .from('affiliate_keywords')
      .insert({ keyword })
      .select()
      .single())
    if (error) {
      // 23505 = unique_violation (case-insensitive unique index on lower(keyword))
      if (error.code === '23505') return json({ error: 'Keyword already exists' }, 409)
      return json({ error: 'Failed to create affiliate keyword', details: error.message }, 500)
    }

    try {
      const { error: auditError } = await ((auth.adminSupabase as any).from('admin_logs').insert({
        admin_user_id: auth.adminUserId,
        action: 'create_affiliate_keyword',
        details: { keyword },
      }))
      if (auditError) console.warn('Failed to log admin action:', auditError)
    } catch (auditError) {
      console.warn('Failed to log admin action:', auditError)
    }

    return json({ success: true, keyword: data })
  } catch (error) {
    console.error('Error in admin-create-affiliate-keyword:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
