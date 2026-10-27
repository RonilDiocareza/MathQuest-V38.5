import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/math_background.dart';

class ForgotPassword extends StatelessWidget {
  const ForgotPassword({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MathBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Text(
              'Forgot Password',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const CustomTextField(hint: 'Enter your email'),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Send Reset Link',
              onPressed: () {},
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
