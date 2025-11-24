# Script de diagnóstico para verificar datos en la base de datos
# Ejecutar: .\diagnose_db.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key real o dejar vacío si no hay API_KEY configurada

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DIAGNÓSTICO DE BASE DE DATOS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Configurar headers
$headers = @{}
if ($API_KEY -ne "tu_api_key_aqui" -and $API_KEY -ne "") {
    $headers["X-API-Key"] = $API_KEY
    Write-Host "🔑 Usando API Key" -ForegroundColor Yellow
} else {
    Write-Host "⚠️  Sin API Key (modo desarrollo)" -ForegroundColor Yellow
}
Write-Host ""

# Test 1: Health check
Write-Host "1️⃣  Health Check" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$API_URL/health" -Method GET
    Write-Host "   ✅ API: $($health.status)" -ForegroundColor Green
    if ($health.database) {
        Write-Host "   ✅ BD: $($health.database)" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ API no responde" -ForegroundColor Red
    Write-Host "   Ejecuta: uvicorn main:app --reload" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test 2: Listar todos los outcomes
Write-Host "2️⃣  Listando OUTCOMES disponibles..." -ForegroundColor Yellow
try {
    $outcomes = Invoke-RestMethod -Uri "$API_URL/api/outcomes" -Method GET -Headers $headers
    Write-Host "   ✅ Encontrados: $($outcomes.Count) outcomes" -ForegroundColor Green
    
    if ($outcomes.Count -gt 0) {
        Write-Host ""
        Write-Host "   📊 OUTCOMES EN LA BASE DE DATOS:" -ForegroundColor Cyan
        foreach ($outcome in $outcomes) {
            Write-Host "      - ID: $($outcome.id) | SO: $($outcome.so_number) | Desc: $($outcome.description)" -ForegroundColor White
        }
    } else {
        Write-Host "   ⚠️  NO HAY OUTCOMES EN LA BASE DE DATOS" -ForegroundColor Red
        Write-Host "   Inserta datos en la tabla mdl_gradingform_utb_outcomes" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Error al obtener outcomes" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Probar indicators con los IDs encontrados
if ($outcomes -and $outcomes.Count -gt 0) {
    Write-Host "3️⃣  Probando INDICATORS para cada outcome..." -ForegroundColor Yellow
    foreach ($outcome in $outcomes) {
        Write-Host "   📌 Outcome ID: $($outcome.id) ($($outcome.so_number))" -ForegroundColor Cyan
        try {
            $indicators = Invoke-RestMethod -Uri "$API_URL/api/indicators/$($outcome.id)" -Method GET -Headers $headers
            Write-Host "      ✅ Indicadores: $($indicators.Count)" -ForegroundColor Green
            
            if ($indicators.Count -gt 0) {
                foreach ($ind in $indicators) {
                    Write-Host "         - ID: $($ind.id) | Letra: $($ind.indicator_letter) | Desc: $($ind.description)" -ForegroundColor White
                }
            } else {
                Write-Host "      ⚠️  Sin indicadores para este outcome" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "      ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "3️⃣  OMITIDO: No hay outcomes para probar indicators" -ForegroundColor Yellow
}
Write-Host ""

# Test 4: Probar endpoint específico que reportó error
Write-Host "4️⃣  Probando endpoint específico: /api/indicators/1" -ForegroundColor Yellow
try {
    $test = Invoke-RestMethod -Uri "$API_URL/api/indicators/1" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona: $($test.Count) indicadores" -ForegroundColor Green
    if ($test.Count -eq 0) {
        Write-Host "   ℹ️  Lista vacía: el outcome 1 no tiene indicadores" -ForegroundColor Yellow
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    
    if ($statusCode -eq 404) {
        Write-Host "   🔍 CAUSA: El outcome con ID 1 no existe en la BD" -ForegroundColor Yellow
        Write-Host "   💡 SOLUCIÓN: Usa un ID de outcome que exista (ver lista arriba)" -ForegroundColor Yellow
    } elseif ($statusCode -eq 403) {
        Write-Host "   🔑 CAUSA: API Key inválida o faltante" -ForegroundColor Yellow
        Write-Host "   💡 SOLUCIÓN: Verifica API_KEY en el archivo .env" -ForegroundColor Yellow
    } elseif ($statusCode -eq 500) {
        Write-Host "   💾 CAUSA: Error de base de datos" -ForegroundColor Yellow
        Write-Host "   💡 SOLUCIÓN: Verifica conexión a BD en .env" -ForegroundColor Yellow
    }
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ DIAGNÓSTICO COMPLETADO" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 RECOMENDACIONES:" -ForegroundColor Yellow
Write-Host "   1. Usa IDs de outcomes que existan en tu BD" -ForegroundColor White
Write-Host "   2. Verifica que la tabla mdl_gradingform_utb_indicators tenga datos" -ForegroundColor White
Write-Host "   3. Si usas API Key, configúrala correctamente en .env" -ForegroundColor White
Write-Host ""
