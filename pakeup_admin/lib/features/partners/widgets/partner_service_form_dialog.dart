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
import '../providers/service_categories_provider.dart';
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
  late final TextEditingController _prepCtrl;
  
  String? _partnerId;
  String _category = 'Others';
  String _targetGender = 'Unisex';
  String? _serviceImageUrl;
  String? _localImagePath;
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
    _prepCtrl = TextEditingController(text: e?.prepInstructions ?? '');
    _partnerId = e?.partnerId;
    _category = e?.category ?? 'Others';
    _targetGender = e?.targetGender ?? 'Unisex';
    _serviceImageUrl = e?.serviceImage;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
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

    final partnerId = _partnerId ?? (partners.isNotEmpty ? partners.first.id : '');
    if (partnerId.isEmpty) {
      AppSnackBar.error(context, 'Please select a store');
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
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
        discountPrice: null,
        durationMinutes: duration,
        category: _category,
        targetGender: _targetGender,
        serviceLocation: 'At Salon Only',
        serviceImage: finalServiceImageUrl,
        isFeatured: false,
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
    final serviceCategoriesAsync = ref.watch(activeServiceCategoriesProvider);
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                            fontSize: 18,
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
                  const SizedBox(height: 20),
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

                      // Only use an explicit selection; null means "not chosen yet"
                      final currentPartnerId = _partnerId;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Searchable Dropdown for Partner/Store
                          SearchablePartnerDropdown(
                            partners: partners,
                            selectedId: currentPartnerId,
                            onChanged: (id) => setState(() => _partnerId = id),
                          ),
                          
                          PartnerFormRow(
                            children: [
                              // Cover photo upload card
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
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
                                        ? const Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 22)
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
                                                    : 'Upload',
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
                            ],
                          ),
                          const SizedBox(height: 12),

                          PartnerFormRow(
                            children: [
                              PartnerFormField(
                                label: 'Service Name',
                                icon: Icons.label_outline,
                                controller: _nameCtrl,
                                required: true,
                              ),
                              Builder(builder: (context) {
                                // Resolve the effective category value from live data
                                final serviceCategories = serviceCategoriesAsync.maybeWhen(
                                  data: (cats) => cats,
                                  orElse: () => <dynamic>[],
                                );
                                final catNames = serviceCategories
                                    .map<String>((c) => c.name as String)
                                    .toList();
                                // If loaded & current _category isn't in the list, reset
                                if (catNames.isNotEmpty && !catNames.contains(_category)) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) setState(() => _category = catNames.first);
                                  });
                                }
                                final resolvedValue = catNames.contains(_category)
                                    ? _category
                                    : (catNames.isNotEmpty ? catNames.first : _category);

                                return PartnerFormDropdown<String>(
                                  label: 'Category',
                                  icon: Icons.category_outlined,
                                  value: resolvedValue,
                                  items: catNames.isNotEmpty
                                      ? catNames
                                          .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                                          .toList()
                                      : [DropdownMenuItem(value: _category, child: Text(_category))],
                                  onChanged: (v) => setState(() => _category = v ?? _category),
                                );
                              }),
                            ],
                          ),
                          
                          // Big Description text area
                          PartnerFormField(
                            label: 'Description',
                            icon: Icons.notes_outlined,
                            controller: _descCtrl,
                            maxLines: 4,
                            minLines: 3,
                            hint: 'Optional service details...',
                          ),

                          PartnerFormField(
                            label: 'Customer Prep Instructions',
                            icon: Icons.assignment_outlined,
                            controller: _prepCtrl,
                            maxLines: 3,
                            minLines: 2,
                            hint: 'e.g. Wash your hair before arriving, etc...',
                          ),

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

                          if (isEdit) ...[
                            const SizedBox(height: 4),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: const Text('Inactive services are hidden from customer app', style: TextStyle(fontSize: 11)),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                          ],

                          const SizedBox(height: 16),
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
      ),
    );
  }
}

class SearchablePartnerDropdown extends StatefulWidget {
  const SearchablePartnerDropdown({
    super.key,
    required this.partners,
    required this.selectedId,
    required this.onChanged,
  });

  final List<PartnerRecord> partners;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  State<SearchablePartnerDropdown> createState() => _SearchablePartnerDropdownState();
}

class _SearchablePartnerDropdownState extends State<SearchablePartnerDropdown> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only resolve a selected partner if one has been explicitly chosen
    final selectedPartner = widget.selectedId != null
        ? widget.partners.where((p) => p.id == widget.selectedId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Store',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showSearchDialog(context),
          borderRadius: BorderRadius.circular(10),
          child: selectedPartner == null
              // ── Placeholder (nothing selected yet) ──
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront_outlined, size: 18, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tap to select a store...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                )
              // ── Selected store card ──
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      // Store avatar
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: (selectedPartner.primaryImage?.trim().isNotEmpty == true)
                            ? NetworkImage(selectedPartner.primaryImage!.trim())
                            : (selectedPartner.images.isNotEmpty && selectedPartner.images.first.trim().isNotEmpty)
                                ? NetworkImage(selectedPartner.images.first.trim())
                                : null,
                        child: (selectedPartner.primaryImage?.trim().isNotEmpty == true ||
                                (selectedPartner.images.isNotEmpty && selectedPartner.images.first.trim().isNotEmpty))
                            ? null
                            : Text(
                                selectedPartner.businessName.isNotEmpty
                                    ? selectedPartner.businessName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Store details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedPartner.businessName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 11, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  selectedPartner.ownerName,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                if (selectedPartner.phone?.trim().isNotEmpty == true) ...[
                                  const Text('  ·  ', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                  const Icon(Icons.phone_outlined, size: 11, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    selectedPartner.phone!.trim(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if ((selectedPartner.city?.trim().isNotEmpty == true) ||
                                (selectedPartner.addressLine?.trim().isNotEmpty == true)) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textSecondary),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      [selectedPartner.addressLine, selectedPartner.city]
                                          .where((s) => s?.trim().isNotEmpty == true)
                                          .join(', '),
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Change indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.unfold_more, size: 13, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    _searchCtrl.clear();
    _searchQuery = '';

    // Auto-focus the search field after the dialog frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredPartners = widget.partners
                .where((p) =>
                    p.businessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    p.ownerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (p.phone?.contains(_searchQuery) ?? false))
                .toList();

            final focused = _searchFocusNode.hasFocus;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Store',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Custom Search Bar (matching HeaderSearchBar styling)
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: focused
                                ? AppColors.primary.withValues(alpha: 0.65)
                                : AppColors.border,
                            width: focused ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: focused
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: focused ? 10 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: focused
                                    ? AppColors.primary.withValues(alpha: 0.14)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                size: 17,
                                color: focused ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search by store name, owner, or phone...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                onChanged: (val) {
                                  setModalState(() {
                                    _searchQuery = val;
                                  });
                                },
                              ),
                            ),
                            if (_searchCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setModalState(() {
                                    _searchQuery = '';
                                  });
                                },
                                padding: const EdgeInsets.only(right: 8),
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredPartners.isEmpty
                            ? const Center(
                                child: Text(
                                  'No stores found',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredPartners.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                                itemBuilder: (context, idx) {
                                  final p = filteredPartners[idx];
                                  final isSelected = p.id == widget.selectedId;
                                  
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                      backgroundImage: (p.primaryImage?.trim().isNotEmpty == true)
                                          ? NetworkImage(p.primaryImage!.trim())
                                          : (p.images.isNotEmpty && p.images.first.trim().isNotEmpty)
                                              ? NetworkImage(p.images.first.trim())
                                              : null,
                                      child: (p.primaryImage?.trim().isNotEmpty == true ||
                                              (p.images.isNotEmpty && p.images.first.trim().isNotEmpty))
                                          ? null
                                          : Text(
                                              p.businessName.isNotEmpty
                                                  ? p.businessName[0].toUpperCase()
                                                  : 'S',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                    ),
                                    title: Text(
                                      p.businessName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 10, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${p.ownerName} · ',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            p.phone ?? '—',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
                                        : null,
                                    onTap: () {
                                      widget.onChanged(p.id);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Re-trigger build of parent state when popup closes to match focus styling
      setState(() {});
    });
  }
}
