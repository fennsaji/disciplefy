import type {
  UsageAnalyticsRequest,
  UsageAnalyticsResponse,
  SearchUsersRequest,
  SearchUsersResponse,
  SubscriptionStatsResponse,
  UpdateSubscriptionRequest,
  UpdateSubscriptionResponse,
  CreatePaymentRecordRequest,
  CreatePaymentRecordResponse,
  ListPromoCodesRequest,
  ListPromoCodesResponse,
  CreatePromoCodeRequest,
  CreatePromoCodeResponse,
  TogglePromoCodeRequest,
  TogglePromoCodeResponse,
  ListLearningPathsResponse,
  GetLearningPathResponse,
  CreateLearningPathRequest,
  CreateLearningPathResponse,
  UpdateLearningPathRequest,
  UpdateLearningPathResponse,
  DeleteLearningPathResponse,
  ReorderLearningPathRequest,
  ToggleLearningPathRequest,
  ListTopicsRequest,
  ListTopicsResponse,
  GetTopicResponse,
  CreateTopicRequest,
  CreateTopicResponse,
  UpdateTopicRequest,
  UpdateTopicResponse,
  DeleteTopicResponse,
  BulkImportRequest,
  BulkImportResult,
  AddTopicToPathRequest,
  AddTopicToPathResponse,
  RemoveTopicFromPathRequest,
  RemoveTopicFromPathResponse,
  ReorderTopicsRequest,
  ReorderTopicsResponse,
  ToggleMilestoneRequest,
  ToggleMilestoneResponse,
  LoadStudyGuideResponse,
  UpdateStudyGuideRequest,
  UpdateStudyGuideResponse,
  ListBlogPostsResponse,
  GetBlogPostResponse,
  CreateBlogPostRequest,
  UpdateBlogPostRequest,
  BlogPostResponse,
  DeleteBlogPostResponse,
  TriggerCronResponse,
  UsageLogsRequest,
  UsageLogsResponse,
  PlAnalyticsResponse
} from '@/types/admin'

// Safely parse an error response body: non-JSON (HTML/empty) error bodies fall
// back to a generic message with the HTTP status instead of throwing SyntaxError.
async function parseErrorResponse(response: Response, fallback: string): Promise<string> {
  try {
    const error = await response.json()
    return error?.error || `${fallback} (HTTP ${response.status})`
  } catch {
    return `${fallback} (HTTP ${response.status})`
  }
}

export async function fetchUsageAnalytics(
  params: UsageAnalyticsRequest
): Promise<UsageAnalyticsResponse> {
  const response = await fetch('/api/admin/usage-analytics', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to fetch usage analytics'))
  }

  return response.json()
}

export async function searchUsers(
  params: SearchUsersRequest
): Promise<SearchUsersResponse> {
  const response = await fetch('/api/admin/search-users', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to search users'))
  }

  return response.json()
}

/** Subscription counts over the whole database, independent of the current page. */
export async function getSubscriptionStats(): Promise<SubscriptionStatsResponse> {
  const response = await fetch('/api/admin/subscription-stats', {
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to load subscription stats'))
  }

  return response.json()
}

export async function updateSubscription(
  params: UpdateSubscriptionRequest
): Promise<UpdateSubscriptionResponse> {
  const response = await fetch('/api/admin/update-subscription', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include', // Include cookies for authentication
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to update subscription'))
  }

  return response.json()
}

export async function createPaymentRecord(
  params: CreatePaymentRecordRequest
): Promise<CreatePaymentRecordResponse> {
  const response = await fetch('/api/admin/create-payment-record', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include', // Include cookies for authentication
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to create payment record'))
  }

  return response.json()
}

export async function listPromoCodes(
  params: ListPromoCodesRequest
): Promise<ListPromoCodesResponse> {
  const response = await fetch('/api/admin/list-promo-codes', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to list promo codes'))
  }

  return response.json()
}

export async function createPromoCode(
  params: CreatePromoCodeRequest
): Promise<CreatePromoCodeResponse> {
  const response = await fetch('/api/admin/create-promo-code', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to create promo code'))
  }

  return response.json()
}

export async function togglePromoCode(
  params: TogglePromoCodeRequest
): Promise<TogglePromoCodeResponse> {
  const response = await fetch('/api/admin/toggle-promo-code', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to toggle promo code'))
  }

  return response.json()
}

// ============================================================================
// Learning Paths API
// ============================================================================

export async function listLearningPaths(): Promise<ListLearningPathsResponse> {
  const response = await fetch('/api/admin/learning-paths', {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to list learning paths'))
  }

  return response.json()
}

export async function getLearningPath(id: string): Promise<GetLearningPathResponse> {
  const response = await fetch(`/api/admin/learning-paths/${id}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to get learning path'))
  }

  return response.json()
}

export async function createLearningPath(
  data: CreateLearningPathRequest
): Promise<CreateLearningPathResponse> {
  const response = await fetch('/api/admin/learning-paths', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to create learning path'))
  }

  return response.json()
}

export async function updateLearningPath(
  id: string,
  data: UpdateLearningPathRequest
): Promise<UpdateLearningPathResponse> {
  const response = await fetch(`/api/admin/learning-paths/${id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to update learning path'))
  }

  return response.json()
}

export async function deleteLearningPath(id: string): Promise<DeleteLearningPathResponse> {
  const response = await fetch(`/api/admin/learning-paths/${id}`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to delete learning path'))
  }

  return response.json()
}

export async function reorderLearningPath(
  id: string,
  data: ReorderLearningPathRequest
): Promise<UpdateLearningPathResponse> {
  const response = await fetch(`/api/admin/learning-paths/${id}/reorder`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to reorder learning path'))
  }

  return response.json()
}

export async function toggleLearningPath(
  id: string,
  data: ToggleLearningPathRequest
): Promise<UpdateLearningPathResponse> {
  const response = await fetch(`/api/admin/learning-paths/${id}/toggle`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to toggle learning path'))
  }

  return response.json()
}

// ============================================================================
// Recommended Topics API
// ============================================================================

export async function listTopics(params?: ListTopicsRequest): Promise<ListTopicsResponse> {
  const queryParams = new URLSearchParams()
  if (params?.category) queryParams.append('category', params.category)
  if (params?.input_type) queryParams.append('input_type', params.input_type)
  if (params?.is_active !== undefined) queryParams.append('is_active', String(params.is_active))

  const url = `/api/admin/topics${queryParams.toString() ? `?${queryParams.toString()}` : ''}`

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to list topics'))
  }

  return response.json()
}

export async function listTopicsWithGuides(params?: ListTopicsRequest): Promise<ListTopicsResponse> {
  const queryParams = new URLSearchParams()
  if (params?.category) queryParams.append('category', params.category)
  if (params?.input_type) queryParams.append('input_type', params.input_type)
  if (params?.is_active !== undefined) queryParams.append('is_active', String(params.is_active))

  const url = `/api/admin/topics-with-guides${queryParams.toString() ? `?${queryParams.toString()}` : ''}`

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to list topics with guides'))
  }

  return response.json()
}

export async function getTopic(id: string): Promise<GetTopicResponse> {
  const response = await fetch(`/api/admin/topics/${id}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to get topic'))
  }

  return response.json()
}

export async function createTopic(data: CreateTopicRequest): Promise<CreateTopicResponse> {
  const response = await fetch('/api/admin/topics', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to create topic'))
  }

  return response.json()
}

export async function updateTopic(
  id: string,
  data: UpdateTopicRequest
): Promise<UpdateTopicResponse> {
  const response = await fetch(`/api/admin/topics/${id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to update topic'))
  }

  return response.json()
}

export async function deleteTopic(id: string): Promise<DeleteTopicResponse> {
  const response = await fetch(`/api/admin/topics/${id}`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to delete topic'))
  }

  return response.json()
}

export async function bulkImportTopics(data: BulkImportRequest): Promise<BulkImportResult> {
  const response = await fetch('/api/admin/topics/bulk-import', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to bulk import topics'))
  }

  return response.json()
}

// ============================================================================
// Learning Path Topics Association API
// ============================================================================

export async function addTopicToPath(data: AddTopicToPathRequest): Promise<AddTopicToPathResponse> {
  const response = await fetch('/api/admin/path-topics', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to add topic to path'))
  }

  return response.json()
}

export async function removeTopicFromPath(
  data: RemoveTopicFromPathRequest
): Promise<RemoveTopicFromPathResponse> {
  const response = await fetch('/api/admin/path-topics', {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to remove topic from path'))
  }

  return response.json()
}

export async function reorderPathTopics(data: ReorderTopicsRequest): Promise<ReorderTopicsResponse> {
  const response = await fetch('/api/admin/path-topics/reorder', {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to reorder topics'))
  }

  return response.json()
}

export async function toggleTopicMilestone(
  pathId: string,
  topicId: string,
  data: ToggleMilestoneRequest
): Promise<ToggleMilestoneResponse> {
  const response = await fetch(`/api/admin/path-topics/${pathId}/${topicId}/milestone`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to toggle milestone'))
  }

  return response.json()
}

// ============================================================================
// Study Guide API
// ============================================================================

export async function loadStudyGuide(id: string): Promise<LoadStudyGuideResponse> {
  const response = await fetch(`/api/admin/study-guide/${id}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to load study guide'))
  }

  return response.json()
}

export async function updateStudyGuide(
  id: string,
  data: UpdateStudyGuideRequest
): Promise<UpdateStudyGuideResponse> {
  const response = await fetch(`/api/admin/study-guide/${id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(data),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to update study guide'))
  }

  return response.json()
}

// ============================================================================
// Blog API Client Functions
// ============================================================================

export async function listBlogPosts(params?: {
  locale?: string
  status?: string
  /** Free-text search over title, excerpt, slug and tags — applied in SQL. */
  search?: string
  page?: number
  limit?: number
}): Promise<ListBlogPostsResponse> {
  const query = new URLSearchParams()
  if (params?.locale) query.set('locale', params.locale)
  if (params?.status) query.set('status', params.status)
  if (params?.search) query.set('search', params.search)
  if (params?.page) query.set('page', String(params.page))
  if (params?.limit) query.set('limit', String(params.limit))

  const response = await fetch(`/api/admin/blogs?${query}`, {
    credentials: 'include',
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to list blog posts'))
  }
  return response.json()
}

export async function getBlogPost(id: string): Promise<GetBlogPostResponse> {
  const response = await fetch(`/api/admin/blogs/${id}`, {
    credentials: 'include',
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to get blog post'))
  }
  return response.json()
}

export async function createBlogPost(data: CreateBlogPostRequest): Promise<BlogPostResponse> {
  const response = await fetch('/api/admin/blogs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(data),
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to create blog post'))
  }
  return response.json()
}

export async function updateBlogPost(id: string, data: UpdateBlogPostRequest): Promise<BlogPostResponse> {
  const response = await fetch(`/api/admin/blogs/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(data),
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to update blog post'))
  }
  return response.json()
}

export async function deleteBlogPost(id: string): Promise<DeleteBlogPostResponse> {
  const response = await fetch(`/api/admin/blogs/${id}`, {
    method: 'DELETE',
    credentials: 'include',
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to delete blog post'))
  }
  return response.json()
}

export async function publishBlogPost(id: string): Promise<BlogPostResponse> {
  const response = await fetch(`/api/admin/blogs/${id}/publish`, {
    method: 'POST',
    credentials: 'include',
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to publish blog post'))
  }
  return response.json()
}

export async function unpublishBlogPost(id: string): Promise<BlogPostResponse> {
  const response = await fetch(`/api/admin/blogs/${id}/unpublish`, {
    method: 'POST',
    credentials: 'include',
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to unpublish blog post'))
  }
  return response.json()
}

export async function triggerBlogCron(): Promise<TriggerCronResponse> {
  const response = await fetch('/api/admin/blogs/cron', {
    method: 'POST',
    credentials: 'include',
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to trigger blog generation'))
  }
  return response.json()
}

export async function fetchUsageLogs(
  params: UsageLogsRequest
): Promise<UsageLogsResponse> {
  const response = await fetch('/api/admin/usage-logs', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify(params),
  })

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to fetch usage logs'))
  }

  return response.json()
}

// ── P&L Analytics ─────────────────────────────────────────────────────────

export async function fetchPlAnalytics(params: {
  start_date: string
  end_date: string
}): Promise<PlAnalyticsResponse> {
  const response = await fetch('/api/admin/pl-analytics', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(params),
  })
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response, 'Failed to fetch P&L analytics'))
  }
  return response.json()
}
