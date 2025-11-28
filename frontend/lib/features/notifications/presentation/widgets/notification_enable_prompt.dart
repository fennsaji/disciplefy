// ============================================================================
// Notification Enable Prompt Widget
// ============================================================================
// A reusable bottom sheet prompt that asks users to enable specific
// notification types contextually when they interact with relevant features.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

/// Types of notification prompts that can be shown
enum NotificationPromptType {
  dailyVerse,
  recommendedTopic,
  streakReminder,
  streakMilestone,
  memoryVerseReminder,
  memoryVerseOverdue,
}

/// Configuration for each notification prompt type
class NotificationPromptConfig {
  final String title;
  final String description;
  final IconData icon;
  final String sharedPrefsKey;

  const NotificationPromptConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.sharedPrefsKey,
  });

  static NotificationPromptConfig getConfig(
      NotificationPromptType type, String languageCode) {
    switch (type) {
      case NotificationPromptType.dailyVerse:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.menu_book_rounded,
          sharedPrefsKey: 'notification_prompt_shown_daily_verse',
        );
      case NotificationPromptType.recommendedTopic:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.lightbulb_outline_rounded,
          sharedPrefsKey: 'notification_prompt_shown_recommended_topic',
        );
      case NotificationPromptType.streakReminder:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.local_fire_department_rounded,
          sharedPrefsKey: 'notification_prompt_shown_streak_reminder',
        );
      case NotificationPromptType.streakMilestone:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.emoji_events_rounded,
          sharedPrefsKey: 'notification_prompt_shown_streak_milestone',
        );
      case NotificationPromptType.memoryVerseReminder:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.psychology_rounded,
          sharedPrefsKey: 'notification_prompt_shown_memory_verse_reminder',
        );
      case NotificationPromptType.memoryVerseOverdue:
        return NotificationPromptConfig(
          title: _getLocalizedTitle(type, languageCode),
          description: _getLocalizedDescription(type, languageCode),
          icon: Icons.notification_important_rounded,
          sharedPrefsKey: 'notification_prompt_shown_memory_verse_overdue',
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
        'ml': 'സ്ട്രീക് ഓർമ്മപ്പെടുത്തൽ',
      },
      NotificationPromptType.streakMilestone: {
        'en': 'Milestone Celebrations',
        'hi': 'उपलब्धि सूचनाएं',
        'ml': 'നാഴികക്കല്ല് ആഘോഷങ്ങൾ',
      },
      NotificationPromptType.memoryVerseReminder: {
        'en': 'Memory Verse Reminders',
        'hi': 'वचन याद रिमाइंडर',
        'ml': 'വാക്യ ഓർമ്മ റിമൈൻഡർ',
      },
      NotificationPromptType.memoryVerseOverdue: {
        'en': 'Overdue Review Alerts',
        'hi': 'देर हुई समीक्षा अलर्ट',
        'ml': 'വൈകിയ അവലോകന അലേർട്ട്',
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
            'നിങ്ങളുടെ സ്ഥിരത ആഘോഷിക്കൂ! സ്ട്രീക് നാഴികക്കല്ലുകളിൽ എത്തുമ്പോൾ അറിയിപ്പ് ലഭിക്കുക.',
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
            'Get alerts when your memory verses become overdue so you don\'t lose progress.',
        'hi':
            'जब आपके वचन देर हो जाएं तो अलर्ट प्राप्त करें ताकि आप प्रगति न खोएं।',
        'ml':
            'നിങ്ങളുടെ വാക്യങ്ങൾ വൈകുമ്പോൾ അലേർട്ടുകൾ ലഭിക്കുക, അതിനാൽ നിങ്ങൾ പുരോഗതി നഷ്ടപ്പെടുത്തില്ല.',
      },
    };
    return descriptions[type]?[languageCode] ?? descriptions[type]?['en'] ?? '';
  }
}

/// Shows a notification enable prompt bottom sheet
/// Returns true if user enabled, false if declined, null if already shown before
Future<bool?> showNotificationEnablePrompt({
  required BuildContext context,
  required NotificationPromptType type,
  String languageCode = 'en',
  bool forceShow = false,
}) async {
  // Check if we've already shown this prompt
  final prefs = await SharedPreferences.getInstance();
  final config = NotificationPromptConfig.getConfig(type, languageCode);

  if (!forceShow && prefs.getBool(config.sharedPrefsKey) == true) {
    return null; // Already shown before
  }

  if (!context.mounted) return null;

  // Mark as shown only after user interacts with the prompt
  void markAsShown() {
    prefs.setBool(config.sharedPrefsKey, true);
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NotificationEnableSheet(
      type: type,
      config: config,
      languageCode: languageCode,
      onInteraction: markAsShown,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  config.icon,
                  size: 40,
                  color:
                      isDark ? const Color(0xFFA78BFA) : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                config.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : null,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                config.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  // Not Now button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onInteraction();
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _getNotNowText(languageCode),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Enable button
                  Expanded(
                    child: BlocConsumer<NotificationBloc, NotificationState>(
                      listener: (context, state) {
                        if (state is NotificationPreferencesUpdated) {
                          Navigator.pop(context, true);
                        } else if (state is NotificationError) {
                          // Show error feedback and close with false
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _getErrorText(languageCode, state.message),
                              ),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context, false);
                        }
                      },
                      builder: (context, state) {
                        final isLoading = state is NotificationLoading;

                        return ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () => _enableNotification(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  _getEnableText(languageCode),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enableNotification(BuildContext context) {
    onInteraction();
    final bloc = context.read<NotificationBloc>();

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
        bloc.add(const UpdateNotificationPreferences(
          streakMilestoneEnabled: true,
          streakLostEnabled: true, // Enable both together
        ));
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

  String _getErrorText(String languageCode, String errorMessage) {
    switch (languageCode) {
      case 'hi':
        return 'सूचनाएं सक्षम करने में विफल: $errorMessage';
      case 'ml':
        return 'അറിയിപ്പുകൾ പ്രവർത്തനക്ഷമമാക്കുന്നതിൽ പരാജയപ്പെട്ടു: $errorMessage';
      default:
        return 'Failed to enable notifications: $errorMessage';
    }
  }
}
