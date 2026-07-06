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

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(partnerServicesListProvider);
    final partnersAsync = ref.watch(partnersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
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
                  const Column(
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
                        'Manage pricing, availability calendar & visit settings',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Partner filter chip
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
              const SizedBox(height: 20),
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
                    text: 'Availability',
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

        // ── Body ──
        Expanded(
          child: servicesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(e.toString(),
                    style: const TextStyle(color: AppColors.error)),
              ),
            ),
            data: (allServices) {
              final services = _filterPartnerId == null
                  ? allServices
                  : allServices
                      .where((s) => s.partnerId == _filterPartnerId)
                      .toList();

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
