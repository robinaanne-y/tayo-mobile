import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.errorText,
    this.autofillHints,
    this.enabled = true,
    this.hint,
    this.suffixIcon,
    this.labelAbove = false,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final String? hint;
  final Widget? suffixIcon;

  /// Shows [label] as a bold caption above a rounded, pill-shaped field
  /// (with [hint] as the placeholder) instead of the default floating label.
  final bool labelAbove;

  @override
  Widget build(BuildContext context) {
    if (!labelAbove) {
      return TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        autofillHints: autofillHints,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          suffixIcon: suffixIcon,
        ),
      );
    }

    OutlineInputBorder pill(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          autofillHints: autofillHints,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.colors.textDisabled),
            errorText: errorText,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: pill(context.colors.border),
            enabledBorder: pill(context.colors.border),
            focusedBorder: pill(context.colors.primary, 1.5),
            errorBorder: pill(context.colors.error),
            focusedErrorBorder: pill(context.colors.error, 1.5),
          ),
        ),
      ],
    );
  }
}
