# 🔧 Troubleshooting - Oracle APEX + FastAPI Integration

## 🚨 Problemas Comunes y Soluciones

### 1. Error: "CORS policy: No 'Access-Control-Allow-Origin' header"

**Síntomas:**
```
Access to fetch at 'http://tu-servidor:8000/api/outcomes' from origin 
'https://apex.oracle.com' has been blocked by CORS policy
```

**Causa:** CORS no está configurado para permitir el dominio de APEX

**Solución 1 - Configurar CORS en FastAPI:**
```python
# main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://apex.oracle.com",
        "https://tu-apex-domain.com",
        "*"  # Solo para desarrollo
    ],
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)
```

**Solución 2 - Usar APEX como Proxy:**
No llamar la API directamente desde JavaScript, sino usar REST Data Sources de APEX que hacen las llamadas desde el servidor.

---

### 2. Error: "ORA-20001: The Web service returned a HTTP return code 403"

**Síntomas:**
```
Error in APEX_WEB_SERVICE.MAKE_REST_REQUEST
The Web service returned a HTTP return code 403 (Forbidden)
```

**Causa:** API Key no está siendo enviada correctamente

**Solución:**

**Opción A - Verificar Web Credential:**
```sql
-- Ver credentials configurados
SELECT credential_static_id, credential_name
FROM apex_workspace_credentials
WHERE application_id = :APP_ID;
```

**Opción B - Enviar header manualmente:**
```plsql
BEGIN
    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := 'X-API-Key';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := 'tu_api_key';
    
    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        p_url => l_url,
        p_http_method => 'GET'
    );
END;
```

---

### 3. Error: "ORA-40441: JSON syntax error"

**Síntomas:**
```
ORA-40441: JSON syntax error
Error parsing JSON response from API
```

**Causa:** La respuesta de la API no es JSON válido o está vacía

**Solución:**

**1. Verificar respuesta de API:**
```plsql
DECLARE
    l_response CLOB;
BEGIN
    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(...);
    
    -- Log de respuesta
    APEX_DEBUG.INFO('API Response: ' || SUBSTR(l_response, 1, 4000));
    
    -- Verificar si es JSON válido
    IF APEX_JSON.IS_JSON(l_response) THEN
        APEX_DEBUG.INFO('Valid JSON');
    ELSE
        APEX_DEBUG.ERROR('Invalid JSON');
    END IF;
END;
```

**2. Agregar validación:**
```plsql
IF l_response IS NULL OR LENGTH(l_response) = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'API returned empty response');
END IF;

IF NOT APEX_JSON.IS_JSON(l_response) THEN
    RAISE_APPLICATION_ERROR(-20002, 'API returned invalid JSON: ' || 
                            SUBSTR(l_response, 1, 100));
END IF;
```

---

### 4. Error: "ORA-29273: HTTP request failed"

**Síntomas:**
```
ORA-29273: HTTP request failed
ORA-06512: at "SYS.UTL_HTTP", line 1819
```

**Causa:** Oracle no puede conectarse a la API (firewall, SSL, ACL)

**Solución 1 - Verificar ACL (Access Control List):**
```sql
-- Ver ACLs existentes
SELECT host, lower_port, upper_port, ace_order, principal, privilege
FROM dba_network_acls
JOIN dba_network_acl_privileges USING (acl)
WHERE host = 'tu-servidor' OR host = '*';

-- Crear ACL si no existe
BEGIN
    DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(
        acl => 'api_access.xml',
        description => 'HTTP Access for API',
        principal => 'APEX_210200',  -- Tu usuario APEX
        is_grant => TRUE,
        privilege => 'connect'
    );
    
    DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
        acl => 'api_access.xml',
        principal => 'APEX_210200',
        is_grant => TRUE,
        privilege => 'resolve'
    );
    
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'api_access.xml',
        host => 'tu-servidor',  -- o '*' para todos
        lower_port => 8000,
        upper_port => 8000
    );
    
    COMMIT;
END;
/
```

**Solución 2 - Para SSL/HTTPS:**
```sql
-- Si tu API usa HTTPS, necesitas importar certificado
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_WALLET_ACE(
        wallet_path => 'file:/path/to/wallet',
        ace => xs$ace_type(
            privilege_list => xs$name_list('http'),
            principal_name => 'APEX_210200'
        )
    );
END;
/
```

---

### 5. Error: Chart no se muestra / "No data found"

**Síntomas:**
- Gráfico aparece vacío
- Mensaje "No data found"

**Causa:** Query no retorna datos o formato incorrecto

**Solución:**

**1. Verificar query directamente:**
```sql
-- Ejecutar en SQL Workshop
SELECT indicator,
       percentage_eg,
       bar_color
FROM v_chart_eg_performance
WHERE outcome_id = 1;  -- Usar un ID real
```

**2. Verificar bind variable:**
```sql
-- Agregar logging
BEGIN
    APEX_DEBUG.INFO('P1_SELECTED_OUTCOME = ' || :P1_SELECTED_OUTCOME);
END;
```

**3. Usar query estático para testing:**
```sql
-- Reemplazar temporalmente en Chart Source
SELECT 'a' as indicator, 75 as percentage_eg FROM dual UNION ALL
SELECT 'b', 85 FROM dual UNION ALL
SELECT 'c', 65 FROM dual
```

---

### 6. Error: "Region not refreshing after Dynamic Action"

**Síntomas:**
- Dynamic Action se ejecuta pero región no se actualiza
- Datos viejos permanecen

**Solución:**

**1. Verificar que items se submiten:**
```javascript
// Dynamic Action - True Action
Action: Execute JavaScript Code
Code:
    // Forzar submit de items
    apex.item("P1_SELECTED_OUTCOME").setValue(apex.item("P1_SELECTED_OUTCOME").getValue());
    
    // Refrescar región
    apex.region("chart_region").refresh();
```

**2. Usar Execute Server-side Code antes de refresh:**
```plsql
-- True Action 1: Execute Server-side Code
BEGIN
    -- Forzar re-fetch de datos
    :P1_OUTCOME_JSON := fetch_api_endpoint(
        '/api/outcome-report/' || :P1_SELECTED_OUTCOME
    );
END;

-- Items to Submit: P1_SELECTED_OUTCOME
-- Items to Return: P1_OUTCOME_JSON
```

**3. Agregar wait con fire on page load:**
```javascript
// Function and Global Variable Declaration
function refreshDashboard() {
    setTimeout(function() {
        apex.region("chart_region").refresh();
        apex.region("assessment_table").refresh();
    }, 500);  // Esperar 500ms
}
```

---

### 7. Error: "Value too large for column" en sync_outcomes_from_api

**Síntomas:**
```
ORA-01401: inserted value too large for column "DESCRIPTION_EN"
```

**Causa:** Campo en tabla local es muy pequeño

**Solución:**

```sql
-- Aumentar tamaño de columnas
ALTER TABLE apex_student_outcomes MODIFY description_en CLOB;
ALTER TABLE apex_student_outcomes MODIFY description_es CLOB;
ALTER TABLE apex_indicators MODIFY description_en CLOB;
```

---

### 8. Error: REST Data Source "Test failed"

**Síntomas:**
```
Unable to discover REST data source
HTTP Status: 500 Internal Server Error
```

**Causa:** Varios posibles

**Diagnóstico:**

**1. Probar endpoint manualmente:**
```bash
# PowerShell
$headers = @{"X-API-Key"="tu_api_key"}
Invoke-RestMethod -Uri "http://tu-servidor:8000/api/outcomes" -Headers $headers

# O usando curl
curl -H "X-API-Key: tu_api_key" http://tu-servidor:8000/api/outcomes
```

**2. Verificar logs de FastAPI:**
```bash
docker logs moodle-api --tail 100
```

**3. Verificar desde SQL Workshop:**
```sql
SET SERVEROUTPUT ON;

DECLARE
    l_response CLOB;
BEGIN
    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        p_url => 'http://tu-servidor:8000/api/outcomes',
        p_http_method => 'GET'
    );
    
    DBMS_OUTPUT.PUT_LINE('Status: ' || APEX_WEB_SERVICE.G_STATUS_CODE);
    DBMS_OUTPUT.PUT_LINE('Response: ' || SUBSTR(l_response, 1, 500));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
```

---

### 9. Error: JSON_TABLE returns no rows

**Síntomas:**
```sql
SELECT * FROM JSON_TABLE(...) 
-- Returns 0 rows even though JSON has data
```

**Causa:** Path incorrecto en JSON_TABLE

**Solución:**

**1. Validar estructura JSON:**
```sql
SELECT JSON_QUERY(:P1_OUTCOME_JSON, '$')
FROM dual;
```

**2. Usar JSON_QUERY para debugging:**
```sql
-- Ver array completo
SELECT JSON_QUERY(:P1_OUTCOME_JSON, '$.indicators')
FROM dual;

-- Ver primer elemento
SELECT JSON_VALUE(:P1_OUTCOME_JSON, '$.indicators[0].indicator')
FROM dual;
```

**3. Path correcto:**
```sql
-- Incorrecto (falta [*])
'$.indicators'

-- Correcto (con [*] para arrays)
'$.indicators[*]'
```

---

### 10. Error: "Maximum response size exceeded"

**Síntomas:**
```
ORA-20001: The response size exceeded the maximum allowed
```

**Causa:** Respuesta de API es muy grande

**Solución:**

**1. Aumentar límite en APEX:**
```sql
-- Workspace Settings
Maximum Response Size: 10MB  -- Aumentar si es necesario
```

**2. Paginar resultados de API:**
```python
# En FastAPI - agregar paginación
@app.get("/api/outcomes")
async def get_outcomes(
    skip: int = 0, 
    limit: int = 100,
    api_key: str = Depends(verify_api_key)
):
    # ... query con LIMIT y OFFSET
```

**3. Usar tabla local + sincronización:**
En vez de llamar API en cada request, sincronizar a tabla local cada hora.

---

### 11. Performance: Dashboard carga lento

**Síntomas:**
- Página tarda > 5 segundos en cargar
- Timeout en requests

**Solución:**

**1. Implementar caché local:**
```sql
-- Usar tabla local en vez de API directa
CREATE TABLE outcome_cache (
    outcome_id NUMBER PRIMARY KEY,
    json_data CLOB,
    last_updated TIMESTAMP,
    expires_at TIMESTAMP
);

-- Index para búsquedas rápidas
CREATE INDEX idx_cache_expires ON outcome_cache(expires_at);
```

**2. Lazy loading de charts:**
```javascript
// Cargar gráficos solo cuando sean visibles
apex.jQuery(document).ready(function() {
    var chartRegion = apex.region("chart_region");
    
    // Observer para lazy loading
    var observer = new IntersectionObserver(function(entries) {
        if (entries[0].isIntersecting) {
            chartRegion.refresh();
            observer.disconnect();
        }
    });
    
    observer.observe(document.querySelector("#chart_region"));
});
```

**3. Usar APEX Session State Protection:**
```
Page Items:
  - P1_OUTCOME_JSON: Session State Protection = Checksum Required
```

---

### 12. Error: Modal Dialog no se cierra

**Síntomas:**
- Modal se abre pero botón Close no funciona
- URL cambia pero modal permanece

**Solución:**

**1. Verificar tipo de botón:**
```
Button Type: Close
Action: Cancel Dialog
```

**2. Usar JavaScript alternativo:**
```javascript
// Button > Action: Execute JavaScript Code
apex.navigation.dialog.close(true);  // true = refresh parent
```

**3. Dynamic Action para cerrar:**
```
Event: Click
Selection Type: Button
Button: CLOSE

True Action:
  Action: Close Dialog
  Dialog Closed Action: Refresh Parent Page
```

---

## 📊 Debug Mode

### Activar Debug en APEX

**Método 1 - Por sesión:**
```
URL: ?debug=YES
Ejemplo: https://apex.oracle.com/pls/apex/f?p=100:1:::::debug:YES
```

**Método 2 - Por aplicación:**
```
App Builder → Edit Application Properties
Debugging: Yes
```

### Ver Debug Output

```sql
-- En APEX Debug Console
View Debug → Filter by "APEX_DEBUG"

-- O en SQL Workshop
SELECT message, message_timestamp
FROM apex_debug_messages
WHERE application_id = :APP_ID
ORDER BY message_timestamp DESC;
```

---

## 🧪 Testing Script Completo

```sql
-- Ejecutar en SQL Workshop para diagnóstico completo
SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    l_response CLOB;
    l_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== APEX + FastAPI Diagnostic ===');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: ACL
    BEGIN
        SELECT COUNT(*) INTO l_count
        FROM dba_network_acls
        WHERE host LIKE '%tu-servidor%' OR host = '*';
        
        DBMS_OUTPUT.PUT_LINE('✓ ACL configured: ' || l_count || ' entries');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ACL check failed: ' || SQLERRM);
    END;
    
    -- Test 2: Web Credential
    BEGIN
        SELECT COUNT(*) INTO l_count
        FROM apex_workspace_credentials
        WHERE credential_static_id = 'MOODLE_API_CREDENTIAL';
        
        DBMS_OUTPUT.PUT_LINE('✓ Web Credential exists: ' || l_count);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Credential check failed');
    END;
    
    -- Test 3: API Health
    BEGIN
        l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
            p_url => 'http://tu-servidor:8000/health',
            p_http_method => 'GET'
        );
        
        IF APEX_WEB_SERVICE.G_STATUS_CODE = 200 THEN
            DBMS_OUTPUT.PUT_LINE('✓ API Health: ' || l_response);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ API Status: ' || APEX_WEB_SERVICE.G_STATUS_CODE);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ API Health failed: ' || SQLERRM);
    END;
    
    -- Test 4: Outcomes endpoint
    BEGIN
        APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := 'X-API-Key';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := 'tu_api_key';
        
        l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
            p_url => 'http://tu-servidor:8000/api/outcomes',
            p_http_method => 'GET'
        );
        
        IF APEX_JSON.IS_JSON(l_response) THEN
            DBMS_OUTPUT.PUT_LINE('✓ Outcomes endpoint: Valid JSON');
            DBMS_OUTPUT.PUT_LINE('  Response length: ' || LENGTH(l_response));
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ Invalid JSON response');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Outcomes endpoint failed: ' || SQLERRM);
    END;
    
    -- Test 5: Local tables
    BEGIN
        SELECT COUNT(*) INTO l_count FROM apex_student_outcomes;
        DBMS_OUTPUT.PUT_LINE('✓ Local outcomes table: ' || l_count || ' rows');
        
        SELECT COUNT(*) INTO l_count FROM apex_indicators;
        DBMS_OUTPUT.PUT_LINE('✓ Local indicators table: ' || l_count || ' rows');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Local tables check failed');
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== Diagnostic Complete ===');
END;
/
```

---

## 📞 Soporte Adicional

Si ninguna de estas soluciones funciona:

1. **Revisar logs de APEX:**
   - Monitoring → Page Views
   - Debug Messages

2. **Revisar logs de FastAPI:**
   ```bash
   docker logs moodle-api --tail 100 -f
   ```

3. **Probar con Postman/Thunder Client:**
   - Importar colección de endpoints
   - Verificar respuestas esperadas

4. **Oracle APEX Community:**
   - https://community.oracle.com/tech/developers/categories/apex

---

**¡Solución garantizada!** 🎯
