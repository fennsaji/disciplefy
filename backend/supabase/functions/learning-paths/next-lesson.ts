export interface PathTopicRow {
  topic_id: string
  position: number
  is_milestone: boolean
  title: string
  description: string
  input_type: string
}

export interface NextLessonJson {
  topic_id: string
  title: string
  description: string
  input_type: string
  lesson_number: number
  lesson_total: number
}

const ordered = (t: PathTopicRow[]) => [...t].sort((a, b) => a.position - b.position)

/** First incomplete lesson by position (1-based number), or null when all are done. */
export function buildNextLesson(topics: PathTopicRow[], completed: Set<string>): NextLessonJson | null {
  const list = ordered(topics)
  const i = list.findIndex(t => !completed.has(t.topic_id))
  if (i < 0) return null
  const t = list[i]
  return {
    topic_id: t.topic_id,
    title: t.title,
    description: t.description,
    input_type: t.input_type,
    lesson_number: i + 1,
    lesson_total: list.length,
  }
}

/** 1-based lesson numbers (after sorting by position) of milestone lessons. */
export function milestonePositions(topics: PathTopicRow[]): number[] {
  return ordered(topics).flatMap((t, i) => (t.is_milestone ? [i + 1] : []))
}

/** Count of this path's topics present in the completed set. */
export function countCompleted(topics: PathTopicRow[], completed: Set<string>): number {
  return topics.filter(t => completed.has(t.topic_id)).length
}

export interface RecommendedExtras {
  next_lesson: NextLessonJson | null
  topics_completed: number
  milestone_positions: number[]
}

/**
 * Pure mapping from raw get_learning_path_details topics (may be null for a
 * path with no active topics) to the recommended-path fields. Guests
 * (`signedIn` false) have nothing completed. A blank topic title falls back
 * to `fallbackTitle` so next_lesson.title is never empty.
 */
export function buildRecommendedExtras(
  rawTopics: Array<Record<string, unknown>> | null | undefined,
  signedIn: boolean,
  fallbackTitle: string,
): RecommendedExtras {
  const raw = rawTopics || []
  const topics: PathTopicRow[] = raw.map(t => {
    const title = typeof t.title === 'string' ? t.title.trim() : ''
    return {
      topic_id: t.topic_id as string,
      position: t.position as number,
      is_milestone: !!t.is_milestone,
      title: title || fallbackTitle,
      description: typeof t.description === 'string' ? t.description : '',
      input_type: typeof t.input_type === 'string' ? t.input_type : '',
    }
  })
  const completed = new Set<string>(
    signedIn ? raw.filter(t => t.is_completed).map(t => t.topic_id as string) : [],
  )
  return {
    next_lesson: buildNextLesson(topics, completed),
    topics_completed: countCompleted(topics, completed),
    milestone_positions: milestonePositions(topics),
  }
}
