import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  late final TextEditingController _discountPriceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _prepCtrl;
  
  String? _partnerId;
  String _category = 'Others';
  String _targetGender = 'Unisex';
  String _serviceLocation = 'At Salon Only';
  String? _serviceImageUrl;
  String? _localImagePath;
  bool _isFeatured = false;
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
    _discountPriceCtrl = TextEditingController(
      text: e?.discountPrice != null ? e!.discountPrice!.toStringAsFixed(0) : '',
    );
    _durationCtrl = TextEditingController(
      text: e?.durationMinutes.toString() ?? '30',
    );
    _prepCtrl = TextEditingController(text: e?.prepInstructions ?? '');
    _partnerId = e?.partnerId;
    _category = e?.category ?? 'Others';
    _targetGender = e?.targetGender ?? 'Unisex';
    _serviceLocation = e?.serviceLocation ?? 'At Salon Only';
    _serviceImageUrl = e?.serviceImage;
    _isFeatured = e?.isFeatured ?? false;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _discountPriceCtrl.dispose();
    _durationCtrl.dispose();
    _prepCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          setState(() {
            _localImagePath = path;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to pick image: $e');
      }
    }
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
    final discountPriceText = _discountPriceCtrl.text.trim();
    final discountPrice = discountPriceText.isNotEmpty
        ? double.tryParse(discountPriceText)
        : null;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 30;

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnerServicesRepositoryProvider);
      
      String? finalServiceImageUrl = _serviceImageUrl;
      if (_localImagePath != null) {
        finalServiceImageUrl = await repo.uploadServiceImage(
          partnerId: partnerId,
          localPath: _localImagePath!,
        );
      }

      final data = PartnerServiceFormData(
        partnerId: partnerId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        price: price,
        discountPrice: discountPrice,
        durationMinutes: duration,
        category: _category,
        targetGender: _targetGender,
        serviceLocation: _serviceLocation,
        serviceImage: finalServiceImageUrl,
        isFeatured: _isFeatured,
        prepInstructions: _prepCtrl.text.trim().isEmpty ? null : _prepCtrl.text.trim(),
        isActive: _isActive,
      );

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
        constraints: const BoxConstraints(maxWidth: 580),
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
                      onPressed: _submitting ? null : () => Navigator.pop(context),
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
                        
                        // Cover photo section
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                  image: _localImagePath != null
                                      ? DecorationImage(
                                          image: FileImage(File(_localImagePath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : (_serviceImageUrl != null && _serviceImageUrl!.isNotEmpty)
                                          ? DecorationImage(
                                              image: NetworkImage(_serviceImageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                ),
                                child: (_localImagePath == null && (_serviceImageUrl == null || _serviceImageUrl!.isEmpty))
                                    ? const Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 20)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Service Cover Photo',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _pickCoverImage,
                                          icon: const Icon(Icons.upload_outlined, size: 12),
                                          label: Text(
                                            (_localImagePath != null || _serviceImageUrl != null)
                                                ? 'Change'
                                                : 'Upload Photo',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        if (_localImagePath != null || _serviceImageUrl != null) ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                                            onPressed: () {
                                              setState(() {
                                                _localImagePath = null;
                                                _serviceImageUrl = null;
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Remove photo',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        PartnerFormRow(
                          children: [
                            PartnerFormField(
                              label: 'Service Name',
                              icon: Icons.label_outline,
                              controller: _nameCtrl,
                              required: true,
                            ),
                            PartnerFormDropdown<String>(
                              label: 'Category',
                              icon: Icons.category_outlined,
                              value: _category,
                              items: const [
                                DropdownMenuItem(value: 'Hair Styling', child: Text('Hair Styling')),
                                DropdownMenuItem(value: 'Hair Treatment', child: Text('Hair Treatment')),
                                DropdownMenuItem(value: 'Makeup', child: Text('Makeup')),
                                DropdownMenuItem(value: 'Facial & Skin Care', child: Text('Facial & Skin Care')),
                                DropdownMenuItem(value: 'Massage & Spa', child: Text('Massage & Spa')),
                                DropdownMenuItem(value: 'Manicure & Pedicure', child: Text('Manicure & Pedicure')),
                                DropdownMenuItem(value: 'Bridal Package', child: Text('Bridal Package')),
                                DropdownMenuItem(value: 'Others', child: Text('Others')),
                              ],
                              onChanged: (v) => setState(() => _category = v ?? 'Others'),
                            ),
                          ],
                        ),
                        PartnerFormField(
                          label: 'Description',
                          icon: Icons.notes_outlined,
                          controller: _descCtrl,
                          maxLines: 2,
                          minLines: 1,
                          hint: 'Optional service details...',
                        ),
                        PartnerFormField(
                          label: 'Customer Prep Instructions',
                          icon: Icons.assignment_outlined,
                          controller: _prepCtrl,
                          maxLines: 2,
                          minLines: 1,
                          hint: 'e.g. Wash your hair before arriving, etc...',
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
                              label: 'Discount Price (₹)',
                              icon: Icons.local_offer_outlined,
                              controller: _discountPriceCtrl,
                              keyboard: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        PartnerFormRow(
                          children: [
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
                            PartnerFormDropdown<String>(
                              label: 'Target Gender',
                              icon: Icons.people_outline,
                              value: _targetGender,
                              items: const [
                                DropdownMenuItem(value: 'Unisex', child: Text('Unisex')),
                                DropdownMenuItem(value: 'Women', child: Text('Women')),
                                DropdownMenuItem(value: 'Men', child: Text('Men')),
                              ],
                              onChanged: (v) => setState(() => _targetGender = v ?? 'Unisex'),
                            ),
                          ],
                        ),
                        PartnerFormRow(
                          children: [
                            PartnerFormDropdown<String>(
                              label: 'Service Location',
                              icon: Icons.location_on_outlined,
                              value: _serviceLocation,
                              items: const [
                                DropdownMenuItem(value: 'At Salon Only', child: Text('At Salon Only')),
                                DropdownMenuItem(value: 'At Home Only', child: Text('At Home Only')),
                                DropdownMenuItem(value: 'Both (Salon & Home)', child: Text('Both (Salon & Home)')),
                              ],
                              onChanged: (v) => setState(() => _serviceLocation = v ?? 'At Salon Only'),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Popular / Featured', style: TextStyle(fontSize: 13)),
                                  value: _isFeatured,
                                  onChanged: (v) => setState(() => _isFeatured = v),
                                ),
                                if (isEdit)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Active', style: TextStyle(fontSize: 13)),
                                    value: _isActive,
                                    onChanged: (v) => setState(() => _isActive = v),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _submitting ? null : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _submitting ? null : () => _submit(partners),
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
