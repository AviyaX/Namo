import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'bana_catalogue.dart';

/// Builds the video player for [bana]. It reports [onReady] when the player
/// can play and [onError] when it cannot. While [active] is false (another
/// tab is showing) the video must be paused. Tests replace it so no web view is
/// ever created.
typedef BanaPlayerBuilder = Widget Function(
  BuildContext context,
  Bana bana, {
  required VoidCallback onReady,
  required VoidCallback onError,
  required bool active,
});

/// The only place that uses `youtube_player_iframe`.
final banaPlayerBuilderProvider = Provider<BanaPlayerBuilder>(
  (ref) =>
      (context, bana, {required onReady, required onError, required active}) =>
          _IframePlayer(
            key: ValueKey(bana.id),
            videoId: bana.id,
            onReady: onReady,
            onError: onError,
            active: active,
          ),
);

class _IframePlayer extends StatefulWidget {
  const _IframePlayer({
    super.key,
    required this.videoId,
    required this.onReady,
    required this.onError,
    required this.active,
  });

  final String videoId;
  final VoidCallback onReady, onError;
  final bool active;

  @override
  State<_IframePlayer> createState() => _IframePlayerState();
}

class _IframePlayerState extends State<_IframePlayer> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Privacy-enhanced (youtube-nocookie.com) is the package's default.
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    _sub = _controller.listen((value) {
      // An error is let through even after ready: YouTube often says
      // "embedding not allowed" only then. The page ignores repeats.
      if (value.hasError) {
        widget.onError();
      } else if (!_ready && value.playerState != PlayerState.unknown) {
        _ready = true;
        widget.onReady();
      }
    });
  }

  @override
  void didUpdateWidget(_IframePlayer old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) {
      unawaited(_controller.pauseVideo().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_controller.close().catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
}
