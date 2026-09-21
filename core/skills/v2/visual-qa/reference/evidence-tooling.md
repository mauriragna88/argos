# Evidence Tooling — how to actually verify

`SKILL.md` §18 requires evidence for every completion criterion. This file defines **how** to obtain it, so "verified" means measured rather than asserted.

Reading source code does not produce evidence. Only the rendered page does.

## 1. Detect what the project already has

Before writing anything, check the repository. Most projects already have the tooling; using it is cheaper and more credible than inventing a new harness.

```bash
# Playwright / axe already configured?
cat package.json | grep -E 'playwright|axe|vitest|lighthouse'
ls tests/e2e/ 2>/dev/null
```

If a test runner exists, add checks there rather than creating a parallel script. If none exists, a one-off Playwright script is still better than an unverified claim — but say in the report that it was ad hoc.

## 2. Rendering at every breakpoint

Required widths: **375 · 390 · 768 · 1024 · 1280 · 1440** (`SKILL.md` §02–§04).

Verify horizontal overflow by measurement, not by looking:

```js
await page.evaluate(
  () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
)
// must be <= 0
```

Poll rather than sampling once — a stylesheet or transition mid-flight is not a width defect:

```js
await expect
  .poll(() => page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth), { timeout: 5000 })
  .toBeLessThanOrEqual(0)
```

**Useful detail:** overflow often appears only at widths nobody names — 320, 414, 834, 1180. Test between the breakpoints, not just at them.

## 3. Accessibility — machine-checkable subset

Run axe-core against the real routes. Tags must include WCAG 2.2 AA:

```js
import AxeBuilder from '@axe-core/playwright'

const results = await new AxeBuilder({ page })
  .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
  .analyze()

const blocking = results.violations.filter(
  v => v.impact === 'critical' || v.impact === 'serious',
)
```

Report each violation with rule id, node count, and selector so it can be reproduced:

```js
blocking.map(v => `${v.id} (${v.nodes.length}): ${v.nodes.map(n => n.target.join(' ')).join(' | ')}`)
```

**Run automated checks with motion disabled** (`test.use({ reducedMotion: 'reduce' })`). A colour sampled mid-tween is not a state that must pass contrast; disabling motion makes the result deterministic. Verify the animated state separately by capture.

**What axe cannot check** — these still need manual verification:

- Whether focus order matches visual order
- Whether an accessible name is *meaningful* ("Button 7" passes)
- Whether the reading order makes sense with CSS reordering
- Keyboard traps in custom widgets
- Whether error messages are actually announced

Never report "accessibility: passed" from axe alone. State which parts were machine-checked and which were manual.

## 4. Keyboard verification

Walk the page with `Tab` and assert focus is visible at every stop:

```js
for (let step = 0; step < 12; step += 1) {
  await page.keyboard.press('Tab')
  const info = await page.evaluate(() => {
    const active = document.activeElement
    if (!(active instanceof HTMLElement)) return null
    const style = getComputedStyle(active)
    const rect = active.getBoundingClientRect()
    return {
      outline: style.outlineStyle,
      width: Math.round(rect.width),
      label: active.getAttribute('aria-label') ?? (active.textContent ?? '').trim().slice(0, 30),
    }
  })
  if (info && info.width > 0) {
    expect(info.outline, `no focus ring on "${info.label}"`).not.toBe('none')
  }
}
```

Also verify: every interactive element reachable, no trap, dialogs return focus on close.

## 5. Touch targets

Minimum **44×44 CSS px** (WCAG 2.2 AA). Measure, and allow a sub-pixel tolerance rather than exact equality:

```js
const sizes = await page.locator('a.btn, button, [role="button"]').evaluateAll(els =>
  els.map(el => {
    const r = el.getBoundingClientRect()
    return { height: Math.round(r.height * 10) / 10, text: (el.textContent ?? '').trim().slice(0, 40) }
  }).filter(s => s.height > 0),
)
for (const s of sizes) expect(s.height, `control too short: "${s.text}"`).toBeGreaterThanOrEqual(43.5)
```

## 6. Zoom to 200%

A mobile-width render at 200% font size is the practical equivalent:

```js
await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
```

Then assert the primary heading is still visible and no overflow was introduced.

## 7. Contrast

axe covers text contrast against its background. It does **not** cover:

- Text over images or gradients (verify by sampling the worst pixel region)
- Disabled and placeholder states (often exempt from AA by rule, but still need to be legible)
- Focus indicator contrast — WCAG 2.2 requires 3:1 for the focus ring against adjacent colours

## 8. Performance evidence

Numeric, not impressionistic:

- **LCP** — target under 2.5s on a throttled mid-tier connection, not on localhost
- **CLS** — under 0.1; any media without reserved dimensions is a defect
- **JS shipped** — compare against the framework baseline; unexplained tens of KB are a defect
- Layout shift during font swap: check for `font-display` strategy and a matched fallback

Tools: Lighthouse for the headline numbers, the Performance panel for attributing a regression to a specific element.

## 9. Recording evidence in the report

For every criterion in `SKILL.md` §18, cite one of:

| Evidence type | Example |
|---|---|
| Measured value | `scrollWidth - clientWidth = 0` at 375/768/1440 |
| Test output | `npx playwright test tests/e2e/accessibility.spec.ts` → 12 passed |
| Captured image | screenshot at 390px showing the empty state |
| Explicit gap | "Not verified: screen-reader announcement of form errors" |

**"Not verified" is an acceptable answer. "Verified" without evidence is not.**
