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

    const body: { id?: string; is_active?: boolean } = await req.json()
    if (!body.id || typeof body.is_active !== 'boolean')
      return json({ error: 'Missing id or is_active' }, 400)

    const { data, error } = await ((auth.adminSupabase as any)
      .from('affiliate_keywords')
      .update({ is_active: body.is_active, updated_at: new Date().toISOString() })
      .eq('id', body.id)
      .select()
      .single())
    if (error) {
      if ((error as any).code === 'PGRST116') return json({ error: 'Keyword not found' }, 404)
      return json({ error: 'Failed to toggle affiliate keyword', details: error.message }, 500)
    }

    try {
      const { error: auditError } = await ((auth.adminSupabase as any).from('admin_logs').insert({
        admin_user_id: auth.adminUserId,
        action: 'toggle_affiliate_keyword',
        details: { id: body.id, keyword: (data as any).keyword, is_active: body.is_active },
      }))
      if (auditError) console.warn('Failed to log admin action:', auditError)
    } catch (auditError) {
      console.warn('Failed to log admin action:', auditError)
    }

    return json({ success: true, keyword: data })
  } catch (error) {
    console.error('Error in admin-toggle-affiliate-keyword:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
