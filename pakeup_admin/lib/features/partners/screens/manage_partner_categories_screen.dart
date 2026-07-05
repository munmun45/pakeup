import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partner_categories_repository.dart';
import '../providers/partner_categories_provider.dart';
import '../widgets/partner_form_field.dart';
import '../widgets/partner_table_widgets.dart';
import '../../../core/providers/header_search_provider.dart';

class ManagePartnerCategoriesScreen extends ConsumerWidget {
  const ManagePartnerCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(partnerCategoriesListProvider);
    final searchQuery = ref.watch(headerSearchQueryProvider).trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.category_rounded,
          title: 'Partner Categories',
          subtitle:
              'Manage categories shown in Add Partner — salon, spa, and custom types.',
          action: FilledButton.icon(
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Category'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        categoriesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(e.toString()),
            ),
          ),
          data: (categories) {
            final filtered = searchQuery.isEmpty
                ? categories
                : categories.where((c) {
                    final q = searchQuery;
                    return c.name.toLowerCase().contains(q) ||
                        c.slug.toLowerCase().contains(q);
                  }).toList();

            if (filtered.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(searchQuery.isEmpty
                        ? 'No categories yet. Add your first category.'
                        : 'No categories match "$searchQuery"'),
                  ),
                ),
              );
            }

            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text('NAME', style: partnerTableHeaderStyle),
                        ),
                        SizedBox(
                          width: 140,
                          child: Text('SLUG', style: partnerTableHeaderStyle),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text('STATUS', style: partnerTableHeaderStyle),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'ACTIONS',
                            style: partnerTableHeaderStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < filtered.length; i++)
                    _CategoryRow(
                      category: filtered[i],
                      isLast: i == filtered.length - 1,
                      onEdit: () => _openForm(context, ref, existing: filtered[i]),
                      onDelete: () => _delete(context, ref, filtered[i]),
                      onToggle: () => _toggleActive(context, ref, filtered[i]),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PartnerCategory? existing,
  }) async {
    final result = await showDialog<({String name, String? slug})>(
      context: context,
      builder: (context) => _CategoryFormDialog(existing: existing),
    );
    if (result == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    final repo = ref.read(partnerCategoriesRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createCategory(
          callerId: user.id,
          name: result.name,
          slug: result.slug,
        );
        if (context.mounted) {
          AppSnackBar.success(
            context,
            'Category "${result.name}" added successfully',
          );
        }
      } else {
        await repo.updateCategory(
          callerId: user.id,
          categoryId: existing.id,
          name: result.name,
          slug: result.slug,
        );
        if (context.mounted) {
          AppSnackBar.success(
            context,
            'Category "${result.name}" updated successfully',
          );
        }
      }
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(
          context,
          existing == null ? 'add category' : 'update category',
          e,
        );
      }
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    PartnerCategory category,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    try {
      await ref.read(partnerCategoriesRepositoryProvider).setCategoryActive(
            callerId: user.id,
            categoryId: category.id,
            active: !category.isActive,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          category.isActive
              ? '"${category.name}" deactivated'
              : '"${category.name}" activated',
        );
      }
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'update category status', e);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PartnerCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete category?'),
        content: Text('Remove "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    try {
      await ref.read(partnerCategoriesRepositoryProvider).deleteCategory(
            callerId: user.id,
            categoryId: category.id,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          'Category "${category.name}" deleted successfully',
        );
      }
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'delete category', e);
      }
    }
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final PartnerCategory category;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: category.isActive ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            SizedBox(
              width: 140,
              child: Text(
                category.slug,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: PartnerStatusBadge(isActive: category.isActive),
            ),
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PartnerTableAction(
                    icon: category.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    tooltip: category.isActive ? 'Deactivate' : 'Activate',
                    color: category.isActive
                        ? AppColors.warning
                        : AppColors.success,
                    onPressed: onToggle,
                  ),
                  const SizedBox(width: 4),
                  PartnerTableAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 4),
                  PartnerTableAction(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: AppColors.error,
                    onPressed: onDelete,
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

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.existing});

  final PartnerCategory? existing;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _slugCtrl = TextEditingController(text: widget.existing?.slug ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.14),
                        AppColors.surface,
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isEdit
                              ? Icons.edit_note_rounded
                              : Icons.category_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Category' : 'Add Category',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              isEdit
                                  ? 'Update name or slug for this category'
                                  : 'Create a new partner category type',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                ColoredBox(
                  color: AppColors.background.withValues(alpha: 0.45),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Form(
                      key: _formKey,
                      child: Container(
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '1',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Category Details',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Name shown in Add Partner dropdown',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.label_outline,
                                  size: 18,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            PartnerFormField(
                              label: 'Category Name',
                              icon: Icons.label_outline,
                              controller: _nameCtrl,
                              required: true,
                              hint: 'e.g. Salon, Spa, Clinic...',
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Name is required'
                                  : null,
                            ),
                            PartnerFormField(
                              label: 'Slug',
                              icon: Icons.link,
                              controller: _slugCtrl,
                              hint: 'auto-generated from name if empty',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Slug is used in URLs and filters',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.pop(
                            context,
                            (
                              name: _nameCtrl.text.trim(),
                              slug: _slugCtrl.text.trim().isEmpty
                                  ? null
                                  : _slugCtrl.text.trim(),
                            ),
                          );
                        },
                        icon: Icon(
                          isEdit ? Icons.save_outlined : Icons.add_rounded,
                          size: 18,
                        ),
                        label: Text(isEdit ? 'Save Changes' : 'Add Category'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
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
      ),
    );
  }
}
