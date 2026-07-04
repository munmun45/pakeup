import 'package:supabase_flutter/supabase_flutter.dart';

enum PartnerOtpChannel { mobile, whatsapp, email, alternate }

extension PartnerOtpChannelX on PartnerOtpChannel {
  String get rpcValue => switch (this) {
        PartnerOtpChannel.mobile => 'mobile',
        PartnerOtpChannel.whatsapp => 'whatsapp',
        PartnerOtpChannel.email => 'email',
        PartnerOtpChannel.alternate => 'alternate',
      };

  String get label => switch (this) {
        PartnerOtpChannel.mobile => 'Mobile',
        PartnerOtpChannel.whatsapp => 'WhatsApp',
        PartnerOtpChannel.email => 'Email',
        PartnerOtpChannel.alternate => 'Alternate',
      };
}

class SendPartnerOtpResult {
  const SendPartnerOtpResult({
    required this.sent,
    required this.retryAfterSeconds,
    this.debugOtp,
    this.message,
  });

  final bool sent;
  final int retryAfterSeconds;
  final String? debugOtp;
  final String? message;

  factory SendPartnerOtpResult.fromJson(Map<String, dynamic> json) {
    return SendPartnerOtpResult(
      sent: json['sent'] as bool? ?? false,
      retryAfterSeconds: json['retry_after'] as int? ?? 60,
      debugOtp: json['debug_otp'] as String?,
      message: json['message'] as String?,
    );
  }
}

class VerifyPartnerOtpResult {
  const VerifyPartnerOtpResult({
    required this.token,
    required this.phone,
    required this.channel,
  });

  final String token;
  final String phone;
  final String channel;

  factory VerifyPartnerOtpResult.fromJson(Map<String, dynamic> json) {
    return VerifyPartnerOtpResult(
      token: json['token'] as String,
      phone: json['phone'] as String,
      channel: json['channel'] as String,
    );
  }
}

class PartnerOtpRepository {
  PartnerOtpRepository(this._client);

  final SupabaseClient _client;

  Future<SendPartnerOtpResult> sendOtp({
    required String callerId,
    required String phone,
    required PartnerOtpChannel channel,
  }) async {
    final result = await _client.rpc<dynamic>(
      'send_partner_otp',
      params: {
        'caller_id': callerId,
        'phone': phone,
        'channel': channel.rpcValue,
      },
    );
    return SendPartnerOtpResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<VerifyPartnerOtpResult> verifyOtp({
    required String callerId,
    required String phone,
    required PartnerOtpChannel channel,
    required String otpCode,
  }) async {
    final result = await _client.rpc<dynamic>(
      'verify_partner_otp',
      params: {
        'caller_id': callerId,
        'phone': phone,
        'channel': channel.rpcValue,
        'otp_code': otpCode,
      },
    );
    return VerifyPartnerOtpResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}
