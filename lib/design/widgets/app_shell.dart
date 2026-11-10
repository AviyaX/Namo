import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

final _tabs = [
  _Tab('Home', Symbols.home_rounded),
  _Tab('Library', Symbols.menu_book_rounded),
  _Tab('Saved', Symbols.bookmark_rounded),
  _Tab('Settings', Symbols.settings_rounded),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon, weight: 300),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _select,
            destinations: [
              for (final t in _tabs)
                NavigationDestination(
                  icon: Icon(t.icon, weight: 300),
                  label: t.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
