# 📖 API de Solo Lectura - Endpoints GET Disponibles

## ✅ API Configurada Como Solo Lectura

La API ahora **solo acepta peticiones GET** (read-only). No hay endpoints POST, PUT, DELETE o PATCH.

---

## 🔍 Endpoints Disponibles

### 1. **GET /health**
- **Descripción**: Estado de salud de la API y conexión a BD
- **Autenticación**: No requerida
- **Ejemplo**:
```powershell
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET
```

---

### 2. **GET /api/outcomes**
- **Descripción**: Listar todos los Student Outcomes
- **Autenticación**: Requerida (X-API-Key)
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/outcomes" -Headers $headers
```
- **Respuesta**:
```json
[
  {
    "id": 1,
    "so_number": "SO1",
    "description": "Identifica problemas de ingeniería..."
  }
]
```

---

### 3. **GET /api/indicators/{outcome_id}**
- **Descripción**: Listar todos los Performance Indicators de un outcome
- **Autenticación**: Requerida (X-API-Key)
- **Parámetros**: 
  - `outcome_id` - ID del outcome (acepta formato con o sin llaves)
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators/1" -Headers $headers
```
- **Respuesta**:
```json
[
  {
    "id": 1,
    "student_outcome_id": 1,
    "indicator_letter": "a",
    "description": "Identifica el problema..."
  }
]
```

---

### 4. **GET /api/levels/{indicator_id}**
- **Descripción**: Listar todos los Performance Levels de un indicador
- **Autenticación**: Requerida (X-API-Key)
- **Parámetros**: 
  - `indicator_id` - ID del indicador (acepta formato con o sin llaves)
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/levels/1" -Headers $headers
```
- **Respuesta**:
```json
[
  {
    "id": 1,
    "indicator_id": 1,
    "title": "Excelente",
    "description": "Establece todas las ecuaciones...",
    "minscore": 4.5,
    "maxscore": 5.0
  }
]
```

---

### 5. **GET /api/evaluations/{student_id}**
- **Descripción**: Listar todas las evaluaciones de un estudiante
- **Autenticación**: Requerida (X-API-Key)
- **Parámetros**: 
  - `student_id` - ID del estudiante (número entero)
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/evaluations/1" -Headers $headers
```
- **Respuesta**:
```json
[
  {
    "id": 1,
    "instanceid": 100,
    "studentid": 1,
    "courseid": 5,
    "activityid": 10,
    "activityname": "Quiz Final",
    "student_outcome_id": 1,
    "indicator_id": 2,
    "performance_level_id": 5,
    "score": 4.75,
    "feedback": "Excelente trabajo",
    "timecreated": 1760308621,
    "timemodified": 1760308621
  }
]
```

---

### 6. **GET /api/outcome-summary/{outcome_id}**
- **Descripción**: Obtener resumen completo de un outcome con sus indicadores y niveles
- **Autenticación**: Requerida (X-API-Key)
- **Parámetros**: 
  - `outcome_id` - ID del outcome
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/outcome-summary/1" -Headers $headers
```
- **Respuesta**:
```json
{
  "id": 1,
  "so_number": "SO1",
  "description_es": "...",
  "indicators": [
    {
      "id": 1,
      "indicator_letter": "a",
      "description_es": "...",
      "levels": [
        {
          "id": 1,
          "title_es": "Excelente",
          "minscore": 4.5,
          "maxscore": 5.0
        }
      ]
    }
  ]
}
```

---

## 🔒 Seguridad

- **API Key**: Requerida para todos los endpoints excepto `/health`
- **Header requerido**: `X-API-Key: tu_api_key`
- **Configuración**: Define `API_KEY` en tu archivo `.env`
- **Modo desarrollo**: Si no hay `API_KEY` configurada, permite acceso sin autenticación

---

## 🌐 CORS

La API está configurada para:
- **Métodos permitidos**: Solo `GET`
- **Orígenes**: Configurables via `ALLOWED_ORIGINS` en `.env`

---

## 📊 Swagger UI

Documentación interactiva disponible en:
```
http://localhost:8000/docs
```

---

## 🧪 Probar Todos los Endpoints

### Script de prueba completo:

```powershell
$API_URL = "http://localhost:8000"
$API_KEY = "tu_api_key"
$headers = @{"X-API-Key"=$API_KEY}

# 1. Health check
Invoke-RestMethod -Uri "$API_URL/health" -Method GET

# 2. Outcomes
$outcomes = Invoke-RestMethod -Uri "$API_URL/api/outcomes" -Headers $headers
Write-Host "Outcomes: $($outcomes.Count)"

# 3. Indicators (usando primer outcome)
$outcomeId = $outcomes[0].id
$indicators = Invoke-RestMethod -Uri "$API_URL/api/indicators/$outcomeId" -Headers $headers
Write-Host "Indicators: $($indicators.Count)"

# 4. Levels (usando primer indicador)
if ($indicators.Count -gt 0) {
    $indicatorId = $indicators[0].id
    $levels = Invoke-RestMethod -Uri "$API_URL/api/levels/$indicatorId" -Headers $headers
    Write-Host "Levels: $($levels.Count)"
}

# 5. Evaluations (estudiante con ID 1)
$evals = Invoke-RestMethod -Uri "$API_URL/api/evaluations/1" -Headers $headers
Write-Host "Evaluations: $($evals.Count)"

# 6. Outcome Summary
$summary = Invoke-RestMethod -Uri "$API_URL/api/outcome-summary/$outcomeId" -Headers $headers
Write-Host "Summary for outcome: $($summary.so_number)"
```

---

### 7. **GET /api/outcome-assessment/{outcome_id}**
- **Descripción**: Obtener estadísticas de evaluación directa agrupadas por nivel de desempeño (E, G, F, I)
- **Autenticación**: Requerida (X-API-Key)
- **Parámetros**: 
  - `outcome_id` - ID del outcome
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/outcome-assessment/1" -Headers $headers
```
- **Respuesta**:
```json
{
  "outcome_id": 1,
  "so_number": "SO1",
  "indicators": [
    {
      "indicator": "a",
      "indicator_id": 1,
      "total_evaluations": 13,
      "levels": {
        "E": {"count": 8, "percentage": 62},
        "G": {"count": 5, "percentage": 38},
        "F": {"count": 0, "percentage": 0},
        "I": {"count": 0, "percentage": 0}
      },
      "summary": {
        "E_plus_G": {"count": 13, "percentage": 100},
        "F_plus_I": {"count": 0, "percentage": 0}
      }
    },
    {
      "indicator": "b",
      "indicator_id": 2,
      "total_evaluations": 13,
      "levels": {
        "E": {"count": 0, "percentage": 0},
        "G": {"count": 8, "percentage": 62},
        "F": {"count": 5, "percentage": 38},
        "I": {"count": 0, "percentage": 0}
      },
      "summary": {
        "E_plus_G": {"count": 8, "percentage": 62},
        "F_plus_I": {"count": 5, "percentage": 38}
      }
    }
  ]
}
```

**Uso**: Este endpoint genera automáticamente la tabla de "Direct Assessment of Student Outcome" que agrupa las evaluaciones por nivel de desempeño (Excellent, Good, Fair, Inadequate) para cada indicador, similar a la imagen proporcionada.

---

### 8. **GET /api/outcome-chart/{outcome_id}**
- **Descripción**: Obtener datos para gráfico de barras con porcentaje E+G por indicador
- **Autenticación**: Requerida (X-API-Key)
- **Parámetros**: 
  - `outcome_id` - ID del outcome
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/outcome-chart/1" -Headers $headers
```
- **Respuesta**:
```json
{
  "outcome_id": 1,
  "so_number": "SO1",
  "title": "Percentage of student relates can attained E+G Level",
  "chart_data": [
    {
      "indicator": "a",
      "indicator_id": 1,
      "percentage_eg": 100,
      "count_eg": 13,
      "total": 13
    },
    {
      "indicator": "b",
      "indicator_id": 2,
      "percentage_eg": 62,
      "count_eg": 8,
      "total": 13
    }
  ]
}
```

**Uso**: Este endpoint genera los datos para el gráfico de barras que muestra el porcentaje de estudiantes que alcanzaron nivel E+G (Excellent + Good) por indicador. Ideal para visualizaciones con Chart.js, D3.js, etc.

---

### 9. **GET /api/outcome-report/{outcome_id}** ✨ NUEVO
- **Descripción**: Obtener reporte completo del Student Outcome (formato ABET)
- **Autenticación**: Requerida (X-API-Key)
- **Parámetros**: 
  - `outcome_id` - ID del outcome
- **Ejemplo**:
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/outcome-report/1" -Headers $headers
```
- **Respuesta**:
```json
{
  "outcome_id": 1,
  "so_number": "SO-2",
  "title": "Outcome Title",
  "course": {
    "code": "IAMB-A09A",
    "name": "TRATAMIENTO DE AGUA / PROCESOS UNITARIOS",
    "professor": "PASQUALINO JORGELINA"
  },
  "programs": ["IAMB"],
  "students": {
    "total": 14,
    "type_of_assessment": "Continuous Assessment"
  },
  "compliance": {
    "percentage": 73,
    "missing_percentage": 27
  },
  "indicators": [
    {
      "indicator": "a",
      "indicator_id": 1,
      "title": "Indicator Title",
      "assessment_status": "Ok",
      "student_status": "Pendiente",
      "evaluations": {
        "E": 2,
        "G": 8,
        "F": 3,
        "I": 1,
        "total": 14
      }
    }
  ],
  "continuous_improvement": {
    "activities_applied": "Ok",
    "current_results": "Ok",
    "actions_proposed": "Ok"
  }
}
```

**Uso**: Este endpoint genera el reporte completo del Student Outcome con toda la información necesaria para generar el documento oficial (estilo ABET). Incluye:
- Información del curso y profesor
- Porcentajes de cumplimiento (compliance) y faltante (missing)
- Estado de evaluación (assessment_status) y estudiantes (student_status) por indicador
- Detalle de evaluaciones E/G/F/I por indicador
- Estado de mejora continua (continuous improvement)

---

## 🚫 Métodos NO Permitidos

Los siguientes métodos HTTP **no están disponibles**:
- ❌ POST (crear)
- ❌ PUT (actualizar)
- ❌ DELETE (eliminar)
- ❌ PATCH (actualizar parcialmente)

Cualquier intento de usar estos métodos devolverá **405 Method Not Allowed**.

---

## 📝 Resumen

| Endpoint | Método | Autenticación | Descripción |
|----------|--------|---------------|-------------|
| `/health` | GET | No | Estado de la API |
| `/api/outcomes` | GET | Sí | Listar outcomes |
| `/api/indicators/{outcome_id}` | GET | Sí | Listar indicadores |
| `/api/levels/{indicator_id}` | GET | Sí | Listar niveles |
| `/api/evaluations/{student_id}` | GET | Sí | Listar evaluaciones |
| `/api/outcome-summary/{outcome_id}` | GET | Sí | Resumen completo |
| `/api/outcome-assessment/{outcome_id}` | GET | Sí | Estadísticas por nivel (E,G,F,I) |
| `/api/outcome-chart/{outcome_id}` | GET | Sí | Datos para gráfico E+G |
| `/api/outcome-report/{outcome_id}` | GET | Sí | Reporte completo (ABET) ✨ |

**Total de endpoints**: 9 (todos GET - solo lectura)
