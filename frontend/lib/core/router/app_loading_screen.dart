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

    // Use the appropriate splash screen image based on theme
    final splashImage = isDarkMode
        ? 'assets/images/splash_screen_dark.png'
        : 'assets/images/splash_screen.png';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Splash screen image (same as web splash screen)
            Image.asset(
              splashImage,
              width: 200,
              height: 200,
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
            const SizedBox(height: 48),

            // Loading indicator
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
