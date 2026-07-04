import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns exceptions into short, user-readable messages.
String formatAppError(Object error) {
  if (error is PostgrestException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) return msg;
  }

  if (error is AuthException) {
    return error.message;
  }

  final message = error.toString();

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

  if (message.contains('function') && message.contains('does not exist')) {
    return 'Server setup is incomplete. Contact your administrator.';
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
