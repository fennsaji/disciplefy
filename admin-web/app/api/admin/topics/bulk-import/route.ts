import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import type { BulkImportRequest, BulkImportResult } from '@/types/admin'

/**
 * POST - Bulk import topics from CSV
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
    const body: BulkImportRequest = await request.json()

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

    // Call the admin-recommended-topics Edge Function
    const { data, error } = await supabase.functions.invoke('admin-recommended-topics/bulk-import', {
      method: 'POST',
      body,
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to bulk import topics' },
        { status: 500 }
      )
    }

    return NextResponse.json(data as BulkImportResult, { status: data.error_count > 0 ? 207 : 201 })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
