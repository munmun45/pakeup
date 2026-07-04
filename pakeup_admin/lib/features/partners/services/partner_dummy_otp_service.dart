import 'dart:math';

/// In-memory dummy OTP for admin partner form (until SMS / email API is connected).
class PartnerDummyOtpService {
  PartnerDummyOtpService._();

  static final PartnerDummyOtpService instance = PartnerDummyOtpService._();

  final _sessions = <String, _OtpSession>{};
  final _tokens = <String, _VerifiedToken>{};
  final _random = Random();

  String _sessionKey(String channel, String contact) =>
      '${channel.toLowerCase()}::${contact.trim().toLowerCase()}';

  String _newToken() =>
      'dummy_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(999999)}';

  /// Generates a 6-digit OTP and stores it for verification.
  String send({required String channel, required String contact}) {
    final code = (_random.nextInt(900000) + 100000).toString();
    _sessions[_sessionKey(channel, contact)] = _OtpSession(
      code: code,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    return code;
  }

  /// Returns a verification token when the OTP matches.
  String? verify({
    required String channel,
    required String contact,
    required String otpCode,
  }) {
    final key = _sessionKey(channel, contact);
    final session = _sessions[key];
    if (session == null) return null;
    if (session.expiresAt.isBefore(DateTime.now())) {
      _sessions.remove(key);
      return null;
    }
    if (session.code != otpCode.trim()) return null;

    _sessions.remove(key);
    final token = _newToken();
    _tokens[token] = _VerifiedToken(
      channel: channel,
      contact: contact.trim(),
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    return token;
  }

  bool isTokenValid({
    required String? token,
    required String channel,
    required String contact,
  }) {
    if (token == null) return false;
    final entry = _tokens[token];
    if (entry == null) return false;
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _tokens.remove(token);
      return false;
    }
    return entry.channel == channel &&
        entry.contact.trim().toLowerCase() ==
            contact.trim().toLowerCase();
  }

  void consumeToken(String token) => _tokens.remove(token);
}

class _OtpSession {
  _OtpSession({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

class _VerifiedToken {
  _VerifiedToken({
    required this.channel,
    required this.contact,
    required this.expiresAt,
  });

  final String channel;
  final String contact;
  final DateTime expiresAt;
}
