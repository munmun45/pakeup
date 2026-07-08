import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../models/store_location_data.dart';
import '../models/store_models.dart';
import '../models/store_schedule_models.dart';
import '../providers/stores_provider.dart';
import '../widgets/store_form_fields.dart';
import '../widgets/store_location_picker.dart';
import '../widgets/store_open_hours_section.dart';

class EditStoreScreen extends ConsumerStatefulWidget {
  const EditStoreScreen({super.key, required this.storeId});

  final String storeId;

  @override
  ConsumerState<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends ConsumerState<EditStoreScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  final _businessNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  String _category = 'salon';
  double? _latitude;
  double? _longitude;
  bool _loading = false;
  bool _prefilled = false;
  double _keyboardInset = 0;
  List<DaySchedule> _schedules = DaySchedule.defaults();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardClosing = _keyboardInset > 0 && inset == 0;
    _keyboardInset = inset;
    if (!keyboardClosing || !_scrollCtrl.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final position = _scrollCtrl.position;
      final clamped = position.pixels.clamp(0.0, position.maxScrollExtent);
      if ((position.pixels - clamped).abs() > 1) {
        _scrollCtrl.jumpTo(clamped);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _businessNameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  void _prefill(StoreRecord store) {
    if (_prefilled) return;
    _prefilled = true;
    _businessNameCtrl.text = store.businessName;
    _phoneCtrl.text = store.phone ?? '';
    _whatsappCtrl.text = store.whatsapp ?? store.phone ?? '';
    _descriptionCtrl.text = store.description ?? '';
    _addressCtrl.text = store.address ?? '';
    _cityCtrl.text = store.city ?? '';
    _stateCtrl.text = store.state ?? '';
    _pincodeCtrl.text = store.pincode ?? '';
    _category = store.category;
    _latitude = store.latitude;
    _longitude = store.longitude;
    _schedules = store.schedules.isEmpty
        ? DaySchedule.defaults()
        : List<DaySchedule>.from(store.schedules);
  }

  void _onLocationChanged(StoreLocationData location) {
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
    });
    if (location.address.isNotEmpty) _addressCtrl.text = location.address;
    if (location.city.isNotEmpty) _cityCtrl.text = location.city;
    if (location.state.isNotEmpty) _stateCtrl.text = location.state;
    if (location.pincode.isNotEmpty) _pincodeCtrl.text = location.pincode;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
    if (!mounted) return;
    if (loginPass == null || loginPass.isEmpty) {
      AppSnackBar.error(context, 'Session expired. Please log in again.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(storesRepositoryProvider).updateStore(
            accountId: user.id,
            loginPass: loginPass,
            storeId: widget.storeId,
            data: AddStoreData(
              businessName: _businessNameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              whatsapp: _whatsappCtrl.text.trim(),
              description: _descriptionCtrl.text.trim().isEmpty
                  ? null
                  : _descriptionCtrl.text.trim(),
              address: _addressCtrl.text.trim().isEmpty
                  ? null
                  : _addressCtrl.text.trim(),
              city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
              state:
                  _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
              pincode: _pincodeCtrl.text.trim().isEmpty
                  ? null
                  : _pincodeCtrl.text.trim(),
              latitude: _latitude,
              longitude: _longitude,
              category: _category,
              schedules: _schedules,
            ),
          );
      ref.invalidate(myStoresProvider);
      ref.invalidate(storeDetailProvider(widget.storeId));
      if (mounted) {
        AppSnackBar.success(context, 'Store updated successfully!');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to update store: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _phoneValidator(String? v) {
    if (v?.trim().isEmpty == true) return 'Required';
    if (v!.trim().length != 10) return 'Enter 10 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeDetailProvider(widget.storeId));
    final categoriesAsync = ref.watch(partnerCategoriesProvider);
    final mapsKey = Env.googleMapsApiKey;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Edit Store'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (store) {
          _prefill(store);
          return SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                        StoreFormSection(
                          title: 'Store Information',
                          icon: Icons.storefront_outlined,
                          child: Column(
                            children: [
                              StoreFormField(
                                controller: _businessNameCtrl,
                                label: 'Store / Business Name',
                                icon: Icons.store_outlined,
                                required: true,
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    v?.trim().isEmpty == true ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              StoreFieldRow(
                                children: [
                                  StoreFormField(
                                    controller: _phoneCtrl,
                                    label: 'Phone',
                                    icon: Icons.phone_outlined,
                                    required: true,
                                    hint: '10 digits',
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: _phoneValidator,
                                  ),
                                  StoreFormField(
                                    controller: _whatsappCtrl,
                                    label: 'WhatsApp',
                                    icon: Icons.chat_outlined,
                                    required: true,
                                    hint: '10 digits',
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: _phoneValidator,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              categoriesAsync.when(
                                loading: () => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: LinearProgressIndicator(),
                                ),
                                error: (error, _) => StoreCategoryDropdown(
                                  value: _category,
                                  items: const [('salon', 'Salon')],
                                  onChanged: (v) =>
                                      setState(() => _category = v ?? 'salon'),
                                ),
                                data: (items) => StoreCategoryDropdown(
                                  value: items.any((c) => c.slug == _category)
                                      ? _category
                                      : items.first.slug,
                                  items: items
                                      .map((c) => (c.slug, c.name))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _category = v ?? 'salon'),
                                ),
                              ),
                              const SizedBox(height: 14),
                              StoreFormField(
                                controller: _descriptionCtrl,
                                label: 'Description',
                                icon: Icons.description_outlined,
                                maxLines: 4,
                                minLines: 3,
                                hint: 'About this store, services, specialties...',
                                textInputAction: TextInputAction.newline,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        StoreFormSection(
                          title: 'Location & Map',
                          icon: Icons.location_on_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (mapsKey == null)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.warning.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'Add GOOGLE_MAPS_API_KEY to pakeup_store_app/.env '
                                    'to enable map search and location picker.',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                )
                              else
                                StoreLocationPicker(
                                  apiKey: mapsKey,
                                  latitude: _latitude,
                                  longitude: _longitude,
                                  initialAddress: _addressCtrl.text,
                                  city: _cityCtrl.text,
                                  state: _stateCtrl.text,
                                  onLocationChanged: _onLocationChanged,
                                ),
                              const SizedBox(height: 14),
                              StoreFormField(
                                controller: _addressCtrl,
                                label: 'Full Address',
                                icon: Icons.home_outlined,
                                maxLines: 2,
                                minLines: 1,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              StoreFieldRow(
                                breakpoint: 280,
                                spacing: 8,
                                children: [
                                  StoreFormField(
                                    controller: _cityCtrl,
                                    label: 'City',
                                    icon: Icons.location_city_outlined,
                                    compact: true,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  StoreFormField(
                                    controller: _stateCtrl,
                                    label: 'State',
                                    icon: Icons.map_outlined,
                                    compact: true,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  StoreFormField(
                                    controller: _pincodeCtrl,
                                    label: 'Pincode',
                                    icon: Icons.pin_drop_outlined,
                                    compact: true,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        StoreFormSection(
                          title: 'Opening Hours',
                          icon: Icons.access_time_rounded,
                          child: StoreOpenHoursSection(
                            schedules: _schedules,
                            onChanged: (v) => setState(() => _schedules = v),
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
