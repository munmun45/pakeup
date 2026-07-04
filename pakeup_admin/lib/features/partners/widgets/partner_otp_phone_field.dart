import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/field_validators.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partner_otp_repository.dart';
import '../services/partner_dummy_otp_service.dart';
import 'partner_form_field.dart';

enum PartnerOtpInputKind { phone, email }

class PartnerOtpContactField extends ConsumerStatefulWidget {
  const PartnerOtpContactField({
    super.key,
    required this.label,
    required this.icon,
    required this.valueController,
    required this.channel,
    required this.onVerified,
    this.inputKind = PartnerOtpInputKind.phone,
    this.required = true,
    this.initialVerified = false,
    this.initialVerifiedValue,
    this.embedded = false,
  });

  final String label;
  final IconData icon;
  final TextEditingController valueController;
  final PartnerOtpChannel channel;
  final PartnerOtpInputKind inputKind;
  final void Function(String? verificationToken) onVerified;
  final bool required;
  final bool initialVerified;
  final String? initialVerifiedValue;
  final bool embedded;

  @override
  ConsumerState<PartnerOtpContactField> createState() =>
      _PartnerOtpContactFieldState();
}

class _PartnerOtpContactFieldState extends ConsumerState<PartnerOtpContactField> {
  final _otpCtrl = TextEditingController();
  bool _verified = false;
  String? _verifiedValue;
  bool _otpSent = false;
  bool _sending = false;
  bool _verifying = false;
  int _retrySeconds = 0;
  Timer? _retryTimer;
  String? _dummyOtp;

  @override
  void initState() {
    super.initState();
    if (widget.initialVerified && widget.initialVerifiedValue != null) {
      _verified = true;
      _verifiedValue = widget.initialVerifiedValue;
    }
    widget.valueController.addListener(_onValueEdited);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    widget.valueController.removeListener(_onValueEdited);
    _otpCtrl.dispose();
    super.dispose();
  }

  void _onValueEdited() {
    final value = widget.valueController.text.trim();
    if (_verified && value != _verifiedValue) {
      setState(() {
        _verified = false;
        _verifiedValue = null;
        _otpSent = false;
        _dummyOtp = null;
        _otpCtrl.clear();
      });
      _notifyVerified(null);
    }
  }

  void _notifyVerified(String? token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVerified(token);
    });
  }

  String? _validateValue() {
    final value = widget.valueController.text.trim();
    if (widget.inputKind == PartnerOtpInputKind.email) {
      return FieldValidators.email(value);
    }
    return FieldValidators.phone10(
      value,
      label: widget.label,
      required: widget.required,
    );
  }

  void _startRetryTimer(int seconds) {
    _retryTimer?.cancel();
    setState(() => _retrySeconds = seconds);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_retrySeconds <= 1) {
        timer.cancel();
        setState(() => _retrySeconds = 0);
      } else {
        setState(() => _retrySeconds -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    final value = widget.valueController.text.trim();
    final error = _validateValue();
    if (error != null) {
      AppSnackBar.warning(context, error);
      return;
    }

    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final code = PartnerDummyOtpService.instance.send(
      channel: widget.channel.rpcValue,
      contact: value,
    );

    if (!mounted) return;
    setState(() {
      _otpSent = true;
      _dummyOtp = code;
      _otpCtrl.text = code;
    });
    _startRetryTimer(60);
    setState(() => _sending = false);

    AppSnackBar.success(
      context,
      'Dummy OTP generated for ${widget.channel.label}',
    );
  }

  Future<void> _verifyOtp() async {
    final value = widget.valueController.text.trim();
    final otp = _otpCtrl.text.trim();

    if (otp.length != 6) {
      AppSnackBar.warning(context, 'Enter the 6-digit OTP');
      return;
    }

    setState(() => _verifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final token = PartnerDummyOtpService.instance.verify(
      channel: widget.channel.rpcValue,
      contact: value,
      otpCode: otp,
    );

    if (!mounted) return;
    setState(() => _verifying = false);

    if (token == null) {
      AppSnackBar.error(context, 'Invalid OTP — use the code shown above');
      return;
    }

    setState(() {
      _verified = true;
      _verifiedValue = value;
      _dummyOtp = null;
    });
    _notifyVerified(token);
    AppSnackBar.success(context, '${widget.channel.label} verified');
  }

  Color get _accent => switch (widget.channel) {
        PartnerOtpChannel.mobile => AppColors.primary,
        PartnerOtpChannel.whatsapp => const Color(0xFF25D366),
        PartnerOtpChannel.email => AppColors.secondary,
        PartnerOtpChannel.alternate => const Color(0xFF0288D1),
      };

  @override
  Widget build(BuildContext context) {
    final fieldBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PartnerFieldLabel(
                icon: widget.icon,
                label: widget.label,
                required: widget.required,
              ),
            ),
            if (_verified) _verifiedBadge(),
          ],
        ),
        const SizedBox(height: 8),
        _contactRow(),
        if (_otpSent && !_verified) ...[
          const SizedBox(height: 12),
          if (_dummyOtp != null)
            _DummyOtpBanner(
              otp: _dummyOtp!,
              channelLabel: widget.channel.label,
              onAutoFill: () => setState(() => _otpCtrl.text = _dummyOtp!),
            ),
          const SizedBox(height: 10),
          _otpRow(),
        ],
      ],
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: fieldBody,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _verified
                ? AppColors.success.withValues(alpha: 0.45)
                : AppColors.border,
          ),
          color: _verified
              ? AppColors.success.withValues(alpha: 0.04)
              : AppColors.background.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: fieldBody,
      ),
    );
  }

  Widget _verifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow() {
    final fieldHeight = widget.embedded ? 44.0 : 48.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: widget.valueController,
            keyboardType: widget.inputKind == PartnerOtpInputKind.email
                ? TextInputType.emailAddress
                : TextInputType.phone,
            readOnly: false,
            inputFormatters: widget.inputKind == PartnerOtpInputKind.phone
                ? FieldValidators.phone10Formatters
                : null,
            style: const TextStyle(fontSize: 14, height: 1.35),
            decoration: PartnerFormField.fieldDecoration(
              hint: widget.inputKind == PartnerOtpInputKind.email
                  ? 'name@example.com'
                  : '10 digit number',
              compact: widget.embedded,
            ).copyWith(
              prefixText: widget.inputKind == PartnerOtpInputKind.phone
                  ? '+91 '
                  : null,
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            validator: (_) => _validateValue(),
          ),
        ),
        const SizedBox(width: 8),
        if (!_verified)
          SizedBox(
            height: fieldHeight,
            child: FilledButton(
              onPressed: (_sending || _retrySeconds > 0) ? null : _sendOtp,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _accent.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _otpSent
                          ? (_retrySeconds > 0 ? '${_retrySeconds}s' : 'Resend')
                          : 'Send OTP',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _otpRow() {
    final fieldHeight = widget.embedded ? 44.0 : 48.0;
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            decoration: PartnerFormField.fieldDecoration(
              hint: '• • • • • •',
              compact: widget.embedded,
            ).copyWith(
              counterText: '',
              hintStyle: TextStyle(
                letterSpacing: 4,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            onFieldSubmitted: (_) => _verifyOtp(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: fieldHeight,
          child: FilledButton.icon(
            onPressed: _verifying ? null : _verifyOtp,
            icon: _verifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Verify'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DummyOtpBanner extends StatelessWidget {
  const _DummyOtpBanner({
    required this.otp,
    required this.channelLabel,
    required this.onAutoFill,
  });

  final String otp;
  final String channelLabel;
  final VoidCallback onAutoFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sms_outlined,
                  size: 18, color: AppColors.secondary.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text(
                'Dummy OTP for $channelLabel',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            otp,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 14,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter this code below and tap Verify',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class PartnerVerificationProgress extends StatelessWidget {
  const PartnerVerificationProgress({
    super.key,
    required this.phoneVerified,
    required this.whatsappVerified,
    required this.emailVerified,
    required this.alternateVerified,
    this.alternateRequired = false,
  });

  final bool phoneVerified;
  final bool whatsappVerified;
  final bool emailVerified;
  final bool alternateVerified;
  final bool alternateRequired;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData('Mobile', Icons.phone_android_rounded, phoneVerified,
          AppColors.primary),
      _StepData('WhatsApp', Icons.chat_rounded, whatsappVerified,
          const Color(0xFF25D366)),
      _StepData('Email', Icons.email_rounded, emailVerified, AppColors.secondary),
      if (alternateRequired)
        _StepData('Alt', Icons.phone_callback_rounded, alternateVerified,
            const Color(0xFF0288D1)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) _connector(steps[i - 1].done),
            _StepChip(
              label: steps[i].label,
              icon: steps[i].icon,
              done: steps[i].done,
              color: steps[i].color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _connector(bool active) {
    return SizedBox(
      width: 28,
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: active ? AppColors.success : AppColors.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _StepData {
  const _StepData(this.label, this.icon, this.done, this.color);

  final String label;
  final IconData icon;
  final bool done;
  final Color color;
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.icon,
    required this.done,
    required this.color,
  });

  final String label;
  final IconData icon;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final chipColor = done ? AppColors.success : color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: done ? 0.15 : 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: chipColor.withValues(alpha: done ? 0.5 : 0.35),
                width: done ? 2 : 1,
              ),
            ),
            child: Icon(
              done ? Icons.check_rounded : icon,
              size: 17,
              color: chipColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: done ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Backward-compatible alias
typedef PartnerOtpPhoneField = PartnerOtpContactField;
