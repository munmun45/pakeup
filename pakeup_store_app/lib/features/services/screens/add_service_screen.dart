import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';
import '../../stores/widgets/store_form_fields.dart';
import '../../stores/widgets/store_select_dropdown_tile.dart';
import '../data/services_repository.dart';
import '../providers/services_provider.dart';

// ─── Category list ────────────────────────────────────────────────────────────

const _kCategories = [
  'Hair Care',
  'Skin Care',
  'Nail Care',
  'Makeup',
  'Massage',
  'Waxing',
  'Threading',
  'Facial',
  'Mehendi',
  'Others',
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddServiceScreen extends ConsumerStatefulWidget {
  const AddServiceScreen({super.key, this.initialStore});
  final StoreRecord? initialStore;

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedStoreId;
  String _category = 'Hair Care';

  // Media
  final List<File> _images = [];
  int _primaryImageIndex = 0;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.initialStore?.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      AppSnackBar.warning(context, 'Maximum 5 photos allowed.');
      return;
    }
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (xFile == null) return;
    setState(() => _images.add(File(xFile.path)));
  }

  Future<void> _pickImageCamera() async {
    if (_images.length >= 5) {
      AppSnackBar.warning(context, 'Maximum 5 photos allowed.');
      return;
    }
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (xFile == null) return;
    setState(() => _images.add(File(xFile.path)));
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_primaryImageIndex >= _images.length) {
        _primaryImageIndex = _images.isEmpty ? 0 : _images.length - 1;
      }
    });
  }

  void _setPrimary(int index) {
    setState(() => _primaryImageIndex = index);
  }

  Future<List<String>> _uploadImages(
      String storeId, SupabaseClient client) async {
    final urls = <String>[];
    for (final file in _images) {
      final bytes = await file.readAsBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'services/$storeId/image_$ts.jpg';
      await client.storage.from('partner-images').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      urls.add(client.storage.from('partner-images').getPublicUrl(path));
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStoreId == null) {
      AppSnackBar.error(context, 'Please select a store first.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      final loginPass =
          await ref.read(authRepositoryProvider).getStoredLoginPass();
      if (user == null || loginPass == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final client = ref.read(supabaseClientProvider);
      final imageUrls =
          _images.isNotEmpty ? await _uploadImages(_selectedStoreId!, client) : <String>[];

      final primaryUrl = imageUrls.isNotEmpty
          ? imageUrls[_primaryImageIndex.clamp(0, imageUrls.length - 1)]
          : null;

      final data = AddServiceData(
        name: _nameCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        serviceImageUrl: primaryUrl,
        primaryImageUrl: primaryUrl,
        images: imageUrls,
      );

      await ref.read(servicesRepositoryProvider).createService(
            accountId: user.id,
            loginPass: loginPass,
            storeId: _selectedStoreId!,
            data: data,
          );

      ref.invalidate(storeServicesProvider(_selectedStoreId!));
      ref.invalidate(myServicesProvider);

      if (mounted) {
        AppSnackBar.success(context, 'Service added successfully!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to add service: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);
    final approvedStores = storesAsync.valueOrNull
            ?.where((s) => s.isKycApproved)
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Service'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _submit,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ── Card 1: Store & Service Details ───────────────────────
            _Card(
              icon: Icons.storefront_rounded,
              title: 'Store & Service Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store selector
                  const _FieldLabel(
                    label: 'Select Store',
                    icon: Icons.store_outlined,
                    required: true,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStoreId != null &&
                            approvedStores
                                .any((s) => s.id == _selectedStoreId)
                        ? _selectedStoreId
                        : null,
                    isExpanded: true,
                    hint: const Text('Tap to select a store...'),
                    decoration: StoreFormField.decoration(
                            hint: 'Select store')
                        .copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      isDense: true,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    validator: (v) =>
                        v == null ? 'Please select a store' : null,
                    items: buildStoreDropdownItems(approvedStores,
                        kycApprovedOnly: true),
                    selectedItemBuilder: (context) => approvedStores
                        .map((s) => StoreSelectDropdownTile(
                            store: s, compact: true))
                        .toList(),
                    onChanged: (id) =>
                        setState(() => _selectedStoreId = id),
                  ),
                  const SizedBox(height: 14),
                  // Name + Category row
                  StoreFieldRow(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel(
                            label: 'Service Name',
                            icon: Icons.spa_outlined,
                            required: true,
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: StoreFormField.decoration(
                                hint: 'e.g. Haircut, Facial'),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                            textCapitalization:
                                TextCapitalization.words,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel(
                            label: 'Category',
                            icon: Icons.category_outlined,
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: StoreFormField.decoration(
                                hint: 'Category'),
                            borderRadius: BorderRadius.circular(12),
                            items: _kCategories
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c,
                                          style: const TextStyle(
                                              fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _category = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Card 2: Service Media ──────────────────────────────────
            _Card(
              icon: Icons.photo_library_outlined,
              title: 'Service Media',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_images.isEmpty)
                    _MediaUploadPlaceholder(
                      onCamera: _pickImageCamera,
                      onGallery: _pickImage,
                    )
                  else ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: _images.length < 5
                          ? _images.length + 1
                          : _images.length,
                      itemBuilder: (context, index) {
                        if (index == _images.length) {
                          return _AddMoreTile(
                            onCamera: _pickImageCamera,
                            onGallery: _pickImage,
                          );
                        }
                        return _ImageTile(
                          file: _images[index],
                          isPrimary: index == _primaryImageIndex,
                          onRemove: () => _removeImage(index),
                          onSetPrimary: () => _setPrimary(index),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Tap image to set as cover photo',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Supports PNG, JPG (Max 5 files)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Card 3: Description ────────────────────────────────────
            _Card(
              icon: Icons.subject_rounded,
              title: 'Service Description',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel(
                    label: 'Description',
                    icon: Icons.notes_rounded,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: StoreFormField.decoration(
                        hint: 'Optional service details...'),
                    maxLines: 4,
                    minLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Service',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared card wrapper ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card(
      {required this.icon,
      required this.title,
      required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(
      {required this.label, required this.icon, this.required = false});
  final String label;
  final IconData icon;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}

// ─── Media upload placeholder ─────────────────────────────────────────────────

class _MediaUploadPlaceholder extends StatelessWidget {
  const _MediaUploadPlaceholder(
      {required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showPickerSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload Service Photos',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to take or choose photos',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add more tile ────────────────────────────────────────────────────────────

class _AddMoreTile extends StatelessWidget {
  const _AddMoreTile({required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _MediaUploadPlaceholder(
              onCamera: onCamera, onGallery: onGallery)
          ._showPickerSheet(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
            SizedBox(height: 6),
            Text('Add Photo',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Image tile ───────────────────────────────────────────────────────────────

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.file,
    required this.onRemove,
    required this.isPrimary,
    required this.onSetPrimary,
  });
  final File file;
  final VoidCallback onRemove;
  final bool isPrimary;
  final VoidCallback onSetPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSetPrimary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(file, fit: BoxFit.cover),
          ),

          // Primary highlight border
          if (isPrimary)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

          // Primary star badge (bottom-left)
          Positioned(
            bottom: 6,
            left: 6,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isPrimary ? 1 : 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        color: Colors.white, size: 11),
                    SizedBox(width: 3),
                    Text('Cover',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),

          // Remove button (top-right)
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

