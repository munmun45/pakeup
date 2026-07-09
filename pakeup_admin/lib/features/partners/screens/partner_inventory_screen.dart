import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partners_repository.dart';
import '../models/partner_service_models.dart';
import '../models/service_availability_models.dart';
import '../providers/partner_services_provider.dart';
import '../providers/partners_provider.dart';
import '../providers/partner_table_focus_provider.dart';
import '../providers/service_availability_provider.dart';

part 'inventory_calendar_tab.dart';
part 'inventory_visit_tab.dart';
part 'inventory_unified_panel.dart';

class PartnerInventoryScreen extends ConsumerStatefulWidget {
  const PartnerInventoryScreen({super.key});

  @override
  ConsumerState<PartnerInventoryScreen> createState() =>
      _PartnerInventoryScreenState();
}

class _PartnerInventoryScreenState extends ConsumerState<PartnerInventoryScreen> {
  final GlobalKey<_UnifiedInventoryPanelState> _inventoryPanelKey =
      GlobalKey<_UnifiedInventoryPanelState>();

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(partnerServicesListProvider);
    final partnersAsync = ref.watch(partnersListProvider);

    return SelectionContainer.disabled(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: SectionHeader(
                  icon: Icons.inventory_2_rounded,
                  title: 'Service Inventory',
                  subtitle: 'Weekly availability, pricing, and bulk date updates',
                  action: OutlinedButton.icon(
                    onPressed: () =>
                        _inventoryPanelKey.currentState?.openBulkUpdateDialog(),
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Bulk update'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
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
                    return partnersAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (partners) {
                        if (partners.isEmpty) {
                          return const _InventoryEmptyState(
                            title: 'No stores yet',
                            message: 'Add stores first, then add services.',
                          );
                        }
                        if (allServices.isEmpty) {
                          return const _InventoryEmptyState(
                            title: 'No services yet',
                            message:
                                'Add partner services first, then manage rates here.',
                          );
                        }
                        return _UnifiedInventoryPanel(
                          key: _inventoryPanelKey,
                          partners: partners,
                          services: allServices,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

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
          ],
        ),
      ),
    );
  }
}
