// ARGOS/OSMA brain bridge for DeepSeek Harness.
// Equivalent of pi/extensions/argos-brain.ts runBrain: spawns the shared Python
// brain (osma_brain.py) against <project>/.arnes/arnes.db and returns JSON.
import { spawn } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'

export function isArnesProject(cwd) {
  return existsSync(join(cwd, '.arnes', 'arnes.db'))
}

// Find the project root: from a cwd (session header cwd or explicit), walk up
// looking for .arnes/arnes.db (memoria per-proyecto compartida entre CLIs).
export function resolveProjectRoot(cwd) {
  let dir = resolve(cwd || process.cwd())
  for (let i = 0; i < 8; i++) {
    if (existsSync(join(dir, '.arnes', 'arnes.db'))) return dir
    const parent = resolve(dir, '..')
    if (parent === dir) break
    dir = parent
  }
  return null
}

// OSMA vive en un repo separado e instalado globalmente. Resolucion:
//  1. $env:ARNES_OSMA_ROOT  2. ~/.config/arnes/osma  3. ../osma  4. ./cli (legacy)
export function resolveBrainPath(projectRoot) {
  const home = process.env.USERPROFILE || ''
  const candidates = []
  if (process.env.ARNES_OSMA_ROOT) candidates.push(process.env.ARNES_OSMA_ROOT)
  if (home) candidates.push(join(home, '.config', 'arnes', 'osma'))
  candidates.push(resolve(projectRoot, '..', 'osma'))
  candidates.push(resolve(projectRoot, 'cli'))
  for (const root of candidates) {
    for (const name of ['osma_brain.py', 'arnes_brain.py']) {
      const local = join(root, name)
      if (existsSync(local)) return local
    }
  }
  throw new Error('ARGOS: no se encontró osma_brain.py (instala OSMA o set ARNES_OSMA_ROOT)')
}

// Localiza el scanner de proyectos OSMA (osma-scan-projects.ps1) en la raiz OSMA.
export function resolveScanScript(projectRoot) {
  const home = process.env.USERPROFILE || ''
  const candidates = []
  if (process.env.ARNES_OSMA_ROOT) candidates.push(process.env.ARNES_OSMA_ROOT)
  if (home) candidates.push(join(home, '.config', 'arnes', 'osma'))
  candidates.push(resolve(projectRoot, '..', 'osma'))
  for (const root of candidates) {
    const local = join(root, 'osma-scan-projects.ps1')
    if (existsSync(local)) return local
  }
  return null
}

export async function runBrain(cwd, args, stdinJson, timeoutMs = 8000) {
  try {
    const projectRoot = resolveProjectRoot(cwd)
    if (!projectRoot) return { ok: false, data: null, error: 'no ARNES project (.arnes/arnes.db not found)' }
    const brain = resolveBrainPath(projectRoot)
    const db = join(projectRoot, '.arnes', 'arnes.db')
    const child = spawn('python', [brain, db, ...args], { cwd: projectRoot, windowsHide: true })
    let stdout = ''
    let stderr = ''
    child.stdout.on('data', (d) => (stdout += d))
    child.stderr.on('data', (d) => (stderr += d))
    if (stdinJson !== undefined) child.stdin.write(JSON.stringify(stdinJson))
    child.stdin.end()
    const timedOut = Symbol('runBrain-timeout')
    const code = await new Promise((resolveCode) => {
      const timer = setTimeout(() => { child.kill(); resolveCode(timedOut) }, timeoutMs)
      child.on('close', (c) => { clearTimeout(timer); resolveCode(c ?? 0) })
      child.on('error', () => { clearTimeout(timer); resolveCode(-2) })
    })
    child.stdout.destroy(); child.stderr.destroy(); child.stdin.destroy()
    if (code === timedOut) return { ok: false, data: null, error: 'timeout' }
    if (code !== 0) return { ok: false, data: null, error: stderr.trim() || `exit ${code}` }
    const trimmed = stdout.trim()
    if (!trimmed) return { ok: true, data: null }
    try { return { ok: true, data: JSON.parse(trimmed) } }
    catch { return { ok: true, data: trimmed } }
  } catch (e) {
    return { ok: false, data: null, error: e.message }
  }
}
