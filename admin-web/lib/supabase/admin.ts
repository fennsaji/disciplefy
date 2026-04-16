import { createClient } from '@supabase/supabase-js'

/**
 * Creates a Supabase client with service role key for admin operations.
 * Uses createClient (not createServerClient) to ensure the service role key
 * is used as the Authorization header, bypassing RLS policies.
 * createServerClient reads JWT from cookies which overrides the service role.
 */
export async function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    }
  )
}
