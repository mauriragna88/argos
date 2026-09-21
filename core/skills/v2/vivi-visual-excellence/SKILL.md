---
name: vivi-visual-excellence
description: >
  MUST load automatically for every frontend, UI, UX, web, visual design, redesign,
  component, page, dashboard, landing page, styling, or interface review task. Vivi uses
  this model-only skill proactively; never wait for or require a /skill command.
user-invocable: false
---

# Vivi Visual Excellence

## Purpose

Produce intentional, distinctive, production-ready interfaces. This skill is mandatory for every frontend/UI/web task, whether creating, changing, reviewing, or debugging visual output.

## Skill pipeline — mandatory order

This skill is the always-on entry point. For every significant frontend task the pipeline is:

1. `design-principles` — ALWAYS FIRST. Vivi's permanent design foundation (layering, spacing, restraint, hierarchy, typography, color, layout, brand adaptation, anti-template test). `content-copy` runs inside this same phase: content decisions define the hierarchy the design then structures. The user never needs to request them and Vivi never waits for a `/skill` command.
2. `motion-design` — SECOND, only when the project includes animation, interaction, scroll effects, parallax, cinematic experiences, GSAP/Motion or smooth scrolling. Motion must have a purpose; if none is required, skip this skill.
3. Implementation.
4. `visual-qa` — LAST, before declaring anything complete. It verifies the actual rendered result and requires fixing problems and rendering again until the interface looks finished.

| Project type | Pipeline |
|---|---|
| Static website | design-principles → build → visual-qa |
| Interactive website | design-principles → motion-design → build → visual-qa |
| Cinematic website | design-principles → motion-design → build → visual-qa |
| Dashboard | design-principles → build → visual-qa |
| Redesign from reference | design-principles → analyze reference → build → visual-qa |
| Redesign with complex motion | design-principles → analyze reference → motion-design → build → visual-qa |

The three skills complement each other; they are not competing instructions. Apply them together with this standard, `impeccable` and `taste-skill`.

## Reference standard — learn, never copy

Use these sources only to calibrate quality and broaden visual vocabulary:

- **Impeccable** for composition, hierarchy, typography, color, polish, and systematic critique.
- **Taste / taste-skill** for anti-slop judgment, purposeful decisions, and direct product copy.
- **Dribbble** and **Collect UI** for visual exploration and pattern breadth.
- **Mobbin** for proven product flows, states, and interaction conventions.
- **Awwwards** for art direction, storytelling, and expressive interaction.
- **Figma** for design-system rigor, tokens, components, constraints, and handoff quality.
- **Higgsfield** for cinematic composition and motion inspiration when the product context warrants it.

Never trace, clone, reproduce, or imitate a specific screen, brand, asset, layout, animation, or signature style. Extract principles, combine multiple signals, and produce an original result appropriate to the product, audience, content, and existing design system.

## Mandatory workflow — audit first

1. Load and apply the pipeline (`design-principles` + `content-copy` always; `motion-design` when it applies) plus `impeccable` and `taste-skill` automatically through the model-facing skill loader. They are always active with this skill; do not wait for or ask the user to type `/skill`.
2. **Audit before editing:** inspect the rendered experience and repository context: user goal, information architecture, real content, existing components, tokens, typography, responsive behavior, accessibility, motion, performance, and technical constraints. Preserve what already works.
3. Set the three project dials explicitly before choosing an art direction:
   - **Variance:** low for established product systems, medium for most product work, high only for justified expressive or campaign experiences.
   - **Motion:** none/subtle/expressive according to task criticality, user expectations, device cost, and `prefers-reduced-motion`.
   - **Density:** compact/balanced/airy according to content volume and task frequency, never as a cosmetic default.
4. State one coherent visual concept and the design decisions that support it. Prefer one strong idea over a collage of trends.
5. Implement the complete experience, including loading, empty, error, success, disabled, hover, focus, and reduced-motion states where applicable.
6. Review at mobile, tablet, laptop, and wide layouts; verify keyboard use, contrast, zoom, motion preferences, and performance.
7. Remove decorative or interaction slop, then run the preflight before delivery.

## Anti-slop rules

- No generic AI dashboard formula, gratuitous purple/blue gradients, indiscriminate glassmorphism, excessive pills, giant blurred shadows, emoji-as-icons, fake metrics, or filler copy.
- Do not default to centered hero + three equal cards. Let information architecture and real content determine composition and density.
- Use a deliberate type scale, restrained palette, consistent geometry, clear hierarchy, and product-specific microcopy.
- Decoration must reinforce meaning, brand, or spatial hierarchy. If it only fills space, remove it.
- Reuse the repository's design system. Introduce new tokens or patterns only when the current system cannot express a justified need.

## Motion

- Motion communicates continuity, causality, hierarchy, or feedback; it is never ornamental delay.
- Prefer transform and opacity animations, avoid layout thrashing, and keep interaction feedback immediate.
- Use a small, consistent duration/easing vocabulary and avoid animating every element.
- Honor `prefers-reduced-motion`; essential state changes must remain understandable without animation.
- Cinematic or scroll-driven effects require a clear product rationale and must not obstruct reading, navigation, or input.
- The full motion system — vocabulary, hierarchy, density, mobile adaptation, reduced motion — lives in the `motion-design` skill. Load it whenever the task includes motion.

## Responsive quality

- Design mobile-first, then adapt structure rather than merely shrinking it.
- Support narrow screens, long localized text, zoom to 200%, touch targets, safe areas, and content reflow without horizontal scrolling.
- Use intrinsic layout, flexible grids, container queries or breakpoints chosen by content, and sensible readable line lengths.
- Preserve task priority across sizes; do not hide essential actions or information to make a layout fit.

## Accessibility — WCAG 2.2 AA minimum

- Use semantic HTML, correct landmarks, labels, names, roles, and states before adding ARIA.
- Ensure full keyboard operation, visible focus, logical focus order, and safe focus management.
- Meet contrast requirements; never rely on color, animation, hover, or sound alone.
- Provide accessible validation, errors, status announcements, alternatives for non-text content, and adequate target sizes.
- Test reduced motion, high zoom, screen-reader naming, and forced/high-contrast behavior when relevant.

## Performance budget

- Protect Core Web Vitals: avoid unnecessary client JavaScript, hydration, third-party scripts, and render-blocking assets.
- Reserve media dimensions to prevent layout shift; optimize responsive images, fonts, SVGs, and video.
- Lazy-load below-the-fold media and expensive UI, but never delay primary content or interaction readiness.
- Animate compositor-friendly properties and profile expensive effects, filters, canvas, and scroll handlers.
- Prefer progressive enhancement and measure regressions instead of assuming visual polish is free.

## Preflight

Before delivery, confirm all of the following:

- The audit informed the result and the chosen variance, motion, and density dials are coherent.
- Mobile is complete first; tablet, desktop, wide, long-content, and 200% zoom layouts reflow correctly.
- Semantics, keyboard flow, visible focus, labels, contrast, target sizes, and state announcements meet WCAG 2.2 AA.
- `prefers-reduced-motion` works and no animation is required to understand or operate the interface.
- Loading, empty, error, success, disabled, hover, and focus states are present where applicable.
- Images, fonts, JavaScript, hydration, layout shift, and animated effects stay within the project's performance budget.
- The final anti-slop pass removes generic patterns, filler copy, unjustified decoration, and copied reference details.
- The `visual-qa` skill pass was executed (desktop, tablet and mobile renders; typography, spacing, color, images, motion, interaction, accessibility, performance) and its findings were fixed, not just noted.

## Definition of done

The result is original, context-specific, responsive, WCAG 2.2 AA-ready, motion-safe, performant, complete across states, and free of obvious AI-design slop. Any reference influence is expressed as a principle, never as copied output.
