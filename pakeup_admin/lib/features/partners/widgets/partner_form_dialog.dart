import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/field_validators.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partner_categories_repository.dart';
import '../data/partners_repository.dart';
import '../models/partner_location_data.dart';
import '../providers/partner_categories_provider.dart';
import '../providers/partners_provider.dart';
import '../utils/partner_map_utils.dart';
import 'partner_form_field.dart';
import 'partner_location_picker.dart';

class PartnerFormDialog extends ConsumerStatefulWidget {
  const PartnerFormDialog({
    super.key,
    this.existing,
    this.storeOnlyMode = false,
  });

  final PartnerRecord? existing;
  final bool storeOnlyMode;

  @override
  ConsumerState<PartnerFormDialog> createState() => _PartnerFormDialogState();
}

class _PartnerFormDialogState extends ConsumerState<PartnerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _alternatePhoneCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _mapEmbedCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _notesCtrl;
  String? _category;
  bool _useExistingAccount = false;
  String? _selectedAccountId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _businessCtrl = TextEditingController(text: e?.businessName ?? '');
    _ownerCtrl = TextEditingController(text: e?.ownerName ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _whatsappCtrl = TextEditingController(text: e?.whatsapp ?? '');
    _alternatePhoneCtrl = TextEditingController(text: e?.alternatePhone ?? '');
    _websiteCtrl = TextEditingController(text: e?.website ?? '');
    _gstCtrl = TextEditingController(text: e?.gstNumber ?? '');
    _cityCtrl = TextEditingController(text: e?.city ?? '');
    _stateCtrl = TextEditingController(text: e?.state ?? '');
    _pincodeCtrl = TextEditingController(text: e?.pincode ?? '');
    _addressCtrl = TextEditingController(text: e?.addressLine ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _mapEmbedCtrl = TextEditingController(text: e?.googleMapEmbed ?? '');
    _latCtrl = TextEditingController(text: e?.latitude?.toString() ?? '');
    _lngCtrl = TextEditingController(text: e?.longitude?.toString() ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _category = e?.category;
    if (widget.storeOnlyMode && widget.existing == null) {
      _useExistingAccount = true;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _businessCtrl,
      _ownerCtrl,
      _phoneCtrl,
      _emailCtrl,
      _whatsappCtrl,
      _alternatePhoneCtrl,
      _websiteCtrl,
      _gstCtrl,
      _cityCtrl,
      _stateCtrl,
      _pincodeCtrl,
      _addressCtrl,
      _descriptionCtrl,
      _mapEmbedCtrl,
      _latCtrl,
      _lngCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _latitude => PartnerMapUtils.parseCoordinate(_latCtrl.text);
  double? get _longitude => PartnerMapUtils.parseCoordinate(_lngCtrl.text);

  PartnerFormData? _buildFormData() {
    if (_category == null || _category!.isEmpty) return null;

    final lat = _latitude;
    final lng = _longitude;

    return PartnerFormData(
      businessName: _businessCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim(),
      accountId: _useExistingAccount ? _selectedAccountId : null,
      phone: _emptyToNull(_phoneCtrl.text),
      email: _emptyToNull(_emailCtrl.text),
      whatsapp: _emptyToNull(_whatsappCtrl.text),
      alternatePhone: _emptyToNull(_alternatePhoneCtrl.text),
      website: _emptyToNull(_websiteCtrl.text),
      gstNumber: _emptyToNull(_gstCtrl.text),
      city: _emptyToNull(_cityCtrl.text),
      state: _emptyToNull(_stateCtrl.text),
      pincode: _emptyToNull(_pincodeCtrl.text),
      category: _category!,
      addressLine: _emptyToNull(_addressCtrl.text),
      description: _emptyToNull(_descriptionCtrl.text),
      googleMapEmbed: lat != null && lng != null
          ? PartnerMapUtils.buildEmbedFromCoords(lat, lng)
          : _emptyToNull(_mapEmbedCtrl.text),
      latitude: lat,
      longitude: lng,
      notes: _emptyToNull(_notesCtrl.text),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) {
      AppSnackBar.error(context, 'Please fill all required fields');
      return;
    }

    if (_category == null || _category!.isEmpty) {
      AppSnackBar.error(context, 'Please select a category');
      return;
    }

    final lat = _latitude;
    final lng = _longitude;
    if ((lat != null && lng == null) || (lat == null && lng != null)) {
      AppSnackBar.error(context, 'Enter both latitude and longitude');
      return;
    }

    if (_useExistingAccount && _selectedAccountId == null) {
      AppSnackBar.error(context, 'Please select a parent account');
      return;
    }

    final data = _buildFormData();
    if (data == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.error(context, 'Please sign in again');
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnersRepositoryProvider);
      final isEdit = widget.existing != null;

      if (isEdit) {
        await repo.updatePartner(
          callerId: user.id,
          partnerId: widget.existing!.id,
          data: data,
        );
      } else {
        await repo.createPartner(callerId: user.id, data: data);
      }

      if (!mounted) return;

      AppSnackBar.success(
        context,
        isEdit
            ? 'Partner "${data.businessName}" updated successfully'
            : 'Partner "${data.businessName}" added successfully',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.actionFailed(
          context,
          widget.existing == null ? 'add partner' : 'update partner',
          e,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _applyAccountFields({
    required String ownerName,
    String? phone,
    String? email,
    String? whatsapp,
    String? alternatePhone,
  }) {
    _ownerCtrl.text = ownerName;
    _phoneCtrl.text = phone ?? '';
    _emailCtrl.text = email ?? '';
    _whatsappCtrl.text = whatsapp ?? '';
    _alternatePhoneCtrl.text = alternatePhone ?? '';
  }

  void _applyLocation(PartnerLocationData location) {
    setState(() {
      _addressCtrl.text = location.address;
      _cityCtrl.text = location.city;
      _stateCtrl.text = location.state;
      _pincodeCtrl.text = location.pincode;
      _latCtrl.text = location.latitude.toStringAsFixed(6);
      _lngCtrl.text = location.longitude.toStringAsFixed(6);
    });
  }

  Widget _businessSection(List<PartnerCategory> categories) {
    final activeCategories =
        categories.where((c) => c.isActive).toList();

    if (_category == null && activeCategories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _category == null) {
          setState(() => _category = activeCategories.first.slug);
        }
      });
    }

    final categoryDropdown = activeCategories.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No categories found. Add categories from Partners → Partner Categories.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          )
        : PartnerFormDropdown<String>(
            label: 'Category',
            icon: Icons.category_outlined,
            value: _category ?? activeCategories.first.slug,
            items: [
              for (final c in activeCategories)
                DropdownMenuItem(value: c.slug, child: Text(c.name)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          );

    return PartnerFormSection(
      title: 'Store Information',
      icon: Icons.storefront_outlined,
      children: [
        PartnerFormField(
          label: 'Store / Business Name',
          icon: Icons.store_outlined,
          controller: _businessCtrl,
          required: true,
        ),
        categoryDropdown,
        PartnerFormField(
          label: 'Description',
          icon: Icons.description_outlined,
          controller: _descriptionCtrl,
          maxLines: 4,
          minLines: 4,
          hint: 'About this store, services, specialties...',
        ),
      ],
    );
  }

  Widget _accountSection(List<PartnerOwnerAccount> accounts, {required bool wide}) {
    final accountLocked = widget.existing != null ||
        (_useExistingAccount && _selectedAccountId != null);

    if (widget.storeOnlyMode &&
        widget.existing == null &&
        _selectedAccountId == null &&
        accounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final account = accounts.first;
        setState(() {
          _selectedAccountId = account.id;
          _applyAccountFields(
            ownerName: account.ownerName,
            phone: account.phone,
            email: account.email,
            whatsapp: account.whatsapp,
            alternatePhone: account.alternatePhone,
          );
        });
      });
    }

    return PartnerFormSection(
      title: widget.storeOnlyMode && widget.existing == null
          ? 'Parent Account'
          : 'Account Information',
      icon: Icons.account_circle_outlined,
      children: [
        if (widget.existing == null && !widget.storeOnlyMode) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add store to existing account'),
            subtitle: const Text(
              'Use when one owner already has another store on PakeUp',
            ),
            value: _useExistingAccount,
            onChanged: (value) {
              setState(() {
                _useExistingAccount = value;
                if (!value) {
                  _selectedAccountId = null;
                } else if (accounts.isNotEmpty) {
                  _selectedAccountId = accounts.first.id;
                  final account = accounts.first;
                  _applyAccountFields(
                    ownerName: account.ownerName,
                    phone: account.phone,
                    email: account.email,
                    whatsapp: account.whatsapp,
                    alternatePhone: account.alternatePhone,
                  );
                }
              });
            },
          ),
          if (_useExistingAccount && accounts.isNotEmpty) ...[
            PartnerFormDropdown<String>(
              label: 'Existing Account',
              icon: Icons.people_outline,
              value: _selectedAccountId ?? accounts.first.id,
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.displayLabel),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                final account =
                    accounts.firstWhere((a) => a.id == value);
                setState(() {
                  _selectedAccountId = value;
                  _applyAccountFields(
                    ownerName: account.ownerName,
                    phone: account.phone,
                    email: account.email,
                    whatsapp: account.whatsapp,
                    alternatePhone: account.alternatePhone,
                  );
                });
              },
            ),
          ],
          if (_useExistingAccount && accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No accounts yet. Turn off the switch above to create a new account.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          if (_useExistingAccount) const SizedBox(height: 8),
        ],
        if (widget.storeOnlyMode && widget.existing == null) ...[
          if (accounts.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'No parent accounts yet. Create a parent account first, then add a store.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            )
          else
            PartnerFormDropdown<String>(
              label: 'Parent Account',
              icon: Icons.people_outline,
              value: _selectedAccountId ?? accounts.first.id,
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.displayLabel),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                final account =
                    accounts.firstWhere((a) => a.id == value);
                setState(() {
                  _selectedAccountId = value;
                  _applyAccountFields(
                    ownerName: account.ownerName,
                    phone: account.phone,
                    email: account.email,
                    whatsapp: account.whatsapp,
                    alternatePhone: account.alternatePhone,
                  );
                });
              },
            ),
        ],
        if (!widget.storeOnlyMode || widget.existing != null) ...[
        PartnerFormField(
          label: 'Owner Name',
          icon: Icons.person_outline,
          controller: _ownerCtrl,
          required: true,
          readOnly: accountLocked && _useExistingAccount,
        ),
        if (wide)
          PartnerFormRow(
            children: [
              _phoneField(
                label: 'Phone',
                icon: Icons.phone_outlined,
                controller: _phoneCtrl,
                required: true,
                readOnly: accountLocked && _useExistingAccount,
              ),
              _emailField(readOnly: accountLocked && _useExistingAccount),
            ],
          )
        else ...[
          _phoneField(
            label: 'Phone',
            icon: Icons.phone_outlined,
            controller: _phoneCtrl,
            required: true,
            readOnly: accountLocked && _useExistingAccount,
          ),
          _emailField(readOnly: accountLocked && _useExistingAccount),
        ],
        if (wide)
          PartnerFormRow(
            children: [
              _phoneField(
                label: 'WhatsApp',
                icon: Icons.chat_outlined,
                controller: _whatsappCtrl,
                required: true,
                readOnly: accountLocked && _useExistingAccount,
              ),
              _phoneField(
                label: 'Alternate Phone',
                icon: Icons.phone_callback_outlined,
                controller: _alternatePhoneCtrl,
                readOnly: accountLocked && _useExistingAccount,
              ),
            ],
          )
        else ...[
          _phoneField(
            label: 'WhatsApp',
            icon: Icons.chat_outlined,
            controller: _whatsappCtrl,
            required: true,
            readOnly: accountLocked && _useExistingAccount,
          ),
          _phoneField(
            label: 'Alternate Phone',
            icon: Icons.phone_callback_outlined,
            controller: _alternatePhoneCtrl,
            readOnly: accountLocked && _useExistingAccount,
          ),
        ],
        ],
        if (accountLocked && _useExistingAccount && !widget.storeOnlyMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Account details are shared across all stores for this owner.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.95),
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _phoneField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool required = false,
    bool readOnly = false,
  }) {
    return PartnerFormField(
      label: label,
      icon: icon,
      controller: controller,
      required: required,
      readOnly: readOnly,
      keyboard: TextInputType.phone,
      hint: '10 digit number',
      inputFormatters: FieldValidators.phone10Formatters,
      validator: (v) =>
          FieldValidators.phone10(v, label: label, required: required),
    );
  }

  Widget _emailField({bool readOnly = false}) {
    return PartnerFormField(
      label: 'Email',
      icon: Icons.email_outlined,
      controller: _emailCtrl,
      keyboard: TextInputType.emailAddress,
      hint: 'name@example.com',
      readOnly: readOnly,
      validator: FieldValidators.email,
    );
  }

  Widget _storeDetailsSection({required bool wide}) {
    return PartnerFormSection(
      title: 'Store Details',
      icon: Icons.receipt_long_outlined,
      children: [
        if (wide)
          PartnerFormRow(
            children: [
              PartnerFormField(
                label: 'Website',
                icon: Icons.language_outlined,
                controller: _websiteCtrl,
              ),
              PartnerFormField(
                label: 'GST Number',
                icon: Icons.receipt_long_outlined,
                controller: _gstCtrl,
              ),
            ],
          )
        else ...[
          PartnerFormField(
            label: 'Website',
            icon: Icons.language_outlined,
            controller: _websiteCtrl,
          ),
          PartnerFormField(
            label: 'GST Number',
            icon: Icons.receipt_long_outlined,
            controller: _gstCtrl,
          ),
        ],
        const SizedBox(height: 4),
        const Divider(height: 24),
        PartnerFormField(
          label: 'Internal Notes',
          icon: Icons.notes_outlined,
          controller: _notesCtrl,
          maxLines: 3,
          minLines: 2,
          hint: 'Admin-only notes, special instructions, or extra details...',
        ),
      ],
    );
  }

  Widget _locationSection() {
    final mapsKey = Env.googleMapsApiKey;

    return PartnerFormSection(
      title: 'Location & Map',
      icon: Icons.location_on_outlined,
      children: [
        if (mapsKey != null)
          PartnerLocationPicker(
            apiKey: mapsKey,
            latitude: _latitude,
            longitude: _longitude,
            initialAddress: _addressCtrl.text,
            city: _cityCtrl.text,
            state: _stateCtrl.text,
            onLocationChanged: _applyLocation,
          )
        else
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'Add GOOGLE_MAPS_API_KEY to pakeup_admin/.env to enable map '
              'search and location picker.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 10),
        PartnerFormField(
          label: 'Full Address',
          icon: Icons.place_outlined,
          controller: _addressCtrl,
          compact: true,
          maxLines: 2,
          minLines: 1,
        ),
        PartnerFormRow(
          children: [
            PartnerFormField(
              label: 'City',
              icon: Icons.location_city_outlined,
              controller: _cityCtrl,
              compact: true,
            ),
            PartnerFormField(
              label: 'State',
              icon: Icons.map_outlined,
              controller: _stateCtrl,
              compact: true,
            ),
            PartnerFormField(
              label: 'Pincode',
              icon: Icons.pin_outlined,
              controller: _pincodeCtrl,
              keyboard: TextInputType.number,
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final size = MediaQuery.sizeOf(context);
    final categoriesAsync = ref.watch(partnerCategoriesListProvider);
    final accountsAsync = ref.watch(partnerOwnerAccountsListProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          children: [
            _Header(
              isEdit: isEdit,
              storeOnlyMode: widget.storeOnlyMode,
              onClose: _submitting ? null : () => Navigator.pop(context),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF3F4F6),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Form(
                    key: _formKey,
                    child: categoriesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(e.toString()),
                      data: (categories) => accountsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Text(e.toString()),
                        data: (accounts) => LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 720;

                            if (wide) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _accountSection(
                                          accounts,
                                          wide: true,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _businessSection(categories),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _storeDetailsSection(wide: true),
                                  const SizedBox(height: 16),
                                  _locationSection(),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                _accountSection(accounts, wide: false),
                                _businessSection(categories),
                                _storeDetailsSection(wide: false),
                                const SizedBox(height: 16),
                                _locationSection(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEdit ? Icons.save_outlined : Icons.add_rounded,
                          ),
                    label: Text(
                      _submitting
                          ? (isEdit ? 'Saving...' : 'Adding...')
                          : (isEdit ? 'Save Store' : 'Add Store'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isEdit,
    this.storeOnlyMode = false,
    this.onClose,
  });

  final bool isEdit;
  final bool storeOnlyMode;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 8, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_rounded,
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
                  isEdit
                      ? 'Edit Store'
                      : (storeOnlyMode ? 'Add New Store' : 'Add Store & Account'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  storeOnlyMode && !isEdit
                      ? 'Link a new store to an existing parent account'
                      : 'Account info is shared; each store has its own profile & location',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
