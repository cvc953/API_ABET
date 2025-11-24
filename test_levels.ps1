# Script para probar el endpoint /api/levels/{indicator_id}
# Ejecutar: .\test_levels.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key o dejar vacío

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST: /api/levels/{indicator_id}" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Configurar headers
$headers = @{}
if ($API_KEY -ne "tu_api_key_aqui" -and $API_KEY -ne "") {
    $headers["X-API-Key"] = $API_KEY
}

# Test 1: Health check
Write-Host "1️⃣  Health Check" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$API_URL/health" -Method GET
    Write-Host "   ✅ API: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ API no responde" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Obtener outcomes e indicadores para saber qué IDs probar
Write-Host "2️⃣  Obteniendo indicadores disponibles..." -ForegroundColor Yellow
try {
    $outcomes = Invoke-RestMethod -Uri "$API_URL/api/outcomes" -Method GET -Headers $headers
    
    if ($outcomes.Count -gt 0) {
        $firstOutcome = $outcomes[0]
        Write-Host "   ✅ Outcome encontrado: ID $($firstOutcome.id) - $($firstOutcome.so_number)" -ForegroundColor Green
        
        # Obtener indicadores de este outcome
        $indicators = Invoke-RestMethod -Uri "$API_URL/api/indicators/$($firstOutcome.id)" -Method GET -Headers $headers
        
        if ($indicators.Count -gt 0) {
            Write-Host "   ✅ Indicadores encontrados: $($indicators.Count)" -ForegroundColor Green
            $testIndicatorId = $indicators[0].id
            Write-Host "   📌 Usaremos indicator ID: $testIndicatorId" -ForegroundColor Cyan
        } else {
            Write-Host "   ⚠️  No hay indicadores para este outcome" -ForegroundColor Yellow
            $testIndicatorId = 2  # Usar ID del error reportado
        }
    } else {
        Write-Host "   ⚠️  No hay outcomes en BD, probando con ID 2" -ForegroundColor Yellow
        $testIndicatorId = 2
    }
} catch {
    Write-Host "   ⚠️  Error al obtener datos, probando con ID 2" -ForegroundColor Yellow
    $testIndicatorId = 2
}
Write-Host ""

# Test 3: Probar /api/levels con el ID encontrado (formato correcto)
Write-Host "3️⃣  Test /api/levels/$testIndicatorId (formato correcto)" -ForegroundColor Yellow
try {
    $levels = Invoke-RestMethod -Uri "$API_URL/api/levels/$testIndicatorId" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona: $($levels.Count) niveles encontrados" -ForegroundColor Green
    
    if ($levels.Count -gt 0) {
        Write-Host ""
        Write-Host "   📊 NIVELES DE DESEMPEÑO:" -ForegroundColor Cyan
        foreach ($level in $levels) {
            Write-Host "      - ID: $($level.id) | Título: $($level.title) | Score: $($level.minscore)-$($level.maxscore)" -ForegroundColor White
            Write-Host "        Desc: $($level.description)" -ForegroundColor Gray
        }
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Probar formato con llaves
Write-Host "4️⃣  Test /api/levels/{$testIndicatorId} (formato con llaves)" -ForegroundColor Yellow
try {
    $levels2 = Invoke-RestMethod -Uri "$API_URL/api/levels/{$testIndicatorId}" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona con llaves: $($levels2.Count) niveles" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Probar con el ID específico del error (2)
if ($testIndicatorId -ne 2) {
    Write-Host "5️⃣  Test /api/levels/2 (ID del error reportado)" -ForegroundColor Yellow
    try {
        $levels3 = Invoke-RestMethod -Uri "$API_URL/api/levels/2" -Method GET -Headers $headers
        Write-Host "   ✅ Funciona: $($levels3.Count) niveles" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "   📊 ESTRUCTURA DE RESPUESTA:" -ForegroundColor Cyan
        $levels3[0] | Format-List
    } catch {
        Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 El endpoint ahora mapea correctamente:" -ForegroundColor Yellow
Write-Host "   title_es → title" -ForegroundColor White
Write-Host "   description_es → description" -ForegroundColor White
Write-Host ""
