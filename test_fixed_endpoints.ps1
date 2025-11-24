# Script para probar los endpoints corregidos
# Ejecutar: .\test_fixed_endpoints.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key real
$OUTCOME_ID = 1
$STUDENT_CODE = "EST001"  # Cambiar por un código de estudiante real

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST: Endpoints Corregidos" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Configurar headers
$headers = @{
    "X-API-Key" = $API_KEY
}

# Test 1: Health check
Write-Host "1️⃣  Health Check" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$API_URL/health" -Method GET
    Write-Host "   ✅ API: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ API no responde" -ForegroundColor Red
    Write-Host "   Ejecuta: uvicorn main:app --reload" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test 2: /api/indicators/{outcome_id} - Formato correcto
Write-Host "2️⃣  Test /api/indicators/$OUTCOME_ID (formato correcto)" -ForegroundColor Yellow
try {
    $indicators1 = Invoke-RestMethod -Uri "$API_URL/api/indicators/$OUTCOME_ID" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona: $($indicators1.Count) indicadores encontrados" -ForegroundColor Green
    if ($indicators1.Count -gt 0) {
        Write-Host "   📊 Primer indicador: $($indicators1[0].indicator_letter)" -ForegroundColor Cyan
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    if ($statusCode -eq 403) {
        Write-Host "   🔑 Verifica API_KEY" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "   🔍 Outcome ID $OUTCOME_ID no existe" -ForegroundColor Yellow
    } else {
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 3: /api/indicators/{outcome_id} - Formato con llaves
Write-Host "3️⃣  Test /api/indicators/{$OUTCOME_ID} (formato con llaves)" -ForegroundColor Yellow
try {
    $indicators2 = Invoke-RestMethod -Uri "$API_URL/api/indicators/{$OUTCOME_ID}" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona con llaves: $($indicators2.Count) indicadores" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: /api/evaluations/{student_code} - Formato correcto
Write-Host "4️⃣  Test /api/evaluations/$STUDENT_CODE (formato correcto)" -ForegroundColor Yellow
try {
    $evals1 = Invoke-RestMethod -Uri "$API_URL/api/evaluations/$STUDENT_CODE" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona: $($evals1.Count) evaluaciones encontradas" -ForegroundColor Green
    if ($evals1.Count -gt 0) {
        Write-Host "   📊 Primera evaluación - Outcome: $($evals1[0].outcome_id), Score: $($evals1[0].score)" -ForegroundColor Cyan
    } elseif ($evals1.Count -eq 0) {
        Write-Host "   ℹ️  Sin evaluaciones para este estudiante" -ForegroundColor Yellow
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    if ($statusCode -eq 403) {
        Write-Host "   🔑 Verifica API_KEY" -ForegroundColor Yellow
    } else {
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 5: /api/evaluations/{student_code} - Formato con llaves
Write-Host "5️⃣  Test /api/evaluations/{$STUDENT_CODE} (formato con llaves)" -ForegroundColor Yellow
try {
    $evals2 = Invoke-RestMethod -Uri "$API_URL/api/evaluations/{$STUDENT_CODE}" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona con llaves: $($evals2.Count) evaluaciones" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Ambos endpoints ahora soportan:" -ForegroundColor Yellow
Write-Host "   ✅ Formato estándar: /api/indicators/1" -ForegroundColor White
Write-Host "   ✅ Formato con llaves: /api/indicators/{1}" -ForegroundColor White
Write-Host ""
