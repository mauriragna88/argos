---
name: content-copy
description: >
  MUST load automatically for every significant frontend task, alongside
  design-principles. Vivi's content and copy layer: the inputs a brief must
  supply, message hierarchy, headlines, body structure, CTAs, microcopy,
  empty/loading/error/success states, voice and tone, proof and honesty rules,
  Spanish-language adaptation, and the falsifiable copy test. Design decides how
  a page looks; this skill decides whether it says anything. Vivi uses this
  proactively and never waits for a /skill command.
user-invocable: false
---

# Content & Copy — Vivi Message System

**Version 1.0**

## Purpose

A page can be beautifully proportioned, correctly spaced, and completely empty.

Generic copy is the strongest tell of an AI-generated interface — far stronger than a gradient, a card grid, or any visual pattern. Hierarchy and motion cannot rescue a page that says nothing specific.

This skill governs what the interface **says**, before and during implementation.

It is **always active**, on the same footing as `design-principles`.

## Composition with the rest of the stack

- `design-principles` — foundation layer: layering, spacing, restraint, hierarchy, scales, tokens.
- `content-copy` (this skill) — **message layer.** Runs inside the `design-principles` phase, not before it: content decisions define the hierarchy that the design then structures.
- `impeccable` — execution layer: composition, typography, color, polish, critique.
- `taste-skill` — judgment layer: anti-slop, purposeful decisions.
- `motion-design` — conditional motion layer.
- `visual-qa` — verification layer; its §14 and §15 check copy in the rendered result.
- `vivi-visual-excellence` — direction layer and router.

Execution order is defined in `vivi-visual-excellence`. If this skill contradicts the brief, the real content, or usability, those win.

**The rule that governs everything below:** every sentence must be replaceable only by a fact about *this* product. If a competitor could paste their own name into your copy and it would still be true, the copy is filler.

---

## 01 — Content before design

Write the content — or at least the message hierarchy — before composing the layout.

Designing around placeholder text produces layouts that break the moment real copy arrives. `Lorem ipsum` hides the only thing that matters: whether the message fits, and whether it is worth reading.

Order of operations:

1. Establish the inputs (§02).
2. Establish the message hierarchy (§03).
3. Write every heading that carries meaning.
4. Compose the layout around that real text.
5. Write body copy and microcopy in place, in the real interface (§05–§08).

A hero designed for "Lorem ipsum dolor sit amet" will not survive "Certificación sanitaria para distribuidoras de alimentos en el Bajío."

---

## 02 — Inputs you must obtain

You cannot write specific copy from a vague brief. Before writing, establish these five. If the user has not supplied one, **ask** — do not invent it.

| Input | Question | Why it changes the copy |
|---|---|---|
| **Audience** | Who is reading, and what do they already know? | Determines vocabulary, assumed context, and what needs explaining |
| **Objective** | What single action should they take? | Determines the CTA and the argument order |
| **Offer** | What exactly is being sold or offered? | Determines the noun. "Plataforma" is not an offer; "control de inventario para 3 sucursales" is |
| **Differentiator** | What is true here that is not true of the alternative? | Determines the headline |
| **Proof** | What evidence exists — real numbers, real names, real certifications? | Determines whether a claim may be made at all |

Rules:

- **Ask rather than invent.** A single question is cheaper than a page of plausible fiction. If you must proceed without an answer, mark the assumption explicitly and flag it for confirmation.
- **Never fabricate proof to fill a gap.** See §10.
- If the user cannot answer, that is information: the offer is not yet clear, and no layout will fix it.

---

## 03 — Message hierarchy

Every page answers four questions, in this order of priority:

**WHAT IS THIS? · WHO IS IT FOR? · WHY DOES IT MATTER? · WHAT DO I DO NEXT?**

The first screen must answer the first two. The body earns the third. The CTA delivers the fourth.

Rules:

- **One primary message per page.** If two messages compete for the hero, the page has no hero.
- **One primary action per screen.** Secondary actions are visually and rhetorically subordinate.
- Specificity beats intensity. "Reduces inventory shrinkage" outperforms "Transforma tu negocio" every time.
- Never lead with the mechanism when the benefit is available. Lead with the outcome; explain the mechanism once the reader cares.

---

## 04 — Headlines

The headline carries the most weight in the hierarchy. It must be specific, true, and readable at display size.

Prefer:

- A concrete noun and a concrete verb: *"Cobra a tiempo, siempre."*
- The outcome the reader wants, stated plainly.
- A number when the number is real: *"3 sucursales, un inventario."*
- A claim that only this product can make.

Avoid:

- **"Empieza tu viaje"** — a journey to where, for whom?
- **"Desbloquea tu potencial"** — whose potential, measured how?
- **"La solución integral para tu negocio"** — "integral" and "solución" mean nothing
- **"Sin complicaciones"** — a claim every competitor also makes
- **"Potencia tu flujo de trabajo con nuestra plataforma innovadora"** — four abstractions in one line
- Any headline that would still be true if the product did not exist

Test each headline:

1. Does it name something real?
2. Could a competitor use it verbatim? If yes, rewrite.
3. Does it survive being read aloud to a skeptical customer?

Subheadings add information; they do not restate the headline in smaller type. If the subheading repeats the headline, delete one of them.

---

## 05 — Body and structure

Body copy exists to move the reader from the headline's claim to the CTA's action.

Rules:

- **Structure for scanning.** Short paragraphs, descriptive subheadings, lists where the content is genuinely a list. Nobody reads a wall of prose in a marketing page.
- **One idea per paragraph.**
- **Front-load.** The first sentence of a section carries it; assume the rest may not be read.
- **Concrete over abstract.** Replace "optimizamos procesos" with what actually changes: "el cierre de mes pasa de 3 días a 4 horas."
- **No feature without consequence.** For every feature listed, state what it changes for the reader. A feature list with no consequences is a specification, not copy.
- **Cut filler transitions.** "En el mundo actual", "cabe destacar que", "es importante mencionar" — delete on sight.
- **Length follows content.** Do not pad to fill a layout, and do not truncate real information to fit one. Fix the layout.

---

## 06 — CTAs

A CTA is a promise about what happens next.

Rules:

- **Verb + specific outcome.** "Agenda una demostración" beats "Enviar". "Empieza tu prueba de 14 días" beats "Comenzar".
- **The label must match the destination.** If the button says "Ver precios" and lands on a contact form, it lied. `visual-qa` checks this.
- **Never "Descubre más", "Saber más", "Click aquí", or "Más información"** — they promise nothing and are indistinguishable from every other link.
- **First person is often stronger** where the platform allows it: "Quiero mi prueba" over "Solicitar prueba".
- **One primary CTA.** Multiple equally-weighted CTAs produce no action. Secondary actions are links or ghost buttons, clearly subordinate.
- **State the commitment where it matters.** If it costs money, requires a card, or takes 30 minutes, say so before the click — not after.

---

## 07 — Microcopy

Microcopy is where a product feels considered or careless. It is read at the moment of hesitation, so it carries disproportionate weight.

| Surface | Write | Not |
|---|---|---|
| Button | "Guardar cambios" | "Enviar" |
| Empty state | "Aún no tienes facturas. Crea la primera para empezar a cobrar." | "Nada por aquí todavía ✨" |
| Loading | "Cargando tus facturas…" (say *what*) | "Cargando..." |
| Error | "No pudimos guardar. Revisa tu conexión e inténtalo de nuevo." | "¡Ups! Algo salió mal 😅" |
| Validation | "El RFC debe tener 12 o 13 caracteres." | "Campo inválido" |
| Success | "Guardado" / "3 facturas enviadas" | "¡Operación exitosa!" |
| Destructive confirm | "Eliminar 14 registros. Esta acción no se puede deshacer." | "¿Estás seguro?" |
| Permission denied | "No tienes permisos para editar precios. Pídeselo a un administrador." | "Acceso denegado" |

Rules:

- **Say what happened and what to do.** An error that does not tell the user how to recover is only an apology.
- **Be specific about counts and names.** "3 facturas pendientes" beats "Algunos elementos pendientes".
- **No emoji as interface.** Not in buttons, labels, headings, or serious states.
- **No false cheer.** Enthusiasm on a failure state reads as mockery.
- **Write for the screen it appears on.** A mobile error must be readable and actionable in two lines.

---

## 08 — States

Every state is a piece of copy, not just a visual variant. Each must be written, not left to a component default.

- **Empty** — explain what would be here, and how to create it. An empty state is an onboarding opportunity, not an apology.
- **Loading** — name what is loading when the wait is meaningful; use skeletons when structure is known.
- **Partial** — say what is missing and why, when the cause is knowable.
- **Error** — cause if known, recovery always. Never blame the user for a system fault.
- **Success** — confirm what changed, not that "it worked".
- **Disabled** — the interface must say *why* it is disabled, adjacent to the control.
- **Zero-permission** — distinguish "nothing here yet" from "you cannot see this".

`visual-qa` requires these to exist where applicable. This section governs what they say.

---

## 09 — Voice and tone

Voice is constant; tone adapts to the moment.

- **Voice** is defined once per project: three to five adjectives, chosen with the brand, and held across every surface.
- **Tone** shifts by state: a success message may be warm; a payment failure must be plain and calm.
- **Formality is a decision, not a default.** In Spanish this is explicit — *tú* or *usted* — and must be consistent across the entire product. Mixing them reads as carelessness.
- **Direct address.** Write to the reader. Avoid the impersonal third person where the product is speaking to someone.
- **No corporate abstraction.** "Soluciones", "potencial", "sinergia", "transformación digital" — cut.
- **Say it out loud.** If you would not say the sentence to a real customer, do not ship it.

---

## 10 — Proof and honesty

**Never fabricate evidence.** This is a hard rule, not a stylistic preference.

Forbidden without real, verifiable sources:

- Invented metrics ("+40% de productividad")
- Invented testimonials or invented names
- Fake client logos or implied partnerships
- Fake certifications, awards, or press mentions
- Invented user counts ("más de 10,000 empresas confían en nosotros")
- Fictional case studies presented as real
- Placeholder names presented as customers

Rules:

- **No proof available?** Either omit the proof section entirely, or mark it explicitly as placeholder for the user to replace — never present fiction as fact.
- **Real but unquantified is fine.** "Usado por tres distribuidoras en León" is honest. "Miles de clientes satisfechos" is not, if you do not know.
- **Attribute claims.** If a number comes from the user, use it. If it comes from you, it does not exist.
- **Distinguish demonstration from evidence.** A sample dashboard is a demonstration; label it as such.

This rule protects the client's credibility and their legal position, and an AI agent is exactly the entity most likely to violate it by default.

---

## 11 — Spanish-language adaptation

When the product is in Spanish — the default for most DEVOGATEC work — these are not style preferences but layout constraints.

- **Spanish is 15–25% longer than English.** Every English-derived layout will overflow. Write the real Spanish copy first, then set the layout.
- **Plan for accents and `¿ ¡ ñ`.** Uppercase accented characters, correct punctuation, and the inverted question mark must render — check the font covers them.
- **Decide *tú* or *usted* once, and hold it.** Regional and audience-dependent; never mixed within a product.
- **Avoid anglicisms when a natural term exists**: *contacto* over *lead*, *tablero* over *dashboard*, *inicio de sesión* over *login* — unless the audience genuinely uses the English term, in which case use it consistently.
- **Avoid translated-English constructions**: "hacer sentido", "aplicar para", "remover" as *remove*. Write Spanish, not English with Spanish words.
- **Regional vocabulary matters.** Mexican Spanish differs from Spain and from the Southern Cone. Match the client's market; do not default to one region's idiom for another.
- **Line length in `ch` differs per language.** Re-verify measure after translation, not just font size.
- **Uppercase is longer than lowercase.** Small caps and uppercase labels need extra horizontal room in Spanish.

---

## 12 — The copy test

Falsify the claim that the copy is specific. A yes/no question ("does this sound generic?") is easy to answer wrongly; a request for evidence is not.

**Delete the product name and the logo. Could this text belong to a competitor?**

If yes, name what would have to change to make it belong only here. If you cannot name it, the copy is filler.

Then run the three checks:

1. **The substitution test** — swap in a competitor's name. If every sentence remains true, rewrite.
2. **The specificity test** — count concrete nouns (numbers, places, processes, tools, names, units). Fewer than one per paragraph means vagueness.
3. **The read-aloud test** — say it to a skeptical customer. If you would be embarrassed, rewrite.

---

## 13 — Copy preflight

Before delivery, confirm:

- The input table in §02 was answered or explicitly flagged as assumption.
- The first screen states what this is and who it is for, in specific terms.
- Every headline passes the substitution test.
- One primary message and one primary action per page.
- Every CTA names a concrete outcome, and its label matches its destination.
- Every feature listed states its consequence.
- Empty, loading, error, success, and disabled states have real copy, not defaults.
- No fabricated metrics, testimonials, logos, or certifications.
- Formality (*tú* / *usted*) is consistent throughout.
- Spanish copy was written before the layout, and the layout holds it at every breakpoint.
- No filler transitions, no emoji as interface, no corporate abstraction.

`visual-qa` verifies these in the **rendered** result, not in the source.

---

## 14 — Final principle

Do not ask: *"How do I fill this space?"*

Ask: *"What is true here that is worth saying?"*

**Then say only that.**

A page that says one true, specific thing beats a page that says eight plausible ones.
