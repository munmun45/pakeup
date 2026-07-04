String friendlyErrorMessage(Object error) {
  final text = error.toString();
  if (text.contains('Phone number already registered')) {
    return 'This phone number is already registered.';
  }
  if (text.contains('Login ID already in use')) {
    return 'This phone number is already registered.';
  }
  if (text.contains('Password must be at least')) {
    return 'Password must be at least 4 characters.';
  }
  if (text.contains('Business name and owner name')) {
    return 'Business name and owner name are required.';
  }
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup')) {
    return 'No internet connection. Check your network and try again.';
  }
  final match = RegExp(r'(?:Exception|Error):\s*(.+)$').firstMatch(text);
  return match?.group(1)?.trim() ?? text.replaceFirst('Exception: ', '');
}
