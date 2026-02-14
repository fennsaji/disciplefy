import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch all system configuration settings
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
    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )
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

    // Fetch token limits from database (subscription_plans table)
    const { data: plans, error: plansError } = await supabaseAdmin
      .from('subscription_plans')
      .select('plan_code, features')
      .eq('is_active', true)
      .order('tier', { ascending: true })

    if (plansError) {
      console.error('[SYSTEM CONFIG] Error fetching subscription plans:', plansError)
    }

    // Extract daily tokens and voice conversations from each plan's features JSONB
    const planTokens = plans?.reduce((acc, plan) => {
      const dailyTokens = plan.features?.daily_tokens
      acc[plan.plan_code] = dailyTokens === -1 ? 999999999 : (dailyTokens || 0)
      return acc
    }, {} as Record<string, number>) || {}

    const planVoiceConversations = plans?.reduce((acc, plan) => {
      const voiceConversations = plan.features?.voice_conversations_monthly
      acc[plan.plan_code] = voiceConversations || 0
      return acc
    }, {} as Record<string, number>) || {}

    // Fetch all system config from database (system_config table)
    const { data: systemConfigs, error: configError } = await supabaseAdmin
      .from('system_config')
      .select('key, value')
      .eq('is_active', true)

    if (configError) {
      console.error('[SYSTEM CONFIG] Error fetching system config:', configError)
    }

    // Parse system config into key-value map
    const parseConfigValue = (key: string, value: string) => {
      // Integer configs
      if (key.includes('_days') || key === 'rollout_percentage') {
        return parseInt(value)
      }
      // Boolean configs
      if (key.includes('_enabled')) {
        return value === 'true'
      }
      // Everything else is string
      return value
    }

    const systemConfigMap = systemConfigs?.reduce((acc, config) => {
      acc[config.key] = parseConfigValue(config.key, config.value)
      return acc
    }, {} as Record<string, any>) || {}

    // Return current configuration
    // All values read directly from database tables
    const config = {
      // Token System - from subscription_plans table
      token_system: {
        daily_free_tokens: planTokens.free || 8,
        standard_daily_tokens: planTokens.standard || 20,
        plus_daily_tokens: planTokens.plus || 50,
        premium_daily_tokens: planTokens.premium || 999999999,
      },
      // Voice Features - from subscription_plans.features.voice_conversations_monthly
      voice_features: {
        free_monthly_conversations: planVoiceConversations.free || 0,
        standard_monthly_conversations: planVoiceConversations.standard || 10,
        plus_monthly_conversations: planVoiceConversations.plus || 15,
        premium_monthly_conversations: planVoiceConversations.premium || -1,
      },
      // Maintenance Mode - from system_config table
      maintenance_mode: {
        enabled: systemConfigMap.maintenance_mode_enabled || false,
        message: systemConfigMap.maintenance_mode_message || 'We are currently performing maintenance. Please check back soon.',
      },
      // App Version Control - from system_config table
      app_version: {
        min_android: systemConfigMap.min_app_version_android || '1.0.0',
        min_ios: systemConfigMap.min_app_version_ios || '1.0.0',
        min_web: systemConfigMap.min_app_version_web || '1.0.0',
        latest: systemConfigMap.latest_app_version || '1.0.0',
        force_update: systemConfigMap.force_update_enabled || false,
      },
      // Trial Configuration - from system_config table
      trial_config: {
        standard_trial_end_date: systemConfigMap.standard_trial_end_date || '2026-03-31T23:59:59+05:30',
        premium_trial_days: systemConfigMap.premium_trial_days || 7,
        premium_trial_start_date: systemConfigMap.premium_trial_start_date || '2026-04-01T00:00:00+05:30',
        grace_period_days: systemConfigMap.grace_period_days || 7,
      },
    }

    return NextResponse.json({ config })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * POST - Update system configuration
 * Token system updates go to database, other settings are noted for .env updates
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()

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
    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )
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

    // Handle token_system updates - save to database (subscription_plans table)
    if (body.token_system) {
      const { daily_free_tokens, standard_daily_tokens, plus_daily_tokens, premium_daily_tokens } = body.token_system

      const updates = [
        { plan_code: 'free', daily_tokens: daily_free_tokens },
        { plan_code: 'standard', daily_tokens: standard_daily_tokens },
        { plan_code: 'plus', daily_tokens: plus_daily_tokens },
        { plan_code: 'premium', daily_tokens: premium_daily_tokens === 999999999 ? -1 : premium_daily_tokens }
      ]

      for (const update of updates) {
        const { data: plan } = await supabaseAdmin
          .from('subscription_plans')
          .select('features')
          .eq('plan_code', update.plan_code)
          .single()

        if (plan) {
          const updatedFeatures = {
            ...plan.features,
            daily_tokens: update.daily_tokens
          }

          await supabaseAdmin
            .from('subscription_plans')
            .update({
              features: updatedFeatures,
              updated_at: new Date().toISOString()
            })
            .eq('plan_code', update.plan_code)
        }
      }

      return NextResponse.json({
        message: 'Token system updated successfully in database!',
        updated_plans: updates.map(u => u.plan_code)
      })
    }

    // Handle voice_features updates - save to subscription_plans.features JSONB
    if (body.voice_features) {
      const { free_monthly_conversations, standard_monthly_conversations, plus_monthly_conversations, premium_monthly_conversations } = body.voice_features

      const updates = [
        { plan_code: 'free', voice_conversations_monthly: free_monthly_conversations },
        { plan_code: 'standard', voice_conversations_monthly: standard_monthly_conversations },
        { plan_code: 'plus', voice_conversations_monthly: plus_monthly_conversations },
        { plan_code: 'premium', voice_conversations_monthly: premium_monthly_conversations }
      ]

      for (const update of updates) {
        const { data: plan } = await supabaseAdmin
          .from('subscription_plans')
          .select('features')
          .eq('plan_code', update.plan_code)
          .single()

        if (plan) {
          const updatedFeatures = {
            ...plan.features,
            voice_conversations_monthly: update.voice_conversations_monthly
          }

          await supabaseAdmin
            .from('subscription_plans')
            .update({
              features: updatedFeatures,
              updated_at: new Date().toISOString()
            })
            .eq('plan_code', update.plan_code)
        }
      }

      return NextResponse.json({
        message: 'Voice conversation limits updated successfully in database!',
        updated_plans: updates.map(u => u.plan_code)
      })
    }

    // Handle maintenance_mode updates - save to system_config table
    if (body.maintenance_mode) {
      const { enabled, message } = body.maintenance_mode

      const configUpdates = [
        { key: 'maintenance_mode_enabled', value: String(enabled) },
        { key: 'maintenance_mode_message', value: message }
      ]

      for (const update of configUpdates) {
        await supabaseAdmin
          .from('system_config')
          .update({
            value: update.value,
            updated_at: new Date().toISOString()
          })
          .eq('key', update.key)
      }

      return NextResponse.json({
        message: 'Maintenance mode updated successfully in database!',
        maintenance_enabled: enabled
      })
    }

    // Handle app_version updates - save to system_config table
    if (body.app_version) {
      const { min_android, min_ios, min_web, latest, force_update } = body.app_version

      const configUpdates = [
        { key: 'min_app_version_android', value: min_android },
        { key: 'min_app_version_ios', value: min_ios },
        { key: 'min_app_version_web', value: min_web },
        { key: 'latest_app_version', value: latest },
        { key: 'force_update_enabled', value: String(force_update) }
      ]

      for (const update of configUpdates) {
        await supabaseAdmin
          .from('system_config')
          .update({
            value: update.value,
            updated_at: new Date().toISOString()
          })
          .eq('key', update.key)
      }

      return NextResponse.json({
        message: 'App version control updated successfully in database!',
        versions: { min_android, min_ios, min_web, latest }
      })
    }

    // Handle trial_config updates - save to system_config table
    if (body.trial_config) {
      const { standard_trial_end_date, premium_trial_days, premium_trial_start_date, grace_period_days } = body.trial_config

      const configUpdates = [
        { key: 'standard_trial_end_date', value: standard_trial_end_date },
        { key: 'premium_trial_days', value: String(premium_trial_days) },
        { key: 'premium_trial_start_date', value: premium_trial_start_date },
        { key: 'grace_period_days', value: String(grace_period_days) }
      ]

      for (const update of configUpdates) {
        await supabaseAdmin
          .from('system_config')
          .update({
            value: update.value,
            updated_at: new Date().toISOString()
          })
          .eq('key', update.key)
      }

      return NextResponse.json({
        message: 'Trial configuration updated successfully in database!',
        trial_config: { standard_trial_end_date, premium_trial_days, premium_trial_start_date, grace_period_days }
      })
    }

    return NextResponse.json({
      message: 'No valid configuration section provided',
      received_config: body
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
