import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tips.dart';

/// Where each tip's controls are: the keys of the [TipAnchor]s on screen.
class TipAnchors extends ChangeNotifier {
  final Map<Tip, List<GlobalKey>> _keys = {};
  bool _notifyPending = false;
  bool _disposed = false;

  List<GlobalKey> keysFor(Tip tip) => List.unmodifiable(_keys[tip] ?? const []);

  void register(Tip tip, GlobalKey key) {
    (_keys[tip] ??= []).add(key);
    _notifySoon();
  }

  void unregister(Tip tip, GlobalKey key) {
    _keys[tip]?.remove(key);
    _notifySoon();
  }

  /// Anchors come and go while widgets build, when no provider may change:
  /// listeners hear of it once the build is over.
  void _notifySoon() {
    if (_notifyPending) return;
    _notifyPending = true;
    scheduleMicrotask(() {
      _notifyPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final tipAnchorsProvider = Provider<TipAnchors>((ref) {
  final anchors = TipAnchors();
  ref.onDispose(anchors.dispose);
  return anchors;
});

/// Marks [child] as the control [tip] points at. Several anchors for one tip
/// share one cut-out.
class TipAnchor extends ConsumerStatefulWidget {
  const TipAnchor({super.key, required this.tip, required this.child});

  final Tip tip;
  final Widget child;

  @override
  ConsumerState<TipAnchor> createState() => _TipAnchorState();
}

class _TipAnchorState extends ConsumerState<TipAnchor> {
  final _key = GlobalKey();
  late final TipAnchors _anchors;

  @override
  void initState() {
    super.initState();
    _anchors = ref.read(tipAnchorsProvider);
    _anchors.register(widget.tip, _key);
  }

  @override
  void didUpdateWidget(TipAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tip != widget.tip) {
      _anchors.unregister(oldWidget.tip, _key);
      _anchors.register(widget.tip, _key);
    }
  }

  @override
  void dispose() {
    _anchors.unregister(widget.tip, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
