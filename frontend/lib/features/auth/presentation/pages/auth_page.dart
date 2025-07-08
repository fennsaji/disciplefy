import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      await _authService.signInWithApple();
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple Sign-In failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title
            Text(
              'Welcome to Disciplefy Bible Study',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Subtitle
            Text(
              'Sign in to save your study guides and sync across devices',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 48),
            
            // Sign in buttons
            Column(
              children: [
                // Google Sign In
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata),
                    label: Text(_isLoading ? 'Signing in...' : 'Continue with Google'),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Apple Sign In
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleAppleSignIn,
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Continue without signing in
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Continue without signing in'),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Privacy note
            Text(
              'By signing in, you agree to our Terms of Service and Privacy Policy',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}