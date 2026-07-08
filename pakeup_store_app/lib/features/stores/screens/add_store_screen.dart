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
      AppSnackBar.show(context, 'No contact number on your account.');
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
      appBar: AppBar(
        title: const Text('Add Store'),
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
                        'Add Store',
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
      body: SingleChildScrollView(
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
                      title: 'Parent Account',
                      icon: Icons.account_circle_outlined,
                      child: _ParentAccountCard(
                        ownerName: user.ownerName,
                        phone: user.phone ?? user.loginId,
                        email: user.email,
                        storeCount: user.storeCount,
                        onUseContact: () => _useParentContact(user),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StoreFormSection(
                      title: 'Store Contact Details',
                      icon: Icons.badge_outlined,
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
                    const SizedBox(height: 12),
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
      ),
    );
  }

  String? _phoneValidator(String? v) {
    if (v?.trim().isEmpty == true) return 'Required';
    if (v!.trim().length != 10) return 'Enter 10 digits';
    return null;
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
    required this.storeCount,
    required this.onUseContact,
  });

  final String ownerName;
  final String phone;
  final String? email;
  final int storeCount;
  final VoidCallback onUseContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 11, color: AppColors.success),
                    SizedBox(width: 3),
                    Text(
                      'Selected',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$storeCount store${storeCount == 1 ? '' : 's'} on this account',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: onUseContact,
              icon: const Icon(Icons.copy_all_rounded, size: 14),
              label: const Text(
                'Use parent contact',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
