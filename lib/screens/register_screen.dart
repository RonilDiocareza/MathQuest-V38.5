import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../game/player.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/math_background.dart';

typedef StudentRegistrationHandler = Future<void> Function({
  required String email,
  required String password,
  required String name,
  required String address,
  required String lrn,
  required String character,
});

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.onRegister});

  final StudentRegistrationHandler? onRegister;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _lrnController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  bool _isLoading = false;
  String? _selectedCharacter = 'boy';

  @override
  void initState() {
    super.initState();
    _lrnController = TextEditingController();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _lrnController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_selectedCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a character before registering.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Check password match
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('❌ Passwords do not match!'),
              backgroundColor: Colors.red),
        );
        return;
      }

      setState(() => _isLoading = true);

      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      try {
        final name = _nameController.text.trim();
        final address = _addressController.text.trim();
        final lrn = _lrnController.text.trim();
        final register = widget.onRegister;
        if (register == null) {
          await AuthService.register(
            email: email,
            password: password,
            name: name,
            address: address,
            lrn: lrn,
            character: _selectedCharacter!,
          );
        } else {
          await register(
            email: email,
            password: password,
            name: name,
            address: address,
            lrn: lrn,
            character: _selectedCharacter!,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Account created. Wait for admin approval.'),
                backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (error, stackTrace) {
        final code = switch (error) {
          FirebaseAuthException() => error.code,
          FirebaseException() => error.code,
          _ => error.runtimeType.toString(),
        };
        debugPrint(
          'Student registration failed: type=${error.runtimeType}, '
          'code=$code, message=$error.',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_registrationErrorMessage(error)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _registrationErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'An account already uses this email.',
        'weak-password' => 'Choose a stronger password.',
        'invalid-email' => 'Enter a valid email address.',
        'wrong-password' ||
        'invalid-credential' =>
          'The email is already registered. Enter the correct password to retry this registration.',
        'network-request-failed' =>
          'Could not connect to Firebase. Check your connection and try again.',
        _ =>
          'Registration failed (${error.code}): ${error.message ?? 'No additional details were provided.'}',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'unavailable' ||
        'deadline-exceeded' =>
          'Could not connect to Firestore. Check your connection and retry using the same email and password.',
        'permission-denied' =>
          'Firestore denied profile creation (${error.code}): ${error.message ?? 'No additional details were provided.'}',
        _ => 'Firestore registration failed (${error.code}): '
            '${error.message ?? 'No additional details were provided.'}',
      };
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Check the registration details.';
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Registration failed: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MathBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1E7D4).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: const Color(0xFF5A3820), width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(51, 30, 15, 0.18),
                        blurRadius: 14,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFB98C52),
                            border: Border.all(
                                color: const Color(0xFF5A3820), width: 3),
                          ),
                          child: const Icon(Icons.person_add,
                              size: 54, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3C2A1C),
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Choose Your Character',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3C2A1C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCharacterOption(
                                id: 'boy',
                                label: 'Boy',
                                asset: Player.boySpriteAssetPath,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCharacterOption(
                                id: 'girl',
                                label: 'Girl',
                                asset: Player.girlSpriteAssetPath,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        CustomTextField(
                          label: 'LRN',
                          hint: 'Enter 12-digit LRN',
                          controller: _lrnController,
                          keyboardType: TextInputType.number,
                          width: double.infinity,
                          validator: (value) =>
                              !RegExp(r'^\d{12}$').hasMatch(value?.trim() ?? '')
                                  ? 'LRN must contain exactly 12 digits.'
                                  : null,
                        ),
                        CustomTextField(
                          label: 'Name',
                          hint: 'Enter your full name',
                          controller: _nameController,
                          width: double.infinity,
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            if (name.isEmpty) return 'Name is required.';
                            if (name.length > 100) {
                              return 'Name must be 100 characters or fewer.';
                            }
                            return null;
                          },
                        ),
                        CustomTextField(
                          label: 'Address',
                          hint: 'Enter your address',
                          controller: _addressController,
                          width: double.infinity,
                          validator: (value) {
                            final address = value?.trim() ?? '';
                            if (address.isEmpty) return 'Address is required.';
                            if (address.length > 300) {
                              return 'Address must be 300 characters or fewer.';
                            }
                            return null;
                          },
                        ),
                        CustomTextField(
                          label: 'Email',
                          hint: 'Enter your email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          width: double.infinity,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Email is required.';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 2, bottom: 8),
                          child: Text(
                            'Please use an email address that you or your parent/guardian can access. This will help you recover your account if you forget your password.',
                            style: TextStyle(
                              color: Color(0xFF5A3820),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        CustomTextField(
                          label: 'Password',
                          hint: 'At least 6 characters',
                          controller: _passwordController,
                          obscure: true,
                          width: double.infinity,
                          validator: (value) => value!.length < 6
                              ? 'Password must be at least 6 characters.'
                              : null,
                        ),
                        CustomTextField(
                          label: 'Confirm Password',
                          hint: 'Re-enter your password',
                          controller: _confirmPasswordController,
                          obscure: true,
                          width: double.infinity,
                          validator: (value) => value!.isEmpty
                              ? 'Please confirm your password.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: _isLoading
                                ? 'Creating Account...'
                                : 'Create Account',
                            onPressed: _isLoading ? null : _register,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Already have an account? Log In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7E4A23),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterOption({
    required String id,
    required String label,
    required String asset,
  }) {
    final isSelected = _selectedCharacter == id;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label character${isSelected ? ', selected' : ''}',
      child: Material(
        color: isSelected ? const Color(0xFFE9CCA1) : const Color(0xFFF8EDDB),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _selectedCharacter = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF7E4A23)
                    : const Color(0xFFC6A36E),
                width: isSelected ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 96,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final frameAspectRatio = id == 'boy' ? 2 / 3 : 1.0;
                      final imageHeight = constraints.maxHeight.clamp(
                        0.0,
                        constraints.maxWidth / frameAspectRatio,
                      );
                      final imageWidth = imageHeight * frameAspectRatio;
                      return Center(
                        child: SizedBox(
                          width: imageWidth,
                          height: imageHeight,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: 0,
                              maxWidth: imageWidth * 6,
                              minHeight: 0,
                              maxHeight: imageHeight * 4,
                              child: Image.asset(
                                asset,
                                width: imageWidth * 6,
                                height: imageHeight * 4,
                                fit: BoxFit.fill,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.broken_image_outlined,
                                  color: Color(0xFF7E4A23),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF3C2A1C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
