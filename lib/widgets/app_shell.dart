import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_dimens.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'basics.dart';

class NavItem {
  const NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Bottom navigation on phones (blueprint `.bn`), navigation rail on wide screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.items, required this.pages, required this.index, required this.onSelect});

  final List<NavItem> items;
  final List<Widget> pages;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(index: index, children: pages);
    if (context.rs.isExpanded) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.surface,
              selectedIndex: index,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.tint(AppColors.cyan),
              selectedIconTheme: const IconThemeData(color: AppColors.cyan),
              unselectedIconTheme: const IconThemeData(color: AppColors.muted),
              selectedLabelTextStyle: AppText.nav.copyWith(color: AppColors.cyan),
              unselectedLabelTextStyle: AppText.nav,
              destinations: [
                for (final i in items) NavigationRailDestination(icon: Icon(i.icon), label: Text(i.label)),
              ],
            ),
            const VerticalDivider(width: AppSizes.border),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].label,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.sm, AppSpacing.xxs, AppSpacing.md - 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(items[i].icon,
                                size: AppSizes.icon, color: i == index ? AppColors.cyan : AppColors.muted),
                            const Gap(AppSpacing.xs - 1),
                            Text(
                              items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.nav.copyWith(color: i == index ? AppColors.cyan : AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
