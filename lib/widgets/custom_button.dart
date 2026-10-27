import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final Color? textColor;

  const CustomButton({
    required this.text,
    this.onPressed,
    this.width,
    this.textColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = width ?? 200;

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? const Color(0xFFB28B57) : const Color(0xFF8A5C2E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF5A3820), width: 2),
          ),
          elevation: onPressed == null ? 0 : 6,
          shadowColor: const Color.fromRGBO(60, 35, 18, 0.35),
          minimumSize: Size(buttonWidth, 54),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.6,
            color: textColor ??
                (onPressed == null
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white),
          ),
        ),
      ),
    );
  }
}
