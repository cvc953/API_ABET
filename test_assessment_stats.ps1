# Script para probar el endpoint de estadísticas de evaluación
# Ejecutar: .\test_assessment_stats.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST: Direct Assessment Statistics" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Configurar headers
$headers = @{"X-API-Key" = $API_KEY}

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

# Test 2: Obtener outcomes para probar
Write-Host "2️⃣  Obteniendo outcomes..." -ForegroundColor Yellow
try {
    $outcomes = Invoke-RestMethod -Uri "$API_URL/api/outcomes" -Headers $headers
    
    if ($outcomes.Count -gt 0) {
        $outcomeId = $outcomes[0].id
        $soNumber = $outcomes[0].so_number
        Write-Host "   ✅ Usando Outcome: $soNumber (ID: $outcomeId)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ No hay outcomes en BD" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ❌ Error al obtener outcomes" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 3: Obtener estadísticas de evaluación
Write-Host "3️⃣  Obteniendo estadísticas (GET /api/outcome-assessment/$outcomeId)" -ForegroundColor Yellow
try {
    $stats = Invoke-RestMethod -Uri "$API_URL/api/outcome-assessment/$outcomeId" -Headers $headers
    
    Write-Host "   ✅ Estadísticas obtenidas" -ForegroundColor Green
    Write-Host ""
    Write-Host "   📊 DIRECT ASSESSMENT OF STUDENT OUTCOME: $($stats.so_number)" -ForegroundColor Cyan
    Write-Host "   ============================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($stats.indicators.Count -eq 0) {
        Write-Host "   ℹ️  No hay evaluaciones para este outcome" -ForegroundColor Yellow
    } else {
        # Crear tabla similar a la imagen
        Write-Host "   Level of Attainment | " -NoNewline -ForegroundColor White
        foreach ($ind in $stats.indicators) {
            Write-Host "Indicator $($ind.indicator) (No. / %)  | " -NoNewline -ForegroundColor White
        }
        Write-Host ""
        Write-Host "   " + ("-" * 80) -ForegroundColor Gray
        
        # Nivel E
        Write-Host "   E                   | " -NoNewline -ForegroundColor White
        foreach ($ind in $stats.indicators) {
            $e = $ind.levels.E
            Write-Host "$($e.count) / $($e.percentage)%         | " -NoNewline -ForegroundColor White
        }
        Write-Host ""
        
        # Nivel G
        Write-Host "   G                   | " -NoNewline -ForegroundColor White
        foreach ($ind in $stats.indicators) {
            $g = $ind.levels.G
            Write-Host "$($g.count) / $($g.percentage)%         | " -NoNewline -ForegroundColor White
        }
        Write-Host ""
        
        # Nivel F
        Write-Host "   F                   | " -NoNewline -ForegroundColor White
        foreach ($ind in $stats.indicators) {
            $f = $ind.levels.F
            Write-Host "$($f.count) / $($f.percentage)%         | " -NoNewline -ForegroundColor White
        }
        Write-Host ""
        
        # Nivel I
        Write-Host "   I                   | " -NoNewline -ForegroundColor White
        foreach ($ind in $stats.indicators) {
            $i = $ind.levels.I
            Write-Host "$($i.count) / $($i.percentage)%         | " -NoNewline -ForegroundColor White
        }
        Write-Host ""
        Write-Host "   " + ("-" * 80) -ForegroundColor Gray
        
        # E + G
        Write-Host "   E + G               | " -NoNewline -ForegroundColor Green
        foreach ($ind in $stats.indicators) {
            $eg = $ind.summary.E_plus_G
            Write-Host "$($eg.count) / $($eg.percentage)%       | " -NoNewline -ForegroundColor Green
        }
        Write-Host ""
        
        # F + I
        Write-Host "   F + I               | " -NoNewline -ForegroundColor Yellow
        foreach ($ind in $stats.indicators) {
            $fi = $ind.summary.F_plus_I
            Write-Host "$($fi.count) / $($fi.percentage)%       | " -NoNewline -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host ""
        
        # Mostrar JSON completo para referencia
        Write-Host "   📄 RESPUESTA JSON COMPLETA:" -ForegroundColor Cyan
        Write-Host ($stats | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    }
    
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Probar con diferentes outcomes
Write-Host "4️⃣  Probando con todos los outcomes disponibles..." -ForegroundColor Yellow
foreach ($outcome in $outcomes) {
    try {
        $stats = Invoke-RestMethod -Uri "$API_URL/api/outcome-assessment/$($outcome.id)" -Headers $headers
        $totalEvals = ($stats.indicators | Measure-Object -Property total_evaluations -Sum).Sum
        Write-Host "   ✅ $($outcome.so_number): $totalEvals evaluaciones totales" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  $($outcome.so_number): Error al obtener estadísticas" -ForegroundColor Yellow
    }
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 ESTRUCTURA DE RESPUESTA:" -ForegroundColor Yellow
Write-Host "   - outcome_id: ID del outcome" -ForegroundColor White
Write-Host "   - so_number: Número del outcome (ej: SO1)" -ForegroundColor White
Write-Host "   - indicators: Array de indicadores con estadísticas" -ForegroundColor White
Write-Host "     - indicator: Letra del indicador (a, b, c...)" -ForegroundColor White
Write-Host "     - total_evaluations: Total de evaluaciones" -ForegroundColor White
Write-Host "     - levels: Desglose por nivel (E, G, F, I)" -ForegroundColor White
Write-Host "       - count: Cantidad de estudiantes" -ForegroundColor White
Write-Host "       - percentage: Porcentaje" -ForegroundColor White
Write-Host "     - summary: Resumen E+G y F+I" -ForegroundColor White
Write-Host ""
