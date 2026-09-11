/**
 * Anthropic Message Batches — half price, answers within 24 hours.
 *
 * For work nobody is waiting on: the one-off catalogue pre-warm, the nightly
 * blog generator, teaser backfills. A study a user asked for in the app stays
 * on the streaming path; this is only for jobs where latency costs nothing and
 * halving the bill is the whole point.
 *
 * The API is deliberately thin: submit a list of requests, poll until the batch
 * ends, read the results. Callers own retry policy, because what to do with a
 * failed item differs per job — the pre-warm falls back to the instant path,
 * the blog generator waits for tomorrow.
 */

const BATCHES_URL = 'https://api.anthropic.com/v1/messages/batches'
const API_VERSION = '2023-06-01'

/** One request in a batch, paired with the id the caller uses to match results. */
export interface BatchRequest {
  readonly customId: string
  readonly model: string
  readonly maxTokens: number
  readonly temperature: number
  /** System blocks, including any cache_control markers, exactly as the streaming path sends them. */
  readonly system: string | Array<{ type: 'text'; text: string; cache_control?: { type: 'ephemeral' } }>
  readonly userMessage: string
}

export interface BatchStatus {
  readonly id: string
  /** Anthropic reports `in_progress` until every request has settled, then `ended`. */
  readonly processingStatus: 'in_progress' | 'canceling' | 'ended'
  readonly counts: {
    processing: number
    succeeded: number
    errored: number
    canceled: number
    expired: number
  }
}

export interface BatchResult {
  readonly customId: string
  /** Present when the request succeeded; the assistant's text, already joined. */
  readonly content?: string
  readonly inputTokens?: number
  readonly outputTokens?: number
  /** Present when it did not; the caller decides whether to retry it live. */
  readonly error?: string
}

export class AnthropicBatchClient {
  constructor(private readonly apiKey: string) {}

  private headers(): HeadersInit {
    return {
      'x-api-key': this.apiKey,
      'content-type': 'application/json',
      'anthropic-version': API_VERSION,
    }
  }

  /**
   * Submits [requests] as one batch and returns its id.
   *
   * Anthropic caps a batch at 100,000 requests or 256 MB; a caller with more
   * work than that splits it and submits several batches.
   */
  async submit(requests: readonly BatchRequest[]): Promise<string> {
    if (requests.length === 0) throw new Error('Batch submit called with no requests')

    const body = {
      requests: requests.map((r) => ({
        custom_id: r.customId,
        params: {
          model: r.model,
          max_tokens: r.maxTokens,
          temperature: r.temperature,
          top_k: 250,
          system: r.system,
          messages: [{ role: 'user', content: r.userMessage }],
        },
      })),
    }

    const res = await fetch(BATCHES_URL, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    })
    if (!res.ok) throw new Error(`Batch submit failed (${res.status}): ${await res.text()}`)

    const data = await res.json()
    console.log(`[AnthropicBatch] submitted ${requests.length} requests as ${data.id}`)
    return data.id as string
  }

  /** Current state of [batchId]. */
  async status(batchId: string): Promise<BatchStatus> {
    const res = await fetch(`${BATCHES_URL}/${batchId}`, { headers: this.headers() })
    if (!res.ok) throw new Error(`Batch status failed (${res.status}): ${await res.text()}`)

    const data = await res.json()
    return {
      id: data.id,
      processingStatus: data.processing_status,
      counts: {
        processing: data.request_counts?.processing ?? 0,
        succeeded: data.request_counts?.succeeded ?? 0,
        errored: data.request_counts?.errored ?? 0,
        canceled: data.request_counts?.canceled ?? 0,
        expired: data.request_counts?.expired ?? 0,
      },
    }
  }

  /**
   * Results for a batch that has ended, as JSON Lines streamed from Anthropic.
   *
   * Yields one entry per request, successes and failures alike, so a caller can
   * account for every id it submitted.
   */
  async *results(batchId: string): AsyncGenerator<BatchResult> {
    const res = await fetch(`${BATCHES_URL}/${batchId}/results`, { headers: this.headers() })
    if (!res.ok) throw new Error(`Batch results failed (${res.status}): ${await res.text()}`)
    if (!res.body) throw new Error('Batch results returned no body')

    const reader = res.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ''

    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      buffer += decoder.decode(value, { stream: true })

      let newline: number
      while ((newline = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, newline).trim()
        buffer = buffer.slice(newline + 1)
        if (line) yield parseResultLine(line)
      }
    }
    const tail = buffer.trim()
    if (tail) yield parseResultLine(tail)
  }
}

/** Turns one JSON Lines entry into a {@link BatchResult}. */
export function parseResultLine(line: string): BatchResult {
  const entry = JSON.parse(line)
  const customId = entry.custom_id as string
  const result = entry.result

  if (result?.type !== 'succeeded') {
    const detail = result?.error?.message ?? result?.type ?? 'unknown'
    return { customId, error: String(detail) }
  }

  const message = result.message
  const content = (message?.content ?? [])
    .map((block: { text?: string }) => block.text ?? '')
    .join('')

  return {
    customId,
    content,
    inputTokens: (message?.usage?.input_tokens ?? 0) +
      (message?.usage?.cache_read_input_tokens ?? 0) +
      (message?.usage?.cache_creation_input_tokens ?? 0),
    outputTokens: message?.usage?.output_tokens ?? 0,
  }
}
