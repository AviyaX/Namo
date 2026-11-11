import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/content_repository.dart';
import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/namo_page.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/surface_card.dart';
import '../library/library_gate.dart';
import '../router.dart';

/// One credited source. An address is shown as text to copy, never opened.
class _Credit {
  const _Credit(this.name, this.supplied, [this.address]);

  final String name, supplied;
  final String? address;
}

const _credits = [
  _Credit('namo.lk', 'Sections 1–17.', 'https://namo.lk/buddha-puja/'),
  _Credit(
    'The paritha.org booklet',
    'Compiled by Devapriya and Shyamali from the Piruwana Poth Wahanse, '
        '"for free distribution". Sections 18–19.',
    'https://www.paritha.org/wp-content/uploads/2019/11/Booklet-1.pdf',
  ),
  _Credit(
    'The "Vandana" booklet of Mahamevnawa Bhavana Asapuwa, Markham, Ontario',
    'Part of the English.',
    'https://www.mahamevnawa.ca/uploads/1/0/7/1/107195823/vandana_v1.pdf',
  ),
  _Credit(
    '"Daily Buddha Vandana", prepared by Cynthia Gunawardana, Yasodhara '
        'Dhamma School, Sri Lankarama Maha Viharaya, Ellen Grove, Brisbane',
    'The rest of the English.',
  ),
  _Credit(
    'pitaka.lk/pirith (pathnirvana)',
    'Pirith: Pali text and Sinhala meaning from the Piruwana Poth Wahanse, '
        'as published at pitaka.lk/pirith; English meaning as given there '
        '(its origin is not stated). Chanted by Ven. Nauyane Ariyadhamma '
        'Thero. Licence named by the source: Creative Commons '
        'Attribution-NoDerivatives 4.0 International.',
    'https://pitaka.lk/pirith/',
  ),
];

const _pictureCredits = [
  _Credit(
    'Home card picture',
    'Made for this app by its owner with an AI image tool. It is a '
        'generated picture, not a photograph of a real statue or place.',
  ),
  _Credit(
    'Home banner picture',
    'Shown across the top of Home on wide screens. Made for this app by its '
        'owner with an AI image tool; a generated picture, not a photograph '
        'of a real place.',
  ),
  _Credit(
    'Pirith card picture',
    'Shown on the Pirith card. Made for this app by its owner with an AI '
        'image tool; a generated picture, not a photograph of a real place.',
  ),
  _Credit(
    'Samantha Pattana card picture',
    'Shown on the Samantha Pattana card. Made for this app by its owner with '
        'an AI image tool; a generated picture, not a photograph of a real '
        'place.',
  ),
];

/// The id of the Samantha Pattana topic in the content.
const _samanthaCategoryId = 'cat-samantha-patthana';

/// The Samantha Pattana credit. [title] is the book's Sinhala title, taken
/// from the loaded content.
_Credit _samanthaCredit(String title) => _Credit(
  'Samantha Pattana Dharma Wandanawa',
  'Text: $title, published by tipitaka.lk; converted to Unicode by tool; '
      "the Introduction as supplied by the app's owner. Chanting: Ven. "
      'Kiriwaththuduwe Ariyadassana Thero, from the channel Samata Dharmaya. '
      'No English meaning is included. Namo is not connected with '
      'tipitaka.lk or the channel.',
);

/// A correction as the content file records it, with every section it was
/// made in.
class _CorrectionEntry {
  _CorrectionEntry(this.correction);

  final Correction correction;
  final sections = <int>[];
}

/// Every distinct correction in [library], in reading order.
List<_CorrectionEntry> _collectCorrections(Library library) {
  final entries = <String, _CorrectionEntry>{};
  void add(Correction c, int section) {
    final entry = entries.putIfAbsent(
      '${c.field}|${c.from}|${c.to}|${c.reason}',
      () => _CorrectionEntry(c),
    );
    if (!entry.sections.contains(section)) entry.sections.add(section);
  }

  for (final category in library.categories) {
    for (final reading in category.readings) {
      for (final section in reading.sections) {
        for (final c in section.corrections) {
          add(c, section.number);
        }
        for (final verse in section.verses) {
          for (final c in verse.corrections) {
            add(c, section.number);
          }
        }
      }
    }
  }
  return entries.values.toList();
}

/// What still needs checking: a row key, the row's title and its notes. A
/// reading with one section whose every verse needs checking is one row
/// under the reading's title; otherwise each such verse is a row of its own
/// under its section number.
List<(String key, String title, List<String> notes)> _collectChecks(
  Library library,
) {
  final rows = <(String, String, List<String>)>[];
  for (final category in library.categories) {
    for (final reading in category.readings) {
      final whole =
          reading.sections.length == 1 &&
          reading.sections.single.verses.isNotEmpty &&
          reading.sections.single.verses.every(
            (v) => v.check == CheckStatus.needsChecking,
          );
      if (whole) {
        rows.add(('check-reading-${reading.id}', reading.title, const []));
        continue;
      }
      for (final section in reading.sections) {
        for (final verse in section.verses) {
          if (verse.check == CheckStatus.needsChecking) {
            rows.add((
              'check-${verse.id}',
              'Section ${section.number}',
              verse.notes,
            ));
          }
        }
      }
    }
  }
  return rows;
}

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key = const ValueKey('screen-sources')});

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return NamoPage(
      columnKey: const ValueKey('sources-column'),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: NamoIconButton(
            icon: Symbols.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => context.go(Routes.settings),
          ),
        ),
        const SizedBox(height: NamoSpace.sm),
        const PageHeader(title: 'Sources'),
        const SizedBox(height: NamoSpace.xl),
        Center(
          child: SizedBox(
            key: const ValueKey('sources-icon'),
            width: 96,
            height: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NamoRadius.sm),
              child: Image.asset(
                'assets/branding/namo_icon_square.png',
                semanticLabel: 'Namo',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: NamoSpace.lg),
        Text(
          'Namo is free. It has no ads and nothing to buy.',
          textAlign: TextAlign.center,
          style: NamoType.body(p.text),
        ),
        const SizedBox(height: NamoSpace.sm),
        Text(
          'Namo is not made by, or connected with, namo.lk or pitaka.lk.',
          textAlign: TextAlign.center,
          style: NamoType.body(p.text),
        ),
        for (final credit in _credits) _CreditBlock(credit),
        const _SamanthaCreditBlock(),
        const _SectionLabel('Pictures'),
        for (final credit in _pictureCredits) _CreditBlock(credit),
        LibraryGate(
          builder: (context, library) {
            final corrections = _collectCorrections(library);
            final checks = _collectChecks(library);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (corrections.isNotEmpty) ...[
                  const _SectionLabel('Corrections'),
                  for (final (i, e) in corrections.indexed)
                    _CorrectionRow(key: ValueKey('correction-$i'), entry: e),
                ],
                if (checks.isNotEmpty) ...[
                  const _SectionLabel('Still to be checked'),
                  for (final (key, title, notes) in checks)
                    _CheckRow(key: ValueKey(key), title: title, notes: notes),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: NamoSpace.lg),
        ListRow(
          title: 'Font licences',
          onTap: () =>
              showLicensePage(context: context, applicationName: 'Namo'),
        ),
      ],
    );
  }
}

/// The Samantha Pattana credit, once the content (which holds its Sinhala
/// title) has loaded; nothing before that, or without the topic.
class _SamanthaCreditBlock extends ConsumerWidget {
  const _SamanthaCreditBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).value;
    final title = library?.category(_samanthaCategoryId)?.subtitle;
    if (title == null) return const SizedBox.shrink();
    return _CreditBlock(_samanthaCredit(title));
  }
}

/// A heading over a run of cards.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NamoSpace.xl),
    child: Semantics(
      header: true,
      child: Text(
        text,
        softWrap: true,
        style: NamoType.overline(NamoPalette.of(context).textSecondary),
      ),
    ),
  );
}

/// A card in a run of cards, 16 below the one before.
class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NamoSpace.lg),
    child: SurfaceCard(child: child),
  );
}

class _CreditBlock extends StatelessWidget {
  const _CreditBlock(this.credit);

  final _Credit credit;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return _SourceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(credit.name, style: NamoType.cardTitle(p.text)),
          ),
          const SizedBox(height: NamoSpace.xs),
          Text(credit.supplied, style: NamoType.body(p.textSecondary)),
          if (credit.address != null) ...[
            const SizedBox(height: NamoSpace.xs),
            // A screen reader reads the address as a label; the text can
            // still be selected and copied by touch or mouse.
            Semantics(
              container: true,
              label: credit.address!,
              child: ExcludeSemantics(
                child: SelectableText(
                  credit.address!,
                  style: NamoType.caption(p.sage),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CorrectionRow extends StatelessWidget {
  const _CorrectionRow({super.key, required this.entry});

  final _CorrectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final c = entry.correction;
    final where = entry.sections.length == 1
        ? 'Section ${entry.sections.single}'
        : 'Sections ${entry.sections.join(', ')}';
    final form = NamoType.spelling(p.text);
    final detail = NamoType.caption(p.textSecondary);
    // The arrow is drawn from the bundled icon font: a text arrow is in none
    // of the bundled text fonts and would be fetched from the network.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [
        '${c.from}, corrected to ${c.to}',
        where,
        if (c.reason.isNotEmpty) c.reason,
      ].join(', '),
      child: _SourceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: NamoSpace.sm,
              runSpacing: NamoSpace.xs,
              children: [
                Text(c.from, style: form),
                Icon(
                  Symbols.arrow_right_alt_rounded,
                  size: NamoSizes.icon,
                  weight: 300,
                  color: p.textSecondary,
                ),
                Text(c.to, style: form),
              ],
            ),
            Text(where, style: detail),
            if (c.reason.isNotEmpty) Text(c.reason, style: detail),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({super.key, required this.title, required this.notes});

  final String title;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return _SourceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(title, style: NamoType.label(p.text)),
          ),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(top: NamoSpace.xs),
              child: Text(note, style: NamoType.caption(p.textSecondary)),
            ),
        ],
      ),
    );
  }
}
