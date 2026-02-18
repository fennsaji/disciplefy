import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')
  const origin = requestUrl.origin

  console.log('🟢 [CALLBACK] OAuth Callback invoked')
  console.log('🟢 [CALLBACK] Full URL:', request.url)
  console.log('🟢 [CALLBACK] Code received:', code ? 'Yes' : 'No')
  console.log('🟢 [CALLBACK] Code value (first 20 chars):', code?.substring(0, 20) + '...')

  if (code) {
    const cookieStore = await cookies()

    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          get(name: string) {
            const value = cookieStore.get(name)?.value
            return value
          },
          set(name: string, value: string, options: CookieOptions) {
            try {
              console.log('🍪 Setting cookie:', name)
              cookieStore.set({ name, value, ...options })
            } catch (error) {
              console.error('❌ Error setting cookie:', error)
            }
          },
          remove(name: string, options: CookieOptions) {
            try {
              console.log('🗑️ Removing cookie:', name)
              cookieStore.set({ name, value: '', ...options })
            } catch (error) {
              console.error('❌ Error removing cookie:', error)
            }
          },
        },
      }
    )

    // Exchange the code for a session
    console.log('🟢 [CALLBACK] Exchanging code for session...')
    const { data, error } = await supabase.auth.exchangeCodeForSession(code)

    console.log('🟢 [CALLBACK] Exchange result:', {
      success: !error,
      error: error?.message,
      errorDetails: error,
      hasSession: !!data.session,
      hasUser: !!data.user,
      userId: data.user?.id,
      userEmail: data.user?.email
    })

    if (!error && data.user) {
      console.log('✅ [CALLBACK] Session created for user:', data.user.email)
      console.log('✅ [CALLBACK] User ID:', data.user.id)

      // Use service role to check for existing profile (bypass RLS)
      console.log('🟢 [CALLBACK] Creating admin client with service role key')
      const supabaseAdmin = createServerClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
        {
          cookies: {
            get(name: string) {
              return cookieStore.get(name)?.value
            },
            set() {},
            remove() {},
          },
        }
      )

      // Check if user_profiles row exists, create if not
      console.log('🟢 [CALLBACK] Checking for existing profile...')
      const { data: profile, error: profileError } = await supabaseAdmin
        .from('user_profiles')
        .select('id, is_admin')
        .eq('id', data.user.id)
        .maybeSingle() // Use maybeSingle() instead of single() - returns null if no rows, doesn't throw error

      console.log('🟢 [CALLBACK] Profile check result:', {
        found: !!profile,
        profile,
        error: profileError?.message,
        errorCode: profileError?.code
      })

      // Extract name from OAuth provider metadata
      const userMetadata = data.user.user_metadata || {}
      const fullName = userMetadata.full_name || userMetadata.name || ''
      const firstName = userMetadata.given_name || fullName.split(' ')[0] || null
      const lastName = userMetadata.family_name || fullName.split(' ').slice(1).join(' ') || null

      console.log('👤 [CALLBACK] User metadata:', {
        full_name: userMetadata.full_name,
        given_name: userMetadata.given_name,
        family_name: userMetadata.family_name,
        extracted_first_name: firstName,
        extracted_last_name: lastName
      })

      if (!profile && !profileError) {
        console.log('📝 [CALLBACK] Creating user profile for:', data.user.email)

        // Check if email is in admin list from database (secure server-side check)
        const { data: adminConfig } = await supabaseAdmin
          .from('system_config')
          .select('value')
          .eq('key', 'admin_emails')
          .single()

        const adminEmails = adminConfig?.value ? adminConfig.value.split(',') : []
        const isAdmin = adminEmails.includes(data.user.email || '')

        if (isAdmin) {
          console.log('👑 [CALLBACK] Auto-granting admin access to:', data.user.email)
        }

        const { error: insertError } = await supabaseAdmin
          .from('user_profiles')
          .insert({
            id: data.user.id,
            first_name: firstName,
            last_name: lastName,
            language_preference: 'en',
            theme_preference: 'light',
            is_admin: isAdmin,
          })

        if (insertError) {
          console.error('❌ [CALLBACK] Error creating profile:', insertError)
        } else {
          console.log('✅ [CALLBACK] Profile created successfully with name:', firstName, lastName)

          // Create a free subscription for the new user
          console.log('📝 [CALLBACK] Creating free subscription for new user')
          const { data: freePlan } = await supabaseAdmin
            .from('subscription_plans')
            .select('id')
            .eq('plan_code', 'free')
            .single()

          if (freePlan) {
            const { error: subscriptionError } = await supabaseAdmin
              .from('subscriptions')
              .insert({
                user_id: data.user.id,
                plan_id: freePlan.id,
                plan_type: 'free_monthly',
                status: 'active',
                provider: 'system',
                current_period_start: new Date().toISOString(),
                current_period_end: new Date(Date.now() + 100 * 365 * 24 * 60 * 60 * 1000).toISOString(), // 100 years
              })

            if (subscriptionError) {
              console.error('❌ [CALLBACK] Error creating free subscription:', subscriptionError)
            } else {
              console.log('✅ [CALLBACK] Free subscription created successfully')
            }
          } else {
            console.error('❌ [CALLBACK] Free plan not found in subscription_plans')
          }
        }
      } else if (profile) {
        console.log('✅ [CALLBACK] Profile exists - is_admin:', profile.is_admin)

        // Check if email is in admin list from database (secure server-side check)
        const { data: adminConfig } = await supabaseAdmin
          .from('system_config')
          .select('value')
          .eq('key', 'admin_emails')
          .single()

        const adminEmails = adminConfig?.value ? adminConfig.value.split(',') : []
        const shouldBeAdmin = adminEmails.includes(data.user.email || '')

        const updates: any = {}

        // Update profile with name from OAuth if name is missing
        const { data: fullProfile } = await supabaseAdmin
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', data.user.id)
          .single()

        if (fullProfile && !fullProfile.first_name && !fullProfile.last_name && (firstName || lastName)) {
          console.log('📝 [CALLBACK] Adding name to update:', firstName, lastName)
          updates.first_name = firstName
          updates.last_name = lastName
        }

        // Grant admin if user should be admin but isn't
        if (shouldBeAdmin && !profile.is_admin) {
          console.log('👑 [CALLBACK] Upgrading user to admin:', data.user.email)
          updates.is_admin = true
        }

        // Apply updates if any
        if (Object.keys(updates).length > 0) {
          const { error: updateError } = await supabaseAdmin
            .from('user_profiles')
            .update(updates)
            .eq('id', data.user.id)

          if (updateError) {
            console.error('❌ [CALLBACK] Error updating profile:', updateError)
          } else {
            console.log('✅ [CALLBACK] Profile updated:', Object.keys(updates).join(', '))
          }
        }
      } else {
        console.error('⚠️ [CALLBACK] Profile query error:', profileError)
      }

      // Create response with redirect
      console.log('🟢 [CALLBACK] Creating redirect response to dashboard')
      const response = NextResponse.redirect(`${origin}/`)

      // Manually copy session cookies to response
      const cookiePrefix = `sb-${process.env.NEXT_PUBLIC_SUPABASE_URL?.split('://')[1]?.split('.')[0]}`
      console.log('🟢 [CALLBACK] Cookie prefix:', cookiePrefix)
      const sessionCookie = cookieStore.get(`${cookiePrefix}-auth-token`)

      console.log('🟢 [CALLBACK] Session cookie found:', !!sessionCookie)
      if (sessionCookie) {
        console.log('🍪 [CALLBACK] Copying session cookie to response:', sessionCookie.name)
        response.cookies.set(sessionCookie.name, sessionCookie.value, {
          ...sessionCookie,
          httpOnly: true,
          secure: process.env.NODE_ENV === 'production',
          sameSite: 'lax',
          maxAge: 60 * 60 * 24 * 7, // 7 days
        })
      } else {
        console.warn('⚠️ [CALLBACK] No session cookie found to copy')
      }

      console.log('🎉 [CALLBACK] Redirecting to dashboard:', `${origin}/`)
      return response
    }

    // If there was an error, redirect to login with error
    console.error('❌ [CALLBACK] OAuth error:', error?.message)
    console.error('❌ [CALLBACK] OAuth error details:', error)
    return NextResponse.redirect(`${origin}/login?error=auth_failed`)
  }

  // If no code, redirect to login
  return NextResponse.redirect(`${origin}/login`)
}
