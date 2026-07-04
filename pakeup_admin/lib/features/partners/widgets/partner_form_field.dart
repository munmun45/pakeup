import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Label + icon above the input — avoids broken prefix icons on multiline fields.
class PartnerFieldLabel extends StatelessWidget {
  const PartnerFieldLabel({
    super.key,
    required this.icon,
    required this.label,
    this.required = false,
  });

  final IconData icon;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class PartnerFormField extends StatelessWidget {
  const PartnerFormField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.required = false,
    this.keyboard,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.onChanged,
    this.validator,
    this.compact = false,
    this.obscureText = false,
    this.readOnly = false,
    this.suffix,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool compact;
  final bool obscureText;
  final bool readOnly;
  final Widget? suffix;

  static InputDecoration fieldDecoration({String? hint, bool compact = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.65),
        fontSize: compact ? 13 : 14,
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PartnerFieldLabel(icon: icon, label: label, required: required),
          SizedBox(height: compact ? 5 : 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboard,
            obscureText: obscureText,
            readOnly: readOnly,
            maxLines: maxLines,
            minLines: minLines ?? (maxLines > 1 ? maxLines : 1),
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: TextStyle(fontSize: compact ? 13 : 14, height: 1.35),
            decoration: fieldDecoration(hint: hint, compact: compact).copyWith(
              suffixIcon: suffix,
            ),
            validator: validator ??
                (required
                    ? (v) =>
                        v?.trim().isEmpty == true ? '$label is required' : null
                    : null),
          ),
        ],
      ),
    );
  }
}

class PartnerFormDropdown<T> extends StatelessWidget {
  const PartnerFormDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PartnerFieldLabel(icon: icon, label: label),
          const SizedBox(height: 8),
          DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: PartnerFormField.fieldDecoration(),
            borderRadius: BorderRadius.circular(10),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }
}

class PartnerFormSection extends StatelessWidget {
  const PartnerFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class PartnerFormRow extends StatelessWidget {
  const PartnerFormRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
