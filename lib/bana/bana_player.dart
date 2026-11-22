import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'bana_catalogue.dart';

/// Builds the video player for [bana]. It reports [onReady] when the player
/// can play and [onError] when it cannot. Tests replace it so no web view is
/// ever created.
typedef BanaPlayerBuilder = Widget Function(
  BuildContext context,
  Bana bana, {
  required VoidCallback onReady,
  required VoidCallback onError,
});

/// The only place that uses `youtube_player_iframe`.
final banaPlayerBuilderProvider = Provider<BanaPlayerBuilder>(
  (ref) => (context, bana, {required onReady, required onError}) =>
      _IframePlayer(
        key: ValueKey(bana.id),
        videoId: bana.id,
        onReady: onReady,
        onError: onError,
      ),
);

class _IframePlayer extends StatefulWidget {
  const _IframePlayer({
    super.key,
    required this.videoId,
    required this.onReady,
    required this.onError,
  });

  final String videoId;
  final VoidCallback onReady, onError;

  @override
  State<_IframePlayer> createState() => _IframePlayerState();
}

class _IframePlayerState extends State<_IframePlayer> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  bool _reported = false;

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
      if (_reported) return;
      if (value.hasError) {
        _reported = true;
        widget.onError();
      } else if (value.playerState != PlayerState.unknown) {
        _reported = true;
        widget.onReady();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
}
