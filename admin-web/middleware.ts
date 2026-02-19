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
          request.cookies.set({ name, value, ...options })
          response = NextResponse.next({
            request: { headers: request.headers },
          })
          response.cookies.set({ name, value, ...options })
        },
        remove(name: string, options: CookieOptions) {
          request.cookies.set({ name, value: '', ...options })
          response = NextResponse.next({
            request: { headers: request.headers },
          })
          response.cookies.set({ name, value: '', ...options })
        },
      },
    }
  )

  // Allow auth callback route without authentication
  if (request.nextUrl.pathname.startsWith('/auth/callback')) {
    return response
  }

  // Validate the session server-side (cryptographically verified)
  const { data: { user } } = await supabase.auth.getUser()

  // No session — redirect to login (or 401 for API routes)
  if (!user && !request.nextUrl.pathname.startsWith('/login')) {
    if (request.nextUrl.pathname.startsWith('/api/')) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401, headers: response.headers }
      )
    }
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Authenticated user — check admin flag.
  // Uses the anon client with the user's session cookies; RLS allows users to
  // read their own profile row, so no service-role key is needed here.
  if (user && !request.nextUrl.pathname.startsWith('/login') && !request.nextUrl.pathname.startsWith('/unauthorized')) {
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle()

    if (!profile?.is_admin) {
      if (request.nextUrl.pathname.startsWith('/api/')) {
        return NextResponse.json(
          { error: 'Forbidden - Admin access required' },
          { status: 403, headers: response.headers }
        )
      }
      return NextResponse.redirect(new URL('/unauthorized', request.url))
    }
  }

  // Admin user on login page — redirect to dashboard
  if (user && request.nextUrl.pathname.startsWith('/login')) {
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle()

    if (profile?.is_admin) {
      return NextResponse.redirect(new URL('/', request.url))
    }
  }

  return response
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}
