#Requires -Version 5.1
<#
.SYNOPSIS
Tabla de precios estimados por modelo (USD) - dot-sourcable desde argos-stats.ps1.

.DESCRIPTION
Define Get-ModelPricePerToken, que devuelve el costo estimado en USD por TOKEN
(promedio input/output) segun el modelo. Los precios de la tabla estan expresados
por 1M de tokens; la funcion los divide por 1,000,000 para devolver el precio por
token. No imprime nada al ser dot-sourced.
#>

function Get-ModelPricePerToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModelName
    )

    $name = $ModelName.Trim().ToLowerInvariant()
    if (-not $name) { return [double](0.35 / 1000000.0) }

    # Precios promedio USD por 1M tokens (input+output). El orden importa:
    # se recorre de arriba a abajo y gana la primera coincidencia parcial.
    # 'deepseek' va al final para que 'deepseek v4 pro' no caiga en flash.
    $priceTable = @(
        @{ Keyword = 'flash';    PricePerM = 0.21 },  # DeepSeek V4 Flash  (0.14 in / 0.28 out)
        @{ Keyword = 'pro';      PricePerM = 0.42 },  # DeepSeek V4 Pro    (0.28 in / 0.56 out)
        @{ Keyword = 'luna';     PricePerM = 1.00 },  # GPT-5.6 Luna       (0.40 in / 1.60 out)
        @{ Keyword = 'qwen';     PricePerM = 1.50 },  # Qwen3.8 Max        (0.60 in / 2.40 out)
        @{ Keyword = 'deepseek'; PricePerM = 0.21 }   # deepseek a secas   -> Flash
    )

    foreach ($row in $priceTable) {
        if ($name -like "*$($row.Keyword)*") {
            return [double]($row.PricePerM / 1000000.0)
        }
    }

    # Fallback generico para modelos desconocidos: $0.35 por 1M tokens
    return [double](0.35 / 1000000.0)
}

<#
.SYNOPSIS
Calcula el costo estimado considerando cache hit/miss de DeepSeek.

.DESCRIPTION
DeepSeek cobra 3 precios para input tokens:
- Cache miss: precio completo (ej: $0.27/1M para Flash)
- Cache hit: 4x mas barato (ej: $0.07/1M para Flash)
- Cache storage: = cache miss (se amortiza en peticiones siguientes)

Esta funcion recibe el total de tokens, cuantos fueron cache hit, el modelo,
y devuelve el costo REAL considerando el descuento de cache.

.EXAMPLE
Get-ModelCostWithCache -Model 'deepseek-v4-flash' -TotalTokens 5000 -CacheHitTokens 3000
#>
function Get-ModelCostWithCache {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModelName,

        [Parameter(Mandatory = $true)]
        [int]$TotalTokens,

        [int]$CacheHitTokens = 0
    )

    if ($TotalTokens -le 0) { return 0.0 }

    $normalPrice = Get-ModelPricePerToken $ModelName
    $cacheHitTokens = [math]::Max(0, [math]::Min($CacheHitTokens, $TotalTokens))
    $cacheMissTokens = $TotalTokens - $cacheHitTokens

    # DeepSeek: cache hit cuesta 4x menos (1/4 del precio normal)
    # Otros modelos (OpenAI o4/o3, Qwen3.8): tambien aplican descuento de cache
    $cacheHitPrice = $normalPrice / 4.0

    $cost = ($cacheMissTokens * $normalPrice) + ($cacheHitTokens * $cacheHitPrice)
    return [double]$cost
}

<#
.SYNOPSIS
Calcula el ahorro (savings) en USD por usar cache de prefijo.

.DESCRIPTION
Devuelve la diferencia entre lo que costaria sin cache vs lo que costo con cache.
Util para mostrar en argos stats cuanto dinero se ahorra con prompt caching.

.EXAMPLE
Get-CacheSavings -Model 'deepseek-v4-flash' -TotalTokens 5000 -CacheHitTokens 3000
#>
function Get-CacheSavings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModelName,

        [Parameter(Mandatory = $true)]
        [int]$TotalTokens,

        [int]$CacheHitTokens = 0
    )

    if ($TotalTokens -le 0 -or $CacheHitTokens -le 0) { return 0.0 }

    $normalPrice = Get-ModelPricePerToken $ModelName
    $costWithoutCache = $TotalTokens * $normalPrice
    $costWithCache = Get-ModelCostWithCache -ModelName $ModelName -TotalTokens $TotalTokens -CacheHitTokens $CacheHitTokens

    return [double]($costWithoutCache - $costWithCache)
}
