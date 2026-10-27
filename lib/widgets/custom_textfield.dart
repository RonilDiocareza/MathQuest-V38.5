import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final String hint;
  final String? label;
  final bool obscure;
  final bool enabled;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final double height;
  final double? width;
  final Color? textColor;
  final Color? hintColor;

  const CustomTextField({
    required this.hint,
    this.label,
    this.obscure = false,
    this.enabled = true,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.height = 54.0,
    this.width = 200.0,
    this.textColor,
    this.hintColor,
    super.key,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: TextFormField(
          enabled: widget.enabled,
          controller: _controller,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          style: TextStyle(
            color: widget.textColor ?? const Color(0xFF3D2A1B),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: widget.hintColor ?? const Color(0xFF7C5B3A),
              fontWeight: FontWeight.w600,
            ),
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: widget.hintColor ?? const Color(0xFF7C5B3A),
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F3E8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF7A5634), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF7A5634), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFB36B1F), width: 2.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }
}
