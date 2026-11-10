<!-- The owner's original written spec, pasted on 2026-11-09. Kept unchanged for reference. Later decisions are in 2026-11-10-gatha-app-first-release-design.md. -->

# Claude Code Implementation Prompt — Buddhist Gatha MVP 01

Act as a Senior Flutter Developer, UI/UX Designer and Software Architect.

We are starting a premium Buddhist prayer and Gatha application for Android and iOS.

## 1. Project objective

Build a minimalist, elegant, premium-looking Buddhist Gatha reading application.

The app should feel like a beautifully designed digital Buddhist prayer book, not a colourful generic mobile application.

The first release must focus on one content section:

**Namaskaraya to Deviyanta Pin Dima**

Do not build unnecessary features or overcomplicate the initial version.

## 2. Technology

- Flutter and Dart
- Android and iOS support
- Clean, maintainable architecture
- Local SQLite database or structured local JSON for initial content
- Offline-first functionality
- Local persistence for user preferences and reading progress

Before implementation, inspect the existing project. If it is empty, establish the Flutter project structure. Do not overwrite existing work unnecessarily.

## 3. Premium UI/UX design

Use a calm, refined Buddhist editorial design.

Colour palette:

- Warm ivory: #F5F1E8
- Soft sand: #E8E0D2
- Muted antique gold: #A88B5B
- Deep forest green: #354638
- Charcoal: #292A26

Design requirements:

- Minimal and premium appearance.
- Elegant typography.
- Comfortable reading spacing.
- Thin-line icons.
- Subtle borders.
- Very limited shadows.
- No bright gradients.
- No colourful category cards.
- No oversized headings.
- No unnecessary animations.
- No excessive rounded corners.

Typography:
- Sinhala: Noto Sans Sinhala or another verified readable Sinhala font.
- English: Lora or Noto Serif.
- Roman Pali: Noto Serif.
- Support appropriate Sinhala-script Pali content where supplied.

Bundle the fonts locally.

## 4. Language selection

Support three languages:

1. Sinhala
2. English
3. Pali

Users must be able to select either one language or two languages simultaneously.

Examples:
- Sinhala only
- English only
- Pali only
- Sinhala + English
- Sinhala + Pali
- English + Pali

Do not allow all three languages to be selected simultaneously.

Persist language preferences.

When two languages are selected, support two display layouts:

- Section layout: one language followed by the other.
- Verse layout: corresponding verses displayed together, one after another.

The user can switch between these layouts.

Important: Never invent religious translations. Keep original text, transliteration and translations as separate content fields.

## 5. Reader screen

This is the most important feature.

Create a premium, distraction-free reading interface.

Include:

- Gatha title.
- Category name.
- Selected language or languages.
- Clearly formatted prayer text.
- Font size adjustment.
- Reading line-spacing adjustment.
- Bookmark.
- Favourite.
- Reading progress.
- Previous and next content navigation.
- Reader settings.

The screen should be comfortable for extended reading.

Remember the user's last reading position and restore it when reopening the content.

## 6. Automatic scrolling

Implement smooth automatic scrolling.

Controls:

- Play.
- Pause.
- Resume.
- Reset to beginning.
- Slow speed.
- Normal speed.
- Fast speed.
- Custom adjustable speed.

Requirements:

- Smooth continuous vertical scrolling.
- No sudden jumps.
- Pause immediately when the user manually interacts with the reader.
- Resume from the current position.
- Keep the controls accessible but visually minimal.
- Allow the user to adjust scrolling speed without leaving the reader.

Do not use a timer-based approach that produces jerky scrolling. Use an appropriate Flutter scrolling controller and animation strategy.

## 7. Audio support — with and without audio

Audio must be optional.

The application must work completely without audio.

Design the architecture to support recorded chanting audio in the future.

Reader audio controls should support:

- Play.
- Pause.
- Resume.
- Restart.
- Audio progress.
- Audio duration.
- Optional background playback.
- Audio playback while reading.
- Optional auto-scroll while audio is playing.

Important:

- Do not generate fake chanting recordings.
- Do not use generic text-to-speech as a substitute for authentic Buddhist chanting.
- Do not assume audio files exist.
- Use local sample placeholders only for development, clearly identified as placeholders.
- Build an audio repository/service abstraction so authentic recordings can be added later.
- If no recording exists for a Gatha, hide or disable the audio control gracefully.
- Audio and auto-scrolling must work independently as well as together.

The user must be able to choose:

1. Reading without audio.
2. Listening without automatic scrolling.
3. Reading with audio and automatic scrolling.

## 8. Initial content

Create the first category:

**Namaskaraya to Deviyanta Pin Dima**

Keep the content data structured to support:

- Sinhala text.
- English text.
- Pali text.
- Original source reference.
- Translator attribution.
- Audio file reference.
- Content verification status.

Do not fabricate the prayer or its translations. If verified text is unavailable, create a clearly labelled content placeholder and leave the content fields empty until supplied.

## 9. Basic navigation

Keep navigation simple:

- Home
- Library
- Saved
- Settings

For the initial release, only the first prayer category needs to contain real content.

## 10. Settings

Include:

- Language selection.
- Reader layout selection.
- Font size.
- Line spacing.
- Default scrolling speed.
- Audio preference.
- Light/dark theme.

Persist settings locally.

## 11. Quality requirements

This is a production-minded MVP, not a disposable UI mockup.

Ensure:

- Android and iOS compatibility.
- No horizontal overflow.
- Sinhala Unicode renders correctly.
- Pali diacritics render correctly.
- Smooth scrolling on different screen sizes.
- Correct handling of missing audio.
- Reading progress persists after app restarts.
- Language combinations display correctly.
- No crashes when switching languages during reading.
- Offline functionality.
- Accessible touch targets and screen-reader labels.

## 12. Development approach

Use a structured implementation process.

First:

1. Inspect the repository.
2. Review the existing Flutter setup.
3. Identify available assets and dependencies.
4. Propose the architecture and screen structure.
5. Create a short implementation plan.

Then implement in small, testable stages:

Stage 1: Premium design system and navigation.

Stage 2: Home screen and initial category.

Stage 3: Multilingual content model and language selection.

Stage 4: Premium reader screen.

Stage 5: Automatic scrolling.

Stage 6: Optional audio architecture and playback integration.

Stage 7: Local persistence and reading progress.

Stage 8: Tests, UI refinement and Android/iOS validation.

Use Superpowers workflows where appropriate: plan before implementation, write tests for important behaviour, and verify each stage before moving forward.

Do not attempt to implement everything in one large unverified change.

## Final design objective

The finished application should feel like a premium digital Buddhist prayer book.

The reading experience, typography, calm atmosphere, multilingual support and automatic scrolling are the priorities.

Keep the first release focused on:

**Namaskaraya to Deviyanta Pin Dima — Sinhala, English and Pali — with optional audio and automatic scrolling.**
