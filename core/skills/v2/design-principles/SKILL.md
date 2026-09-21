---
name: design-principles
description: >
  MUST load automatically before every significant frontend project, page, landing,
  SaaS UI, dashboard, web app, marketing or product site, portal, or interactive
  interface. Vivi's permanent design foundation: layering, spacing, restraint,
  hierarchy, typography, color, layout, hero, components, brand adaptation, scales,
  tokens, and the anti-template test. Vivi uses this proactively and never waits for
  a /skill command.
user-invocable: false
---

# Design Principles — Vivi Permanent Design Foundation

**Version 1.1**

## Purpose

This is Vivi's permanent visual design foundation.

It MUST be used as a reference for every significant frontend project. Vivi must NOT wait for the user to explicitly request it.

This skill applies whenever Vivi creates, redesigns, restructures, or significantly modifies:

- websites
- landing pages
- SaaS interfaces
- dashboards
- web applications
- marketing pages
- product pages
- business websites
- portals
- interactive interfaces

This skill defines HOW Vivi thinks about visual design. It does not force every website to look identical.

The objective is:

**CONSISTENT DESIGN QUALITY + UNIQUE BRAND EXPRESSION**

## Composition with the rest of the stack

- `impeccable` — execution layer: composition, typography, color, polish, systematic critique.
- `taste-skill` — judgment layer: anti-slop, purposeful decisions, direct product copy.
- `vivi-visual-excellence` — direction layer: art direction, dials, preflight, delivery standard.
- `design-principles` (this skill) — foundation layer: the principles every decision must satisfy.
- `motion-design` — conditional motion layer: choreography, timing, scroll-driven work.
- `visual-qa` — verification layer: judges the rendered result before delivery.

Execution order is defined in `vivi-visual-excellence`. If another skill, trend, or reference contradicts these principles, the brief, the real content, or usability win.

---

## 01 — The three fundamental principles

Every design must be guided by:

**LAYERING · SPACING · RESTRAINT**

### Layering

Avoid visually flat interfaces. Create visual depth using:

- foreground, midground, background
- typography, imagery, cards
- overlapping elements, shadows, z-index
- visual planes, scale, contrast, perspective

Layering should establish hierarchy. Do not add layers simply because they look impressive. Every layer should have a purpose.

### Spacing

Whitespace is an active design element. Use:

- generous section spacing
- intentional margins
- consistent padding
- controlled content width
- vertical rhythm
- grouping and separation

Do not fill empty space simply because it exists. Empty space can communicate importance, luxury, calm, hierarchy, and focus.

### Restraint

Premium design is not the accumulation of effects. Avoid unnecessary:

- gradients, shadows, glassmorphism
- rounded cards, 3D objects, floating elements
- animations, decorative elements, visual noise

If an element does not improve communication, hierarchy, usability, storytelling, or brand identity, consider removing it.

---

## 02 — Scales

Principles are not executable without numbers. Every project must define these four scales **before** writing components, and every value in the interface must come from them.

### Spacing scale

One base unit, one ladder. A 4px base with an 8px rhythm covers almost every case:

```
4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96 · 128
```

Rules:

- Component-internal padding uses the lower half (4–24).
- Gaps between groups use the middle (24–48).
- Section spacing uses the upper half (48–128).
- Off-scale values are a bug, not a preference. If a layout needs 27px, the scale is wrong — fix the scale, do not add the exception.

Scale section spacing with viewport, never with fixed values at every breakpoint:

```css
--section-y: clamp(4rem, 8vw, 8rem);
```

### Type scale

Pick one ratio and hold it. 1.25 (major third) for product UI, 1.333 (perfect fourth) for editorial and marketing:

```
body   = 1rem      (16px, never below)
ratio  = 1.25      or 1.333
h1     ≈ 3.05rem   h2 ≈ 2.44rem   h3 ≈ 1.95rem   h4 ≈ 1.56rem
```

Further:

- Display and hero type scales with the viewport: `clamp(2.5rem, 6vw, 5rem)`.
- Line-height moves inversely with size: tight for display (0.95–1.1), comfortable for body (1.5–1.7).
- Body copy never below 16px; functional text never below 12px.
- Two families maximum — usually one, plus a mono for code or data.

### Measure

Control line length, not just font size:

- Single column: 45–75 characters, target 65.
- Multi-column or sidebar layouts: 45–60.
- Enforce it with `max-width` in `ch`, not with guessed pixel values.

### Radius and borders

Choose one radius language and apply it consistently:

- Sharp (0–2px): editorial, technical, architectural.
- Soft (6–12px): product UI, the safe default.
- Round (16px+ or pill): consumer, friendly, expressive.

Do not mix languages within a project. A 4px card next to a 24px card reads as an accident.

---

## 03 — Design tokens

A scale that lives only in your head is not a system. Every decision in §02 lands as a token before components are written.

- Colors, spacing, type, radius, shadows, and durations are declared once as CSS custom properties (or the framework's token layer).
- Components consume tokens. No raw hex, no loose `font-size`, no arbitrary `padding` inside a component.
- If a component needs a value the tokens cannot express, the token set is incomplete: extend the scale deliberately, in one place.

```css
:root {
  --space-4: 1rem;
  --space-8: 2rem;
  --section-y: clamp(4rem, 8vw, 8rem);
  --text-body: 1rem;
  --text-h2: 2.44rem;
  --radius-card: 12px;
  --color-surface: /* brand */;
  --color-ink: /* brand */;
}
```

Tokens are the mechanism that makes §01 restraint enforceable and §06 consistency visible. Reuse the repository's existing token layer before inventing a parallel one.

---

## 04 — Design references

Use these references as inspiration and design research:

- Awwwards
- Godly.design
- 21st.dev
- motion-focused websites
- premium editorial websites
- high-end agency websites
- premium SaaS websites
- premium product websites

These references define a QUALITY LEVEL. They do NOT define templates.

NEVER copy exact layouts, text, branding, proprietary illustrations, component structures, or animations.

Instead:

**STUDY → UNDERSTAND → ABSTRACT → RECOMBINE → CREATE ORIGINAL DESIGN**

---

## 05 — Reference analysis

When the user provides a screenshot, website, video, image, competitor, design reference, or an Awwwards / Godly.design / 21st.dev / motion reference, analyze it before implementing.

Identify:

1. Composition
2. Visual hierarchy
3. Typography
4. Spacing
5. Color
6. Grid
7. Layering
8. Imagery
9. Interaction
10. Motion
11. Storytelling
12. Visual rhythm

Then ask internally:

**WHAT MAKES THIS DESIGN EFFECTIVE?**

Do not ask "how can I copy this?" The final implementation must be original.

---

## 06 — Visual hierarchy

Every page must have clear hierarchy. The user should quickly understand:

- WHAT IS THIS?
- WHO IS IT FOR?
- WHY DOES IT MATTER?
- WHAT SHOULD I DO NEXT?

Use display typography, supporting typography, labels, CTAs, visual anchors, imagery, contrast, and scale.

Not every element should have equal visual importance. If everything is emphasized, nothing is.

---

## 07 — Typography

Typography is a structural component, not a styling afterthought.

Prefer:

- strong display typography
- readable body typography
- clear hierarchy
- controlled line length (§02)
- appropriate contrast
- editorial combinations when appropriate

Avoid:

- too many font families
- tiny body text
- excessive font weights
- decorative fonts everywhere
- poor line-height
- awkward wrapping

Headlines should feel intentional. Check that display type breaks at sensible points, not mid-phrase. Typography must work on mobile, where the display scale and the measure both change.

---

## 08 — Color system

Choose colors according to brand, audience, industry, emotional objective, and accessibility.

Prefer:

- a neutral foundation
- one primary brand color
- one or two controlled accents
- strong contrast

Define roles, not colors: surface, raised surface, ink, muted ink, border, brand, accent, success, warning, danger. A color without a role will be used inconsistently.

Do not use gradients simply because they are fashionable. Do not force a universal palette onto every client.

### Dark mode

Decide at the token layer, **before** the first component is written. Retrofitting dark mode onto a light-only palette means rewriting every colour decision, including the ones already baked into imagery and shadows.

**Roles make it possible.** Because §08 defines roles rather than raw values, a theme is a re-declaration of the same roles — not a per-component override:

```css
:root {
  --color-surface: oklch(0.98 0.004 250);
  --color-surface-raised: oklch(1 0 0);
  --color-ink: oklch(0.22 0.02 258);
  --color-ink-muted: oklch(0.52 0.018 255);
  --color-border: oklch(0.90 0.006 250);
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme='light']) {
    --color-surface: oklch(0.17 0.012 258);
    --color-surface-raised: oklch(0.22 0.014 258);
    --color-ink: oklch(0.95 0.006 250);
    --color-ink-muted: oklch(0.70 0.012 255);
    --color-border: oklch(0.30 0.012 258);
  }
}

:root[data-theme='dark'] { /* same block, for explicit choice */ }
```

Rules:

- **Dark mode is not inverted light mode.** Do not flip `#fff` to `#000`. Pure black on pure white texts creates halation and eye strain; real dark themes use a near-black surface (roughly `oklch(0.15–0.20)`) and off-white ink (roughly `oklch(0.92–0.96)`).
- **Elevation reverses.** In light mode, raised surfaces are lighter and cast shadows. In dark mode, raised surfaces are *lighter than the surface* and shadows barely read — elevation comes from surface lightness, not from shadow.
- **Reduce saturation, keep hue.** A vivid brand colour that works on white will vibrate on near-black. Lower chroma and raise lightness for accents in dark mode; keep the hue so it still reads as the brand.
- **Shadows cannot be reused.** A shadow tuned for light mode is invisible on dark. If depth matters, express it with a subtle lighter surface or a hairline border.
- **Respect the system first.** Prefer `prefers-color-scheme` and offer an explicit override; never ship dark-only or light-only when the platform exposes a preference, and never flash the wrong theme on load.
- **Both themes must pass WCAG 2.2 AA independently.** A pairing that passes in light mode proves nothing about dark. `visual-qa` §11 must run against both.

Imagery, illustrations, and logos need a decision too. Photographs usually survive; flat logos, illustrations with white backgrounds, and diagrams often do not — plan a variant rather than discovering it at QA.

---

## 09 — Layout

Do not automatically use NAVBAR → HERO → 3 CARDS → FEATURES → TESTIMONIALS → CTA → FOOTER unless this structure makes sense.

Think about:

**STORY → INFORMATION → EXPERIENCE → ACTION**

Possible layouts: editorial, asymmetric, modular, full-width, constrained, overlapping, horizontal, split-screen, immersive. Choose based on the project.

Vary the rhythm between sections. Eight consecutive centered sections read as a template regardless of how good each one is.

---

## 10 — Hero sections

A hero must communicate:

**WHAT · VALUE · AUDIENCE · ACTION**

Possible techniques:

- oversized typography
- layered imagery
- cinematic photography
- product mockups
- editorial composition
- visual depth
- subtle motion
- strong CTA hierarchy

Avoid generic SaaS hero templates: centered heading, one sentence of abstract value, two buttons, and a floating dashboard mockup.

---

## 11 — Component design

Components should be reusable, configurable, accessible, consistent, and maintainable.

Typical components: Hero, Section, CTA, Card, FeatureGrid, CaseStudy, ProductShowcase, Testimonial, Navigation, Footer.

Components consume tokens (§03) and must not hardcode values. Motion-specific components belong to `motion-design`. Reuse the repository's existing design system before introducing new tokens or patterns.

---

## 12 — Brand adaptation

Every project must have its own visual identity. Determine:

- brand personality, audience, industry, tone
- colors, typography, imagery, visual density
- which references inform it, and which conventions it deliberately rejects

**Do not make every website look alike.** A consistent house style is not the goal at the level of expression — consistency belongs to quality (hierarchy, spacing, craft), not to palette and composition.

Per-client brand directions do not belong in this foundation skill. When a project has an established brand system, it lives in that project's own design document or brand skill. For DEVOGATEC specifically, see `reference/devogatec.md`.

---

## 13 — Anti-template test

Before finalizing, falsify the claim that your design is distinctive. A yes/no question ("does this look like a template?") is easy to answer wrongly; a request for evidence is not.

**Name three decisions that exist only because of this brand and this content.**

Good answers are specific:

- "The hero uses the client's product photography as the background plane, so the page cannot exist without their assets."
- "Section order follows the customer's actual decision sequence, not a generic funnel."
- "The type scale is built on a ratio chosen to match the brand's editorial voice."

Bad answers are generic:

- "It uses their colors."
- "It has their logo."
- "The copy mentions their industry."

If you cannot name three, the design is a template with a logo on it. Improve the art direction before delivery.

---

## 14 — Design before code

Before significant implementation, determine:

PROJECT · AUDIENCE · OBJECTIVE · BRAND · VISUAL LANGUAGE · CONTENT HIERARCHY · LAYOUT · RESPONSIVE STRATEGY · SCALES · TOKENS

Then build. Do not blindly generate components.

---

## 15 — Mobile-first thinking

Mobile is not desktop reduced in size. Consider mobile during design, not after.

Check typography, spacing, navigation, imagery, cards, CTA, content order, and interactions.

Every desktop design decision must have a mobile strategy. Reordering content is often the right mobile answer, not shrinking it.

---

## 16 — Accessibility

Design must consider:

- readable contrast
- semantic structure
- keyboard navigation
- focus states
- readable typography
- accessible controls
- reduced motion

Accessibility is part of quality, not a later phase. Full verification requirements live in `visual-qa`.

---

## 17 — Graceful degradation

Every interface is one failed request away from looking broken. The question is not whether assets will fail, but whether the page still reads as finished when they do.

**A page must hold its composition with any single asset missing.** Design the fallback at the same time as the asset, not after the first incident.

| Failure | What must happen | What must never happen |
|---|---|---|
| **Hero image fails** | The section keeps its height and hierarchy; a solid or tonal background carries the headline | A collapsed section, a broken-image icon at full width, or a layout jump |
| **Web font fails** | A metric-compatible fallback renders; text is readable immediately | Invisible text (`FOIT`), or a visible reflow that shifts the layout |
| **Image slow** | Space is reserved; a dominant-color or blurred placeholder occupies it | Cumulative layout shift when the image lands |
| **Icon or SVG fails** | The accessible name still conveys the meaning | An unlabeled empty box, or a control whose purpose disappears |
| **Third-party embed fails** | The surrounding page is unaffected; the slot degrades to a link | A blank rectangle that reads as broken content |
| **JavaScript fails** | Content and navigation remain readable and operable | A blank page, or navigation that only exists in JS |
| **API data fails** | An error state with a recovery path (see `content-copy` §08) | A permanent skeleton, or a silent empty list |

Rules:

- **Reserve dimensions before the asset arrives.** `width`/`height` attributes, `aspect-ratio`, or a sized container. This is what prevents layout shift, and it is cheap.
- **Never let a decorative asset carry information.** If the meaning disappears with the image, the meaning was never in the markup.
- **Prefer a solid brand tone over a gray box.** A fallback in the palette reads as intentional; a neutral placeholder reads as broken.
- **Test with the network throttled and assets blocked**, not only on a fast local connection. `visual-qa` evidence tooling covers this.

**The test:** block every image, font, and script, and reload. If the page still communicates what it is and what to do next, the design is resilient. If it collapses, that is a Blocking finding.

---

## 18 — Premium design definition

Never interpret "premium", "modern", "beautiful", or "amazing" as "add more effects."

Instead translate them into:

- better hierarchy
- better typography
- better spacing
- better imagery
- stronger composition
- meaningful interaction
- visual restraint
- consistency
- storytelling

---

## 19 — Final design principle

The strongest design is intentional.

Do not ask: "How many effects can I add?"

Ask: "What deserves the user's attention?"

**Design what matters. Remove what does not.**
