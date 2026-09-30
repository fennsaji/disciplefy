import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/config/app_config.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_form.dart';

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

  // Available interests: API value -> label translation key
  static const Map<String, String> _interests = {
    'prayer': TranslationKeys.profileSetupInterestPrayer,
    'worship': TranslationKeys.profileSetupInterestWorship,
    'community': TranslationKeys.profileSetupInterestCommunity,
    'bible_study': TranslationKeys.profileSetupInterestBibleStudy,
    'theology': TranslationKeys.profileSetupInterestTheology,
    'missions': TranslationKeys.profileSetupInterestMissions,
    'youth_ministry': TranslationKeys.profileSetupInterestYouthMinistry,
    'family': TranslationKeys.profileSetupInterestFamily,
    'leadership': TranslationKeys.profileSetupInterestLeadership,
    'evangelism': TranslationKeys.profileSetupInterestEvangelism,
  };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WelcomeFormPage(
      photo: WelcomePhotos.greenHills,
      backKey: const Key('profile_setup_back'),
      eyebrow: context.tr(TranslationKeys.profileSetupEyebrow),
      title: context.tr(TranslationKeys.profileSetupTitle),
      subtitle:
          WelcomeSubtitle(context.tr(TranslationKeys.profileSetupSubtitle)),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileImageSection(context),
              const SizedBox(height: 28),
              _buildNameSection(context),
              const SizedBox(height: 24),
              _buildAgeGroupSection(context),
              const SizedBox(height: 24),
              _buildInterestsSection(context),
              const SizedBox(height: 36),
              WelcomePrimaryButton(
                key: const Key('profile_setup_continue'),
                label: context.tr(TranslationKeys.profileSetupContinue),
                isLoading: _isLoading,
                onPressed: _handleContinue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageSection(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Center(
      child: Column(
        children: [
          Semantics(
            button: true,
            label: context.tr(TranslationKeys.profileSetupAddPhoto),
            child: GestureDetector(
              key: const Key('profile_setup_photo'),
              onTap: _isImageUploading ? null : _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.card,
                      border: Border.all(color: palette.outline, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _profileImageData != null
                        ? Image.memory(
                            _profileImageData!,
                            fit: BoxFit.cover,
                            cacheWidth: 336,
                          )
                        : Icon(
                            Icons.person_outline_rounded,
                            size: 48,
                            color: palette.dim,
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.ctaFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.page, width: 3),
                      ),
                      child: _isImageUploading
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    palette.ctaInk),
                              ),
                            )
                          : Icon(
                              Icons.camera_alt_outlined,
                              size: 17,
                              color: palette.ctaInk,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(TranslationKeys.profileSetupAddPhoto),
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.accentIcon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(
    BuildContext context, {
    required Key key,
    required TextEditingController controller,
    required String label,
    required String requiredMessage,
    required List<String> autofillHints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WelcomeFieldLabel(label),
        TextFormField(
          key: key,
          controller: controller,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: autofillHints,
          style: welcomeFieldTextStyle(context),
          decoration: welcomeFieldDecoration(context, hint: label),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return requiredMessage;
            }
            return null;
          },
        ),
      ],
    );
  }

  /// First and last name, side by side when there is room.
  Widget _buildNameSection(BuildContext context) {
    final first = _buildNameField(
      context,
      key: const Key('profile_setup_first_name'),
      controller: _firstNameController,
      label: context.tr(TranslationKeys.profileSetupFirstName),
      requiredMessage:
          context.tr(TranslationKeys.profileSetupFirstNameRequired),
      autofillHints: const [AutofillHints.givenName],
    );
    final last = _buildNameField(
      context,
      key: const Key('profile_setup_last_name'),
      controller: _lastNameController,
      label: context.tr(TranslationKeys.profileSetupLastName),
      requiredMessage: context.tr(TranslationKeys.profileSetupLastNameRequired),
      autofillHints: const [AutofillHints.familyName],
    );

    return AutofillGroup(
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 400
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [first, const SizedBox(height: 18), last],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 14),
                  Expanded(child: last),
                ],
              ),
      ),
    );
  }

  Widget _buildAgeGroupSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WelcomeFieldLabel(context.tr(TranslationKeys.profileSetupAgeGroup)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ageGroup in _ageGroups)
              WelcomeChoiceChip(
                key: Key('profile_setup_age_$ageGroup'),
                label: ageGroup,
                selected: _selectedAgeGroup == ageGroup,
                onTap: () => setState(() => _selectedAgeGroup = ageGroup),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInterestsSection(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WelcomeFieldLabel(context.tr(TranslationKeys.profileSetupInterests)),
        Text(
          context.tr(TranslationKeys.profileSetupInterestsHint),
          style: AppFonts.inter(
            fontSize: 13,
            height: 1.4,
            color: palette.dim,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _interests.entries)
              WelcomeChoiceChip(
                key: Key('profile_setup_interest_${entry.key}'),
                label: context.tr(entry.value),
                selected: _selectedInterests.contains(entry.key),
                onTap: () => setState(() {
                  if (!_selectedInterests.remove(entry.key)) {
                    _selectedInterests.add(entry.key);
                  }
                }),
              ),
          ],
        ),
      ],
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
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.profileSetupImageWebOnly),
        );
      }
    } catch (e) {
      Logger.error(
        'Failed to pick image',
        tag: 'PROFILE_SETUP',
        context: {'error': e.toString()},
      );

      if (mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.profileSetupImageFailed),
          tone: AppSnackTone.error,
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
          'file_type': fileType,
        },
      );

      final response = await _httpService.post(
        '${AppConfig.baseApiUrl}/upload-profile-image',
        headers: headers,
        body: jsonEncode({
          'action': 'upload_image',
          'file_type': fileType,
          'image_data': 'data:$fileType;base64,$imageData',
        }),
      );

      Logger.info(
        'Upload response received',
        tag: 'PROFILE_SETUP',
        context: {
          'status_code': response.statusCode,
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
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.commonErrorTryAgain),
          tone: AppSnackTone.error,
        );
      }
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAgeGroup == null) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.profileSetupSelectAgeGroup),
        tone: AppSnackTone.warning,
      );
      return;
    }

    if (_selectedInterests.isEmpty) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.profileSetupSelectInterest),
        tone: AppSnackTone.warning,
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
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.commonErrorTryAgain),
          tone: AppSnackTone.error,
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
