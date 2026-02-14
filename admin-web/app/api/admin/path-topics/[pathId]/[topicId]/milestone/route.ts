import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import type { ToggleMilestoneRequest, ToggleMilestoneResponse } from '@/types/admin'

/**
 * PATCH - Toggle milestone flag for topic in path
 */
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ pathId: string; topicId: string }> }
) {
  try {
    const { pathId, topicId } = await params

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
    const body: ToggleMilestoneRequest = await request.json()

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
    const { data, error } = await supabase.functions.invoke(
      `admin-learning-path-topics/${pathId}/${topicId}/milestone`,
      {
        method: 'PATCH',
        body,
      }
    )

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to toggle milestone' },
        { status: error.message?.includes('not found') ? 404 : 500 }
      )
    }

    return NextResponse.json(data as ToggleMilestoneResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
