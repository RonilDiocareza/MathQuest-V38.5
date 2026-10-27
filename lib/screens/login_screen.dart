import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/math_background.dart';
import 'admin_dashboard_screen.dart';
import 'landing_screen.dart';
import 'register_screen.dart';
import 'teacher_analytics_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final inputEmail = _emailController.text.trim().toLowerCase();
      final inputPassword = _passwordController.text.trim();

      try {
        final account = await AuthService.signIn(inputEmail, inputPassword);
        final Widget destination;
        switch (account.role.trim().toLowerCase()) {
          case 'student':
            destination = const LandingScreen(role: 'student');
          case 'teacher':
            destination =
                const TeacherAnalyticsScreen(isTeacherDashboard: true);
          case 'admin':
            destination = const AdminDashboardScreen();
          default:
            await AuthService.signOut();
            throw StateError('Account has no valid role.');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_email', account.email);
        await prefs.setString('current_user_name', account.name);
        await prefs.setString('current_user_role', account.role);
        await prefs.setString('current_user_lrn', account.lrn);
        await prefs.setString('current_user_address', account.address);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => destination),
            (route) => false,
          );
        }
      } catch (error) {
        debugPrint('Unable to sign in: $error');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_loginErrorMessage(error)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _loginErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' =>
          'Email or password is incorrect.',
        'user-disabled' => 'This account is disabled. Please contact support.',
        'too-many-requests' =>
          'Too many attempts. Please wait a moment and try again.',
        'network-request-failed' =>
          'Unable to connect. Check your internet connection and try again.',
        _ => 'Unable to sign in right now. Please try again.',
      };
    }
    if (error is StateError &&
        error.message == 'Account pending admin approval.') {
      return 'Your account is waiting for admin approval.';
    }
    if (error is StateError &&
        error.message.contains('already active on another device')) {
      return 'This account is already active on another device. Sign out there first, or ask an admin to clear its session.';
    }
    if (error is StateError &&
        error.message.contains('session is incomplete')) {
      return 'This account has an incomplete device session. Ask an admin to clear its session.';
    }
    if (error is StateError && error.message == 'Account has no valid role.') {
      return 'This account does not have a valid role. Contact an administrator.';
    }
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'permission-denied' =>
          'This account is already active on another device. Sign out there first, or ask an admin to clear that device session.',
        'failed-precondition' => (error.message?.contains('LRN') ?? false)
            ? 'This LRN is linked to multiple accounts. Please contact an administrator.'
            : 'This account is waiting for admin approval.',
        'not-found' =>
          'Login service is not deployed yet. An administrator must deploy the Firebase Functions and rules.',
        'unavailable' ||
        'deadline-exceeded' =>
          'Could not reach the login service. Check your connection and try again.',
        'internal' => error.message
                    ?.contains('updating Firebase Authentication') ??
                false
            ? 'Firebase could not update the device session. An administrator should check the Cloud Function logs and deploy the latest Functions.'
            : error.message?.contains('checking the account LRN') ?? false
                ? 'Could not verify this account’s LRN. Please try again or contact an administrator.'
                : error.message?.contains('claiming the device session') ??
                        false
                    ? 'Could not reserve this device session. Check your connection and try again.'
                    : 'Could not establish a secure device session. Please try again or contact an administrator.',
        'unauthenticated' =>
          'Your sign-in session expired. Please enter your email and password again.',
        _ =>
          'Login service error (${error.code}). Please contact an administrator.',
      };
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Firebase security rules and login services are out of sync. An administrator must deploy the latest Firestore rules and Functions.';
      }
      if (error.code == 'unavailable' ||
          error.code == 'network-request-failed') {
        return 'Could not connect to Firebase. Check your internet connection and try again.';
      }
    }
    return 'Unable to sign in right now. Please try again.';
  }

  Future<void> _showPasswordRecoveryInstructions() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot Your Password?'),
        content: const Text(
          'Please ask your teacher or school administrator for help resetting your password. A password reset link can be sent to your registered email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MathBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFF8F3E8)),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Container(
                              key: const ValueKey('login-panel'),
                              padding:
                                  const EdgeInsets.fromLTRB(24, 28, 24, 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1E7D4)
                                    .withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                    color: const Color(0xFF5A3820), width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(51, 30, 15, 0.2),
                                    blurRadius: 14,
                                    offset: Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 136,
                                    height: 136,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFB98C52),
                                      border: Border.all(
                                          color: const Color(0xFF5A3820),
                                          width: 3),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/Icon/Icon3.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Login',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF3C2A1C),
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        CustomTextField(
                                          hint: 'Email',
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          width: double.infinity,
                                        ),
                                        const SizedBox(height: 8),
                                        CustomTextField(
                                          hint: 'Password',
                                          controller: _passwordController,
                                          obscure: true,
                                          width: double.infinity,
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed:
                                                _showPasswordRecoveryInstructions,
                                            child: const Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                color: Color(0xFF7E4A23),
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        SizedBox(
                                          width: double.infinity,
                                          child: CustomButton(
                                            text: _isLoading
                                                ? 'Logging In...'
                                                : 'Log In',
                                            onPressed:
                                                _isLoading ? null : _login,
                                          ),
                                        ),
                                        const SizedBox(height: 26),
                                        const Text(
                                          'New User?',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF3C2A1C),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterScreen(),
                                              ),
                                            ),
                                            child: const Text(
                                              'Create Account',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF7E4A23),
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
        ),
      ),
    );
  }
}
