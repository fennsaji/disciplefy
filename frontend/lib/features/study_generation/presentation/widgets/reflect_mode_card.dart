import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../shared/widgets/clickable_scripture_text.dart';
import '../../domain/entities/reflection_response.dart';

/// Lightens a color for better contrast in dark mode
Color _lightenColor(Color color, [double amount = 0.2]) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

/// A card component for Reflect Mode that displays one section at a time
/// with an interactive element for engagement.
///
/// The card progresses through each section of the study guide, presenting
/// content with a low-friction interaction (taps, sliders, selections).
class ReflectModeCard extends StatefulWidget {
  /// Current card index (0-based)
  final int cardIndex;

  /// Total number of cards
  final int totalCards;

  /// Section title (e.g., "Summary", "Interpretation")
  final String sectionTitle;

  /// Section content text
  final String sectionContent;

  /// Type of interaction for this card
  final ReflectionInteractionType interactionType;

  /// Question to prompt the interaction
  final String interactionQuestion;

  /// Options for tap/multi-select interactions
  final List<InteractionOption>? options;

  /// Labels for slider interactions
  final SliderLabels? sliderLabels;

  /// Callback when interaction is completed
  final void Function(ReflectionResponse response) onInteractionComplete;

  /// Callback when Continue is pressed
  final VoidCallback onContinue;

  /// Whether this card is currently active
  final bool isActive;

  const ReflectModeCard({
    super.key,
    required this.cardIndex,
    required this.totalCards,
    required this.sectionTitle,
    required this.sectionContent,
    required this.interactionType,
    required this.interactionQuestion,
    this.options,
    this.sliderLabels,
    required this.onInteractionComplete,
    required this.onContinue,
    this.isActive = true,
  });

  @override
  State<ReflectModeCard> createState() => _ReflectModeCardState();
}

class _ReflectModeCardState extends State<ReflectModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _hasInteracted = false;
  dynamic _selectedValue;
  String? _additionalText;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ReflectModeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleInteraction(dynamic value, {String? additionalText}) {
    setState(() {
      _selectedValue = value;
      _additionalText = additionalText;
      _hasInteracted = true;
    });

    widget.onInteractionComplete(ReflectionResponse(
      interactionType: widget.interactionType,
      cardIndex: widget.cardIndex,
      sectionTitle: widget.sectionTitle,
      value: value,
      additionalText: additionalText,
      respondedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress bar
              _buildProgressBar(context),

              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section title
                      _buildSectionHeader(context),

                      const SizedBox(height: 16),

                      // Section content
                      _buildSectionContent(context),
                    ],
                  ),
                ),
              ),

              // Interaction area
              _buildInteractionArea(context),

              // Continue button
              _buildContinueButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = (widget.cardIndex + 1) / widget.totalCards;

    // Use tertiary color for dark mode (lighter purple), primary for light mode
    final textColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Card ${widget.cardIndex + 1} of ${widget.totalCards}',
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: textColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use tertiary color for dark mode (lighter purple), primary for light mode
    final badgeColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.sectionTitle,
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withOpacity(0.15),
        ),
      ),
      child: ClickableScriptureText(
        text: widget.sectionContent,
        style: AppFonts.inter(
          fontSize: 16,
          height: 1.6,
          color: theme.colorScheme.onBackground,
        ),
      ),
    );
  }

  Widget _buildInteractionArea(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.0),
                  accentColor.withOpacity(0.2),
                  accentColor.withOpacity(0.0),
                ],
              ),
            ),
          ),

          // Question
          Text(
            widget.interactionQuestion,
            style: AppFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),

          const SizedBox(height: 16),

          // Interaction widget
          _buildInteractionWidget(context),
        ],
      ),
    );
  }

  Widget _buildInteractionWidget(BuildContext context) {
    switch (widget.interactionType) {
      case ReflectionInteractionType.tapSelection:
        return _buildTapSelection(context);
      case ReflectionInteractionType.slider:
        return _buildSlider(context);
      case ReflectionInteractionType.yesNo:
        return _buildYesNo(context);
      case ReflectionInteractionType.multiSelect:
      case ReflectionInteractionType.verseSelection:
        return _buildMultiSelect(context);
      case ReflectionInteractionType.prayer:
        return _buildPrayerMode(context);
    }
  }

  Widget _buildTapSelection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;
    final options = widget.options ?? [];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = _selectedValue == option.label;
        return GestureDetector(
          onTap: () => _handleInteraction(option.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? accentColor : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? accentColor : accentColor.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Text(option.icon!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ],
                Text(
                  option.label,
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSlider(BuildContext context) {
    final theme = Theme.of(context);
    final labels = widget.sliderLabels ??
        const SliderLabels(left: 'Not at all', right: 'Very much');
    final value = (_selectedValue as double?) ?? 0.5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              labels.left,
              style: AppFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            Text(
              labels.right,
              style: AppFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
          ),
          child: Slider(
            value: value,
            onChanged: (newValue) {
              setState(() {
                _selectedValue = newValue;
                _hasInteracted = true;
              });
            },
            onChangeEnd: (newValue) => _handleInteraction(newValue),
          ),
        ),
      ],
    );
  }

  Widget _buildYesNo(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildYesNoButton(
                context,
                label: 'Yes',
                icon: Icons.check_circle_outline,
                isSelected: _selectedValue == true,
                onTap: () => _handleInteraction(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildYesNoButton(
                context,
                label: 'No',
                icon: Icons.cancel_outlined,
                isSelected: _selectedValue == false,
                onTap: () => _handleInteraction(false),
              ),
            ),
          ],
        ),
        if (_selectedValue == true) ...[
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Share briefly (optional)...',
              hintStyle: AppFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onBackground.withOpacity(0.4),
              ),
              filled: true,
              fillColor: accentColor.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 2,
            onChanged: (text) {
              _additionalText = text;
              _handleInteraction(true, additionalText: text);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildYesNoButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : accentColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : accentColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? Colors.white : theme.colorScheme.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelect(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;
    final options = widget.options ?? [];
    final selectedList = (_selectedValue as List<String>?) ?? [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedList.contains(option.label);
        return GestureDetector(
          onTap: () {
            final newList = List<String>.from(selectedList);
            if (isSelected) {
              newList.remove(option.label);
            } else {
              newList.add(option.label);
            }
            _handleInteraction(newList);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withOpacity(0.15)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? accentColor : accentColor.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Text(option.icon!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                ],
                Text(
                  option.label,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? accentColor
                        : theme.colorScheme.onBackground,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check,
                    size: 16,
                    color: accentColor,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrayerMode(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Column(
      children: [
        Row(
          children: [
            for (final mode in PrayerMode.values) ...[
              Expanded(
                child: _buildPrayerModeButton(context, mode),
              ),
              if (mode != PrayerMode.values.last) const SizedBox(width: 10),
            ],
          ],
        ),
        if (_selectedValue != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: accentColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Take your time in prayer',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrayerModeButton(BuildContext context, PrayerMode mode) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;
    final selectedMode = _selectedValue is Map
        ? PrayerModeExtension.fromString(_selectedValue['mode'] as String?)
        : null;
    final isSelected = selectedMode == mode;

    return GestureDetector(
      onTap: () {
        _handleInteraction({
          'mode': mode.value,
          'duration': 60, // Default 60 seconds
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : accentColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              mode.icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              mode.displayName,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    isSelected ? Colors.white : theme.colorScheme.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;
    final isLastCard = widget.cardIndex == widget.totalCards - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _hasInteracted ? 1.0 : 0.5,
        child: ElevatedButton(
          onPressed: _hasInteracted ? widget.onContinue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: _hasInteracted ? 4 : 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLastCard ? 'Complete' : 'Continue',
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLastCard ? Icons.check_circle_outline : Icons.arrow_forward,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Option for tap/multi-select interactions
class InteractionOption {
  final String label;
  final String? icon;
  final String? description;

  const InteractionOption({
    required this.label,
    this.icon,
    this.description,
  });
}

/// Labels for slider interactions
class SliderLabels {
  final String left;
  final String right;

  const SliderLabels({
    required this.left,
    required this.right,
  });
}
