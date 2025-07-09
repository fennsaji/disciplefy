/**
 * Repository for managing Recommended Guide Bible study topics.
 * 
 * Provides access to curated topics following structured 4-step methodology:
 * - Context: Historical and cultural background
 * - Scholar's Guide: Original meaning and interpretation
 * - Group Discussion: Contemporary application questions
 * - Application: Personal life transformation steps
 */

/**
 * Represents a Recommended Guide methodology topic for Bible study.
 */
interface RecommendedGuideTopic {
  readonly id: string
  readonly title: string
  readonly description: string
  readonly difficulty_level: 'beginner' | 'intermediate' | 'advanced'
  readonly estimated_duration: string
  readonly key_verses: readonly string[]
  readonly category: string
  readonly tags: readonly string[]
}

/**
 * Repository for accessing Recommended Guide Bible study topics.
 * 
 * This repository provides a clean abstraction over the topics data,
 * following the Repository pattern for data access.
 */
export class TopicsRepository {
  
  /**
   * Retrieves all topics for a specific language.
   * 
   * @param language - Language code (currently only 'en' is supported)
   * @returns Promise resolving to array of topics
   */
  async getTopicsByLanguage(language: string): Promise<readonly RecommendedGuideTopic[]> {
    // For now, we only support English topics
    // In future iterations, this could be expanded to include translations
    if (language !== 'en') {
      return []
    }

    return this.getEnglishTopics()
  }

  /**
   * Retrieves a specific topic by its ID.
   * 
   * @param id - Unique topic identifier
   * @param language - Language code
   * @returns Promise resolving to topic or undefined if not found
   */
  async getTopicById(id: string, language = 'en'): Promise<RecommendedGuideTopic | undefined> {
    const topics = await this.getTopicsByLanguage(language)
    return topics.find(topic => topic.id === id)
  }

  /**
   * Retrieves topics filtered by category.
   * 
   * @param category - Topic category
   * @param language - Language code
   * @returns Promise resolving to filtered topics array
   */
  async getTopicsByCategory(category: string, language = 'en'): Promise<readonly RecommendedGuideTopic[]> {
    const topics = await this.getTopicsByLanguage(language)
    const normalizedCategory = category.toLowerCase()
    
    return topics.filter(topic => 
      topic.category.toLowerCase() === normalizedCategory
    )
  }

  /**
   * Retrieves topics filtered by difficulty level.
   * 
   * @param difficulty - Difficulty level
   * @param language - Language code
   * @returns Promise resolving to filtered topics array
   */
  async getTopicsByDifficulty(
    difficulty: 'beginner' | 'intermediate' | 'advanced', 
    language = 'en'
  ): Promise<readonly RecommendedGuideTopic[]> {
    const topics = await this.getTopicsByLanguage(language)
    return topics.filter(topic => topic.difficulty_level === difficulty)
  }

  /**
   * Retrieves all unique categories from available topics.
   * 
   * @param language - Language code
   * @returns Promise resolving to array of category names
   */
  async getCategories(language = 'en'): Promise<readonly string[]> {
    const topics = await this.getTopicsByLanguage(language)
    return [...new Set(topics.map(topic => topic.category))]
  }

  /**
   * Searches topics by title and description.
   * 
   * @param query - Search query string
   * @param language - Language code
   * @returns Promise resolving to matching topics
   */
  async searchTopics(query: string, language = 'en'): Promise<readonly RecommendedGuideTopic[]> {
    const topics = await this.getTopicsByLanguage(language)
    const normalizedQuery = query.toLowerCase()

    return topics.filter(topic =>
      topic.title.toLowerCase().includes(normalizedQuery) ||
      topic.description.toLowerCase().includes(normalizedQuery) ||
      topic.tags.some(tag => tag.toLowerCase().includes(normalizedQuery))
    )
  }

  /**
   * Gets the complete set of English Recommended Guide topics.
   * 
   * @returns Array of Recommended Guide methodology topics
   */
  private getEnglishTopics(): readonly RecommendedGuideTopic[] {
    return [
      {
        id: 'rg-001',
        title: 'Understanding Biblical Context',
        description: 'Learn to read Scripture within its historical and cultural setting',
        difficulty_level: 'beginner',
        estimated_duration: '45 minutes',
        key_verses: ['2 Timothy 3:16-17', 'Nehemiah 8:1-8', 'Acts 17:11'],
        category: 'Bible Study Methods',
        tags: ['context', 'interpretation', 'hermeneutics']
      },
      {
        id: 'rg-002',
        title: 'The Scholar\'s Approach to Scripture',
        description: 'Discovering what the text meant to its original audience',
        difficulty_level: 'intermediate',
        estimated_duration: '60 minutes',
        key_verses: ['1 Corinthians 2:14', 'Luke 24:13-35', 'Acts 8:30-31'],
        category: 'Bible Study Methods',
        tags: ['scholarship', 'original meaning', 'exegesis']
      },
      {
        id: 'rg-003',
        title: 'Group Discussion Dynamics',
        description: 'Facilitating meaningful biblical conversations',
        difficulty_level: 'intermediate',
        estimated_duration: '50 minutes',
        key_verses: ['Proverbs 27:17', 'Ecclesiastes 4:12', 'Hebrews 10:24-25'],
        category: 'Group Leadership',
        tags: ['discussion', 'community', 'facilitation']
      },
      {
        id: 'rg-004',
        title: 'Personal Application of Scripture',
        description: 'Moving from understanding to life transformation',
        difficulty_level: 'beginner',
        estimated_duration: '40 minutes',
        key_verses: ['James 1:22-25', 'Luke 6:46-49', 'John 14:15'],
        category: 'Spiritual Growth',
        tags: ['application', 'transformation', 'obedience']
      },
      {
        id: 'rg-005',
        title: 'The Gospel in the Old Testament',
        description: 'Seeing Christ throughout the Hebrew Scriptures',
        difficulty_level: 'advanced',
        estimated_duration: '75 minutes',
        key_verses: ['Luke 24:27', 'John 5:39', 'Isaiah 53:1-12'],
        category: 'Biblical Theology',
        tags: ['gospel', 'christology', 'old testament']
      },
      {
        id: 'rg-006',
        title: 'Prayer and Scripture Study',
        description: 'Integrating prayer into Bible study for spiritual insight',
        difficulty_level: 'beginner',
        estimated_duration: '35 minutes',
        key_verses: ['Psalm 119:18', '1 Corinthians 2:10-14', 'John 16:13'],
        category: 'Spiritual Disciplines',
        tags: ['prayer', 'illumination', 'holy spirit']
      },
      {
        id: 'rg-007',
        title: 'Character Studies in Scripture',
        description: 'Learning from biblical characters and their journeys',
        difficulty_level: 'intermediate',
        estimated_duration: '55 minutes',
        key_verses: ['1 Corinthians 10:11', 'Romans 15:4', 'Hebrews 11:1-40'],
        category: 'Biblical Characters',
        tags: ['biography', 'character', 'examples']
      },
      {
        id: 'rg-008',
        title: 'Understanding Biblical Covenants',
        description: 'Exploring God\'s covenant relationship with humanity',
        difficulty_level: 'advanced',
        estimated_duration: '70 minutes',
        key_verses: ['Genesis 12:1-3', 'Jeremiah 31:31-34', 'Hebrews 8:6-13'],
        category: 'Biblical Theology',
        tags: ['covenant', 'relationship', 'promise']
      },
      {
        id: 'rg-009',
        title: 'The Parables of Jesus',
        description: 'Understanding the teaching method of Christ',
        difficulty_level: 'intermediate',
        estimated_duration: '50 minutes',
        key_verses: ['Matthew 13:3-23', 'Mark 4:33-34', 'Luke 8:4-15'],
        category: 'New Testament Studies',
        tags: ['parables', 'teaching', 'kingdom']
      },
      {
        id: 'rg-010',
        title: 'Spiritual Warfare and Victory',
        description: 'Biblical understanding of our battle and Christ\'s victory',
        difficulty_level: 'intermediate',
        estimated_duration: '60 minutes',
        key_verses: ['Ephesians 6:10-18', '2 Corinthians 10:3-5', '1 John 4:4'],
        category: 'Spiritual Growth',
        tags: ['warfare', 'victory', 'armor']
      },
      {
        id: 'rg-011',
        title: 'Love and Relationships',
        description: 'Biblical foundations for healthy relationships',
        difficulty_level: 'beginner',
        estimated_duration: '45 minutes',
        key_verses: ['1 Corinthians 13:1-13', 'John 13:34-35', 'Ephesians 5:21-33'],
        category: 'Christian Living',
        tags: ['love', 'relationships', 'community']
      },
      {
        id: 'rg-012',
        title: 'Forgiveness and Grace',
        description: 'Understanding God\'s forgiveness and extending it to others',
        difficulty_level: 'beginner',
        estimated_duration: '50 minutes',
        key_verses: ['Ephesians 4:32', 'Matthew 6:14-15', 'Colossians 3:13'],
        category: 'Christian Living',
        tags: ['forgiveness', 'grace', 'reconciliation']
      },
      {
        id: 'rg-013',
        title: 'Faith and Doubt',
        description: 'Navigating seasons of doubt and growing in faith',
        difficulty_level: 'intermediate',
        estimated_duration: '55 minutes',
        key_verses: ['Mark 9:24', 'James 1:6-8', 'Hebrews 11:1'],
        category: 'Spiritual Growth',
        tags: ['faith', 'doubt', 'trust']
      },
      {
        id: 'rg-014',
        title: 'Worship and Praise',
        description: 'Biblical foundations for authentic worship',
        difficulty_level: 'beginner',
        estimated_duration: '40 minutes',
        key_verses: ['John 4:23-24', 'Psalm 150:1-6', 'Romans 12:1'],
        category: 'Spiritual Disciplines',
        tags: ['worship', 'praise', 'heart']
      },
      {
        id: 'rg-015',
        title: 'Suffering and Hope',
        description: 'Finding hope and purpose in times of suffering',
        difficulty_level: 'advanced',
        estimated_duration: '65 minutes',
        key_verses: ['Romans 8:28', '2 Corinthians 1:3-4', '1 Peter 4:12-19'],
        category: 'Life Challenges',
        tags: ['suffering', 'hope', 'perseverance']
      }
    ]
  }
}