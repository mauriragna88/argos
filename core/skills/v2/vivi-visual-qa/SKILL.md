---
name: vivi-visual-qa
description: >
  Use AFTER significant frontend implementation, before declaring any interface complete.
  Verifies the actual rendered result — desktop, tablet and mobile — for typography,
  spacing, color, images, motion, interaction, accessibility, responsive behavior and
  performance. A successful build does NOT mean a successful design. Model-only: never wait
  for or require a /skill command.
agent: vivi
source: ARGOS propio (Vivi visual verification v1.0)
user-invocable: false
---

# Visual QA — Vivi's Frontend Visual Verification System

Part of Vivi's design pipeline: `vivi-design-principles` (always first) → `vivi-motion-design` (when applicable) → `vivi-visual-qa` (last). Vivi loads these automatically.

## Purpose

This skill verifies the actual rendered result.

A successful build does NOT mean a successful design.

Vivi MUST inspect and refine significant frontend work before declaring it complete.

## 01 — Required Workflow

BUILD → RUN → RENDER → INSPECT → IDENTIFY PROBLEMS → FIX → RENDER AGAIN → FINAL REVIEW

Never stop at:

"The code compiles."

The target is:

"The interface looks finished."

## 02 — Desktop QA

Check at:

- 1440px
- 1280px
- 1024px

Verify:

- hierarchy
- typography
- spacing
- alignment
- imagery
- navigation
- CTAs
- section rhythm
- cards
- forms
- interaction
- animation
- overflow

## 03 — Tablet QA

Check around:

- 768px
- 834px
- 1024px where relevant

Verify:

- navigation
- layout transitions
- grid behavior
- typography
- cards
- spacing
- images
- interaction

## 04 — Mobile QA

Check:

- 390px
- 375px

Verify:

- no horizontal overflow
- no clipped text
- no oversized headings
- no broken cards
- no inaccessible buttons
- no broken navigation
- no overlapping content
- no animation overflow
- no unexpected layout shifts

## 05 — Typography QA

Check:

- font size
- line-height
- letter spacing
- line length
- wrapping
- hierarchy
- contrast

Headlines must not wrap awkwardly.

Body text must remain readable.

## 06 — Spacing QA

Check:

- section spacing
- component padding
- margins
- grid gaps
- vertical rhythm
- alignment

Identify:

- crowded areas
- excessive empty areas
- inconsistent spacing

## 07 — Color QA

Check:

- contrast
- consistency
- brand usage
- CTA visibility
- background transitions
- readability

## 08 — Image QA

Check:

- aspect ratio
- cropping
- resolution
- loading
- object positioning
- responsive behavior

Never allow distorted imagery.

## 09 — Motion QA

If `vivi-motion-design` was used, verify:

- animations trigger correctly
- animations reverse correctly
- scroll interactions behave correctly
- no flicker
- no jumps
- no layout shifts
- no animation overflow
- mobile adaptation
- reduced-motion behavior

If an animation feels unnecessary:

REMOVE IT.

## 10 — Interaction QA

Test:

- buttons
- links
- navigation
- dropdowns
- menus
- forms
- cards
- hover states
- focus states
- touch interactions

## 11 — Accessibility QA

Check:

- keyboard navigation
- focus visibility
- semantic HTML
- alt text
- contrast
- button labels
- form labels
- reduced motion

## 12 — Responsive QA

The layout must not merely shrink.

It must intentionally adapt.

Check:

- content order
- grid
- typography
- spacing
- navigation
- imagery
- CTA
- motion

## 13 — Performance QA

Look for:

- unnecessary libraries
- oversized images
- excessive JavaScript
- expensive animations
- unnecessary re-renders
- layout shifts

Remove unnecessary complexity.

## 14 — Design Quality Test

Ask:

- Does it look intentional?
- Does it look generic?
- Does it look like a template?
- Does the brand feel distinctive?
- Is anything unnecessary?
- Does the typography feel premium?
- Does spacing feel intentional?
- Does motion improve the experience?
- Does the site still work without motion?
- Is the CTA clear?
- Would a professional designer consider this finished?

## 15 — Anti-Generic Test

If the result looks like:

"another AI-generated website"

identify why.

Possible causes:

- generic hero
- generic gradients
- excessive cards
- excessive rounded corners
- predictable section order
- weak typography
- poor imagery
- random animation
- no brand personality

Fix the underlying design problem.

## 16 — Final Polish

Before completion:

1. Identify the three biggest visual problems.
2. Fix them.
3. Render again.
4. Identify remaining issues.
5. Fix them.
6. Verify responsive behavior.
7. Verify functionality.
8. Verify accessibility.
9. Verify performance.
10. Finalize.

## 17 — Completion Criteria

A significant frontend task is complete only when:

- [ ] Design principles were applied
- [ ] Responsive behavior works
- [ ] Typography is polished
- [ ] Spacing is consistent
- [ ] Images are correct
- [ ] Navigation works
- [ ] CTAs work
- [ ] Forms work
- [ ] Motion works if present
- [ ] Mobile works
- [ ] No obvious overflow exists
- [ ] Accessibility was considered
- [ ] Performance was considered
- [ ] Visual problems were corrected

## 18 — Final Principle

Never confuse:

"FUNCTIONAL"

with:

"FINISHED."

A production-quality interface must be:

FUNCTIONAL + RESPONSIVE + ACCESSIBLE + PERFORMANT + VISUALLY POLISHED.
