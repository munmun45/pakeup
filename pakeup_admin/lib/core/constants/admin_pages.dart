import 'package:flutter/material.dart';

class AdminPageDef {
  const AdminPageDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.route,
    this.superAdminOnly = false,
    this.group = 'general',
  });

  final String key;
  final String label;
  final IconData icon;
  final String? route;
  final bool superAdminOnly;
  final String group;
}

class AdminMenuGroup {
  const AdminMenuGroup({
    required this.id,
    required this.label,
    required this.pageKeys,
  });

  final String id;
  final String label;
  final List<String> pageKeys;
}

class AdminPages {
  AdminPages._();

  static const manageAdminsKey = 'manage_admins';

  static const List<AdminMenuGroup> menuGroups = [
    AdminMenuGroup(
      id: 'administration',
      label: 'Administration',
      pageKeys: [manageAdminsKey],
    ),
    AdminMenuGroup(
      id: 'overview',
      label: 'Overview',
      pageKeys: ['dashboard'],
    ),
    AdminMenuGroup(
      id: 'operations',
      label: 'Operations',
      pageKeys: [
        'users',
        'salons',
        'bookings',
        'payments',
        'commissions',
      ],
    ),
    AdminMenuGroup(
      id: 'marketing',
      label: 'Marketing',
      pageKeys: ['coupons', 'ads', 'affiliates'],
    ),
    AdminMenuGroup(
      id: 'monitoring',
      label: 'Monitoring',
      pageKeys: [
        'ai_monitor',
        'moderation',
        'reports',
        'notifications',
      ],
    ),
    AdminMenuGroup(
      id: 'system',
      label: 'System',
      pageKeys: ['settings'],
    ),
  ];

  static const List<AdminPageDef> all = [
    AdminPageDef(
      key: manageAdminsKey,
      label: 'Manage Admins',
      icon: Icons.admin_panel_settings_rounded,
      route: '/manage-admins',
      superAdminOnly: true,
      group: 'administration',
    ),
    AdminPageDef(
      key: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      route: '/dashboard',
      group: 'overview',
    ),
    AdminPageDef(
      key: 'users',
      label: 'Users',
      icon: Icons.people_rounded,
      route: '/users',
      group: 'operations',
    ),
    AdminPageDef(
      key: 'salons',
      label: 'Salons',
      icon: Icons.store_rounded,
      route: '/salons',
      group: 'operations',
    ),
    AdminPageDef(
      key: 'bookings',
      label: 'Bookings',
      icon: Icons.calendar_month_rounded,
      route: '/bookings',
      group: 'operations',
    ),
    AdminPageDef(
      key: 'payments',
      label: 'Payments',
      icon: Icons.payments_rounded,
      route: '/payments',
      group: 'operations',
    ),
    AdminPageDef(
      key: 'commissions',
      label: 'Commissions',
      icon: Icons.percent_rounded,
      route: '/commissions',
      group: 'operations',
    ),
    AdminPageDef(
      key: 'coupons',
      label: 'Coupons',
      icon: Icons.local_offer_rounded,
      route: '/coupons',
      group: 'marketing',
    ),
    AdminPageDef(
      key: 'ai_monitor',
      label: 'AI Monitor',
      icon: Icons.face_retouching_natural,
      route: '/ai-monitor',
      group: 'monitoring',
    ),
    AdminPageDef(
      key: 'ads',
      label: 'Ads',
      icon: Icons.campaign_rounded,
      route: '/ads',
      group: 'marketing',
    ),
    AdminPageDef(
      key: 'affiliates',
      label: 'Affiliates',
      icon: Icons.link_rounded,
      route: '/affiliates',
      group: 'marketing',
    ),
    AdminPageDef(
      key: 'moderation',
      label: 'Moderation',
      icon: Icons.shield_rounded,
      route: '/moderation',
      group: 'monitoring',
    ),
    AdminPageDef(
      key: 'reports',
      label: 'Reports',
      icon: Icons.bar_chart_rounded,
      route: '/reports',
      group: 'monitoring',
    ),
    AdminPageDef(
      key: 'notifications',
      label: 'Notifications',
      icon: Icons.notifications_rounded,
      route: '/notifications',
      group: 'monitoring',
    ),
    AdminPageDef(
      key: 'settings',
      label: 'Settings',
      icon: Icons.settings_rounded,
      route: '/settings',
      superAdminOnly: true,
      group: 'system',
    ),
  ];

  static AdminPageDef? byKey(String key) {
    for (final page in all) {
      if (page.key == key) return page;
    }
    return null;
  }

  static List<AdminPageDef> forUser({
    required bool isSuperAdmin,
    required List<String> pageKeys,
  }) {
    if (isSuperAdmin) return all;

    return all
        .where((p) => !p.superAdminOnly && pageKeys.contains(p.key))
        .toList();
  }

  static List<({AdminMenuGroup group, List<AdminPageDef> pages})> groupedForUser({
    required bool isSuperAdmin,
    required List<String> pageKeys,
  }) {
    final accessible = forUser(
      isSuperAdmin: isSuperAdmin,
      pageKeys: pageKeys,
    );
    final accessibleKeys = accessible.map((page) => page.key).toSet();

    final groups = <({AdminMenuGroup group, List<AdminPageDef> pages})>[];

    for (final menuGroup in menuGroups) {
      final pages = menuGroup.pageKeys
          .map((key) => byKey(key))
          .whereType<AdminPageDef>()
          .where((page) => accessibleKeys.contains(page.key))
          .toList();

      if (pages.isNotEmpty) {
        groups.add((group: menuGroup, pages: pages));
      }
    }

    return groups;
  }

  static List<AdminPageDef> assignablePages() {
    return all.where((p) => !p.superAdminOnly).toList();
  }
}
