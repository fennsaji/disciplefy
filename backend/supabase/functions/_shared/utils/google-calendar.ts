/**
 * google-calendar.ts
 * Thin wrapper around Google Calendar API v3 using service-account JWT auth.
 * Reads credentials from GOOGLE_SERVICE_ACCOUNT_JSON and GOOGLE_CALENDAR_ID env vars.
 * All exported functions throw on failure — callers handle errors.
 */

interface ServiceAccountKey {
  client_email: string
  private_key: string
}

/** Builds a signed JWT and exchanges it for a Google OAuth2 access token. */
async function getAccessToken(): Promise<string> {
  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
  if (!raw) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON secret is not set')

  const key: ServiceAccountKey = JSON.parse(raw)

  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/calendar.events',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const encode = (obj: object) => {
    const bytes = new TextEncoder().encode(JSON.stringify(obj))
    return btoa(String.fromCharCode(...bytes))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  }

  const headerB64 = encode(header)
  const payloadB64 = encode(payload)
  const signingInput = `${headerB64}.${payloadB64}`

  // Import the RSA private key from PKCS8 PEM
  const pemBody = key.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const der = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0))
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput)
  )
  const signatureB64 = btoa(
    Array.from(new Uint8Array(signatureBuffer), b => String.fromCharCode(b)).join('')
  ).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

  const jwt = `${signingInput}.${signatureB64}`

  // Exchange JWT for access token
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  if (!resp.ok) {
    const text = await resp.text()
    throw new Error(`Google OAuth token error: ${text}`)
  }
  const data = await resp.json() as { access_token: string }
  return data.access_token
}

/**
 * Maps non-IANA timezone strings (Windows-style names, short abbreviations)
 * to their canonical IANA equivalents.
 *
 * Flutter on Windows / some web runtimes emits names like "India Standard Time"
 * or the abbreviation "IST" instead of the IANA identifier "Asia/Kolkata".
 * Google Calendar API only accepts IANA identifiers, so we normalise here.
 *
 * When the string already contains a "/" it is assumed to be a valid IANA zone
 * and returned unchanged.  Unknown values fall back to "UTC" — the ISO-8601
 * datetime string sent by the client already embeds the correct UTC offset, so
 * the absolute time is preserved even if the display timezone is wrong.
 */
function normalizeTimezone(tz: string): string {
  if (tz.includes('/')) return tz // already IANA

  const map: Record<string, string> = {
    // Windows-style names
    'Afghanistan Standard Time':          'Asia/Kabul',
    'AUS Eastern Standard Time':          'Australia/Sydney',
    'Canada Central Standard Time':       'America/Regina',
    'Cape Verde Standard Time':           'Atlantic/Cape_Verde',
    'Central America Standard Time':      'America/Guatemala',
    'Central Asia Standard Time':         'Asia/Almaty',
    'Central Standard Time':              'America/Chicago',
    'China Standard Time':                'Asia/Shanghai',
    'E. Africa Standard Time':            'Africa/Nairobi',
    'Eastern Standard Time':              'America/New_York',
    'GMT Standard Time':                  'Europe/London',
    'India Standard Time':                'Asia/Kolkata',
    'Mountain Standard Time':             'America/Denver',
    'Pacific Standard Time':              'America/Los_Angeles',
    'Romance Standard Time':              'Europe/Paris',
    'Singapore Standard Time':            'Asia/Singapore',
    'Tokyo Standard Time':                'Asia/Tokyo',
    'US Eastern Standard Time':           'America/New_York',
    'UTC':                                'UTC',
    'UTC+00':                             'UTC',
    // Short abbreviations
    'IST':  'Asia/Kolkata',
    'EST':  'America/New_York',
    'CST':  'America/Chicago',
    'MST':  'America/Denver',
    'PST':  'America/Los_Angeles',
    'GMT':  'Europe/London',
    'BST':  'Europe/London',
    'CET':  'Europe/Paris',
    'EET':  'Europe/Helsinki',
    'JST':  'Asia/Tokyo',
    'AEST': 'Australia/Sydney',
    'SGT':  'Asia/Singapore',
    'PKT':  'Asia/Karachi',
    'WIB':  'Asia/Jakarta',
    'HKT':  'Asia/Hong_Kong',
    'KST':  'Asia/Seoul',
  }

  return map[tz] ?? 'UTC'
}

/**
 * Exchanges a Google OAuth refresh token for a fresh access token.
 * Uses the same Google OAuth Client ID/Secret as the Supabase auth provider.
 */
export async function refreshGoogleAccessToken(refreshToken: string): Promise<string> {
  const clientId = Deno.env.get('GOOGLE_OAUTH_CLIENT_ID')
  const clientSecret = Deno.env.get('GOOGLE_OAUTH_CLIENT_SECRET')
  if (!clientId || !clientSecret) {
    throw new Error('GOOGLE_OAUTH_CLIENT_ID or GOOGLE_OAUTH_CLIENT_SECRET env var not set')
  }

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }).toString(),
  })

  if (!resp.ok) {
    const text = await resp.text()
    throw new Error(`Failed to refresh Google access token: ${text}`)
  }

  const data = await resp.json() as { access_token: string }
  return data.access_token
}

/**
 * Creates a calendar event using the service account (no Meet link).
 *
 * Used as a fallback when no user OAuth token is available.
 * Service accounts cannot create Meet links on personal Google accounts
 * (requires Google Workspace DWD). The event is still created so the
 * meeting is tracked; the meet_link column in the DB will be empty.
 */
async function createServiceAccountEvent(
  params: CreateEventParams,
  calendarId: string,
  ianaTimezone: string,
  rruleMap: Record<string, string>,
): Promise<CreatedEvent> {
  const saToken = await getAccessToken()

  const saBody: Record<string, unknown> = {
    summary: params.title,
    start: { dateTime: params.startsAt, timeZone: ianaTimezone },
    end:   { dateTime: params.endsAt,   timeZone: ianaTimezone },
  }
  if (params.description) saBody.description = params.description
  if (params.recurrence) saBody.recurrence = [rruleMap[params.recurrence]]

  const saUrl = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`
  const saResp = await fetch(saUrl, {
    method: 'POST',
    headers: { Authorization: `Bearer ${saToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(saBody),
  })
  if (!saResp.ok) {
    const saErrText = await saResp.text()
    throw new Error(`Google Calendar createEvent (SA) failed (${saResp.status}): ${saErrText}`)
  }
  const saEvent = await saResp.json() as { id: string }
  return { eventId: saEvent.id, meetLink: '', calendarType: 'service_account' }
}

export interface CreateEventParams {
  title: string
  description?: string | null
  startsAt: string       // ISO-8601 with timezone offset
  endsAt: string         // ISO-8601 with timezone offset
  timeZone: string       // IANA timezone e.g. 'Asia/Kolkata'
  recurrence?: 'daily' | 'weekly' | 'monthly' | null
  attendeeEmails?: string[]
  /** When provided, the user's own Google OAuth token is used instead of the
   *  service account — this enables hangoutsMeet conference creation and
   *  proper Calendar invite emails on personal Google accounts. */
  userAccessToken?: string
  /** Google OAuth refresh token (offline access). When the access token is
   *  expired (401), the backend exchanges this for a fresh access token and
   *  retries, ensuring Meet links always work even for long-running sessions. */
  userRefreshToken?: string
}

export interface CreatedEvent {
  eventId: string
  meetLink: string
  /** Which Google Calendar holds this event. Needed by the cancel function
   *  to target the correct calendar for deletion. */
  calendarType: 'service_account' | 'user_primary'
}


/**
 * Creates a Google Calendar event with a Google Meet link.
 *
 * Primary path (no user token): uses the service account + Google Meet REST
 * API v2 to generate a real Meet space URI, then creates the calendar event
 * with the link embedded in the description. No user OAuth needed.
 *
 * Legacy path (user token present): uses the user's own token to create a
 * Calendar event with hangoutsMeet conference data. Falls back to the SA path
 * on 401/403.
 */
export async function createCalendarEvent(params: CreateEventParams): Promise<CreatedEvent> {
  const calendarId = Deno.env.get('GOOGLE_CALENDAR_ID')
  if (!calendarId) throw new Error('GOOGLE_CALENDAR_ID secret is not set')

  const ianaTimezone = normalizeTimezone(params.timeZone)

  const rruleMap: Record<string, string> = {
    daily: 'RRULE:FREQ=DAILY',
    weekly: 'RRULE:FREQ=WEEKLY',
    monthly: 'RRULE:FREQ=MONTHLY',
  }

  // Without a user token, use the service account + Meet API path directly.
  // createServiceAccountEvent creates a real Meet space via the Meet REST API.
  if (!params.userAccessToken) {
    return createServiceAccountEvent(params, calendarId, ianaTimezone, rruleMap)
  }

  // User's own Google token path (opportunistic — only reached when the caller
  // has calendar.events scope on the session, e.g. legacy sign-ins).
  const accessToken = params.userAccessToken

  const body: Record<string, unknown> = {
    summary: params.title,
    start: { dateTime: params.startsAt, timeZone: ianaTimezone },
    end:   { dateTime: params.endsAt,   timeZone: ianaTimezone },
  }

  if (params.recurrence) {
    body.recurrence = [rruleMap[params.recurrence]]
  }

  body.conferenceData = {
    createRequest: {
      requestId: crypto.randomUUID(),
      conferenceSolutionKey: { type: 'hangoutsMeet' },
    },
  }

  // Fixed reminders: popup + email 1 hour before, popup 1 minute before.
  // These appear in every attendee's Google Calendar automatically.
  body.reminders = {
    useDefault: false,
    overrides: [
      { method: 'email', minutes: 60 },
      { method: 'popup', minutes: 60 },
      { method: 'popup', minutes: 1 },
    ],
  }

  if (params.attendeeEmails && params.attendeeEmails.length > 0) {
    body.attendees = params.attendeeEmails.map(email => ({ email }))
    body.guestsCanSeeOtherGuests = true
  }

  const url =
    `https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1&sendUpdates=all`

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })

  if (!resp.ok) {
    const errText = await resp.text()

    // When the user token is expired (401) or rejected (403):
    // 1. If a refresh token is available, get a fresh access token and retry.
    // 2. Otherwise, fall back to the service-account path (no Meet link).
    if (resp.status === 401 || resp.status === 403) {

      // ── Step 1: Try refreshing the access token ──────────────────────────
      if (params.userRefreshToken) {
        try {
          console.log('[google-calendar] Access token expired, refreshing via refresh token...')
          const freshToken = await refreshGoogleAccessToken(params.userRefreshToken)

          // Retry the exact same Calendar API call with the fresh token
          const retryResp = await fetch(url, {
            method: 'POST',
            headers: { Authorization: `Bearer ${freshToken}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
          })

          if (retryResp.ok) {
            const retryEvent = await retryResp.json() as {
              id: string
              conferenceData?: { entryPoints?: Array<{ entryPointType: string; uri: string }> }
              hangoutLink?: string
            }
            const retryMeetLink =
              retryEvent.hangoutLink ??
              retryEvent.conferenceData?.entryPoints?.find(e => e.entryPointType === 'video')?.uri ??
              ''
            console.log('[google-calendar] Token refresh succeeded — Meet link:', retryMeetLink || '(none)')
            return { eventId: retryEvent.id, meetLink: retryMeetLink, calendarType: 'user_primary' }
          }

          const retryErrText = await retryResp.text()
          console.warn(`[google-calendar] Retry with refreshed token failed (${retryResp.status}): ${retryErrText}`)
        } catch (refreshErr) {
          console.warn('[google-calendar] Token refresh error:', refreshErr)
        }
      } else {
        console.warn(`[google-calendar] User token rejected (${resp.status}) and no refresh token available: ${errText}`)
      }

      // ── Step 2: Fall back to service account + Meet API for Meet link ───
      console.log('[google-calendar] Falling back to service-account Calendar event + Jitsi link')
      return await createServiceAccountEvent(params, calendarId, ianaTimezone, rruleMap)
    }

    throw new Error(`Google Calendar createEvent failed (${resp.status}): ${errText}`)
  }

  const event = await resp.json() as {
    id: string
    conferenceData?: { entryPoints?: Array<{ entryPointType: string; uri: string }> }
    hangoutLink?: string
  }

  // Extract Meet link from the Calendar API response (user-token path).
  // For service-account path we have no Meet link — the caller handles this.
  const meetLink =
    event.hangoutLink ??
    event.conferenceData?.entryPoints?.find(e => e.entryPointType === 'video')?.uri ??
    ''

  return { eventId: event.id, meetLink, calendarType: 'user_primary' }
}

/**
 * Cancels (deletes) a Google Calendar event and sends cancellation emails.
 * A 404 response is treated as success (event already deleted).
 *
 * @param eventId      The Google Calendar event ID to delete.
 * @param calendarType Determines which calendar to target:
 *   - 'service_account' (default): uses the SA calendar (GOOGLE_CALENDAR_ID env var).
 *   - 'user_primary': the event was created on the mentor's personal calendar via their
 *     OAuth token; the service account has no access to it, so cancellation is skipped
 *     and a warning is logged instead.
 */
export async function cancelCalendarEvent(
  eventId: string,
  calendarType: 'service_account' | 'user_primary' = 'service_account',
  userAccessToken?: string,
): Promise<void> {
  if (calendarType === 'user_primary') {
    if (!userAccessToken) {
      console.warn('[google-calendar] cancelCalendarEvent: skipping user_primary event — no access token provided:', eventId)
      return
    }
    // Use the mentor's own access token to delete from their personal calendar.
    const url = `https://www.googleapis.com/calendar/v3/calendars/primary/events/${encodeURIComponent(eventId)}?sendUpdates=all`
    const resp = await fetch(url, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${userAccessToken}` },
    })
    // 204 = deleted, 404 = already gone — both acceptable
    if (!resp.ok && resp.status !== 404) {
      const text = await resp.text()
      throw new Error(`Google Calendar deleteEvent (user_primary) failed (${resp.status}): ${text}`)
    }
    return
  }

  const calendarId = Deno.env.get('GOOGLE_CALENDAR_ID')
  if (!calendarId) throw new Error('GOOGLE_CALENDAR_ID secret is not set')

  const accessToken = await getAccessToken()

  const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(eventId)}?sendUpdates=all`
  const resp = await fetch(url, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  // 204 = deleted, 404 = already gone — both acceptable
  if (!resp.ok && resp.status !== 404) {
    const text = await resp.text()
    throw new Error(`Google Calendar deleteEvent failed (${resp.status}): ${text}`)
  }
}
