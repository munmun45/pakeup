import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  String? _partnerId;
  String _category = 'Others';
  
  List<String> _images = [];
  String? _primaryImage;
  bool _isActive = true;
  bool _submitting = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _partnerId = e?.partnerId;
    _category = e?.category ?? 'Others';
    _isActive = e?.isActive ?? true;
    _images = e != null ? List<String>.from(e.images) : [];
    _primaryImage = e?.primaryImage;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final partnerId = _partnerId ?? '';
    if (partnerId.isEmpty) {
      AppSnackBar.warning(context, 'Please select a store first before uploading images.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) return;

      setState(() => _isLoading = true);

      final repo = ref.read(partnerServicesRepositoryProvider);
      final publicUrl = await repo.uploadServiceImage(
        partnerId: partnerId,
        localPath: result.files.first.path!,
      );

      setState(() {
        _images.add(publicUrl);
        _primaryImage ??= publicUrl;
        _isLoading = false;
      });

      if (mounted) {
        AppSnackBar.success(context, 'Photo uploaded successfully');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppSnackBar.actionFailed(context, 'upload image', e);
      }
    }
  }

  void _deleteImage(String url) {
    setState(() {
      _images.remove(url);
      if (_primaryImage == url) {
        _primaryImage = _images.isNotEmpty ? _images.first : null;
      }
    });
  }

  void _setPrimary(String url) {
    setState(() {
      _primaryImage = url;
    });
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

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnerServicesRepositoryProvider);
      final e = widget.existing;
      
      final data = PartnerServiceFormData(
        partnerId: partnerId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        isActive: _isActive,
        
        // Preserve existing pricing or set safe defaults for new services
        price: e?.price ?? 0.0,
        discountPrice: e?.discountPrice,
        durationMinutes: e?.durationMinutes ?? 30,
        targetGender: e?.targetGender ?? 'Unisex',
        serviceLocation: e?.serviceLocation ?? 'Both',
        freeRadiusKm: e?.freeRadiusKm ?? 0,
        perKmCharge: e?.perKmCharge ?? 0.0,
        
        isParlourAvailable: e?.isParlourAvailable ?? true,
        parlourPrice: e?.parlourPrice,
        parlourDurationMinutes: e?.parlourDurationMinutes,
        parlourTargetGender: e?.parlourTargetGender,
        parlourPriceMen: e?.parlourPriceMen,
        parlourDurationMen: e?.parlourDurationMen,
        parlourPriceWomen: e?.parlourPriceWomen,
        parlourDurationWomen: e?.parlourDurationWomen,
        parlourPrepMen: e?.parlourPrepMen,
        parlourPrepWomen: e?.parlourPrepWomen,
        
        isHomeAvailable: e?.isHomeAvailable ?? false,
        homePrice: e?.homePrice,
        homeDurationMinutes: e?.homeDurationMinutes,
        homeTargetGender: e?.homeTargetGender,
        homePriceMen: e?.homePriceMen,
        homeDurationMen: e?.homeDurationMen,
        homePriceWomen: e?.homePriceWomen,
        homeDurationWomen: e?.homeDurationWomen,
        homePrepMen: e?.homePrepMen,
        homePrepWomen: e?.homePrepWomen,
        prepInstructions: e?.prepInstructions,
      );

      final PartnerServiceRecord serviceRecord;
      if (widget.existing == null) {
        serviceRecord = await repo.createService(callerId: user.id, data: data);
      } else {
        serviceRecord = await repo.updateService(
          callerId: user.id,
          serviceId: widget.existing!.id,
          data: data,
        );
      }

      // Sync the images to DB after service creation/update
      await repo.updateServiceImages(
        callerId: user.id,
        serviceId: serviceRecord.id,
        images: _images,
        primaryImage: _primaryImage,
      );

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

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 850;

    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.spa_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Service' : 'Add Service',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Configure basic service metadata and photos',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),

            // 2. BODY & FOOTER
            Expanded(
              child: partnersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString()),
                ),
                data: (partners) {
                  if (partners.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Add a partner first before creating services.'),
                    );
                  }

                  final currentPartnerId = _partnerId;

                  Widget buildNameCategoryRow() {
                    final categoryDropdown = Builder(builder: (context) {
                      final serviceCategories = serviceCategoriesAsync.maybeWhen(
                        data: (cats) => cats,
                        orElse: () => <dynamic>[],
                      );
                      final catNames = serviceCategories
                          .map<String>((c) => c.name as String)
                          .toList();
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
                        compact: true,
                        onChanged: (v) => setState(() => _category = v ?? _category),
                        items: catNames.isNotEmpty
                            ? catNames
                                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                                .toList()
                            : [DropdownMenuItem(value: _category, child: Text(_category))],
                      );
                    });

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PartnerFormField(
                            label: 'Service Name',
                            icon: Icons.label_outline,
                            controller: _nameCtrl,
                            required: true,
                            compact: true,
                          ),
                          categoryDropdown,
                        ],
                      );
                    } else {
                      return PartnerFormRow(
                        children: [
                          PartnerFormField(
                            label: 'Service Name',
                            icon: Icons.label_outline,
                            controller: _nameCtrl,
                            required: true,
                            compact: true,
                          ),
                          categoryDropdown,
                        ],
                      );
                    }
                  }

                  Widget buildImageUploader(BuildContext context) {
                    Widget buildUploadDropzone() {
                      return InkWell(
                        onTap: _isLoading || _images.length >= 5 ? null : _pickAndUploadImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.01),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _images.length >= 5
                                  ? AppColors.border
                                  : AppColors.primary.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _images.length >= 5
                                      ? AppColors.border.withValues(alpha: 0.2)
                                      : AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 24,
                                  color: _images.length >= 5
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _images.length >= 5
                                    ? 'Upload Limit Reached'
                                    : 'Upload Service Photos',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _images.length >= 5
                                    ? 'You have uploaded the maximum of 5 photos'
                                    : 'Supports PNG, JPG (Max 5 files)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    Widget buildUploadedGrid() {
                      if (_images.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            'Uploaded Photos',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _images.map((url) {
                              final isPrimary = url == _primaryImage;
                              return Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPrimary ? AppColors.primary : AppColors.border,
                                    width: isPrimary ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Center(
                                        child: Icon(Icons.broken_image_outlined, size: 20, color: Colors.red),
                                      ),
                                    ),
                                    // Delete button
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: GestureDetector(
                                        onTap: _isLoading ? null : () => _deleteImage(url),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Primary badge
                                    Positioned(
                                      bottom: 5,
                                      right: 5,
                                      child: GestureDetector(
                                        onTap: _isLoading ? null : () => _setPrimary(url),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: isPrimary ? AppColors.primary : Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    }

                    return Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buildUploadDropzone(),
                            buildUploadedGrid(),
                          ],
                        ),
                        if (_isLoading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }

                  Widget buildCardsBody() {
                    final serviceDetailsCard = PartnerFormSection(
                      title: 'Store & Service Details',
                      icon: Icons.storefront_outlined,
                      children: [
                        SearchablePartnerDropdown(
                          partners: partners,
                          selectedId: currentPartnerId,
                          onChanged: (id) => setState(() => _partnerId = id),
                        ),
                        const SizedBox(height: 16),
                        buildNameCategoryRow(),
                      ],
                    );

                    final descriptionCard = PartnerFormSection(
                      title: 'Service Description',
                      icon: Icons.notes_outlined,
                      children: [
                        PartnerFormField(
                          label: 'Description',
                          icon: Icons.notes_outlined,
                          controller: _descCtrl,
                          maxLines: 6,
                          minLines: 4,
                          hint: 'Optional service details...',
                          compact: true,
                        ),
                      ],
                    );

                    final mediaCard = PartnerFormSection(
                      title: 'Service Media',
                      icon: Icons.image_outlined,
                      children: [
                        buildImageUploader(context),
                      ],
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          serviceDetailsCard,
                          descriptionCard,
                          mediaCard,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column card stack (Store & Service details + Description)
                              Expanded(
                                flex: 11,
                                child: Column(
                                  children: [
                                    serviceDetailsCard,
                                    const SizedBox(height: 20),
                                    descriptionCard,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Right column (Service Media)
                              Expanded(
                                flex: 12,
                                child: mediaCard,
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  }

                  return Column(
                    children: [
                      // Sticky Body Area
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: buildCardsBody(),
                          ),
                        ),
                      ),
                      
                      // Sticky Footer Area
                      Container(
                        padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                          border: Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _submitting ? null : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
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
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
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
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
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
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedPartner.phone!.trim(),
                                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    _searchCtrl.clear();
    _searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = widget.partners.where((p) {
              final q = _searchQuery.toLowerCase();
              return p.businessName.toLowerCase().contains(q) ||
                  p.ownerName.toLowerCase().contains(q) ||
                  (p.phone ?? '').contains(q);
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450, maxHeight: 500),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text('Select Store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search business name, owner or phone...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setDialogState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('No stores found.', style: TextStyle(color: AppColors.textSecondary)),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final p = filtered[idx];
                                  final isSelected = p.id == widget.selectedId;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
      setState(() {});
    });
  }
}
