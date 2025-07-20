/**
 * Feedback Service
 * 
 * Handles sentiment analysis and feedback processing logic.
 */

export class FeedbackService {
  /**
   * Calculates sentiment score for feedback message
   * 
   * @param message - User feedback message
   * @returns Sentiment score between 0 and 1 (0.3 = negative, 0.5 = neutral, 0.7 = positive)
   */
  async calculateSentimentScore(message: string): Promise<number> {
    // Simple sentiment analysis - count positive/negative words
    const positiveWords = [
      'good', 'great', 'helpful', 'love', 'amazing', 'excellent', 'wonderful',
      'useful', 'clear', 'easy', 'perfect', 'fantastic', 'awesome', 'brilliant'
    ]
    
    const negativeWords = [
      'bad', 'terrible', 'awful', 'hate', 'horrible', 'poor', 'useless',
      'confusing', 'difficult', 'wrong', 'broken', 'disappointing', 'frustrating'
    ]
    
    const words = message.toLowerCase().split(/\s+/)
    const positiveCount = words.filter(word => positiveWords.includes(word)).length
    const negativeCount = words.filter(word => negativeWords.includes(word)).length
    
    // Return sentiment score based on word counts
    if (positiveCount > negativeCount) {
      return 0.7 // Positive
    } else if (negativeCount > positiveCount) {
      return 0.3 // Negative
    } else {
      return 0.5 // Neutral
    }
  }

  /**
   * Validates feedback category
   * 
   * @param category - Feedback category to validate
   * @returns True if category is valid
   */
  isValidCategory(category: string): boolean {
    const allowedCategories = ['general', 'content', 'usability', 'technical', 'suggestion']
    return allowedCategories.includes(category)
  }

  /**
   * Gets default feedback category
   */
  getDefaultCategory(): string {
    return 'general'
  }

  /**
   * Gets maximum message length
   */
  getMaxMessageLength(): number {
    return 1000
  }
}