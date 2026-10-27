import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/teacher_profile_avatar.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onProfileUpdated;
  final bool isDialog;
  final Map<String, String>? initialProfile;
  final Uint8List? initialProfilePhoto;

  const ProfileScreen({
    super.key,
    this.onClose,
    this.onProfileUpdated,
    this.isDialog = false,
    this.initialProfile,
    this.initialProfilePhoto,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  late ProfileService _profileService;

  String _userName = '';
  String _userEmail = '';
  String _userLRN = '';
  String _userGrade = '';
  String _savedUserGrade = '';
  String _userAddress = '';
  String _userRole = '';
  String _userCharacter = 'boy';
  String _userGender = '';
  Uint8List? _profilePhoto;
  Uint8List? _pendingProfilePhoto;
  bool _isEditing = false;
  bool _isDialogOpen = false;
  bool _isSavingProfile = false;
  bool _isProfileLoading = true;
  double? _photoUploadProgress;
  String? _saveStatus;
  String? _profileLoadError;
  String? _pendingEmailAddress;
  String? _emailSyncError;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _lrnController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileService = ProfileService();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _lrnController = TextEditingController();
    _addressController = TextEditingController();
    final initialProfile = widget.initialProfile;
    if (initialProfile != null) {
      _applyProfile(initialProfile);
      _profilePhoto = widget.initialProfilePhoto;
      _isProfileLoading = false;
      if (_profilePhoto == null &&
          (initialProfile['profilePhotoUrl'] ?? '').isNotEmpty) {
        _loadProfilePhoto(initialProfile['profilePhotoUrl']);
      }
    } else {
      _loadUserProfile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isProfileLoading &&
        !_isEditing &&
        !_isSavingProfile &&
        _pendingEmailAddress != null) {
      unawaited(_loadUserProfile());
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.loadProfile();
      Uint8List? photoFile;
      try {
        photoFile = await _profileService
            .getProfilePhoto(profilePhotoUrl: profile['profilePhotoUrl'])
            .timeout(const Duration(seconds: 20));
      } catch (error, stackTrace) {
        debugPrint('Unable to load profile photo: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() {
        _applyProfile(profile);
        _profilePhoto = photoFile;
        _isProfileLoading = false;
        _profileLoadError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to load profile: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isProfileLoading = false;
        _profileLoadError = _profileSaveErrorMessage(
          error,
          operation: 'profile load',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_profileLoadError!)),
      );
    }
  }

  void _applyProfile(Map<String, String> profile) {
    _userName = profile['name'] ?? '';
    _userEmail = profile['email'] ?? '';
    _userRole = profile['role'] ?? '';
    _userGender = profile['gender'] ?? '';
    _userLRN = profile['lrn'] ?? '';
    _userGrade = profile['grade'] ?? '';
    _savedUserGrade = _userGrade;
    _userAddress = profile['address'] ?? '';
    _userCharacter = profile['character'] == 'girl' ? 'girl' : 'boy';
    final pendingEmail = profile['pendingEmailAddress']?.trim() ?? '';
    _pendingEmailAddress = pendingEmail.isEmpty ? null : pendingEmail;
    final emailSyncError = profile['emailSyncError']?.trim() ?? '';
    _emailSyncError = emailSyncError.isEmpty ? null : emailSyncError;
    _nameController.text = _userName;
    _emailController.text = _userEmail;
    _lrnController.text = _userLRN;
    _addressController.text = _userAddress;
  }

  Future<void> _loadProfilePhoto(String? photoUrl) async {
    try {
      final photoFile = await _profileService
          .getProfilePhoto(profilePhotoUrl: photoUrl)
          .timeout(const Duration(seconds: 20));
      if (mounted && photoFile != null) {
        setState(() => _profilePhoto = photoFile);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to load profile photo: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 50,
      );

      if (pickedFile != null && mounted) {
        final photoBytes = await pickedFile.readAsBytes();
        if (photoBytes.length > 600 * 1024) {
          throw ArgumentError('Profile photos must be 600 KB or smaller.');
        }
        setState(() {
          _pendingProfilePhoto = photoBytes;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to update profile photo: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_profileSaveErrorMessage(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _profileSaveErrorMessage(
    Object error, {
    String operation = 'profile update',
  }) {
    if (error is ArgumentError) {
      return 'The selected image is too large. Choose a smaller photo (600 KB or less) and try again.';
    }
    if (error is StateError) return error.message.toString();
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'That email is already used by another account. Try a different email.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'That password does not match your current account.';
        case 'requires-recent-login':
          return 'Please log out and log back in before changing your email.';
        case 'too-many-requests':
          return 'Too many requests were made. Please wait a while and try again.';
        case 'network-request-failed':
          return 'Check your internet connection and try again.';
        case 'operation-not-allowed':
          return 'Email changes are not enabled for this account.';
        default:
          return 'Could not request the email change (${error.code}). Please retry.';
      }
    }
    if (error is! FirebaseException) {
      if (error is TimeoutException) {
        return 'Saving your changes timed out. Check your connection and retry.';
      }
      return 'Profile save failed: $error';
    }

    switch (
        error.code.replaceFirst(RegExp(r'^(storage|cloud_firestore)/'), '')) {
      case 'unauthenticated':
        return 'Your Firebase session expired. Log in again, then retry.';
      case 'permission-denied':
        return 'Firebase denied the $operation (${error.plugin}/${error.code}). Confirm that your account is approved, your session is active, and the deployed Firestore Rules allow this change.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Firebase could not save your changes right now. Check your internet connection and retry.';
      case 'resource-exhausted':
        return 'The profile photo exceeds Firestore limits. Choose a smaller image and retry.';
      default:
        return 'Could not save your profile (${error.plugin}/${error.code}). Please retry.';
    }
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final isStudent = _userRole.toLowerCase() == 'student';
    final email = _emailController.text.trim();
    final lrn = _lrnController.text.trim();
    if (name.isEmpty ||
        name.length > 100 ||
        address.length > 300 ||
        (isStudent &&
            (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
                !RegExp(r'^\d{12}$').hasMatch(lrn)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
              'Check your name, address, email, and 12-digit LRN before saving.',
            ),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (isStudent && _userGrade != 'Grade 7') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Grade 7 is available in MathQuest.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _photoUploadProgress = null;
      _saveStatus = 'Saving profile details...';
    });

    try {
      if (isStudent &&
          email.toLowerCase() != _userEmail.toLowerCase() &&
          email.toLowerCase() != _pendingEmailAddress?.toLowerCase()) {
        final password = await _requestCurrentPassword();
        if (password == null) {
          if (mounted) setState(() => _isSavingProfile = false);
          return;
        }
        await AuthService.requestCurrentEmailChange(
          newEmail: email.toLowerCase(),
          currentPassword: password,
        );
        _pendingEmailAddress = email.toLowerCase();
      }
      await _profileService.saveProfile(
        name: name,
        email: _userEmail,
        role: _userRole,
        address: address,
        grade: isStudent ? _userGrade : null,
        lrn: isStudent ? lrn : null,
        photoBytes: _pendingProfilePhoto,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _saveStatus = status);
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to save profile changes: $error');
      debugPrintStack(stackTrace: stackTrace);
      final saveException = error is ProfileSaveException ? error : null;
      final cause = saveException?.cause ?? error;
      if (saveException != null) {
        debugPrintStack(stackTrace: saveException.causeStackTrace);
      }
      if (!mounted) return;
      setState(() {
        if (saveException?.profileFieldsSaved == true) {
          _userName = name;
          _userAddress = address;
          if (isStudent) {
            _userLRN = lrn;
            _lrnController.text = lrn;
            _savedUserGrade = _userGrade;
          }
        }
        _isSavingProfile = false;
        _photoUploadProgress = null;
        _saveStatus = null;
      });
      final operation = saveException?.operation ?? 'profile update';
      final errorMessage = _profileSaveErrorMessage(
        cause,
        operation: operation,
      );
      final message = saveException?.profileFieldsSaved == true
          ? 'Your profile details were saved, but your photo was not. '
              '$errorMessage Your selected photo is still available to retry.'
          : _pendingEmailAddress != null &&
                  _pendingEmailAddress!.toLowerCase() ==
                      _emailController.text.trim().toLowerCase()
              ? 'Your profile details were not saved. A verification link was sent to $_pendingEmailAddress; your account email will not change until you verify it. $errorMessage'
              : errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
      if (saveException?.profileFieldsSaved == true) {
        widget.onProfileUpdated?.call();
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _userName = name;
      _userAddress = address;
      if (isStudent) {
        _userLRN = lrn;
        _lrnController.text = lrn;
        _savedUserGrade = _userGrade;
      }
      _profilePhoto = _pendingProfilePhoto ?? _profilePhoto;
      _isEditing = false;
      _isSavingProfile = false;
      _pendingProfilePhoto = null;
      _photoUploadProgress = null;
      _saveStatus = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _pendingEmailAddress != null &&
                  _pendingEmailAddress!.toLowerCase() == email.toLowerCase() &&
                  email.toLowerCase() != _userEmail.toLowerCase()
              ? 'Profile changes saved. A verification link was sent to $email. Your email changes after you verify it.'
              : 'Profile updated successfully!',
        ),
        backgroundColor: Colors.green,
      ),
    );
    widget.onProfileUpdated?.call();
  }

  Future<String?> _requestCurrentPassword() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _CurrentPasswordDialog(),
    );
  }

  void _logout() {
    if (_isDialogOpen) return; // Prevent multiple dialogs

    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isDialogOpen = false;
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _confirmLogout(context),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((_) {
      _isDialogOpen = false;
    });
  }

  Future<void> _confirmLogout(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    try {
      await _profileService.clearProfile();
      if (!mounted) return;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to sign out: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileContent = _isProfileLoading
        ? const Center(child: CircularProgressIndicator())
        : _profileLoadError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_profileLoadError!),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isProfileLoading = true;
                          _profileLoadError = null;
                        });
                        _loadUserProfile();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3D5AA),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 4),
                            // Profile Photo
                            GestureDetector(
                              onTap: _isEditing && !_isSavingProfile
                                  ? _pickProfilePhoto
                                  : null,
                              child: Stack(
                                children: [
                                  if (_userRole.toLowerCase() == 'teacher')
                                    TeacherProfileAvatar(
                                      gender: _userGender,
                                      photoBytes:
                                          _pendingProfilePhoto ?? _profilePhoto,
                                      size: 100,
                                      backgroundColor: const Color(0xFFECB56E),
                                    )
                                  else
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: const Color(0xFFECB56E),
                                      backgroundImage: (_pendingProfilePhoto ??
                                                  _profilePhoto) !=
                                              null
                                          ? MemoryImage(
                                              _pendingProfilePhoto ??
                                                  _profilePhoto!,
                                            )
                                          : null,
                                      child: _pendingProfilePhoto == null &&
                                              _profilePhoto == null
                                          ? ClipOval(
                                              child: Image.asset(
                                                _userCharacter == 'girl'
                                                    ? 'assets/images/player/girl.png'
                                                    : 'assets/images/player/boy.png',
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Text(
                                                  _userName.isEmpty
                                                      ? 'S'
                                                      : _userName[0]
                                                          .toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  if (_isSavingProfile &&
                                      _pendingProfilePhoto != null)
                                    Positioned.fill(
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 42,
                                              height: 42,
                                              child: CircularProgressIndicator(
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (_photoUploadProgress != null)
                                              Text(
                                                '${(_photoUploadProgress! * 100).round()}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E7D32),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(Icons.camera_alt,
                                            color: Colors.white, size: 18),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Display name or edit field
                            if (_isEditing)
                              TextField(
                                controller: _nameController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B3B5A),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your name',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            else
                              Text(
                                _userName.isEmpty ? 'Your Profile' : _userName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B3B5A),
                                ),
                              ),
                            const SizedBox(height: 24),
                            // Info fields
                            if (_isEditing &&
                                _userRole.toLowerCase() == 'student')
                              _buildEditableField(
                                'Email',
                                _emailController,
                                keyboardType: TextInputType.emailAddress,
                              )
                            else
                              _buildInfoRow('Email', _userEmail,
                                  readOnly: true),
                            if (!_isEditing && _pendingEmailAddress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 8),
                                child: Text(
                                  'Verify the link sent to $_pendingEmailAddress to finish updating your email.',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (_emailSyncError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _emailSyncError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isProfileLoading
                                          ? null
                                          : _loadUserProfile,
                                      child: const Text('Retry email sync'),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (_isEditing &&
                                _userRole.toLowerCase() == 'student')
                              _buildGradeDropdown()
                            else
                              _buildInfoRow(
                                  _userRole.toLowerCase() == 'teacher'
                                      ? 'Role'
                                      : 'Grade',
                                  _userRole.toLowerCase() == 'teacher'
                                      ? 'Teacher'
                                      : _userRole.toLowerCase() == 'student'
                                          ? _userGrade
                                          : _userRole.isEmpty
                                              ? 'N/A'
                                              : _userRole.toUpperCase(),
                                  readOnly: true),
                            const SizedBox(height: 12),
                            if (_isEditing &&
                                _userRole.toLowerCase() == 'student')
                              _buildEditableField(
                                'LRN',
                                _lrnController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12),
                                ],
                              )
                            else
                              _buildInfoRow('LRN', _userLRN, readOnly: true),
                            const SizedBox(height: 12),
                            if (_isEditing)
                              _buildEditableField('Address', _addressController)
                            else
                              _buildInfoRow('Address', _userAddress),
                            const SizedBox(height: 26),
                            if (_isEditing)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed:
                                      _isSavingProfile ? null : _saveProfile,
                                  child: _isSavingProfile
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _saveStatus ??
                                                  'Saving changes...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (_photoUploadProgress !=
                                                null) ...[
                                              const SizedBox(height: 8),
                                              LinearProgressIndicator(
                                                value: _photoUploadProgress,
                                                backgroundColor: Colors.white30,
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                        Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${((_photoUploadProgress ?? 0) * 100).round()}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ] else if (_pendingProfilePhoto !=
                                                null) ...[
                                              const SizedBox(height: 8),
                                              const LinearProgressIndicator(
                                                backgroundColor: Colors.white30,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            ],
                                          ],
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            if (_isEditing) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _isSavingProfile
                                      ? null
                                      : () {
                                          setState(() {
                                            _isEditing = false;
                                            _pendingProfilePhoto = null;
                                            _userGrade = _savedUserGrade;
                                            _emailController.text = _userEmail;
                                            _lrnController.text = _userLRN;
                                          });
                                          _nameController.text = _userName;
                                          _addressController.text =
                                              _userAddress;
                                        },
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1976D2),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: () =>
                                          setState(() => _isEditing = true),
                                      child: const Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _logout,
                                      child: const Text(
                                        'Logout',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF2E7D32),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: widget.onClose ??
                                          () => Navigator.maybePop(context),
                                      child: const Text(
                                        'Close',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
    if (widget.isDialog) {
      return profileContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F2847),
      body: SafeArea(
        child: profileContent,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool readOnly = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? 'N/A' : value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBBBBB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              isDense: true,
              hintText: 'Enter $label',
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBBBBB), width: 1),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _userGrade == 'Grade 7' ? _userGrade : 'Grade 7',
        decoration: const InputDecoration(
          labelText: 'Grade',
          border: InputBorder.none,
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7')),
        ],
        onChanged: _isSavingProfile
            ? null
            : (grade) {
                if (grade != null) setState(() => _userGrade = grade);
              },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _emailController.dispose();
    _lrnController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}

class _CurrentPasswordDialog extends StatefulWidget {
  const _CurrentPasswordDialog();

  @override
  State<_CurrentPasswordDialog> createState() => _CurrentPasswordDialogState();
}

class _CurrentPasswordDialogState extends State<_CurrentPasswordDialog> {
  final TextEditingController _controller = TextEditingController();

  void _close([String? password]) {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, password);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm It Is You'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Current password',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _close(_controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
