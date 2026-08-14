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

// Copied verbatim from admin-list-affiliate-keywords/index.ts
async function handleList(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }) {
  const { data, error } = await auth.adminSupabase
    .from('affiliate_keywords')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) return json({ error: 'Failed to list affiliate keywords', details: error.message }, 500)

  return json({ success: true, keywords: data })
}

// Copied verbatim from admin-create-affiliate-keyword/index.ts
async function handleCreate(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
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
}

// Copied verbatim from admin-toggle-affiliate-keyword/index.ts
async function handleToggle(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
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
}

// Copied verbatim from admin-delete-affiliate-keyword/index.ts
async function handleDelete(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
  const body: { id?: string } = await req.json()
  if (!body.id) return json({ error: 'Missing id' }, 400)

  const { data, error } = await ((auth.adminSupabase as any)
    .from('affiliate_keywords')
    .delete()
    .eq('id', body.id)
    .select()
    .single())
  if (error) {
    if ((error as any).code === 'PGRST116') return json({ error: 'Keyword not found' }, 404)
    return json({ error: 'Failed to delete affiliate keyword', details: error.message }, 500)
  }

  try {
    const { error: auditError } = await ((auth.adminSupabase as any).from('admin_logs').insert({
      admin_user_id: auth.adminUserId,
      action: 'delete_affiliate_keyword',
      details: { id: body.id, keyword: (data as any).keyword },
    }))
    if (auditError) console.warn('Failed to log admin action:', auditError)
  } catch (auditError) {
    console.warn('Failed to log admin action:', auditError)
  }

  return json({ success: true })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)
    const method = req.method

    if (method === 'GET' && pathParts.length === 1) return await handleList(auth)
    if (method === 'POST' && pathParts.length === 1) return await handleCreate(auth, req)
    if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'toggle') return await handleToggle(auth, req)
    if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'delete') return await handleDelete(auth, req)

    return json({ error: 'Not found' }, 404)
  } catch (error) {
    console.error('Error in admin-affiliate-keywords:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
