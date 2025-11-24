# Script para probar el endpoint /api/evaluations/{student_id} corregido
# Ejecutar: .\test_evaluations.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key o dejar vacío

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST: /api/evaluations/{student_id}" -ForegroundColor Cyan
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

# Test 2: Probar con diferentes IDs de estudiante
$testStudentIds = @(1, 2, 3, 100)

foreach ($studentId in $testStudentIds) {
    Write-Host "2️⃣  Test /api/evaluations/$studentId" -ForegroundColor Yellow
    
    try {
        $evals = Invoke-RestMethod -Uri "$API_URL/api/evaluations/$studentId" -Method GET -Headers $headers
        
        if ($evals.Count -gt 0) {
            Write-Host "   ✅ Encontradas: $($evals.Count) evaluaciones" -ForegroundColor Green
            Write-Host ""
            Write-Host "   📊 PRIMERA EVALUACIÓN:" -ForegroundColor Cyan
            $first = $evals[0]
            Write-Host "      - ID: $($first.id)" -ForegroundColor White
            Write-Host "      - Student ID: $($first.studentid)" -ForegroundColor White
            Write-Host "      - Course ID: $($first.courseid)" -ForegroundColor White
            Write-Host "      - Activity: $($first.activityname)" -ForegroundColor White
            Write-Host "      - Outcome ID: $($first.student_outcome_id)" -ForegroundColor White
            Write-Host "      - Indicator ID: $($first.indicator_id)" -ForegroundColor White
            Write-Host "      - Performance Level: $($first.performance_level_id)" -ForegroundColor White
            Write-Host "      - Score: $($first.score)" -ForegroundColor White
            if ($first.feedback) {
                Write-Host "      - Feedback: $($first.feedback)" -ForegroundColor White
            }
            Write-Host ""
            break  # Encontramos datos, salir del loop
        } else {
            Write-Host "   ℹ️  Sin evaluaciones para student ID $studentId" -ForegroundColor Yellow
        }
        
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "   ❌ Error $statusCode para student ID $studentId" -ForegroundColor Red
        
        if ($statusCode -eq 403) {
            Write-Host "   🔑 Verifica API_KEY" -ForegroundColor Yellow
            break
        }
    }
    Write-Host ""
}

# Test 3: Probar formato con llaves
Write-Host "3️⃣  Test /api/evaluations/{1} (formato con llaves)" -ForegroundColor Yellow
try {
    $evals2 = Invoke-RestMethod -Uri "$API_URL/api/evaluations/{1}" -Method GET -Headers $headers
    Write-Host "   ✅ Funciona con llaves: $($evals2.Count) evaluaciones" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Probar con ID inválido
Write-Host "4️⃣  Test /api/evaluations/abc (ID inválido)" -ForegroundColor Yellow
try {
    $evalsInvalid = Invoke-RestMethod -Uri "$API_URL/api/evaluations/abc" -Method GET -Headers $headers
    Write-Host "   ⚠️  Debería haber fallado pero no lo hizo" -ForegroundColor Yellow
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 422) {
        Write-Host "   ✅ Validación correcta: rechaza ID inválido" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Error inesperado: $statusCode" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 CAMBIOS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "   ❌ ANTES: /api/evaluations/{student_code} (string)" -ForegroundColor Red
Write-Host "   ✅ AHORA: /api/evaluations/{student_id} (integer)" -ForegroundColor Green
Write-Host ""
Write-Host "📊 ESTRUCTURA DE RESPUESTA COMPLETA:" -ForegroundColor Yellow
Write-Host "   - id, instanceid, studentid, courseid" -ForegroundColor White
Write-Host "   - activityid, activityname" -ForegroundColor White
Write-Host "   - student_outcome_id, indicator_id, performance_level_id" -ForegroundColor White
Write-Host "   - score, feedback, timecreated, timemodified" -ForegroundColor White
Write-Host ""
