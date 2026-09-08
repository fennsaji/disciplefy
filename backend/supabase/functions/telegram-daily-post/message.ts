// backend/supabase/functions/telegram-daily-post/message.ts
/**
 * Composes the channel message. Kept separate from the job so the wording can
 * be tested without a Telegram token or a database.
 */

export interface TelegramLesson {
  topicTitle: string
  hook: string
  body: string
  blogSlug: string
}

/** Where the reader lands. The blog, not the app: the channel is public. */
export const BLOG_BASE_URL = 'https://www.disciplefy.in/blog'

/**
 * Builds the post.
 *
 * The body is sent whole — a reader on Telegram gets the same thought a member
 * gets in the app, and the link is for the full study, not for the rest of a
 * sentence. Telegram's own limit is 4096 characters and hook + body are capped
 * at 90 + 220 by the prompt, so nothing here needs trimming.
 */
export function buildTelegramMessage(lesson: TelegramLesson): string {
  return [
    `📖 ${lesson.topicTitle}`,
    '',
    `✨ ${lesson.hook}`,
    '',
    lesson.body,
    '',
    `${BLOG_BASE_URL}/${lesson.blogSlug}`,
  ].join('\n')
}
