# Bana — design

Date: 2026-11-22. Owner: Avishka Induwara. Branch `bana` (from `first-release` 7732f6e).

## Why

The owner wants dharma talks (bana) by respected monks inside Namo, arranged
by topic, so a person can find a bana on what they need (meditation, metta,
kamma…) without searching YouTube. The owner sends YouTube playlists or links;
the app arranges them.

## Goals

- A **Bana bottom tab** of its own, like Tripitaka (owner's choice), placed between Library and Tripitaka: six tabs in all.
- Bana are YouTube videos played **inside Namo with YouTube's own embedded
  player**; an **"Open in YouTube"** button on every bana, and the only way
  when a video's owner has turned embedding off or the player fails.
- **Filter by topic and by speaker**, together (e.g. Metta bana by one monk).
- **Series**: a numbered series (a course or a long set) shows as **one series
  card** ("සමථ භාවනාව · 23 parts"); inside, its parts in part order, and
  "Continue: part N" from the last part the person opened.
- The bana list lives **online** on the app's own storage, so new bana appear
  without an app release; a copy ships in the app so the list shows offline
  and on first run.
- Every bana credits its **speaker (monk)** and the **YouTube channel**.
- Android, iPhone and web, in step.

## Non-goals

- No downloading, re-hosting or offline playing of videos or their audio
  (YouTube's terms; no permission asked). Videos stay on YouTube.
- No saving bana to Saved, no Home card, no watched-progress inside a video,
  no comments/likes. (Later, if the owner asks.)
- No admin screen: the list is edited by Claude from the owner's links.

## Anti-goals

- Namo shows no ads of its own; nothing hides or alters YouTube's player
  branding or controls.
- Never invent or rewrite titles: a bana's shown title is its YouTube title
  with only the channel name and monk name trimmed off (copied by the tool,
  not typed).

## Decided (owner)

- Embedded YouTube player + Open in YouTube fallback (approach A).
- Its own bottom tab (owner overrode "Library after Books"); online list with a bundled copy.
- Topic + speaker filters; series as one card with parts inside and resume.
- Current content (2 monks, 180 bana), from the owner's playlists:
  - Ven. Na Uyane Ariyadhamma Maha Thero — 85 single bana (channel
    "Budu Dahama බුදු දහම", playlist PLGNIkoMWkSHwt6A8dAjMOziznanGdB8SM) and
    the 23-part course **සමථ භාවනාව** (channel "Yathiwara Adawiya යතිවර
    අඩවිය", playlist PLiOaRw4J4Uyv9IBNP9aDWxsluAqtC_Bng).
  - Ven. Kiriwaththuduwe Ariyadassana Thero — the series **පට්ඨාන ධර්ම
    දේශනා මාලාව**, all 72 parts (68 from the playlist, parts 38, 45, 48, 50
    found on the same channel by search) (channel "Wassana Dharma Deshana
    වස්සාන ධර්ම දේශනා", playlist PLoV7IpZqAgVSLpauPjwUnoYi2VVuRxT33).
- Topics, in this order (Sinhala — English):
  1. භාවනාව — Meditation (the සමථ භාවනාව course + 7 single meditation bana)
  2. මෛත්‍රී — Loving-kindness
  3. බුදු ගුණ — Qualities of the Buddha
  4. සූත්‍ර දේශනා — Suttas explained
  5. කර්මය හා සංසාරය — Kamma and samsara
  6. දානය, පින් හා පාරමිතා — Giving, merit and perfections
  7. මාර්ගය හා ප්‍රඥාව — The path and wisdom
  8. උතුමන්ගේ චරිත — Lives of the noble ones
  9. පොහොය දින දේශනා — Poya day talks
  10. එදිනෙදා ජීවිතයට — Mind and daily life
  11. පට්ඨානය — Patthana (the Patthana series + Ven. Na Uyane's
      "සමත්ත පට්ඨාන මහා ප්‍රකරණය", which also stays in topic 7)
  The per-bana topic choices are in `tool/bana/draft-list.json` (field
  `topics`, codes M ME BG SU KS DP PW LV PY DL PT; first = main topic).
  A bana may have several topics; a series has its topics too.

## Decided (designer's calls — owner may overrule)

- **The list file**: one JSON, `bana.json`, served at
  `<audio host>/audio/bana/bana.json` (the Worker only serves `audio/`).
  Contents: `version` (int, bumped on every change), `topics` (id, Sinhala,
  English, order), `speakers` (id, display name), `channels` (id, name, URL),
  `series` (id, title, speaker, channel, topics, total parts if known, parts
  as video ids in part order), `bana` (YouTube video id, title, speaker,
  channel, topics, length in seconds, optional series id + part number).
  Unknown fields are ignored; a malformed file is ignored (keep the last good
  one). The bundled copy is the same file under `assets/bana/`.
- **Refresh**: when the Bana section opens, at most once a day, fetch the list
  in the background (same User-Agent as recordings); keep it if newer
  `version`; show the stored/bundled list immediately. No spinner blocks the
  list.
- **Thumbnails** come from YouTube's image server when online; offline, a
  plain card in the app's colours with the title. No thumbnails stored.
- **Offline**: the list, filters and series all work; opening a bana offline
  says plainly "Bana play from YouTube and need an internet connection." with
  a retry.
- **Player screen**: the player at the top (16:9), then title, speaker,
  channel (tap = channel page in YouTube), "Open in YouTube". For a series
  part: "Part N of M", Previous / Next part, and the part list. If the player
  reports embedding not allowed / errors, the player area shows the message
  and the Open in YouTube button instead.
- **Privacy**: use YouTube's privacy-enhanced (no-cookie) embed where the
  player supports it; Namo sends no personal data.
- **Ads note**: Settings → Sources gains a Bana entry crediting each channel
  and saying the bana play from YouTube, which may show its own ads.
- **Search**: Library search also finds bana by title (and series parts),
  shown as a "Bana" group of results.
- **Series card**: series title, speaker, "N parts", and "Continue: part K"
  once any part was opened (remembered on the device, per series).
- **Part numbers** in the Patthana series: all 72 present; six numbers were placed
  by playlist order because the titles lacked or repeated a number
  (`partGuessed: true` in the draft) — the owner checks these later; the app
  just uses the part numbers in the file.
- **Speaker filter** lists only speakers in the list; topic chips show only
  topics with bana for the chosen speaker.
- **Tool**: a small script under `tool/bana/` rebuilds `bana.json` from the
  playlists + a topics mapping file, so adding the owner's next links is
  repeatable; it fetches titles/lengths from YouTube's public playlist page.

## Settled after the builder check (designer's calls)

- **Embed package**: a WebView/iframe-based player such as
  `youtube_player_iframe` is acceptable. Small platform differences (autoplay
  blocked on iOS/web, fullscreen behaviour) are fine; no spike needed.
- **Embedding allowed**: checked 2026-11-22 through YouTube's oEmbed: all 176
  allow embedding. Each bana in `bana.json` carries `embeddable` (bool); the
  tool re-checks it. When false, the player screen shows Open in YouTube in
  place of the player. A runtime player error does the same.
- **Hosting**: `bana.json` is uploaded by Claude with
  `npx wrangler r2 object put namo-audio/audio/bana/bana.json … --remote`
  (same as recordings and builds; the Worker already serves `audio/` keys with
  CORS headers the web app uses for recordings). The plan includes the
  tool command that produces the file and this upload step as the last task;
  freshness relies on the `version` field, not cache headers.
- **Missing series parts** (none now, rule kept for later series): parts are only the ones present. The series card
  says "68 parts" (and, where the file gives a known total, "of 72"); the
  player shows "Part 39"; Previous/Next go to the neighbouring present part
  (37 → 39).
- **Topics and series**: a series has its own topics (the course: Meditation;
  the Patthana series: Patthana). Its parts carry no topics of their own. A
  topic filter shows the series card whole if the series has that topic. A
  single bana in two topics shows in both.
- **Resume**: "Continue: part K" = the last part opened (reopen it), stored on
  the device only, per series.
- **Search**: a hit on a series part opens that part's player screen, with its
  series context (Part N, Previous/Next).
- **Navigation**: the Bana tab's screen is the full Bana list (monk chips,
  topic chips, series cards and bana). Routes: `/bana`, `/bana/series/:id`,
  `/bana/play/:videoId` (deep-linkable). Mockup:
  https://claude.ai/artifact/VqqWCNDmoCCBcSBeqL1zsX
- **Title trimming**: the tool trims only known strings listed in its mapping
  file (channel names, the monks' name forms) plus separators, and prints any
  title that still contains a speaker or channel fragment for review. The
  owner reviews titles in the list Claude sends before upload.
- **Offline**: no connectivity package. The list works from storage; the
  player screen shows the "need an internet connection" message when the
  player fails to load (error or no ready event within a timeout), with retry
  and Open in YouTube.
- **Web**: the web build fetches `bana.json` from the same Worker (CORS as for
  recordings) and embeds YouTube iframes, which any host allows.

## Constraints

Project rules apply: Android, iOS and web in step; no overflow at 320 wide
with large text; 48-point targets; theme tokens only; text never invented;
reduced motion respected; sources credited; app stays totally free.

## Left to the builder

The embed package (one that works on Android, iOS and web), exact layouts,
how the filters look (chips vs. dropdown for speaker), list caching storage,
the tool's language.
