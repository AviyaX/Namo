<!-- The owner's redesign brief, pasted on 2026-11-10. Kept word for word; nothing here was written by the builder. -->

# Namo – Complete Premium UI/UX Transformation

Act as a world-class Senior Product Designer, UI/UX Architect and Senior Flutter Developer.

I want you to completely redesign the existing Namo application to achieve a genuinely premium, modern, minimalist and sophisticated visual experience.

The current application looks like a basic, outdated mobile application. It uses simple containers, basic navigation bars, excessive empty space and generic UI components.

I do NOT want minor styling improvements. I want a complete visual design transformation.

## 1. Design Vision

Namo is a Buddhist spiritual reading application containing Buddhist Gathas, Buddha Vandana, Pirith and Tripitaka content in:

- Pali
- Sinhala
- English

The application should communicate:

- Peace
- Serenity
- Wisdom
- Simplicity
- Spirituality
- Premium craftsmanship

Design inspiration:
- Apple Books
- Headspace (but less colourful)
- Calm
- Premium digital reading applications
- Modern editorial typography
- High-end minimalist wellness applications

The final result should feel like a professionally designed international application, not a typical template-based Flutter application.

## 2. Visual Design System

Establish a consistent design system before implementing individual screens.

### Colour palette

Use a sophisticated dark theme as the primary experience.

Background:
- Main background: #151714
- Secondary background: #1C1F1B
- Elevated surfaces: #232720
- Subtle borders: #34382F

Typography:
- Primary text: #EAE6DC
- Secondary text: #A9A698
- Muted text: #77776D

Accent:
- Soft sage green: #A8B99F
- Secondary accent: #C6A879 (subtle muted gold)

Use accent colours sparingly.

Avoid:
- Bright green
- Neon colours
- Excessive gradients
- Highly saturated colours
- Unnecessary colourful icons
- Heavy shadows
- Excessive borders

The application should feel warm, elegant and comfortable for extended reading.

## 3. Typography

Typography is one of the most important aspects of this redesign.

Use a carefully selected typography system that supports all three languages.

Requirements:
- Elegant serif typography for important titles and Buddhist content.
- Clean sans-serif typography for navigation, labels and supporting information.
- Excellent Sinhala rendering.
- Proper Pali diacritics support.
- Consistent font weights and line heights.
- Carefully controlled font sizes.

Do not use excessively large headings.

Ensure Sinhala, Pali and English have consistent visual balance.

Use suitable fonts such as Noto Serif, Noto Sans Sinhala and Noto Sans for their respective language requirements, or better alternatives already available in the project.

## 4. Bottom Navigation

Redesign the bottom navigation completely.

Current navigation looks like a default Android navigation bar.

Create a refined floating or subtly elevated bottom navigation experience.

Navigation items:
1. Home
2. Library
3. Saved
4. Settings

Requirements:
- Elegant outline icons.
- Subtle active-state background.
- Sage green active indicator.
- Muted inactive icons.
- Carefully balanced spacing.
- Small, sophisticated labels.
- Smooth transitions when switching tabs.
- Respect device safe areas.

Avoid oversized navigation icons and generic Material-style navigation appearance.

## 5. Home Screen

Completely redesign the current Home screen.

The current screen has a basic heading and one rectangular content card.

New design:

### Header
- Display Namo with elegant typography.
- Keep the header minimal.
- Include a subtle greeting or peaceful introductory message if appropriate.
- Provide a refined settings/profile access point if needed.

### Featured content

Create a visually beautiful featured Buddha Vandana section.

Requirements:
- Use high-quality Buddhist imagery.
- Use large, carefully cropped imagery.
- Elegant rounded corners.
- Sophisticated typography.
- Subtle image overlays only when needed for text readability.
- Avoid excessive card decoration.

### Content discovery

Introduce elegant sections such as:
- Continue Reading
- Daily Gatha
- Buddha Vandana
- Popular Collections
- Recently Added

Use horizontal content collections where appropriate.

Do not overcrowd the Home screen.

Maintain generous but intentional spacing.

## 6. Library Screen

Redesign the current Library screen.

The current implementation has a basic dropdown and an enormous empty area.

Create a more sophisticated content discovery experience.

Requirements:
- Elegant Library heading.
- Search functionality.
- Refined category or collection selectors.
- Well-designed content list.
- Meaningful empty states.
- Clear content hierarchy.

For Buddha Vandana, show:
- Title
- Sinhala subtitle
- Number of sections
- Optional thumbnail or subtle visual indicator.

Use beautiful editorial-style list items rather than generic rectangular cards.

The library should feel like a premium digital book collection.

## 7. Reading Experience

This is one of the most important screens in Namo.

Create an exceptional distraction-free reading experience.

Requirements:
- Beautiful typography.
- Excellent Sinhala, Pali and English rendering.
- Adjustable text size.
- Comfortable line spacing.
- Clear section hierarchy.
- Minimal controls.
- Audio playback controls when available.
- Auto-scrolling functionality.
- Reading progress indicator.
- Bookmark functionality.

### Language selection

Users should be able to select two languages simultaneously.

Supported combinations:
- Pali + Sinhala
- Pali + English
- Sinhala + English

Make language selection elegant and intuitive.

Avoid ordinary dropdowns where a refined segmented selection or language selector would work better.

Ensure both languages remain visually distinguishable without introducing unnecessary colours.

## 8. Saved Screen

Create a premium saved-content experience.

Requirements:
- Elegant page heading.
- Saved Gathas and sections.
- Refined list layout.
- Clear empty state.
- Easy navigation back to the original content.

Avoid generic empty-state illustrations.

## 9. Settings Screen

Redesign settings using elegant grouped sections.

Possible sections:
- Appearance
- Reading preferences
- Language preferences
- Audio preferences
- Auto-scroll settings
- About Namo

Use subtle dividers, refined icons and excellent spacing.

Avoid making settings look like a basic Android settings page.

## 10. Micro-interactions and Animations

Introduce subtle, purposeful animations.

Examples:
- Smooth page transitions.
- Elegant tab switching.
- Subtle button press feedback.
- Smooth expanding and collapsing sections.
- Refined audio player interactions.
- Gentle loading transitions.

Animations should feel natural and premium.

Avoid unnecessary bouncing, flashy effects or excessive motion.

## 11. Component Design Standards

Every component must follow the same design system.

Pay particular attention to:
- Consistent corner radiuses.
- Consistent spacing.
- Typography hierarchy.
- Icon sizing.
- Button dimensions.
- Touch target sizes.
- Card proportions.
- Responsive layouts.
- Safe area handling.

Avoid:
- Default Flutter buttons.
- Default dropdown styling.
- Generic Material cards.
- Excessive rounded rectangles.
- Unnecessary outlines.
- Repeated identical card layouts.
- Inconsistent padding.

Use custom-designed components wherever necessary.

## 12. Technical Implementation Requirements

Before changing anything:

1. Inspect the entire existing project structure.
2. Identify the current Flutter architecture.
3. Understand the existing navigation and routing.
4. Identify existing reusable widgets.
5. Understand the current data models and content-loading mechanism.
6. Identify existing audio, language selection, bookmarking and auto-scroll implementations.

IMPORTANT:

This is a UI/UX redesign, NOT a request to rebuild the application's functionality.

Preserve all existing functionality.

Do not:
- Remove existing features.
- Change existing content structures unnecessarily.
- Break navigation.
- Break language switching.
- Break audio playback.
- Break auto-scrolling.
- Break saved content.
- Introduce unnecessary dependencies.
- Replace working functionality with dummy implementations.

Refactor components where necessary to achieve a clean and maintainable architecture.

## 13. Implementation Strategy

Work in the following order:

Phase 1: Inspect the existing application and understand its architecture.

Phase 2: Establish the design system, theme, typography and reusable components.

Phase 3: Redesign bottom navigation and overall application structure.

Phase 4: Redesign Home and Library screens.

Phase 5: Redesign the reading experience.

Phase 6: Redesign Saved and Settings screens.

Phase 7: Implement transitions, animations and interaction refinements.

Phase 8: Run the application, inspect every screen and fix visual inconsistencies.

## 14. Quality Expectations

I want you to think like a premium product design team, not like a developer simply changing colours.

Every screen must look intentionally designed.

Pay attention to visual hierarchy, whitespace, proportions, typography and consistency.

Do not stop after creating a basic dark theme.

Do not just describe the improvements. Actually implement them in the existing codebase.

After implementation:

- Run Flutter analysis.
- Resolve compilation errors.
- Test navigation.
- Test language selection.
- Test reading and auto-scrolling.
- Test saved content.
- Test audio functionality.
- Check different mobile screen sizes.

## Final Design Direction

Imagine opening Namo and immediately feeling that this is a beautifully crafted Buddhist spiritual companion.

It should feel peaceful, modern, premium and timeless.

The design should be minimal without feeling empty, sophisticated without feeling complicated, and spiritual without looking outdated.

**My expectation: A production-quality premium application that could comfortably compete with internationally released meditation, reading and wellness applications.**
