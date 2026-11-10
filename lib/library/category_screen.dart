import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/not_found.dart';
import '../router.dart';
import 'library_gate.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return LibraryGate(builder: (context, library) {
      final category = library.category(categoryId);
      if (category == null) return const NotFoundScreen();
      return Scaffold(
        appBar: AppBar(title: Text(category.title)),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: NamoSizes.readingColumn),
            child: ListView(
              children: [
                for (final r in category.readings)
                  ListRow(
                    title: r.title,
                    onTap: () => context.go(Routes.contents(r.id)),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
