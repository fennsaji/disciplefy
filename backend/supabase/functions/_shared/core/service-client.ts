/**
 * Shared service-role Supabase client.
 *
 * One client per worker (per URL/key pair) instead of a new client per call:
 * createClient builds auth, realtime and fetch wrappers each time, so
 * per-call clients add CPU and memory on every request.
 */

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

const clients = new Map<string, SupabaseClient>()

/**
 * Returns the worker-wide service-role client. Defaults to SUPABASE_URL /
 * SUPABASE_SERVICE_ROLE_KEY; explicit values get their own cached client.
 */
export function getServiceRoleClient(
  supabaseUrl: string = Deno.env.get('SUPABASE_URL') ?? '',
  supabaseServiceKey: string = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
): SupabaseClient {
  const cacheKey = `${supabaseUrl}\n${supabaseServiceKey}`
  let client = clients.get(cacheKey)
  if (!client) {
    client = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    clients.set(cacheKey, client)
  }
  return client
}
