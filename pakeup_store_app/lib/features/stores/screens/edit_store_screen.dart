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
    final profileId = ref.watch(authStateProvider).valueOrNull?.profileId?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: _EditStoreAppBar(profileId: profileId),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white70,
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
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(storeDetailProvider(widget.storeId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (store) {
          _prefill(store);
          return SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EditStoreSummaryCard(store: store),
                  const SizedBox(height: 14),
                  StoreFormSection(
                    title: 'Store Contact Details',
                    subtitle: 'Phone and WhatsApp for this store',
                    child: StoreFieldRow(
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
                  ),
                  const SizedBox(height: 14),
                  StoreFormSection(
                    title: 'Store Information',
                    subtitle: 'Business name, category, and description',
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
                  const SizedBox(height: 14),
                  StoreFormSection(
                    title: 'Location & Map',
                    subtitle: 'Pin your store on the map and enter address',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mapsKey == null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
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
                  const SizedBox(height: 14),
                  StoreFormSection(
                    title: 'Opening Hours',
                    subtitle: 'When customers can visit or book',
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

class _EditStoreAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditStoreAppBar({this.profileId});

  final String? profileId;

  @override
  Size get preferredSize {
    final hasId = profileId?.trim().isNotEmpty == true;
    return Size.fromHeight(hasId ? 56 : kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    final id = profileId?.trim();

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      toolbarHeight: preferredSize.height,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Edit Store',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          if (id != null && id.isNotEmpty)
            Text(
              'Profile ID: $id',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _EditStoreSummaryCard extends StatelessWidget {
  const _EditStoreSummaryCard({required this.store});

  final StoreRecord store;

  @override
  Widget build(BuildContext context) {
    final imageUrl = store.primaryImage ??
        (store.images.isNotEmpty ? store.images.first : null);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: 50,
                              height: 50,
                              errorBuilder: (_, e, s) => _fallback(),
                            )
                          : _fallback(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          store.categoryLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                store.addressLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.22),
      child: Center(
        child: Text(
          store.businessName.isNotEmpty
              ? store.businessName[0].toUpperCase()
              : 'S',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
