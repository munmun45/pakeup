import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partners_repository.dart';
import '../models/partner_service_models.dart';
import '../models/service_availability_models.dart';
import '../providers/partner_services_provider.dart';
import '../providers/partners_provider.dart';
import '../providers/service_availability_provider.dart';

part 'inventory_pricing_tab.dart';
part 'inventory_calendar_tab.dart';
part 'inventory_visit_tab.dart';

enum _InventoryGenderFilter { all, male, female }

extension on _InventoryGenderFilter {
  String get label => switch (this) {
        _InventoryGenderFilter.all => 'All',
        _InventoryGenderFilter.male => 'Male',
        _InventoryGenderFilter.female => 'Female',
      };

  IconData get icon => switch (this) {
        _InventoryGenderFilter.all => Icons.people_outline_rounded,
        _InventoryGenderFilter.male => Icons.male_rounded,
        _InventoryGenderFilter.female => Icons.female_rounded,
      };
}

bool _serviceMatchesGenderFilter(
  PartnerServiceRecord service,
  _InventoryGenderFilter filter,
) {
  if (filter == _InventoryGenderFilter.all) return true;

  bool matchesGender(String? value) {
    final g = value?.trim().toLowerCase() ?? '';
    if (g.isEmpty) return true;
    return switch (filter) {
      _InventoryGenderFilter.male =>
        g.contains('male') || g.contains('men') || g == 'm',
      _InventoryGenderFilter.female =>
        g.contains('female') || g.contains('women') || g == 'f',
      _InventoryGenderFilter.all => true,
    };
  }

  final target = service.targetGender;
  if (target.toLowerCase() == 'unisex') return true;

  return matchesGender(target) ||
      matchesGender(service.parlourTargetGender) ||
      matchesGender(service.homeTargetGender) ||
      (filter == _InventoryGenderFilter.male &&
          (service.parlourPriceMen != null || service.homePriceMen != null)) ||
      (filter == _InventoryGenderFilter.female &&
          (service.parlourPriceWomen != null || service.homePriceWomen != null));
}

class PartnerInventoryScreen extends ConsumerStatefulWidget {
  const PartnerInventoryScreen({super.key});

  @override
  ConsumerState<PartnerInventoryScreen> createState() =>
      _PartnerInventoryScreenState();
}

class _PartnerInventoryScreenState
    extends ConsumerState<PartnerInventoryScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  String? _filterPartnerId;
  _InventoryGenderFilter _genderFilter = _InventoryGenderFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _contentHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    const shellHeader = 76.0;
    const shellPadding = 56.0;
    return (media.size.height - shellHeader - shellPadding - media.padding.top)
        .clamp(560.0, media.size.height);
  }

  List<PartnerServiceRecord> _filterServices(
    List<PartnerServiceRecord> allServices,
  ) {
    final byStore = _filterPartnerId == null
        ? allServices
        : allServices.where((s) => s.partnerId == _filterPartnerId).toList();

    return byStore
        .where((s) => _serviceMatchesGenderFilter(s, _genderFilter))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(partnerServicesListProvider);
    final partnersAsync = ref.watch(partnersListProvider);
    final contentHeight = _contentHeight(context);

    return SizedBox(
      height: contentHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Inventory',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Pricing · gig calendar · home & parlour visits · male & female',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    partnersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (partners) {
                        return _PartnerFilterChip(
                          partners: partners,
                          selectedId: _filterPartnerId,
                          onChanged: (id) =>
                              setState(() => _filterPartnerId = id),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    for (final option in _InventoryGenderFilter.values)
                      _GenderFilterChip(
                        label: option.label,
                        icon: option.icon,
                        selected: _genderFilter == option,
                        onTap: () =>
                            setState(() => _genderFilter = option),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.price_change_outlined, size: 18),
                      text: 'Pricing',
                      iconMargin: EdgeInsets.only(bottom: 4),
                    ),
                    Tab(
                      icon: Icon(Icons.calendar_month_outlined, size: 18),
                      text: 'Gig Calendar',
                      iconMargin: EdgeInsets.only(bottom: 4),
                    ),
                    Tab(
                      icon: Icon(Icons.tune_rounded, size: 18),
                      text: 'Visit Settings',
                      iconMargin: EdgeInsets.only(bottom: 4),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: servicesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load services',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ),
              data: (allServices) {
                final services = _filterServices(allServices);

                if (allServices.isEmpty) {
                  return const _InventoryEmptyState(
                    title: 'No services yet',
                    message:
                        'Add partner services first, then manage pricing and availability here.',
                  );
                }

                if (services.isEmpty) {
                  return _InventoryEmptyState(
                    title: 'No matching services',
                    message:
                        'Try another store or gender filter, or clear filters.',
                    onClear: () => setState(() {
                      _filterPartnerId = null;
                      _genderFilter = _InventoryGenderFilter.all;
                    }),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _PricingTab(services: services),
                    _CalendarTab(services: services),
                    _VisitSettingsTab(services: services),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({
    required this.title,
    required this.message,
    this.onClear,
  });

  final String title;
  final String message;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onClear != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenderFilterChip extends StatelessWidget {
  const _GenderFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Partner Filter Chip ──────────────────────────────────────
class _PartnerFilterChip extends StatelessWidget {
  const _PartnerFilterChip({
    required this.partners,
    required this.selectedId,
    required this.onChanged,
  });

  final List<PartnerRecord> partners;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedId != null
        ? partners.where((p) => p.id == selectedId).firstOrNull
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected != null
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected != null
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 15,
              color: selected != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              selected?.businessName ?? 'All Stores',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected != null
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: selected != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Filter by Store'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.all_inclusive, color: AppColors.primary),
                  ),
                  title: const Text('All Stores',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: selectedId == null
                      ? const Icon(Icons.check_circle,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    onChanged(null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ...partners.map((p) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage:
                            (p.primaryImage?.isNotEmpty == true)
                                ? NetworkImage(p.primaryImage!)
                                : null,
                        child: p.primaryImage?.isNotEmpty != true
                            ? Text(
                                p.businessName.isNotEmpty
                                    ? p.businessName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(p.businessName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(p.ownerName,
                          style: const TextStyle(fontSize: 12)),
                      trailing: selectedId == p.id
                          ? const Icon(Icons.check_circle,
                              color: AppColors.primary)
                          : null,
                      onTap: () {
                        onChanged(p.id);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
