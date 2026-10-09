// ============================================================================
// Notification Enable Prompt Widget
// ============================================================================
// A reusable bottom sheet prompt that asks users to enable specific
// notification types contextually when they interact with relevant features.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/popup.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';
import '../utils/notification_prompt_policy.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';

/// Types of notification prompts that can be shown
enum NotificationPromptType {
  dailyVerse,
  recommendedTopic,
  streakReminder,
  streakMilestone,
  streakLost,
  memoryVerseReminder,
  memoryVerseOverdue,
}

/// Configuration for each notification prompt type
class NotificationPromptConfig {
  final String title;
  final String description;
  final IconData icon;

  const NotificationPromptConfig({
    required this.title,
    required this.description,
    required this.icon,
  });

  static NotificationPromptConfig getConfig(
      NotificationPromptType type, String languageCode) {
    switch (type) {
      case NotificationPromptType.dailyVerse:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.menu_book_rounded,
        );
      case NotificationPromptType.recommendedTopic:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.lightbulb_outline_rounded,
        );
      case NotificationPromptType.streakReminder:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.local_fire_department_rounded,
        );
      case NotificationPromptType.streakMilestone:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.emoji_events_rounded,
        );
      case NotificationPromptType.streakLost:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.favorite_border_rounded,
        );
      case NotificationPromptType.memoryVerseOverdue:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.warning_amber_rounded,
        );
      case NotificationPromptType.memoryVerseReminder:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.psychology_rounded,
        );
    }
  }

  static String _getLocalizedTitle(
      NotificationPromptType type, String languageCode) {
    final titles = {
      NotificationPromptType.dailyVerse: {
        'en': 'Daily Verse Notifications',
        'hi': 'दैनिक वचन सूचनाएं',
        'ml': 'ദൈനംദിന വാക്യ അറിയിപ്പുകൾ',
      },
      NotificationPromptType.recommendedTopic: {
        'en': 'Study Topic Notifications',
        'hi': 'अध्ययन विषय सूचनाएं',
        'ml': 'പഠന വിഷയ അറിയിപ്പുകൾ',
      },
      NotificationPromptType.streakReminder: {
        'en': 'Streak Reminder',
        'hi': 'स्ट्रीक रिमाइंडर',
        'ml': 'സ്റ്റ്രീക്ക് ഓർമ്മപ്പെടുത്തൽ',
      },
      NotificationPromptType.streakMilestone: {
        'en': 'Milestone Celebrations',
        'hi': 'उपलब्धि सूचनाएं',
        'ml': 'നാഴികക്കല്ല് ആഘോഷങ്ങൾ',
      },
      NotificationPromptType.streakLost: {
        'en': 'Streak Reset Motivation',
        'hi': 'स्ट्रीक रीसेट प्रेरणा',
        'ml': 'സ്റ്റ്രീക്ക് റീസെറ്റ് പ്രചോദനം',
      },
      NotificationPromptType.memoryVerseReminder: {
        'en': 'Memory Verse Reminders',
        'hi': 'वचन याद रिमाइंडर',
        'ml': 'വാക്യ ഓർമ്മ റിമൈൻഡർ',
      },
      NotificationPromptType.memoryVerseOverdue: {
        'en': 'Overdue Verses Alert',
        'hi': 'अतिदेय वचन अलर्ट',
        'ml': 'കാലഹരണപ്പെട്ട വചന അറിയിപ്പ്',
      },
    };
    return titles[type]?[languageCode] ?? titles[type]?['en'] ?? '';
  }

  static String _getLocalizedDescription(
      NotificationPromptType type, String languageCode) {
    final descriptions = {
      NotificationPromptType.dailyVerse: {
        'en':
            'Get a daily Bible verse delivered to you every morning to start your day with God\'s Word.',
        'hi':
            'हर सुबह परमेश्वर के वचन के साथ अपना दिन शुरू करने के लिए दैनिक बाइबल वचन प्राप्त करें।',
        'ml':
            'ദൈവവചനത്തോടെ നിങ്ങളുടെ ദിവസം ആരംഭിക്കാൻ എല്ലാ ദിവസവും രാവിലെ ഒരു ബൈബിൾ വാക്യം ലഭിക്കുക.',
      },
      NotificationPromptType.recommendedTopic: {
        'en':
            'Receive personalized Bible study topic suggestions based on your interests.',
        'hi':
            'अपनी रुचियों के आधार पर व्यक्तिगत बाइबल अध्ययन विषय सुझाव प्राप्त करें।',
        'ml':
            'നിങ്ങളുടെ താൽപ്പര്യങ്ങളെ അടിസ്ഥാനമാക്കി വ്യക്തിഗത ബൈബിൾ പഠന വിഷയ നിർദ്ദേശങ്ങൾ സ്വീകരിക്കുക.',
      },
      NotificationPromptType.streakReminder: {
        'en':
            'Get a gentle reminder in the evening if you haven\'t read your daily verse yet.',
        'hi':
            'यदि आपने अभी तक अपना दैनिक वचन नहीं पढ़ा है तो शाम को एक कोमल रिमाइंडर प्राप्त करें।',
        'ml':
            'നിങ്ങൾ ഇന്നത്തെ വാക്യം വായിച്ചിട്ടില്ലെങ്കിൽ വൈകുന്നേരം ഒരു സൗമ്യമായ ഓർമ്മപ്പെടുത്തൽ ലഭിക്കുക.',
      },
      NotificationPromptType.streakMilestone: {
        'en':
            'Celebrate your consistency! Get notified when you reach streak milestones.',
        'hi':
            'अपनी निरंतरता का जश्न मनाएं! जब आप स्ट्रीक माइलस्टोन तक पहुंचें तो सूचना प्राप्त करें।',
        'ml':
            'നിങ്ങളുടെ സ്ഥിരത ആഘോഷിക്കൂ! സ്റ്റ്രീക്ക് നാഴികക്കല്ലുകളിൽ എത്തുമ്പോൾ അറിയിപ്പ് ലഭിക്കുക.',
      },
      NotificationPromptType.streakLost: {
        'en':
            'Receive a gentle nudge of encouragement when your streak resets — every new day is a fresh start.',
        'hi':
            'जब आपकी स्ट्रीक रीसेट हो तो प्रोत्साहन का एक कोमल संदेश प्राप्त करें — हर नया दिन एक नई शुरुआत है।',
        'ml':
            'നിങ്ങളുടെ സ്റ്റ്രീക്ക് റീസെറ്റ് ആകുമ്പോൾ ഒരു സൗമ്യമായ പ്രോത്സാഹന സന്ദേശം ലഭിക്കുക — ഓരോ പുതിയ ദിവസവും ഒരു പുതിയ തുടക്കമാണ്.',
      },
      NotificationPromptType.memoryVerseReminder: {
        'en':
            'Get daily reminders when your memory verses are ready for review.',
        'hi':
            'जब आपके वचन समीक्षा के लिए तैयार हों तो दैनिक रिमाइंडर प्राप्त करें।',
        'ml':
            'നിങ്ങളുടെ വാക്യങ്ങൾ അവലോകനത്തിന് തയ്യാറാകുമ്പോൾ ദൈനംദിന ഓർമ്മപ്പെടുത്തലുകൾ ലഭിക്കുക.',
      },
      NotificationPromptType.memoryVerseOverdue: {
        'en':
            'Be alerted when memory verses fall behind their review date, so none slip away.',
        'hi':
            'जब वचन अपनी समीक्षा तिथि से पीछे रह जाएं तो सूचना प्राप्त करें, ताकि कोई छूट न जाए।',
        'ml':
            'വാക്യങ്ങൾ അവലോകന തീയതി പിന്നിടുമ്പോൾ അറിയിപ്പ് ലഭിക്കുക, ഒന്നും വിട്ടുപോകാതിരിക്കാൻ.',
      },
    };
    return descriptions[type]?[languageCode] ?? descriptions[type]?['en'] ?? '';
  }
}

/// Shows the notification enable sheet.
///
/// Every notification category is on by default, so this never asks about a
/// category preference — that is what Settings is for. It appears only when
/// the OS/browser permission was explicitly refused, and at most once per
/// install across all notification types (see [NotificationPromptPolicy]).
///
/// Returns true if the user enabled, false if declined, null if not shown.
Future<bool?> showNotificationEnablePrompt({
  required BuildContext context,
  required NotificationPromptType type,
  String languageCode = 'en',
  bool forceShow = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final policy = NotificationPromptPolicy(prefs);

  if (!forceShow) {
    if (policy.hasAsked) return null;

    final service = sl<NotificationService>();
    final granted =
        await service.areNotificationsEnabled().catchError((_) => true);
    final denied = granted
        ? false
        : await service
            .isNotificationPermissionDenied()
            .catchError((_) => false);

    if (!policy.shouldShow(
        permissionGranted: granted, permissionDenied: denied)) {
      return null;
    }
  }

  if (!context.mounted) return null;

  // Recorded as soon as it is shown, so a swipe-away or barrier tap counts.
  await policy.markAsked();
  if (!context.mounted) return null;

  final config = NotificationPromptConfig.getConfig(type, languageCode);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NotificationEnableSheet(
      type: type,
      config: config,
      languageCode: languageCode,
      onInteraction: () {},
    ),
  );
}

class _NotificationEnableSheet extends StatelessWidget {
  final NotificationPromptType type;
  final NotificationPromptConfig config;
  final String languageCode;
  final VoidCallback onInteraction;

  const _NotificationEnableSheet({
    required this.type,
    required this.config,
    required this.languageCode,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return PopupSheet(
      crossAxisAlignment: CrossAxisAlignment.center,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      children: [
        PopupHeader(
          icon: PopupIconCircle(icon: config.icon, size: 64),
          eyebrow: context.tr(TranslationKeys.appChromeNotifyPromptEyebrow),
          title: config.title,
          body: config.description,
        ),
        const SizedBox(height: 24),
        BlocConsumer<NotificationBloc, NotificationState>(
          listener: (context, state) {
            if (state is NotificationPreferencesUpdated) {
              Navigator.pop(context, true);
            } else if (state is NotificationError) {
              // Show error feedback and close with false
              showAppSnackBar(
                context,
                _getErrorText(languageCode),
                tone: AppSnackTone.error,
              );
              Navigator.pop(context, false);
            }
          },
          builder: (context, state) {
            final isLoading = state is NotificationLoading;
            return _EnablePill(
              label: _getEnableText(languageCode),
              loading: isLoading,
              onPressed: () => _enableNotification(context),
            );
          },
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          label: _getNotNowText(languageCode),
          onPressed: () {
            onInteraction();
            Navigator.pop(context, false);
          },
        ),
      ],
    );
  }

  Future<void> _enableNotification(BuildContext context) async {
    onInteraction();
    final bloc = context.read<NotificationBloc>();

    // Turning the preference on is not enough when the OS permission was never
    // granted (or was denied) — the push still would not arrive. Ask for it
    // first, then record the preference either way so the user's intent is not
    // lost if they decline the system dialog.
    final notificationService = sl<NotificationService>();
    final osPermissionGranted = await notificationService
        .areNotificationsEnabled()
        .catchError((_) => true);
    var granted = osPermissionGranted;
    if (!osPermissionGranted) {
      granted = await notificationService
          .requestPermissions()
          .catchError((_) => false);
    }

    if (granted) {
      ActivationAnalytics.maybeTrack(
          NuxEvent.reminderOptIn, {'type': type.name});
    }

    if (!context.mounted) return;

    // Still refused, and the OS will not prompt again: the preference below
    // would switch on while no notification could ever arrive. Say so, and
    // offer the only route that still works.
    if (!granted) {
      final permanentlyDenied = await notificationService
          .isPermissionPermanentlyDenied()
          .catchError((_) => false);
      if (!context.mounted) return;
      if (permanentlyDenied) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.notificationsSettingsPermissionsDenied),
          tone: AppSnackTone.warning,
          actionLabel: context.tr(TranslationKeys.commonOpenSettings),
          onAction: notificationService.openPermissionSettings,
        );
      }
    }

    if (!context.mounted) return;

    switch (type) {
      case NotificationPromptType.dailyVerse:
        bloc.add(const UpdateNotificationPreferences(dailyVerseEnabled: true));
        break;
      case NotificationPromptType.recommendedTopic:
        bloc.add(
            const UpdateNotificationPreferences(recommendedTopicEnabled: true));
        break;
      case NotificationPromptType.streakReminder:
        bloc.add(
            const UpdateNotificationPreferences(streakReminderEnabled: true));
        break;
      case NotificationPromptType.streakMilestone:
        bloc.add(
            const UpdateNotificationPreferences(streakMilestoneEnabled: true));
        break;
      case NotificationPromptType.streakLost:
        bloc.add(const UpdateNotificationPreferences(streakLostEnabled: true));
        break;
      case NotificationPromptType.memoryVerseReminder:
        bloc.add(const UpdateNotificationPreferences(
            memoryVerseReminderEnabled: true));
        break;
      case NotificationPromptType.memoryVerseOverdue:
        bloc.add(const UpdateNotificationPreferences(
            memoryVerseOverdueEnabled: true));
        break;
    }
  }

  String _getNotNowText(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return 'अभी नहीं';
      case 'ml':
        return 'ഇപ്പോൾ വേണ്ട';
      default:
        return 'Not Now';
    }
  }

  String _getEnableText(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return 'चालू करें';
      case 'ml':
        return 'പ്രവർത്തനക്ഷമമാക്കുക';
      default:
        return 'Enable';
    }
  }

  String _getErrorText(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return 'कुछ गलत हो गया। कृपया पुनः प्रयास करें।';
      case 'ml':
        return 'എന്തോ തകരാറു സംഭവിച്ചു. ദയവായി വീണ്ടും ശ്രമിക്കുക.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Full-width primary pill that swaps its label for a spinner while the
/// preference is being saved.
class _EnablePill extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _EnablePill({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return PopupPrimaryButton(label: label, onPressed: onPressed);
    }
    final palette = ReaderPalette.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: palette.ctaFill.withValues(alpha: 0.7),
          minimumSize: const Size.fromHeight(50),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(palette.ctaInk),
          ),
        ),
      ),
    );
  }
}
