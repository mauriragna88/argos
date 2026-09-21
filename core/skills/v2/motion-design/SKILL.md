---
name: motion-design
description: >
  CONDITIONAL — load only when the project actually includes animation, scroll
  interaction, parallax, interactive storytelling, cursor interaction, complex hover
  states, page transitions, animated typography, stacking cards, scroll-driven
  transformation, cinematic experiences, GSAP, Motion / Framer Motion, smooth
  scrolling, or complex visual effects. Vivi's interaction and motion system:
  motion philosophy, timing scale, vocabulary, parallax, scroll-driven work,
  stagger, micro-interactions, motion density, mobile motion, reduced motion, and
  performance. This skill MUST NOT be used as an excuse to add unnecessary animation.
user-invocable: false
---

# Motion Design — Vivi Interaction & Motion System

**Version 1.1**

## Purpose

This skill defines how Vivi designs, plans, and implements animation and interaction.

It is **CONDITIONAL**. Use this skill when the project includes:

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

This skill **MUST NOT** be used as an excuse to add unnecessary animation.

## Composition with the rest of the stack

- `design-principles` — foundation layer: layering, spacing, restraint, hierarchy, scales, tokens.
- `impeccable` — execution layer: composition, typography, color, polish, critique.
- `taste-skill` — judgment layer: anti-slop, purposeful decisions, direct copy.
- `vivi-visual-excellence` — direction layer: art direction, dials, preflight, delivery.
- `visual-qa` — verification layer: judges the rendered motion before delivery.
- `motion-design` (this skill) — the conditional motion layer.

`design-principles` §01 establishes **restraint** as a fundamental principle. Motion is where restraint is most often abandoned, so this skill enforces it hardest.

If a motion idea contradicts the brief, the real content, or usability, the brief and the product win.

### Relationship to the motion dial

`vivi-visual-excellence` sets a **Motion** dial before any art direction: `none`, `subtle`, or `expressive`. That dial governs this skill:

| Dial | Major concepts allowed | Guidance |
|---|---|---|
| `none` | 0 | Do not load this skill. Ship still. |
| `subtle` | 1 | One major concept at most; everything else is micro-interaction. |
| `expressive` | 2–3 | Full choreography permitted, still bounded by §12. |

The dial is set once, per project, and this skill never overrides it. Motion budget is a ceiling, not a target.

---

## 01 — Motion philosophy

Motion exists to support:

- hierarchy
- storytelling
- navigation
- interaction
- depth
- feedback

Motion is **NOT** decoration by default.

**The non-negotiable test:** the content must remain fully understandable with all motion removed. If a section only makes sense while it is animating, the motion is carrying information it should not be carrying. Fix the content structure, then keep or drop the animation.

---

## 02 — The motion question

Before implementing any significant animation, ask:

1. What does this communicate?
2. Why is it moving?
3. Does it improve hierarchy?
4. Does it guide attention?
5. Does it improve storytelling?
6. Does it clarify interaction?

If none apply:

**DO NOT ADD THE ANIMATION.**

---

## 03 — Timing scale

Motion that is correct in concept still feels amateur when every element uses a different duration. One timing vocabulary, held across the project:

| Layer | Duration | Easing |
|---|---|---|
| Micro-feedback (hover, focus, press) | 100–150ms | `ease-out` |
| State change (open, close, swap) | 200–300ms | `ease-in-out` |
| Section entrance (reveal, stagger step) | 400–600ms | `ease-out` |
| Scroll-driven, parallax, pinned | tied to scroll progress | linear or mapped |

Rules:

- Shorter for smaller elements, longer for larger travel. A button never takes 400ms.
- Exit is faster than entry — leaving should feel immediate.
- Stagger step: 60–120ms between siblings; beyond ~5 steps the last item feels broken.
- One easing family per project. Do not mix spring physics with cubic-bezier in the same interaction.
- Trust CSS for the first two rows; reach for a library only when the motion genuinely needs orchestration, scroll mapping, or stateful sequencing.

```css
:root {
  --dur-micro: 120ms;
  --dur-state: 250ms;
  --dur-enter: 500ms;
  --ease-out: cubic-bezier(0.22, 1, 0.36, 1);
  --ease-in-out: cubic-bezier(0.65, 0, 0.35, 1);
  --stagger-step: 80ms;
}
```

Durations live as tokens alongside the spacing and type scales in `design-principles` §03. Motion is part of the design system, not a decoration added on top of it.

---

## 04 — Motion vocabulary

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

A vocabulary is a set of options, not a checklist. See §12.

---

## 05 — Layered parallax

Use multiple visual layers moving at different speeds:

```
background  = 0.5
midground   = 0.8
foreground  = 1.0
```

These values are a starting point, not a formula. Calibrate to the design: the further a plane sits from the viewer, the slower it travels. If the layers do not read as distinct depths, the effect is decoration — remove it.

Use only when depth contributes to the story. Do not apply parallax to every section.

---

## 06 — Scroll-triggered text reveal

Possible methods:

- line reveal
- word reveal
- character reveal
- clip-path
- fade + translate
- stagger

Important content must remain accessible. Animation should not make reading difficult. Text must be present in the DOM and readable by assistive technology before, during, and after the reveal.

---

## 07 — Scroll-driven transformation

Tie animation progress to scroll progress.

Possible properties: rotation, scale, position, opacity, clipping, perspective.

Example:

```
0%   → 0°
25%  → 90°
50%  → 180°
75%  → 270°
100% → 360°
```

The animation should reverse naturally when scrolling backward. If it snaps or only plays forward, the mapping is wrong.

---

## 08 — Stacking cards

Use stacking cards for:

- services
- products
- steps
- case studies
- features
- storytelling

The content must remain understandable **without** the animation. See §01.

---

## 09 — Cursor tracking

Possible interactions:

- magnetic buttons
- subtle tilt
- image movement
- cursor follower
- spotlight
- displacement

Use restraint. Do not make the entire page follow the cursor. Cursor effects must never be required to reach or operate an element, and they must not exist on touch devices.

---

## 10 — Staggered reveals

Use stagger to establish hierarchy:

```
Heading
  ↓
Description
  ↓
CTA
  ↓
Image
```

Avoid excessive delay. The page must remain responsive. See the stagger step in §03.

---

## 11 — Micro-interactions

Use motion to communicate interaction:

| Element | Motion |
|---|---|
| Button | hover → subtle movement |
| Link | hover → underline transition |
| Card | hover → subtle elevation |
| Icon | hover → controlled movement |

Motion must feel responsive, not theatrical. Feedback belongs in the 100–150ms band.

---

## 12 — Motion budget

A premium website generally needs only **1–3 major motion concepts**, allocated by importance:

**Major motion** — hero, main product, important storytelling section.

**Medium motion** — cards, images, secondary sections.

**Minor motion** — buttons, links, icons.

Example allocation:

```
Hero:       layered parallax
Services:   stacking cards
Typography: scroll reveal
Everything else: subtle transitions
```

Not everything should move simultaneously, and not every available technique should be used. This section is the ceiling; the motion dial sets how much of it you may spend.

---

## 13 — Mobile motion

Mobile is not desktop motion scaled down. Adapt motion for touch devices.

Possible strategy:

```
Desktop: parallax + cursor interaction
Mobile:  reduced parallax
```

or:

```
Desktop: complex scroll animation
Mobile:  simple reveal
```

If motion creates problems:

**REMOVE IT.**

---

## 14 — Reduced motion

Respect `prefers-reduced-motion`.

When enabled:

- remove parallax
- reduce transforms
- reduce transitions
- disable unnecessary animation
- preserve information
- preserve hierarchy

Reduced motion is not "smaller motion." The interface must remain complete, ordered, and navigable with every transform removed.

---

## 15 — Performance

Motion must not create:

- jank
- layout shifts
- excessive CPU usage
- excessive JavaScript
- slow loading

Prefer CSS for simple animation. Use Motion or GSAP for complex animation when justified. Avoid unnecessary animation libraries.

Animate compositor-friendly properties (`transform`, `opacity`) and treat anything that triggers layout or paint as a bug until proven necessary.

---

## 16 — Smooth scrolling

Smooth scrolling may be used for cinematic experiences. Do not introduce it automatically.

It must:

- remain performant
- respect accessibility
- work on touch devices
- not break browser behavior

Smooth scrolling that hijacks native scroll, breaks anchor links, or traps keyboard users is a regression, not a feature.

---

## 17 — Page transitions

Navigation between pages is motion, and it is the one place where bad motion costs the user real time.

**Default to none.** Most multi-page sites are better with an instant navigation than with a 600ms transition on every click. Add a transition only when it communicates something: spatial continuity, hierarchy between list and detail, or a brand moment on a deliberate entry point.

If you do add one:

- **Use the platform first.** The View Transitions API (`document.startViewTransition`, or the framework's wrapper) gives cross-document transitions natively, respects the browser's own timing model, and degrades to an instant navigation where unsupported. Reach for a JS transition library only when the platform cannot express the idea.
- **Never block navigation on the animation.** The new content must be usable immediately; the transition plays around it, not in front of it.
- **Respect scroll restoration.** Returning to a list must land where the user left it. A transition that resets scroll position destroys more usability than it adds polish.
- **Keep it inside the timing scale** (§03). A page transition is a state change: 200–300ms, not a section entrance.
- **Honor `prefers-reduced-motion`** by removing the transition entirely, not by shortening it.
- **Do not animate the whole viewport on every route.** Reserve that for deliberate entry points; routine navigation — back, pagination, filter changes — should feel instant.
- **Astro, Next, SvelteKit, Nuxt:** prefer the router's own transition hooks over a manual overlay. A manual overlay fights the router, breaks the back button, and leaks state.

The test: navigate ten times in a row. If the tenth feels slower than the first, the transition is a tax, not a feature.

---

## 18 — Motion references

Use as inspiration for motion vocabulary:

- Awwwards
- Godly.design
- 21st.dev
- motion-focused websites

Study timing, sequencing, interaction, transitions, and storytelling.

Never clone exact implementations. See `design-principles` §04–05.

---

## 19 — Motion composition

Animation should have:

- beginning
- purpose
- progression
- conclusion

Avoid random perpetual movement. Animation should feel choreographed.

---

## 20 — Motion without distraction

Avoid:

- bouncing everything
- infinite floating elements
- constant rotation
- excessive scaling
- excessive cursor effects
- animations on every card
- animations on every section

Motion should make the interface feel **alive**, not **busy**.

---

## 21 — Final motion principle

The question is **NOT**:

> "Can we animate this?"

The question is:

> "**Should this move?**"

If movement improves the experience:

**IMPLEMENT IT.**

If not:

**LEAVE IT STILL.**
