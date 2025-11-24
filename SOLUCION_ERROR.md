# 🔧 Solución al Error de Parsing del Endpoint

## ❌ Error Original

```json
{
  "type": "int_parsing",
  "loc": ["path", "outcome_id"],
  "msg": "Input should be a valid integer, unable to parse string as an integer",
  "input": "{2}",
  "url": "https://errors.pydantic.dev/2.5/v/int_parsing"
}
```

## 🔍 Causa del Error

El cliente estaba enviando las **llaves literales** en la URL:

```
❌ INCORRECTO: http://localhost:8000/api/outcome-summary/{2}
✅ CORRECTO:   http://localhost:8000/api/outcome-summary/2
```

FastAPI esperaba un número entero (`2`), pero recibió una cadena con llaves (`"{2}"`), causando un error de validación de Pydantic.

## ✅ Solución Aplicada

He modificado el endpoint para **aceptar ambos formatos** y limpiar automáticamente las llaves:

### Cambios en `main.py`:

1. **Cambio de tipo de parámetro**: `outcome_id: int` → `outcome_id: str`
2. **Añadido path converter**: `{outcome_id}` → `{outcome_id:path}`
3. **Limpieza automática**: `.strip('{}').strip()` para remover llaves
4. **Validación mejorada**: Mensajes de error más descriptivos
5. **Manejo de excepciones**: Diferencia entre errores de validación y de BD

### Código actualizado:

```python
@app.get("/api/outcome-summary/{outcome_id:path}", dependencies=[Depends(verify_api_key)])
def get_outcome_summary(outcome_id: str):
    """
    Obtener resumen completo de un outcome con sus indicadores y niveles.
    Acepta el ID como string y lo convierte, removiendo llaves si existen.
    """
    # Limpiar el outcome_id: remover llaves si existen
    clean_id = outcome_id.strip('{}').strip()
    try:
        outcome_id_int = int(clean_id)
    except ValueError:
        raise HTTPException(
            status_code=422, 
            detail=f"ID inválido: '{outcome_id}'. Debe ser un número entero."
        )
    
    # ... resto del código ...
```

## 🎯 Ahora Funciona Con:

### ✅ Formato correcto (recomendado)
```bash
GET http://localhost:8000/api/outcome-summary/2
```

### ✅ Formato con llaves (compatibilidad)
```bash
GET http://localhost:8000/api/outcome-summary/{2}
```

### ✅ Con espacios (se limpian automáticamente)
```bash
GET http://localhost:8000/api/outcome-summary/{ 2 }
```

## 🧪 Cómo Probar

### PowerShell:
```powershell
# Formato correcto
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://localhost:8000/api/outcome-summary/2" -Headers $headers

# Formato con llaves (ahora funciona)
Invoke-RestMethod -Uri "http://localhost:8000/api/outcome-summary/{2}" -Headers $headers
```

### Script de prueba automatizado:
```powershell
python test_endpoint.py
```

El script probará ambos formatos automáticamente.

### cURL:
```bash
# Formato correcto
curl -H "X-API-Key: tu_api_key" http://localhost:8000/api/outcome-summary/2

# Formato con llaves (ahora funciona)
curl -H "X-API-Key: tu_api_key" "http://localhost:8000/api/outcome-summary/{2}"
```

## 📊 Respuestas Posibles

### ✅ 200 OK - Éxito
```json
{
  "id": 2,
  "so_number": "SO2",
  "description_es": "...",
  "indicators": [...]
}
```

### ❌ 422 Unprocessable Entity - ID inválido
```json
{
  "detail": "ID inválido: 'abc'. Debe ser un número entero."
}
```

### ❌ 404 Not Found - Outcome no existe
```json
{
  "detail": "Outcome con ID 2 no encontrado"
}
```

### ❌ 403 Forbidden - API Key inválida
```json
{
  "detail": "API Key inválida o faltante"
}
```

### ❌ 500 Internal Server Error - Error de BD
```json
{
  "detail": "Error al consultar resumen: ..."
}
```

## 🚀 Ejecución

Si aún no has iniciado el servidor:

```powershell
# Activar entorno virtual
.\.venv\Scripts\Activate.ps1

# Ejecutar servidor
uvicorn main:app --reload

# En otra terminal, probar
python test_endpoint.py
```

## 💡 Recomendación

Aunque el endpoint ahora acepta ambos formatos, **recomiendo usar el formato sin llaves** en el cliente:

```
✅ RECOMENDADO: /api/outcome-summary/2
⚠️  COMPATIBLE:  /api/outcome-summary/{2}
```

El formato con llaves se mantiene solo por compatibilidad con integraciones existentes.

## 📝 Para Oracle APEX

Si estás llamando desde Oracle APEX, asegúrate de construir la URL correctamente:

```sql
-- ✅ CORRECTO
l_url := 'http://your-api.com/api/outcome-summary/' || :P1_OUTCOME_ID;

-- ❌ INCORRECTO (no incluir llaves literales)
l_url := 'http://your-api.com/api/outcome-summary/{' || :P1_OUTCOME_ID || '}';
```

## ✅ Problema Resuelto

El endpoint ahora:
- ✅ Acepta ambos formatos de URL
- ✅ Limpia automáticamente las llaves
- ✅ Proporciona mensajes de error claros
- ✅ Mantiene compatibilidad con integraciones existentes
- ✅ Valida correctamente los IDs
