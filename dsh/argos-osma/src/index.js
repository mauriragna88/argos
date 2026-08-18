// ARGOS/OSMA memory bridge for DeepSeek Harness (Cordis plugin).
//
// Goals (user requirement):
//  1. OSMA es la memoria compartida per-proyecto: <project>/.arnes/arnes.db.
//  2. Este plugin carga ARGOS junto al harness de DeepSeek: registra tools
//     argos_* (status, save, recall, experience record/search, cue search,
//     episode, scan) y un hook de aprendizaje que registra cada turno como
//     observacion + experiencia (igual que argos-learning.ts en PI).
//  3. Cualquier CLI (opencode, pi, claude, codex, dsh) escribe/lee el MISMO
//     arnes.db del proyecto actual.
import { existsSync, appendFileSync, mkdirSync, readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { defineTool } from '@deepseek-ai/dsh-tools'
import { runBrain, resolveProjectRoot, isArnesProject, resolveScanScript } from './brain.js'

// ---------- Prompt Triage (misma heuristica que cli/quest-detector.ps1) ----------
// Protocolo: core/protocols/prompt-triage.md — clasifica 1-4, recomienda modelo,
// gate de confirmacion y deja rastro en .arnes/triage-log.jsonl (event log).
const TRIAGE_PATTERNS = {
  frontend: ['componente', 'component', 'tsx', 'jsx', 'ui', 'css', 'tailwind', 'modal', 'dashboard', 'formulario', 'form', 'login form', 'signup', 'pagina', 'pantalla', 'responsive', 'animacion', 'sidebar', 'navbar', 'header', 'footer', 'button', 'input', 'select', 'card', 'hero', 'toast', 'tabla', 'list', 'grid', 'layout', 'styled'],
  backend: ['api', 'endpoint', 'route', 'supabase', 'postgres', 'prisma', 'schema', 'query', 'mutation', 'rls', 'server action', 'middleware', 'zod', 'webhook', 'backend', 'server', 'database', 'table', 'migration', 'trigger', 'sql', 'rest', 'graphql', 'trpc', 'rpc', 'cron'],
  fix: ['bug', 'fix', 'broken', 'error', 'fail', 'no funciona', 'crash', '404', '500', 'regression', 'exception', 'stack trace', 'undefined', 'null pointer', 'race condition', 'memory leak'],
  architecture: ['arquitectura', 'architecture', 'plan', 'redisen', 'refactor mayor', 'migrar', 'monorepo', 'design system', 'project structure', 'adr', 'clean architecture', 'hexagonal', 'microservice', 'serverless', 'event-driven', 'cqrs'],
  research: ['investiga', 'busca', 'compara', 'que libreria', 'best practice', 'mejor forma', 'docs', 'documentation', 'como se hace', 'how to', 'tutorial', 'benchmark', 'comparison', 'alternatives', 'vs'],
  devops: ['deploy', 'ci', 'cd', 'docker', 'production', 'prod', 'rollback', 'vercel', 'netlify', 'github actions', 'pipeline', 'workflow', 'build', 'release', 'infrastructure', 'k8s', 'kubernetes', 'terraform'],
  boss: ['feature completa', 'nueva area', 'modulo entero', 'v1', 'mvp', 'from scratch', 'rebuild', 'new project', 'greenfield', 'go-live', 'prod-ready', 'complete feature', 'end to end'],
}

const TRIAGE_L0 = ['delete', 'bulk delete', 'destroy', 'drop table', 'rm -rf', 'production deploy', 'prod deploy', 'force push', 'git reset', 'schema migration', 'rls change', 'rls policy', 'auth change', 'rollback prod', 'rollback production', 'secret rotation', 'database migration', 'breaking change', 'produccion', 'producción', 'rollback', 'migracion', 'migración', 'rls', 'borrar', 'rotacion de secrets', 'rotación de secrets']

// Modelo recomendado por dificultad/dominio (espejo de quest-detector.ps1)
function recommendModel(difficulty, questType) {
  if (difficulty >= 4) return { model: 'opencode-go/qwen3.8-max', tier: 'highest', gate: 'required' }
  if (difficulty === 3) {
    const byType = {
      frontend: 'opencode-go/gpt-5.6-luna',
      architecture: 'opencode-go/kimi-k2.6',
      research: 'opencode-go/deepseek-v4-flash',
      devops: 'opencode-go/deepseek-v4-pro',
    }
    return { model: byType[questType] || 'opencode-go/deepseek-v4-pro', tier: 'pro', gate: 'ask' }
  }
  return { model: 'opencode-go/deepseek-v4-flash', tier: 'flash', gate: 'auto_pass' }
}

function classifyPrompt(prompt) {
  const lower = String(prompt || '').toLowerCase()
  // quest type por keywords
  let bestType = 'unknown'
  let bestScore = 0
  for (const [qt, kws] of Object.entries(TRIAGE_PATTERNS)) {
    const score = kws.filter((k) => lower.includes(k)).length
    if (score > bestScore) { bestScore = score; bestType = qt }
  }
  // L0
  const isL0 = TRIAGE_L0.some((k) => lower.includes(k))
  // complexity por longitud (misma tabla que el detector)
  const len = prompt.length
  let complexity = 'simple'
  if (len < 30) complexity = 'trivial'
  else if (len < 80) complexity = 'simple'
  else if (len < 200) complexity = 'medium'
  else if (len < 500) complexity = 'complex'
  else complexity = 'boss'
  if (bestType === 'boss') complexity = 'boss'
  if (isL0) complexity = 'complex'
  // difficulty 1-4
  let difficulty = 2
  if (complexity === 'trivial') difficulty = 1
  else if (complexity === 'medium') difficulty = 3
  else if (complexity === 'complex') difficulty = 3
  else if (complexity === 'boss') difficulty = 4
  if (bestType === 'boss') difficulty = 4
  if (isL0 && difficulty < 3) difficulty = 3
  // AMBIGUITY (V1.3): prompt abierto -> Atlas complementa antes de clasificar.
  // El nivel final = prompt + complemento; si es ambiguo el gate sube a ask
  // porque el complemento puede subir el nivel. (Espejo de quest-detector.ps1)
  const ambiguityPatterns = ['creas mejor', 'como tu veas', 'lo que mejor', 'alguna idea', 'sugiere', 'sugiereme', 'recomiendame', 'que opinas', 'mejor forma', 'no se', 'nose', 'no se como', 'quiza', 'tal vez', 'no estoy seguro', 'ayudame a decidir', 'que haria', 'segun tu', 'según tu', 'que prefieres', 'podrias sugerir', 'dame ideas', 'me gustaria algo', 'haz algo', 'hazme algo']
  const isAmbiguous = bestScore === 0 || ambiguityPatterns.some((ap) => lower.includes(ap))
  let rec = recommendModel(difficulty, bestType)
  // L0 manda: gate required siempre (espejo de quest-detector.ps1)
  if (isL0 && rec.gate === 'ask') rec.gate = 'required'
  if (isAmbiguous && rec.gate === 'auto_pass') rec.gate = 'ask'
  return { quest_type: bestType, confidence: bestScore, complexity, is_l0: isL0, difficulty, is_ambiguous: isAmbiguous, ...rec, prompt: prompt }
}

// Append de evento triage a .arnes/triage-log.jsonl (append-only, no memoria)
function appendTriageLog(projectRoot, triage, osmaHint) {
  try {
    const logFile = join(projectRoot, '.arnes', 'triage-log.jsonl')
    mkdirSync(dirname(logFile), { recursive: true })
    const evt = {
      event: 'triage',
      ts: new Date().toISOString(),
      prompt_type: triage.quest_type,
      difficulty: triage.difficulty,
      signals: [triage.is_l0 ? 'l0' : '', triage.quest_type === 'unknown' ? 'unknown_type' : '', triage.is_ambiguous ? 'ambiguity' : ''].filter(Boolean),
      similarity: { matched: Boolean(osmaHint), hint: osmaHint || '' },
      model_used: triage.model,
      recommendation: triage.tier,
      user_decision: 'auto',
      outcome: 'PENDING',
      notes: 'dsh argos_triage | gate=' + triage.gate + (triage.is_ambiguous ? ' | ambiguity: Atlas complementa' : ''),
    }
    appendFileSync(logFile, JSON.stringify(evt) + '\n', 'utf8')
  } catch {
    // nunca romper la tool por un fallo de log
  }
}

// ---------- argos_triage: clasificar dificultad + recomendar modelo ----------
const triageTool = defineTool({
  name: 'argos_triage',
  description: 'Clasifica un prompt (dificultad 1-4, quest type, L0), recomienda modelo (flash/pro/highest) y gate de confirmacion (auto_pass/ask/required). Consulta experiencias OSMA similares y deja rastro en .arnes/triage-log.jsonl. Úsalo ANTES de empezar cualquier tarea no trivial para decidir si conviene un modelo de razonamiento.',
  parameters: {
    prompt: { type: 'string', required: true, description: 'El prompt/quest del usuario a clasificar' },
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(args.cwd || (exec && exec.cwd) || process.cwd())
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí (falta .arnes/arnes.db).')
    const triage = classifyPrompt(args.prompt)
    // consulta OSMA: experiencias similares para afinar (anti-repeticion)
    let osmaHint = ''
    try {
      const res = await runBrain(root, ['osma-experience-search', args.prompt, '-', '-', '3'])
      if (res.ok && Array.isArray(res.data) && res.data.length > 0) {
        osmaHint = res.data.map((e) => `[${e.validation_status}] apply=${e.applicability} conf=${e.confidence}: ${(e.summary || e.situation || '').slice(0, 80)}`).join(' | ')
      }
    } catch {}
    appendTriageLog(root, triage, osmaHint)
    const gateLine = triage.gate === 'auto_pass'
      ? 'Gate: auto_pass (ejecutar directo con flash)'
      : triage.gate === 'ask'
        ? 'Gate: ASK — confirma antes: [cambiar a pro] [seguir flash] [dividir]'
        : 'Gate: REQUIRED — tarea L0/dificultad 4, confirmacion obligatoria'
    return text([
      `Prompt Triage (DSH): dificultad ${triage.difficulty}/4`,
      `Quest type: ${triage.quest_type} (conf ${triage.confidence}) | complejidad: ${triage.complexity} | L0: ${triage.is_l0} | AMBIGUO: ${triage.is_ambiguous}`,
      triage.is_ambiguous ? 'Prompt abierto: Atlas complementa (interpreta + alternativas + planeacion minima) antes de clasificar.' : '',
      `Modelo recomendado: ${triage.model} (tier ${triage.tier})`,
      gateLine,
      osmaHint ? `OSMA: ${osmaHint}` : 'OSMA: sin experiencias similares',
    ].filter(Boolean).join('\n'))
  },
})

export const name = 'argos-osma'
export const inject = ['tools']

const text = (value) => ({ content: [{ type: 'text', text: value }], details: {} })

function resolveCwd(args, exec) {
  if (args?.cwd) return args.cwd
  // exec carries the session context; fall back to process cwd
  return process.cwd()
}

// ---------- argos_status: estado del cerebro OSMA del proyecto ----------
const statusTool = defineTool({
  name: 'argos_status',
  description: 'Estado de la memoria OSMA del proyecto ARGOS actual (.arnes/arnes.db): schema, observaciones, experiencias, cues, episodios, patrones, contradicciones. Úsalo para saber si el proyecto tiene ARGOS/OSMA y qué tan poblado está.',
  parameters: {
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional; por defecto la sesión actual)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(resolveCwd(args, exec))
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí (falta .arnes/arnes.db). Corre "argos init" o usa -cwd.')
    const res = await runBrain(root, ['osma-stats'])
    if (!res.ok) return text(`ARGOS error: ${res.error}`)
    const s = res.data
    return text([
      `ARGOS/OSMA proyecto: ${root}`,
      `Schema OSMA: v${s.schema_version ?? '?'}`,
      `Observaciones activas: ${s.active}`,
      `Links asociativos: ${s.links}`,
      `Experiencias (V5): ${s.total_experiences}`,
      `Cues (V6): ${s.total_cues}`,
      `Episodios: ${s.total_episodes}`,
      `Patrones: ${s.total_patterns ?? 0}`,
      `Contradicciones abiertas: ${s.contradictions_open}`,
    ].join('\n'))
  },
})

// ---------- argos_save: guardar observacion ----------
const saveTool = defineTool({
  name: 'argos_save',
  description: 'Guarda una observación (recuerdo) en la memoria OSMA del proyecto. Usa esto al descubrir un hecho, patrón, decisión, error o preferencia durante el trabajo.',
  parameters: {
    content: { type: 'string', required: true, description: 'Contenido del recuerdo (texto)' },
    agent: { type: 'string', description: 'Agente (default: atlas; en dsh usa el nombre del rol, ej: atlas-dsh)' },
    type: { type: 'string', description: 'Tipo: discovery|pattern|decision|bugfix|verdict|preference|action' },
    topic: { type: 'string', description: 'topic_key, ej: "supabase/rls"' },
    score: { type: 'number', description: 'Importancia 0-5 (5 = crítico)' },
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(resolveCwd(args, exec))
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí.')
    const res = await runBrain(root, ['save', '-'], {
      agent: args.agent || 'atlas-dsh',
      topic_key: args.topic || `dsh/${Date.now()}`,
      type: args.type || 'discovery',
      content: args.content,
      score: args.score ?? 0,
    })
    if (!res.ok) return text(`ARGOS error: ${res.error}`)
    return text(`OK observación #${res.data.id} guardada en ${join(root, '.arnes', 'arnes.db')}`)
  },
})

// ---------- argos_recall: buscar recuerdos ----------
const recallTool = defineTool({
  name: 'argos_recall',
  description: 'Busca recuerdos en la memoria OSMA del proyecto (recall FTS5 + propagación asociativa). Úsalo para recordar cómo se resolvió algo antes antes de razonar desde cero.',
  parameters: {
    query: { type: 'string', required: true, description: 'Consulta (palabras clave)' },
    limit: { type: 'number', description: 'Máximo de resultados (default 5)' },
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(resolveCwd(args, exec))
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí.')
    const res = await runBrain(root, ['recall', args.query, '-', String(args.limit || 5)])
    if (!res.ok) return text(`ARGOS error: ${res.error}`)
    const rows = res.data || []
    if (!Array.isArray(rows) || rows.length === 0) return text('Sin recuerdos para esa consulta.')
    return text(rows.map((r, i) => `#${r.id} [${r.memory_kind || r.type || '-'}] ${r.topic_key}\n${r.content}\n(${r.agent}, conf=${r.confidence})`).join('\n\n'))
  },
})

// ---------- argos_experience: registrar experiencia validada ----------
const expTool = defineTool({
  name: 'argos_experience_record',
  description: 'Registra una EXPERIENCIA VALIDADA (V5) en OSMA: situación→razonamiento→conclusión→acción→resultado con reward (-1..1). Las experiencias con reward>=0.9 quedan "verified" y se reutilizan en problemas parecidos. Úsalo cuando resuelvas un problema real (no trivial).',
  parameters: {
    situation: { type: 'string', required: true, description: 'Situación/problema (obligatorio)' },
    reasoning: { type: 'string', description: 'Razonamiento' },
    conclusion: { type: 'string', description: 'Conclusión' },
    action: { type: 'string', description: 'Acción tomada' },
    outcome: { type: 'string', description: 'Resultado real' },
    reward: { type: 'number', description: 'Señal -1..1: 0.9 éxito validado, 0.5 éxito parcial, -0.8 fallo' },
    agent: { type: 'string', description: 'Agente (default atlas-dsh)' },
    project: { type: 'string', description: 'Nombre del proyecto' },
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(resolveCwd(args, exec))
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí.')
    const data = {
      situation: args.situation,
      reasoning: args.reasoning || '',
      conclusion: args.conclusion || '',
      action: args.action || '',
      outcome: args.outcome || '',
      reward: args.reward ?? 0,
      agent: args.agent || 'atlas-dsh',
      project: args.project || root.split(/[\\/]/).pop(),
    }
    const res = await runBrain(root, ['osma-experience-record', '-'], data)
    if (!res.ok) return text(`ARGOS error: ${res.error}`)
    return text(`OK experiencia #${res.data.id}: ${res.data.cues_created} cues, salience=${res.data.salience}, links exp=${res.data.linked_experiences} obs=${res.data.linked_observations}`)
  },
})

// ---------- argos_experience_search: reutilizar experiencia ----------
const expSearchTool = defineTool({
  name: 'argos_experience_search',
  description: 'Busca experiencias validadas reutilizables (V5) para un problema parecido. Devuelve top resultados con applicability (apply/caution/obsolete). Úsalo ANTES de razonar desde cero.',
  parameters: {
    query: { type: 'string', required: true, description: 'Descripción del problema' },
    limit: { type: 'number', description: 'Máximo (default 5)' },
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(resolveCwd(args, exec))
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí.')
    const res = await runBrain(root, ['osma-experience-search', args.query, '-', '-', String(args.limit || 5)])
    if (!res.ok) return text(`ARGOS error: ${res.error}`)
    const rows = res.data || []
    if (!Array.isArray(rows) || rows.length === 0) return text('Sin experiencias previas para ese problema.')
    return text(rows.map((e) => `[${e.validation_status}] apply=${e.applicability} conf=${e.confidence}\n${e.summary || e.situation}`).join('\n\n'))
  },
})

// ---------- argos_cue_search: pattern completion V6/V7 ----------
const cueTool = defineTool({
  name: 'argos_cue_search',
  description: 'Recuperación multidimensional OSMA V6/V7: da pistas (cues) separadas por coma y reconstruye el EPISODIO completo ganador con reactivación (recordar refuerza la memoria). Úsalo cuando "una parte del recuerdo" deba evocar el episodio completo.',
  parameters: {
    cues: { type: 'string', required: true, description: 'Pistas separadas por coma, ej: "permission denied, rls, supabase"' },
    project: { type: 'string', description: 'Proyecto para desambiguar' },
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(resolveCwd(args, exec))
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí.')
    const res = await runBrain(root, ['osma-cue-search', '-'], {
      cues: String(args.cues).split(',').map((s) => s.trim()).filter(Boolean),
      project: args.project || undefined,
    })
    if (!res.ok) return text(`ARGOS error: ${res.error}`)
    const d = res.data || {}
    if (!d.winner) return text(`Sin winner para cues: ${args.cues}`)
    return text([
      `WINNER: ${d.winner.episode_id} score=${d.winner.episode_activation_score}`,
      `Reactivación: ${JSON.stringify(d.reactivation || null)}`,
      `Summary: ${d.winner.summary || d.winner.situation || ''}`,
      `Solución: ${d.winner.solution || ''}`,
      `Outcome: ${d.winner.outcome || ''}`,
    ].join('\n'))
  },
})

// ---------- argos_episode: reconstrucción completa ----------
const episodeTool = defineTool({
  name: 'argos_episode',
  description: 'Reconstruye un EPISODIO OSMA completo por experience_id (V7): summary/situation/reasoning/conclusion/action/outcome, validación, dimensiones, cues, links.',
  parameters: {
    id: { type: 'number', required: true, description: 'experience_id' },
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(resolveCwd(args, exec))
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí.')
    const res = await runBrain(root, ['osma-episode', '-'], { experience_id: args.id })
    if (!res.ok) return text(`ARGOS error: ${res.error}`)
    const e = res.data || {}
    if (e.error) return text(e.error)
    return text([
      `${e.episode_id} [${e.validation_status}] reward=${e.reward_signal}`,
      `S: ${e.summary}`,
      `Razonamiento: ${e.reasoning || ''}`,
      `Solución: ${e.solution || ''}`,
      `Outcome: ${e.outcome || ''}`,
      `Dims: conf=${e.confidence} imp=${e.importance} sal=${e.salience} retr=${e.retrieval_strength} freq=${e.frequency} assoc=${e.association_strength}`,
    ].join('\n'))
  },
})

// ---------- argos_model_stats: telemetria de modelos (Fase 1) ----------
// Lee .arnes/model-runs.jsonl (event log de telemetria, escrito por
// cli/model-telemetry.ps1 en quest-done) y agrega por modelo.
const modelStatsTool = defineTool({
  name: 'argos_model_stats',
  description: 'Telemetría de modelos (Fase 1): lee .arnes/model-runs.jsonl y agrega success rate, tokens y dificultades por modelo recomendado. Úsalo para saber qué modelo (flash/pro/highest) funciona mejor por quest type y presupuestar.',
  parameters: {
    cwd: { type: 'string', description: 'Ruta del proyecto (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    const root = resolveProjectRoot(args.cwd || (exec && exec.cwd) || process.cwd())
    if (!root) return text('ARGOS: no hay proyecto ARNES aquí.')
    const logFile = join(root, '.arnes', 'model-runs.jsonl')
    if (!existsSync(logFile)) return text('Sin telemetría todavía: no existe .arnes/model-runs.jsonl. Se llena al cerrar quests (quest-done).')
    let runs = []
    try {
      runs = readFileSync(logFile, 'utf8').split('\n').filter((l) => l.trim()).map((l) => { try { return JSON.parse(l) } catch { return null } }).filter(Boolean)
    } catch {
      return text(`ARGOS error leyendo ${logFile}`)
    }
    if (runs.length === 0) return text('model-runs.jsonl existe pero sin eventos.')
    const byModel = {}
    for (const r of runs) {
      const key = `${r.model} [${r.route}]`
      if (!byModel[key]) byModel[key] = { count: 0, pass: 0, fail: 0, tokens: 0, diffs: {} }
      byModel[key].count++
      if (r.verdict === 'PASS') byModel[key].pass++
      else if (r.verdict) byModel[key].fail++
      byModel[key].tokens += Number(r.tokens_used) || 0
      const d = Number(r.difficulty) || 0
      byModel[key].diffs[d] = (byModel[key].diffs[d] || 0) + 1
    }
    const lines = Object.entries(byModel)
      .sort((a, b) => b[1].count - a[1].count)
      .map(([model, v]) => {
        const sr = v.count ? Math.round((v.pass / v.count) * 100) : 0
        const avg = v.count ? Math.round(v.tokens / v.count) : 0
        const dl = Object.keys(v.diffs).sort().map((d) => `D${d}x${v.diffs[d]}`).join(' ')
        return `${model}: ${v.count} runs | ${sr}% success | avg ${avg} tok | ${dl}`
      })
    return text([`TELEMETRIA DE MODELOS (${runs.length} runs)`, ...lines].join('\n'))
  },
})

// ---------- argos_scan: auto-identificación de proyectos ARGOS/OSMA ----------
const scanTool = defineTool({
  name: 'argos_scan',
  description: 'Escanea una carpeta (default: carpeta padre del proyecto actual o Documents/GitHub) y detecta qué proyectos tienen ARGOS/OSMA. Auto-identificación de la memoria en todos los proyectos.',
  parameters: {
    base: { type: 'string', description: 'Carpeta a escanear (opcional)' },
  },
  output: {
    schema: { type: 'string' },
    render: (_args, value) => [{ type: 'text', text: value }],
  },
  async execute(args, exec) {
    // Reutiliza el scanner PowerShell del repo (fuente unica)
    const { spawnSync } = await import('node:child_process')
    const root = resolveProjectRoot(process.cwd())
    const script = root ? resolveScanScript(root) : null
    if (!script || !existsSync(script)) return text('ARGOS: no se encontró osma-scan-projects.ps1 (instala OSMA).')
    const base = args.base || ''
    const r = spawnSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, ...(base ? ['-BaseDir', base] : []), '-Json'], { encoding: 'utf8' })
    if (r.status !== 0) return text(`ARGOS scan error: ${r.stderr || r.stdout}`)
    try {
      const d = JSON.parse(r.stdout.trim().split('\n').pop())
      const lines = d.arnes.map((p) => `[ARGOS] ${p.name}: OSMA v${p.schema} obs=${p.obs} exp=${p.exps} cues=${p.cues} quests=${p.quests}`)
      return text([`Proyectos escaneados: ${d.total} | con ARGOS/OSMA: ${d.arnes.length} | sin: ${d.no_arnes.length}`, ...lines].join('\n'))
    } catch {
      return text(r.stdout)
    }
  },
})

// ---------- Learning hook: registrar cada turno en OSMA ----------
// Escucha el fin de turno de la sesión y, si la sesión pertenece a un proyecto
// ARNES, guarda observación + experiencia (equivalente a agent_settled de PI).
function installLearningHook(ctx) {
  const seen = new Set()
  ctx.on('session/event', (session, event) => {
    try {
      if (event.type !== 'turn/end') return
      if (!session?.header?.cwd) return
      const cwd = session.header.cwd
      if (!isArnesProject(cwd)) return
      // una observación por turno (evita duplicados por re-events)
      const key = `${session.id}:${event.turn ?? 0}`
      if (seen.has(key)) return
      seen.add(key)
      const res = runBrain(cwd, ['save', '-'], {
        agent: 'atlas-dsh',
        topic_key: `dsh/turn-${Date.now()}`,
        type: 'action',
        content: `Turno DSH ${event.turn} completado (${event.reason || 'completed'}).`,
      })
      res.catch(() => {}) // nunca romper el harness
    } catch {
      // nunca romper el harness
    }
  })
}

export function apply(ctx) {
  for (const tool of [statusTool, saveTool, recallTool, expTool, expSearchTool, cueTool, episodeTool, scanTool, triageTool, modelStatsTool]) {
    ctx.tools.register(tool)
  }
  installLearningHook(ctx)
  ctx.on('ready', () => {
    // eslint-disable-next-line no-console
    console.log('[argos-osma] ARGOS/OSMA memoria compartida activa (tools argos_*)')
  })
}
