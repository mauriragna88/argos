---
name: vivi-motion-design
description: >
  Use ONLY when the project includes animation, scroll interaction, parallax, interactive
  storytelling, cursor interaction, complex hover states, page transitions, animated
  typography, stacking cards, scroll-driven transformations, cinematic experiences, GSAP,
  Motion/Framer Motion, smooth scrolling or complex visual effects. Defines how Vivi plans
  and implements motion: philosophy, vocabulary, hierarchy, density, mobile, reduced motion
  and performance. Never an excuse to add unnecessary animation. Model-only: never wait for
  or require a /skill command.
agent: vivi
source: ARGOS propio (Vivi motion system v1.0)
user-invocable: false
---

# Motion Design — Vivi's Interaction & Motion System

Part of Vivi's design pipeline: `vivi-design-principles` (always first) → `vivi-motion-design` (when applicable) → `vivi-visual-qa` (last). Vivi loads these automatically.

## Purpose

This skill defines how Vivi designs, plans and implements animation and interaction.

It is CONDITIONAL.

Use this skill when the project includes:

- animation
- scroll interaction
- parallax
- interactive storytelling
- cursor interaction
- complex hover states
- page transitions
- animated typography
- stacking cards
- scroll-driven transformations
- cinematic experiences
- GSAP
- Motion / Framer Motion
- smooth scrolling
- complex visual effects

This skill MUST NOT be used as an excuse to add unnecessary animation.

## 01 — Motion Philosophy

Motion exists to support:

- hierarchy
- storytelling
- navigation
- interaction
- depth
- feedback

Motion is NOT decoration by default.

## 02 — The Motion Question

Before implementing any significant animation ask:

1. What does this communicate?
2. Why is it moving?
3. Does it improve hierarchy?
4. Does it guide attention?
5. Does it improve storytelling?
6. Does it clarify interaction?

If none apply:

DO NOT ADD THE ANIMATION.

## 03 — Motion Vocabulary

Vivi may use:

- layered parallax
- scroll-triggered text reveal
- scroll-driven transformation
- stacking cards
- staggered reveal
- cursor tracking
- magnetic buttons
- image reveal
- mask reveal
- section transitions
- horizontal scroll
- pinned sections
- hover transformation
- navbar transitions
- product rotation
- scale transformation
- opacity transitions
- clip-path animation

## 04 — Layered Parallax

Use multiple visual layers moving at different speeds.

Example:

- background = 0.5
- midground = 0.8
- foreground = 1.0

Use only when depth contributes to the story.

Do not apply parallax to every section.

## 05 — Scroll-Triggered Text Reveal

Possible methods:

- line reveal
- word reveal
- character reveal
- clip-path
- fade + translate
- stagger

Important content must remain accessible.

Animation should not make reading difficult.

## 06 — Scroll-Driven Transformation

Tie animation progress to scroll progress.

Possible properties:

- rotation
- scale
- position
- opacity
- clipping
- perspective

Example:

- 0% → 0°
- 25% → 90°
- 50% → 180°
- 75% → 270°
- 100% → 360°

The animation should reverse naturally when scrolling backward.

## 07 — Stacking Cards

Use stacking cards for:

- services
- products
- steps
- case studies
- features
- storytelling

The content must remain understandable without the animation.

## 08 — Cursor Tracking

Possible interactions:

- magnetic buttons
- subtle tilt
- image movement
- cursor follower
- spotlight
- displacement

Use restraint.

Do not make the entire page follow the cursor.

## 09 — Staggered Reveals

Use stagger to establish hierarchy.

Example:

Heading → Description → CTA → Image

Avoid excessive delay.

The page must remain responsive.

## 10 — Micro-Interactions

Use motion to communicate interaction.

Examples:

- Button: hover → subtle movement
- Link: hover → underline transition
- Card: hover → subtle elevation
- Icon: hover → controlled movement

Motion must feel responsive, not theatrical.

## 11 — Motion Density

A premium website generally needs only:

1–3 major motion concepts.

Example:

- Hero: layered parallax
- Services: stacking cards
- Typography: scroll reveal
- Everything else: subtle transitions

Do not use every available technique.

## 12 — Motion Hierarchy

Major motion:

- Hero
- Main product
- Important storytelling section

Medium motion:

- Cards
- Images
- Secondary sections

Minor motion:

- Buttons
- Links
- Icons

Not everything should move simultaneously.

## 13 — Mobile Motion

Mobile is not desktop motion scaled down.

Adapt motion for touch devices.

Possible strategy:

Desktop: parallax + cursor interaction → Mobile: reduced parallax

or:

Desktop: complex scroll animation → Mobile: simple reveal

If motion creates problems:

REMOVE IT.

## 14 — Reduced Motion

Respect `prefers-reduced-motion`.

When enabled:

- remove parallax
- reduce transforms
- reduce transitions
- disable unnecessary animation
- preserve information
- preserve hierarchy

## 15 — Performance

Motion must not create:

- jank
- layout shifts
- excessive CPU usage
- excessive JavaScript
- slow loading

Prefer CSS for simple animation.

Use Motion or GSAP for complex animation when justified.

Avoid unnecessary animation libraries.

## 16 — Smooth Scrolling

Smooth scrolling may be used for cinematic experiences.

Do not introduce it automatically.

It must:

- remain performant
- respect accessibility
- work on touch devices
- not break browser behavior

## 17 — Motion References

Use:

- Awwwards
- Godly.design
- 21st.dev
- Motion-focused websites

as inspiration for motion vocabulary.

Study:

- timing
- sequencing
- interaction
- transitions
- storytelling

Never clone exact implementations.

## 18 — Motion Composition

Animation should have:

- beginning
- purpose
- progression
- conclusion

Avoid random perpetual movement.

Animation should feel choreographed.

## 19 — Motion Without Distraction

Avoid:

- bouncing everything
- infinite floating elements
- constant rotation
- excessive scaling
- excessive cursor effects
- animations on every card
- animations on every section

Motion should make the interface feel alive. Not busy.

## 20 — Final Motion Principle

The question is NOT:

"Can we animate this?"

The question is:

"Should this move?"

If movement improves the experience:

IMPLEMENT IT.

If not:

LEAVE IT STILL.
