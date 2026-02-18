import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import type { ReorderTopicsRequest, ReorderTopicsResponse } from '@/types/admin'

/**
 * PATCH - Reorder topics in learning path
 */
export async function PATCH(request: NextRequest) {
  try {
    // Verify admin authentication
    const cookieStore = await cookies()
    const authToken = cookieStore.get('sb-access-token')?.value

    if (!authToken) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    // Parse request body
    const body: ReorderTopicsRequest = await request.json()

    // Create Supabase client
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      {
        auth: {
          persistSession: false,
        },
      }
    )

    // Call the admin-learning-path-topics Edge Function
    const { data, error } = await supabase.functions.invoke('admin-learning-path-topics/reorder', {
      method: 'PATCH',
      body,
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to reorder topics' },
        { status: 500 }
      )
    }

    return NextResponse.json(data as ReorderTopicsResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
