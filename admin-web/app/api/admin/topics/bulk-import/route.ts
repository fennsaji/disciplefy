import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import type { BulkImportRequest, BulkImportResult } from '@/types/admin'

/**
 * POST - Bulk import topics from CSV
 */
export async function POST(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    // Verify admin status
    const supabaseAdmin = await createAdminClient()
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json(
        { error: 'Unauthorized - Admin access required' },
        { status: 403 }
      )
    }

    // Parse request body
    const body: BulkImportRequest = await request.json()

    // Call the admin-recommended-topics Edge Function
    const functionUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-recommended-topics/bulk-import`

    const response = await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        'x-admin-user-id': user.id,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ error: 'Unknown error' }))
      console.error('Supabase function error:', response.status, errorData)
      return NextResponse.json(
        { error: errorData.error || 'Failed to bulk import topics' },
        { status: 500 }
      )
    }

    const data = await response.json()

    return NextResponse.json(data as BulkImportResult, { status: data.error_count > 0 ? 207 : 201 })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
