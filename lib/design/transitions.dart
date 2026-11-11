import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tokens.dart';

/// A page that fades in and rises [_rise] logical pixels over
/// [NamoMotion.open], and fades out over [NamoMotion.close], ease-out. Both
/// take no time when the person has asked for no animation.
Page<T> namoPage<T>({
  required LocalKey key,
  required Widget child,
  required BuildContext context,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: NamoMotion.of(context, NamoMotion.open),
    reverseTransitionDuration: NamoMotion.of(context, NamoMotion.close),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final eased = CurvedAnimation(
        parent: animation,
        curve: NamoMotion.curve,
        reverseCurve: NamoMotion.curve,
      );
      return AnimatedBuilder(
        animation: eased,
        child: child,
        builder: (context, child) => Opacity(
          opacity: eased.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - eased.value) * _rise),
            child: child,
          ),
        ),
      );
    },
  );
}

const _rise = 12.0;
