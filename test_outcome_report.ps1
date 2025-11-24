# Script para probar el endpoint de reporte completo del Student Outcome
# Ejecutar: .\test_outcome_report.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST: Student Outcome Complete Report" -ForegroundColor Cyan
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

# Test 2: Obtener outcomes
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

# Test 3: Obtener reporte completo
Write-Host "3️⃣  Obteniendo reporte completo (GET /api/outcome-report/$outcomeId)" -ForegroundColor Yellow
try {
    $report = Invoke-RestMethod -Uri "$API_URL/api/outcome-report/$outcomeId" -Headers $headers
    
    Write-Host "   ✅ Reporte obtenido" -ForegroundColor Green
    Write-Host ""
    
    # Header del reporte
    Write-Host "   ╔═══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "   ║          UNIVERSIDAD TECNOLÓGICA DE BOLÍVAR                               ║" -ForegroundColor Cyan
    Write-Host "   ║          FACULTY OF ENGINEERING                                           ║" -ForegroundColor Cyan
    Write-Host "   ║          STUDENT OUTCOMES $($report.so_number.PadRight(50))║" -ForegroundColor Cyan
    Write-Host "   ╚═══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Información del curso
    Write-Host "   📚 COURSE INFORMATION:" -ForegroundColor White
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   Code:      $($report.course.code)" -ForegroundColor White
    Write-Host "   Course:    $($report.course.name)" -ForegroundColor White
    Write-Host "   Professor: $($report.course.professor)" -ForegroundColor White
    Write-Host "   Programs:  $($report.programs -join ', ')" -ForegroundColor White
    Write-Host "   Students:  $($report.students.total)" -ForegroundColor White
    Write-Host ""
    
    # Porcentajes
    Write-Host "   📊 COMPLIANCE:" -ForegroundColor White
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    $complianceBar = "█" * [Math]::Round($report.compliance.percentage / 2)
    $missingBar = "█" * [Math]::Round($report.compliance.missing_percentage / 2)
    
    Write-Host "   Compliance:  |" -NoNewline -ForegroundColor White
    Write-Host $complianceBar -NoNewline -ForegroundColor Green
    Write-Host "| $($report.compliance.percentage)%" -ForegroundColor Green
    
    Write-Host "   Missing:     |" -NoNewline -ForegroundColor White
    Write-Host $missingBar -NoNewline -ForegroundColor Red
    Write-Host "| $($report.compliance.missing_percentage)%" -ForegroundColor Red
    Write-Host ""
    
    # Indicadores - Assessment
    Write-Host "   📋 ASSESSMENT STATUS:" -ForegroundColor White
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   Assesment Description:  Ok" -ForegroundColor Green
    Write-Host ""
    Write-Host "   ID Performance Indicator:" -ForegroundColor White
    
    foreach ($indicator in $report.indicators) {
        $statusColor = if ($indicator.assessment_status -eq "Ok") { "Green" } else { "Yellow" }
        $statusIcon = if ($indicator.assessment_status -eq "Ok") { "✓" } else { "⚠" }
        
        Write-Host "      $statusIcon Indicator $($indicator.indicator): " -NoNewline -ForegroundColor $statusColor
        Write-Host "$($indicator.assessment_status)" -ForegroundColor $statusColor
    }
    Write-Host ""
    
    # Indicadores - Students
    Write-Host "   👥 STUDENTS STATUS:" -ForegroundColor White
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   Performance Indicator:" -ForegroundColor White
    
    foreach ($indicator in $report.indicators) {
        $statusColor = if ($indicator.student_status -eq "Ok") { "Green" } else { "Yellow" }
        $statusIcon = if ($indicator.student_status -eq "Ok") { "✓" } else { "⚠" }
        
        Write-Host "      $statusIcon Indicator $($indicator.indicator): " -NoNewline -ForegroundColor $statusColor
        Write-Host "$($indicator.student_status)" -ForegroundColor $statusColor
    }
    Write-Host ""
    
    # Mejora continua
    Write-Host "   🔄 CONTINUOUS IMPROVEMENT:" -ForegroundColor White
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   ✓ Activities Applied:  $($report.continuous_improvement.activities_applied)" -ForegroundColor Green
    Write-Host "   ✓ Current Results:     $($report.continuous_improvement.current_results)" -ForegroundColor Green
    Write-Host "   ✓ Actions Proposed:    $($report.continuous_improvement.actions_proposed)" -ForegroundColor Green
    Write-Host ""
    
    # Tipo de evaluación
    Write-Host "   📝 TYPE OF ASSESSMENT:" -ForegroundColor White
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   $($report.students.type_of_assessment)" -ForegroundColor White
    Write-Host "   Total Students: $($report.students.total)" -ForegroundColor White
    Write-Host ""
    
    # Detalle de evaluaciones por indicador
    Write-Host "   📊 EVALUATION DETAILS:" -ForegroundColor White
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   Indicator | E | G | F | I | Total" -ForegroundColor White
    Write-Host "   ──────────┼───┼───┼───┼───┼──────" -ForegroundColor Gray
    
    foreach ($indicator in $report.indicators) {
        $ev = $indicator.evaluations
        $line = "      {0,-3}    | {1,-1} | {2,-1} | {3,-1} | {4,-1} | {5}" -f `
            $indicator.indicator, $ev.E, $ev.G, $ev.F, $ev.I, $ev.total
        
        # Colorear según rendimiento
        $eg_percentage = if ($ev.total -gt 0) { (($ev.E + $ev.G) / $ev.total) * 100 } else { 0 }
        if ($eg_percentage -ge 70) {
            Write-Host $line -ForegroundColor Green
        } elseif ($eg_percentage -ge 50) {
            Write-Host $line -ForegroundColor Yellow
        } else {
            Write-Host $line -ForegroundColor Red
        }
    }
    Write-Host ""
    
    # JSON completo
    Write-Host "   📄 FULL JSON RESPONSE:" -ForegroundColor Cyan
    Write-Host ($report | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Comparar todos los outcomes
Write-Host "4️⃣  Reportes de todos los outcomes..." -ForegroundColor Yellow
foreach ($outcome in $outcomes) {
    try {
        $rpt = Invoke-RestMethod -Uri "$API_URL/api/outcome-report/$($outcome.id)" -Headers $headers
        
        Write-Host "   ✅ $($outcome.so_number): " -NoNewline -ForegroundColor Green
        Write-Host "Compliance: $($rpt.compliance.percentage)%, " -NoNewline -ForegroundColor Cyan
        Write-Host "Students: $($rpt.students.total), " -NoNewline -ForegroundColor Cyan
        Write-Host "Indicators: $($rpt.indicators.Count)" -ForegroundColor Cyan
    } catch {
        Write-Host "   ❌ $($outcome.so_number): Error" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 USO DEL ENDPOINT:" -ForegroundColor Yellow
Write-Host "   GET /api/outcome-report/{outcome_id}" -ForegroundColor White
Write-Host ""
Write-Host "📊 DATOS DEVUELTOS:" -ForegroundColor Yellow
Write-Host "   - outcome_id, so_number, title" -ForegroundColor White
Write-Host "   - course: code, name, professor" -ForegroundColor White
Write-Host "   - programs: array de programas" -ForegroundColor White
Write-Host "   - students: total, type_of_assessment" -ForegroundColor White
Write-Host "   - compliance: percentage, missing_percentage" -ForegroundColor White
Write-Host "   - indicators: array con estado y evaluaciones" -ForegroundColor White
Write-Host "   - continuous_improvement: actividades, resultados, acciones" -ForegroundColor White
Write-Host ""
Write-Host "🎨 USAR EN FRONTEND:" -ForegroundColor Yellow
Write-Host "   - Generar reportes PDF/Excel" -ForegroundColor White
Write-Host "   - Crear dashboards completos" -ForegroundColor White
Write-Host "   - Mostrar Student Outcome Reports" -ForegroundColor White
Write-Host ""
