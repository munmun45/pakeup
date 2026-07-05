import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partner_categories_repository.dart';
import '../data/service_categories_repository.dart';
import '../providers/partner_categories_provider.dart';
import '../providers/service_categories_provider.dart';
import '../widgets/partner_form_field.dart';
import '../widgets/partner_table_widgets.dart';

class ManagePartnerCategoriesScreen extends ConsumerWidget {
  const ManagePartnerCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.category_rounded,
          title: 'Categories',
          subtitle: 'Manage store types and service categories shown across the app.',
        ),
        const SizedBox(height: 24),
        // Two-column layout
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 800;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StoreCategoryPanel(ref: ref, context: context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ServiceCategoryPanel(ref: ref, context: context),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _StoreCategoryPanel(ref: ref, context: context),
                const SizedBox(height: 16),
                _ServiceCategoryPanel(ref: ref, context: context),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STORE CATEGORIES PANEL
// ─────────────────────────────────────────────────────────────
class _StoreCategoryPanel extends ConsumerStatefulWidget {
  const _StoreCategoryPanel({required this.ref, required this.context});
  final WidgetRef ref;
  final BuildContext context;

  @override
  ConsumerState<_StoreCategoryPanel> createState() => _StoreCategoryPanelState();
}

class _StoreCategoryPanelState extends ConsumerState<_StoreCategoryPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(partnerCategoriesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel header
        _PanelHeader(
          icon: Icons.storefront_outlined,
          iconColor: AppColors.primary,
          title: 'Store Categories',
          subtitle: 'Types shown when adding a partner store.',
          searchCtrl: _searchCtrl,
          searchHint: 'Search store categories...',
          onSearchChanged: (v) => setState(() => _searchQuery = v.toLowerCase().trim()),
          onAdd: () => _openForm(context),
        ),
        const SizedBox(height: 12),
        categoriesAsync.when(
          loading: () => const _PanelLoading(),
          error: (e, _) => _PanelError(e.toString()),
          data: (categories) {
            final filtered = _searchQuery.isEmpty
                ? categories
                : categories.where((c) =>
                    c.name.toLowerCase().contains(_searchQuery) ||
                    c.slug.toLowerCase().contains(_searchQuery)).toList();

            if (filtered.isEmpty) {
              return _PanelEmpty(_searchQuery.isEmpty
                  ? 'No store categories yet.\nTap + Add to create one.'
                  : 'No categories match "$_searchQuery"');
            }

            return _CategoryTable(
              children: [
                for (var i = 0; i < filtered.length; i++)
                  _CategoryRow(
                    name: filtered[i].name,
                    slug: filtered[i].slug,
                    isActive: filtered[i].isActive,
                    isLast: i == filtered.length - 1,
                    onEdit: () => _openForm(context, existing: filtered[i]),
                    onDelete: () => _delete(context, filtered[i]),
                    onToggle: () => _toggleActive(context, filtered[i]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, {PartnerCategory? existing}) async {
    final result = await showDialog<({String name, String? slug})>(
      context: context,
      builder: (context) => _CategoryFormDialog(
        title: existing != null ? 'Edit Store Category' : 'Add Store Category',
        subtitle: existing != null
            ? 'Update the name or slug for this store type'
            : 'Create a new store type (e.g. Salon, Spa, Clinic)',
        icon: Icons.storefront_outlined,
        iconColor: AppColors.primary,
        existing: existing != null ? (name: existing.name, slug: existing.slug) : null,
      ),
    );
    if (result == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      if (context.mounted) AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    final repo = ref.read(partnerCategoriesRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createCategory(callerId: user.id, name: result.name, slug: result.slug);
        if (context.mounted) AppSnackBar.success(context, 'Store category "${result.name}" added');
      } else {
        await repo.updateCategory(
            callerId: user.id, categoryId: existing.id, name: result.name, slug: result.slug);
        if (context.mounted) AppSnackBar.success(context, 'Store category "${result.name}" updated');
      }
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, existing == null ? 'add store category' : 'update store category', e);
      }
    }
  }

  Future<void> _toggleActive(BuildContext context, PartnerCategory c) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      await ref.read(partnerCategoriesRepositoryProvider).setCategoryActive(
          callerId: user.id, categoryId: c.id, active: !c.isActive);
      if (context.mounted) {
        AppSnackBar.success(context, c.isActive ? '"${c.name}" deactivated' : '"${c.name}" activated');
      }
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.actionFailed(context, 'update status', e);
    }
  }

  Future<void> _delete(BuildContext context, PartnerCategory c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete store category?'),
        content: Text('Remove "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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
          callerId: user.id, categoryId: c.id);
      if (context.mounted) AppSnackBar.success(context, 'Store category "${c.name}" deleted');
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.actionFailed(context, 'delete store category', e);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SERVICE CATEGORIES PANEL
// ─────────────────────────────────────────────────────────────
class _ServiceCategoryPanel extends ConsumerStatefulWidget {
  const _ServiceCategoryPanel({required this.ref, required this.context});
  final WidgetRef ref;
  final BuildContext context;

  @override
  ConsumerState<_ServiceCategoryPanel> createState() => _ServiceCategoryPanelState();
}

class _ServiceCategoryPanelState extends ConsumerState<_ServiceCategoryPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(serviceCategoriesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          icon: Icons.design_services_outlined,
          iconColor: AppColors.primary,
          title: 'Service Categories',
          subtitle: 'Types shown when adding a service (e.g. Makeup, Hair).',
          searchCtrl: _searchCtrl,
          searchHint: 'Search service categories...',
          onSearchChanged: (v) => setState(() => _searchQuery = v.toLowerCase().trim()),
          onAdd: () => _openForm(context),
        ),
        const SizedBox(height: 12),
        categoriesAsync.when(
          loading: () => const _PanelLoading(),
          error: (e, _) => _PanelError(e.toString()),
          data: (categories) {
            final filtered = _searchQuery.isEmpty
                ? categories
                : categories.where((c) =>
                    c.name.toLowerCase().contains(_searchQuery) ||
                    c.slug.toLowerCase().contains(_searchQuery)).toList();

            if (filtered.isEmpty) {
              return _PanelEmpty(_searchQuery.isEmpty
                  ? 'No service categories yet.\nTap + Add to create one.'
                  : 'No categories match "$_searchQuery"');
            }

            return _CategoryTable(
              children: [
                for (var i = 0; i < filtered.length; i++)
                  _CategoryRow(
                    name: filtered[i].name,
                    slug: filtered[i].slug,
                    isActive: filtered[i].isActive,
                    isLast: i == filtered.length - 1,
                    onEdit: () => _openForm(context, existing: filtered[i]),
                    onDelete: () => _delete(context, filtered[i]),
                    onToggle: () => _toggleActive(context, filtered[i]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, {ServiceCategory? existing}) async {
    final result = await showDialog<({String name, String? slug})>(
      context: context,
      builder: (context) => _CategoryFormDialog(
        title: existing != null ? 'Edit Service Category' : 'Add Service Category',
        subtitle: existing != null
            ? 'Update the name or slug for this service type'
            : 'Create a new service type (e.g. Makeup, Hair Styling)',
        icon: Icons.design_services_outlined,
        iconColor: AppColors.primary,
        existing: existing != null ? (name: existing.name, slug: existing.slug) : null,
      ),
    );
    if (result == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      if (context.mounted) AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    final repo = ref.read(serviceCategoriesRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createCategory(callerId: user.id, name: result.name, slug: result.slug);
        if (context.mounted) AppSnackBar.success(context, 'Service category "${result.name}" added');
      } else {
        await repo.updateCategory(
            callerId: user.id, categoryId: existing.id, name: result.name, slug: result.slug);
        if (context.mounted) AppSnackBar.success(context, 'Service category "${result.name}" updated');
      }
      ref.invalidate(serviceCategoriesListProvider);
      ref.invalidate(activeServiceCategoriesProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, existing == null ? 'add service category' : 'update service category', e);
      }
    }
  }

  Future<void> _toggleActive(BuildContext context, ServiceCategory c) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      await ref.read(serviceCategoriesRepositoryProvider).setCategoryActive(
          callerId: user.id, categoryId: c.id, active: !c.isActive);
      if (context.mounted) {
        AppSnackBar.success(context, c.isActive ? '"${c.name}" deactivated' : '"${c.name}" activated');
      }
      ref.invalidate(serviceCategoriesListProvider);
      ref.invalidate(activeServiceCategoriesProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.actionFailed(context, 'update status', e);
    }
  }

  Future<void> _delete(BuildContext context, ServiceCategory c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete service category?'),
        content: Text('Remove "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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
      await ref.read(serviceCategoriesRepositoryProvider).deleteCategory(
          callerId: user.id, categoryId: c.id);
      if (context.mounted) AppSnackBar.success(context, 'Service category "${c.name}" deleted');
      ref.invalidate(serviceCategoriesListProvider);
      ref.invalidate(activeServiceCategoriesProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.actionFailed(context, 'delete service category', e);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED UI WIDGETS
// ─────────────────────────────────────────────────────────────

class _PanelHeader extends StatefulWidget {
  const _PanelHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.searchCtrl,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onAdd,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final TextEditingController searchCtrl;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;

  @override
  State<_PanelHeader> createState() => _PanelHeaderState();
}

class _PanelHeaderState extends State<_PanelHeader> {
  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearchChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          // Title + subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              Text(widget.subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(width: 12),
          // Search box — flexible, fills available space
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 9),
                  Icon(Icons.search_rounded, size: 15, color: accent.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: widget.searchCtrl,
                      onChanged: widget.onSearchChanged,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        hintStyle: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (widget.searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        widget.searchCtrl.clear();
                        widget.onSearchChanged('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: accent.withValues(alpha: 0.7)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Add button
          FilledButton.icon(
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}


class _CategoryTable extends StatelessWidget {
  const _CategoryTable({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              border: Border(
                  bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
            ),
            child: Row(
              children: [
                const Expanded(
                    child: Text('NAME', style: partnerTableHeaderStyle)),
                const SizedBox(
                    width: 110,
                    child: Text('SLUG', style: partnerTableHeaderStyle)),
                const SizedBox(
                    width: 80,
                    child: Text('STATUS', style: partnerTableHeaderStyle)),
                SizedBox(
                  width: 100,
                  child: Text('ACTIONS',
                      style: partnerTableHeaderStyle,
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.slug,
    required this.isActive,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final String name;
  final String slug;
  final bool isActive;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1 : 0.55,
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
              child: Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
            SizedBox(
              width: 110,
              child: Text(slug,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
            ),
            SizedBox(
              width: 80,
              child: PartnerStatusBadge(isActive: isActive),
            ),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PartnerTableAction(
                    icon: isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    tooltip: isActive ? 'Deactivate' : 'Activate',
                    color: isActive ? AppColors.warning : AppColors.success,
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

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
}

class _PanelError extends StatelessWidget {
  const _PanelError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, style: const TextStyle(color: AppColors.error)),
        ),
      );
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// SHARED FORM DIALOG (used by both panels)
// ─────────────────────────────────────────────────────────────

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.existing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final ({String name, String? slug})? existing;

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
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.iconColor.withValues(alpha: 0.12),
                        AppColors.surface,
                      ],
                    ),
                    border: Border(
                        bottom: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.9))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: widget.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: widget.iconColor.withValues(alpha: 0.25)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(widget.icon, color: widget.iconColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            Text(widget.subtitle,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary)),
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
                // Form body
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
                            PartnerFormField(
                              label: 'Category Name',
                              icon: Icons.label_outline,
                              controller: _nameCtrl,
                              required: true,
                              hint: 'e.g. Salon, Makeup, Hair Styling...',
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Name is required' : null,
                            ),
                            const SizedBox(height: 4),
                            PartnerFormField(
                              label: 'Slug (optional)',
                              icon: Icons.link,
                              controller: _slugCtrl,
                              hint: 'auto-generated from name if left empty',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                        top: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.9))),
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
                      Text('Slug is used in URLs and filters',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(alpha: 0.85))),
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
                          backgroundColor: widget.iconColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
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
