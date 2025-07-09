import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/debug_helper.dart';

/// Welcome/Login screen based on Login_Screen.jpg design.
/// 
/// Features app logo, tagline, and authentication options
/// following the UX specifications and brand guidelines.
class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage> {
  // Constants for API configuration
  static const String _baseUrl = 'http://127.0.0.1:54321';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
  
  // Secure storage instance
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Loading states
  bool _isGuestLoginLoading = false;
  bool _isGoogleLoginLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;
    
    // If localization is not ready, show loading
    if (l10n == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Top spacing
              SizedBox(height: isLargeScreen ? 80 : 60),
              
              // App Logo Section
              Column(
                children: [
                  // Logo Container
                  Container(
                    width: isLargeScreen ? 120 : 100,
                    height: isLargeScreen ? 120 : 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: isLargeScreen ? 64 : 56,
                      color: Colors.white,
                    ),
                  ),
                  
                  SizedBox(height: isLargeScreen ? 32 : 24),
                  
                  // App Title
                  Text(
                    'Disciplefy',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isLargeScreen ? 48 : 42,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  SizedBox(height: isLargeScreen ? 16 : 12),
                  
                  // Tagline
                  Text(
                    'Deepen your faith with guided studies',
                    style: GoogleFonts.inter(
                      fontSize: isLargeScreen ? 20 : 18,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Features Preview Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'What you\'ll get:',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _WelcomeFeatureItem(
                      icon: Icons.auto_awesome,
                      title: 'AI-Powered Study Guides',
                      subtitle: 'Personalized insights for any verse or topic',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _WelcomeFeatureItem(
                      icon: Icons.school,
                      title: 'Structured Learning',
                      subtitle: 'Follow proven biblical study methodology',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _WelcomeFeatureItem(
                      icon: Icons.language,
                      title: 'Multi-Language Support',
                      subtitle: 'Study in English, Hindi, and Malayalam',
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Authentication Buttons
              Column(
                children: [
                  // Login with Google Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGoogleLoginLoading || _isGuestLoginLoading 
                          ? null 
                          : () => _handleGoogleLogin(context),
                      icon: _isGoogleLoginLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.g_mobiledata,
                              size: 24,
                            ),
                      label: Text(
                        _isGoogleLoginLoading ? 'Signing in...' : 'Login with Google',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Continue as Guest Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isGoogleLoginLoading || _isGuestLoginLoading 
                          ? null 
                          : () => _loginAsGuest(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isGuestLoginLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Signing in...',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Continue as Guest',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: isLargeScreen ? 40 : 24),
              
              // Privacy/Terms Notice
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Logs in as a guest user by creating an anonymous session.
  /// 
  /// This method:
  /// 1. Calls the Supabase anonymous signup API
  /// 2. Extracts the access token from the response
  /// 3. Stores the token securely using flutter_secure_storage
  /// 4. Navigates to the home screen on success
  /// 5. Shows error messages on failure
  Future<void> _loginAsGuest() async {
    if (_isGuestLoginLoading) return;
    
    setState(() {
      _isGuestLoginLoading = true;
    });

    try {
      print('🚀 [DEBUG] Starting guest login...');
      
      // Create anonymous session with Supabase auth
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/signup'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _supabaseAnonKey,
        },
        body: json.encode({}), // Empty JSON body as required
      );

      print('📡 [DEBUG] API Response Status: ${response.statusCode}');
      print('📄 [DEBUG] API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          // Parse the response to extract the access token
          final Map<String, dynamic> responseData = json.decode(response.body);
          print('✅ [DEBUG] JSON parsing successful');
          print('🔍 [DEBUG] Response keys: ${responseData.keys.toList()}');
          
          // Log detailed response structure
          DebugHelper.logSupabaseResponse(responseData);
          
          // Check for access token with detailed logging
          if (responseData.containsKey('access_token')) {
            final String accessToken = responseData['access_token'];
            print('🔑 [DEBUG] Access token received: ${accessToken.substring(0, 20)}...');
            
            try {
              // Store the token securely
              await _secureStorage.write(
                key: 'auth_token', 
                value: accessToken,
              );
              print('💾 [DEBUG] Auth token stored');
              
              // Store user type for future reference
              await _secureStorage.write(
                key: 'user_type', 
                value: 'guest',
              );
              print('💾 [DEBUG] User type stored');
              
              // Store session info if available - with null safety
              final user = responseData['user'];
              if (user != null && user is Map<String, dynamic>) {
                final userId = user['id'];
                if (userId != null && userId is String) {
                  await _secureStorage.write(
                    key: 'user_id', 
                    value: userId,
                  );
                  print('💾 [DEBUG] User ID stored: $userId');
                } else {
                  print('⚠️ [DEBUG] User ID is null or not a string: $userId');
                }
              } else {
                print('⚠️ [DEBUG] User object is null or invalid: $user');
              }
              
              // Mark onboarding as completed
              await _secureStorage.write(
                key: 'onboarding_completed', 
                value: 'true',
              );
              print('💾 [DEBUG] Onboarding marked as completed');

              if (mounted) {
                print('🧭 [DEBUG] Navigating to home (/)');
                // Navigate to home screen (route is '/' not '/home')
                context.go('/');
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Welcome! You\'re signed in as a guest.',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                print('✅ [DEBUG] Guest login flow completed successfully');
                
                // Validate stored data
                await DebugHelper.printStoredAuthData();
              } else {
                print('❌ [DEBUG] Widget not mounted, skipping navigation');
              }
            } catch (storageError) {
              print('💥 [DEBUG] Storage error: $storageError');
              throw Exception('Failed to store authentication data: $storageError');
            }
          } else {
            print('❌ [DEBUG] No access_token in response');
            print('🔍 [DEBUG] Available keys: ${responseData.keys.toList()}');
            throw Exception('No access token received from server');
          }
        } catch (jsonError) {
          print('💥 [DEBUG] JSON parsing error: $jsonError');
          print('📄 [DEBUG] Raw response: ${response.body}');
          throw Exception('Failed to parse server response: $jsonError');
        }
      } else {
        print('❌ [DEBUG] API error - Status: ${response.statusCode}');
        print('📄 [DEBUG] Error response: ${response.body}');
        
        // Handle API error response with safer JSON parsing
        try {
          final Map<String, dynamic> errorData = json.decode(response.body);
          final String errorMessage = errorData['error_description'] ?? 
                                     errorData['message'] ?? 
                                     'Server returned status ${response.statusCode}';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Server error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      print('💥 [DEBUG] Guest login error: $e');
      print('📚 [DEBUG] Stack trace: $stackTrace');
      
      if (mounted) {
        // Show error dialog with more specific error information
        _showErrorDialog(
          'Guest Login Failed',
          'Unable to sign in as guest:\n\n${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGuestLoginLoading = false;
        });
      }
    }
  }

  void _handleGoogleLogin(BuildContext context) async {
    setState(() {
      _isGoogleLoginLoading = true;
    });
    
    // TODO: Implement Google login with Supabase auth
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    
    if (mounted) {
      setState(() {
        _isGoogleLoginLoading = false;
      });
      
      // Show loading state while authenticating
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google authentication coming soon!',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  /// Shows an error dialog with the given title and message.
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: AppTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Individual feature item widget for the welcome screen.
class _WelcomeFeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WelcomeFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon container
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 2),
              
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}