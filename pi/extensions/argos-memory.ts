import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { runBrain } from "./argos-brain.js";
import { addRecalledMemory } from "./argos-working-memory.js";

export function memoryCard(row: any): string {
  return [
    `MEMORY #${row.id}`,
    "",
    `kind: ${row.memory_kind ?? "-"}`,
    `topic: ${row.topic_key}`,
    "",
    `state: ${row.state}`,
    `epistemic: ${row.epistemic_type ?? "unverified"}`,
    "",
    `confidence: ${row.confidence}`,
    `trust: ${row.trust ?? "-"}`,
    `importance: ${row.score ?? "-"}`,
    "",
    `source: ${row.source || "-"}`,
    "",
    `summary:`,
    ` ${row.content}`,
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  const register = (
    name: string,
    label: string,
    description: string,
    params: any,
    map: (p: any) => string[],
    customExecute?: (params: any, ctx: any) => Promise<{ content: any; details: any }>
  ) => {
    pi.registerTool({
      name,
      label,
      description,
      parameters: params,
      async execute(_id, params: any, _sig, _upd, ctx) {
        if (!runBrain) throw new Error("ARGOS: no project");
        if (customExecute) {
          return customExecute(params, ctx);
        }
        const res = await runBrain(ctx.cwd, map(params));
        if (!res.ok)
          return {
            content: [{ type: "text", text: `ARGOS error: ${res.error}` }],
            details: {},
          };
        const rows = res.data as any[];
        const text = Array.isArray(rows)
          ? rows.map(memoryCard).join("\n\n---\n\n")
          : JSON.stringify(res.data, null, 2);
        return {
          content: [{ type: "text", text }],
          details: { count: Array.isArray(rows) ? rows.length : 0 },
        };
      },
    });
  };

  // Search: uses osma-recall command (associative memory with activation)
  register(
    "argos_memory_search",
    "Memory Search",
    "Busca hechos verificados en Memory V3 (RAG asociativo OSMA). Úsalo antes de afirmar hechos del proyecto.",
    Type.Object({
      query: Type.String({ description: "búsqueda" }),
      agent: Type.Optional(Type.String()),
      limit: Type.Optional(Type.Integer({ default: 5 })),
      tag: Type.Optional(Type.String()),
    }),
    (p) => ["osma-recall", p.query, p.agent ?? "-", String(p.limit ?? 5), p.tag ?? "-"],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, [
        "osma-recall",
        params.query,
        params.agent ?? "-",
        String(params.limit ?? 5),
        params.tag ?? "-",
      ]);
      if (!res.ok) {
        return {
          content: [{ type: "text", text: `ARGOS error: ${res.error}` }],
          details: {},
        };
      }
      const rows = res.data as any[];
      if (Array.isArray(rows)) {
        for (const row of rows) {
          if (row && typeof row.id === "number") {
            addRecalledMemory(row.id);
          }
        }
      }
      const text = Array.isArray(rows)
        ? rows.map(memoryCard).join("\n\n---\n\n")
        : JSON.stringify(res.data, null, 2);
      return {
        content: [{ type: "text", text }],
        details: { count: Array.isArray(rows) ? rows.length : 0 },
      };
    }
  );

  // Get: uses get command
  register(
    "argos_memory_get",
    "Memory Get",
    "Obtiene una memoria por id.",
    Type.Object({ id: Type.Integer() }),
    (p) => ["get", String(p.id)]
  );

  // Save: uses save command with JSON stdin
  register(
    "argos_memory_save",
    "Memory Save",
    "Guarda una observación (working|episodic|semantic|procedural). Después de trabajar.",
    Type.Object({
      agent: Type.String(),
      topic_key: Type.String(),
      type: Type.Union([
        Type.Literal("bugfix"),
        Type.Literal("decision"),
        Type.Literal("pattern"),
        Type.Literal("discovery"),
        Type.Literal("preference"),
        Type.Literal("verdict"),
        Type.Literal("recommendation"),
        Type.Literal("action"),
        Type.Literal("session_summary"),
      ]),
      content: Type.String(),
      kind: Type.Optional(Type.String()),
      confidence: Type.Optional(Type.Number()),
      score: Type.Optional(Type.Integer()),
      quest_id: Type.Optional(Type.String()),
    }),
    (p) => ["save", "-"],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, ["save", "-"], params);
      return {
        content: [{ type: "text", text: res.ok ? `Guardado id=${JSON.stringify(res.data)}` : `ARGOS error: ${res.error}` }],
        details: {},
      };
    }
  );

  // Update: uses update command with JSON stdin
  register(
    "argos_memory_update",
    "Memory Update",
    "Actualiza contenido de una memoria (mantiene revisiones).",
    Type.Object({ id: Type.Integer(), content: Type.String() }),
    (p) => ["update", "-"],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, ["update", "-"], params);
      return {
        content: [{ type: "text", text: res.ok ? "Actualizado" : `ARGOS error: ${res.error}` }],
        details: {},
      };
    }
  );

  // Verify: uses verify command with JSON stdin
  register(
    "argos_memory_verify",
    "Memory Verify",
    "Marca una memoria como verificada (PASS/FAIL) con evidencia.",
    Type.Object({
      id: Type.Integer(),
      verdict: Type.String(),
      evidence: Type.Optional(Type.String()),
    }),
    (p) => ["verify", "-"],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, ["verify", "-"], params);
      return {
        content: [{ type: "text", text: res.ok ? "Verificado" : `ARGOS error: ${res.error}` }],
        details: {},
      };
    }
  );

  // Stats: uses stats command
  register(
    "argos_memory_stats",
    "Memory Stats",
    "Estadísticas del cerebro (observaciones, estados, FTS, grafo).",
    Type.Object({}),
    (p) => ["stats"]
  );

  // Context: uses context command
  register(
    "argos_memory_context",
    "Memory Context",
    "Contexto reciente del harness.",
    Type.Object({}),
    (p) => ["context"]
  );

  // Context Associative: uses osma-context command (structured associative package)
  register(
    "argos_memory_context_assoc",
    "Memory Context Associative",
    "Contexto asociativo completo del proyecto (decisiones, errores, soluciones, agentes, contradicciones) para reconstruir el estado antes de trabajar",
    Type.Object({
      query: Type.String({ description: "consulta para activar memoria asociativa" }),
      project: Type.Optional(Type.String()),
      agent: Type.Optional(Type.String()),
      max_tokens: Type.Optional(Type.Integer({ default: 800 })),
    }),
    (p) => [
      "osma-context",
      p.query,
      p.project ?? "-",
      p.agent ?? "-",
      String(p.max_tokens ?? 800),
    ],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, [
        "osma-context",
        params.query,
        params.project ?? "-",
        params.agent ?? "-",
        String(params.max_tokens ?? 800),
      ]);
      if (!res.ok) {
        return {
          content: [{ type: "text", text: `ARGOS error: ${res.error}` }],
          details: {},
        };
      }
      const pkg = res.data as any;
      if (!pkg || typeof pkg !== "object") {
        return {
          content: [{ type: "text", text: JSON.stringify(res.data, null, 2) }],
          details: {},
        };
      }
      const lines: string[] = ["## ARGOS ASSOCIATIVE CONTEXT", ""];
      const sections: Array<[string, string]> = [
        ["project", "PROYECTO"],
        ["direct", "DIRECTO"],
        ["associations", "ASOCIACIONES"],
        ["decisions", "DECISIONES"],
        ["errors_solutions", "ERRORES + SOLUCIONES"],
        ["agents", "AGENTES"],
        ["contradictions", "CONTRADICCIONES"],
      ];
      for (const [key, label] of sections) {
        const val = pkg[key];
        if (val === undefined || val === null) continue;
        if (Array.isArray(val)) {
          if (val.length === 0) continue;
          lines.push(`### ${label} (${val.length})`);
          const capped = val.slice(0, 10);
          for (const row of capped) {
            if (row && typeof row === "object") {
              const id = row.id ?? "-";
              const content = row.content ?? row.summary ?? JSON.stringify(row);
              lines.push(`- #${id}: ${String(content).slice(0, 200)}`);
            } else {
              lines.push(`- ${String(row).slice(0, 200)}`);
            }
          }
          lines.push("");
        } else {
          lines.push(`### ${label}`, String(val), "");
        }
      }
      const text = lines.length > 2 ? lines.join("\n") : JSON.stringify(pkg, null, 2);
      return {
        content: [{ type: "text", text }],
        details: {},
      };
    }
  );

  // Timeline: uses revisions command
  register(
    "argos_memory_timeline",
    "Memory Timeline",
    "Timeline de una memoria (revisiones).",
    Type.Object({ id: Type.Integer() }),
    (p) => ["revisions", String(p.id)]
  );

  // Experience Search: uses osma-experience-search command (validated experiences)
  interface ExperienceRow {
    id: number;
    situation: string;
    conclusion: string;
    action: string;
    outcome: string;
    reward_signal: number;
    validation_status: string;
    confidence: number;
    successful_retrievals: number;
    failed_retrievals: number;
    agent: string;
    project: string;
    topic_key: string;
    applicability: string;
    source_pattern: string | null;
    derived_from: number[];
    // OSMA V6: multidimensional retrieval metadata (may be absent in older rows)
    salience?: number;
    retrieval_routes?: number;
  }
  register(
    "argos_experience_search",
    "Experiencia Validada",
    "Busca experiencias previas validadas (problema→razonamiento→solucion→resultado) para reutilizar antes de razonar desde cero. Si una experiencia similar ya funciono, ARGOS debe reutilizarla.",
    Type.Object({
      query: Type.String({ description: "búsqueda de experiencia" }),
      project: Type.Optional(Type.String()),
      agent: Type.Optional(Type.String()),
      limit: Type.Optional(Type.Integer({ default: 5 })),
    }),
    (p) => [
      "osma-experience-search",
      p.query,
      p.project ?? "-",
      p.agent ?? "-",
      String(p.limit ?? 5),
    ],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, [
        "osma-experience-search",
        params.query,
        params.project ?? "-",
        params.agent ?? "-",
        String(params.limit ?? 5),
      ]);
      if (!res.ok) {
        return {
          content: [{ type: "text", text: `ARGOS error: ${res.error}` }],
          details: {},
        };
      }
      const rows = res.data as ExperienceRow[];
      if (!Array.isArray(rows)) {
        return {
          content: [
            { type: "text", text: JSON.stringify(res.data, null, 2) },
          ],
          details: {},
        };
      }
      const lines: string[] = [];
      for (const row of rows) {
        const applicability = String(row.applicability ?? "").toLowerCase();
        const tag =
          applicability === "apply"
            ? "VALIDADA"
            : applicability === "caution"
            ? "PARCIAL"
            : "OBSOLETA";
        const situation = String(row.situation ?? "").slice(0, 200);
        const conclusion = String(row.conclusion ?? "").slice(0, 200);
        const reward = Number(row.reward_signal ?? 0).toFixed(1);
        const conf = Number(row.confidence ?? 0).toFixed(2);
        const sal =
          row.salience !== undefined ? ` | sal: ${Number(row.salience).toFixed(1)}` : "";
        const rutas =
          row.retrieval_routes !== undefined ? ` | rutas: ${row.retrieval_routes}` : "";
        lines.push(
          `[${tag}] (#${row.id ?? "-"}) situacion: ${situation} | solucion: ${conclusion} | reward: ${reward} | conf: ${conf}${sal}${rutas}`
        );
      }
      const text = lines.length > 0 ? lines.join("\n") : "(sin experiencias validadas)";
      return {
        content: [{ type: "text", text }],
        details: { count: rows.length },
      };
    }
  );

  // Multidimensional Cue Search (OSMA V6): uses osma-cue-search command.
  // Evoca experiencias por MULTIPLES pistas independientes; cada pista que coincide
  // suma confianza y el episodio ganador se entrega con su reconstruccion completa.
  interface CueSearchMatchedCue {
    component_type: string;
    value: string;
    cue_quality: number;
  }
  interface CueSearchRow {
    experience_id: number;
    // OSMA V7: episode identity (format "EPISODE_0742")
    episode_id: string;
    episode_activation_score: number;
    matched_cues: CueSearchMatchedCue[];
    k: number;
    salience: number;
    validation_status: string;
    reward_signal: number;
    applicability: string;
    summary: string;
    solution: string;
    outcome: string;
    project: string;
    agent: string;
  }
  interface CueSearchReconstruction {
    summary: string;
    solution: string;
    outcome: string;
    validation: string;
  }
  interface CueSearchWinner {
    experience_id: number;
    episode_activation_score: number;
    confidence: number;
    reconstruction: CueSearchReconstruction;
  }
  interface CueSearchReactivation {
    episode_id: string;
    reinforced_links: number;
    cues_reinforced: number;
    retrieval_strength_delta: number;
    frequency_delta: number;
  }
  interface CueSearchResponse {
    episodes?: CueSearchRow[];
    results?: CueSearchRow[];
    winner: CueSearchWinner | null;
    total_activated: number;
    // OSMA V7: refuerzo aplicado a la ruta del episodio ganador (null si no hubo)
    reactivation?: CueSearchReactivation | null;
  }
  interface CueSearchParams {
    cues: string;
    project?: string;
    agent?: string;
    limit?: number;
  }
  register(
    "argos_cue_search",
    "Recuperacion Multidimensional",
    "Evoca experiencias por MULTIPLES pistas independientes (tecnologia, persona, error, proyecto, concepto). Cuantas mas pistas coinciden, mas confianza. Devuelve el episodio ganador con su reconstruccion (summary, solucion, resultado).",
    Type.Object({
      cues: Type.String({
        description: "pistas separadas por comas: supabase, rls, permission denied, vivi",
      }),
      project: Type.Optional(Type.String()),
      agent: Type.Optional(Type.String()),
      limit: Type.Optional(Type.Integer({ default: 5 })),
    }),
    (p) => ["osma-cue-search", "-"],
    async (params: CueSearchParams, ctx: { cwd: string }) => {
      const cues = String(params.cues ?? "")
        .split(",")
        .map((c) => c.trim())
        .filter((c) => c.length > 0);
      const res = await runBrain(ctx.cwd, ["osma-cue-search", "-"], {
        cues,
        limit: params.limit ?? 5,
        project: params.project ?? "-",
        agent: params.agent ?? "-",
      });
      if (!res.ok) {
        return {
          content: [{ type: "text", text: `ARGOS error: ${res.error}` }],
          details: {},
        };
      }
      if (!res.data || typeof res.data !== "object") {
        return {
          content: [{ type: "text", text: JSON.stringify(res.data, null, 2) }],
          details: {},
        };
      }
      const pkg = res.data as CueSearchResponse;
      // El contrato nombra la lista "episodes"; la implementacion Python actual
      // entrega "results". Aceptar ambos para no romper la herramienta.
      const episodes = Array.isArray(pkg.episodes)
        ? pkg.episodes
        : Array.isArray(pkg.results)
        ? pkg.results
        : [];
      const lines: string[] = [];
      lines.push("## Episodio ganador (PATTERN COMPLETION)");
      if (pkg.winner && typeof pkg.winner === "object") {
        const w = pkg.winner;
        lines.push(
          `- #${w.experience_id ?? "-"} · score ${Number(
            w.episode_activation_score ?? 0
          ).toFixed(2)} · confianza ${Number(w.confidence ?? 0).toFixed(2)}`
        );
        const rec = w.reconstruction;
        if (rec && typeof rec === "object") {
          lines.push(`- Summary: ${String(rec.summary ?? "-").slice(0, 200)}`);
          lines.push(`- Solucion: ${String(rec.solution ?? "-").slice(0, 200)}`);
          lines.push(`- Resultado: ${String(rec.outcome ?? "-").slice(0, 200)}`);
          lines.push(`- Validacion: ${String(rec.validation ?? "-").slice(0, 200)}`);
        }
        lines.push("");
      } else {
        lines.push("(sin episodio ganador)", "");
      }
      if (pkg.reactivation && typeof pkg.reactivation === "object") {
        const r = pkg.reactivation;
        const retr = Number(r.retrieval_strength_delta ?? 0);
        const retrStr = (retr >= 0 ? "+" : "") + retr.toFixed(2);
        const freq = Number(r.frequency_delta ?? 0);
        const freqStr = (freq >= 0 ? "+" : "") + String(freq);
        lines.push(
          `## Reactivacion: ${r.episode_id ?? "-"} — refuerzo aplicado (links: ${
            r.reinforced_links ?? 0
          }, cues: ${r.cues_reinforced ?? 0}, retrieval ${retrStr}, freq ${freqStr})`,
          ""
        );
      }
      if (episodes.length > 0) {
        lines.push(`## Episodios activados (${episodes.length})`);
        for (const row of episodes) {
          const score = Number(row.episode_activation_score ?? 0).toFixed(1);
          const k = Number(row.k ?? 0);
          const applicability = String(row.applicability ?? "-");
          const episode = row.episode_id ?? `#${row.experience_id ?? "-"}`;
          const text = String(row.summary ?? row.solution ?? "").slice(0, 120);
          lines.push(
            `[score ${score}, ${k} cues] (${episode}, ${applicability}) ${text}`
          );
        }
      }
      const text = lines.length > 0 ? lines.join("\n") : "(sin episodios activados)";
      return {
        content: [{ type: "text", text }],
        details: { count: episodes.length },
      };
    }
  );

  // Episode Detail (OSMA V7): uses osma-episode command.
  // Reconstruye un episodio completo desde su id: componentes (cues), solucion,
  // resultado, rutas de recuperacion, experiencias relacionadas, observaciones y
  // patrones. Permite evocar la experiencia completa a partir de una parte.
  interface EpisodeCue {
    component_type: string;
    value: string;
    cue_quality: number;
    source: string;
    coactivation_count: number;
  }
  interface EpisodeRoutes {
    retrieval_routes: number;
    route_count_by_type: Record<string, number>;
    avg_cue_quality: number;
  }
  interface EpisodeRelatedExperience {
    experience_id: number;
    episode_id: string;
    weight: number;
    coactivation_count: number;
  }
  interface EpisodeRelatedObservation {
    observation_id: number;
    weight: number;
  }
  interface EpisodePattern {
    id: number;
    title: string;
    check_procedure: string;
  }
  interface EpisodeResponse {
    episode_id: string;
    experience_id: number;
    summary: string;
    situation: string;
    reasoning: string;
    conclusion: string;
    action: string;
    outcome: string;
    validation_status: string;
    reward_signal: number;
    confidence: number;
    importance: number;
    salience: number;
    retrieval_strength: number;
    frequency: number;
    association_strength: number;
    project: string;
    agent: string;
    topic_key: string;
    quest_id: string;
    session_id: string;
    files: string[];
    temporal_context: unknown;
    cues: EpisodeCue[];
    routes: EpisodeRoutes;
    related_experiences: EpisodeRelatedExperience[];
    related_observations: EpisodeRelatedObservation[];
    patterns: EpisodePattern[];
  }
  register(
    "argos_episode",
    "Episodio",
    "Reconstruye un episodio completo (EPISODE_XXXX) desde su id: componentes, solucion, resultado, rutas, experiencias relacionadas, observaciones y patrones. Para evocar la experiencia completa a partir de una parte.",
    Type.Object({
      experience_id: Type.Integer({ description: "id de la experiencia" }),
    }),
    (p) => ["osma-episode", String(p.experience_id)],
    async (params: { experience_id: number }, ctx: { cwd: string }) => {
      const res = await runBrain(ctx.cwd, [
        "osma-episode",
        String(params.experience_id),
      ]);
      if (!res.ok) {
        return {
          content: [{ type: "text", text: `ARGOS error: ${res.error}` }],
          details: {},
        };
      }
      if (!res.data || typeof res.data !== "object") {
        return {
          content: [{ type: "text", text: JSON.stringify(res.data, null, 2) }],
          details: {},
        };
      }
      const ep = res.data as EpisodeResponse;
      const lines: string[] = [];
      lines.push(
        `## Episodio ${String(ep.episode_id ?? `#${ep.experience_id ?? params.experience_id}`)}`
      );
      lines.push(`- Summary: ${String(ep.summary ?? "-").slice(0, 200)}`);
      if (ep.situation) {
        lines.push(`- Situacion: ${String(ep.situation).slice(0, 200)}`);
      }
      lines.push(`- Solucion: ${String(ep.conclusion ?? ep.action ?? "-").slice(0, 200)}`);
      lines.push(`- Resultado: ${String(ep.outcome ?? "-").slice(0, 200)}`);
      lines.push(`- Validacion: ${String(ep.validation_status ?? "-")}`);
      if (Array.isArray(ep.cues) && ep.cues.length > 0) {
        lines.push(`Cues: (${ep.cues.length})`);
        for (const cue of ep.cues.slice(0, 12)) {
          const ctype = String(cue.component_type ?? "-");
          const cval = String(cue.value ?? "-").slice(0, 60);
          const q = Number(cue.cue_quality ?? 0).toFixed(2);
          const co = Number(cue.coactivation_count ?? 0);
          lines.push(`- ${ctype}: ${cval} (q ${q}, coactiv ${co})`);
        }
      }
      const routes = ep.routes && typeof ep.routes === "object" ? ep.routes : null;
      lines.push(
        `Rutas: ${routes ? String(routes.retrieval_routes ?? "-") : "-"}`
      );
      if (Array.isArray(ep.related_experiences) && ep.related_experiences.length > 0) {
        lines.push("Relacionados:");
        for (const rel of ep.related_experiences.slice(0, 5)) {
          const eid = String(rel.episode_id ?? `#${rel.experience_id ?? "-"}`);
          const w = Number(rel.weight ?? 0).toFixed(2);
          lines.push(`- ${eid} (w ${w})`);
        }
      }
      const obsCount = Array.isArray(ep.related_observations)
        ? ep.related_observations.length
        : 0;
      lines.push(`Observaciones: ${obsCount}`);
      if (Array.isArray(ep.patterns) && ep.patterns.length > 0) {
        lines.push("Patrones:");
        for (const pat of ep.patterns.slice(0, 3)) {
          lines.push(`- ${String(pat.title ?? pat.id ?? "-")}`);
        }
      }
      const text = lines.length > 0 ? lines.join("\n") : JSON.stringify(ep, null, 2);
      return {
        content: [{ type: "text", text }],
        details: { episode_id: ep.episode_id ?? null },
      };
    }
  );

  // Relations: uses edges command
  register(
    "argos_memory_relations",
    "Memory Relations",
    "Relaciones del grafo de un nodo.",
    Type.Object({ node: Type.String() }),
    (p) => ["edges", p.node]
  );
}
