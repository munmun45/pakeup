import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _businessCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _category = 'salon';
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [
      _businessCtrl,
      _ownerCtrl,
      _phoneCtrl,
      _emailCtrl,
      _passCtrl,
      _confirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authStateProvider.notifier).register(
            PartnerRegisterData(
              businessName: _businessCtrl.text,
              ownerName: _ownerCtrl.text,
              password: _passCtrl.text,
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim().isEmpty
                  ? null
                  : _emailCtrl.text.trim(),
              category: _category,
            ),
          );
      if (mounted) {
        AppSnackBar.success(
          context,
          'Registration successful! Complete KYC from admin review.',
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) AppSnackBar.actionFailed(context, 'register', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(partnerCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Register your business',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create your partner account. KYC approval is required before go-live.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    _field(
                      controller: _businessCtrl,
                      label: 'Business Name',
                      icon: Icons.storefront_outlined,
                      required: true,
                    ),
                    _field(
                      controller: _ownerCtrl,
                      label: 'Owner Name',
                      icon: Icons.person_outline,
                      required: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: categoriesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'salon',
                            child: Text('Salon'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _category = v ?? 'salon'),
                      ),
                      data: (items) => DropdownButtonFormField<String>(
                        value: items.any((c) => c.slug == _category)
                            ? _category
                            : items.first.slug,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final item in items)
                            DropdownMenuItem(
                              value: item.slug,
                              child: Text(item.name),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _category = v ?? 'salon'),
                      ),
                    ),
                    ),
                    _field(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      required: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        if (v.trim().length != 10) {
                          return 'Phone must be 10 digits';
                        }
                        return null;
                      },
                    ),
                    _field(
                      controller: _emailCtrl,
                      label: 'Email (optional)',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const Divider(height: 32),
                    _field(
                      controller: _passCtrl,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      required: true,
                      obscure: _obscurePass,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) => v != null && v.length >= 4
                          ? null
                          : 'Min 4 characters',
                    ),
                    _field(
                      controller: _confirmCtrl,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      required: true,
                      obscure: _obscureConfirm,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                      validator: (v) => v?.trim() == _passCtrl.text.trim()
                          ? null
                          : 'Passwords do not match',
                    ),
                    const SizedBox(height: 8),
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
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already registered? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
        ),
        validator: validator ??
            (required
                ? (v) => v?.trim().isEmpty == true ? '$label is required' : null
                : null),
      ),
    );
  }
}
