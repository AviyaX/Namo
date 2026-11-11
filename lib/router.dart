import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/transitions.dart';
import 'design/widgets/app_shell.dart';
import 'design/widgets/fade_indexed_stack.dart';
import 'design/widgets/not_found.dart';
import 'flows/flow_editor_screen.dart';
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

  /// The Library with its search box focused.
  static const librarySearch = '/library?focus=search';

  /// The Library with this category's sections showing.
  static String category(String id) =>
      '/library?open=${Uri.encodeQueryComponent(id)}';

  /// The Library with the sections of the category holding this reading
  /// showing (the Library works out which category that is).
  static String contents(String readingId) =>
      '/library?reading=${Uri.encodeQueryComponent(readingId)}';

  /// The reader; [from] names the page Back returns to (the Library when
  /// absent).
  static String reader(
    String readingId, {
    String? sectionId,
    ReaderFrom? from,
  }) {
    final query = [
      if (sectionId != null) 'section=$sectionId',
      if (from != null) 'from=${from.name}',
    ];
    return query.isEmpty
        ? '/read/$readingId'
        : '/read/$readingId?${query.join('&')}';
  }

  /// The editor of one flow.
  static String flowEditor(String flowId) => '/library/flow/$flowId';
}

/// The pages that open the reader and want Back to return to them. The
/// reader is opened with `go`, so it is the only page on the stack; Back
/// goes by this value in the address instead, the same way on every
/// platform and after a reload of the web page. [editor] is a flow's editor,
/// and means nothing for a reading that is not a flow.
enum ReaderFrom { home, saved, editor }

GoRouter buildRouter({String initialLocation = Routes.home}) => GoRouter(
  initialLocation: initialLocation,
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => AppShell(shell: shell),
      // Every tab stays mounted (its state and scroll position kept); the
      // switch between tabs is a cross-fade.
      navigatorContainerBuilder: (context, shell, children) =>
          FadeIndexedStack(index: shell.currentIndex, children: children),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.library,
              builder: (context, state) => LibraryScreen(
                openCategory: state.uri.queryParameters['open'],
                openReading: state.uri.queryParameters['reading'],
                focusSearch: state.uri.queryParameters['focus'] == 'search',
              ),
              routes: [
                // Saved links from before the in-place list.
                GoRoute(
                  path: 'category/:id',
                  redirect: (context, state) =>
                      Routes.category(state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'reading/:id',
                  redirect: (context, state) =>
                      Routes.contents(state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'flow/:id',
                  pageBuilder: (context, state) => namoPage(
                    key: state.pageKey,
                    context: context,
                    child: FlowEditorScreen(
                      flowId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.saved,
              builder: (context, state) => const SavedScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.settings,
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'sources',
                  pageBuilder: (context, state) => namoPage(
                    key: state.pageKey,
                    child: const SourcesScreen(),
                    context: context,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/read/:id',
      pageBuilder: (context, state) => namoPage(
        key: state.pageKey,
        context: context,
        child: ReaderScreen(
          readingId: state.pathParameters['id']!,
          sectionId: state.uri.queryParameters['section'],
          from:
              ReaderFrom.values.asNameMap()[state.uri.queryParameters['from']],
        ),
      ),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
