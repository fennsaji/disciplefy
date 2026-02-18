import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return request.cookies.get(name)?.value
        },
        set(name: string, value: string, options: CookieOptions) {
          request.cookies.set({
            name,
            value,
            ...options,
          })
          response = NextResponse.next({
            request: {
              headers: request.headers,
            },
          })
          response.cookies.set({
            name,
            value,
            ...options,
          })
        },
        remove(name: string, options: CookieOptions) {
          request.cookies.set({
            name,
            value: '',
            ...options,
          })
          response = NextResponse.next({
            request: {
              headers: request.headers,
            },
          })
          response.cookies.set({
            name,
            value: '',
            ...options,
          })
        },
      },
    }
  )

  // Allow auth callback route without authentication
  if (request.nextUrl.pathname.startsWith('/auth/callback')) {
    return response
  }

  // Refresh session if expired - required for Server Components
  console.log('🟡 [MIDDLEWARE] Processing request:', request.nextUrl.pathname)
  console.log('🟡 [MIDDLEWARE] Request URL:', request.url)

  const { data: { user }, error: userError } = await supabase.auth.getUser()

  console.log('🟡 [MIDDLEWARE] User check result:', {
    hasUser: !!user,
    email: user?.email,
    userId: user?.id,
    error: userError?.message,
    errorCode: userError?.code
  })

  // If no user and not on login page, redirect to login (or return 401 for API routes)
  if (!user && !request.nextUrl.pathname.startsWith('/login')) {
    console.log('❌ [MIDDLEWARE] No user found')
    console.log('❌ [MIDDLEWARE] Attempted path:', request.nextUrl.pathname)

    // For API routes, return 401 instead of redirecting
    if (request.nextUrl.pathname.startsWith('/api/')) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401, headers: response.headers }
      )
    }

    return NextResponse.redirect(new URL('/login', request.url))
  }

  // If user exists, check admin flag using service role
  if (user && !request.nextUrl.pathname.startsWith('/login') && !request.nextUrl.pathname.startsWith('/unauthorized')) {
    console.log('🟡 [MIDDLEWARE] User authenticated, checking admin status...')
    console.log('🟡 [MIDDLEWARE] Service role key available:', !!process.env.SUPABASE_SERVICE_ROLE_KEY)

    // Use service role client to bypass RLS for admin check
    const supabaseAdmin = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      {
        cookies: {
          get(name: string) {
            return request.cookies.get(name)?.value
          },
          set() {},
          remove() {},
        },
      }
    )

    console.log('🟡 [MIDDLEWARE] Querying user_profiles table for user:', user.id)
    const { data: profile, error } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle() // Use maybeSingle() - returns null if no rows, doesn't throw error

    console.log('🔐 [MIDDLEWARE] Admin check result:', {
      userId: user.id,
      email: user.email,
      profileFound: !!profile,
      profileData: profile,
      error: error?.message,
      errorCode: error?.code,
      isAdminValue: profile?.is_admin,
      isAdminType: typeof profile?.is_admin
    })

    // If not admin, redirect to unauthorized page (or return 403 for API routes)
    if (!profile?.is_admin) {
      console.error('❌ [MIDDLEWARE] NOT ADMIN')
      console.error('❌ [MIDDLEWARE] Reason: profile?.is_admin =', profile?.is_admin)
      console.error('❌ [MIDDLEWARE] Profile object:', JSON.stringify(profile))

      // For API routes, return 403 instead of redirecting
      if (request.nextUrl.pathname.startsWith('/api/')) {
        return NextResponse.json(
          { error: 'Forbidden - Admin access required' },
          { status: 403, headers: response.headers }
        )
      }

      return NextResponse.redirect(new URL('/unauthorized', request.url))
    }

    console.log('✅ [MIDDLEWARE] ADMIN ACCESS GRANTED')
  }

  // If user is logged in and on login page, redirect to home
  if (user && request.nextUrl.pathname.startsWith('/login')) {
    console.log('🟡 [MIDDLEWARE] User on login page, checking if should redirect')

    // Use service role to verify admin status
    const supabaseAdmin = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      {
        cookies: {
          get(name: string) {
            return request.cookies.get(name)?.value
          },
          set() {},
          remove() {},
        },
      }
    )

    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle() // Use maybeSingle() - returns null if no rows, doesn't throw error

    console.log('🟡 [MIDDLEWARE] Login page admin check:', {
      hasProfile: !!profile,
      isAdmin: profile?.is_admin
    })

    if (profile?.is_admin) {
      console.log('✅ [MIDDLEWARE] Admin user on login page, redirecting to dashboard')
      return NextResponse.redirect(new URL('/', request.url))
    } else {
      console.log('⚠️ [MIDDLEWARE] Non-admin user on login page, staying on login')
    }
  }

  console.log('🟡 [MIDDLEWARE] Request processed, continuing...')
  return response
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * Note: /auth/callback is handled but allowed through in middleware
     */
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}
