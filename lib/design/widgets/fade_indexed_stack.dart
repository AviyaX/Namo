import 'package:flutter/material.dart';

import '../tokens.dart';

/// Shows the child at [index] and keeps every other child mounted, so each
/// one keeps its state and scroll position. On a change of [index] the
/// outgoing child fades out while the incoming one fades in, over
/// [NamoMotion.quick] (at once when animations are off). A child that is not
/// showing is offstage, its tickers are off, and it is out of the semantics
/// tree and the focus order. While it fades out the outgoing child takes no
/// taps, focus or semantics either.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NamoMotion.quick,
    value: 1,
  )..addStatusListener(_onStatus);
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _controller,
    curve: NamoMotion.curve,
  );
  late final Animation<double> _fadeOut = ReverseAnimation(_fadeIn);

  /// The child fading out, while the switch runs.
  int? _previous;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previous != null) {
      setState(() => _previous = null);
    }
  }

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    final duration = NamoMotion.of(context, NamoMotion.quick);
    if (duration == Duration.zero) {
      _previous = null;
      _controller.value = 1;
      return;
    }
    _previous = old.index;
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _branch(i, widget.children[i]),
      ],
    );
  }

  // The same wrappers for every child at every moment, so a child is never
  // moved in the tree and never loses its state.
  Widget _branch(int i, Widget child) {
    final current = i == widget.index;
    final outgoing = i == _previous && i != widget.index;
    final showing = current || outgoing;
    return Offstage(
      offstage: !showing,
      child: TickerMode(
        enabled: showing,
        child: ExcludeFocus(
          excluding: !current,
          child: ExcludeSemantics(
            excluding: !current,
            child: IgnorePointer(
              ignoring: !current,
              child: FadeTransition(
                opacity: current
                    ? _fadeIn
                    : outgoing
                        ? _fadeOut
                        : kAlwaysCompleteAnimation,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
