/// SECURITY FIX: Client-side rate limiting utility
///
/// Implements a sliding window rate limiter to prevent API abuse
/// and provide user-friendly feedback when rate limits are exceeded.
class RateLimiter {
  /// Maximum number of requests allowed within the time window
  final int maxRequests;

  /// Time window for rate limiting
  final Duration window;

  /// List of request timestamps within the current window
  final List<DateTime> _requests = [];

  /// Creates a rate limiter with specified constraints
  ///
  /// [maxRequests] - Maximum requests allowed in the time window
  /// [window] - Duration of the sliding time window
  RateLimiter({
    required this.maxRequests,
    required this.window,
  });

  /// Checks if a new request can be made within rate limits
  ///
  /// Returns `true` if the request is allowed, `false` if rate limited.
  /// Automatically records the request timestamp if allowed.
  bool canMakeRequest() {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Remove requests outside the current window
    _requests.removeWhere((time) => time.isBefore(windowStart));

    // Check if we've exceeded the limit
    if (_requests.length >= maxRequests) {
      return false;
    }

    // Record this request
    _requests.add(now);
    return true;
  }

  /// Gets the time until the next request is allowed
  ///
  /// Returns `Duration.zero` if requests are currently allowed.
  /// Returns the wait time if rate limited.
  Duration getRetryAfter() {
    if (_requests.isEmpty) return Duration.zero;

    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Clean up old requests first
    _requests.removeWhere((time) => time.isBefore(windowStart));

    // If under limit, no wait needed
    if (_requests.length < maxRequests) {
      return Duration.zero;
    }

    // Calculate when the oldest request will expire
    final oldestRequest = _requests.first;
    final retryTime = oldestRequest.add(window);
    final waitTime = retryTime.difference(now);

    return waitTime.isNegative ? Duration.zero : waitTime;
  }

  /// Gets remaining requests in current window
  int get remainingRequests {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Clean up old requests
    _requests.removeWhere((time) => time.isBefore(windowStart));

    return maxRequests - _requests.length;
  }

  /// Resets the rate limiter (clears all tracked requests)
  void reset() {
    _requests.clear();
  }
}
