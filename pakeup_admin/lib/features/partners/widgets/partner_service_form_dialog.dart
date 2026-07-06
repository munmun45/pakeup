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
  late final TextEditingController _parlourPriceMenCtrl;
  late final TextEditingController _parlourDurationMenCtrl;
  late final TextEditingController _parlourPriceWomenCtrl;
  late final TextEditingController _parlourDurationWomenCtrl;
  late final TextEditingController _parlourPrepMenCtrl;
  late final TextEditingController _parlourPrepWomenCtrl;
  late final TextEditingController _homePriceMenCtrl;
  late final TextEditingController _homeDurationMenCtrl;
  late final TextEditingController _homePriceWomenCtrl;
  late final TextEditingController _homeDurationWomenCtrl;
  late final TextEditingController _homePrepMenCtrl;
  late final TextEditingController _homePrepWomenCtrl;
  late final TextEditingController _freeRadiusCtrl;
  late final TextEditingController _perKmChargeCtrl;

  String? _partnerId;
  String _category = 'Others';
  
  bool _isParlourAvailable = false;
  bool _isParlourMenEnabled = false;
  bool _isParlourWomenEnabled = false;
  
  bool _isHomeAvailable = false;
  bool _isHomeMenEnabled = false;
  bool _isHomeWomenEnabled = false;

  String? _serviceImageUrl;
  bool _isActive = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    
    _isParlourAvailable = e?.isParlourAvailable ?? false;
    _isParlourMenEnabled = e != null ? (e.parlourPriceMen != null) : false;
    _isParlourWomenEnabled = e != null ? (e.parlourPriceWomen != null) : false;

    _isHomeAvailable = e?.isHomeAvailable ?? false;
    _isHomeMenEnabled = e != null ? (e.homePriceMen != null) : false;
    _isHomeWomenEnabled = e != null ? (e.homePriceWomen != null) : false;

    _parlourPriceMenCtrl = TextEditingController(
      text: e?.parlourPriceMen?.toStringAsFixed(0) ?? (e != null && e.isParlourAvailable ? e.price.toStringAsFixed(0) : ''),
    );
    _parlourDurationMenCtrl = TextEditingController(
      text: e?.parlourDurationMen?.toString() ?? (e != null && e.isParlourAvailable ? e.durationMinutes.toString() : '30'),
    );
    _parlourPriceWomenCtrl = TextEditingController(
      text: e?.parlourPriceWomen?.toStringAsFixed(0) ?? '',
    );
    _parlourDurationWomenCtrl = TextEditingController(
      text: e?.parlourDurationWomen?.toString() ?? '30',
    );
    _parlourPrepMenCtrl = TextEditingController(
      text: e?.parlourPrepMen ?? (e != null && e.isParlourAvailable && e.parlourPriceMen != null ? e.prepInstructions ?? '' : ''),
    );
    _parlourPrepWomenCtrl = TextEditingController(
      text: e?.parlourPrepWomen ?? (e != null && e.isParlourAvailable && e.parlourPriceWomen != null ? e.prepInstructions ?? '' : ''),
    );

    _homePriceMenCtrl = TextEditingController(
      text: e?.homePriceMen?.toStringAsFixed(0) ?? (e != null && e.isHomeAvailable ? e.price.toStringAsFixed(0) : ''),
    );
    _homeDurationMenCtrl = TextEditingController(
      text: e?.homeDurationMen?.toString() ?? (e != null && e.isHomeAvailable ? e.durationMinutes.toString() : '30'),
    );
    _homePriceWomenCtrl = TextEditingController(
      text: e?.homePriceWomen?.toStringAsFixed(0) ?? '',
    );
    _homeDurationWomenCtrl = TextEditingController(
      text: e?.homeDurationWomen?.toString() ?? '30',
    );
    _homePrepMenCtrl = TextEditingController(
      text: e?.homePrepMen ?? (e != null && e.isHomeAvailable && e.homePriceMen != null ? e.prepInstructions ?? '' : ''),
    );
    _homePrepWomenCtrl = TextEditingController(
      text: e?.homePrepWomen ?? (e != null && e.isHomeAvailable && e.homePriceWomen != null ? e.prepInstructions ?? '' : ''),
    );

    _partnerId = e?.partnerId;
    _category = e?.category ?? 'Others';

    _freeRadiusCtrl = TextEditingController(
      text: e?.freeRadiusKm.toString() ?? '0',
    );
    _perKmChargeCtrl = TextEditingController(
      text: e != null ? e.perKmCharge.toStringAsFixed(0) : '0',
    );
    _serviceImageUrl = e?.serviceImage;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _parlourPriceMenCtrl.dispose();
    _parlourDurationMenCtrl.dispose();
    _parlourPriceWomenCtrl.dispose();
    _parlourDurationWomenCtrl.dispose();
    _parlourPrepMenCtrl.dispose();
    _parlourPrepWomenCtrl.dispose();
    _homePriceMenCtrl.dispose();
    _homeDurationMenCtrl.dispose();
    _homePriceWomenCtrl.dispose();
    _homeDurationWomenCtrl.dispose();
    _homePrepMenCtrl.dispose();
    _homePrepWomenCtrl.dispose();
    _freeRadiusCtrl.dispose();
    _perKmChargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(List<PartnerRecord> partners) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isParlourAvailable && !_isHomeAvailable) {
      AppSnackBar.warning(context, 'Please select at least one service location: Salon or Home Visit');
      return;
    }

    if (_isParlourAvailable && !_isParlourMenEnabled && !_isParlourWomenEnabled) {
      AppSnackBar.warning(context, 'Please select at least one gender (Male or Female) for Salon Visit');
      return;
    }

    if (_isHomeAvailable && !_isHomeMenEnabled && !_isHomeWomenEnabled) {
      AppSnackBar.warning(context, 'Please select at least one gender (Male or Female) for Home Visit');
      return;
    }

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

    // Extraction
    final parlourPriceMen = (_isParlourAvailable && _isParlourMenEnabled) ? (double.tryParse(_parlourPriceMenCtrl.text.trim()) ?? 0.0) : null;
    final parlourDurationMen = (_isParlourAvailable && _isParlourMenEnabled) ? (int.tryParse(_parlourDurationMenCtrl.text.trim()) ?? 30) : null;
    final parlourPriceWomen = (_isParlourAvailable && _isParlourWomenEnabled) ? (double.tryParse(_parlourPriceWomenCtrl.text.trim()) ?? 0.0) : null;
    final parlourDurationWomen = (_isParlourAvailable && _isParlourWomenEnabled) ? (int.tryParse(_parlourDurationWomenCtrl.text.trim()) ?? 30) : null;
    final parlourPrepMen = (_isParlourAvailable && _isParlourMenEnabled) ? (_parlourPrepMenCtrl.text.trim().isEmpty ? null : _parlourPrepMenCtrl.text.trim()) : null;
    final parlourPrepWomen = (_isParlourAvailable && _isParlourWomenEnabled) ? (_parlourPrepWomenCtrl.text.trim().isEmpty ? null : _parlourPrepWomenCtrl.text.trim()) : null;

    final homePriceMen = (_isHomeAvailable && _isHomeMenEnabled) ? (double.tryParse(_homePriceMenCtrl.text.trim()) ?? 0.0) : null;
    final homeDurationMen = (_isHomeAvailable && _isHomeMenEnabled) ? (int.tryParse(_homeDurationMenCtrl.text.trim()) ?? 30) : null;
    final homePriceWomen = (_isHomeAvailable && _isHomeWomenEnabled) ? (double.tryParse(_homePriceWomenCtrl.text.trim()) ?? 0.0) : null;
    final homeDurationWomen = (_isHomeAvailable && _isHomeWomenEnabled) ? (int.tryParse(_homeDurationWomenCtrl.text.trim()) ?? 30) : null;
    final homePrepMen = (_isHomeAvailable && _isHomeMenEnabled) ? (_homePrepMenCtrl.text.trim().isEmpty ? null : _homePrepMenCtrl.text.trim()) : null;
    final homePrepWomen = (_isHomeAvailable && _isHomeWomenEnabled) ? (_homePrepWomenCtrl.text.trim().isEmpty ? null : _homePrepWomenCtrl.text.trim()) : null;

    final freeRadius = _isHomeAvailable ? (int.tryParse(_freeRadiusCtrl.text.trim()) ?? 0) : 0;
    final perKmCharge = _isHomeAvailable ? (double.tryParse(_perKmChargeCtrl.text.trim()) ?? 0.0) : 0.0;

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnerServicesRepositoryProvider);
      
      // Determine location description for backward compatibility
      final String serviceLocation;
      if (_isParlourAvailable && _isHomeAvailable) {
        serviceLocation = 'Both';
      } else if (_isHomeAvailable) {
        serviceLocation = 'At Home';
      } else {
        serviceLocation = 'At Salon Only';
      }

      // Determine backward-compatible fallbacks
      final priceFallback = parlourPriceMen ?? parlourPriceWomen ?? homePriceMen ?? homePriceWomen ?? 0.0;
      final durationFallback = parlourDurationMen ?? parlourDurationWomen ?? homeDurationMen ?? homeDurationWomen ?? 30;
      final prepFallback = parlourPrepMen ?? parlourPrepWomen ?? homePrepMen ?? homePrepWomen;
      
      final String genderFallback;
      if ((parlourPriceMen != null || homePriceMen != null) && (parlourPriceWomen != null || homePriceWomen != null)) {
        genderFallback = 'Unisex';
      } else if (parlourPriceMen != null || homePriceMen != null) {
        genderFallback = 'Men';
      } else {
        genderFallback = 'Women';
      }

      final data = PartnerServiceFormData(
        partnerId: partnerId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        price: priceFallback,
        discountPrice: null,
        durationMinutes: durationFallback,
        category: _category,
        targetGender: genderFallback,
        serviceLocation: serviceLocation,
        freeRadiusKm: freeRadius,
        perKmCharge: perKmCharge,
        
        isParlourAvailable: _isParlourAvailable,
        parlourPrice: parlourPriceMen ?? parlourPriceWomen,
        parlourDurationMinutes: parlourDurationMen ?? parlourDurationWomen,
        parlourTargetGender: (parlourPriceMen != null && parlourPriceWomen != null) ? 'Unisex' : (parlourPriceMen != null ? 'Men' : 'Women'),
        parlourPriceMen: parlourPriceMen,
        parlourDurationMen: parlourDurationMen,
        parlourPriceWomen: parlourPriceWomen,
        parlourDurationWomen: parlourDurationWomen,
        parlourPrepMen: parlourPrepMen,
        parlourPrepWomen: parlourPrepWomen,
        
        isHomeAvailable: _isHomeAvailable,
        homePrice: homePriceMen ?? homePriceWomen,
        homeDurationMinutes: homeDurationMen ?? homeDurationWomen,
        homeTargetGender: (homePriceMen != null && homePriceWomen != null) ? 'Unisex' : (homePriceMen != null ? 'Men' : 'Women'),
        homePriceMen: homePriceMen,
        homeDurationMen: homeDurationMen,
        homePriceWomen: homePriceWomen,
        homeDurationWomen: homeDurationWomen,
        homePrepMen: homePrepMen,
        homePrepWomen: homePrepWomen,
        
        serviceImage: _serviceImageUrl,
        isFeatured: false,
        prepInstructions: prepFallback,
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
            // 1. HEADER (White background bar with top rounded corners)
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
                          'Configure service information, availability, and pricing details',
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

            // 2. BODY & FOOTER (Scoping partners data)
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

                  Widget buildPricingDurationRow({
                    required String genderLabel,
                    required TextEditingController priceCtrl,
                    required TextEditingController durationCtrl,
                  }) {
                    final priceField = PartnerFormField(
                      label: "$genderLabel Price (₹) *",
                      icon: Icons.currency_rupee,
                      controller: priceCtrl,
                      required: true,
                      keyboard: TextInputType.number,
                      compact: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    );

                    final durationField = PartnerFormField(
                      label: "$genderLabel Duration (min) *",
                      icon: Icons.timer_outlined,
                      controller: durationCtrl,
                      required: true,
                      keyboard: TextInputType.number,
                      compact: true,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          priceField,
                          durationField,
                        ],
                      );
                    } else {
                      return PartnerFormRow(
                        children: [
                          priceField,
                          durationField,
                        ],
                      );
                    }
                  }

                  Widget buildHomeTravelRow() {
                    final radiusField = PartnerFormField(
                      label: 'Free Radius (km) *',
                      icon: Icons.map_outlined,
                      controller: _freeRadiusCtrl,
                      required: true,
                      keyboard: TextInputType.number,
                      compact: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    );

                    final chargeField = PartnerFormField(
                      label: 'Charge per km (₹) *',
                      icon: Icons.currency_rupee,
                      controller: _perKmChargeCtrl,
                      required: true,
                      keyboard: TextInputType.number,
                      compact: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          radiusField,
                          chargeField,
                        ],
                      );
                    } else {
                      return PartnerFormRow(
                        children: [
                          radiusField,
                          chargeField,
                        ],
                      );
                    }
                  }

                  final parlourVisitWidget = Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isParlourAvailable
                          ? AppColors.primary.withValues(alpha: 0.02)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isParlourAvailable
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _isParlourAvailable,
                              onChanged: (v) => setState(() {
                                _isParlourAvailable = v ?? false;
                              }),
                              activeColor: AppColors.primary,
                            ),
                            const Icon(Icons.storefront_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Available at Salon (Parlour Visit)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isParlourAvailable) ...[
                          const SizedBox(height: 12),
                          // Male option
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isParlourMenEnabled,
                                      onChanged: (v) => setState(() {
                                        _isParlourMenEnabled = v ?? false;
                                      }),
                                      activeColor: AppColors.primary,
                                    ),
                                    const Icon(Icons.male, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Men's Service",
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                                if (_isParlourMenEnabled) ...[
                                  const SizedBox(height: 8),
                                  buildPricingDurationRow(
                                    genderLabel: "Men's",
                                    priceCtrl: _parlourPriceMenCtrl,
                                    durationCtrl: _parlourDurationMenCtrl,
                                  ),
                                  const SizedBox(height: 8),
                                  PartnerFormField(
                                    label: "Men's Prep Instructions",
                                    icon: Icons.assignment_outlined,
                                    controller: _parlourPrepMenCtrl,
                                    hint: "e.g. Wash your hair before arriving...",
                                    compact: true,
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Female option
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isParlourWomenEnabled,
                                      onChanged: (v) => setState(() {
                                        _isParlourWomenEnabled = v ?? false;
                                      }),
                                      activeColor: AppColors.primary,
                                    ),
                                    const Icon(Icons.female, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Women's Service",
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                                if (_isParlourWomenEnabled) ...[
                                  const SizedBox(height: 8),
                                  buildPricingDurationRow(
                                    genderLabel: "Women's",
                                    priceCtrl: _parlourPriceWomenCtrl,
                                    durationCtrl: _parlourDurationWomenCtrl,
                                  ),
                                  const SizedBox(height: 8),
                                  PartnerFormField(
                                    label: "Women's Prep Instructions",
                                    icon: Icons.assignment_outlined,
                                    controller: _parlourPrepWomenCtrl,
                                    hint: "e.g. Wash your hair before arriving...",
                                    compact: true,
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );

                  final homeVisitWidget = Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isHomeAvailable
                          ? AppColors.primary.withValues(alpha: 0.02)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isHomeAvailable
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _isHomeAvailable,
                              onChanged: (v) => setState(() {
                                _isHomeAvailable = v ?? false;
                              }),
                              activeColor: AppColors.primary,
                            ),
                            const Icon(Icons.home_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Available at Home (Home Visit)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isHomeAvailable) ...[
                          const SizedBox(height: 12),
                          // Male option
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isHomeMenEnabled,
                                      onChanged: (v) => setState(() {
                                        _isHomeMenEnabled = v ?? false;
                                      }),
                                      activeColor: AppColors.primary,
                                    ),
                                    const Icon(Icons.male, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Men's Service",
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                                if (_isHomeMenEnabled) ...[
                                  const SizedBox(height: 8),
                                  buildPricingDurationRow(
                                    genderLabel: "Men's",
                                    priceCtrl: _homePriceMenCtrl,
                                    durationCtrl: _homeDurationMenCtrl,
                                  ),
                                  const SizedBox(height: 8),
                                  PartnerFormField(
                                    label: "Men's Prep Instructions",
                                    icon: Icons.assignment_outlined,
                                    controller: _homePrepMenCtrl,
                                    hint: "e.g. Wash your hair before arriving...",
                                    compact: true,
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Female option
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isHomeWomenEnabled,
                                      onChanged: (v) => setState(() {
                                        _isHomeWomenEnabled = v ?? false;
                                      }),
                                      activeColor: AppColors.primary,
                                    ),
                                    const Icon(Icons.female, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Women's Service",
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                                if (_isHomeWomenEnabled) ...[
                                  const SizedBox(height: 8),
                                  buildPricingDurationRow(
                                    genderLabel: "Women's",
                                    priceCtrl: _homePriceWomenCtrl,
                                    durationCtrl: _homeDurationWomenCtrl,
                                  ),
                                  const SizedBox(height: 8),
                                  PartnerFormField(
                                    label: "Women's Prep Instructions",
                                    icon: Icons.assignment_outlined,
                                    controller: _homePrepWomenCtrl,
                                    hint: "e.g. Wash your hair before arriving...",
                                    compact: true,
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          buildHomeTravelRow(),
                        ],
                      ],
                    ),
                  );

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
                        if (isEdit) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Inactive services are hidden from customer app', style: TextStyle(fontSize: 11)),
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        ],
                      ],
                    );

                    final pricingCard = PartnerFormSection(
                      title: 'Service Availability & Pricing',
                      icon: Icons.payments_outlined,
                      children: [
                        if (isCompact) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              parlourVisitWidget,
                              const SizedBox(height: 16),
                              homeVisitWidget,
                            ],
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: parlourVisitWidget),
                              const SizedBox(width: 20),
                              Expanded(child: homeVisitWidget),
                            ],
                          ),
                        ],
                      ],
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          serviceDetailsCard,
                          descriptionCard,
                          pricingCard,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column card (Store & Service details)
                              Expanded(
                                flex: 11,
                                child: serviceDetailsCard,
                              ),
                              const SizedBox(width: 20),
                              // Right column description card
                              Expanded(
                                flex: 12,
                                child: descriptionCard,
                              ),
                            ],
                          ),
                          pricingCard,
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
