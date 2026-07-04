import 'dart:io';

import '../models/partner_kyc_models.dart';

class KycDocumentLimits {
  KycDocumentLimits._();

  static const int defaultMaxBytes = 1024 * 1024;
  static const int agreementMaxBytes = 2 * 1024 * 1024;

  static int maxBytesFor(KycDocType type) =>
      type == KycDocType.agreement ? agreementMaxBytes : defaultMaxBytes;

  static String maxSizeLabel(KycDocType type) =>
      type == KycDocType.agreement ? '2 MB' : '1 MB';

  static String uploadHint(KycDocType type) =>
      'PDF, JPG or PNG — max ${maxSizeLabel(type)}';

  static String? validateBytes(int size, KycDocType type) {
    final max = maxBytesFor(type);
    if (size <= max) return null;
    return '${type.label} is too large (${formatSize(size)}). Max ${maxSizeLabel(type)}.';
  }

  static Future<String?> validatePath(String path, KycDocType type) async {
    final file = File(path);
    if (!await file.exists()) return 'File not found';
    return validateBytes(await file.length(), type);
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
