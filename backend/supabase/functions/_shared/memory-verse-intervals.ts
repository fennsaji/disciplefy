/**
 * Memory Verse Review Intervals Utility
 *
 * Provides shared interval calculation logic for memory verse review scheduling.
 * Used by both submit-memory-verse-review and submit-memory-practice endpoints.
 *
 * Progressive spacing after mastery (quality 5):
 * - Review 15: 3 days
 * - Review 16: 7 days (1 week)
 * - Review 17: 14 days (2 weeks)
 * - Review 18: 21 days (3 weeks)
 * - Review 19: 30 days (1 month)
 * - Review 20: 45 days (1.5 months)
 * - Review 21: 60 days (2 months)
 * - Review 22: 90 days (3 months)
 * - Review 23: 120 days (4 months)
 * - Review 24: 150 days (5 months)
 * - Review 25+: 180 days (6 months max)
 */

/**
 * Progressive interval schedule for mastered verses (quality 5).
 * Index represents reviewsSinceMastery (0-based), value is the interval in days.
 *
 * Note: Index 0 is not used (reviewsSinceMastery starts at 1),
 * but included for cleaner array indexing.
 */
export const MASTERY_INTERVAL_DAYS = [
  0,   // Index 0: Not used (reviewsSinceMastery starts at 1)
  3,   // Index 1 (Review 15): 3 days
  7,   // Index 2 (Review 16): 1 week
  14,  // Index 3 (Review 17): 2 weeks
  21,  // Index 4 (Review 18): 3 weeks
  30,  // Index 5 (Review 19): 1 month
  45,  // Index 6 (Review 20): 1.5 months
  60,  // Index 7 (Review 21): 2 months
  90,  // Index 8 (Review 22): 3 months
  120, // Index 9 (Review 23): 4 months
  150, // Index 10 (Review 24): 5 months
]

/**
 * Gets the interval in days for a mastered verse based on reviews since mastery.
 *
 * @param reviewsSinceMastery - Number of reviews completed since achieving mastery (quality 5)
 * @param maxInterval - Maximum allowed interval in days (default: 180)
 * @returns Interval in days until next review
 *
 * @example
 * // First review after mastery (review 15)
 * getIntervalForReviewsSinceMastery(1) // Returns 3 days
 *
 * @example
 * // Tenth review after mastery (review 24)
 * getIntervalForReviewsSinceMastery(10) // Returns 150 days
 *
 * @example
 * // Beyond defined intervals (review 25+)
 * getIntervalForReviewsSinceMastery(15) // Returns 180 days (max)
 */
export function getIntervalForReviewsSinceMastery(
  reviewsSinceMastery: number,
  maxInterval: number = 180
): number {
  // If reviewsSinceMastery exceeds our defined intervals, return max
  if (reviewsSinceMastery >= MASTERY_INTERVAL_DAYS.length) {
    return maxInterval
  }

  // Return the interval from our lookup table
  // If somehow reviewsSinceMastery is 0 or negative, this will return 0
  return MASTERY_INTERVAL_DAYS[reviewsSinceMastery] || maxInterval
}
