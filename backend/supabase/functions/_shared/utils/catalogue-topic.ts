/**
 * The catalogue's own facts about a lesson topic, and the prompt context a
 * study request is allowed to use.
 *
 * A request's `topic_id`, title, description and path fields all come from the
 * client. A lesson is cached under its topic for every reader, so nothing the
 * client says about it is trusted: titles, description, input type and path
 * context come from the database, and a request that does not verify as a
 * lesson carries no catalogue context at all.
 */

import { AppError } from './error-handler.ts'

export type StudyInputType = 'scripture' | 'topic' | 'question'

/** The path holding a topic, localized to the study language. */
export interface CataloguePath {
  readonly title: string
  readonly description: string
  readonly discipleLevel: string | null
  readonly recommendedMode: string | null
}

/** What the catalogue holds for a topic. */
export interface CatalogueTopic {
  /** Every title of the topic: base, each translation, each path's override. */
  readonly titles: string[]
  /** The topic's description in the study language, falling back to the base one. */
  readonly description: string
  /** The study input type the topic is generated as. */
  readonly inputType: StudyInputType
  /** The path holding the topic, if any. */
  readonly path: CataloguePath | null
}

/**
 * The result of a catalogue lookup. `error` means the database could not be
 * read, which must not quietly turn a real lesson into a paid study.
 */
export type CatalogueLookup =
  | { readonly status: 'found'; readonly topic: CatalogueTopic }
  | { readonly status: 'not_found' }
  | { readonly status: 'error' }

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Whether [value] is shaped like a UUID, so it can be a topic id at all. */
export function isUuid(value: string): boolean {
  return UUID.test(value)
}

/**
 * The study input type for a catalogue topic's `input_type`. A verse topic is
 * a scripture study; a missing value is a topic, as `get_learning_path_details`
 * treats it.
 */
export function studyInputTypeFor(catalogueType: string | null | undefined): StudyInputType {
  if (catalogueType === 'verse') return 'scripture'
  if (catalogueType === 'question') return 'question'
  return 'topic'
}

/** One `learning_path_topics` row with its path embedded. */
export interface PathRow {
  readonly learning_path_id: string
  readonly learning_paths: {
    readonly title: string
    readonly description: string
    readonly disciple_level: string | null
    readonly recommended_mode: string | null
    readonly display_order: number | null
  } | null
}

/**
 * The path a topic's lesson context comes from when it sits in several:
 * lowest `display_order` first (missing last), then lowest path id, so the
 * choice is the same on every request.
 */
export function pickPath(rows: readonly PathRow[]): PathRow | null {
  const withPath = rows.filter((r) => r.learning_paths !== null)
  if (withPath.length === 0) return null
  return [...withPath].sort((a, b) => {
    const ao = a.learning_paths!.display_order ?? Number.POSITIVE_INFINITY
    const bo = b.learning_paths!.display_order ?? Number.POSITIVE_INFINITY
    if (ao !== bo) return ao - bo
    return a.learning_path_id < b.learning_path_id ? -1 : a.learning_path_id > b.learning_path_id ? 1 : 0
  })[0]
}

/** The minimum of a Supabase client this module needs. */
// deno-lint-ignore no-explicit-any -- the query builder is untyped across this codebase
export type QueryClient = { from(table: string): any }

/**
 * Loads [topicId] from the catalogue in [language].
 *
 * A non-UUID id or a topic that does not exist is `not_found`: the request is
 * simply not a lesson. A failed query is `error`, for the caller to report as
 * a retryable outage rather than charge for a lesson.
 */
export async function loadCatalogueTopic(
  db: QueryClient,
  topicId: string,
  language: string,
): Promise<CatalogueLookup> {
  if (!isUuid(topicId)) return { status: 'not_found' }

  const [topicRes, translationsRes, overridesRes, pathRes] = await Promise.all([
    db.from('recommended_topics').select('title, description, input_type').eq('id', topicId).maybeSingle(),
    db.from('recommended_topics_translations').select('language_code, title, description').eq('topic_id', topicId),
    db.from('learning_path_topic_titles').select('title').eq('topic_id', topicId),
    db
      .from('learning_path_topics')
      .select('learning_path_id, learning_paths!inner(title, description, disciple_level, recommended_mode, display_order)')
      .eq('topic_id', topicId),
  ])
  if (topicRes.error || translationsRes.error || overridesRes.error || pathRes.error) {
    return { status: 'error' }
  }
  if (!topicRes.data) return { status: 'not_found' }

  const translations = (translationsRes.data ?? []) as Array<{ language_code: string; title: string; description: string }>
  const overrides = (overridesRes.data ?? []) as Array<{ title: string }>
  const localized = translations.find((t) => t.language_code === language)

  const pathRow = pickPath((pathRes.data ?? []) as PathRow[])
  let path: CataloguePath | null = null
  if (pathRow?.learning_paths) {
    const lp = pathRow.learning_paths
    const lptRes = await db
      .from('learning_path_translations')
      .select('title, description')
      .eq('learning_path_id', pathRow.learning_path_id)
      .eq('lang_code', language)
      .maybeSingle()
    if (lptRes.error) return { status: 'error' }
    path = {
      title: lptRes.data?.title || lp.title,
      description: lptRes.data?.description || lp.description,
      discipleLevel: lp.disciple_level ?? null,
      recommendedMode: lp.recommended_mode ?? null,
    }
  }

  return {
    status: 'found',
    topic: {
      titles: [topicRes.data.title, ...translations.map((t) => t.title), ...overrides.map((o) => o.title)],
      description: localized?.description || topicRes.data.description,
      inputType: studyInputTypeFor(topicRes.data.input_type),
      path,
    },
  }
}

/** The request fields that shape the prompt and the cache key. */
export interface LessonContext {
  readonly inputType: StudyInputType
  readonly topicDescription?: string
  readonly pathTitle?: string
  readonly pathDescription?: string
  readonly discipleLevel?: string
}

/**
 * The prompt context a request may use.
 *
 * A verified lesson ([topic] given) takes everything from the catalogue. Any
 * other request keeps its own input type and loses the catalogue fields: only
 * lesson launches send them, always with a topic id that verifies, so on an
 * unverified request they can only be injected text bound for a shared cache.
 */
export function lessonContext(client: LessonContext, topic: CatalogueTopic | null): LessonContext {
  if (!topic) return { inputType: client.inputType }
  return {
    inputType: topic.inputType,
    topicDescription: topic.description || undefined,
    pathTitle: topic.path?.title,
    pathDescription: topic.path?.description,
    discipleLevel: topic.path?.discipleLevel ?? undefined,
  }
}

/**
 * The topic of a lookup, or null when the request is not a lesson. Throws a
 * retryable 503 when the catalogue could not be read: charging for a real
 * lesson because the database blinked would be worse than asking to retry.
 */
export function catalogueTopicOrThrow(lookup: CatalogueLookup | null): CatalogueTopic | null {
  if (lookup === null || lookup.status === 'not_found') return null
  if (lookup.status === 'error') {
    throw new AppError('SERVICE_UNAVAILABLE', 'The lesson could not be loaded. Please try again.', 503)
  }
  return lookup.topic
}
