import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../models/store_location_data.dart';
import '../models/store_models.dart';
import '../models/store_schedule_models.dart';
import '../providers/stores_provider.dart';
import '../widgets/store_form_fields.dart';
import '../widgets/store_location_picker.dart';
import '../widgets/store_open_hours_section.dart';

class AddStoreScreen extends ConsumerStatefulWidget {
  const AddStoreScreen({super.key});

  @override
  ConsumerState<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends ConsumerState<AddStoreScreen>
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
  bool _whatsappSameAsPhone = false;
  bool _syncingWhatsapp = false;
  double _keyboardInset = 0;
  List<DaySchedule> _schedules = DaySchedule.defaults();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phoneCtrl.addListener(_syncWhatsappFromPhone);
    _whatsappCtrl.addListener(_onWhatsappManualEdit);
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

  String? _normalizePhone(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  String? _accountPhone(PartnerUser user) =>
      _normalizePhone(user.phone) ?? _normalizePhone(user.loginId);

  void _fillFromParentAccount(PartnerUser user) {
    final phone = _accountPhone(user);
    if (phone == null || phone.isEmpty) {
      AppSnackBar.warning(context, 'No contact number on your account.');
      return;
    }

    final accountWhatsapp = _normalizePhone(user.whatsapp);
    final sameAsPhone =
        accountWhatsapp == null || accountWhatsapp == phone;

    _syncingWhatsapp = true;
    _phoneCtrl.text = phone;
    _whatsappSameAsPhone = sameAsPhone;
    _whatsappCtrl.text = sameAsPhone ? phone : accountWhatsapp;
    _syncingWhatsapp = false;

    setState(() {});
    AppSnackBar.success(
      context,
      'Store contact details pre-filled from parent account!',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _phoneCtrl.removeListener(_syncWhatsappFromPhone);
    _whatsappCtrl.removeListener(_onWhatsappManualEdit);
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


  void _syncWhatsappFromPhone() {
    if (!_whatsappSameAsPhone || _syncingWhatsapp) return;
    final phone = _phoneCtrl.text;
    if (_whatsappCtrl.text == phone) return;
    _syncingWhatsapp = true;
    _whatsappCtrl.text = phone;
    _syncingWhatsapp = false;
  }

  void _onWhatsappManualEdit() {
    if (_syncingWhatsapp || !_whatsappSameAsPhone) return;
    if (_whatsappCtrl.text != _phoneCtrl.text) {
      setState(() => _whatsappSameAsPhone = false);
    }
  }

  void _setWhatsappSameAsPhone(bool value) {
    setState(() {
      _whatsappSameAsPhone = value;
      if (value) {
        _syncingWhatsapp = true;
        _whatsappCtrl.text = _phoneCtrl.text;
        _syncingWhatsapp = false;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
    if (!mounted) return;
    if (loginPass == null || loginPass.isEmpty) {
      AppSnackBar.error(
        context,
        'Session expired. Please log out and log in again.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final repo = ref.read(storesRepositoryProvider);
      await repo.addStore(
        accountId: user.id,
        loginPass: loginPass,
        ownerName: user.ownerName,
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
      if (mounted) {
        AppSnackBar.success(context, 'Store added successfully!');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to add store: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useParentContact(PartnerUser user) => _fillFromParentAccount(user);

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final categoriesAsync = ref.watch(partnerCategoriesProvider);
    final mapsKey = Env.googleMapsApiKey;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: _AddStoreAppBar(profileId: user.profileId),
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
                          'Add Store',
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
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                    _ParentAccountCard(
                      ownerName: user.ownerName,
                      phone: user.phone ?? user.loginId,
                      email: user.email,
                      profileId: user.profileId,
                      storeCount: user.storeCount,
                      onUseContact: () => _useParentContact(user),
                    ),
                    const SizedBox(height: 14),
                    StoreFormSection(
                      title: 'Store Contact Details',
                      subtitle: 'Phone and WhatsApp for this store',
                      child: Column(
                        children: [
                          StoreFieldRow(
                            children: [
                              StoreFormField(
                                controller: _phoneCtrl,
                                label: 'Phone',
                                icon: Icons.phone_outlined,
                                required: true,
                                hint: '10 digit number',
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
                                hint: '10 digit number',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                readOnly: _whatsappSameAsPhone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: _phoneValidator,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _SameAsPhoneToggle(
                            value: _whatsappSameAsPhone,
                            onChanged: _setWhatsappSameAsPhone,
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
                              items: items.map((c) => (c.slug, c.name)).toList(),
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
                                  color:
                                      AppColors.warning.withValues(alpha: 0.3),
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
      ),
    );
  }

  String? _phoneValidator(String? v) {
    if (v?.trim().isEmpty == true) return 'Required';
    if (v!.trim().length != 10) return 'Enter 10 digits';
    return null;
  }
}

class _AddStoreAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AddStoreAppBar({this.profileId});

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
            'Add Store',
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

// ── Same as phone toggle ────────────────────────────────────────────────────────

class _SameAsPhoneToggle extends StatelessWidget {
  const _SameAsPhoneToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? AppColors.primary.withValues(alpha: 0.06)
          : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'WhatsApp same as phone number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (value)
                Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Parent account card ───────────────────────────────────────────────────────

class _ParentAccountCard extends StatelessWidget {
  const _ParentAccountCard({
    required this.ownerName,
    required this.phone,
    this.email,
    this.profileId,
    required this.storeCount,
    required this.onUseContact,
  });

  final String ownerName;
  final String phone;
  final String? email;
  final String? profileId;
  final int storeCount;
  final VoidCallback onUseContact;

  @override
  Widget build(BuildContext context) {
    final id = profileId?.trim();

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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: Text(
                    ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ownerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (id != null && id.isNotEmpty)
                  Text(
                    'Profile ID: $id',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (id != null && id.isNotEmpty) const SizedBox(height: 4),
                Text(
                  '$storeCount store${storeCount == 1 ? '' : 's'} on this account',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: onUseContact,
                    icon: const Icon(Icons.copy_all_rounded, size: 16),
                    label: const Text(
                      'Use parent contact',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
    );
  }
}
