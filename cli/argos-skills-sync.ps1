#Requires -Version 5.1
# ============================================================
# ARGOS - STACK VISUAL DE VIVI -> TODOS LOS RUNNERS
#
# Fuente canonica (repo): core/skills/v2/<skill> (propias ARGOS)
# y .agents/skills/taste-skill (externa adaptada). Impeccable se
# toma de ~/.config/opencode/skills/impeccable si existe.
#
# Destinos: cada CLI/entorno lee skills de SU directorio global.
# El stack se mantiene identico en todos para que Vivi cargue lo
# mismo sin importar desde donde se lance (DSH, claude, codex,
# opencode, gemini/agy, cmdc, Antigravity y el estandar ~/.agents,
# que es de donde tambien leen la app de ChatGPT/Codex y freebuff).
#
# Ademas genera el pack de experiencia completa para la app de
# ChatGPT en <HomeBase>/.agents/chatgpt-vivi/ (INSTRUCTIONS.md +
# VIVI-STACK.md + README.md).
#
# Uso (dot-source):
#   . (Join-Path $PSScriptRoot 'argos-skills-sync.ps1')
#   Sync-ViviDesignStack -Root $Root [-HomeBase <dir>] [-Quiet]
#
# -HomeBase permite el modo hermetico de los tests (TargetDir).
# Idempotente y barato: solo escribe si el contenido cambio.
# ============================================================

function Get-ViviDesignStackNames {
    return @('vivi-visual-excellence', 'design-principles', 'content-copy', 'motion-design', 'visual-qa')
}

# Fuentes canonicas del stack: skills propias v2 + externas adaptadas (si existen).
function Get-ViviDesignStackSources {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$HomeBase = ''
    )
    if (-not $HomeBase) { $HomeBase = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME } }
    $sources = @()
    foreach ($n in (Get-ViviDesignStackNames)) {
        $p = Join-Path $Root "core\skills\v2\$n"
        if (Test-Path -LiteralPath (Join-Path $p 'SKILL.md')) { $sources += @{ Name = $n; Source = $p } }
    }
    $taste = Join-Path $Root '.agents\skills\taste-skill'
    if (Test-Path -LiteralPath (Join-Path $taste 'SKILL.md')) { $sources += @{ Name = 'taste-skill'; Source = $taste } }
    $impeccable = Join-Path $HomeBase '.config\opencode\skills\impeccable'
    if (Test-Path -LiteralPath (Join-Path $impeccable 'SKILL.md')) { $sources += @{ Name = 'impeccable'; Source = $impeccable } }
    return $sources
}

# Escribe solo si el contenido cambio (idempotente, sin tocar timestamps).
function Write-FileIfChanged {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    if (Test-Path -LiteralPath $Path) {
        try {
            if ([System.IO.File]::ReadAllText($Path) -eq $Content) { return 0 }
        } catch { }
    }
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
    return 1
}

# Compara el bundle destino contra la fuente (SKILL.md + reference/ + cualquier archivo).
function Test-SkillBundleCurrent {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath (Join-Path $Destination 'SKILL.md'))) { return $false }
    $srcFiles = @(Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue)
    if ($srcFiles.Count -eq 0) { return $false }
    foreach ($f in $srcFiles) {
        $rel = $f.FullName.Substring($Source.Length).TrimStart('\', '/')
        $dst = Join-Path $Destination $rel
        if (-not (Test-Path -LiteralPath $dst)) { return $false }
        if ((Get-Item -LiteralPath $dst).Length -ne $f.Length) { return $false }
        if ((Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash) { return $false }
    }
    return $true
}

# Reemplazo atomico a nivel de bundle: evita anidamiento y archivos obsoletos al repetir.
function Sync-SkillBundle {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

# ============================================================
# PACK "EXPERIENCIA COMPLETA" PARA LA APP DE CHATGPT
# Genera <HomeBase>/.agents/chatgpt-vivi/ con:
#   INSTRUCTIONS.md -> se pega en las instrucciones del Project/GPT
#   VIVI-STACK.md   -> stack completo en un solo archivo (Source)
#   README.md       -> pasos de montaje
# ============================================================
function Sync-ChatGPTViviPack {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$HomeBase = '',
        [switch]$Quiet
    )
    if (-not $HomeBase) { $HomeBase = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME } }

    $packDir = Join-Path $HomeBase '.agents\chatgpt-vivi'
    $sources = Get-ViviDesignStackSources -Root $Root -HomeBase $HomeBase

    # --- VIVI-STACK.md: todas las skills + sus reference/ en un solo archivo ---
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# Vivi Visual Stack — bundle completo (generado por ARGOS)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Pipeline: design-principles + content-copy (siempre) → motion-design (si aplica) → visual-qa (al final).')
    [void]$sb.AppendLine(('Generado: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm')))
    [void]$sb.AppendLine('')
    foreach ($item in $sources) {
        $skillFile = Join-Path $item.Source 'SKILL.md'
        [void]$sb.AppendLine('---')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine(("# === SKILL: {0} ===" -f $item.Name))
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine(([System.IO.File]::ReadAllText($skillFile)).Trim())
        [void]$sb.AppendLine('')
        # Los reference/ del bundle: solo de las skills canonicas ARGOS (devogatec, evidence-tooling).
        # Las externas (impeccable, taste-skill) traen decenas de referencias internas que solo
        # inflan el bundle; su SKILL.md ya apunta a ellas cuando la skill completa esta instalada.
        if ((Get-ViviDesignStackNames) -contains $item.Name) {
            foreach ($sub in @('reference', 'references', 'resources')) {
                $dir = Join-Path $item.Source $sub
                if (-not (Test-Path -LiteralPath $dir)) { continue }
                foreach ($f in (Get-ChildItem -LiteralPath $dir -File | Sort-Object Name)) {
                    [void]$sb.AppendLine('---')
                    [void]$sb.AppendLine('')
                    [void]$sb.AppendLine(("# === REFERENCE: {0}/{1}/{2} ===" -f $item.Name, $sub, $f.Name))
                    [void]$sb.AppendLine('')
                    [void]$sb.AppendLine(([System.IO.File]::ReadAllText($f.FullName)).Trim())
                    [void]$sb.AppendLine('')
                }
            }
        }
    }

    $instructions = @'
# Vivi — Frontend DPS del party ARGOS

Eres **Vivi** (Mage / Frontend) del harness ARGOS/OSMA: la responsable de que toda interfaz
sea intencional, distintiva y TERMINADA. Personalidad: entusiasta, perfeccionista, duda
antes de actuar y brilla al ejecutar. No generas pantallas a lo loco: auditas, diseñas,
implementas y verificas.

> Este texto va en las instrucciones del Project (o como system prompt de un GPT).
> El detalle completo de las skills vive en VIVI-STACK.md (adjunto como Source).

## Pipeline obligatorio — no esperes a que te lo pidan

1. **design-principles — SIEMPRE primero.** Fundamento: layering, spacing, restraint,
   jerarquía, tipografía, color, layout, escalas, tokens, adaptación de marca y
   anti-template test. En la misma fase corre **content-copy**: primero qué dice la
   interfaz, después cómo se ve.
2. **motion-design — SOLO si el proyecto incluye** animación, scroll, parallax, cursor,
   transiciones o experiencia cinemática. Si no hay movimiento con propósito, se omite.
3. **Implementación real** (nada de placeholders ni TODOs).
4. **visual-qa — SIEMPRE al final.** Verifica el render real (desktop/tablet/mobile):
   tipografía, spacing, color, imágenes, interacción, accesibilidad WCAG 2.2 AA y
   performance. Un build que compila NO es un diseño terminado: corrige y vuelve a revisar.

## Estándar de referencia

- **impeccable** — composición, tipografía, color, pulido y crítica sistemática.
- **taste-skill** — anti-slop: sin gradientes genéricos, sin dashboard clon, sin copy de IA.
- **ui-ux-pro-max** — design intelligence: jerarquía visual, spacing, componentes.
- Nunca copies una referencia: **estudia → entiende → abstrae → recombina → crea original**.
- **DEVOGATEC**: deep navy · blue · cyan · white + acentos orange/gold controlados.
  Personalidad: tecnología, confianza, crecimiento, profesional, local, humano, moderno.
  Evita cyberpunk, gaming, cripto, neón y estética de startup IA genérica.

## Reglas de Vivi (no negociables)

- TypeScript strict; nunca `any` ni `@ts-ignore`.
- Server Components por defecto; `'use client'` solo si hay hooks/eventos/APIs del browser.
- Loading + error + empty states obligatorios en cada componente.
- WCAG 2.2 AA: teclado, foco visible, labels, contraste, `prefers-reduced-motion`.
- Mobile-first real: adaptar la estructura, no encogerla.
- Design tokens > valores mágicos; dark mode desde el primer componente.
- Perfeccionismo > velocidad: 1 bien antes que 3 mal.
- Si falta información: UNA pregunta concreta (need-info-escalation). No inventes requisitos.
- Nunca digas "se ve bien": muestra evidencia (qué mediste, en qué breakpoint, qué cambió).

## Skills y contexto

- Carga las skills con `@design-principles`, `@content-copy`, `@motion-design`, `@visual-qa`
  o deja que se carguen solas por su descripción (están instaladas a nivel usuario en
  `~/.agents/skills/` y reunidas en el adjunto **VIVI-STACK.md**).
- `reference/devogatec.md` (dirección de marca) y `reference/evidence-tooling.md` (cómo
  medir la evidencia del QA) forman parte del stack.
- Si trabajas dentro de una carpeta de proyecto con ARGOS: consulta `.arnes/` (memoria OSMA)
  antes de explorar y revalida la memoria contra el código real.
'@

    $readme = @'
# Pack "Vivi — experiencia completa" para la app de ChatGPT

Generado por ARGOS (`cli/argos-skills-sync.ps1`). Se regenera en cada `argos`,
`argos target <entorno>` o `argos opencode`.

## Contenido

- `INSTRUCTIONS.md` -> se pega en las instrucciones del Project (o de un GPT).
- `VIVI-STACK.md`   -> el stack completo (5 skills + taste-skill + impeccable + reference/)
                       en un solo archivo: se adjunta como Source.
- `README.md`       -> esto.

## Montaje (3 pasos)

1. App de ChatGPT -> **Projects** -> **New project** -> nombre "Vivi".
2. **Project instructions** -> pega el contenido de `INSTRUCTIONS.md`.
3. **Sources** -> **Add files** -> adjunta `VIVI-STACK.md`.

Opcional (para que trabaje archivos reales del proyecto):
4. **Edit project** -> **Add folder** -> elige la carpeta del proyecto. Con eso ChatGPT/Codex
   además descubre el `AGENTS.md` del repo y su `.agents/skills` local.

## Uso

- Abre un chat DENTRO del proyecto.
- Pide lo que necesites: "revisa esta landing", "hazme el dashboard", "arregla el mobile".
- Las skills se cargan solas por su descripción; también puedes forzar con `@visual-qa`.

## Notas

- Las skills ya viven a nivel usuario en `~/.agents/skills/` (la app las muestra en la
  barra lateral **Skills**), así que este pack es para la experiencia completa: persona +
  pipeline + stack dentro del contexto del proyecto.
- Si cambian las skills en el arnés, corre `argos` y vuelve a subir `VIVI-STACK.md` si cambió.
'@

    $writes = 0
    $writes += Write-FileIfChanged -Path (Join-Path $packDir 'INSTRUCTIONS.md') -Content $instructions
    $writes += Write-FileIfChanged -Path (Join-Path $packDir 'VIVI-STACK.md') -Content ($sb.ToString())
    $writes += Write-FileIfChanged -Path (Join-Path $packDir 'README.md') -Content $readme
    if (-not $Quiet -and $writes -gt 0) {
        Write-Host ("  [OK] Pack ChatGPT (experiencia Vivi) -> {0}" -f $packDir) -ForegroundColor Green
    }
    return $writes
}

function Sync-ViviDesignStack {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$HomeBase = '',
        [switch]$Quiet
    )
    if (-not $HomeBase) { $HomeBase = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME } }

    # --- Fuentes ---
    foreach ($n in (Get-ViviDesignStackNames)) {
        $p = Join-Path $Root "core\skills\v2\$n"
        if (-not (Test-Path -LiteralPath (Join-Path $p 'SKILL.md')) -and -not $Quiet) {
            Write-Host ("  [!] Skill canonica ausente (se omite): {0}" -f $p) -ForegroundColor Yellow
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $HomeBase '.config\opencode\skills\impeccable\SKILL.md')) -and -not $Quiet) {
        Write-Host '  [!] Impeccable no encontrado (opcional): npx skills add pbakaus/impeccable' -ForegroundColor Yellow
    }
    $sources = Get-ViviDesignStackSources -Root $Root -HomeBase $HomeBase

    # --- Destinos (directorio global de skills de cada entorno) ---
    $destinations = @(
        @{ Label = 'agents';   Path = (Join-Path $HomeBase '.agents\skills') }
        @{ Label = 'dsh';      Path = (Join-Path $HomeBase '.dsh\skills') }
        @{ Label = 'claude';   Path = (Join-Path $HomeBase '.claude\skills') }
        @{ Label = 'codex';    Path = (Join-Path $HomeBase '.codex\skills') }
        @{ Label = 'opencode'; Path = (Join-Path $HomeBase '.config\opencode\skills') }
        @{ Label = 'gemini';   Path = (Join-Path $HomeBase '.gemini\skills') }
        @{ Label = 'cmdc';     Path = (Join-Path $HomeBase '.commandcode\skills') }
        # Antigravity (codelab oficial): scope global de todos sus productos + scope global del CLI
        @{ Label = 'agy-global'; Path = (Join-Path $HomeBase '.gemini\config\skills') }
        @{ Label = 'agy-cli';    Path = (Join-Path $HomeBase '.gemini\antigravity-cli\skills') }
    )

    $updated = 0
    $total = 0
    foreach ($dest in $destinations) {
        foreach ($item in $sources) {
            $total++
            $target = Join-Path $dest.Path $item.Name
            if (Test-SkillBundleCurrent -Source $item.Source -Destination $target) { continue }
            Sync-SkillBundle -Source $item.Source -Destination $target
            $updated++
            if (-not $Quiet) {
                Write-Host ("  [OK] {0,-22} -> {1}" -f $item.Name, $target) -ForegroundColor Green
            }
        }
    }

    # --- Pack de experiencia completa para la app de ChatGPT ---
    $packWrites = Sync-ChatGPTViviPack -Root $Root -HomeBase $HomeBase -Quiet:$Quiet

    if (-not $Quiet) {
        if ($updated -eq 0) {
            Write-Host ("  [OK] Stack visual de Vivi al dia en los {0} entornos." -f $destinations.Count) -ForegroundColor DarkGray
        } else {
            Write-Host ("  [OK] Stack visual de Vivi sincronizado: {0} de {1} bundles actualizados." -f $updated, $total) -ForegroundColor Green
        }
        if ($packWrites -gt 0) {
            Write-Host ("  [OK] Pack ChatGPT actualizado ({0} archivo/s)." -f $packWrites) -ForegroundColor Green
        }
    }
    return $updated
}
