import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partner_categories_repository.dart';
import '../providers/partner_categories_provider.dart';
import '../widgets/partner_table_widgets.dart';

class ManagePartnerCategoriesScreen extends ConsumerWidget {
  const ManagePartnerCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(partnerCategoriesListProvider);

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
            if (categories.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: Text('No categories yet. Add your first category.'),
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
                  for (var i = 0; i < categories.length; i++)
                    _CategoryRow(
                      category: categories[i],
                      isLast: i == categories.length - 1,
                      onEdit: () => _openForm(context, ref, existing: categories[i]),
                      onDelete: () => _delete(context, ref, categories[i]),
                      onToggle: () => _toggleActive(context, ref, categories[i]),
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
    if (user == null) return;

    final repo = ref.read(partnerCategoriesRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createCategory(
          callerId: user.id,
          name: result.name,
          slug: result.slug,
        );
        if (context.mounted) {
          AppSnackBar.success(context, 'Category "${result.name}" added');
        }
      } else {
        await repo.updateCategory(
          callerId: user.id,
          categoryId: existing.id,
          name: result.name,
          slug: result.slug,
        );
        if (context.mounted) {
          AppSnackBar.success(context, 'Category updated');
        }
      }
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    PartnerCategory category,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

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
      if (context.mounted) AppSnackBar.error(context, e.toString());
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
    if (user == null) return;

    try {
      await ref.read(partnerCategoriesRepositoryProvider).deleteCategory(
            callerId: user.id,
            categoryId: category.id,
          );
      if (context.mounted) {
        AppSnackBar.success(context, 'Deleted "${category.name}"');
      }
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? 'Edit Category' : 'Add Category',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _slugCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Slug (optional)',
                    hintText: 'auto-generated from name',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
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
                      child: Text(isEdit ? 'Save' : 'Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
