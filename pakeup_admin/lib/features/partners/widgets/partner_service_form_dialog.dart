import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partners_repository.dart';
import '../models/partner_service_models.dart';
import '../providers/partner_services_provider.dart';
import '../providers/partners_provider.dart';
import 'partner_form_field.dart';

class PartnerServiceFormDialog extends ConsumerStatefulWidget {
  const PartnerServiceFormDialog({super.key, this.existing});

  final PartnerServiceRecord? existing;

  @override
  ConsumerState<PartnerServiceFormDialog> createState() =>
      _PartnerServiceFormDialogState();
}

class _PartnerServiceFormDialogState
    extends ConsumerState<PartnerServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  String? _partnerId;
  bool _isActive = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(
      text: e != null ? e.price.toStringAsFixed(0) : '',
    );
    _durationCtrl = TextEditingController(
      text: e?.durationMinutes.toString() ?? '30',
    );
    _partnerId = e?.partnerId;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(List<PartnerRecord> partners) async {
    if (!_formKey.currentState!.validate()) return;

    final partnerId = _partnerId ?? partners.first.id;
    if (partnerId.isEmpty) {
      AppSnackBar.error(context, 'Please select a partner');
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 30;

    final data = PartnerServiceFormData(
      partnerId: partnerId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      price: price,
      durationMinutes: duration,
      isActive: _isActive,
    );

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnerServicesRepositoryProvider);
      if (widget.existing == null) {
        await repo.createService(callerId: user.id, data: data);
      } else {
        await repo.updateService(
          callerId: user.id,
          serviceId: widget.existing!.id,
          data: data,
        );
      }
      if (mounted) {
        AppSnackBar.success(
          context,
          widget.existing == null
              ? 'Service "${data.name}" added successfully'
              : 'Service "${data.name}" updated successfully',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.actionFailed(
          context,
          widget.existing == null ? 'add service' : 'update service',
          e,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnersListProvider);
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.spa_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Service' : 'Add Service',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                partnersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(e.toString()),
                  data: (partners) {
                    if (partners.isEmpty) {
                      return const Text(
                        'Add a partner first before creating services.',
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PartnerFormDropdown<String>(
                          label: 'Partner',
                          icon: Icons.storefront_outlined,
                          value: _partnerId ?? partners.first.id,
                          items: partners
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.businessName),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _partnerId = v),
                        ),
                        PartnerFormField(
                          label: 'Service Name',
                          icon: Icons.label_outline,
                          controller: _nameCtrl,
                          required: true,
                        ),
                        PartnerFormField(
                          label: 'Description',
                          icon: Icons.notes_outlined,
                          controller: _descCtrl,
                          maxLines: 2,
                          minLines: 1,
                          hint: 'Optional service details...',
                        ),
                        PartnerFormRow(
                          children: [
                            PartnerFormField(
                              label: 'Price (₹)',
                              icon: Icons.currency_rupee,
                              controller: _priceCtrl,
                              required: true,
                              keyboard: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                            ),
                            PartnerFormField(
                              label: 'Duration (min)',
                              icon: Icons.timer_outlined,
                              controller: _durationCtrl,
                              required: true,
                              keyboard: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ],
                        ),
                        if (isEdit)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active'),
                            subtitle: const Text(
                              'Inactive services are hidden from listings',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _submit(partners),
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isEdit ? Icons.save_outlined : Icons.add,
                                      size: 18,
                                    ),
                              label: Text(isEdit ? 'Save' : 'Add Service'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
