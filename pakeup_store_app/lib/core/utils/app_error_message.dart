import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyErrorMessage(Object error) => formatAppError(error);

String formatAppError(Object error) {
  if (error is PostgrestException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) return msg;
  }

  if (error is AuthException) {
    return error.message;
  }

  final message = error.toString();

  if (message.contains('Phone number already registered')) {
    return 'This phone number is already registered.';
  }
  if (message.contains('Login ID already in use')) {
    return 'This phone number is already registered.';
  }
  if (message.contains('Password must be at least')) {
    return 'Password must be at least 4 characters.';
  }
  if (message.contains('Business name and owner name')) {
    return 'Business name and owner name are required.';
  }

  final postgrestMatch = RegExp(r'message:\s*([^,}]+)').firstMatch(message);
  if (postgrestMatch != null) {
    return postgrestMatch.group(1)!.trim();
  }

  if (message.contains('SocketException') ||
      message.contains('Failed host lookup') ||
      message.contains('NetworkException')) {
    return 'No internet connection. Check your network and try again.';
  }

  if (message.contains('Access denied')) {
    return 'Access denied. You may not have permission for this action.';
  }

  return message
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException:\s*'), '')
      .replaceFirst(RegExp(r'^AuthException:\s*'), '')
      .trim();
}

String couldNotMessage(String action, Object error) {
  return 'Could not $action. ${formatAppError(error)}';
}
