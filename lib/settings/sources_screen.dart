import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../library/library_gate.dart';
import 'setting_controls.dart';

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
    TextStyle body({Color? color}) =>
        namoText(NamoFonts.english, size: 16, color: color ?? p.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Sources')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: NamoSizes.readingColumn),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: SizedBox(
                      key: const ValueKey('sources-icon'),
                      width: 96,
                      height: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/branding/namo_icon_square.png',
                          semanticLabel: 'Namo',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    'Namo is free. It has no ads and nothing to buy.',
                    textAlign: TextAlign.center,
                    style: body(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Namo is not made by, or connected with, namo.lk.',
                    textAlign: TextAlign.center,
                    style: body(),
                  ),
                ),
                for (final credit in _credits) _CreditBlock(credit),
                LibraryGate(
                  builder: (context, library) {
                    final corrections = _collectCorrections(library);
                    final checks = _collectChecks(library);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (corrections.isNotEmpty) ...[
                          const SettingsHeading('Corrections'),
                          for (final (i, e) in corrections.indexed)
                            _CorrectionRow(
                              key: ValueKey('correction-$i'),
                              entry: e,
                            ),
                        ],
                        if (checks.isNotEmpty) ...[
                          const SettingsHeading('Still to be checked'),
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
                const SizedBox(height: 16),
                ListRow(
                  title: 'Font licences',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Namo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditBlock extends StatelessWidget {
  const _CreditBlock(this.credit);

  final _Credit credit;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            credit.name,
            style: namoText(NamoFonts.english, size: 18, color: p.text),
          ),
          const SizedBox(height: 4),
          Text(
            credit.supplied,
            style: namoText(NamoFonts.english, size: 16, color: p.textQuiet),
          ),
          if (credit.address != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              credit.address!,
              style: namoText(NamoFonts.english, size: 14, color: p.heading),
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
    final detail = namoText(NamoFonts.english, size: 14, color: p.textQuiet);
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.divider, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(c.from, style: form),
                Icon(Symbols.arrow_right_alt_rounded, size: 22, color: p.textQuiet),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Section $section',
            style: namoText(NamoFonts.english, size: 16, color: p.text),
          ),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                style: namoText(
                  NamoFonts.english,
                  size: 14,
                  color: p.textQuiet,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
