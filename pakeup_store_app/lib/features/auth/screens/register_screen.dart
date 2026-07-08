import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Step 1: Validate form → show OTP sheet
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // Simulate sending OTP (replace with real SMS gateway / Supabase phone auth)
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Show OTP verification sheet
      final verified = await _showOtpSheet(
        phone: _phoneCtrl.text.trim(),
      );

      if (verified == true && mounted) {
        await _register();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Step 2: After OTP verified → create account
  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      await ref.read(authStateProvider.notifier).register(
            PartnerRegisterData(
              businessName: _ownerCtrl.text.trim(),
              ownerName: _ownerCtrl.text.trim(),
              password: _passCtrl.text,
              phone: _phoneCtrl.text.trim(),
            ),
          );
      if (mounted) {
        AppSnackBar.success(
          context,
          'Account created! Complete KYC from your profile.',
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) AppSnackBar.actionFailed(context, 'register', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showOtpSheet({required String phone}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OtpSheet(phone: phone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.surface,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Create your partner account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _ownerCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Your Full Name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) =>
                              v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            prefixText: '+91  ',
                            prefixIcon: Icon(Icons.phone_outlined),
                            helperText: 'OTP will be sent to this number',
                          ),
                          validator: (v) {
                            if (v?.trim().isEmpty == true) return 'Required';
                            if (v!.trim().length != 10) {
                              return 'Enter 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        const _LabelDivider(label: 'Set Password'),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscurePass,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 4
                              ? null
                              : 'Min 4 characters',
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) => v == _passCtrl.text
                              ? null
                              : 'Passwords do not match',
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Already registered?'),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── OTP Bottom Sheet ─────────────────────────────────────────────────────────

class _OtpSheet extends StatefulWidget {
  const _OtpSheet({required this.phone});
  final String phone;

  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  static const _otpLength = 6;
  static const _resendSeconds = 60;

  final List<TextEditingController> _ctrls =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _nodes =
      List.generate(_otpLength, (_) => FocusNode());

  int _countdown = _resendSeconds;
  Timer? _timer;
  bool _verifying = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _resendOtp() {
    for (final c in _ctrls) {
      c.clear();
    }
    setState(() => _errorText = null);
    _nodes[0].requestFocus();
    _startCountdown();
    // TODO: call real OTP resend RPC
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  String _maskedPhone(String phone) {
    if (phone.length == 10) {
      return '+91 ${phone.substring(0, 2)}XXXXXX${phone.substring(8)}';
    }
    return '+91 $phone';
  }

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length < _otpLength) {
      setState(() => _errorText = 'Enter complete 6-digit OTP');
      return;
    }

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      // TODO: replace with real OTP verification RPC
      // For now simulate: accept any 6-digit code
      await Future.delayed(const Duration(milliseconds: 900));

      if (mounted) Navigator.of(context).pop(true); // verified ✓
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Invalid OTP. Please try again.';
          _verifying = false;
        });
        // Shake / clear boxes on failure
        for (final c in _ctrls) {
          c.clear();
        }
        _nodes[0].requestFocus();
      }
    }
  }

  void _onDigitChanged(String value, int index) {
    setState(() => _errorText = null);
    if (value.length == 1 && index < _otpLength - 1) {
      // Advance to next box
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Back to previous box on delete
      _nodes[index - 1].requestFocus();
    }
    // Auto-verify when last digit entered
    if (index == _otpLength - 1 && value.length == 1) {
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Phone icon
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.sms_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Verify Mobile Number',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'We sent a 6-digit OTP to\n'),
                TextSpan(
                  text: _maskedPhone(widget.phone),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_otpLength, (i) {
              return _OtpBox(
                controller: _ctrls[i],
                focusNode: _nodes[i],
                hasError: _errorText != null,
                onChanged: (v) => _onDigitChanged(v, i),
                onBackspace: () {
                  if (_ctrls[i].text.isEmpty && i > 0) {
                    _ctrls[i - 1].clear();
                    _nodes[i - 1].requestFocus();
                  }
                },
              );
            }),
          ),

          // Error text
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _errorText != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Text(
                          _errorText!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 28),

          // Verify button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verify & Create Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Resend / countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Didn't receive OTP? ",
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (_countdown > 0)
                Text(
                  'Resend in ${_countdown}s',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                )
              else
                GestureDetector(
                  onTap: _resendOtp,
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Change number
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Change Number',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single OTP digit box ─────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onBackspace,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    final borderColor = widget.hasError
        ? AppColors.error
        : _focused
            ? AppColors.primary
            : filled
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border;

    return Container(
      width: 46,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: widget.hasError
            ? AppColors.error.withValues(alpha: 0.05)
            : _focused
                ? AppColors.primary.withValues(alpha: 0.05)
                : filled
                    ? AppColors.primary.withValues(alpha: 0.04)
                    : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: _focused || filled ? 2 : 1,
        ),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              widget.controller.text.isEmpty) {
            widget.onBackspace();
          }
        },
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: widget.hasError ? AppColors.error : AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

// ── Label Divider ────────────────────────────────────────────────────────────

class _LabelDivider extends StatelessWidget {
  const _LabelDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
