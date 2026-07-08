import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/models/store_models.dart';
import '../../stores/widgets/store_form_fields.dart';
import '../data/services_repository.dart';
import '../models/service_models.dart';
import '../providers/services_provider.dart';

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

class EditServiceScreen extends ConsumerStatefulWidget {
  const EditServiceScreen({
    super.key,
    required this.store,
    required this.service,
  });

  final StoreRecord store;
  final ServiceRecord service;

  @override
  ConsumerState<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends ConsumerState<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  final _picker = ImagePicker();

  late String _category;
  final List<String> _existingUrls = [];
  final List<File> _newImages = [];
  int _primaryIndex = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.service.name);
    _descCtrl = TextEditingController(text: widget.service.description ?? '');
    _category = _kCategories.contains(widget.service.category)
        ? widget.service.category
        : 'Others';

    if (widget.service.images.isNotEmpty) {
      _existingUrls.addAll(widget.service.images);
    } else if (widget.service.displayImage != null) {
      _existingUrls.add(widget.service.displayImage!);
    }

    final primary = widget.service.displayImage;
    if (primary != null) {
      final idx = _existingUrls.indexOf(primary);
      _primaryIndex = idx >= 0 ? idx : 0;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int get _totalImages => _existingUrls.length + _newImages.length;

  Future<void> _pickImage(ImageSource source) async {
    if (_totalImages >= 5) {
      AppSnackBar.warning(context, 'Maximum 5 photos allowed.');
      return;
    }
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (xFile == null) return;
    setState(() => _newImages.add(File(xFile.path)));
  }

  void _removeAt(int index) {
    setState(() {
      if (index < _existingUrls.length) {
        _existingUrls.removeAt(index);
      } else {
        _newImages.removeAt(index - _existingUrls.length);
      }
      if (_primaryIndex >= _totalImages) {
        _primaryIndex = _totalImages == 0 ? 0 : _totalImages - 1;
      }
    });
  }

  Future<List<String>> _uploadNewImages(SupabaseClient client) async {
    final urls = <String>[];
    for (final file in _newImages) {
      final bytes = await file.readAsBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'services/${widget.store.id}/image_$ts.jpg';
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

    setState(() => _submitting = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      final loginPass =
          await ref.read(authRepositoryProvider).getStoredLoginPass();
      if (user == null || loginPass == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final client = ref.read(supabaseClientProvider);
      final uploaded = _newImages.isNotEmpty
          ? await _uploadNewImages(client)
          : <String>[];
      final allUrls = [..._existingUrls, ...uploaded];
      final primaryUrl = allUrls.isNotEmpty
          ? allUrls[_primaryIndex.clamp(0, allUrls.length - 1)]
          : null;

      await ref.read(servicesRepositoryProvider).updateService(
            accountId: user.id,
            loginPass: loginPass,
            storeId: widget.store.id,
            serviceId: widget.service.id,
            data: UpdateServiceData(
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              category: _category,
              serviceImageUrl: primaryUrl,
              primaryImageUrl: primaryUrl,
              images: allUrls,
            ),
          );

      ref.invalidate(storeServicesProvider(widget.store.id));
      ref.invalidate(myServicesProvider);

      if (mounted) {
        AppSnackBar.success(context, 'Service updated successfully.');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to update service: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Service'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _sectionCard(
              icon: Icons.edit_note_rounded,
              title: 'Service Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        StoreFormField.decoration(hint: 'Service name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration:
                        StoreFormField.decoration(hint: 'Category'),
                    items: _kCategories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: StoreFormField.decoration(
                        hint: 'Optional description...'),
                    maxLines: 4,
                    minLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              icon: Icons.photo_library_outlined,
              title: 'Service Media',
              child: Column(
                children: [
                  if (_totalImages == 0)
                    OutlinedButton.icon(
                      onPressed: () => _showPicker(context),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add Photos'),
                    )
                  else
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
                      itemCount:
                          _totalImages < 5 ? _totalImages + 1 : _totalImages,
                      itemBuilder: (context, index) {
                        if (index == _totalImages) {
                          return InkWell(
                            onTap: () => _showPicker(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded,
                                      color: AppColors.primary),
                                  Text('Add Photo',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }
                        final isPrimary = index == _primaryIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _primaryIndex = index),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: index < _existingUrls.length
                                    ? Image.network(
                                        _existingUrls[index],
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        _newImages[
                                            index - _existingUrls.length],
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              if (isPrimary)
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('Cover',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: GestureDetector(
                                  onTap: () => _removeAt(index),
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
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
