import 'package:flutter/material.dart';

/// Global route observer for tracking navigation events across the app.
///
/// This observer is used to detect when users navigate away from screens
/// (like the Study Guide screen) and come back, allowing us to:
/// - Continue API generation in the background
/// - Prevent unnecessary API call cancellations
/// - Check for completed background operations
/// - Reduce token waste from navigation-triggered regenerations
///
/// Usage:
/// 1. Add to GoRouter observers in app_router.dart
/// 2. Make your State class implement RouteAware
/// 3. Subscribe/unsubscribe in didChangeDependencies/dispose
/// 4. Implement didPushNext, didPopNext, didPush, didPop callbacks
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();
