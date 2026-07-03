import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/admin_pages.dart';
import '../../../core/providers/header_search_provider.dart';
import '../../../core/theme/app_theme.dart';

class HeaderSearchBar extends ConsumerStatefulWidget {
  const HeaderSearchBar({
    super.key,
    required this.pageKey,
  });

  final String pageKey;

  @override
  ConsumerState<HeaderSearchBar> createState() => _HeaderSearchBarState();
}

class _HeaderSearchBarState extends ConsumerState<HeaderSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(HeaderSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _clearSearch();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(headerSearchQueryProvider.notifier).state = '';
    _focusNode.unfocus();
  }

  String _hintForPage(String pageKey) {
    return switch (pageKey) {
      AdminPages.manageAdminsKey => 'Search admins...',
      'profile' => 'Search settings...',
      'dashboard' => 'Search dashboard...',
      'users' => 'Search users...',
      'salons' => 'Search salons...',
      'bookings' => 'Search bookings...',
      'add_partners' => 'Search partners...',
      'partner_categories' => 'Search categories...',
      'partner_kyc' => 'Search KYC requests...',
      'partner_manage_accounts' => 'Search partner accounts...',
      'partner_services' => 'Search services...',
      _ => 'Search ${AdminPages.byKey(pageKey)?.label ?? ''}...',
    };
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final hasText = _controller.text.isNotEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_focusNode.hasFocus) _clearSearch();
        },
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: focused
                ? AppColors.primary.withValues(alpha: 0.65)
                : AppColors.border,
            width: focused ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: focused
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: focused ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: focused
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 17,
                color: focused ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: _hintForPage(widget.pageKey),
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  ref.read(headerSearchQueryProvider.notifier).state = value;
                  setState(() {});
                },
                textInputAction: TextInputAction.search,
              ),
            ),
            if (hasText)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(7),
                  child: InkWell(
                    onTap: _clearSearch,
                    borderRadius: BorderRadius.circular(7),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
