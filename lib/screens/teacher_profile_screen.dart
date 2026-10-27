import 'package:flutter/material.dart';

import '../models/user_account.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/math_background.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  late final Future<UserAccount> _accountFuture = _loadTeacherAccount();

  Future<UserAccount> _loadTeacherAccount() async {
    final user = AuthService.currentUser;
    if (user == null) throw StateError('Not signed in.');

    final account = await AuthService.getAccount(user.uid);
    if (account == null ||
        !account.isTeacher ||
        !account.isApproved ||
        account.uid != user.uid) {
      throw StateError('This profile is not an approved teacher account.');
    }
    return account;
  }

  void _returnToDashboard() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MathBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 22),
              const Text(
                'Teacher Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<UserAccount>(
                  future: _accountFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            snapshot.error is StateError
                                ? (snapshot.error! as StateError).message
                                : 'Could not load the teacher profile. Please try again.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }

                    final account = snapshot.requireData;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1E7D4)
                                  .withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFF5A3820),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Color(0xFFD09F5C),
                                  child: Icon(
                                    Icons.school_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  account.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3C2A1C),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _profileField('Email', account.email),
                                _profileField('Role', account.role),
                                _profileField(
                                  'Address',
                                  account.address.isEmpty
                                      ? 'Not provided'
                                      : account.address,
                                ),
                                if (account.lrn.isNotEmpty)
                                  _profileField('LRN', account.lrn),
                                if (account.character.isNotEmpty)
                                  _profileField(
                                    'Character',
                                    account.character,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: CustomButton(
                  text: 'Back to Dashboard',
                  width: 240,
                  onPressed: _returnToDashboard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}
