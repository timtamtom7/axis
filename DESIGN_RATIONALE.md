# Design Rationale — AXISBlueprint Theme System

---

## 1. Colors: Why `axisBackground` is #0A0A0C and not pure black

Pure black (`#000000`) creates harsh contrast against macOS system chrome (menubar, window borders) because OS chrome itself is rarely true black — it's typically `#1e1e1e` or `#2d2d2d`. Using `#0A0A0C` (near-black with a cool undertone) creates a *slightly lifted* surface that blends seamlessly with the system dark appearance while still feeling like a deep, focused background. The cool undertone also aligns with SF Symbols and macOS UI conventions.

---

## 2. Three-Tier Surface Elevation (Surface / SurfaceElevated / SurfaceOverlay)

A two-tier surface system (background + surface) collapses at popover scale — you can't distinguish a selected row from an unselected one. We use three tiers:

- **Surface (`#131316`)** — panels, list backgrounds, sidebars
- **SurfaceElevated (`#1A1A1E`)** — cards, message bubbles, hover states
- **SurfaceOverlay (`#222226`)** — dropdowns, tooltips, context ring detail panel

This mirrors the Apple HIG elevation system adapted for a compact popover. Raycast uses a similar approach.

---

## 3. Accent Blue `#4B9EFF` for Primary CTA, Not Purple

The primary action (send button, active tab indicator, primary buttons) must be the most visually distinct element in the UI. Blue has the highest recognition speed and contrast against dark backgrounds of any accent color. Purple (`#7B61FF`) is reserved for AI-specific elements (Claude messages, agent indicators) to create a secondary visual identity — so users instantly recognize "purple = AI, blue = action."

---

## 4. Chat Bubbles: Claude Bubble Darker Than User Bubble

User messages are right-aligned and use `#2A2A30` (lighter than surface), while Claude messages use `#1E1E22` (matches surfaceElevated). This inverted hierarchy (prose lighter than AI, action lighter than reaction) is intentional: user input is "in progress" and visually present, while Claude responses are contextual and recede slightly. Tool outputs use the darkest tint (`#111113`) to create maximum separation from prose — code is a distinct artifact, not conversational content.

---

## 5. Typography: 13pt Mono, Not 14pt

Code and tool output use `SF Mono` at 13pt (not the 14pt body size). This is not arbitrary: at 14pt, monospaced text in a dark popover starts to feel visually heavy next to 14pt prose. 13pt mono is the Apple system default for terminal/code and maintains clear visual hierarchy between prose and output. The 1pt size gap is small but perceptually significant at popover scale.

---

## 6. Line Height = Size + 6pt (Consistent Across All Text Sizes)

Every font size in our system has a line height exactly 6pt larger than its point size (body: 14pt / 20pt line = +6; caption: 12pt / 16pt = +4; mono: 13pt / 18pt = +5). This `+6` rule is derived from SF Pro's native metrics at these sizes — it produces comfortable reading without excessive whitespace. Caption uses +4 because at 12pt, +6 creates a too-open feel for small secondary text.

---

## 7. Negative Letter Spacing on Display/Title, Positive on Caption

Large display text (`20pt semibold`) uses `-0.3pt` tracking; title (`17pt semibold`) uses `-0.2pt`. This compensates for SF Pro's natural tendency to spread at larger sizes, keeping headings tight and authoritative. Caption (`12pt regular`) uses `+0.1pt` tracking because at small sizes, letters can appear to crowd each other in dark mode — a touch of tracking opens it up. Body text uses `0` tracking — no intervention needed at 14pt.

---

## 8. Spacing Scale: Why 10 Values and Why These Intervals

The scale starts at `2pt` (not 4pt) because SF Symbols and inline icon-label combinations need a `2pt` hairline gap — 4pt is too wide for icon-to-text. The intervals are `2, 4, 4, 4, 4, 4, 8, 8, 8` (the 4pt base with every-other-step being 8pt for larger jumps). This is not a geometric series — it's a *felt-scale*: compact → tight → standard → comfortable → spacious → large → very large. Raycast uses an almost identical 9-step scale.

---

## 9. Corner Radii: Why `radiusSmall = 6`, Not 4 or 8

`4pt` is too tight to read as "rounded" on dark surfaces — it looks almost sharp. `8pt` starts to look bubbly in a popover context (feels like iOS, not macOS). `6pt` sits in the perceptually optimal sweet spot: visibly rounded, not childish, native to macOS window chrome. `radiusMedium = 10pt` for inputs is Apple HIG-compliant. `radiusLarge = 14pt` for cards and bubbles gives a premium, approachable feel that matches ChatGPT's macOS app. `radiusXLarge = 20pt` for large modals — the large radius softens the blow of opening a dialog.

---

## 10. Three Shadow Levels, Not One

Using a single shadow for all elevated elements is a common mistake. At popover scale:

- **shadowSubtle** (`radius: 8, opacity: 0.25`) — used on chat message hover cards and the context ring panel. Must be felt, not seen.
- **shadowMedium** (`radius: 16, opacity: 0.35`) — dropdowns and skill panels. Needs to float above the popover background.
- **shadowStrong** (`radius: 32, opacity: 0.50`) — modal dialogs. Must clearly separate from everything behind it.

A single shadow at medium intensity looks wrong everywhere. The gradient of intensity creates the proper depth hierarchy.
