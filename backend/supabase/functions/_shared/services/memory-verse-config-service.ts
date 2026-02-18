import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Memory Verse Configuration
 * Database-driven configuration for memory verse system
 */
export interface MemoryVerseConfig {
  unlockLimits: {
    free: number
    standard: number
    plus: number
    premium: number
  }
  verseLimits: {
    free: number
    standard: number
    plus: number
    premium: number
  }
  availableModes: {
    free: string[]
    paid: string[]
  }
  spacedRepetition: {
    initialEaseFactor: number
    initialIntervalDays: number
    minEaseFactor: number
    maxIntervalDays: number
  }
  gamification: {
    masteryThreshold: number
    xpPerReview: number
    xpMasteryBonus: number
  }
}

/**
 * Service for managing memory verse configuration from database
 * Implements 5-minute cache pattern for performance
 */
export class MemoryVerseConfigService {
  private cache: MemoryVerseConfig | null = null
  private cacheTimestamp = 0
  private readonly CACHE_TTL = 5 * 60 * 1000 // 5 minutes

  // deno-lint-ignore no-explicit-any
  constructor(private supabaseClient: any) {}

  /**
   * Get complete memory verse configuration
   * Uses 5-minute cache to avoid excessive database queries
   */
  async getMemoryVerseConfig(forceRefresh = false): Promise<MemoryVerseConfig> {
    // Return cached config if still valid
    if (
      this.cache &&
      !forceRefresh &&
      Date.now() - this.cacheTimestamp < this.CACHE_TTL
    ) {
      return this.cache
    }

    // Fetch fresh config from database
    const { data, error } = await this.supabaseClient.rpc('get_system_configs')

    if (error) {
      console.error('[MemoryVerseConfigService] Error fetching config:', error)
      // Return default config on error
      return this.getDefaultConfig()
    }

    // Parse config from database response
    const configMap = new Map<string, string>(data.map((row: any) => [row.key, row.value]))

    this.cache = {
      unlockLimits: {
        free: parseInt(configMap.get('free_practice_unlock_limit') || '1'),
        standard: parseInt(configMap.get('standard_practice_unlock_limit') || '2'),
        plus: parseInt(configMap.get('plus_practice_unlock_limit') || '3'),
        premium: parseInt(configMap.get('premium_practice_unlock_limit') || '-1'),
      },
      verseLimits: {
        free: parseInt(configMap.get('free_memory_verses_limit') || '3'),
        standard: parseInt(configMap.get('standard_memory_verses_limit') || '5'),
        plus: parseInt(configMap.get('plus_memory_verses_limit') || '10'),
        premium: parseInt(configMap.get('premium_memory_verses_limit') || '-1'),
      },
      availableModes: {
        free: JSON.parse(
          configMap.get('free_available_practice_modes') ||
            '["flip_card", "type_it_out"]'
        ),
        paid: JSON.parse(
          configMap.get('paid_available_practice_modes') ||
            '["flip_card", "type_it_out", "cloze", "first_letter", "progressive", "word_scramble", "word_bank", "audio"]'
        ),
      },
      spacedRepetition: {
        initialEaseFactor: parseFloat(
          configMap.get('memory_verse_initial_ease_factor') || '2.5'
        ),
        initialIntervalDays: parseInt(
          configMap.get('memory_verse_initial_interval_days') || '1'
        ),
        minEaseFactor: parseFloat(
          configMap.get('memory_verse_min_ease_factor') || '1.3'
        ),
        maxIntervalDays: parseInt(
          configMap.get('memory_verse_max_interval_days') || '365'
        ),
      },
      gamification: {
        masteryThreshold: parseInt(
          configMap.get('memory_verse_mastery_threshold') || '5'
        ),
        xpPerReview: parseInt(configMap.get('memory_verse_xp_per_review') || '10'),
        xpMasteryBonus: parseInt(
          configMap.get('memory_verse_xp_mastery_bonus') || '50'
        ),
      },
    }

    this.cacheTimestamp = Date.now()
    return this.cache
  }

  /**
   * Get practice mode unlock limit for specific tier
   * Returns -1 for unlimited (premium)
   */
  async getUnlockLimit(tier: string): Promise<number> {
    const config = await this.getMemoryVerseConfig()
    const normalizedTier = tier.toLowerCase() as keyof typeof config.unlockLimits

    return config.unlockLimits[normalizedTier] ?? config.unlockLimits.free
  }

  /**
   * Get memory verse limit for specific tier
   * Returns -1 for unlimited (premium)
   */
  async getVerseLimits(tier: string): Promise<number> {
    const config = await this.getMemoryVerseConfig()
    const normalizedTier = tier.toLowerCase() as keyof typeof config.verseLimits

    return config.verseLimits[normalizedTier] ?? config.verseLimits.free
  }

  /**
   * Get available practice modes for specific tier
   * Free tier gets limited modes, paid tiers get all modes
   */
  async getAvailableModes(tier: string): Promise<string[]> {
    const config = await this.getMemoryVerseConfig()
    const normalizedTier = tier.toLowerCase()

    if (normalizedTier === 'free') {
      return config.availableModes.free
    }

    // Standard, Plus, Premium get all modes
    return config.availableModes.paid
  }

  /**
   * Get spaced repetition parameters
   */
  async getSpacedRepetitionConfig(): Promise<MemoryVerseConfig['spacedRepetition']> {
    const config = await this.getMemoryVerseConfig()
    return config.spacedRepetition
  }

  /**
   * Get gamification settings
   */
  async getGamificationConfig(): Promise<MemoryVerseConfig['gamification']> {
    const config = await this.getMemoryVerseConfig()
    return config.gamification
  }

  /**
   * Clear cache to force fresh database fetch on next request
   */
  clearMemoryVerseConfigCache(): void {
    this.cache = null
    this.cacheTimestamp = 0
  }

  /**
   * Default configuration (fallback if database fetch fails)
   */
  private getDefaultConfig(): MemoryVerseConfig {
    return {
      unlockLimits: {
        free: 1,
        standard: 2,
        plus: 3,
        premium: -1,
      },
      verseLimits: {
        free: 3,
        standard: 5,
        plus: 10,
        premium: -1,
      },
      availableModes: {
        free: ['flip_card', 'type_it_out'],
        paid: [
          'flip_card',
          'type_it_out',
          'cloze',
          'first_letter',
          'progressive',
          'word_scramble',
          'word_bank',
          'audio',
        ],
      },
      spacedRepetition: {
        initialEaseFactor: 2.5,
        initialIntervalDays: 1,
        minEaseFactor: 1.3,
        maxIntervalDays: 365,
      },
      gamification: {
        masteryThreshold: 5,
        xpPerReview: 10,
        xpMasteryBonus: 50,
      },
    }
  }

  /**
   * Check if tier has access to a specific practice mode
   */
  async hasAccessToMode(tier: string, mode: string): Promise<boolean> {
    const availableModes = await this.getAvailableModes(tier)
    return availableModes.includes(mode)
  }

  /**
   * Get upgrade tier recommendation based on current tier
   */
  getRecommendedUpgradeTier(currentTier: string): string {
    const tier = currentTier.toLowerCase()
    if (tier === 'free') return 'standard'
    if (tier === 'standard') return 'plus'
    if (tier === 'plus') return 'premium'
    return 'premium'
  }

  /**
   * Get user-friendly tier comparison for upgrade prompts
   */
  async getTierComparison(): Promise<
    Array<{
      tier: string
      tierName: string
      unlockLimit: number
      unlockLimitText: string
      verseLimit: number
      verseLimitText: string
      modeCount: number
    }>
  > {
    const config = await this.getMemoryVerseConfig()

    return [
      {
        tier: 'free',
        tierName: 'Free',
        unlockLimit: config.unlockLimits.free,
        unlockLimitText: `${config.unlockLimits.free} mode per verse per day`,
        verseLimit: config.verseLimits.free,
        verseLimitText: `${config.verseLimits.free} active verses`,
        modeCount: config.availableModes.free.length,
      },
      {
        tier: 'standard',
        tierName: 'Standard',
        unlockLimit: config.unlockLimits.standard,
        unlockLimitText: `${config.unlockLimits.standard} modes per verse per day`,
        verseLimit: config.verseLimits.standard,
        verseLimitText: `${config.verseLimits.standard} active verses`,
        modeCount: config.availableModes.paid.length,
      },
      {
        tier: 'plus',
        tierName: 'Plus',
        unlockLimit: config.unlockLimits.plus,
        unlockLimitText: `${config.unlockLimits.plus} modes per verse per day`,
        verseLimit: config.verseLimits.plus,
        verseLimitText: `${config.verseLimits.plus} active verses`,
        modeCount: config.availableModes.paid.length,
      },
      {
        tier: 'premium',
        tierName: 'Premium',
        unlockLimit: config.unlockLimits.premium,
        unlockLimitText: 'All modes unlocked',
        verseLimit: config.verseLimits.premium,
        verseLimitText: 'Unlimited verses',
        modeCount: config.availableModes.paid.length,
      },
    ]
  }
}
