import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../menu/widgets/app_side_menu_drawer.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _inventoryIndex = 2;

  static const _sideTabs = [
    _TabInfo(
      index: 0,
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    _TabInfo(
      index: 1,
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Booking',
    ),
    _TabInfo(
      index: 3,
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments_rounded,
      label: 'Payment',
    ),
  ];

  void _goTo(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _openMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.navigationShell.currentIndex;
    final inventorySelected = current == _inventoryIndex;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppSideMenuDrawer(),
      drawerEnableOpenDragGesture: true,
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavTab(
                          tab: _sideTabs[0],
                          selected: current == 0,
                          onTap: () => _goTo(0),
                        ),
                      ),
                      Expanded(
                        child: _NavTab(
                          tab: _sideTabs[1],
                          selected: current == 1,
                          onTap: () => _goTo(1),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Expanded(
                        child: _NavTab(
                          tab: _sideTabs[2],
                          selected: current == 3,
                          onTap: () => _goTo(3),
                        ),
                      ),
                      Expanded(
                        child: _NavTab(
                          icon: Icons.menu_rounded,
                          activeIcon: Icons.menu_open_rounded,
                          label: 'Menu',
                          selected: false,
                          onTap: _openMenu,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -18,
                  child: _InventoryCenterButton(
                    selected: inventorySelected,
                    onTap: () => _goTo(_inventoryIndex),
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

class _NavTab extends StatelessWidget {
  const _NavTab({
    this.tab,
    this.icon,
    this.activeIcon,
    this.label,
    required this.selected,
    required this.onTap,
  }) : assert(
          tab != null || (icon != null && activeIcon != null && label != null),
        );

  final _TabInfo? tab;
  final IconData? icon;
  final IconData? activeIcon;
  final String? label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = tab?.icon ?? icon!;
    final resolvedActiveIcon = tab?.activeIcon ?? activeIcon!;
    final resolvedLabel = tab?.label ?? label!;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? resolvedActiveIcon : resolvedIcon,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            resolvedLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCenterButton extends StatelessWidget {
  const _InventoryCenterButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 58 : 54,
            height: selected ? 58 : 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [AppColors.primary, AppColors.secondary]
                    : [
                        AppColors.primary.withValues(alpha: 0.92),
                        AppColors.secondary.withValues(alpha: 0.88),
                      ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surface,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: selected ? 16 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Inventory',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabInfo {
  const _TabInfo({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
