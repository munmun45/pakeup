import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partners_repository.dart';
import '../providers/partners_provider.dart';

class PartnerImagesDialog extends ConsumerStatefulWidget {
  const PartnerImagesDialog({
    super.key,
    required this.partner,
  });

  final PartnerRecord partner;

  @override
  ConsumerState<PartnerImagesDialog> createState() => _PartnerImagesDialogState();
}

class _PartnerImagesDialogState extends ConsumerState<PartnerImagesDialog> {
  late List<String> _images;
  String? _primaryImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.partner.images);
    _primaryImage = widget.partner.primaryImage;
  }

  Future<void> _uploadImage() async {
    if (_images.length >= 5) {
      AppSnackBar.warning(context, 'You can upload a maximum of 5 images');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final remainingSlots = 5 - _images.length;
      final filesToUpload = result.files
          .where((f) => f.path != null)
          .take(remainingSlots)
          .toList();

      if (filesToUpload.isEmpty) return;

      setState(() => _isLoading = true);

      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      final repo = ref.read(partnersRepositoryProvider);
      
      final uploadedUrls = <String>[];
      for (final file in filesToUpload) {
        final publicUrl = await repo.uploadStoreImage(
          partnerId: widget.partner.id,
          localPath: file.path!,
        );
        uploadedUrls.add(publicUrl);
      }

      final updatedImages = [..._images, ...uploadedUrls];
      final updatedPrimary = _primaryImage ?? (uploadedUrls.isNotEmpty ? uploadedUrls.first : null);

      await repo.updatePartnerImages(
        callerId: user.id,
        partnerId: widget.partner.id,
        images: updatedImages,
        primaryImage: updatedPrimary,
      );

      setState(() {
        _images = updatedImages;
        _primaryImage = updatedPrimary;
        _isLoading = false;
      });

      if (mounted) {
        final ignoredCount = result.files.length - filesToUpload.length;
        if (ignoredCount > 0) {
          AppSnackBar.success(
            context,
            'Uploaded ${filesToUpload.length} images. $ignoredCount ignored (limit of 5 exceeded).',
          );
        } else {
          AppSnackBar.success(context, 'Uploaded ${filesToUpload.length} images successfully');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppSnackBar.actionFailed(context, 'upload image', e);
      }
    }
  }

  Future<void> _deleteImage(String url) async {
    try {
      setState(() => _isLoading = true);

      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      final repo = ref.read(partnersRepositoryProvider);
      final updatedImages = _images.where((img) => img != url).toList();
      
      String? updatedPrimary = _primaryImage;
      if (updatedPrimary == url) {
        updatedPrimary = updatedImages.isNotEmpty ? updatedImages.first : null;
      }

      await repo.updatePartnerImages(
        callerId: user.id,
        partnerId: widget.partner.id,
        images: updatedImages,
        primaryImage: updatedPrimary,
      );

      setState(() {
        _images = updatedImages;
        _primaryImage = updatedPrimary;
        _isLoading = false;
      });

      if (mounted) {
        AppSnackBar.success(context, 'Image deleted successfully');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppSnackBar.actionFailed(context, 'delete image', e);
      }
    }
  }

  Future<void> _setPrimary(String url) async {
    if (_primaryImage == url) return;

    try {
      setState(() => _isLoading = true);

      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      final repo = ref.read(partnersRepositoryProvider);
      await repo.updatePartnerImages(
        callerId: user.id,
        partnerId: widget.partner.id,
        images: _images,
        primaryImage: url,
      );

      setState(() {
        _primaryImage = url;
        _isLoading = false;
      });

      if (mounted) {
        AppSnackBar.success(context, 'Primary image updated');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppSnackBar.actionFailed(context, 'set primary image', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      title: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Store Images',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.partner.businessName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Upload up to 5 photos of your store. Select a star icon to mark an image as primary.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _images.length + (_images.length < 5 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _images.length) {
                      return InkWell(
                        onTap: _isLoading ? null : _uploadImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 32,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add Photo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final imageUrl = _images[index];
                    final isPrimary = imageUrl == _primaryImage;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPrimary ? AppColors.primary : AppColors.border,
                          width: isPrimary ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.red),
                            ),
                          ),
                          // Primary Badge Star
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Tooltip(
                              message: isPrimary ? 'Primary Image' : 'Set as Primary',
                              child: Material(
                                color: isPrimary
                                    ? AppColors.primary
                                    : Colors.black.withValues(alpha: 0.5),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _isLoading
                                      ? null
                                      : () => _setPrimary(imageUrl),
                                  customBorder: const CircleBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      isPrimary
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Delete button
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () => _deleteImage(imageUrl),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.7),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
