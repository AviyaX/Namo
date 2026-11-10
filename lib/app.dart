import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/theme.dart';

class NamoApp extends ConsumerWidget {
  const NamoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Namo',
      theme: namoTheme(Brightness.light),
      darkTheme: namoTheme(Brightness.dark),
      home: const Scaffold(body: Center(child: Text('Namo'))),
    );
  }
}
