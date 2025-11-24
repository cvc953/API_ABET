# Script para probar CRUD de Performance Indicators
# Ejecutar: .\test_indicators_crud.ps1

$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key_aqui"  # Cambiar por tu API key

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST: CRUD Performance Indicators" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Configurar headers
$headers = @{
    "X-API-Key" = $API_KEY
    "Content-Type" = "application/json"
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

# Test 2: Obtener un outcome para usar en las pruebas
Write-Host "2️⃣  Obteniendo outcomes disponibles..." -ForegroundColor Yellow
try {
    $outcomes = Invoke-RestMethod -Uri "$API_URL/api/outcomes" -Method GET -Headers $headers
    
    if ($outcomes.Count -gt 0) {
        $outcomeId = $outcomes[0].id
        Write-Host "   ✅ Usando Outcome ID: $outcomeId ($($outcomes[0].so_number))" -ForegroundColor Green
    } else {
        Write-Host "   ❌ No hay outcomes en la BD" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ❌ Error al obtener outcomes" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 3: Crear un nuevo indicador (POST)
Write-Host "3️⃣  Crear nuevo indicador (POST /api/indicators)" -ForegroundColor Yellow
$newIndicator = @{
    student_outcome_id = $outcomeId
    indicator_letter = "z"  # Usar letra poco común para evitar conflictos
    description_en = "Test indicator - Demonstrates ability to solve complex problems"
    description_es = "Indicador de prueba - Demuestra capacidad para resolver problemas complejos"
} | ConvertTo-Json

try {
    $created = Invoke-RestMethod -Uri "$API_URL/api/indicators" -Method POST -Headers $headers -Body $newIndicator
    Write-Host "   ✅ Indicador creado:" -ForegroundColor Green
    Write-Host "      - ID: $($created.id)" -ForegroundColor White
    Write-Host "      - Letra: $($created.indicator_letter)" -ForegroundColor White
    Write-Host "      - Descripción: $($created.description)" -ForegroundColor White
    
    $createdId = $created.id
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "   ❌ Error $statusCode" -ForegroundColor Red
    
    if ($statusCode -eq 409) {
        Write-Host "   ⚠️  El indicador ya existe (conflicto)" -ForegroundColor Yellow
        Write-Host "   💡 Prueba cambiando la 'indicator_letter' en el script" -ForegroundColor Yellow
    } else {
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    }
    $createdId = $null
}
Write-Host ""

# Test 4: Leer el indicador creado (GET)
if ($createdId) {
    Write-Host "4️⃣  Leer indicadores del outcome (GET /api/indicators/$outcomeId)" -ForegroundColor Yellow
    try {
        $indicators = Invoke-RestMethod -Uri "$API_URL/api/indicators/$outcomeId" -Method GET -Headers $headers
        $found = $indicators | Where-Object { $_.id -eq $createdId }
        
        if ($found) {
            Write-Host "   ✅ Indicador encontrado en la lista" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Indicador no encontrado en la lista" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ Error al leer indicadores" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 5: Actualizar el indicador (PUT)
if ($createdId) {
    Write-Host "5️⃣  Actualizar indicador (PUT /api/indicators/$createdId)" -ForegroundColor Yellow
    $updateData = @{
        description_es = "Indicador ACTUALIZADO - Nueva descripción en español"
    } | ConvertTo-Json
    
    try {
        $updated = Invoke-RestMethod -Uri "$API_URL/api/indicators/$createdId" -Method PUT -Headers $headers -Body $updateData
        Write-Host "   ✅ Indicador actualizado:" -ForegroundColor Green
        Write-Host "      - ID: $($updated.id)" -ForegroundColor White
        Write-Host "      - Nueva descripción: $($updated.description)" -ForegroundColor White
    } catch {
        Write-Host "   ❌ Error al actualizar: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 6: Intentar crear duplicado (debería fallar con 409)
Write-Host "6️⃣  Intentar crear indicador duplicado (debería fallar)" -ForegroundColor Yellow
try {
    $duplicate = Invoke-RestMethod -Uri "$API_URL/api/indicators" -Method POST -Headers $headers -Body $newIndicator
    Write-Host "   ⚠️  No debería haber permitido crear duplicado" -ForegroundColor Yellow
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 409) {
        Write-Host "   ✅ Correctamente rechazado (409 Conflict)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Error inesperado: $statusCode" -ForegroundColor Red
    }
}
Write-Host ""

# Test 7: Eliminar el indicador (DELETE)
if ($createdId) {
    Write-Host "7️⃣  Eliminar indicador (DELETE /api/indicators/$createdId)" -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "$API_URL/api/indicators/$createdId" -Method DELETE -Headers $headers
        Write-Host "   ✅ Indicador eliminado correctamente (204 No Content)" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        if ($statusCode -eq 409) {
            Write-Host "   ⚠️  No se puede eliminar: tiene niveles o evaluaciones asociadas" -ForegroundColor Yellow
            Write-Host "   💡 Elimina primero los niveles y evaluaciones asociadas" -ForegroundColor Yellow
        } else {
            Write-Host "   ❌ Error al eliminar: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Test 8: Verificar que fue eliminado
if ($createdId) {
    Write-Host "8️⃣  Verificar eliminación (GET /api/indicators/$outcomeId)" -ForegroundColor Yellow
    try {
        $indicators = Invoke-RestMethod -Uri "$API_URL/api/indicators/$outcomeId" -Method GET -Headers $headers
        $found = $indicators | Where-Object { $_.id -eq $createdId }
        
        if (-not $found) {
            Write-Host "   ✅ Indicador eliminado correctamente (no aparece en la lista)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  El indicador todavía existe" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ Error al verificar" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 ENDPOINTS DISPONIBLES:" -ForegroundColor Yellow
Write-Host "   POST   /api/indicators              - Crear indicador" -ForegroundColor White
Write-Host "   GET    /api/indicators/{outcome_id} - Listar indicadores" -ForegroundColor White
Write-Host "   PUT    /api/indicators/{id}         - Actualizar indicador" -ForegroundColor White
Write-Host "   DELETE /api/indicators/{id}         - Eliminar indicador" -ForegroundColor White
Write-Host ""
Write-Host "💡 VALIDACIONES IMPLEMENTADAS:" -ForegroundColor Yellow
Write-Host "   ✅ No permite indicadores duplicados (letra + outcome)" -ForegroundColor White
Write-Host "   ✅ Verifica que el outcome existe antes de crear" -ForegroundColor White
Write-Host "   ✅ No permite eliminar si tiene niveles asociados" -ForegroundColor White
Write-Host "   ✅ No permite eliminar si tiene evaluaciones asociadas" -ForegroundColor White
Write-Host ""
