import 'package:flutter/material.dart';

import '../tokens/brew_layout.dart';

/// One top-level destination.
class BrewNavDestination {
  const BrewNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

/// Top-level navigation that adapts to width (from BREW's
/// `ScaffoldWithNav`): a bottom bar on phones, a rail from
/// [BrewBreakpoints.compact], and a rail with labels from
/// [BrewBreakpoints.medium].
///
/// Router-agnostic. With go_router's `StatefulShellRoute`, pass the
/// navigation shell as [body], `shell.currentIndex` as [selectedIndex], and
/// `shell.goBranch` as [onSelected].
class BrewAdaptiveShell extends StatelessWidget {
  const BrewAdaptiveShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.railLeading,
    this.railTrailing,
  }) : assert(destinations.length >= 2);

  final List<BrewNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  /// Above the rail's destinations: the app mark, a compose button.
  final Widget? railLeading;

  /// Below them: settings, account.
  final Widget? railTrailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (BrewBreakpoints.isCompact(width)) {
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon ?? d.icon),
                  label: d.label,
                ),
            ],
          ),
        );
      }
      final extended = width >= BrewBreakpoints.medium;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: railLeading,
              trailing: railTrailing == null
                  ? null
                  : Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: BrewSpacing.lg,
                          ),
                          child: railTrailing,
                        ),
                      ),
                    ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon ?? d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    },
  );
}
