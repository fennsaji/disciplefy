/**
 * Personalization Scoring Algorithm
 *
 * Intelligent scoring system that calculates personalized learning path recommendations
 * based on 6 questionnaire responses:
 * 1. Faith stage (beginner/growing/committed)
 * 2. Spiritual goals (1-3 selections)
 * 3. Time availability (5-10min / 10-20min / 20+min)
 * 4. Learning style (practical/deep/reflection/balanced)
 * 5. Life stage focus (personal/family/community/intellectual)
 * 6. Biggest challenge (basics/consistency/doubts/sharing/stagnation)
 *
 * Each path receives a score (0-100+) based on how well it matches the user's responses.
 */

// ============================================================================
// Types & Interfaces
// ============================================================================

export interface QuestionnaireResponses {
  faith_stage: 'new_believer' | 'growing_believer' | 'committed_disciple';
  spiritual_goals: string[]; // 1-3 selections
  time_availability: '5_to_10_min' | '10_to_20_min' | '20_plus_min';
  learning_style: 'practical_application' | 'deep_understanding' | 'reflection_meditation' | 'balanced_approach';
  life_stage_focus: 'personal_foundation' | 'family_relationships' | 'community_impact' | 'intellectual_growth';
  biggest_challenge: 'starting_basics' | 'staying_consistent' | 'handling_doubts' | 'sharing_faith' | 'growing_stagnant';
}

export interface LearningPath {
  id: string;
  slug: string;
  title: string;
  disciple_level: string; // 'believer' | 'disciple' | 'leader'
  recommended_mode: string; // 'quick' | 'standard' | 'deep' | 'lectio'
  topics_count?: number; // Optional: used for tie-breaking
  is_featured: boolean;
  display_order: number;
}

export interface PathScore {
  pathId: string;
  pathSlug: string;
  pathTitle: string;
  score: number;
  matchReasons: string[];
}

interface ScoringMapping {
  path: string;
  points: number;
  reason: string;
}

// ============================================================================
// Main Scoring Function
// ============================================================================

/**
 * Calculate scores for all learning paths based on questionnaire responses
 *
 * @param responses - User's questionnaire answers
 * @param availablePaths - All active learning paths
 * @param completedPathIds - IDs of paths user has already completed
 * @returns Sorted array of path scores (highest first)
 */
export function calculatePathScores(
  responses: QuestionnaireResponses,
  availablePaths: LearningPath[],
  completedPathIds: string[]
): PathScore[] {

  // 1. Initialize scores for all paths
  const scores: Map<string, PathScore> = new Map();
  availablePaths.forEach(path => {
    scores.set(path.slug, {
      pathId: path.id,
      pathSlug: path.slug,
      pathTitle: path.title,
      score: 0,
      matchReasons: []
    });
  });

  // 2. Apply Question 1: Faith Stage Scoring (+30 points)
  applyFaithStageScoring(scores, responses.faith_stage);

  // 3. Apply Question 2: Spiritual Goals (each +20 points)
  responses.spiritual_goals.forEach(goal => {
    applySpiritualGoalScoring(scores, goal);
  });

  // 4. Apply Question 3: Time Availability (+15 bonus / -10 penalty)
  applyTimeAvailabilityScoring(scores, responses.time_availability, availablePaths);

  // 5. Apply Question 4: Learning Style (+15-20 points)
  applyLearningStyleScoring(scores, responses.learning_style, availablePaths);

  // 6. Apply Question 5: Life Stage Focus (+15-25 points)
  applyLifeStageFocusScoring(scores, responses.life_stage_focus);

  // 7. Apply Question 6: Challenge Addressing (+20-25 points)
  applyBiggestChallengeScoring(scores, responses.biggest_challenge);

  // 8. Filter out completed paths
  const filteredScores = Array.from(scores.values())
    .filter(score => !completedPathIds.includes(score.pathId));

  // 9. Sort by score (highest first) with tie-breaker logic
  const sortedScores = filteredScores.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    // Tie-breaker logic
    return applyTieBreaker(a, b, availablePaths);
  });

  return sortedScores;
}

// ============================================================================
// Question 1: Faith Stage Scoring (+30 points)
// ============================================================================

function applyFaithStageScoring(
  scores: Map<string, PathScore>,
  faithStage: string
): void {
  const mappings: Record<string, ScoringMapping[]> = {
    new_believer: [
      { path: 'new-believer-essentials', points: 30, reason: 'Perfect for new believers' },
      { path: 'faith-and-family', points: 30, reason: 'Great foundation for relationships' }
    ],
    growing_believer: [
      { path: 'growing-in-discipleship', points: 30, reason: 'Designed for growing believers' },
      { path: 'deepening-your-walk', points: 30, reason: 'Deepens spiritual disciplines' },
      { path: 'faith-and-family', points: 25, reason: 'Strengthens family faith' }
    ],
    committed_disciple: [
      { path: 'serving-and-mission', points: 30, reason: 'For committed disciples ready to serve' },
      { path: 'defending-your-faith', points: 30, reason: 'Advanced apologetics training' },
      { path: 'heart-for-the-world', points: 30, reason: 'Mission-focused discipleship' },
      { path: 'faith-and-reason', points: 30, reason: 'Deep theological exploration' }
    ]
  };

  const stageMappings = mappings[faithStage] || [];
  stageMappings.forEach(({ path, points, reason }) => {
    const score = scores.get(path);
    if (score) {
      score.score += points;
      score.matchReasons.push(reason);
    }
  });
}

// ============================================================================
// Question 2: Spiritual Goals Scoring (+20 points each)
// ============================================================================

function applySpiritualGoalScoring(
  scores: Map<string, PathScore>,
  goal: string
): void {
  const mappings: Record<string, ScoringMapping[]> = {
    foundational_faith: [
      { path: 'new-believer-essentials', points: 20, reason: 'Covers faith foundations' },
      { path: 'faith-and-family', points: 10, reason: 'Includes basic teachings' }
    ],
    spiritual_depth: [
      { path: 'deepening-your-walk', points: 20, reason: 'Focuses on spiritual depth' },
      { path: 'growing-in-discipleship', points: 15, reason: 'Deepens spiritual life' }
    ],
    relationships: [
      { path: 'faith-and-family', points: 20, reason: 'Directly addresses relationships' },
      { path: 'heart-for-the-world', points: 10, reason: 'Includes community relationships' }
    ],
    apologetics: [
      { path: 'defending-your-faith', points: 20, reason: 'Pure apologetics training' },
      { path: 'faith-and-reason', points: 15, reason: 'Addresses tough questions' }
    ],
    service: [
      { path: 'serving-and-mission', points: 20, reason: 'Centered on service' },
      { path: 'heart-for-the-world', points: 20, reason: 'Global service perspective' }
    ],
    theology: [
      { path: 'faith-and-reason', points: 20, reason: 'Deep theological study' },
      { path: 'defending-your-faith', points: 10, reason: 'Includes doctrinal defense' }
    ]
  };

  const goalMappings = mappings[goal] || [];
  goalMappings.forEach(({ path, points, reason }) => {
    const score = scores.get(path);
    if (score) {
      score.score += points;
      score.matchReasons.push(reason);
    }
  });
}

// ============================================================================
// Question 3: Time Availability Scoring (+15 bonus / -10 penalty)
// ============================================================================

function applyTimeAvailabilityScoring(
  scores: Map<string, PathScore>,
  timeAvailability: string,
  paths: LearningPath[]
): void {
  paths.forEach(path => {
    const score = scores.get(path.slug);
    if (!score) return;

    // Apply penalty for deep/lectio modes if user has limited time
    if (timeAvailability === '5_to_10_min' &&
        (path.recommended_mode === 'deep' || path.recommended_mode === 'lectio')) {
      score.score -= 10;
      score.matchReasons.push('May need more time than available');
    }

    // Apply bonus for deep mode if user has plenty of time
    if (timeAvailability === '20_plus_min' && path.recommended_mode === 'deep') {
      score.score += 15;
      score.matchReasons.push('Perfect for in-depth study time');
    }
  });
}

// ============================================================================
// Question 4: Learning Style Scoring (+15-20 points)
// ============================================================================

function applyLearningStyleScoring(
  scores: Map<string, PathScore>,
  learningStyle: string,
  paths: LearningPath[]
): void {
  const styleModeMapping: Record<string, string> = {
    practical_application: 'standard',
    deep_understanding: 'deep',
    reflection_meditation: 'lectio',
    balanced_approach: 'all' // Gives small bonus to everything
  };

  const targetMode = styleModeMapping[learningStyle];

  paths.forEach(path => {
    const score = scores.get(path.slug);
    if (!score) return;

    if (learningStyle === 'balanced_approach') {
      // Small bonus to all paths for balanced approach
      score.score += 10;
      score.matchReasons.push('Fits balanced learning style');
    } else if (path.recommended_mode === targetMode) {
      score.score += 20;
      const modeDescriptions: Record<string, string> = {
        standard: 'Practical, actionable steps',
        deep: 'Deep theological exploration',
        lectio: 'Prayerful reflection focus'
      };
      score.matchReasons.push(modeDescriptions[targetMode] || 'Matches your learning style');
    }
  });
}

// ============================================================================
// Question 5: Life Stage Focus Scoring (+15-25 points)
// ============================================================================

function applyLifeStageFocusScoring(
  scores: Map<string, PathScore>,
  lifeStageFocus: string
): void {
  const mappings: Record<string, ScoringMapping[]> = {
    personal_foundation: [
      { path: 'new-believer-essentials', points: 25, reason: 'Builds personal foundation' },
      { path: 'growing-in-discipleship', points: 20, reason: 'Strengthens relationship with God' },
      { path: 'deepening-your-walk', points: 20, reason: 'Personal spiritual growth' }
    ],
    family_relationships: [
      { path: 'faith-and-family', points: 25, reason: 'Directly addresses family relationships' },
      { path: 'new-believer-essentials', points: 10, reason: 'Foundation for family faith' }
    ],
    community_impact: [
      { path: 'serving-and-mission', points: 25, reason: 'Focused on community service' },
      { path: 'heart-for-the-world', points: 25, reason: 'Global and local impact' }
    ],
    intellectual_growth: [
      { path: 'faith-and-reason', points: 25, reason: 'Explores deep theological questions' },
      { path: 'defending-your-faith', points: 20, reason: 'Intellectual apologetics' }
    ]
  };

  const focusMappings = mappings[lifeStageFocus] || [];
  focusMappings.forEach(({ path, points, reason }) => {
    const score = scores.get(path);
    if (score) {
      score.score += points;
      score.matchReasons.push(reason);
    }
  });
}

// ============================================================================
// Question 6: Biggest Challenge Scoring (+20-25 points)
// ============================================================================

function applyBiggestChallengeScoring(
  scores: Map<string, PathScore>,
  biggestChallenge: string
): void {
  const mappings: Record<string, ScoringMapping[]> = {
    starting_basics: [
      { path: 'new-believer-essentials', points: 25, reason: 'Perfect starting point for basics' },
      { path: 'faith-and-family', points: 10, reason: 'Foundational teachings' }
    ],
    staying_consistent: [
      { path: 'deepening-your-walk', points: 25, reason: 'Builds consistent spiritual habits' },
      { path: 'growing-in-discipleship', points: 20, reason: 'Develops daily disciplines' }
    ],
    handling_doubts: [
      { path: 'defending-your-faith', points: 25, reason: 'Addresses doubts with apologetics' },
      { path: 'faith-and-reason', points: 20, reason: 'Explores difficult questions' }
    ],
    sharing_faith: [
      { path: 'serving-and-mission', points: 25, reason: 'Equips you to share the Gospel' },
      { path: 'heart-for-the-world', points: 20, reason: 'Mission and evangelism focus' }
    ],
    growing_stagnant: [
      { path: 'deepening-your-walk', points: 25, reason: 'Breaks spiritual stagnation' },
      { path: 'growing-in-discipleship', points: 20, reason: 'Reignites spiritual growth' }
    ]
  };

  const challengeMappings = mappings[biggestChallenge] || [];
  challengeMappings.forEach(({ path, points, reason }) => {
    const score = scores.get(path);
    if (score) {
      score.score += points;
      score.matchReasons.push(reason);
    }
  });
}

// ============================================================================
// Tie-Breaker Logic
// ============================================================================

/**
 * Break ties when multiple paths have the same score
 * Priority order:
 * 1. Featured paths (is_featured = true)
 * 2. Fewer topics (easier to complete)
 * 3. Display order (lower = higher priority)
 */
function applyTieBreaker(
  pathA: PathScore,
  pathB: PathScore,
  allPaths: LearningPath[]
): number {
  const pathAData = allPaths.find(p => p.slug === pathA.pathSlug);
  const pathBData = allPaths.find(p => p.slug === pathB.pathSlug);

  if (!pathAData || !pathBData) return 0;

  // 1. Prefer featured paths
  if (pathAData.is_featured && !pathBData.is_featured) return -1;
  if (!pathAData.is_featured && pathBData.is_featured) return 1;

  // 2. Prefer paths with fewer topics (easier to complete) - if available
  if (pathAData.topics_count !== undefined && pathBData.topics_count !== undefined) {
    if (pathAData.topics_count !== pathBData.topics_count) {
      return pathAData.topics_count - pathBData.topics_count;
    }
  }

  // 3. Use display order
  return pathAData.display_order - pathBData.display_order;
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Validate questionnaire responses
 * @throws Error if validation fails
 */
export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

export function validateQuestionnaireResponses(responses: Partial<QuestionnaireResponses>): ValidationResult {
  const errors: string[] = [];

  // Validate faith_stage
  const validFaithStages = ['new_believer', 'growing_believer', 'committed_disciple'];
  if (!responses.faith_stage || !validFaithStages.includes(responses.faith_stage)) {
    errors.push('Invalid faith_stage');
  }

  // Validate spiritual_goals (1-3 selections)
  const validGoals = ['foundational_faith', 'spiritual_depth', 'relationships', 'apologetics', 'service', 'theology'];
  if (!responses.spiritual_goals || !Array.isArray(responses.spiritual_goals)) {
    errors.push('spiritual_goals must be an array');
  } else if (responses.spiritual_goals.length < 1 || responses.spiritual_goals.length > 3) {
    errors.push('spiritual_goals must have 1-3 selections');
  } else if (!responses.spiritual_goals.every(goal => validGoals.includes(goal))) {
    errors.push('Invalid spiritual_goals values');
  }

  // Validate time_availability
  const validTimeOptions = ['5_to_10_min', '10_to_20_min', '20_plus_min'];
  if (!responses.time_availability || !validTimeOptions.includes(responses.time_availability)) {
    errors.push('Invalid time_availability');
  }

  // Validate learning_style
  const validStyles = ['practical_application', 'deep_understanding', 'reflection_meditation', 'balanced_approach'];
  if (!responses.learning_style || !validStyles.includes(responses.learning_style)) {
    errors.push('Invalid learning_style');
  }

  // Validate life_stage_focus
  const validFocusOptions = ['personal_foundation', 'family_relationships', 'community_impact', 'intellectual_growth'];
  if (!responses.life_stage_focus || !validFocusOptions.includes(responses.life_stage_focus)) {
    errors.push('Invalid life_stage_focus');
  }

  // Validate biggest_challenge
  const validChallenges = ['starting_basics', 'staying_consistent', 'handling_doubts', 'sharing_faith', 'growing_stagnant'];
  if (!responses.biggest_challenge || !validChallenges.includes(responses.biggest_challenge)) {
    errors.push('Invalid biggest_challenge');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Get human-readable summary of scoring results
 */
export function getScoringResultsSummary(
  topPath: PathScore,
  allScores: PathScore[]
): {
  scoredAt: string;
  algorithmVersion: string;
  topMatch: {
    pathId: string;
    pathSlug: string;
    pathTitle: string;
    score: number;
    matchReasons: string[];
  };
  allScores: Array<{ pathSlug: string; score: number }>;
} {
  return {
    scoredAt: new Date().toISOString(),
    algorithmVersion: '1.0',
    topMatch: {
      pathId: topPath.pathId,
      pathSlug: topPath.pathSlug,
      pathTitle: topPath.pathTitle,
      score: topPath.score,
      matchReasons: topPath.matchReasons
    },
    allScores: allScores.map(s => ({
      pathSlug: s.pathSlug,
      score: s.score
    }))
  };
}
