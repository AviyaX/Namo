import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/widgets/app_shell.dart';
import 'design/widgets/not_found.dart';
import 'home/home_screen.dart';
import 'library/category_screen.dart';
import 'library/library_screen.dart';
import 'library/reading_contents_screen.dart';
import 'reader/reader_screen.dart';
import 'saved/saved_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/sources_screen.dart';

abstract final class Routes {
  static const home = '/';
  static const library = '/library';
  static const saved = '/saved';
  static const settings = '/settings';
  static const sources = '/settings/sources';

  static String category(String id) => '/library/category/$id';
  static String contents(String readingId) => '/library/reading/$readingId';
  static String reader(String readingId, {String? sectionId}) =>
      sectionId == null
          ? '/read/$readingId'
          : '/read/$readingId?section=$sectionId';
}

GoRouter buildRouter({String initialLocation = Routes.home}) => GoRouter(
      initialLocation: initialLocation,
      errorBuilder: (context, state) => const NotFoundScreen(),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: Routes.home,
                  builder: (context, state) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: Routes.library,
                  builder: (context, state) => const LibraryScreen(),
                  routes: [
                    GoRoute(
                        path: 'category/:id',
                        builder: (context, state) => CategoryScreen(
                            categoryId: state.pathParameters['id']!)),
                    GoRoute(
                        path: 'reading/:id',
                        builder: (context, state) => ReadingContentsScreen(
                            readingId: state.pathParameters['id']!)),
                  ]),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: Routes.saved,
                  builder: (context, state) => const SavedScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: Routes.settings,
                  builder: (context, state) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                        path: 'sources',
                        builder: (context, state) => const SourcesScreen()),
                  ]),
            ]),
          ],
        ),
        GoRoute(
            path: '/read/:id',
            builder: (context, state) => ReaderScreen(
                readingId: state.pathParameters['id']!,
                sectionId: state.uri.queryParameters['section'])),
      ],
    );

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
