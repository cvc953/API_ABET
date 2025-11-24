# Ejemplos de uso de los endpoints de Performance Indicators

## 📋 Endpoints CRUD Implementados

### 1. **POST /api/indicators** - Crear nuevo indicador

```bash
curl -X POST "http://localhost:8000/api/indicators" \
  -H "X-API-Key: tu_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "student_outcome_id": 1,
    "indicator_letter": "d",
    "description_en": "Demonstrates ability to identify engineering problems",
    "description_es": "Demuestra capacidad para identificar problemas de ingeniería"
  }'
```

**PowerShell:**
```powershell
$headers = @{"X-API-Key"="tu_api_key"; "Content-Type"="application/json"}
$body = @{
    student_outcome_id = 1
    indicator_letter = "d"
    description_en = "Demonstrates ability to identify engineering problems"
    description_es = "Demuestra capacidad para identificar problemas de ingeniería"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8000/api/indicators" -Method POST -Headers $headers -Body $body
```

**Respuesta (201 Created):**
```json
{
  "id": 10,
  "student_outcome_id": 1,
  "indicator_letter": "d",
  "description": "Demuestra capacidad para identificar problemas de ingeniería"
}
```

---

### 2. **GET /api/indicators/{outcome_id}** - Listar indicadores de un outcome

```bash
curl -H "X-API-Key: tu_api_key" http://localhost:8000/api/indicators/1
```

**PowerShell:**
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators/1" -Headers $headers
```

**Respuesta (200 OK):**
```json
[
  {
    "id": 1,
    "student_outcome_id": 1,
    "indicator_letter": "a",
    "description": "Identifica el problema de ingeniería..."
  },
  {
    "id": 2,
    "student_outcome_id": 1,
    "indicator_letter": "b",
    "description": "Formula el problema correctamente..."
  }
]
```

---

### 3. **PUT /api/indicators/{id}** - Actualizar indicador

```bash
curl -X PUT "http://localhost:8000/api/indicators/10" \
  -H "X-API-Key: tu_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "description_es": "Nueva descripción actualizada en español"
  }'
```

**PowerShell:**
```powershell
$headers = @{"X-API-Key"="tu_api_key"; "Content-Type"="application/json"}
$body = @{
    description_es = "Nueva descripción actualizada en español"
    description_en = "New updated description in English"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8000/api/indicators/10" -Method PUT -Headers $headers -Body $body
```

**Respuesta (200 OK):**
```json
{
  "id": 10,
  "student_outcome_id": 1,
  "indicator_letter": "d",
  "description": "Nueva descripción actualizada en español"
}
```

---

### 4. **DELETE /api/indicators/{id}** - Eliminar indicador

```bash
curl -X DELETE "http://localhost:8000/api/indicators/10" \
  -H "X-API-Key: tu_api_key"
```

**PowerShell:**
```powershell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators/10" -Method DELETE -Headers $headers
```

**Respuesta (204 No Content):**
```
(Sin contenido - eliminación exitosa)
```

---

## 🛡️ Validaciones Implementadas

### Crear Indicador (POST)
- ✅ **Verifica que el outcome existe** (404 si no existe)
- ✅ **No permite duplicados** (409 si ya existe indicador con misma letra para ese outcome)
- ✅ **Campos requeridos**: `student_outcome_id`, `indicator_letter`, `description_en`, `description_es`

### Actualizar Indicador (PUT)
- ✅ **Verifica que el indicador existe** (404 si no existe)
- ✅ **Actualización parcial**: puedes actualizar solo los campos que necesites
- ✅ **Campos opcionales**: `indicator_letter`, `description_en`, `description_es`

### Eliminar Indicador (DELETE)
- ✅ **Verifica que el indicador existe** (404 si no existe)
- ✅ **No permite eliminar si tiene niveles asociados** (409 Conflict)
- ✅ **No permite eliminar si tiene evaluaciones asociadas** (409 Conflict)

---

## ❌ Códigos de Error

| Código | Descripción | Cuándo ocurre |
|--------|-------------|---------------|
| **201** | Created | Indicador creado exitosamente |
| **200** | OK | Operación exitosa (GET, PUT) |
| **204** | No Content | Eliminación exitosa |
| **404** | Not Found | Indicador u outcome no encontrado |
| **409** | Conflict | Indicador duplicado o tiene datos asociados |
| **422** | Unprocessable Entity | Datos inválidos (ej: ID no es número) |
| **403** | Forbidden | API Key inválida o faltante |
| **500** | Internal Server Error | Error de base de datos |

---

## 🧪 Prueba Rápida

**Script automatizado:**
```powershell
.\test_indicators_crud.ps1
```

**Swagger UI (interfaz interactiva):**
```
http://localhost:8000/docs
```

---

## 📊 Estructura de la Tabla

**mdl_gradingform_utb_indicators:**
```
- id (int, PK, auto_increment)
- student_outcome_id (int, FK)
- indicator_letter (varchar)
- description_en (text)
- description_es (text)
- timecreated (int, timestamp)
- timemodified (int, timestamp)
```

---

## 💡 Ejemplos Completos

### Crear varios indicadores para un outcome

```powershell
$headers = @{"X-API-Key"="tu_api_key"; "Content-Type"="application/json"}

# Indicador a
$bodyA = @{
    student_outcome_id = 1
    indicator_letter = "a"
    description_en = "Identifies engineering problems"
    description_es = "Identifica problemas de ingeniería"
} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators" -Method POST -Headers $headers -Body $bodyA

# Indicador b
$bodyB = @{
    student_outcome_id = 1
    indicator_letter = "b"
    description_en = "Formulates engineering problems"
    description_es = "Formula problemas de ingeniería"
} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators" -Method POST -Headers $headers -Body $bodyB

# Indicador c
$bodyC = @{
    student_outcome_id = 1
    indicator_letter = "c"
    description_en = "Solves engineering problems"
    description_es = "Resuelve problemas de ingeniería"
} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators" -Method POST -Headers $headers -Body $bodyC
```

### Actualizar solo la descripción en inglés

```powershell
$headers = @{"X-API-Key"="tu_api_key"; "Content-Type"="application/json"}
$body = @{
    description_en = "Updated English description only"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8000/api/indicators/1" -Method PUT -Headers $headers -Body $body
```
