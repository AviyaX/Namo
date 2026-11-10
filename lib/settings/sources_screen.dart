import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

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
];

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

/// Every verse marked 'needs checking', with its section number and notes.
List<(String id, int section, List<String> notes)> _collectChecks(
  Library library,
) => [
  for (final category in library.categories)
    for (final reading in category.readings)
      for (final section in reading.sections)
        for (final verse in section.verses)
          if (verse.check == CheckStatus.needsChecking)
            (verse.id, section.number, verse.notes),
];

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
          'Namo is not made by, or connected with, namo.lk.',
          textAlign: TextAlign.center,
          style: NamoType.body(p.text),
        ),
        for (final credit in _credits) _CreditBlock(credit),
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
                  for (final (id, section, notes) in checks)
                    _CheckRow(
                      key: ValueKey('check-$id'),
                      section: section,
                      notes: notes,
                    ),
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
    final form = namoText(NamoFonts.sinhala, size: 18, color: p.text);
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
  const _CheckRow({super.key, required this.section, required this.notes});

  final int section;
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
            child: Text('Section $section', style: NamoType.label(p.text)),
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
