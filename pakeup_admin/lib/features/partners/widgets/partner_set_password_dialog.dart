import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'partner_form_field.dart';

class PartnerSetPasswordResult {
  const PartnerSetPasswordResult({
    required this.loginId,
    required this.password,
  });

  final String loginId;
  final String password;
}

class PartnerSetPasswordDialog extends StatefulWidget {
  const PartnerSetPasswordDialog({
    super.key,
    required this.businessName,
    required this.initialLoginId,
    this.hasPassword = false,
  });

  final String businessName;
  final String initialLoginId;
  final bool hasPassword;

  @override
  State<PartnerSetPasswordDialog> createState() =>
      _PartnerSetPasswordDialogState();
}

class _PartnerSetPasswordDialogState extends State<PartnerSetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _loginCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _confirmCtrl;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loginCtrl = TextEditingController(text: widget.initialLoginId);
    _passCtrl = TextEditingController();
    _confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.14),
                        AppColors.surface,
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.hasPassword
                                  ? 'Update Password'
                                  : 'Set Password',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              widget.businessName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                ColoredBox(
                  color: AppColors.background.withValues(alpha: 0.45),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PartnerFormField(
                              label: 'Login ID',
                              icon: Icons.person_outline,
                              controller: _loginCtrl,
                              required: true,
                              hint: 'Partner login username',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Login ID is required';
                                }
                                return null;
                              },
                            ),
                            PartnerFormField(
                              label: 'Password',
                              icon: Icons.lock_outline,
                              controller: _passCtrl,
                              required: true,
                              hint: 'Min 4 characters',
                              obscureText: _obscurePass,
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscurePass = !_obscurePass),
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().length < 4) {
                                  return 'Password must be at least 4 characters';
                                }
                                return null;
                              },
                            ),
                            PartnerFormField(
                              label: 'Confirm Password',
                              icon: Icons.lock_outline,
                              controller: _confirmCtrl,
                              required: true,
                              obscureText: _obscureConfirm,
                              suffix: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                              ),
                              validator: (v) {
                                if (v?.trim() != _passCtrl.text.trim()) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.pop(
                            context,
                            PartnerSetPasswordResult(
                              loginId: _loginCtrl.text.trim(),
                              password: _passCtrl.text.trim(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          widget.hasPassword ? 'Update Password' : 'Set Password',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
