import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/services/http_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/config/app_config.dart';

// Platform-conditional import for image picker
import '../../utils/profile_image_picker_stub.dart'
    if (dart.library.html) '../../utils/profile_image_picker_web.dart';

/// Profile setup screen for new users after phone verification
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  String? _selectedAgeGroup;
  final List<String> _selectedInterests = [];
  Uint8List? _profileImageData;
  String? _profileImageUrl;
  bool _isLoading = false;
  bool _isImageUploading = false;

  final HttpService _httpService = sl<HttpService>();

  // Available age groups
  final List<String> _ageGroups = ['13-17', '18-25', '26-35', '36-50', '51+'];

  // Available interests
  final Map<String, String> _interests = {
    'prayer': 'Prayer',
    'worship': 'Worship',
    'community': 'Community',
    'bible_study': 'Bible Study',
    'theology': 'Theology',
    'missions': 'Missions',
    'youth_ministry': 'Youth Ministry',
    'family': 'Family',
    'leadership': 'Leadership',
    'evangelism': 'Evangelism'
  };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Setup Profile',
          style: AppFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(theme),
                const SizedBox(height: 32),

                // Profile Image Section
                _buildProfileImageSection(theme),
                const SizedBox(height: 32),

                // Name Fields
                _buildNameSection(theme),
                const SizedBox(height: 24),

                // Age Group Section
                _buildAgeGroupSection(theme),
                const SizedBox(height: 24),

                // Interests Section
                _buildInterestsSection(theme),
                const SizedBox(height: 40),

                // Continue Button
                _buildContinueButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell us about yourself',
          style: AppFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Help us personalize your Bible study experience by sharing a bit about yourself.',
          style: AppFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageSection(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: _profileImageData != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Image.memory(
                          _profileImageData!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 48,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isImageUploading ? null : _pickImage,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 3,
                      ),
                    ),
                    child: _isImageUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Add Profile Photo',
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name',
          style: AppFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgeGroupSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Age Group',
          style: AppFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ageGroups.map((ageGroup) {
            final isSelected = _selectedAgeGroup == ageGroup;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAgeGroup = ageGroup;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  ageGroup,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        isSelected ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInterestsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interests',
          style: AppFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select topics you\'re interested in learning about (select at least one)',
          style: AppFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _interests.entries.map((entry) {
            final isSelected = _selectedInterests.contains(entry.key);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedInterests.remove(entry.key);
                  } else {
                    _selectedInterests.add(entry.key);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildContinueButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Continue',
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isImageUploading = true;
      });

      if (kIsWeb) {
        // Web-only implementation
        await _pickImageWeb();
      } else {
        // Mobile implementation would go here
        // For now, show an error that image picking is only supported on web
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload is currently only supported on web'),
          ),
        );
      }
    } catch (e) {
      Logger.error(
        'Failed to pick image',
        tag: 'PROFILE_SETUP',
        context: {'error': e.toString()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImageUploading = false;
        });
      }
    }
  }

  Future<void> _pickImageWeb() async {
    final result = await ProfileImagePicker.pickImage();

    if (result != null) {
      final data = result['data'] as Uint8List;
      final fileName = result['name'] as String;
      final fileType = result['type'] as String;

      setState(() {
        _profileImageData = data;
      });

      // Upload image (non-blocking - continue even if upload fails)
      try {
        await _uploadImage(fileName, fileType, base64Encode(data));
      } catch (e) {
        Logger.error(
          'Image upload failed, but continuing with local image',
          tag: 'PROFILE_SETUP',
          context: {'error': e.toString()},
        );
        // Continue with local image data even if upload fails
      }
    }
  }

  Future<void> _uploadImage(
      String fileName, String fileType, String imageData) async {
    try {
      final headers = await _httpService.createHeaders(
        additionalHeaders: {'Content-Type': 'application/json'},
      );

      Logger.info(
        'Uploading image with headers',
        tag: 'PROFILE_SETUP',
        context: {
          'headers_keys': headers.keys.toList(),
          'has_authorization': headers.containsKey('Authorization'),
          'file_name': fileName,
          'file_type': fileType,
        },
      );

      final response = await _httpService.post(
        '${AppConfig.baseApiUrl}/upload-profile-image',
        headers: headers,
        body: jsonEncode({
          'action': 'upload_image',
          'file_name': fileName,
          'file_type': fileType,
          'image_data': 'data:$fileType;base64,$imageData',
        }),
      );

      Logger.info(
        'Upload response received',
        tag: 'PROFILE_SETUP',
        context: {
          'status_code': response.statusCode,
          'response_body': response.body,
        },
      );

      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        setState(() {
          _profileImageUrl = responseData['data']['image_url'];
        });

        Logger.info(
          'Profile image uploaded successfully',
          tag: 'PROFILE_SETUP',
          context: {'image_url': _profileImageUrl},
        );
      } else {
        throw Exception(responseData['error'] ?? 'Upload failed');
      }
    } catch (e) {
      Logger.error(
        'Failed to upload image',
        tag: 'PROFILE_SETUP',
        context: {'error': e.toString()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAgeGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your age group'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one interest'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await _httpService.createHeaders(
        additionalHeaders: {'Content-Type': 'application/json'},
      );

      final response = await _httpService.post(
        '${AppConfig.baseApiUrl}/profile-setup',
        headers: headers,
        body: jsonEncode({
          'action': 'update_profile',
          'profile_data': {
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'age_group': _selectedAgeGroup,
            'interests': _selectedInterests,
            'profile_image_url': _profileImageUrl,
          },
        }),
      );

      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        Logger.info(
          'Profile setup completed successfully',
          tag: 'PROFILE_SETUP',
          context: {
            'user_name':
                '${_firstNameController.text} ${_lastNameController.text}',
            'age_group': _selectedAgeGroup,
            'interests_count': _selectedInterests.length,
          },
        );

        // Navigate to language selection
        if (mounted) {
          context.go('/language-selection');
        }
      } else {
        throw Exception(responseData['error'] ?? 'Profile setup failed');
      }
    } catch (e) {
      Logger.error(
        'Failed to setup profile',
        tag: 'PROFILE_SETUP',
        context: {'error': e.toString()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
