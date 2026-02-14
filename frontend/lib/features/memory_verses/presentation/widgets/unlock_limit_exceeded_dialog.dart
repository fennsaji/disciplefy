import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';

/// Dialog shown when user exceeds their daily practice mode unlock limit for a verse.
/// Displays unlocked modes, remaining slots, and upgrade options.
class UnlockLimitExceededDialog extends StatelessWidget {
  final List<String> unlockedModes;
  final int unlockedCount;
  final int limit;
  final String tier;
  final String verseReference;

  const UnlockLimitExceededDialog({
    super.key,
    required this.unlockedModes,
    required this.unlockedCount,
    required this.limit,
    required this.tier,
    required this.verseReference,
  });

  /// Show the unlock limit exceeded dialog.
  static void show(
    BuildContext context, {
    required List<String> unlockedModes,
    required int unlockedCount,
    required int limit,
    required String tier,
    required String verseReference,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnlockLimitExceededDialog(
        unlockedModes: unlockedModes,
        unlockedCount: unlockedCount,
        limit: limit,
        tier: tier,
        verseReference: verseReference,
      ),
    );
  }

  /// Get user-friendly mode names
  String _getModeName(String mode) {
    const modeNames = {
      'flip_card': 'Flip Card',
      'type_it_out': 'Type It Out',
      'cloze': 'Cloze Practice',
      'first_letter': 'First Letter',
      'progressive': 'Progressive Reveal',
      'word_scramble': 'Word Scramble',
      'word_bank': 'Word Bank',
      'audio': 'Audio Practice',
    };
    return modeNames[mode] ?? mode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Convert unlocked mode slugs to readable names
    final unlockedModeNames =
        unlockedModes.map((mode) => _getModeName(mode)).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Daily Unlock Limit Reached',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve unlocked $unlockedCount practice mode${unlockedCount > 1 ? 's' : ''} for "$verseReference" today.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Modes Unlocked Today:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$unlockedCount / $limit',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...unlockedModeNames.map((modeName) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              modeName,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to unlock more modes per verse per day:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildPlanOption(
              context,
              'Standard',
              '2 modes per verse per day',
              '₹79/month',
              tier == 'free',
            ),
            _buildPlanOption(
              context,
              'Plus',
              '3 modes per verse per day',
              '₹149/month',
              tier == 'free' || tier == 'standard',
            ),
            _buildPlanOption(
              context,
              'Premium',
              'All modes unlocked',
              '₹499/month',
              true,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You can still practice unlimited times with your unlocked modes today!',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, AppRoutes.pricing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  Widget _buildPlanOption(
    BuildContext context,
    String name,
    String modes,
    String price,
    bool showCheckmark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            showCheckmark ? Icons.check_circle : Icons.circle_outlined,
            color: showCheckmark ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$modes '),
                  TextSpan(
                    text: '($price)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
