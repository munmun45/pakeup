import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../models/store_models.dart';
import '../providers/stores_provider.dart';

class StoreImagesSection extends ConsumerStatefulWidget {
  const StoreImagesSection({
    super.key,
    required this.store,
    required this.onChanged,
  });

  final StoreRecord store;
  final VoidCallback onChanged;

  @override
  ConsumerState<StoreImagesSection> createState() => _StoreImagesSectionState();
}

class _StoreImagesSectionState extends ConsumerState<StoreImagesSection> {
  static const _maxImages = 5;

  late List<String> _images;
  String? _primaryImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _syncFromStore();
  }

  @override
  void didUpdateWidget(covariant StoreImagesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.id != widget.store.id ||
        oldWidget.store.images != widget.store.images ||
        oldWidget.store.primaryImage != widget.store.primaryImage) {
      _syncFromStore();
    }
  }

  void _syncFromStore() {
    _images = List<String>.from(widget.store.images);
    _primaryImage = widget.store.primaryImage;
  }

  Future<({String accountId, String loginPass})?> _credentials() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
    if (user == null || loginPass == null || loginPass.isEmpty) {
      if (mounted) {
        AppSnackBar.error(context, 'Session expired. Please log in again.');
      }
      return null;
    }
    return (accountId: user.id, loginPass: loginPass);
  }

  Future<void> _uploadImage() async {
    if (_images.length >= _maxImages) {
      AppSnackBar.warning(context, 'You can upload a maximum of $_maxImages images');
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    final creds = await _credentials();
    if (!mounted || creds == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await picked.readAsBytes();
      final repo = ref.read(storesRepositoryProvider);
      final url = await repo.uploadStoreImage(
        storeId: widget.store.id,
        bytes: bytes,
      );

      final updatedImages = [..._images, url];
      final updatedPrimary = _primaryImage ?? url;

      await repo.updateStoreImages(
        accountId: creds.accountId,
        loginPass: creds.loginPass,
        storeId: widget.store.id,
        images: updatedImages,
        primaryImage: updatedPrimary,
      );

      setState(() {
        _images = updatedImages;
        _primaryImage = updatedPrimary;
      });
      widget.onChanged();
      if (mounted) AppSnackBar.success(context, 'Photo added successfully');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to upload image: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteImage(String url) async {
    final creds = await _credentials();
    if (!mounted || creds == null) return;

    setState(() => _loading = true);
    try {
      final updatedImages = _images.where((img) => img != url).toList();
      var updatedPrimary = _primaryImage;
      if (updatedPrimary == url) {
        updatedPrimary = updatedImages.isNotEmpty ? updatedImages.first : null;
      }

      await ref.read(storesRepositoryProvider).updateStoreImages(
            accountId: creds.accountId,
            loginPass: creds.loginPass,
            storeId: widget.store.id,
            images: updatedImages,
            primaryImage: updatedPrimary,
          );

      setState(() {
        _images = updatedImages;
        _primaryImage = updatedPrimary;
      });
      widget.onChanged();
      if (mounted) AppSnackBar.success(context, 'Photo removed');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to delete image: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPrimary(String url) async {
    if (_primaryImage == url) return;
    final creds = await _credentials();
    if (!mounted || creds == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(storesRepositoryProvider).updateStoreImages(
            accountId: creds.accountId,
            loginPass: creds.loginPass,
            storeId: widget.store.id,
            images: _images,
            primaryImage: url,
          );

      setState(() => _primaryImage = url);
      widget.onChanged();
      if (mounted) AppSnackBar.success(context, 'Primary photo updated');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to set primary: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Store Photos',
      icon: Icons.photo_library_outlined,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add up to 5 photos. Tap the star to set the cover photo.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: _images.length + (_images.length < _maxImages ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _images.length) {
                    return _AddPhotoTile(onTap: _loading ? null : _uploadImage);
                  }
                  final url = _images[index];
                  final isPrimary = url == _primaryImage;
                  return _PhotoTile(
                    url: url,
                    isPrimary: isPrimary,
                    onSetPrimary: _loading ? null : () => _setPrimary(url),
                    onDelete: _loading ? null : () => _deleteImage(url),
                  );
                },
              ),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: AppColors.surface.withValues(alpha: 0.7),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.primary, size: 28),
              SizedBox(height: 6),
              Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.isPrimary,
    this.onSetPrimary,
    this.onDelete,
  });

  final String url;
  final bool isPrimary;
  final VoidCallback? onSetPrimary;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
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
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: AppColors.background,
              child: Icon(Icons.broken_image_outlined, color: AppColors.error),
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: _CircleAction(
              icon: isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isPrimary ? AppColors.primary : Colors.black54,
              onTap: onSetPrimary,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: _CircleAction(
              icon: Icons.delete_outline_rounded,
              color: Colors.black54,
              onTap: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}
