#!/usr/bin/env node
/**
 * Gate L2 — Schema ↔ Código (columnas referenciadas existen)
 * =========================================================
 * AST-lite audit de strings en supabase-js:
 *   - .from("tabla").select("col1,col2,alias:rel!fk(...)")
 *   - .eq/.neq/.in/.gte/.lte/.like/.ilike/.contains/.overlaps("col", ...)
 *   - .insert({...}) / .update({...}) / .upsert({...}) keys
 *   - .order("col") / .range()
 *
 * Cada identificador se valida contra database.types.ts (Row types).
 * Strings no-literal (template literals, variables) → UNVERIFIABLE (regla 6).
 *
 * Exit: 0 = PASS, 1 = FAIL (errores encontrados), 2 = SKIP (sin codebase TS)
 *
 * Uso: node select-audit.mjs [--config scripts/contract-audit/config.json] [--json]
 */
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const jsonMode = args.includes('--json');
const cfgIdx = args.indexOf('--config');
const cfgPath = cfgIdx >= 0 ? args[cfgIdx + 1] : 'scripts/contract-audit/config.json';

// Los logs van a stderr: stdout queda LIMPIO para el JSON (lo consume run-all.ps1 / CI)
const log = (msg) => { console.error(msg); };
const out = {
  gate: 'L2',
  status: 'SKIP',
  detail: '',
  checks: [],
  findings: [], // { check, file, line, message }
};

// ---------- config ----------
let cfg = { code: { scan_dirs: ['src', 'app'], extensions: ['.ts', '.tsx', '.js', '.jsx'], max_line_distance_from: 8 } };
try {
  const raw = fs.readFileSync(cfgPath, 'utf8');
  const parsed = JSON.parse(raw);
  cfg.code = { ...cfg.code, ...(parsed.code || {}) };
  cfg.supabase = parsed.supabase || {};
} catch {
  log('  L2 | config.json no encontrado, usando defaults');
}

// ---------- helpers ----------
const walkDir = (dir, exts, outArr) => {
  let entries = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    if (e.name === 'node_modules' || e.name.startsWith('.') || e.name === 'scripts') continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walkDir(full, exts, outArr);
    else if (exts.some((x) => e.name.endsWith(x))) outArr.push(full);
  }
};

/** Extraer la cadena literal de un string JS: '"abc"', "'abc'", o template SIN variables */
const extractLiteral = (raw) => {
  const m = raw.match(/^(['"`])([\s\S]*?)\1$/);
  if (!m) return null;
  const [quote, content] = [m[1], m[2]];
  if (quote === '`' && content.includes('${')) return { unverifiable: true, value: content };
  return { unverifiable: false, value: content };
};

/** Parsear database.types.ts → { tables: { nombre: Set(cols) }, relationships: { tabla: [...] } } */
function parseDatabaseTypes(file) {
  const tables = {};
  const relationships = {};
  let content = '';
  try { content = fs.readFileSync(file, 'utf8'); } catch { return null; }

  // Bloques de tabla: `nombre: { Row: { ... } }` dentro de Tables
  const tableRe = /(\w+):\s*\{\s*Row:\s*\{([\s\S]*?)\}\s*(?:Relationships:|Insert:|Update:|,|\})/g;
  let m;
  while ((m = tableRe.exec(content)) !== null) {
    const tableName = m[1];
    const rowBody = m[2];
    const cols = new Set();
    const colRe = /^\s*(\w+)\s*:/gm;
    let c;
    while ((c = colRe.exec(rowBody)) !== null) cols.add(c[1]);
    if (cols.size > 0) tables[tableName] = cols;
  }

  // Relationships: foreignKeyName + columns + referencedRelation + referencedColumns
  // Formato TS de supabase: propiedades separadas por newline (SIN comas)
  const relRe = /foreignKeyName:\s*"([^"]+)"[\s\S]*?columns:\s*\[([^\]]*)\][\s\S]*?referencedRelation:\s*"([^"]+)"[\s\S]*?referencedColumns:\s*\[([^\]]*)\]/g;
  let r;
  while ((r = relRe.exec(content)) !== null) {
    const [, fkName, colsRaw, refTable, refColsRaw] = r;
    const cols = colsRaw.split(',').map((s) => s.trim().replace(/"/g, '')).filter(Boolean);
    const refCols = refColsRaw.split(',').map((s) => s.trim().replace(/"/g, '')).filter(Boolean);
    relationships[fkName] = { cols, refTable, refCols };
  }

  return { tables, relationships };
}

// ---------- validaciones por check ----------

/**
 * C4 — .select("...") columns existen
 * Formato soportado: col, col2, alias:rel!fk(...), count(*) etc.
 * Devuelve errores: { col, reason }
 */
/** Split de columnas respetando parentesis (joins tienen comas internas) */
function splitSelect(str) {
  const parts = [];
  let depth = 0;
  let current = '';
  for (const ch of str) {
    if (ch === '(') depth++;
    if (ch === ')') depth--;
    if (ch === ',' && depth === 0) {
      parts.push(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  if (current.trim()) parts.push(current.trim());
  return parts.filter(Boolean);
}

/**
 * C4 — .select("...") columns existen
 * Formato soportado:
 *   - col simple
 *   - "*" (wildcard, valido en supabase-js)
 *   - alias:col
 *   - tabla(col1,col2) — embedded join valido
 *   - alias:tabla(col1,col2) — embedded join con alias
 *   - alias:tabla!fk(...) — join explicito
 *   - count(*), sum(col)... — funciones de agregacion
 *   - col::cast
 */
function validateSelect(colsRaw, tableCols, tableName, relMap, dbTables) {
  const errors = [];
  const parts = splitSelect(colsRaw);
  for (const part of parts) {
    // Wildcard
    if (part === '*') continue;

    // Funcion agregada SOLO de funciones SQL conocidas: count(*), sum(col), avg, min, max
    let fn = part.match(/^(count|sum|avg|min|max)\(\s*([*]|\w+)\s*\)$/i);
    if (fn) {
      if (fn[2] !== '*' && !tableCols.has(fn[2])) {
        errors.push({ col: fn[2], reason: `funcion ${fn[1]}() sobre columna inexistente en ${tableName}` });
      }
      continue;
    }

    // Embedded join con alias: alias:tabla(col1,col2) o alias:tabla!inner(col1,col2)
    let embAlias = part.match(/^([\w]+):([\w]+)(?:!(?:inner|left|outer|full))?\(([^)]*)\)$/);
    if (embAlias) {
      const [, , relTable, innerCols] = embAlias;
      const relTableCols = dbTables[relTable];
      if (!relTableCols) {
        errors.push({ col: relTable, reason: `embedded join refiere tabla "${relTable}" inexistente` });
        continue;
      }
      for (const ic of splitSelect(innerCols)) {
        if (ic === '*') continue;
        if (!relTableCols.has(ic)) {
          errors.push({ col: ic, reason: `embedded join ${relTable}() columna "${ic}" inexistente` });
        }
      }
      continue;
    }

    // Embedded join sin alias: tabla(col1,col2) o tabla!inner(col1,col2)
    let emb = part.match(/^([\w]+)(?:!(?:inner|left|outer|full))?\(([^)]*)\)$/);
    if (emb) {
      const [, relTable, innerCols] = emb;
      const relTableCols = dbTables[relTable];
      if (!relTableCols) {
        errors.push({ col: relTable, reason: `embedded join refiere tabla "${relTable}" inexistente` });
        continue;
      }
      for (const ic of splitSelect(innerCols)) {
        if (ic === '*') continue;
        if (!relTableCols.has(ic)) {
          errors.push({ col: ic, reason: `embedded join ${relTable}() columna "${ic}" inexistente` });
        }
      }
      continue;
    }

    // Join explicito: alias:table!fk(...) o alias:table!fk(col,ref)
    let join = part.match(/^([\w]+):([\w]+)!(?:(\w+)\(([^)]*)\)|([\w]+))$/);
    if (join) {
      const [, , refTable, fkName, fkCols, fkShort] = join;
      const key = fkShort || fkName;
      const rel = relMap[key];
      if (!rel) {
        errors.push({ col: key, reason: `join refiere FK "${key}" que no existe en database.types.ts (${refTable})` });
        continue;
      }
      if (refTable && rel.refTable !== refTable) {
        errors.push({ col: key, reason: `join apunta a tabla ${refTable} pero la FK real referencia ${rel.refTable}` });
      }
      continue;
    }

    // Columna simple (puede tener alias embebido tipo "alias:col" o cast ::text)
    let col = part.split(':').pop(); // quita alias si hay "alias:col"
    col = col.split('::')[0]; // quita cast
    if (!tableCols.has(col)) {
      errors.push({ col, reason: `columna "${col}" no existe en tabla ${tableName}` });
    }
  }
  return errors;
}

// ---------- scan del codebase ----------
const files = [];
for (const dir of cfg.code.scan_dirs) walkDir(dir, cfg.code.extensions, files);
if (files.length === 0) {
  out.status = 'SKIP';
  out.detail = 'Sin archivos de codigo TS/TSX en scan_dirs - gate L2 no aplica';
  out.checks.push('C4');
  console.log(JSON.stringify(out));
  process.exit(2);
}

// Buscar database.types.ts
let typesFile = cfg.supabase.types_file;
if (!fs.existsSync(typesFile)) {
  const found = [];
  for (const dir of cfg.code.scan_dirs) walkDir(dir, ['.ts'], found);
  const hit = found.find((f) => f.includes('database.types') || f.includes('database-types'));
  if (hit) typesFile = hit;
}
if (!fs.existsSync(typesFile)) {
  out.status = 'FAIL';
  out.detail = 'database.types.ts no encontrado - sin tipos no hay validacion de columnas (C1/C4)';
  out.checks.push('C4');
  console.log(JSON.stringify(out));
  process.exit(1);
}

const db = parseDatabaseTypes(typesFile);
if (!db || Object.keys(db.tables).length === 0) {
  out.status = 'FAIL';
  out.detail = `database.types.ts no parseable (${typesFile}) - revisar formato de supabase gen types`;
  out.checks.push('C4');
  console.log(JSON.stringify(out));
  process.exit(1);
}

log(`  L2 | tipos parseados: ${Object.keys(db.tables).length} tablas, ${Object.keys(db.relationships).length} FK`);

// ---------- recorrer archivos ----------
const findings = [];
let unverifiableCount = 0;
const maxDist = cfg.code.max_line_distance_from || 8;

for (const file of files) {
  let content;
  try { content = fs.readFileSync(file, 'utf8'); } catch { continue; }
  const lines = content.split('\n');

  let currentTable = null; // tabla del ultimo .from("X")
  let storageMode = false; // supabase.storage en linea anterior -> .from() es bucket
  let pendingVar = null; // "let mesasQuery = supabase" -> espera .from() en la siguiente linea
  const varTables = {}; // variable -> tabla: { mesasQuery: 'mesas', ordenesQuery: 'ordenes' }
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // .storage (puede estar partido: "supabase.storage" + ".from()" en la siguiente linea)
    if (/\.storage\s*\.?$/.test(line) || /\.storage\.from/.test(line)) storageMode = true;

    // "let mesasQuery = supabase" o "mesasQuery = supabase" (sin .from() aun) -> pendiente
    const varDecl = line.match(/^\s*(?:let|const|var)\s+([\w$]+)\s*=\s*(?:[\w$]+\.)*supabase\s*\.?\s*$/);
    const varReassign = line.match(/^\s*([\w$]+)\s*=\s*(?:[\w$]+\.)*supabase\s*\.?\s*$/);
    if (varDecl || varReassign) {
      pendingVar = (varDecl ? varDecl[1] : varReassign[1]);
    }

    // .from("tabla") — cuatro patrones (orden importa: D y A capturan variable primero):
    //   D: let mesasQuery = supabase.from('mesas').select(...)  (asignacion + metodos encadenados)
    //   A: let mesasQuery = supabase.from('mesas')              (asignacion directa)
    //   B: .from('mesas')                                       (encadenado multi-linea)
    //   C: await supabase.from('empresas').delete()             (inline, sin variable capturable)
    const fromD = line.match(/^\s*(?:(?:let|const|var)\s+)?([\w$]+)\s*=\s*(?:[\w$]+\.)*supabase\s*\.\s*from\(\s*(['"`])([\w.]+)\2\s*\)\s*\./);
    const fromA = line.match(/^\s*(?:(?:let|const|var)\s+)?([\w$]+)\s*=\s*(?:[\w$]+\.)*supabase\s*\.\s*from\(\s*(['"`])([\w.]+)\2\s*\)\s*$/);
    const fromB = line.match(/^\s*\.\s*from\(\s*(['"`])([\w.]+)\1\s*\)/);
    const fromC = line.match(/(?:[\w$]+\.)*supabase\s*\.\s*from\(\s*(['"`])([\w.]+)\1\s*\)/);
    const fromM = fromD || fromA || fromB || fromC;
    if (fromM) {
      const varName = (fromD || fromA) ? (fromD ? fromD[1] : fromA[1]) : (pendingVar || null);
      const tableName = fromD ? fromD[3] : (fromA ? fromA[3] : (fromB ? fromB[2] : fromC[2]));
      if (!storageMode) {
        currentTable = tableName;
        if (varName) varTables[varName] = tableName;
      } else {
        // bucket de storage: no es tabla, y si se asigno a una variable la limpiamos
        if (varName) delete varTables[varName];
      }
      pendingVar = null;
      storageMode = false; // consumido
      continue;
    }
    // Si la linea no tiene .from() ni continua el patron storage, reset modo tras esta linea
    if (!/\.storage\s*\.?$/.test(line)) storageMode = false;
    if (!currentTable && Object.keys(varTables).length === 0) continue;

    // Resolver la tabla segun la variable usada: mesasQuery.order(...) -> varTables['mesasQuery']
    let activeTable = currentTable;
    const varUse = line.match(/([\w$]+)\s*\.\s*(?:select|eq|neq|in|gte|lte|gt|lt|like|ilike|contains|overlaps|order|insert|update|upsert)\(/);
    if (varUse && varTables[varUse[1]]) {
      activeTable = varTables[varUse[1]];
    }
    const tableCols = db.tables[activeTable];
    if (!activeTable) {
      // Estado interno del parser (currentTable reseteado sin .from() nuevo): no es error del codigo
      continue;
    }
    if (!tableCols) {
      // La tabla no existe en los tipos -> error fuerte
      findings.push({
        check: 'C4',
        file, line: i + 1,
        message: `.from("${activeTable}") - tabla NO existe en database.types.ts`,
      });
      currentTable = null;
      continue;
    }

    // .select("cols")
    let sel = line.match(/\.select\(\s*(['"`])([\s\S]*?)\1\s*\)/);
    if (sel) {
      const lit = extractLiteral(`${sel[1]}${sel[2]}${sel[1]}`);
      if (lit && lit.unverifiable) {
        unverifiableCount++;
        findings.push({ check: 'C4-UNV', file, line: i + 1, message: '.select() con string dinamico - UNVERIFIABLE (regla 6)' });
      } else if (lit) {
        const errs = validateSelect(lit.value, tableCols, activeTable, db.relationships, db.tables);
        for (const e of errs) findings.push({ check: 'C4', file, line: i + 1, message: `.select("${lit.value}") -> ${e.reason}` });
      }
    }

    // .eq/.neq/.in/.gte/.lte/.like/.ilike/.contains/.overlaps/.order("col", ...)
    const filterRe = /\.(eq|neq|in|gte|lte|gt|lt|like|ilike|contains|overlaps|order)\(\s*(['"`])([\w.]+)\2/g;
    let f;
    while ((f = filterRe.exec(line)) !== null) {
      const [, op, , col] = f;
      // Cross-table filter valido en supabase v2: "ordenes.empresa_id" (embedded filter)
      if (col.includes('.')) continue;
      // las columnas de order pueden llevar direccion: col.asc / col.desc
      const baseCol = col.split('.')[0];
      if (!tableCols.has(baseCol)) {
        findings.push({ check: 'C5', file, line: i + 1, message: `.${op}("${col}") - columna no existe en ${activeTable}` });
      }
    }

    // .insert({...}) / .update({...}) / .upsert({...}) - keys del objeto
    const mutRe = /\.(insert|update|upsert)\(\s*\{\s*([\s\S]{0,400}?)\}\s*\)/;
    const mut = line.match(mutRe);
    if (mut) {
      const [, op, body] = mut;
      const keyRe = /([\w]+)\s*:/g;
      let k;
      while ((k = keyRe.exec(body)) !== null) {
        const col = k[1];
        if (!tableCols.has(col)) {
          findings.push({ check: 'C6', file, line: i + 1, message: `.${op}() key "${col}" no existe en ${activeTable}` });
        }
      }
    }

    // Nueva cadena .from() en misma linea despues del select -> reset para la siguiente
    if (line.includes('.from(') && line.indexOf('.from(') > (sel ? line.indexOf(sel[0]) : -1)) {
      currentTable = null;
    }
  }
}

// ---------- reporte ----------
if (findings.length === 0) {
  out.status = 'PASS';
  out.detail = `ninguna referencia invalida en ${files.length} archivos` + (unverifiableCount > 0 ? ` (${unverifiableCount} UNVERIFIABLE, requerir runtime check)` : '');
  if (unverifiableCount > 0) out.checks.push('C4-UNV');
  console.log(JSON.stringify(out));
  process.exit(0);
}

// Separar UNV de errores reales
const realErrors = findings.filter((f) => !f.check.endsWith('UNV'));
const unv = findings.filter((f) => f.check.endsWith('UNV'));

if (realErrors.length === 0) {
  out.status = 'PASS_WARN';
  out.detail = `${unv.length} strings UNVERIFIABLE (regla 6) - requiere runtime check, no se silencia`;
  out.checks.push('C4-UNV');
  out.findings = unv.slice(0, 20);
  console.log(JSON.stringify(out));
  process.exit(0);
}

out.status = 'FAIL';
out.detail = `${realErrors.length} referencias invalidas en database.types.ts`;
out.checks.push(...[...new Set(realErrors.map((f) => f.check))]);
out.findings = realErrors.slice(0, 30);
for (const f of realErrors.slice(0, 30)) {
  log(`  L2 | ${f.check}: ${path.relative(process.cwd(), f.file)}:${f.line} ${f.message}`);
}
if (realErrors.length > 30) log(`  L2 | ... y ${realErrors.length - 30} mas`);
console.log(JSON.stringify(out));
process.exit(1);
