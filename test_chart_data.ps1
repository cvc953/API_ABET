# Script para probar el endpoint de datos del gráfico
# Ejecutar: .\test_chart_data.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST: Chart Data - E+G Level Percentage" -ForegroundColor Cyan
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

# Test 3: Obtener datos del gráfico
Write-Host "3️⃣  Obteniendo datos del gráfico (GET /api/outcome-chart/$outcomeId)" -ForegroundColor Yellow
try {
    $chartData = Invoke-RestMethod -Uri "$API_URL/api/outcome-chart/$outcomeId" -Headers $headers
    
    Write-Host "   ✅ Datos del gráfico obtenidos" -ForegroundColor Green
    Write-Host ""
    Write-Host "   📊 $($chartData.title)" -ForegroundColor Cyan
    Write-Host "   Outcome: $($chartData.so_number)" -ForegroundColor Cyan
    Write-Host "   ============================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($chartData.chart_data.Count -eq 0) {
        Write-Host "   ℹ️  No hay datos para este outcome" -ForegroundColor Yellow
    } else {
        # Mostrar gráfico de barras en consola
        Write-Host "   📈 GRÁFICO DE BARRAS:" -ForegroundColor White
        Write-Host ""
        
        $maxPercentage = 100
        $barWidth = 50  # Caracteres de ancho para 100%
        
        foreach ($item in $chartData.chart_data) {
            $indicator = $item.indicator
            $percentage = $item.percentage_eg
            $count = $item.count_eg
            $total = $item.total
            
            # Calcular longitud de la barra
            $barLength = [Math]::Round(($percentage / $maxPercentage) * $barWidth)
            $bar = "█" * $barLength
            
            # Formatear la línea
            $label = "   Indicator $indicator"
            $percentageText = "$percentage%"
            $countText = "($count/$total)"
            
            # Mostrar la barra
            Write-Host $label -NoNewline -ForegroundColor White
            Write-Host " |" -NoNewline -ForegroundColor Gray
            Write-Host $bar -NoNewline -ForegroundColor Blue
            Write-Host " $percentageText $countText" -ForegroundColor Cyan
        }
        
        Write-Host ""
        Write-Host "   " + ("─" * 80) -ForegroundColor Gray
        Write-Host "   0%                    25%                   50%                   75%                  100%" -ForegroundColor Gray
        Write-Host ""
        
        # Mostrar tabla de datos
        Write-Host "   📋 DATOS DETALLADOS:" -ForegroundColor White
        Write-Host ""
        Write-Host "   Indicator | E+G Count | Total | Percentage" -ForegroundColor White
        Write-Host "   " + ("─" * 50) -ForegroundColor Gray
        
        foreach ($item in $chartData.chart_data) {
            $line = "   {0,-9} | {1,-9} | {2,-5} | {3}%" -f $item.indicator, $item.count_eg, $item.total, $item.percentage_eg
            
            # Colorear según el porcentaje
            if ($item.percentage_eg -ge 70) {
                Write-Host $line -ForegroundColor Green
            } elseif ($item.percentage_eg -ge 50) {
                Write-Host $line -ForegroundColor Yellow
            } else {
                Write-Host $line -ForegroundColor Red
            }
        }
        
        Write-Host ""
        
        # Mostrar JSON completo
        Write-Host "   📄 RESPUESTA JSON:" -ForegroundColor Cyan
        Write-Host ($chartData | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    }
    
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Comparar con todos los outcomes
Write-Host "4️⃣  Comparando todos los outcomes..." -ForegroundColor Yellow
foreach ($outcome in $outcomes) {
    try {
        $data = Invoke-RestMethod -Uri "$API_URL/api/outcome-chart/$($outcome.id)" -Headers $headers
        
        if ($data.chart_data.Count -gt 0) {
            $avgPercentage = ($data.chart_data | Measure-Object -Property percentage_eg -Average).Average
            Write-Host "   ✅ $($outcome.so_number): Promedio E+G = $([Math]::Round($avgPercentage))%" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  $($outcome.so_number): Sin datos" -ForegroundColor Yellow
        }
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
Write-Host "   GET /api/outcome-chart/{outcome_id}" -ForegroundColor White
Write-Host ""
Write-Host "📊 DATOS DEVUELTOS:" -ForegroundColor Yellow
Write-Host "   - outcome_id: ID del outcome" -ForegroundColor White
Write-Host "   - so_number: Número del outcome" -ForegroundColor White
Write-Host "   - title: Título del gráfico" -ForegroundColor White
Write-Host "   - chart_data: Array de datos por indicador" -ForegroundColor White
Write-Host "     - indicator: Letra del indicador" -ForegroundColor White
Write-Host "     - percentage_eg: Porcentaje que alcanzó E+G" -ForegroundColor White
Write-Host "     - count_eg: Cantidad de estudiantes E+G" -ForegroundColor White
Write-Host "     - total: Total de evaluaciones" -ForegroundColor White
Write-Host ""
Write-Host "🎨 USAR EN FRONTEND:" -ForegroundColor Yellow
Write-Host "   - Chart.js, D3.js, Plotly, etc." -ForegroundColor White
Write-Host "   - Usar 'indicator' como eje X" -ForegroundColor White
Write-Host "   - Usar 'percentage_eg' como eje Y" -ForegroundColor White
Write-Host ""
