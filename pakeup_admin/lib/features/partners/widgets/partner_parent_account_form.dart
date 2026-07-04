import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partner_otp_repository.dart';
import '../data/partners_repository.dart';
import '../providers/partners_provider.dart';
import '../utils/partner_account_defaults.dart';
import 'partner_form_field.dart';
import 'partner_otp_phone_field.dart';
import 'partner_parent_account_form_ui.dart';

class PartnerParentAccountForm extends ConsumerStatefulWidget {
  const PartnerParentAccountForm({
    super.key,
    this.existing,
    this.formUi,
    this.onCreated,
    this.showFooter = false,
    this.onCancel,
  });

  final PartnerOwnerAccount? existing;
  final PartnerParentAccountFormUi? formUi;
  final VoidCallback? onCreated;
  final bool showFooter;
  final VoidCallback? onCancel;

  bool get isEdit => existing != null;

  @override
  ConsumerState<PartnerParentAccountForm> createState() =>
      _PartnerParentAccountFormState();
}

class _PartnerParentAccountFormState
    extends ConsumerState<PartnerParentAccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _alternatePhoneCtrl;
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _changePassword = false;
  String? _lastSyncedPhone;

  late bool _phoneVerified;
  late bool _whatsappVerified;
  late bool _emailVerified;
  late bool _alternateVerified;

  bool get _hasAlternate => _alternatePhoneCtrl.text.trim().isNotEmpty;

  bool get _needsPhoneOtp =>
      !widget.isEdit ||
      _phoneCtrl.text.trim() != (widget.existing?.phone ?? '');

  bool get _needsWhatsappOtp =>
      !widget.isEdit ||
      _whatsappCtrl.text.trim() != (widget.existing?.whatsapp ?? '');

  bool get _needsEmailOtp =>
      !widget.isEdit ||
      _emailCtrl.text.trim() != (widget.existing?.email ?? '');

  bool get _needsAlternateOtp {
    if (!_hasAlternate) return false;
    return !widget.isEdit ||
        _alternatePhoneCtrl.text.trim() !=
            (widget.existing?.alternatePhone ?? '');
  }

  bool get _passwordRequired =>
      !widget.isEdit || !widget.existing!.hasPassword || _changePassword;

  bool get _showVerificationBanner =>
      !widget.isEdit ||
      _needsPhoneOtp ||
      _needsWhatsappOtp ||
      _needsEmailOtp ||
      _needsAlternateOtp;

  bool get _canSubmit {
    if (_needsPhoneOtp && !_phoneVerified) return false;
    if (_needsWhatsappOtp && !_whatsappVerified) return false;
    if (_needsEmailOtp && !_emailVerified) return false;
    if (_needsAlternateOtp && !_alternateVerified) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    widget.formUi?.submit = _submit;
    _syncFormUi();
    final e = widget.existing;
    final useDefaults = !widget.isEdit;
    _ownerCtrl = TextEditingController(
      text:
          e?.ownerName ?? (useDefaults ? PartnerAccountDefaults.ownerName : ''),
    );
    _phoneCtrl = TextEditingController(
      text: e?.phone ?? (useDefaults ? PartnerAccountDefaults.phone : ''),
    );
    _emailCtrl = TextEditingController(
      text: e?.email ?? (useDefaults ? PartnerAccountDefaults.email : ''),
    );
    _whatsappCtrl = TextEditingController(
      text: e?.whatsapp ?? (useDefaults ? PartnerAccountDefaults.whatsapp : ''),
    );
    _alternatePhoneCtrl = TextEditingController(
      text:
          e?.alternatePhone ??
          (useDefaults ? PartnerAccountDefaults.alternatePhone : ''),
    );
    if (useDefaults) {
      _passCtrl.text = PartnerAccountDefaults.password;
      _confirmPassCtrl.text = PartnerAccountDefaults.password;
      _lastSyncedPhone = PartnerAccountDefaults.phone;
    }
    _phoneVerified = widget.isEdit;
    _whatsappVerified = widget.isEdit;
    _emailVerified = widget.isEdit;
    _alternateVerified =
        widget.isEdit || (e?.alternatePhone?.trim().isNotEmpty != true);
    _alternatePhoneCtrl.addListener(_onAlternateChanged);
    if (!widget.isEdit) {
      _phoneCtrl.addListener(_syncWhatsappFromPhone);
    }
  }

  @override
  void didUpdateWidget(covariant PartnerParentAccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formUi != widget.formUi) {
      oldWidget.formUi?.submit = null;
      widget.formUi?.submit = _submit;
    }
    _syncFormUi();
  }

  void _syncFormUi() {
    final ui = widget.formUi;
    if (ui == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ui.update(canSubmit: _canSubmit, isSubmitting: _submitting);
    });
  }

  void _onAlternateChanged() {
    if (_alternatePhoneCtrl.text.trim().isEmpty) {
      setState(() => _alternateVerified = true);
    } else {
      setState(() {});
    }
    _syncFormUi();
  }

  void _syncWhatsappFromPhone() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    final whatsapp = _whatsappCtrl.text.trim();
    final linkedToPhone =
        whatsapp.isEmpty ||
        _lastSyncedPhone == null ||
        whatsapp == _lastSyncedPhone;

    if (!linkedToPhone || whatsapp == phone) {
      _lastSyncedPhone = phone;
      return;
    }

    _whatsappCtrl.text = phone;
    _lastSyncedPhone = phone;
    if (_whatsappVerified) {
      setState(() => _whatsappVerified = false);
    }
    _syncFormUi();
  }

  @override
  void dispose() {
    widget.formUi?.submit = null;
    if (!widget.isEdit) {
      _phoneCtrl.removeListener(_syncWhatsappFromPhone);
    }
    _alternatePhoneCtrl.removeListener(_onAlternateChanged);
    for (final c in [
      _ownerCtrl,
      _phoneCtrl,
      _emailCtrl,
      _whatsappCtrl,
      _alternatePhoneCtrl,
      _passCtrl,
      _confirmPassCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    if (widget.isEdit) return;
    for (final c in [
      _ownerCtrl,
      _phoneCtrl,
      _emailCtrl,
      _whatsappCtrl,
      _alternatePhoneCtrl,
      _passCtrl,
      _confirmPassCtrl,
    ]) {
      c.clear();
    }
    setState(() {
      _phoneVerified = false;
      _whatsappVerified = false;
      _emailVerified = false;
      _alternateVerified = true;
    });
    _syncFormUi();
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    if (!_canSubmit) {
      AppSnackBar.warning(
        context,
        'Verify Mobile, WhatsApp & Email'
        '${_needsAlternateOtp ? ' (and Alternate phone)' : ''} before continuing',
      );
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.error(context, 'Please sign in again');
      return;
    }

    final data = PartnerAccountFormData(
      ownerName: _ownerCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      alternatePhone: _emptyToNull(_alternatePhoneCtrl.text),
      password: _passwordRequired ? _passCtrl.text.trim() : null,
    );

    setState(() => _submitting = true);
    _syncFormUi();
    try {
      final repo = ref.read(partnersRepositoryProvider);
      if (widget.isEdit) {
        await repo.updatePartnerAccount(
          callerId: user.id,
          accountId: widget.existing!.id,
          data: data,
        );
      } else {
        await repo.createPartnerAccount(callerId: user.id, data: data);
      }
      if (!mounted) return;
      AppSnackBar.success(
        context,
        widget.isEdit
            ? 'Partner "${_ownerCtrl.text.trim()}" updated'
            : 'Partner account created for "${_ownerCtrl.text.trim()}"',
      );
      ref.invalidate(partnerOwnerAccountsListProvider);
      widget.onCreated?.call();
      _resetForm();
    } catch (e) {
      if (mounted) {
        AppSnackBar.actionFailed(
          context,
          widget.isEdit ? 'update partner account' : 'create partner account',
          e,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        _syncFormUi();
      }
    }
  }

  void _onVerified(VoidCallback update) {
    setState(update);
    _syncFormUi();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final fields = wide ? _wideLayout() : _narrowLayout();

          if (!widget.showFooter) return fields;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [fields, const SizedBox(height: 8), _inlineFooter()],
          );
        },
      ),
    );
  }

  Widget _wideLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showVerificationBanner) ...[
          _verificationBanner(),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ownerSection()),
            const SizedBox(width: 16),
            Expanded(child: _loginSecuritySection()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _mobileWhatsappSection()),
            const SizedBox(width: 16),
            Expanded(child: _emailAlternateSection()),
          ],
        ),
      ],
    );
  }

  Widget _narrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showVerificationBanner) ...[
          _verificationBanner(),
          const SizedBox(height: 16),
        ],
        _ownerSection(),
        _loginSecuritySection(),
        _mobileWhatsappSection(),
        _emailAlternateSection(),
      ],
    );
  }

  Widget _inlineFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onCancel != null)
          TextButton(
            onPressed: _submitting ? null : widget.onCancel,
            child: const Text('Cancel'),
          ),
        if (widget.onCancel != null) const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: (_submitting || !_canSubmit) ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  widget.isEdit
                      ? Icons.save_outlined
                      : Icons.person_add_alt_1_rounded,
                ),
          label: Text(
            _submitting
                ? (widget.isEdit ? 'Saving...' : 'Creating...')
                : (widget.isEdit ? 'Save Partner' : 'Create Partner'),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _verificationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PartnerVerificationProgress(
            phoneVerified: _phoneVerified,
            whatsappVerified: _whatsappVerified,
            emailVerified: _emailVerified,
            alternateVerified: _alternateVerified,
            alternateRequired: _hasAlternate,
          ),
          if (!_canSubmit) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.warning.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Send OTP on each contact field, enter the dummy code, then Verify.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ownerSection() {
    return PartnerFormSection(
      title: 'Owner Information',
      icon: Icons.person_outline_rounded,
      children: [
        PartnerFormField(
          label: 'Owner Name',
          icon: Icons.badge_outlined,
          controller: _ownerCtrl,
          required: true,
          hint: 'Full name of the partner / business owner',
        ),
      ],
    );
  }

  Widget _loginSecuritySection() {
    return PartnerFormSection(
      title: 'Login Security',
      icon: Icons.shield_outlined,
      children: [
        if (widget.isEdit && widget.existing!.hasPassword)
          _compactPasswordToggle(),
        if (_passwordRequired)
          PartnerFormRow(
            children: [
              PartnerFormField(
                label: widget.isEdit && widget.existing!.hasPassword
                    ? 'New Password'
                    : 'Password',
                icon: Icons.lock_outline,
                controller: _passCtrl,
                obscureText: _obscurePass,
                required: true,
                compact: true,
                hint: 'Min 4 characters',
                suffix: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return widget.isEdit && !widget.existing!.hasPassword
                        ? 'Required'
                        : 'Required';
                  }
                  return v.trim().length >= 4 ? null : 'Min 4 chars';
                },
              ),
              PartnerFormField(
                label: 'Confirm',
                icon: Icons.lock_outline,
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                required: true,
                compact: true,
                hint: 'Re-enter password',
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return v.trim() == _passCtrl.text.trim() ? null : 'No match';
                },
              ),
            ],
          )
        else if (!widget.isEdit)
          PartnerFormRow(
            children: [
              PartnerFormField(
                label: 'Password (optional)',
                icon: Icons.lock_outline,
                controller: _passCtrl,
                obscureText: _obscurePass,
                compact: true,
                hint: 'Min 4 characters',
                suffix: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return v.trim().length >= 4 ? null : 'Min 4 chars';
                },
              ),
              PartnerFormField(
                label: 'Confirm',
                icon: Icons.lock_outline,
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                compact: true,
                hint: 'Re-enter password',
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (v) {
                  if (_passCtrl.text.trim().isEmpty) return null;
                  return v?.trim() == _passCtrl.text.trim() ? null : 'No match';
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _compactPasswordToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: _changePassword
                ? AppColors.primary
                : AppColors.success.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _changePassword ? 'Enter new password below' : 'Password is set',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
          Text(
            'Change',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: _changePassword,
              onChanged: _submitting
                  ? null
                  : (value) {
                      setState(() {
                        _changePassword = value;
                        if (!value) {
                          _passCtrl.clear();
                          _confirmPassCtrl.clear();
                        }
                      });
                      _syncFormUi();
                    },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileWhatsappSection() {
    return PartnerFormSection(
      title: 'Mobile & WhatsApp',
      icon: Icons.verified_user_outlined,
      children: [
        PartnerOtpContactField(
          label: 'Phone (Login ID)',
          icon: Icons.phone_android_rounded,
          valueController: _phoneCtrl,
          channel: PartnerOtpChannel.mobile,
          embedded: true,
          initialVerified: widget.isEdit,
          initialVerifiedValue: widget.existing?.phone,
          onVerified: (token) {
            _onVerified(() => _phoneVerified = token != null);
          },
        ),
        PartnerOtpContactField(
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          valueController: _whatsappCtrl,
          channel: PartnerOtpChannel.whatsapp,
          embedded: true,
          initialVerified: widget.isEdit,
          initialVerifiedValue: widget.existing?.whatsapp,
          onVerified: (token) {
            _onVerified(() => _whatsappVerified = token != null);
          },
        ),
      ],
    );
  }

  Widget _emailAlternateSection() {
    return PartnerFormSection(
      title: 'Email & Alternate',
      icon: Icons.contact_mail_outlined,
      children: [
        PartnerOtpContactField(
          label: 'Email',
          icon: Icons.email_outlined,
          valueController: _emailCtrl,
          channel: PartnerOtpChannel.email,
          inputKind: PartnerOtpInputKind.email,
          embedded: true,
          initialVerified: widget.isEdit,
          initialVerifiedValue: widget.existing?.email,
          onVerified: (token) {
            _onVerified(() => _emailVerified = token != null);
          },
        ),
        PartnerOtpContactField(
          label: 'Alternate Phone',
          icon: Icons.phone_callback_outlined,
          valueController: _alternatePhoneCtrl,
          channel: PartnerOtpChannel.alternate,
          embedded: true,
          required: false,
          initialVerified:
              widget.isEdit &&
              widget.existing?.alternatePhone?.trim().isNotEmpty == true,
          initialVerifiedValue: widget.existing?.alternatePhone,
          onVerified: (token) {
            _onVerified(() {
              _alternateVerified = token != null || !_hasAlternate;
            });
          },
        ),
      ],
    );
  }
}
