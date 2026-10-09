import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/domain/entities/account_reason.dart';

/// Why a guest was stopped: the value of the `account` query parameter on
/// Home, which opens the "account needed" sheet.
class AccountReasons {
  static const String generate = 'generate';
  static const String discipler = 'discipler';
  static const String community = 'community';
  static const String memoryVerses = 'memory_verses';
  static const String otherPath = 'other_path';
  static const String secondPath = 'second_path';

  /// Query parameter on [AppRoutes.home] that carries the reason.
  static const String queryParam = 'account';

  /// The reason carried by Home's `?account=` value, or null when absent.
  static AccountReason? fromQuery(String? value) =>
      AccountReason.fromWire(value);
}

/// Routes a guest (Supabase anonymous user) may not open.
///
/// Only Home and Topics work for a guest. Everything listed here sends the
/// guest to Home with `?account=<reason>` instead.
class GuestRouteGate {
  GuestRouteGate._();

  /// The single table: route prefix → reason. A prefix matches the route
  /// itself and anything below it (`/community` matches `/community/join`),
  /// but not a sibling that merely shares characters (`/communityx`).
  static const Map<String, String> gatedPrefixes = {
    // Generate tab
    AppRoutes.generateStudy: AccountReasons.generate,
    // Credits, plans and payments (only useful for generating)
    AppRoutes.tokenManagement: AccountReasons.generate,
    AppRoutes.premiumUpgrade: AccountReasons.generate,
    AppRoutes.plusUpgrade: AccountReasons.generate,
    AppRoutes.standardUpgrade: AccountReasons.generate,
    AppRoutes.subscriptionManagement: AccountReasons.generate,
    AppRoutes.myPlan: AccountReasons.generate,
    AppRoutes.pricing: AccountReasons.generate,
    // Discipler
    AppRoutes.discipler: AccountReasons.discipler,
    AppRoutes.voiceConversation: AccountReasons.discipler,
    AppRoutes.voicePreferences: AccountReasons.discipler,
    // Community / fellowships
    AppRoutes.community: AccountReasons.community,
    '/fellowship': AccountReasons.community,
    // Memory verses
    AppRoutes.memoryVerses: AccountReasons.memoryVerses,
    AppRoutes.verseReview: AccountReasons.memoryVerses,
    // Introductions to the account-only features (a guest is only ever
    // introduced to learning paths)
    '/intro/memory': AccountReasons.memoryVerses,
    '/intro/generate': AccountReasons.generate,
    '/intro/discipler': AccountReasons.discipler,
    '/intro/fellowships': AccountReasons.community,
  };

  /// The reason [path] is closed to a guest, or null when it is open.
  static String? reasonFor(String path) {
    final clean = path.split('?').first.split('#').first;
    for (final entry in gatedPrefixes.entries) {
      final prefix = entry.key;
      if (clean == prefix || clean.startsWith('$prefix/')) return entry.value;
    }
    return null;
  }

  /// True when the signed-in user is a guest. False when guest sessions are
  /// not wired up (tests, early startup).
  static bool currentUserIsGuest() =>
      sl.isRegistered<GuestSessionService>() &&
      sl<GuestSessionService>().isGuest;

  /// Home with the account-needed [reason].
  static String homeWithReason(String reason) =>
      '${AppRoutes.home}?${AccountReasons.queryParam}=$reason';
}
