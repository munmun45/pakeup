import 'package:flutter/services.dart';

class FieldValidators {
  FieldValidators._();

  static final phone10Formatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static final _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? phone10(
    String? value, {
    String label = 'Phone',
    bool required = false,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? '$label is required' : null;
    }
    if (trimmed.length != 10 || !RegExp(r'^\d{10}$').hasMatch(trimmed)) {
      return '$label must be exactly 10 digits';
    }
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
