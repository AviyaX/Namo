import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/widgets/app_shell.dart';
import 'design/widgets/not_found.dart';
import 'home/home_screen.dart';
import 'library/library_screen.dart';
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

  /// The Library with this category's sections showing.
  static String category(String id) =>
      '/library?open=${Uri.encodeQueryComponent(id)}';

  /// The Library with the sections of the category holding this reading
  /// showing (the Library works out which category that is).
  static String contents(String readingId) =>
      '/library?reading=${Uri.encodeQueryComponent(readingId)}';

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
                  builder: (context, state) => LibraryScreen(
                      openCategory: state.uri.queryParameters['open'],
                      openReading: state.uri.queryParameters['reading']),
                  routes: [
                    // Saved links from before the in-place list.
                    GoRoute(
                        path: 'category/:id',
                        redirect: (context, state) =>
                            Routes.category(state.pathParameters['id']!)),
                    GoRoute(
                        path: 'reading/:id',
                        redirect: (context, state) =>
                            Routes.contents(state.pathParameters['id']!)),
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
