import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/admin_pages.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/page_refresh.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/smooth_scroll_behavior.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'header_search_bar.dart';
import '../../auth/providers/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.title,
    required this.currentPageKey,
    required this.child,
  });

  final String title;
  final String currentPageKey;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final menuGroups = user == null
        ? <({AdminMenuGroup group, List<AdminPageDef> pages})>[]
        : AdminPages.groupedForUser(
            isSuperAdmin: user.isSuperAdmin,
            pageKeys: user.pages,
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Container(
            width: 272,
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(
                right: BorderSide(color: Color(0xFF2A2035)),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.3),
                              AppColors.secondary.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: _SidebarNavList(
                    menuGroups: menuGroups,
                    currentPageKey: currentPageKey,
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                if (user != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go('/profile'),
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: Colors.white.withValues(alpha: 0.04),
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: currentPageKey == 'profile'
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: currentPageKey == 'profile'
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                user.id.isNotEmpty
                                    ? user.id[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    user.id,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10.5,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: currentPageKey == 'profile'
                                  ? AppColors.primary
                                  : Colors.white38,
                              size: 18,
                            ),
                            _SidebarIconButton(
                              icon: Icons.logout_rounded,
                              tooltip: 'Logout',
                              onPressed: () => _logout(context, ref),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _breadcrumb(currentPageKey),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 320,
                        child: HeaderSearchBar(pageKey: currentPageKey),
                      ),
                      const SizedBox(width: 16),
                      _HeaderIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh page',
                        onPressed: () => _refreshPage(context, ref),
                      ),
                      const SizedBox(width: 6),
                      _HeaderIconButton(
                        icon: Icons.notifications_outlined,
                        tooltip: 'Notifications',
                        showBadge: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: adminPageFadeDuration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topLeft,
                          children: [
                            ...previousChildren,
                            ?currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(currentPageKey),
                        child: _MainContentScroll(
                          pageKey: currentPageKey,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _breadcrumb(String pageKey) {
    final label = AdminPages.byKey(pageKey)?.label ?? title;
    return 'Home / $label';
  }

  void _refreshPage(BuildContext context, WidgetRef ref) {
    refreshAdminPage(ref, currentPageKey);
    AppSnackBar.info(context, 'Page refreshed');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

class _SidebarNavList extends ConsumerStatefulWidget {
  const _SidebarNavList({
    required this.menuGroups,
    required this.currentPageKey,
  });

  final List<({AdminMenuGroup group, List<AdminPageDef> pages})> menuGroups;
  final String currentPageKey;

  @override
  ConsumerState<_SidebarNavList> createState() => _SidebarNavListState();
}

class _SidebarNavListState extends ConsumerState<_SidebarNavList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      interactive: true,
      radius: const Radius.circular(6),
      thickness: 4,
      thumbVisibility: false,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: [
          for (var groupIndex = 0;
              groupIndex < widget.menuGroups.length;
              groupIndex++) ...[
            if (groupIndex > 0) const SizedBox(height: 8),
            _SidebarGroupHeader(
              label: widget.menuGroups[groupIndex].group.label,
            ),
            const SizedBox(height: 4),
            for (final item in widget.menuGroups[groupIndex].pages)
              _SidebarNavItem(
                item: item,
                isSelected: item.key == widget.currentPageKey,
                highlight: item.key == AdminPages.manageAdminsKey,
              ),
          ],
        ],
      ),
    );
  }
}

class _MainContentScroll extends StatefulWidget {
  const _MainContentScroll({
    required this.pageKey,
    required this.child,
  });

  final String pageKey;
  final Widget child;

  @override
  State<_MainContentScroll> createState() => _MainContentScrollState();
}

class _MainContentScrollState extends State<_MainContentScroll> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_MainContentScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(28),
      child: widget.child,
    );
  }
}

class _SidebarGroupHeader extends StatelessWidget {
  const _SidebarGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    this.highlight = false,
  });

  final AdminPageDef item;
  final bool isSelected;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? AppColors.sidebarActive
            : highlight
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            if (item.route != null) {
              context.go(item.route!);
            }
          },
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    )
                  : highlight
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        )
                      : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected || highlight
                      ? AppColors.primary
                      : Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected || highlight
                          ? Colors.white
                          : Colors.white60,
                      fontWeight:
                          isSelected || highlight ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
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

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white54, size: 17),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showBadge = false,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool showBadge;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: showBadge
              ? Badge(
                  smallSize: 8,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    icon,
                    size: 22,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                )
              : Icon(
                  icon,
                  size: 22,
                  color:
                      isActive ? AppColors.primary : AppColors.textSecondary,
                ),
        ),
      ),
    );
  }
}
