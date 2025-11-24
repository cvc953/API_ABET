# Script rápido para probar el endpoint con ambos formatos
# Ejecutar: .\test_quick.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key real
$OUTCOME_ID = 2  # Cambiar por el ID que quieras probar

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST RÁPIDO: /api/outcome-summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Configurar headers
$headers = @{
    "X-API-Key" = $API_KEY
}

# Test 1: Health check
Write-Host "1️⃣  Probando health check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$API_URL/health" -Method GET -ErrorAction Stop
    Write-Host "   ✅ API está activa: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ API no responde. ¿Está ejecutándose?" -ForegroundColor Red
    Write-Host "   Ejecuta: uvicorn main:app --reload" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Test 2: Formato correcto (sin llaves)
Write-Host "2️⃣  Probando formato CORRECTO: /api/outcome-summary/$OUTCOME_ID" -ForegroundColor Yellow
try {
    $response1 = Invoke-RestMethod -Uri "$API_URL/api/outcome-summary/$OUTCOME_ID" -Method GET -Headers $headers -ErrorAction Stop
    Write-Host "   ✅ Funciona correctamente" -ForegroundColor Green
    Write-Host "   📊 Outcome ID: $($response1.id)" -ForegroundColor Cyan
    Write-Host "   📊 SO Number: $($response1.so_number)" -ForegroundColor Cyan
    Write-Host "   📊 Indicadores: $($response1.indicators.Count)" -ForegroundColor Cyan
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    if ($statusCode -eq 403) {
        Write-Host "   🔑 Verifica tu API_KEY en el script" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "   🔍 El Outcome ID $OUTCOME_ID no existe en la BD" -ForegroundColor Yellow
    } else {
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Test 3: Formato con llaves (compatibilidad)
Write-Host "3️⃣  Probando formato CON LLAVES: /api/outcome-summary/{$OUTCOME_ID}" -ForegroundColor Yellow
try {
    # Nota: PowerShell necesita escape para las llaves en URLs
    $urlWithBraces = "$API_URL/api/outcome-summary/{$OUTCOME_ID}"
    $response2 = Invoke-RestMethod -Uri $urlWithBraces -Method GET -Headers $headers -ErrorAction Stop
    Write-Host "   ✅ Funciona con llaves (compatibilidad)" -ForegroundColor Green
    Write-Host "   📊 Outcome ID: $($response2.id)" -ForegroundColor Cyan
    Write-Host "   📊 SO Number: $($response2.so_number)" -ForegroundColor Cyan
    Write-Host "   📊 Indicadores: $($response2.indicators.Count)" -ForegroundColor Cyan
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Tip: Usa el formato sin llaves (Test 2) para mejor rendimiento" -ForegroundColor Yellow
Write-Host ""
