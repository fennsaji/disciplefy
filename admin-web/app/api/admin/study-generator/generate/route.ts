import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

/**
 * GET - Stream SSE events for ongoing generation
 */
export async function GET(request: NextRequest) {
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

    // Get generation parameters from the URL
    const { searchParams } = new URL(request.url)

    // Extract all required parameters
    const input_type = searchParams.get('input_type')
    const input_value = searchParams.get('input_value')
    const language = searchParams.get('language') || 'en'
    const mode = searchParams.get('mode') || 'standard'

    if (!input_type || !input_value) {
      return NextResponse.json(
        { error: 'Missing required parameters: input_type and input_value' },
        { status: 400 }
      )
    }

    // Build URL for admin-study-generator Edge Function
    const edgeParams = new URLSearchParams({
      input_type,
      input_value,
      language,
      mode,
    })

    // Add optional topic_description if present
    const topic_description = searchParams.get('topic_description')
    if (topic_description) {
      edgeParams.append('topic_description', topic_description)
    }

    // Get the user's JWT token to pass to the Edge Function
    const { data: { session } } = await supabaseUser.auth.getSession()

    if (!session?.access_token) {
      return NextResponse.json(
        { error: 'No valid session token' },
        { status: 401 }
      )
    }

    const functionUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-study-generator?${edgeParams.toString()}`

    // Stream the SSE response from Edge Function to client
    // Pass the user's JWT token for authentication
    const response = await fetch(functionUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'apikey': process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '',
      },
    })

    if (!response.ok || !response.body) {
      return NextResponse.json(
        { error: 'Failed to connect to generation service' },
        { status: response.status || 500 }
      )
    }

    // Return SSE stream to client
    return new NextResponse(response.body, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * POST - Start generation and return URL parameters for SSE streaming
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
    const body = await request.json()
    const { source, topic_id, input_type, input_value, study_mode, language, learning_path_id } = body

    // Validate required fields
    if (!study_mode || !language) {
      return NextResponse.json(
        { error: 'study_mode and language are required' },
        { status: 400 }
      )
    }

    if (source === 'topic' && !topic_id) {
      return NextResponse.json(
        { error: 'topic_id is required when source is topic' },
        { status: 400 }
      )
    }

    if (source === 'custom' && (!input_type || !input_value)) {
      return NextResponse.json(
        { error: 'input_type and input_value are required when source is custom' },
        { status: 400 }
      )
    }

    // Determine input_type and input_value for Edge Function
    let edgeInputType: string
    let edgeInputValue: string
    let topicDescription: string | undefined

    if (source === 'topic' && topic_id) {
      // When source is topic, we need to fetch the topic details first
      console.log('[Study Generator] Fetching topic:', topic_id)
      const { data: topicData, error: topicError } = await supabaseAdmin
        .from('recommended_topics')
        .select('title, input_type, description')
        .eq('id', topic_id)
        .single()

      console.log('[Study Generator] Topic query result:', {
        found: !!topicData,
        error: topicError?.message,
        errorCode: topicError?.code,
        topicId: topic_id,
      })

      if (topicError || !topicData) {
        console.error('[Study Generator] Topic not found:', {
          topic_id,
          error: topicError,
        })
        return NextResponse.json(
          { error: 'Topic not found', details: topicError?.message },
          { status: 404 }
        )
      }

      // The title is the input_value
      edgeInputType = topicData.input_type || 'topic'
      edgeInputValue = topicData.title
      topicDescription = topicData.description
    } else if (source === 'custom') {
      edgeInputType = input_type
      edgeInputValue = input_value
    } else {
      return NextResponse.json(
        { error: 'Invalid source or missing data' },
        { status: 400 }
      )
    }

    // Get the user's session token to pass in query params for EventSource
    const { data: { session } } = await supabaseUser.auth.getSession()

    if (!session?.access_token) {
      return NextResponse.json(
        { error: 'No valid session token' },
        { status: 401 }
      )
    }

    // Return the parameters needed for the client to connect via SSE
    // Include auth tokens in query params since EventSource doesn't support headers
    const streamParams: any = {
      input_type: edgeInputType,
      input_value: edgeInputValue,
      language: language,
      mode: study_mode,
      authorization: session.access_token,
      apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '',
    }

    if (topicDescription) {
      streamParams.topic_description = topicDescription
    }

    console.log('[Study Generator] Returning stream params for topic:', edgeInputValue)

    // Generate a unique ID for tracking this generation
    const generationId = `${Date.now()}_${Math.random().toString(36).substring(7)}`

    return NextResponse.json({
      generation_id: generationId,
      stream_params: streamParams,
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
