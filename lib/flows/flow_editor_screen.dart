import 'dart:math' as math;

import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/not_found.dart';
import '../design/widgets/page_header.dart';
import '../library/library_gate.dart';
import '../router.dart';
import 'add_sections_sheet.dart';
import 'flow_name_sheet.dart';
import 'flow_reading.dart';
import 'flows.dart';

const _moveUp = CustomSemanticsAction(label: 'Move up');
const _moveDown = CustomSemanticsAction(label: 'Move down');

/// One flow: its name, its sections in order (moved by dragging, by a screen
/// reader's actions or from each row's menu, and removed with an Undo), and
/// the ways to add sections, chant it and delete it. An id that is no flow
/// shows the not-found page.
class FlowEditorScreen extends ConsumerStatefulWidget {
  const FlowEditorScreen({
    super.key = const ValueKey('screen-flow-editor'),
    required this.flowId,
  });

  final String flowId;

  @override
  ConsumerState<FlowEditorScreen> createState() => _FlowEditorScreenState();
}

class _FlowEditorScreenState extends ConsumerState<FlowEditorScreen> {
  /// The flow as last drawn, kept to draw while the page leaves after the
  /// flow is deleted (instead of the not-found page).
  Flow? _shown;
  bool _leaving = false;

  FlowsController get _flows => ref.read(flowsProvider.notifier);

  /// Moves the section shown at [from] among [live] to where the one at [to]
  /// is. A stored section the content no longer has keeps its place.
  void _move(Flow flow, List<FlowRef> live, int from, int to) {
    if (from == to) return;
    _flows.move(
      flow.id,
      flow.sections.indexOf(live[from]),
      flow.sections.indexOf(live[to]),
    );
  }

  void _remove(Flow flow, FlowRef section) {
    final at = flow.sections.indexOf(section);
    // Held here: Undo may come after this page has gone.
    final flows = _flows..remove(flow.id, section);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed'),
          duration: const Duration(seconds: 4),
          // With an action a snack bar would otherwise wait to be closed.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => flows.insert(flow.id, at, section),
          ),
        ),
      );
  }

  Future<void> _rename(Flow flow) async {
    final name = await showFlowNameSheet(
      context,
      title: 'Rename flow',
      initial: flow.name,
      action: 'Save',
    );
    if (name != null && mounted) _flows.rename(flow.id, name);
  }

  Future<void> _delete(Flow flow) async {
    final p = NamoPalette.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          'Delete "${flow.name}"? This cannot be undone.',
          style: NamoType.body(p.text),
        ),
        actions: [
          QuietButton(
            key: const ValueKey('flow-delete-keep'),
            label: 'Keep',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PrimaryButton(
            key: const ValueKey('flow-delete-confirm'),
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _leaving = true);
    context.go(Routes.library);
    _flows.delete(flow.id);
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(flowsProvider).flow(widget.flowId);
    final flow = stored ?? (_leaving ? _shown : null);
    if (flow == null) return const NotFoundScreen();
    _shown = flow;
    return LibraryGate(
      builder: (context, library) => _page(context, flow, library),
    );
  }

  Widget _page(BuildContext context, Flow flow, Library library) {
    final p = NamoPalette.of(context);
    final live = liveRefs(flow, library);
    // The frame of a NamoPage, as slivers, so a dragged row scrolls the page.
    final width = MediaQuery.sizeOf(context).width;
    final inset = MediaQuery.paddingOf(context);
    final margin = NamoSizes.pageMargin(width);
    final spare = math.max(
      0.0,
      (width - inset.horizontal - 2 * margin - NamoSizes.readingColumn) / 2,
    );
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              margin + inset.left + spare,
              inset.top + NamoSpace.xl,
              margin + inset.right + spare,
              inset.bottom + NamoSpace.xl,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(child: _header(context, flow, live)),
                if (live.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Symbols.playlist_add_rounded,
                      title: 'This flow has no sections yet.',
                    ),
                  )
                else
                  SliverReorderableList(
                    itemCount: live.length,
                    onReorderItem: (from, to) => _move(flow, live, from, to),
                    proxyDecorator: (child, index, animation) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(NamoRadius.sm),
                        boxShadow: p.floatShadow,
                      ),
                      child: child,
                    ),
                    itemBuilder: (context, i) => _FlowRow(
                      key: ValueKey('flow-row-${flowSectionId(live[i])}'),
                      id: flowSectionId(live[i]),
                      index: i,
                      count: live.length,
                      title: _titleOf(library, live[i]),
                      onMove: (to) => _move(flow, live, i, to),
                      onRemove: () => _remove(flow, live[i]),
                    ),
                  ),
                SliverToBoxAdapter(child: _actions(context, flow, live)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A single section's reading is named by its title, as in a pirith.
  static String _titleOf(Library library, FlowRef section) {
    final reading = library.reading(section.readingId)!;
    if (reading.sections.length == 1) return reading.title;
    return reading.sections.firstWhere((s) => s.id == section.sectionId).heading;
  }

  Widget _header(BuildContext context, Flow flow, List<FlowRef> live) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: NamoIconButton(
          icon: Symbols.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => context.go(Routes.library),
        ),
      ),
      const SizedBox(height: NamoSpace.sm),
      PageHeader(
        title: flow.name,
        caption: sectionCount(live.length),
        trailing: NamoIconButton(
          key: const ValueKey('flow-rename'),
          icon: Symbols.edit_rounded,
          tooltip: 'Rename flow',
          onPressed: () => _rename(flow),
        ),
      ),
      const SizedBox(height: NamoSpace.lg),
    ],
  );

  Widget _actions(BuildContext context, Flow flow, List<FlowRef> live) =>
      Padding(
        padding: const EdgeInsets.only(top: NamoSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: NamoSpace.md,
              runSpacing: NamoSpace.md,
              children: [
                QuietButton(
                  key: const ValueKey('flow-add'),
                  label: 'Add sections',
                  icon: Symbols.add_rounded,
                  onPressed: () =>
                      showAddSectionsSheet(context, flowId: flow.id),
                ),
                PrimaryButton(
                  key: const ValueKey('flow-start'),
                  label: 'Start chanting',
                  icon: Symbols.play_arrow_rounded,
                  onPressed: live.isEmpty
                      ? null
                      : () => context.go(
                          Routes.reader(flow.id, from: ReaderFrom.editor),
                        ),
                ),
              ],
            ),
            const SizedBox(height: NamoSpace.lg),
            TextAction(
              key: const ValueKey('flow-delete'),
              label: 'Delete flow',
              icon: Symbols.delete_rounded,
              onPressed: () => _delete(flow),
            ),
          ],
        ),
      );
}

/// A section in the editor: its place, its title, a menu to move it, a
/// button to remove it and a handle to drag it.
class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required super.key,
    required this.id,
    required this.index,
    required this.count,
    required this.title,
    required this.onMove,
    required this.onRemove,
  });

  /// `<readingId>~<sectionId>`, naming the row's controls.
  final String id;
  final int index, count;
  final String title;

  /// Moves this section to the place [index] ± 1.
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final up = index > 0 ? () => onMove(index - 1) : null;
    final down = index < count - 1 ? () => onMove(index + 1) : null;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            label: '${index + 1}, $title',
            customSemanticsActions: {_moveUp: ?up, _moveDown: ?down},
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NamoSpace.lg,
                  vertical: NamoSpace.md,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: NamoSpace.md,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: NamoSpace.xl,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: NamoType.cardTitle(p.gold),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: NamoType.sectionTitleSinhala(
                          p.text,
                        ).copyWith(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (up != null || down != null)
          _MoveMenu(key: ValueKey('flow-move-$id'), up: up, down: down),
        NamoIconButton(
          key: ValueKey('flow-remove-$id'),
          icon: Symbols.close_rounded,
          tooltip: 'Remove from flow',
          color: p.textSecondary,
          onPressed: onRemove,
        ),
        ReorderableDragStartListener(
          key: ValueKey('flow-handle-$id'),
          index: index,
          // Screen readers move a row with its Move up and Move down actions.
          child: ExcludeSemantics(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox.square(
                dimension: NamoSizes.touchTarget,
                child: Icon(
                  Symbols.drag_indicator_rounded,
                  size: NamoSizes.icon,
                  weight: 300,
                  color: p.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Move up" and "Move down" for a keyboard: a button that opens a menu of
/// the moves this row can make.
class _MoveMenu extends StatelessWidget {
  const _MoveMenu({super.key, required this.up, required this.down});

  final VoidCallback? up, down;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final itemStyle = MenuItemButton.styleFrom(
      minimumSize: const Size(0, NamoSizes.touchTarget),
      padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
      foregroundColor: p.text,
      iconColor: p.textSecondary,
      textStyle: NamoType.label(p.text),
    );
    // The first move takes focus as the menu opens, so a keyboard can
    // choose it at once (or go on with the arrow keys).
    Widget item(
      String label,
      IconData icon,
      VoidCallback onPressed, {
      bool first = false,
    }) => MenuItemButton(
          autofocus: first,
          style: itemStyle,
          leadingIcon: Icon(icon, size: NamoSizes.iconSmall, weight: 300),
          onPressed: onPressed,
          child: Text(label),
        );
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NamoRadius.sm),
            side: BorderSide(color: p.border),
          ),
        ),
      ),
      menuChildren: [
        if (up != null)
          item('Move up', Symbols.arrow_upward_rounded, up!, first: true),
        if (down != null)
          item(
            'Move down',
            Symbols.arrow_downward_rounded,
            down!,
            first: up == null,
          ),
      ],
      builder: (context, menu, _) => NamoIconButton(
        icon: Symbols.swap_vert_rounded,
        tooltip: 'Move',
        color: p.textSecondary,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
