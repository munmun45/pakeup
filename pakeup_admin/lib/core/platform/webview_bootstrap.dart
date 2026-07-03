import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart';

Future<void> bootstrapWindowsWebView() async {
  if (kIsWeb || !Platform.isWindows) return;
  try {
    await WebviewController.initializeEnvironment();
  } on Object {
    // Already initialized.
  }
}
