import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import type { AddTopicToPathRequest, AddTopicToPathResponse, RemoveTopicFromPathRequest, RemoveTopicFromPathResponse } from '@/types/admin'

/**
 * POST - Add topic to learning path
 */
export async function POST(request: NextRequest) {
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
    const body: AddTopicToPathRequest = await request.json()

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
    const { data, error } = await supabase.functions.invoke('admin-learning-path-topics', {
      method: 'POST',
      body,
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to add topic to path' },
        { status: 500 }
      )
    }

    return NextResponse.json(data as AddTopicToPathResponse, { status: 201 })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * DELETE - Remove topic from learning path
 */
export async function DELETE(request: NextRequest) {
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
    const body: RemoveTopicFromPathRequest = await request.json()

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
    const { data, error } = await supabase.functions.invoke('admin-learning-path-topics', {
      method: 'DELETE',
      body,
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to remove topic from path' },
        { status: error.message?.includes('not found') ? 404 : 500 }
      )
    }

    return NextResponse.json(data as RemoveTopicFromPathResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
