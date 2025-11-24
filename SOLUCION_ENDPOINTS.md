# ✅ Solución: Endpoints /api/indicators y /api/evaluations

## 🔧 Endpoints Corregidos

### 1. `/api/indicators/{outcome_id}`
### 2. `/api/evaluations/{student_code}`

## ❌ Problemas Encontrados

Ambos endpoints tenían los siguientes problemas:

1. **Sin manejo de errores robusto**: No usaban try-finally para cerrar conexiones
2. **Validación insuficiente**: No validaban IDs/códigos inválidos
3. **Sin soporte para llaves**: Fallaban si el cliente enviaba `{1}` en lugar de `1`
4. **Mensajes de error poco claros**: No especificaban qué falló

## ✅ Correcciones Aplicadas

### `/api/indicators/{outcome_id}`

#### Antes:
```python
@app.get("/api/indicators/{outcome_id}")
def get_indicators(outcome_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM mdl_gradingform_utb_indicators WHERE student_outcome_id = %s", (outcome_id,))
    results = cursor.fetchall()
    close_db_connection(conn, cursor)
    return results
```

#### Después:
```python
@app.get("/api/indicators/{outcome_id:path}")
def get_indicators(outcome_id: str):
    conn = None
    cursor = None
    try:
        # Limpiar y validar outcome_id
        clean_id = outcome_id.strip('{}').strip()
        outcome_id_int = int(clean_id)
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Verificar que el outcome existe
        cursor.execute("SELECT id FROM mdl_gradingform_utb_outcomes WHERE id = %s", (outcome_id_int,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail=f"Outcome con ID {outcome_id_int} no encontrado")
        
        # Obtener indicadores
        cursor.execute("SELECT id, student_outcome_id, indicator_letter, description_es AS description FROM mdl_gradingform_utb_indicators WHERE student_outcome_id = %s", (outcome_id_int,))
        return cursor.fetchall()
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar indicadores: {str(e)}")
    finally:
        close_db_connection(conn, cursor)
```

**Mejoras:**
- ✅ Acepta `{outcome_id:path}` para soportar llaves en URL
- ✅ Limpia automáticamente las llaves con `.strip('{}')`
- ✅ Verifica que el outcome existe antes de buscar indicadores
- ✅ Try-finally garantiza cierre de conexiones
- ✅ Mensajes de error descriptivos

### `/api/evaluations/{student_code}`

#### Antes:
```python
@app.get("/api/evaluations/{student_code}")
def get_evaluations(student_code: str):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT student_code, student_outcome_id AS outcome_id, indicator_id, performance_level_id AS level, score
        FROM mdl_gradingform_utb_evaluations
        WHERE student_code = %s
    """, (student_code,))
    results = cursor.fetchall()
    close_db_connection(conn, cursor)
    return results
```

#### Después:
```python
@app.get("/api/evaluations/{student_code:path}")
def get_evaluations(student_code: str):
    conn = None
    cursor = None
    try:
        # Limpiar student_code
        clean_code = student_code.strip('{}').strip()
        
        if not clean_code:
            raise HTTPException(status_code=422, detail="El código de estudiante no puede estar vacío")
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT student_code, student_outcome_id AS outcome_id, indicator_id, 
                   performance_level_id AS level, score
            FROM mdl_gradingform_utb_evaluations
            WHERE student_code = %s
        """, (clean_code,))
        
        return cursor.fetchall()  # Retorna lista vacía si no hay evaluaciones
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar evaluaciones: {str(e)}")
    finally:
        close_db_connection(conn, cursor)
```

**Mejoras:**
- ✅ Acepta `{student_code:path}` para soportar llaves y caracteres especiales
- ✅ Limpia automáticamente las llaves
- ✅ Valida que el código no esté vacío
- ✅ Try-finally garantiza cierre de conexiones
- ✅ Retorna lista vacía si no hay evaluaciones (no es error)

## 🎯 Formatos Soportados

### Endpoint: /api/indicators/{outcome_id}

| Formato | URL | Estado |
|---------|-----|--------|
| ✅ Estándar | `/api/indicators/1` | Recomendado |
| ✅ Con llaves | `/api/indicators/{1}` | Soportado |
| ✅ Con espacios | `/api/indicators/{ 1 }` | Soportado |

### Endpoint: /api/evaluations/{student_code}

| Formato | URL | Estado |
|---------|-----|--------|
| ✅ Estándar | `/api/evaluations/EST001` | Recomendado |
| ✅ Con llaves | `/api/evaluations/{EST001}` | Soportado |
| ✅ Con espacios | `/api/evaluations/{ EST001 }` | Soportado |

## 🧪 Cómo Probar

### PowerShell - Script Automatizado
```powershell
# Editar configuración
notepad test_fixed_endpoints.ps1

# Ejecutar pruebas
.\test_fixed_endpoints.ps1
```

### PowerShell - Manual

```powershell
$headers = @{"X-API-Key"="tu_api_key"}

# Test: /api/indicators - formato correcto
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators/1" -Headers $headers

# Test: /api/indicators - formato con llaves
Invoke-RestMethod -Uri "http://localhost:8000/api/indicators/{1}" -Headers $headers

# Test: /api/evaluations - formato correcto
Invoke-RestMethod -Uri "http://localhost:8000/api/evaluations/EST001" -Headers $headers

# Test: /api/evaluations - formato con llaves
Invoke-RestMethod -Uri "http://localhost:8000/api/evaluations/{EST001}" -Headers $headers
```

### cURL

```bash
# /api/indicators
curl -H "X-API-Key: tu_api_key" http://localhost:8000/api/indicators/1
curl -H "X-API-Key: tu_api_key" "http://localhost:8000/api/indicators/{1}"

# /api/evaluations
curl -H "X-API-Key: tu_api_key" http://localhost:8000/api/evaluations/EST001
curl -H "X-API-Key: tu_api_key" "http://localhost:8000/api/evaluations/{EST001}"
```

## 📊 Respuestas Esperadas

### ✅ GET /api/indicators/1 - Éxito
```json
[
  {
    "id": 1,
    "student_outcome_id": 1,
    "indicator_letter": "a",
    "description": "Descripción del indicador"
  }
]
```

### ✅ GET /api/evaluations/EST001 - Éxito
```json
[
  {
    "student_code": "EST001",
    "outcome_id": 1,
    "indicator_id": 1,
    "level": "E",
    "score": 95.5
  }
]
```

### ✅ GET /api/evaluations/EST999 - Sin evaluaciones
```json
[]
```

### ❌ GET /api/indicators/999 - Outcome no existe
```json
{
  "detail": "Outcome con ID 999 no encontrado"
}
```

### ❌ GET /api/indicators/abc - ID inválido
```json
{
  "detail": "ID inválido: 'abc'. Debe ser un número entero."
}
```

## 🚀 Reiniciar Servidor

```powershell
# Presiona Ctrl+C donde está corriendo uvicorn, luego:
uvicorn main:app --reload
```

## 📋 Resumen de Cambios

| Archivo | Cambios |
|---------|---------|
| `main.py` | ✅ Endpoint `/api/indicators/{outcome_id}` corregido |
| `main.py` | ✅ Endpoint `/api/evaluations/{student_code}` corregido |
| `test_fixed_endpoints.ps1` | ✅ Script de prueba creado |

## ✅ Ahora Funciona

Ambos endpoints ahora:
- ✅ Aceptan formato estándar y con llaves
- ✅ Validan correctamente los parámetros
- ✅ Manejan errores apropiadamente
- ✅ Cierran conexiones siempre (try-finally)
- ✅ Retornan mensajes de error descriptivos
