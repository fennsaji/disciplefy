import type { SupabaseClient, User } from '@supabase/supabase-js'

const PAGE_SIZE = 1000
const MAX_PAGES = 50 // safety cap: 50k users

/**
 * Fetch ALL auth users, paginating past the admin API's 50-per-page default.
 * Routes that need email lookups or email search must use this instead of a
 * bare `auth.admin.listUsers()`, which silently returns only the first page.
 */
export async function listAllAuthUsers(
  supabaseAdmin: SupabaseClient
): Promise<User[]> {
  const users: User[] = []
  for (let page = 1; page <= MAX_PAGES; page++) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({
      page,
      perPage: PAGE_SIZE,
    })
    if (error) throw error
    users.push(...data.users)
    if (data.users.length < PAGE_SIZE) break
  }
  return users
}

/**
 * Build a userId -> email map for the given user ids (or all users when
 * `userIds` is omitted).
 */
export async function getAuthEmailMap(
  supabaseAdmin: SupabaseClient,
  userIds?: string[]
): Promise<Record<string, string>> {
  const users = await listAllAuthUsers(supabaseAdmin)
  const idFilter = userIds ? new Set(userIds) : null
  return Object.fromEntries(
    users
      .filter(u => (idFilter ? idFilter.has(u.id) : true))
      .map(u => [u.id, u.email || ''])
  )
}
