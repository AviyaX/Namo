"""Pull the pirith text and its chanting times out of the downloaded pitaka.lk page files.

The page at https://pitaka.lk/pirith/ keeps everything inside two script files:
the main one holds, per recording, the text (Pali phrase, Sinhala meaning,
English meaning) grouped into blocks and one [start, end] time in seconds per
block; the "locales" one holds the list of recordings and the site's credit
lines. This tool only reads those files as text; it never runs them.

usage:
  python -I -X utf8 tools/extract_pitaka_pirith.py <site_dir> <audio_dir> <out.json>

<site_dir>  folder with index-*.js, locales-*.js and pnfo_pirith_README.md
<audio_dir> folder with the downloaded <id>.m4a files (sizes are recorded)
"""
import datetime
import glob
import json
import os
import re
import sys

BS = chr(92)
QUOTES = '`"' + "'"


def literal_end(s, i):
    """i at '{' or '[': index just after the matching close, strings honoured."""
    depth = 0
    while i < len(s):
        c = s[i]
        if c in QUOTES:
            q = c
            i += 1
            while s[i] != q:
                i += 2 if s[i] == BS else 1
        elif c in '{[':
            depth += 1
        elif c in '}]':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError('unbalanced literal')


def unescape(raw):
    out = []
    i = 0
    while i < len(raw):
        c = raw[i]
        if c == BS:
            d = raw[i + 1]
            if d == 'u':
                out.append(chr(int(raw[i + 2:i + 6], 16)))
                i += 6
                continue
            out.append({'n': '\n', 't': '\t'}.get(d, d))
            i += 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def to_json(lit):
    """A JavaScript data literal (strings, numbers, lists, objects) as JSON text."""
    out = []
    i = 0
    n = len(lit)
    while i < n:
        c = lit[i]
        if c in QUOTES:
            j = i + 1
            while lit[j] != c:
                j += 2 if lit[j] == BS else 1
            out.append(json.dumps(unescape(lit[i + 1:j]), ensure_ascii=False))
            i = j + 1
        elif c.isalpha() or c in '_$':
            j = i
            while j < n and (lit[j].isalnum() or lit[j] in '_$'):
                j += 1
            word = lit[i:j]
            if j < n and lit[j] == ':':
                out.append(json.dumps(word))
            elif word in ('true', 'false', 'null'):
                out.append(word)
            else:
                raise ValueError('not plain data: ' + word)
            i = j
        elif c == '.' and i + 1 < n and lit[i + 1].isdigit() and not lit[i - 1].isdigit():
            out.append('0.')
            i += 1
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def one(pattern, folder):
    found = sorted(p for p in glob.glob(os.path.join(folder, pattern)) if 'legacy' not in p)
    if len(found) != 1:
        raise SystemExit(f'expected exactly one {pattern} in {folder}, found {len(found)}')
    return found[0]


def main():
    site_dir, audio_dir, out_path = sys.argv[1:4]
    main_js = one('index-*.js', site_dir)
    locales_js = one('locales-*.js', site_dir)
    readme = open(os.path.join(site_dir, 'pnfo_pirith_README.md'), encoding='utf-8').read()
    src = open(main_js, encoding='utf-8').read()
    loc = open(locales_js, encoding='utf-8').read()

    # text and times
    m = re.search(r'=\{"\d\d-[a-z-]+":\{labels:', src)
    a = m.start() + 1
    timing = json.loads(to_json(src[a:literal_end(src, a)]))

    # list of recordings: [`id`, number, `Sinhala title`, `chanter key`, `m:ss`]
    rows = re.findall(r'\[`(\d\d-[a-z0-9-]+)`,(\d+),`([^`]*)`,`([a-z]+)`,`([\d:]+)`\]', loc)
    chanters = {k: {'name_si': si, 'name_en': en}
                for k, si, en in re.findall(r'([a-z]+):\[`([^`]*)`,`([^`]*)`,\[128,256,512\]\]', loc)}
    # the site's own credit lines, in each language it has them
    credits = [list(pair) for pair in re.findall(r'about1:`([^`]*)`,about2:`([^`]*)`', loc)]
    licence = readme[readme.find('## LICENCE'):].strip()

    items = []
    problems = []
    for tid, num, title, who, dur in rows:
        audio = os.path.join(audio_dir, tid + '.m4a')
        item = {
            'id': tid,
            'number': int(num) + 1,
            'title_si': title,
            'chanter': who,
            'duration': dur,
            'audio_file': tid + '.m4a',
            'audio_bytes': os.path.getsize(audio) if os.path.exists(audio) else None,
            'audio_url': f'https://pitaka.lk/pirith/audio/{tid}.m4a',
            'blocks': [],
        }
        t = timing.get(tid)
        if t is None:
            item['text'] = 'none on the site (recording only)'
        else:
            labels, text = t['labels'], t['text']
            if len(labels) != len(text):
                problems.append(f'{tid}: {len(labels)} times for {len(text)} blocks')
            for i, block in enumerate(text):
                lab = labels[i] if i < len(labels) else []
                start = lab[0] if len(lab) >= 1 else None
                end = lab[1] if len(lab) >= 2 else None
                if i and start is not None and labels[i - 1][0] > start:
                    # a filler time (the site has [0] here): this block was never timed
                    problems.append(f'{tid} block {i + 1}: the site gives it no usable time '
                                    f'({json.dumps(lab)}); stored without a time')
                    start = end = None
                elif end is None and start is not None and i + 1 < len(labels):
                    end = labels[i + 1][0]
                    problems.append(f'{tid} block {i + 1}: no end time on the site; next start used')
                item['blocks'].append({
                    'n': i + 1,
                    'start': start,
                    'end': end,
                    'pairs': [{'pali': r.get('pali', ''), 'sinhala': r.get('sinh', ''),
                               'english': r.get('eng', '')} for r in block],
                })
        items.append(item)
    for tid in timing:
        if tid not in {r[0] for r in rows}:
            problems.append(f'{tid}: has text but is not in the list of recordings')

    with_text = [it for it in items if it['blocks']]
    out = {
        'source': 'https://pitaka.lk/pirith/',
        'source_project': 'https://github.com/pnfo/pirith',
        'fetched_utc': datetime.datetime.fromtimestamp(
            os.path.getmtime(main_js), datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'method': 'Text and times read out of the page\'s own script files '
                  '(source_material/pitaka_lk_pirith/site) by tools/extract_pitaka_pirith.py; '
                  'nothing typed by hand. Block i uses time i, as the site does. Inside a block the '
                  'site has no per-phrase times: it estimates the phrase from the Pali text length.',
        'reuse_terms_on_site': licence,
        'credits_on_site': credits,
        'status': 'Owner said on 2026-11-10 that they will get permission from the site\'s makers. '
                  'Not to be shipped in the app until that permission is in hand.',
        'chanters': chanters,
        'counts': {
            'recordings': len(items),
            'with_text': len(with_text),
            'blocks': sum(len(it['blocks']) for it in items),
            'pairs': sum(len(b['pairs']) for it in items for b in it['blocks']),
            'audio_bytes': sum(it['audio_bytes'] or 0 for it in items),
        },
        'problems': problems,
        'items': items,
    }
    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print('recordings', len(items), '| with text', len(with_text), '| blocks', out['counts']['blocks'],
          '| pairs', out['counts']['pairs'], '| audio MB', round(out['counts']['audio_bytes'] / 1048576, 1))
    print('chanters', json.dumps(chanters, ensure_ascii=False))
    print('licence line:', licence.replace('\n', ' | '))
    print('credits:', json.dumps(credits, ensure_ascii=False))
    print('problems', len(problems))
    for p in problems:
        print('  ', p)


if __name__ == '__main__':
    main()
