import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EVPasswordField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;

  const EVPasswordField({
    super.key,
    required this.label,
    this.controller,
  });

  @override
  State<EVPasswordField> createState() => _EVPasswordFieldState();
}

class _EVPasswordFieldState extends State<EVPasswordField> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: obscure,

      decoration: InputDecoration(
        labelText: widget.label,

        prefixIcon: const Icon(
          Icons.lock_outline,
          color: AppColors.primary,
        ),

        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () {
            setState(() {
              obscure = !obscure;
            });
          },
        ),

        filled: true,
        fillColor: AppColors.card,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 22,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),

        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}