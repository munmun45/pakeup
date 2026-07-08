import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';
import '../../stores/widgets/store_form_fields.dart';
import '../data/kyc_repository.dart';
import '../models/kyc_models.dart';
import '../providers/kyc_provider.dart';
import '../utils/kyc_document_limits.dart';
import '../widgets/kyc_form_sections.dart';

const kKycDocuments = [
  _DocInfo(
    key: 'aadhaar',
    label: 'Aadhaar',
    shortLabel: 'AD',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF1565C0),
    required: true,
  ),
  _DocInfo(
    key: 'pan',
    label: 'PAN Card',
    shortLabel: 'PAN',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFF6A1B9A),
    required: true,
  ),
  _DocInfo(
    key: 'agreement',
    label: 'Agreement',
    shortLabel: 'AGR',
    icon: Icons.description_outlined,
    color: Color(0xFF5C6BC0),
    required: false,
  ),
  _DocInfo(
    key: 'gst',
    label: 'GST Certificate',
    shortLabel: 'GST',
    icon: Icons.receipt_rounded,
    color: Color(0xFF00695C),
    required: false,
  ),
  _DocInfo(
    key: 'other',
    label: 'Other Document',
    shortLabel: 'OTH',
    icon: Icons.attach_file_rounded,
    color: Color(0xFFE65100),
    required: false,
  ),
];

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key, this.storeId});
  final String? storeId;

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _picker = ImagePicker();
  final _panCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _otherDocNameCtrl = TextEditingController();
  String? _selectedStoreId;
  String? _propertyType;
  bool _propertyTypeError = false;
  String? _loadedFormKey;
  bool _showStorePicker = true;
  bool _loading = false;

  final Map<String, File?> _localFiles = {
    'aadhaar': null,
    'pan': null,
    'agreement': null,
    'gst': null,
    'other': null,
  };

  final Set<String> _clearedServerDocs = {};

  static const _docs = kKycDocuments;

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.storeId;
    if (widget.storeId != null) _showStorePicker = false;
  }

  @override
  void dispose() {
    _panCtrl.dispose();
    _aadhaarCtrl.dispose();
    _otherDocNameCtrl.dispose();
    super.dispose();
  }

  void _resetFormState() {
    _propertyType = null;
    _propertyTypeError = false;
    _panCtrl.clear();
    _aadhaarCtrl.clear();
    _otherDocNameCtrl.clear();
    _loadedFormKey = null;
  }

  void _syncFormFromKyc(StoreKycRecord? kyc, String storeId) {
    final formKey = '$storeId-${kyc?.id ?? 'new'}';
    if (_loadedFormKey == formKey) return;
    _loadedFormKey = formKey;
    _propertyType = kyc?.propertyType;
    _panCtrl.text = kyc?.panNumber ?? '';
    _aadhaarCtrl.text = kyc?.aadhaarNumber ?? '';
    _otherDocNameCtrl.text = kyc?.otherDocName ?? '';
  }

  void _resetDocState() {
    for (final key in _localFiles.keys) {
      _localFiles[key] = null;
    }
    _clearedServerDocs.clear();
  }

  void _onStoreChanged(String? storeId) {
    if (storeId == null) return;
    setState(() {
      _selectedStoreId = storeId;
      _showStorePicker = false;
      _resetDocState();
      _resetFormState();
    });
    ref.invalidate(storeKycProvider(storeId));
  }

  void _backToStoreList() {
    setState(() {
      _showStorePicker = true;
      _selectedStoreId = null;
      _resetDocState();
      _resetFormState();
    });
  }

  bool _canEditKyc(StoreRecord store, StoreKycRecord? kyc) {
    if (store.kycStatus == 'approved') return false;
    if (store.kycStatus == 'rejected') return true;
    return kyc?.submittedAt == null;
  }

  StoreRecord? _findStore(List<StoreRecord> stores, String? id) {
    if (id == null) return null;
    for (final store in stores) {
      if (store.id == id) return store;
    }
    return null;
  }

  bool _hasDoc(String key, StoreKycRecord? kyc) {
    if (_localFiles[key] != null) return true;
    if (_clearedServerDocs.contains(key)) return false;
    return kyc?.hasDoc(key) ?? false;
  }

  String? _effectiveUrl(String key, StoreKycRecord? kyc) {
    if (_clearedServerDocs.contains(key)) return null;
    return kyc?.docUrl(key);
  }

  Future<void> _pickDocument(String key) async {
    if (_selectedStoreId == null) {
      AppSnackBar.warning(context, 'Please select a store first.');
      return;
    }

    final stores = ref.read(myStoresProvider).valueOrNull ?? [];
    final store = _findStore(stores, _selectedStoreId);
    final kyc = ref.read(storeKycProvider(_selectedStoreId!)).valueOrNull;
    if (store != null && !_canEditKyc(store, kyc)) {
      AppSnackBar.warning(
        context,
        'KYC already submitted. You cannot change documents now.',
      );
      return;
    }

    final action = await _showUploadDialog();
    if (action == null || !mounted) return;

    try {
      File? picked;
      switch (action) {
        case _UploadAction.camera:
          final xFile = await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
            maxWidth: 1200,
          );
          if (xFile != null) picked = File(xFile.path);
        case _UploadAction.gallery:
          final xFile = await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 1200,
          );
          if (xFile != null) picked = File(xFile.path);
        case _UploadAction.file:
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            allowMultiple: false,
            withData: false,
          );
          final path = result?.files.isNotEmpty == true
              ? result!.files.first.path
              : null;
          if (path != null) picked = File(path);
      }

      if (!mounted) return;
      if (picked != null) {
        final docType = KycDocType.values.firstWhere((t) => t.key == key);
        final sizeError = await KycDocumentLimits.validatePath(
          picked.path,
          docType,
        );
        if (!mounted) return;
        if (sizeError != null) {
          AppSnackBar.warning(context, sizeError);
          return;
        }
        setState(() {
          _localFiles[key] = picked;
          _clearedServerDocs.remove(key);
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not pick file: $e');
      }
    }
  }

  Future<_UploadAction?> _showUploadDialog() async {
    return showModalBottomSheet<_UploadAction>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Upload Document',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'JPG, PNG or PDF · Max 1 MB (Agreement: 2 MB)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A1976D2),
                child: Icon(Icons.camera_alt_rounded, color: Color(0xFF1976D2)),
              ),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, _UploadAction.camera),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AE91E8C),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Choose Photo'),
              onTap: () => Navigator.pop(ctx, _UploadAction.gallery),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AFF7043),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFE65100),
                ),
              ),
              title: const Text('Choose File (PDF)'),
              onTap: () => Navigator.pop(ctx, _UploadAction.file),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<({String accountId, String loginPass})?> _credentials() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final loginPass = await ref
        .read(authRepositoryProvider)
        .getStoredLoginPass();
    if (user == null || loginPass == null || loginPass.isEmpty) {
      if (mounted) {
        AppSnackBar.error(context, 'Session expired. Please log in again.');
      }
      return null;
    }
    return (accountId: user.id, loginPass: loginPass);
  }

  Future<String?> _resolveDocUrl({
    required KycRepository repo,
    required String storeId,
    required String key,
    required StoreKycRecord? kyc,
  }) async {
    final local = _localFiles[key];
    if (local != null) {
      return repo.uploadDocument(
        storeId: storeId,
        docType: KycDocType.values.firstWhere((t) => t.key == key),
        localPath: local.path,
      );
    }
    return _effectiveUrl(key, kyc);
  }

  Future<void> _submit(StoreKycRecord? kyc) async {
    final storeId = _selectedStoreId;
    if (storeId == null) {
      AppSnackBar.warning(context, 'Please select a store first.');
      return;
    }

    final stores = ref.read(myStoresProvider).valueOrNull ?? [];
    final store = _findStore(stores, storeId);
    if (store != null && !_canEditKyc(store, kyc)) {
      AppSnackBar.warning(
        context,
        'KYC already submitted. You cannot change documents now.',
      );
      return;
    }

    final missingRequired = _docs
        .where((d) => d.required && !_hasDoc(d.key, kyc))
        .map((d) => d.label)
        .toList();

    if (_propertyType == null) {
      setState(() => _propertyTypeError = true);
      AppSnackBar.error(context, 'Please select property type.');
      return;
    }

    final pan = _panCtrl.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      AppSnackBar.error(context, 'Enter a valid PAN number.');
      return;
    }

    final aadhaar = _aadhaarCtrl.text.trim();
    if (!RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      AppSnackBar.error(context, 'Enter a valid 12-digit Aadhaar number.');
      return;
    }

    if (missingRequired.isNotEmpty) {
      AppSnackBar.error(
        context,
        'Please upload: ${missingRequired.join(', ')}',
      );
      return;
    }

    if (_hasDoc('other', kyc) && _otherDocNameCtrl.text.trim().isEmpty) {
      AppSnackBar.error(context, 'Enter a name for the other document.');
      return;
    }

    final creds = await _credentials();
    if (!mounted || creds == null) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(kycRepositoryProvider);
      final data = StoreKycSubmitData(
        propertyType: _propertyType,
        panNumber: pan,
        aadhaarNumber: aadhaar,
        aadhaarDocUrl: await _resolveDocUrl(
          repo: repo,
          storeId: storeId,
          key: 'aadhaar',
          kyc: kyc,
        ),
        panDocUrl: await _resolveDocUrl(
          repo: repo,
          storeId: storeId,
          key: 'pan',
          kyc: kyc,
        ),
        agreementDocUrl: await _resolveDocUrl(
          repo: repo,
          storeId: storeId,
          key: 'agreement',
          kyc: kyc,
        ),
        gstDocUrl: await _resolveDocUrl(
          repo: repo,
          storeId: storeId,
          key: 'gst',
          kyc: kyc,
        ),
        otherDocUrl: await _resolveDocUrl(
          repo: repo,
          storeId: storeId,
          key: 'other',
          kyc: kyc,
        ),
        otherDocName: _otherDocNameCtrl.text.trim().isEmpty
            ? null
            : _otherDocNameCtrl.text.trim(),
      );

      await repo.saveStoreKyc(
        accountId: creds.accountId,
        loginPass: creds.loginPass,
        storeId: storeId,
        data: data,
      );

      ref.invalidate(storeKycProvider(storeId));
      ref.invalidate(myStoresProvider);
      ref.invalidate(storeDetailProvider(storeId));
      _resetDocState();

      if (mounted) {
        AppSnackBar.success(context, 'KYC documents submitted for review!');
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Submission failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshPage() async {
    ref.invalidate(myStoresProvider);
    await ref.read(myStoresProvider.future);
    final storeId = _selectedStoreId;
    if (storeId != null) {
      ref.invalidate(storeKycProvider(storeId));
      await ref.read(storeKycProvider(storeId).future);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);
    final profileId = ref.watch(authStateProvider).valueOrNull?.profileId?.trim();

    return storesAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _KycAppBar(title: 'KYC Verification', profileId: profileId),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _KycAppBar(title: 'KYC Verification', profileId: profileId),
        body: Center(child: Text('$e')),
      ),
      data: (stores) {
        final showStoreList =
            _showStorePicker || _selectedStoreId == null || stores.isEmpty;
        final selectedStore = _findStore(stores, _selectedStoreId);
        final kycAsync = _selectedStoreId == null
            ? null
            : ref.watch(storeKycProvider(_selectedStoreId!));

        final kyc = kycAsync?.valueOrNull;
        if (_selectedStoreId != null) {
          _syncFormFromKyc(kyc, _selectedStoreId!);
        }
        final uploadedCount = _docs.where((d) => _hasDoc(d.key, kyc)).length;
        final requiredDone = _docs
            .where((d) => d.required && _hasDoc(d.key, kyc))
            .length;
        final requiredTotal = _docs.where((d) => d.required).length;

        final canEditKyc =
            selectedStore != null && _canEditKyc(selectedStore, kyc);
        final showSubmitBar =
            !showStoreList && canEditKyc && kycAsync?.isLoading != true;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _KycAppBar(
            title: showStoreList
                ? 'KYC Verification'
                : selectedStore!.businessName,
            profileId: profileId,
            subtitle: showStoreList
                ? 'Select a store to upload KYC'
                : selectedStore!.categoryLabel,
            leading: !showStoreList && widget.storeId == null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _backToStoreList,
                  )
                : null,
          ),
          bottomNavigationBar: showSubmitBar
              ? _KycSubmitBar(loading: _loading, onSubmit: () => _submit(kyc))
              : null,
          body: pullToRefresh(
            onRefresh: _refreshPage,
            child: showStoreList
                ? _KycStoreList(stores: stores, onSelectStore: _onStoreChanged)
                : SingleChildScrollView(
                    physics: alwaysScrollablePhysics,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      showSubmitBar ? 100 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (selectedStore != null) ...[
                          _KycStoreSummaryCard(store: selectedStore),
                          const SizedBox(height: 14),
                          _KycStatusCard(status: selectedStore.kycStatus),
                          const SizedBox(height: 14),
                          if (kycAsync?.isLoading == true)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else ...[
                            KycStepSection(
                              step: '1',
                              title: 'Property Type',
                              subtitle:
                                  'Select how the business premises is held',
                              required: true,
                              child: KycPropertyTypeSelector(
                                value: _propertyType,
                                showError: _propertyTypeError,
                                onChanged: canEditKyc
                                    ? (value) => setState(() {
                                        _propertyType = value;
                                        _propertyTypeError = false;
                                      })
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 14),
                            KycStepSection(
                              step: '2',
                              title: 'Identity Details',
                              subtitle: 'PAN and Aadhaar numbers',
                              child: StoreFieldRow(
                                children: [
                                  StoreFormField(
                                    controller: _panCtrl,
                                    label: 'PAN Number',
                                    icon: Icons.badge_outlined,
                                    required: true,
                                    hint: 'FGHIJ5678K',
                                    readOnly: !canEditKyc,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[A-Za-z0-9]'),
                                      ),
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                  ),
                                  StoreFormField(
                                    controller: _aadhaarCtrl,
                                    label: 'Aadhaar Number',
                                    icon: Icons.fingerprint,
                                    required: true,
                                    hint: '987654321098',
                                    keyboardType: TextInputType.number,
                                    readOnly: !canEditKyc,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(12),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _ProgressCard(
                              uploaded: uploadedCount,
                              total: _docs.length,
                              requiredDone: requiredDone,
                              requiredTotal: requiredTotal,
                            ),
                            const SizedBox(height: 14),
                            ..._docs.expand((doc) sync* {
                              if (doc.key == 'other') {
                                yield Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: StoreFormField(
                                    controller: _otherDocNameCtrl,
                                    label: 'Other Document Name',
                                    icon: Icons.label_outline_rounded,
                                    hint: 'e.g. Trade License, FSSAI...',
                                    readOnly: !canEditKyc,
                                  ),
                                );
                              }
                              yield Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DocUploadCard(
                                  doc: doc,
                                  localFile: _localFiles[doc.key],
                                  remoteUrl: _effectiveUrl(doc.key, kyc),
                                  uploaded: _hasDoc(doc.key, kyc),
                                  locked: !canEditKyc,
                                  documentName: doc.key == 'other'
                                      ? _otherDocNameCtrl.text.trim()
                                      : null,
                                  onTap: canEditKyc
                                      ? () => _pickDocument(doc.key)
                                      : null,
                                  onRemove: canEditKyc
                                      ? () => setState(() {
                                          _localFiles[doc.key] = null;
                                          if (kyc?.hasDoc(doc.key) == true) {
                                            _clearedServerDocs.add(doc.key);
                                          }
                                          if (doc.key == 'other') {
                                            _otherDocNameCtrl.clear();
                                          }
                                        })
                                      : null,
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _KycAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _KycAppBar({
    required this.title,
    this.profileId,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? profileId;
  final String? subtitle;
  final Widget? leading;

  @override
  Size get preferredSize {
    final hasSubtitle = subtitle?.trim().isNotEmpty == true;
    final hasId = profileId?.trim().isNotEmpty == true;
    if (hasSubtitle || hasId) return const Size.fromHeight(56);
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    final id = profileId?.trim();
    final sub = subtitle?.trim();

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      toolbarHeight: preferredSize.height,
      leading: leading,
      automaticallyImplyLeading: leading == null,
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
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          if (sub != null && sub.isNotEmpty)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            )
          else if (id != null && id.isNotEmpty)
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

class _KycStoreList extends StatelessWidget {
  const _KycStoreList({required this.stores, required this.onSelectStore});

  final List<StoreRecord> stores;
  final ValueChanged<String> onSelectStore;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return ListView(
        physics: alwaysScrollablePhysics,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 72,
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No stores yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add a store first, then upload KYC documents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: alwaysScrollablePhysics,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ...stores.map(
          (store) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _KycStorePickerCard(
              store: store,
              onTap: () => onSelectStore(store.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _KycStorePickerCard extends ConsumerWidget {
  const _KycStorePickerCard({required this.store, required this.onTap});

  final StoreRecord store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycAsync = ref.watch(storeKycProvider(store.id));
    final kyc = kycAsync.valueOrNull;
    final uploaded = kKycDocuments
        .where((d) => kyc?.hasDoc(d.key) ?? false)
        .length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 7),
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
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  ),
                ),
                child: Row(
                  children: [
                    _KycStoreAvatar(name: store.businessName),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        store.kycLabel.replaceFirst('KYC ', ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            store.addressLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!kycAsync.isLoading) ...[
                      const SizedBox(height: 10),
                      _KycIdentitySummary(
                        propertyType: kyc?.propertyType,
                        panNumber: kyc?.panNumber,
                        aadhaarNumber: kyc?.aadhaarNumber,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.85),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                child: kycAsync.isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _KycDocChipRow(
                        kyc: kyc,
                        uploaded: uploaded,
                        total: kKycDocuments.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycIdentitySummary extends StatelessWidget {
  const _KycIdentitySummary({
    required this.propertyType,
    required this.panNumber,
    required this.aadhaarNumber,
  });

  final String? propertyType;
  final String? panNumber;
  final String? aadhaarNumber;

  String _propertyLabel(String? value) => switch (value?.toLowerCase()) {
    'own' => 'Own',
    'lease' => 'Lease',
    'rent' => 'Rent',
    _ => 'Not set',
  };

  String _textOrUnset(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Not set';
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Column(
        children: [
          _KycIdentityRow(
            icon: Icons.home_work_outlined,
            label: 'Property',
            value: _propertyLabel(propertyType),
            highlight: propertyType != null,
          ),
          const SizedBox(height: 8),
          _KycIdentityRow(
            icon: Icons.badge_outlined,
            label: 'PAN',
            value: _textOrUnset(panNumber),
            highlight: panNumber?.trim().isNotEmpty == true,
          ),
          const SizedBox(height: 8),
          _KycIdentityRow(
            icon: Icons.fingerprint_rounded,
            label: 'Aadhaar',
            value: _textOrUnset(aadhaarNumber),
            highlight: aadhaarNumber?.trim().isNotEmpty == true,
          ),
        ],
      ),
    );
  }
}

class _KycIdentityRow extends StatelessWidget {
  const _KycIdentityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.highlight,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final isUnset = value == 'Not set';
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: highlight ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isUnset
                  ? AppColors.textSecondary.withValues(alpha: 0.65)
                  : AppColors.textPrimary,
              fontStyle: isUnset ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _KycDocChipRow extends StatelessWidget {
  const _KycDocChipRow({
    required this.kyc,
    required this.uploaded,
    required this.total,
  });

  final StoreKycRecord? kyc;
  final int uploaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$uploaded/$total uploaded',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kKycDocuments.map((doc) {
            final done = kyc?.hasDoc(doc.key) ?? false;
            return _KycDocChip(label: doc.shortLabel, done: done);
          }).toList(),
        ),
      ],
    );
  }
}

class _KycDocChip extends StatelessWidget {
  const _KycDocChip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_rounded : Icons.remove_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _KycSubmitBar extends StatelessWidget {
  const _KycSubmitBar({required this.loading, required this.onSubmit});

  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                onPressed: loading ? null : onSubmit,
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
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit KYC Documents',
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
    );
  }
}

class _KycStoreSummaryCard extends StatelessWidget {
  const _KycStoreSummaryCard({required this.store});

  final StoreRecord store;

  @override
  Widget build(BuildContext context) {
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
                  _KycStoreAvatar(name: store.businessName),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      store.kycLabel.replaceFirst('KYC ', ''),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
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
}

class _KycStoreAvatar extends StatelessWidget {
  const _KycStoreAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _DocInfo {
  const _DocInfo({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
    required this.required,
  });
  final String key;
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
  final bool required;
}

class _KycStatusCard extends StatelessWidget {
  const _KycStatusCard({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, body) = switch (status) {
      'approved' => (
        AppColors.success,
        Icons.verified_rounded,
        'KYC Approved',
        'This store\'s KYC documents are verified.',
      ),
      'rejected' => (
        AppColors.error,
        Icons.cancel_rounded,
        'KYC Rejected',
        'Documents were rejected. Please re-upload correct documents.',
      ),
      _ => (
        AppColors.warning,
        Icons.pending_rounded,
        'KYC Pending',
        'Documents are under review for this store.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.uploaded,
    required this.total,
    required this.requiredDone,
    required this.requiredTotal,
  });
  final int uploaded;
  final int total;
  final int requiredDone;
  final int requiredTotal;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? uploaded / total : 0.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 5),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload Progress',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    '$uploaded / $total',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Required: $requiredDone / $requiredTotal uploaded',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocUploadCard extends StatelessWidget {
  const _DocUploadCard({
    required this.doc,
    required this.localFile,
    required this.remoteUrl,
    required this.uploaded,
    required this.locked,
    required this.onTap,
    required this.onRemove,
    this.documentName,
  });
  final _DocInfo doc;
  final File? localFile;
  final String? remoteUrl;
  final bool uploaded;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? documentName;

  bool get _isPdf {
    final local = localFile?.path.toLowerCase() ?? '';
    final remote = remoteUrl?.toLowerCase() ?? '';
    return local.endsWith('.pdf') || remote.contains('.pdf');
  }

  KycDocType get _docType =>
      KycDocType.values.firstWhere((t) => t.key == doc.key);

  String get _maxSizeLabel => KycDocumentLimits.maxSizeLabel(_docType);

  String get _statusText {
    if (!uploaded) {
      return locked ? 'Not uploaded' : 'Tap to upload photo or PDF';
    }
    if (localFile != null) {
      final customName = documentName?.trim();
      if (customName != null && customName.isNotEmpty) return customName;
      final name = localFile!.path.split(Platform.pathSeparator).last;
      return name;
    }
    if (documentName?.trim().isNotEmpty == true) {
      return '${documentName!.trim()} uploaded ✓';
    }
    return _isPdf ? 'PDF uploaded ✓' : 'Document uploaded ✓';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: uploaded
                ? AppColors.success.withValues(alpha: 0.45)
                : Colors.white,
            width: uploaded ? 1.5 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: doc.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            uploaded && _isPdf ? Icons.picture_as_pdf_rounded : doc.icon,
            color: doc.color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                doc.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (doc.required)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: uploaded ? AppColors.success : AppColors.textSecondary,
                fontWeight: uploaded ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Max $_maxSizeLabel',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: locked
            ? (uploaded
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 22,
                    )
                  : null)
            : uploaded
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
                onPressed: onRemove,
              )
            : IconButton(
                icon: const Icon(
                  Icons.upload_rounded,
                  color: AppColors.primary,
                ),
                onPressed: onTap,
              ),
        onTap: locked ? null : onTap,
        ),
      ),
    );
  }
}

enum _UploadAction { camera, gallery, file }
