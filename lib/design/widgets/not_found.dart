import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This page could not be found.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
