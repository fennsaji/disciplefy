import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/auth_aware_navigation_service.dart';
import '../../../../core/services/image_compression_service.dart';
import '../../../../core/utils/logger.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;

/// Profile completion screen for first-time users
/// Collects first name, last name, and optional profile picture
class ProfileCompletionScreen extends StatefulWidget {
  final User user;
  final bool isFirstTime;

  const ProfileCompletionScreen({
    super.key,
    required this.user,
    this.isFirstTime = true,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();

  final ImagePicker _imagePicker = ImagePicker();
  final ImageCompressionService _compressionService = ImageCompressionService();

  File? _selectedImage;
  CompressionResult? _compressionResult;
  bool _isCompressing = false;
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _initializeFromUser();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }

  void _initializeFromUser() {
    // Pre-populate fields if user has some data (from OAuth)
    final userMetadata = widget.user.userMetadata ?? {};

    // Try to extract names from OAuth data
    final fullName = userMetadata['full_name'] ?? userMetadata['name'] ?? '';
    if (fullName.isNotEmpty) {
      final nameParts = fullName.split(' ');
      if (nameParts.isNotEmpty) {
        _firstNameController.text = nameParts.first;
        if (nameParts.length > 1) {
          _lastNameController.text = nameParts.skip(1).join(' ');
        }
      }
    }

    // Try to get profile picture URL from OAuth
    final pictureUrl = userMetadata['avatar_url'] ?? userMetadata['picture'];
    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      // For now, we'll show this as a hint but let user upload their own
      Logger.info(
        'User has OAuth profile picture available',
        tag: 'PROFILE_COMPLETION',
        context: {'picture_url': pictureUrl},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, auth_states.AuthState>(
      listener: (context, state) {
        if (state is auth_states.AuthenticatedState) {
          Logger.info(
            'Profile completion successful - navigating to home',
            tag: 'PROFILE_COMPLETION',
            context: {
              'user_id': state.userId,
              'has_profile_picture': _profilePicturePath != null,
            },
          );
          // Use AuthAwareNavigationService for proper post-auth navigation
          context.navigateAfterAuth();
        } else if (state is auth_states.AuthErrorState) {
          Logger.error(
            'Profile completion error',
            tag: 'PROFILE_COMPLETION',
            context: {
              'user_id': widget.user.id,
              'error': state.message,
            },
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is auth_states.ProfilePictureUploadingState) {
          // Show upload progress
          if (state.progress > 0.0 && state.progress < 1.0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: state.progress,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                        'Uploading profile picture... ${(state.progress * 100).toInt()}%'),
                  ],
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 10),
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading:
              false, // Don't show back button for first-time users
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // Header Section
                  _buildHeader(context),

                  const SizedBox(height: 48),

                  // Profile Picture Section
                  _buildProfilePictureSection(context),

                  const SizedBox(height: 32),

                  // Name Input Section
                  _buildNameInputSection(context),

                  const SizedBox(height: 32),

                  // Continue Button
                  _buildContinueButton(context),

                  const SizedBox(height: 24),

                  // Skip Button (if not mandatory)
                  if (widget.isFirstTime) _buildSkipButton(context),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Welcome Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_add,
            size: 40,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(height: 24),

        // Title
        Text(
          'Complete Your Profile',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
        ),

        const SizedBox(height: 16),

        // Subtitle
        Text(
          'Help us personalize your Bible study experience\\nby completing your profile',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProfilePictureSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Profile Picture (Optional)',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 20),

          // Profile Picture Preview/Selector
          GestureDetector(
            onTap: _showImagePickerBottomSheet,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.file(
                        _selectedImage!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.add_a_photo,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Compression info (if available)
          if (_compressionResult != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Optimized: ${_compressionResult!.originalSizeFormatted} → ${_compressionResult!.compressedSizeFormatted}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Add/Change Picture Button
          TextButton.icon(
            onPressed: _showImagePickerBottomSheet,
            icon: Icon(
              _selectedImage != null ? Icons.edit : Icons.add_photo_alternate,
              size: 16,
            ),
            label: Text(
              _selectedImage != null ? 'Change Picture' : 'Add Picture',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInputSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 20),

          // First Name Field
          TextFormField(
            controller: _firstNameController,
            focusNode: _firstNameFocusNode,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'First Name *',
              hintText: 'Enter your first name',
              prefixIcon: Icon(
                Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              labelStyle: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              hintStyle: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
            style: GoogleFonts.inter(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'First name is required';
              }
              if (value.trim().length < 2) {
                return 'First name must be at least 2 characters';
              }
              if (value.trim().length > 50) {
                return 'First name must be less than 50 characters';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              _lastNameFocusNode.requestFocus();
            },
          ),

          const SizedBox(height: 16),

          // Last Name Field
          TextFormField(
            controller: _lastNameController,
            focusNode: _lastNameFocusNode,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Last Name *',
              hintText: 'Enter your last name',
              prefixIcon: Icon(
                Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              labelStyle: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              hintStyle: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
            style: GoogleFonts.inter(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Last name is required';
              }
              if (value.trim().length < 2) {
                return 'Last name must be at least 2 characters';
              }
              if (value.trim().length > 50) {
                return 'Last name must be less than 50 characters';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              _handleProfileCompletion();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isLoading = state is auth_states.ProfileCompletingState ||
            state is auth_states.ProfilePictureUploadingState ||
            _isCompressing;

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleProfileCompletion,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isCompressing
                            ? 'Processing Image...'
                            : 'Completing Profile...',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Continue to Disciplefy',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: () {
        // Skip profile completion and go directly to app
        context.navigateAfterAuth();
      },
      child: Text(
        'Skip for now',
        style: GoogleFonts.inter(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showImagePickerBottomSheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Add Profile Picture',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 24),

              // Camera Option
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Use camera to take a new picture',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),

              // Gallery Option
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Select an existing picture',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),

              // Remove Option (if image exists)
              if (_selectedImage != null)
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  title: Text(
                    'Remove Picture',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Remove current profile picture',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImage = null;
                      _compressionResult = null;
                      _profilePicturePath = null;
                    });
                  },
                ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        await _compressAndSetImage(imageFile);
      }
    } catch (e) {
      Logger.error(
        'Failed to pick image',
        tag: 'PROFILE_COMPLETION',
        context: {
          'source': source.toString(),
          'error': e.toString(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _compressAndSetImage(File imageFile) async {
    setState(() {
      _isCompressing = true;
    });

    try {
      final compressionResult =
          await _compressionService.compressProfilePicture(imageFile);

      setState(() {
        _selectedImage = compressionResult.compressedFile;
        _compressionResult = compressionResult;
        _isCompressing = false;
      });
    } catch (e) {
      setState(() {
        _isCompressing = false;
      });

      Logger.error(
        'Failed to compress image',
        tag: 'PROFILE_COMPLETION',
        context: {
          'error': e.toString(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleProfileCompletion() {
    if (_formKey.currentState?.validate() ?? false) {
      // Haptic feedback
      HapticFeedback.lightImpact();

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // If user selected an image, upload it first
      if (_selectedImage != null) {
        context.read<AuthBloc>().add(
              ProfilePictureUploadRequested(
                userId: widget.user.id,
                imagePath: _selectedImage!.path,
              ),
            );
      }

      // Complete profile with names
      context.read<AuthBloc>().add(
            ProfileCompletionRequested(
              firstName: firstName,
              lastName: lastName,
              profilePicturePath: _profilePicturePath,
            ),
          );
    }
  }
}
