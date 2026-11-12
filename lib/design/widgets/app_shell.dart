import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';
import '../typography.dart';
import 'floating_bar.dart';
import 'pressable.dart';

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _tabs = [
  _Tab('Home', Symbols.home_rounded),
  _Tab('Library', Symbols.menu_book_rounded),
  _Tab('Tripitaka', Symbols.auto_stories_rounded),
  _Tab('Saved', Symbols.bookmark_rounded),
  _Tab('Settings', Symbols.settings_rounded),
];

/// The tabs' places in the bar, as the router's branches are listed.
abstract final class TabIndex {
  static const home = 0;
  static const library = 1;
  static const tripitaka = 2;
  static const saved = 3;
  static const settings = 4;
}

/// A press on the tab that is already showing: which tab, and a count that
/// changes with every press, so a tab's first page can reset itself (empty
/// its search) when its tab is pressed again.
class TabPressedAgain extends Notifier<(int, int)?> {
  @override
  (int, int)? build() => null;

  void press(int index) => state = (index, (state?.$2 ?? 0) + 1);
}

final tabPressedAgainProvider =
    NotifierProvider<TabPressedAgain, (int, int)?>(TabPressedAgain.new);

/// The width of the side rail on wide screens.
const _railWidth = 88.0;

/// Room around a destination's icon and label, inside its pill.
const _pillPadding = NamoSpace.xs;

TextStyle _labelStyle(Color color) => NamoType.tabLabel(color);

/// The tabs: a floating bar at the foot of a phone screen, a rail at the
/// left of a wide one. Pressing the active tab takes it back to its first
/// page.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(int index) {
      final again = index == shell.currentIndex;
      shell.goBranch(index, initialLocation: again);
      if (again) ref.read(tabPressedAgainProvider.notifier).press(index);
    }

    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            // Clear of a display cut-out or a rounded edge on the left.
            SafeArea(
              right: false,
              child: _Rail(current: shell.currentIndex, onSelect: select),
            ),
            Expanded(child: shell),
          ],
        ),
      );
    }
    // extendBody: the pages run under the bar and see its whole height in
    // MediaQuery.padding.bottom, so they can scroll their ends clear of it.
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _Bar(current: shell.currentIndex, onSelect: select),
    );
  }
}

/// The scale for the labels in slots [slotWidth] wide: the person's text
/// size, unless the longest label would then not fit on one line, when it is
/// the largest size that fits, never below the labels' own 12 px. When even
/// 12 px does not fit, the labels wrap (the bar grows; nothing is cut off).
TextScaler _labelScaler(
  BuildContext context,
  double slotWidth, {
  double pillPadding = _pillPadding,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final size = _measuredLabelStyle(context).fontSize!;
  final wanted = scaler.scale(size) / size;
  if (wanted <= 1) return scaler;
  final room = slotWidth - 2 * pillPadding;
  bool fits(double factor) => _labelsFit(context, room, factor);

  if (fits(wanted)) return scaler;
  var factor = wanted;
  while (factor > 1 && !fits(factor)) {
    factor = factor - 0.05 < 1 ? 1 : factor - 0.05;
  }
  return TextScaler.linear(factor);
}

/// The label style the way the Text widget will lay it out: over the
/// inherited default style.
TextStyle _measuredLabelStyle(BuildContext context) => DefaultTextStyle.of(
  context,
).style.merge(_labelStyle(NamoPalette.of(context).text));

/// Whether every label, at [factor] times its size, is at most [room] wide on
/// one line.
bool _labelsFit(BuildContext context, double room, double factor) {
  final style = _measuredLabelStyle(context);
  final direction = Directionality.of(context);
  for (final t in _tabs) {
    final tp = TextPainter(
      text: TextSpan(text: t.label, style: style),
      textDirection: direction,
      textScaler: TextScaler.linear(factor),
      maxLines: 1,
    )..layout();
    final width = tp.width;
    tp.dispose();
    if (width > room) return false;
  }
  return true;
}

/// The bar's horizontal spacing: its margin from the screen's sides, its
/// own padding and the room either side of a label inside its pill.
typedef _BarSpacing = ({double side, double padding, double pill});

/// From roomiest to tightest. A narrow phone takes the first spacing at
/// which every label fits on one line at its own 12 px; the labels may then
/// grow up to the person's text size within it.
const List<_BarSpacing> _barSpacings = [
  (side: NamoSpace.lg, padding: NamoSpace.xs, pill: _pillPadding),
  (side: NamoSpace.sm, padding: NamoSpace.xs, pill: _pillPadding),
  (side: NamoSpace.sm, padding: NamoSpace.xs, pill: 0),
  (side: NamoSpace.sm, padding: 0, pill: 0),
];

class _Bar extends StatelessWidget {
  const _Bar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    // The width of one destination: the bar's margins, padding and 1 px
    // border taken off, shared out.
    double slot(_BarSpacing s) =>
        (width - inset.left - inset.right - 2 * s.side - 2 * s.padding - 2) /
        _tabs.length;
    final spacing = _barSpacings.firstWhere(
      (s) => _labelsFit(context, slot(s) - 2 * s.pill, 1),
      orElse: () => _barSpacings.last,
    );
    final scaler = _labelScaler(
      context,
      slot(spacing),
      pillPadding: spacing.pill,
    );
    return Padding(
      key: const ValueKey('nav-bar'),
      padding: EdgeInsets.fromLTRB(
        spacing.side + inset.left,
        0,
        spacing.side + inset.right,
        NamoSpace.md + inset.bottom,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: NamoSizes.navBarHeight),
        child: FloatingBar(
          pill: true,
          padding: EdgeInsets.all(spacing.padding),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _Destination(
                      tab: _tabs[i],
                      active: i == current,
                      pill: true,
                      pillPadding: spacing.pill,
                      scaler: scaler,
                      onTap: () => onSelect(i),
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

class _Rail extends StatelessWidget {
  const _Rail({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    // The rail's inside: its padding and 1 px border taken off.
    final scaler =
        _labelScaler(context, _railWidth - 2 * NamoSpace.sm - 1);
    return Container(
      key: const ValueKey('nav-rail'),
      width: _railWidth,
      decoration: BoxDecoration(
        color: p.backgroundAlt,
        border: BorderDirectional(end: BorderSide(color: p.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: NamoSpace.sm,
          vertical: NamoSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _tabs.length; i++) ...[
              if (i > 0) const SizedBox(height: NamoSpace.sm),
              _Destination(
                tab: _tabs[i],
                active: i == current,
                scaler: scaler,
                onTap: () => onSelect(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One tab: icon over label. The active one has a filled icon and a sage
/// pill behind it.
class _Destination extends StatelessWidget {
  const _Destination({
    required this.tab,
    required this.active,
    this.pill = false,
    this.pillPadding = _pillPadding,
    required this.scaler,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;

  /// Fully rounded (in the bottom bar) rather than the rail's small radius.
  final bool pill;

  /// The room either side of the label inside the pill.
  final double pillPadding;
  final TextScaler scaler;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final color = active ? p.onSage : p.textSecondary;
    final radius = BorderRadius.circular(pill ? NamoRadius.pill : NamoRadius.sm);
    return Pressable(
      key: ValueKey('nav-${tab.label.toLowerCase()}'),
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: tab.label,
      selected: active,
      excludeChildSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: NamoMotion.of(context, NamoMotion.quick),
          curve: NamoMotion.curve,
          padding: EdgeInsets.symmetric(
            horizontal: pillPadding,
            vertical: _pillPadding,
          ),
          decoration: BoxDecoration(
            color: active ? p.sage : p.sage.withAlpha(0),
            borderRadius: radius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: NamoSizes.icon,
                weight: 300,
                fill: active ? 1 : 0,
                color: color,
              ),
              const SizedBox(height: NamoSpace.xs),
              Text(
                tab.label,
                textAlign: TextAlign.center,
                textScaler: scaler,
                style: _labelStyle(color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
