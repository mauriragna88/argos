---
name: visual-qa
description: >
  MUST load before declaring any significant frontend work complete. Vivi's frontend
  visual verification system: render the real result, inspect desktop/tablet/mobile,
  run typography, spacing, color, image, motion, interaction, accessibility, responsive
  and performance QA, then apply the design-quality, anti-generic, and final-polish
  passes. A successful build is NOT a successful design. Vivi uses this proactively and
  never waits for a /skill command.
user-invocable: false
---

# Visual QA — Vivi Frontend Visual Verification System

**Version 1.0**

## Purpose

This skill verifies the **actual rendered result**.

A successful build does **NOT** mean a successful design.

Vivi MUST inspect and refine significant frontend work before declaring it complete.

## Composition with the rest of the stack

- `design-principles` — foundation layer: the principles the design must satisfy.
- `impeccable` — execution layer: composition, typography, color, polish, critique.
- `taste-skill` — judgment layer: anti-slop, purposeful decisions, direct copy.
- `vivi-visual-excellence` — direction layer: art direction, dials, preflight, delivery.
- `motion-design` — conditional motion layer; load it when the work involves motion.
- `visual-qa` (this skill) — **verification layer.** It is the last gate before delivery.

This skill is **mandatory** for every significant frontend task. It is invoked at the verification phase, not the design phase: it judges what was actually rendered, never what was intended.

If a check here contradicts an earlier decision, the rendered result wins. Fix the result.

---

## 01 — Required workflow

```
BUILD
  ↓
RUN
  ↓
RENDER
  ↓
INSPECT
  ↓
IDENTIFY PROBLEMS
  ↓
FIX
  ↓
RENDER AGAIN
  ↓
FINAL REVIEW
```

Never stop at:

> "The code compiles."

The target is:

> "**The interface looks finished.**"

**Verify the rendered output, not the source code.** Reading JSX tells you what should happen; only the rendered page tells you what does. Inspect the real result at every breakpoint before claiming completion.

**How to obtain evidence:** see `reference/evidence-tooling.md`. It defines the measurement and test procedure for every criterion in §18 — overflow, axe-core, keyboard walk, touch targets, zoom, contrast, and performance numbers. Read it before starting QA; do not improvise a method or assert a result you did not measure.

---

## 02 — Desktop QA

Check at:

- 1440px
- 1280px
- 1024px

Verify: hierarchy, typography, spacing, alignment, imagery, navigation, CTAs, section rhythm, cards, forms, interaction, animation, overflow.

---

## 03 — Tablet QA

Check around:

- 768px
- 834px
- 1024px where relevant

Verify: navigation, layout transitions, grid behavior, typography, cards, spacing, images, interaction.

The tablet range is where layouts most often break silently, because it is rarely tested. Check the in-between widths, not just the named breakpoints.

---

## 04 — Mobile QA

Check at:

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

---

## 05 — Typography QA

Check: font size, line-height, letter spacing, line length, wrapping, hierarchy, contrast.

Headlines must not wrap awkwardly. Body text must remain readable.

---

## 06 — Spacing QA

Check: section spacing, component padding, margins, grid gaps, vertical rhythm, alignment.

Identify: crowded areas, excessive empty areas, inconsistent spacing.

---

## 07 — Color QA

Check: contrast, consistency, brand usage, CTA visibility, background transitions, readability.

---

## 08 — Image QA

Check: aspect ratio, cropping, resolution, loading, object positioning, responsive behavior.

Never allow distorted imagery.

---

## 09 — Motion QA

If `motion-design` was used, verify:

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

**REMOVE IT.**

---

## 10 — Interaction QA

Test: buttons, links, navigation, dropdowns, menus, forms, cards, hover states, focus states, touch interactions.

---

## 11 — Accessibility QA

Check: keyboard navigation, focus visibility, semantic HTML, alt text, contrast, button labels, form labels, reduced motion.

**Machine-checkable subset:** run axe-core against the real routes with WCAG 2.2 AA tags, and report each violation with rule id, node count, and selector. Automated checks must run with motion disabled so contrast is sampled on a settled state.

**What axe cannot verify** — focus order matching visual order, whether an accessible name is *meaningful*, reading order under CSS reordering, keyboard traps in custom widgets, and whether errors are actually announced. These require a manual pass.

Never report "accessibility: passed" from axe alone. State which parts were machine-checked and which were manual. Tooling details and runnable snippets: `reference/evidence-tooling.md` §3–§7.

---

## 12 — Responsive QA

The layout must not merely shrink. It must **intentionally adapt**.

Check: content order, grid, typography, spacing, navigation, imagery, CTA, motion.

---

## 13 — Performance QA

"Looks fast" is not a measurement. Use a numeric budget, and report the measured value:

| Metric | Budget | Notes |
|---|---|---|
| **LCP** | < 2.5s | On a throttled mid-tier connection, not localhost |
| **CLS** | < 0.1 | Any media without reserved dimensions is a defect, not a risk |
| **INP** | < 200ms | Interaction latency; heavy scroll handlers are the usual cause |
| **JS shipped** | Justified against the framework baseline | Unexplained tens of KB are a defect |
| **Hero/above-fold image** | Sized to its rendered box | A 3000px asset in a 600px slot is a defect |

Also look for: unnecessary libraries, oversized images, expensive animations, unnecessary re-renders, layout shifts during font swap.

Remove unnecessary complexity. Where a number cannot be measured, say so explicitly rather than asserting speed. Measurement recipes: `reference/evidence-tooling.md` §8.

---

## 14 — Design quality test

Ask:

- Does it look intentional?
- Does it look generic?
- Does it look like a template?
- Does the brand feel distinctive?
- Is anything unnecessary?
- Does the typography feel premium?
- Does spacing feel intentional?
- Does motion improve the experience?
- Does the site still work **without** motion?
- Is the CTA clear?
- Would a professional designer consider this finished?

**Copy-specific checks** (governed by `content-copy`, judged in the rendered page):

- Does the first screen say what this is and who it is for, specifically?
- Would every headline survive the substitution test — could a competitor paste their name in and stay true? (If yes, it is filler.)
- Does every CTA name a concrete outcome, and does its label match its destination?
- Do empty, loading, error, success, and disabled states have real copy rather than component defaults?
- Is there any fabricated metric, testimonial, logo, or certification? Any single fabricated claim is **Blocking**.
- Is formality (*tú* / *usted*) consistent across the whole product?

---

## 15 — Anti-generic test

If the result looks like *"another AI-generated website"*, identify **why**.

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

Fix the **underlying design problem** — not its symptom. Removing one gradient does not fix a generic composition.

---

## 16 — Final polish

Before completion:

1. List every finding, ordered by severity (§17).
2. Fix all Blocking findings first.
3. Render again and re-inspect — a fix is unverified until it is seen rendered.
4. Fix Major findings, or record why they are accepted.
5. Record Minor findings.
6. Verify responsive behavior at every breakpoint.
7. Verify functionality (real interaction, not inspection).
8. Verify accessibility.
9. Verify performance.
10. Repeat until no Blocking finding remains. Then finalize.

There is no fixed number of problems to find. Inventing findings to satisfy a quota is as wrong as missing a real one.

---

## 17 — Severity

Not every finding weighs the same, and treating them alike produces two failures: real bugs get buried under cosmetic notes, and polish is skipped because "it is only minor".

| Level | Meaning | Examples | Effect on delivery |
|---|---|---|---|
| **Blocking** | Broken, unusable, or inaccessible | Horizontal overflow, unreachable control, missing form label, contrast below AA, form that does not submit, animation required to read content | **Blocks delivery.** Fix before anything else. |
| **Major** | Breaks hierarchy, rhythm, or comprehension | Inconsistent spacing rhythm, weak CTA hierarchy, awkward headline wrap, layout that merely shrinks instead of adapting, image distortion | Fix before delivery. |
| **Minor** | Polish | Slightly inconsistent radius, an icon 1px off, a borderline-but-passing contrast ratio | Fix if cheap; otherwise record it explicitly. |

Report findings ordered by severity, not by the order they were found. Never let a Minor finding delay a Blocking fix.

---

## 18 — Completion criteria

A significant frontend task is complete only when every item below is verified **and backed by evidence**.

**How to obtain that evidence — the actual commands, selectors, and assertions — is defined in `reference/evidence-tooling.md`.** Read it before claiming any criterion below. It covers breakpoint rendering, overflow measurement, axe-core tags for WCAG 2.2 AA, keyboard walking, touch targets, 200% zoom, contrast gaps, and performance numbers.

| # | Criterion | Evidence required |
|---|---|---|
| 1 | Design principles applied | Named brand-specific decisions (see `design-principles` §13), not "yes" |
| 2 | No horizontal overflow | Measured per breakpoint: `document.documentElement.scrollWidth <= window.innerWidth` |
| 3 | Responsive behavior works | Rendered at 375 / 390 / 768 / 1024 / 1280 / 1440 |
| 4 | Typography is polished | No functional text below 12px, no body text below 16px; headline wraps checked |
| 5 | Spacing is consistent | Values traced to the project scale; off-scale values listed and justified |
| 6 | Images are correct | Aspect ratios verified at each breakpoint; no distortion |
| 7 | Navigation works | Every entry reached and reversed |
| 8 | CTAs work | Primary action executed, not just inspected |
| 9 | Forms work | Submitted, validated, and error/success states seen |
| 10 | Motion works if present | Triggers, reverses, no flicker or shift, reduced-motion respected |
| 11 | Accessibility meets WCAG 2.2 AA | Keyboard-only pass completed; focus visible throughout |
| 12 | Performance is acceptable | No oversized images, no unnecessary libraries, no layout shift |
| 13 | Copy is specific, not filler | Substitution test passed: competitor names swapped in would make the copy false (see `content-copy` §12) |
| 14 | No fabricated proof | Every metric, testimonial, logo, and certification traced to a real source, or absent |
| 15 | States have real copy | Empty, loading, error, success, and disabled states read as written text, not component defaults |
| 16 | Visual problems corrected | Re-rendered after fixes, not only edited |

**A criterion checked from source code alone does not count.** Reading JSX tells you what should happen; only the rendered page tells you what does. If a criterion could not be verified, say so explicitly rather than marking it done — an unverified claim is worse than an admitted gap.

**No Blocking finding may remain open at delivery.** Major findings must be fixed or explicitly accepted; Minor findings must be recorded.

---

## 19 — Final principle

Never confuse:

**"FUNCTIONAL"**

with:

**"FINISHED."**

A production-quality interface must be:

**FUNCTIONAL + RESPONSIVE + ACCESSIBLE + PERFORMANT + VISUALLY POLISHED.**
