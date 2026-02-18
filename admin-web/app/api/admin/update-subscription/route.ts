import { createClient } from '@supabase/supabase-js'
import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import type { UpdateSubscriptionRequest, UpdateSubscriptionResponse } from '@/types/admin'

export async function POST(request: NextRequest) {
  try {
    // Verify admin authentication using Supabase SSR
    const cookieStore = await cookies()

    const supabaseAuth = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          get(name: string) {
            return cookieStore.get(name)?.value
          },
          set(name: string, value: string, options: CookieOptions) {
            cookieStore.set({ name, value, ...options })
          },
          remove(name: string, options: CookieOptions) {
            cookieStore.set({ name, value: '', ...options })
          },
        },
      }
    )

    // Get session (includes user and access token)
    const { data: { session }, error: sessionError } = await supabaseAuth.auth.getSession()

    if (sessionError || !session || !session.user) {
      console.error('Auth error:', sessionError)
      return NextResponse.json(
        { error: 'Unauthorized - Please log in' },
        { status: 401 }
      )
    }

    const user = session.user

    // Create Supabase client with service role for admin operations
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      {
        auth: {
          persistSession: false,
        },
      }
    )

    // Parse request body
    const body: UpdateSubscriptionRequest = await request.json()

    // Validate required fields
    if (!body.target_user_id || !body.new_tier) {
      return NextResponse.json(
        { error: 'Missing required fields: target_user_id, new_tier' },
        { status: 400 }
      )
    }

    // Call the admin-update-subscription Supabase Edge Function
    // Pass the user's access token so the Edge Function can verify admin status
    const { data, error } = await supabase.functions.invoke('admin-update-subscription', {
      body: {
        target_user_id: body.target_user_id,
        new_tier: body.new_tier,
        effective_date: body.effective_date,
        reason: body.reason,
        // Extended fields for full subscription editing
        new_status: body.new_status,
        new_start_date: body.new_start_date,
        new_end_date: body.new_end_date,
        plan_name: body.plan_name,
        billing_cycle: body.billing_cycle,
      },
      headers: {
        Authorization: `Bearer ${session.access_token}`,
      },
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to update subscription' },
        { status: 500 }
      )
    }

    // Return the result
    return NextResponse.json(data as UpdateSubscriptionResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
