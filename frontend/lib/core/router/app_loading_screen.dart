import 'package:flutter/material.dart';

/// Loading screen shown during app initialization while Supabase restores session
/// ANDROID FIX: Prevents flash of login screen during session restoration
/// Uses actual splash screen image for visual consistency
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    // Use the appropriate splash screen image based on theme
    final splashImage = isDarkMode
        ? 'assets/images/splash_screen_dark.png'
        : 'assets/images/splash_screen.png';

    // Theme-aware background and loader colors
    final backgroundColor = isDarkMode
        ? const Color(0xFF0F1012) // Dark mode: #0f1012
        : const Color(0xFFFBEDD9); // Light mode: #FBEDD9

    final loaderColor = isDarkMode
        ? Colors.white // White loader for dark mode
        : const Color(0xFF6A4FB6); // Primary purple for light mode

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Splash screen image (same as web splash screen) - fits to screen
          Center(
            child: Image.asset(
              splashImage,
              width: screenSize.width,
              height: screenSize.height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if image fails to load
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    color: theme.colorScheme.onPrimary,
                    size: 48,
                  ),
                );
              },
            ),
          ),

          // Loading indicator positioned at bottom - with theme-aware color
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                color: loaderColor,
                strokeWidth: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
