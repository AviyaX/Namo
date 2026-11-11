import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../router.dart';
import 'empty_state.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Symbols.explore_off_rounded,
        title: 'This page could not be found.',
        actionLabel: 'Go to Home',
        onAction: () => context.go(Routes.home),
      ),
    );
  }
}
