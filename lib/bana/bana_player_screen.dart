import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/app_shell.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/not_found.dart';
import '../design/widgets/pressable.dart';
import '../router.dart';
import '../settings/powered_by.dart';
import 'bana_catalogue.dart';
import 'bana_player.dart';
import 'bana_progress.dart';
import 'bana_repository.dart';

/// How long the player may take to get ready before we call it offline.
const _readyTimeout = Duration(seconds: 15);

const _offlineMessage =
    'Bana play from YouTube and need an internet connection.';

enum _Status { loading, ready, failed }

/// One bana, playing with YouTube's player; its neighbours in the series
/// below.
class BanaPlayerScreen extends ConsumerStatefulWidget {
  const BanaPlayerScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<BanaPlayerScreen> createState() => _BanaPlayerScreenState();
}

class _BanaPlayerScreenState extends ConsumerState<BanaPlayerScreen> {
  _Status _status = _Status.loading;
  int _attempt = 0;
  bool _started = false;
  Timer? _timeout;

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(_readyTimeout, () {
      if (mounted && _status == _Status.loading) {
        setState(() => _status = _Status.failed);
      }
    });
  }

  void _onReady() {
    if (!mounted || _status != _Status.loading) return;
    _timeout?.cancel();
    setState(() => _status = _Status.ready);
  }

  void _onError() {
    if (!mounted || _status == _Status.failed) return;
    _timeout?.cancel();
    setState(() => _status = _Status.failed);
  }

  void _retry() {
    setState(() {
      _attempt++;
      _status = _Status.loading;
    });
    _armTimeout();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.bana);

  void _open(Bana bana) => ref.read(linkOpenerProvider)(bana.watchUri);

  /// Once the bana is known: remember it, and start waiting for the player.
  void _begin(Bana bana) {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(banaProgressProvider.notifier).opened(bana);
      if (bana.embeddable) _armTimeout();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final cat = ref.watch(banaCatalogueProvider).value;
    final bana = cat?.byId(widget.videoId);
    if (cat != null && bana == null) return const NotFoundScreen();
    if (bana != null) _begin(bana);

    final width = MediaQuery.sizeOf(context).width;
    final column = width >= NamoSizes.wideBreakpoint
        ? NamoSizes.homeColumn
        : NamoSizes.readingColumn;
    final margin = ((width - column) / 2).clamp(
      NamoSizes.pageMargin(width),
      double.infinity,
    );
    final inset = MediaQuery.paddingOf(context);

    final Widget body = (cat == null || bana == null)
        ? const Center(child: CircularProgressIndicator())
        : _content(context, p, cat, bana);

    return Scaffold(
      key: const ValueKey('screen-bana-player'),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              margin + inset.left,
              inset.top + NamoSpace.lg,
              margin + inset.right,
              inset.bottom + NamoSpace.xl,
            ),
            sliver: SliverList.list(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: NamoIconButton(
                    icon: Symbols.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: _back,
                  ),
                ),
                const SizedBox(height: NamoSpace.sm),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    NamoPalette p,
    BanaCatalogue cat,
    Bana bana,
  ) {
    final series = bana.series == null ? null : cat.seriesById(bana.series!);
    final parts = series == null ? const <Bana>[] : cat.partsOf(series.id);
    final at = parts.indexWhere((b) => b.id == bana.id);
    final inSeries = series != null && at >= 0;
    final previous = inSeries && at > 0 ? parts[at - 1] : null;
    final next = inSeries && at < parts.length - 1 ? parts[at + 1] : null;
    final upcoming = inSeries
        ? parts.skip(at + 1).take(2).toList()
        : const <Bana>[];
    final speaker =
        cat.speakers.where((s) => s.id == bana.speaker).firstOrNull?.name ??
        bana.speaker;
    final channel = cat.channels[bana.channel]?.name ?? bana.channel;
    final channelUri = Uri.tryParse(cat.channels[bana.channel]?.url ?? '');
    final channelUrl = channelUri != null && channelUri.hasScheme
        ? channelUri
        : null;

    void go(Bana b) => context.pushReplacement(Routes.banaPlay(b.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _playerArea(context, p, bana),
        const SizedBox(height: NamoSpace.lg),
        if (inSeries) ...[
          Text(
            'PART ${at + 1} OF ${parts.length}',
            style: NamoType.overline(p.gold),
          ),
          const SizedBox(height: NamoSpace.sm),
        ],
        Semantics(
          header: true,
          child: Text(bana.title, style: NamoType.screenTitle(p.text)),
        ),
        const SizedBox(height: NamoSpace.sm),
        Text(speaker, style: NamoType.body(p.textSecondary)),
        const SizedBox(height: NamoSpace.xs),
        _SourceLine(
          text: '${bana.lengthLabel} · From YouTube · $channel',
          channel: channel,
          onOpenChannel: channelUrl == null
              ? null
              : () => ref.read(linkOpenerProvider)(channelUrl),
        ),
        if (previous != null || next != null) ...[
          const SizedBox(height: NamoSpace.lg),
          Row(
            children: [
              if (previous != null)
                Expanded(
                  child: QuietButton(
                    key: const ValueKey('bana-previous'),
                    label: 'Part $at',
                    icon: Symbols.skip_previous_rounded,
                    onPressed: () => go(previous),
                  ),
                ),
              if (previous != null && next != null)
                const SizedBox(width: NamoSpace.md),
              if (next != null)
                Expanded(
                  child: QuietButton(
                    key: const ValueKey('bana-next'),
                    label: 'Part ${at + 2}',
                    icon: Symbols.skip_next_rounded,
                    onPressed: () => go(next),
                  ),
                ),
            ],
          ),
        ],
        if (bana.embeddable) ...[
          const SizedBox(height: NamoSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextAction(
              key: const ValueKey('bana-open-youtube'),
              label: 'Open in YouTube',
              icon: Symbols.open_in_new_rounded,
              onPressed: () => _open(bana),
            ),
          ),
        ],
        if (inSeries) ...[
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: NamoSpace.lg),
            Text('NEXT IN THIS SERIES', style: NamoType.overline(p.gold)),
            const SizedBox(height: NamoSpace.sm),
            for (var i = 0; i < upcoming.length; i++)
              _UpNextRow(
                key: ValueKey('bana-up-${upcoming[i].id}'),
                number: at + 2 + i,
                bana: upcoming[i],
                onTap: () => go(upcoming[i]),
              ),
          ],
          const SizedBox(height: NamoSpace.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextAction(
              key: const ValueKey('bana-all-parts'),
              label: 'All ${parts.length} parts ›',
              onPressed: () => context.push(Routes.banaSeries(series.id)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _playerArea(BuildContext context, NamoPalette p, Bana bana) {
    if (!bana.embeddable) {
      return _Panel(
        message: 'This bana can only be played on YouTube.',
        onOpen: () => _open(bana),
      );
    }
    if (_status == _Status.failed) {
      return _Panel(
        message: _offlineMessage,
        onRetry: _retry,
        onOpen: () => _open(bana),
      );
    }
    final tab = ref.watch(currentTabProvider);
    final player = KeyedSubtree(
      key: ValueKey('player-$_attempt'),
      child: ref.read(banaPlayerBuilderProvider)(
        context,
        bana,
        onReady: _onReady,
        onError: _onError,
        active: tab == null || tab == TabIndex.bana,
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: NamoSizes.playerColumn),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(NamoRadius.sm)),
          child: ColoredBox(
            color: p.backgroundAlt,
            child: AspectRatio(aspectRatio: 16 / 9, child: player),
          ),
        ),
      ),
    );
  }
}

/// "10:00 · From YouTube · Channel": the line opens the channel's page.
class _SourceLine extends StatelessWidget {
  const _SourceLine({
    required this.text,
    required this.channel,
    required this.onOpenChannel,
  });

  final String text, channel;
  final VoidCallback? onOpenChannel;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final line = Text(text, style: NamoType.caption(p.textSecondary));
    if (onOpenChannel == null) return line;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Pressable(
        key: const ValueKey('bana-channel'),
        onTap: onOpenChannel!,
        borderRadius: const BorderRadius.all(Radius.circular(NamoRadius.sm)),
        semanticLabel: '$text. Opens $channel on YouTube',
        excludeChildSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: line,
          ),
        ),
      ),
    );
  }
}

/// Stands where the player would: why it is not there, and what to do.
class _Panel extends StatelessWidget {
  const _Panel({required this.message, required this.onOpen, this.onRetry});

  final String message;
  final VoidCallback onOpen;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: NamoSizes.playerColumn),
        child: Container(
          padding: const EdgeInsets.all(NamoSpace.lg),
          decoration: BoxDecoration(
            color: p.backgroundAlt,
            borderRadius: const BorderRadius.all(
              Radius.circular(NamoRadius.sm),
            ),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Symbols.wifi_off_rounded,
                size: NamoSizes.icon,
                color: p.textSecondary,
              ),
              const SizedBox(height: NamoSpace.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: NamoType.body(p.text),
              ),
              const SizedBox(height: NamoSpace.lg),
              if (onRetry != null) ...[
                PrimaryButton(
                  key: const ValueKey('bana-retry'),
                  label: 'Try again',
                  icon: Symbols.refresh_rounded,
                  onPressed: onRetry,
                ),
                const SizedBox(height: NamoSpace.sm),
                QuietButton(
                  key: const ValueKey('bana-open-youtube'),
                  label: 'Open in YouTube',
                  icon: Symbols.open_in_new_rounded,
                  onPressed: onOpen,
                ),
              ] else
                PrimaryButton(
                  key: const ValueKey('bana-open-youtube'),
                  label: 'Open in YouTube',
                  icon: Symbols.open_in_new_rounded,
                  onPressed: onOpen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    super.key,
    required this.number,
    required this.bana,
    required this.onTap,
  });

  final int number;
  final Bana bana;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NamoSpace.xs),
      child: Pressable(
        onTap: onTap,
        borderRadius: radius,
        semanticLabel: 'Part $number, ${bana.title}, ${bana.lengthLabel}',
        excludeChildSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          padding: const EdgeInsets.all(NamoSpace.sm),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Text('$number', style: NamoType.label(p.textSecondary)),
              const SizedBox(width: NamoSpace.md),
              Expanded(child: Text(bana.title, style: NamoType.body(p.text))),
              const SizedBox(width: NamoSpace.sm),
              Text(bana.lengthLabel, style: NamoType.caption(p.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
