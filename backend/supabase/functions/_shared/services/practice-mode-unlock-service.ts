import { SupabaseClient } from '@supabase/supabase-js'

/**
 * Status returned by mode unlock check
 */
export interface ModeUnlockStatus {
  status: 'tier_locked' | 'unlocked' | 'can_unlock' | 'unlock_limit_reached'
  mode: string
  tier: string
  availableModes: string[]
  unlockedModes: string[]
  unlockSlotsRemaining: number
  message: string
  unlockLimit?: number
}

/**
 * Result of unlock attempt
 */
export interface UnlockModeResult {
  success: boolean
  message: string
  error?: string
  unlockedModes?: string[]
  unlockSlotsRemaining?: number
  unlockStatus?: ModeUnlockStatus
}

/**
 * Service for managing tier-based practice mode unlock limits
 */
export class PracticeModeUnlockService {
  // Free tier can only choose from these two modes
  private static readonly FREE_TIER_MODES = ['flip_card', 'type_it_out']

  // All valid practice modes
  private static readonly ALL_MODES = [
    'flip_card',
    'type_it_out',
    'cloze',
    'first_letter',
    'progressive',
    'word_scramble',
    'word_bank',
    'audio',
  ]

  // Tier-based unlock limits per verse per day
  private static readonly UNLOCK_LIMITS: Record<string, number> = {
    free: 1,
    standard: 2,
    plus: 3,
    premium: -1, // Unlimited
  }

  constructor(private supabaseClient: SupabaseClient) {}

  /**
   * Check if a mode is available in the user's tier pool
   * (not related to unlock limit, just tier availability)
   */
  checkModeTierAvailability(tier: string, mode: string): {
    available: boolean
    reason: 'available' | 'tier_locked'
    availableModes: string[]
  } {
    const availableModes = this.getAvailableModesForTier(tier)
    const available = availableModes.includes(mode)

    return {
      available,
      reason: available ? 'available' : 'tier_locked',
      availableModes,
    }
  }

  /**
   * Get available mode pool based on tier
   */
  getAvailableModesForTier(tier: string): string[] {
    if (tier === 'free') {
      return PracticeModeUnlockService.FREE_TIER_MODES
    }
    return PracticeModeUnlockService.ALL_MODES
  }

  /**
   * Get unlock limit based on tier
   */
  getUnlockLimit(tier: string): number {
    return PracticeModeUnlockService.UNLOCK_LIMITS[tier] || PracticeModeUnlockService.UNLOCK_LIMITS.free
  }

  /**
   * Check the unlock status for a specific mode
   * Returns whether mode is tier_locked, unlocked, can_unlock, or unlock_limit_reached
   */
  async getModeUnlockStatus(
    userId: string,
    verseId: string,
    mode: string,
    tier: string
  ): Promise<ModeUnlockStatus> {
    const { data, error } = await this.supabaseClient.rpc(
      'check_mode_unlock_status',
      {
        p_user_id: userId,
        p_memory_verse_id: verseId,
        p_mode: mode,
        p_tier: tier,
      }
    )

    if (error) {
      console.error('[PracticeModeUnlockService] Error checking unlock status:', error)
      throw new Error('Failed to check mode unlock status')
    }

    return {
      status: data.status,
      mode: data.mode,
      tier: data.tier,
      availableModes: data.available_modes || [],
      unlockedModes: data.unlocked_modes || [],
      unlockSlotsRemaining: data.unlock_slots_remaining || 0,
      message: data.message || '',
      unlockLimit: data.unlock_limit,
    }
  }

  /**
   * Unlock a practice mode for a verse (if user has remaining slots)
   * This is called on the first practice attempt with a new mode
   */
  async unlockMode(
    userId: string,
    verseId: string,
    mode: string,
    tier: string
  ): Promise<UnlockModeResult> {
    const { data, error } = await this.supabaseClient.rpc('unlock_practice_mode', {
      p_user_id: userId,
      p_memory_verse_id: verseId,
      p_mode: mode,
      p_tier: tier,
    })

    if (error) {
      console.error('[PracticeModeUnlockService] Error unlocking mode:', error)
      throw new Error('Failed to unlock practice mode')
    }

    return {
      success: data.success,
      message: data.message,
      error: data.error,
      unlockedModes: data.unlocked_modes,
      unlockSlotsRemaining: data.unlock_slots_remaining,
      unlockStatus: data.unlock_status,
    }
  }

  /**
   * Get user-friendly error message for tier-locked mode
   */
  getTierLockedMessage(mode: string, tier: string): string {
    const modeNames: Record<string, string> = {
      cloze: 'Cloze Practice',
      first_letter: 'First Letter',
      progressive: 'Progressive Reveal',
      word_scramble: 'Word Scramble',
      word_bank: 'Word Bank',
      audio: 'Audio Practice',
      flip_card: 'Flip Card',
      type_it_out: 'Type It Out',
    }

    const modeName = modeNames[mode] || mode
    const tierName = tier.charAt(0).toUpperCase() + tier.slice(1)

    return `${modeName} is available on Standard, Plus, and Premium plans. You're currently on the ${tierName} plan. Upgrade to unlock advanced practice modes.`
  }

  /**
   * Get user-friendly error message for unlock limit exceeded
   */
  getUnlockLimitMessage(
    unlockedModes: string[],
    limit: number,
    tier: string
  ): string {
    const tierName = tier.charAt(0).toUpperCase() + tier.slice(1)
    const unlockedCount = unlockedModes.length

    const modeNames: Record<string, string> = {
      flip_card: 'Flip Card',
      type_it_out: 'Type It Out',
      cloze: 'Cloze',
      first_letter: 'First Letter',
      progressive: 'Progressive',
      word_scramble: 'Word Scramble',
      word_bank: 'Word Bank',
      audio: 'Audio',
    }

    const unlockedModeNames = unlockedModes
      .map((mode) => modeNames[mode] || mode)
      .join(', ')

    return `You've unlocked ${unlockedCount} practice mode${
      unlockedCount > 1 ? 's' : ''
    } for this verse today (${unlockedModeNames}). ${tierName} plan allows ${limit} mode${
      limit > 1 ? 's' : ''
    } per verse per day. Upgrade for more variety!`
  }

  /**
   * Get recommended upgrade tier based on current tier
   */
  getRecommendedUpgradeTier(currentTier: string): string {
    if (currentTier === 'free') return 'standard'
    if (currentTier === 'standard') return 'plus'
    if (currentTier === 'plus') return 'premium'
    return 'premium'
  }

  /**
   * Get unlock limit details for all tiers (for upgrade dialog)
   */
  static getAllTierLimits(): Array<{
    tier: string
    tierName: string
    unlockLimit: number
    unlockLimitText: string
    price: string
  }> {
    return [
      {
        tier: 'standard',
        tierName: 'Standard',
        unlockLimit: 2,
        unlockLimitText: '2 modes per verse per day',
        price: '₹79/month',
      },
      {
        tier: 'plus',
        tierName: 'Plus',
        unlockLimit: 3,
        unlockLimitText: '3 modes per verse per day',
        price: '₹149/month',
      },
      {
        tier: 'premium',
        tierName: 'Premium',
        unlockLimit: -1,
        unlockLimitText: 'All modes unlocked',
        price: '₹499/month',
      },
    ]
  }
}
