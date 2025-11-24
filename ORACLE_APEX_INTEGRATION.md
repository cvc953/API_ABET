# 🎯 Integración de API REST con Oracle APEX - Dashboard Student Outcomes

## 📋 Tabla de Contenidos

1. [Configuración Inicial](#1-configuración-inicial)
2. [Creación de Web Credentials](#2-creación-de-web-credentials)
3. [Configuración de REST Data Sources](#3-configuración-de-rest-data-sources)
4. [Estructura del Dashboard](#4-estructura-del-dashboard)
5. [Componentes del Dashboard](#5-componentes-del-dashboard)
6. [Código de Ejemplo](#6-código-de-ejemplo)

---

## 1. Configuración Inicial

### 1.1 Requisitos Previos
- Oracle APEX 21.1 o superior
- API REST funcionando (http://tu-servidor:8000)
- API Key configurada
- Acceso a Application Builder

### 1.2 Arquitectura del Dashboard

```
┌─────────────────────────────────────────────────────────┐
│                    DASHBOARD HOME                        │
├─────────────────────────────────────────────────────────┤
│  📊 Student Outcomes Overview                           │
│  ┌───────────┬───────────┬───────────┬───────────┐    │
│  │  SO-1     │  SO-2     │  SO-3     │  SO-4     │    │
│  │  73%      │  85%      │  62%      │  91%      │    │
│  └───────────┴───────────┴───────────┴───────────┘    │
├─────────────────────────────────────────────────────────┤
│  📈 Outcome Detail (Interactive Report)                 │
│  - Chart: E+G Performance by Indicator                  │
│  - Table: Assessment Statistics (E/G/F/I)              │
│  - Report: Complete Outcome Report                      │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Creación de Web Credentials

### Paso 1: Crear Web Credential para API Key

**App Builder → Shared Components → Web Credentials → Create**

```
Name: MOODLE_API_CREDENTIAL
Authentication Type: HTTP Header
Header Name: X-API-Key
Header Value: tu_api_key_aqui
```

---

## 3. Configuración de REST Data Sources

### 3.1 REST Data Source: Student Outcomes

**Shared Components → REST Data Sources → Create**

```yaml
Name: STUDENT_OUTCOMES
URL Endpoint: http://tu-servidor:8000/api/outcomes
Authentication: MOODLE_API_CREDENTIAL
Method: GET
```

**Discover → Sync with endpoint**

**Columnas esperadas:**
- ID (NUMBER)
- SO_NUMBER (VARCHAR2)
- DESCRIPTION (VARCHAR2)

---

### 3.2 REST Data Source: Outcome Chart Data

```yaml
Name: OUTCOME_CHART_DATA
URL Endpoint: http://tu-servidor:8000/api/outcome-chart/:OUTCOME_ID
Parameters:
  - OUTCOME_ID (Bind Variable)
Method: GET
```

**Estructura JSON Response:**
```json
{
  "outcome_id": 1,
  "so_number": "SO-1",
  "title": "...",
  "chart_data": [
    {
      "indicator": "a",
      "percentage_eg": 100,
      "count_eg": 13,
      "total": 13
    }
  ]
}
```

---

### 3.3 REST Data Source: Outcome Assessment

```yaml
Name: OUTCOME_ASSESSMENT
URL Endpoint: http://tu-servidor:8000/api/outcome-assessment/:OUTCOME_ID
Parameters:
  - OUTCOME_ID (Bind Variable)
Method: GET
```

---

### 3.4 REST Data Source: Outcome Report

```yaml
Name: OUTCOME_REPORT
URL Endpoint: http://tu-servidor:8000/api/outcome-report/:OUTCOME_ID
Parameters:
  - OUTCOME_ID (Bind Variable)
Method: GET
```

---

## 4. Estructura del Dashboard

### 4.1 Página 1: Home Dashboard

**Page → Create → Blank Page**

```
Page Number: 1
Page Name: Student Outcomes Dashboard
Page Mode: Normal
```

#### Regiones del Dashboard:

1. **Región: Outcomes Overview (Cards)**
2. **Región: Chart - E+G Performance**
3. **Región: Assessment Table**
4. **Región: Filters**

---

### 4.2 Página 2: Outcome Detail

**Page → Create → Report**

```
Page Number: 2
Page Name: Outcome Detail Report
Data Source: OUTCOME_REPORT
```

---

## 5. Componentes del Dashboard

### 5.1 Region: Student Outcomes Cards

**Region Type: Cards**

**Source:**
```sql
-- Opción 1: Usando REST Data Source directamente
SELECT id,
       so_number,
       description,
       NULL as compliance_percentage  -- Se calculará después
FROM STUDENT_OUTCOMES

-- Opción 2: Usando Local Database Table (recomendado)
-- Crear tabla local y sincronizar con API usando proceso
```

**Card Attributes:**
```
Title: &SO_NUMBER.
Body: &DESCRIPTION.
Secondary Body: Compliance: &COMPLIANCE_PERCENTAGE.%
Icon: fa-graduation-cap
```

**Card Link:**
```
Target: Page 2 (Outcome Detail)
Set Items:
  - P2_OUTCOME_ID = &ID.
```

---

### 5.2 Region: E+G Performance Chart

**Region Type: Chart**

**Chart Type: Bar Chart**

**Source Type: REST Data Source**
```
REST Data Source: OUTCOME_CHART_DATA
Bind Variables:
  - OUTCOME_ID = :P1_SELECTED_OUTCOME
```

**Series:**
```sql
-- Transformación del JSON con JSON_TABLE
SELECT indicator,
       percentage_eg
FROM JSON_TABLE(
  :CHART_DATA_JSON,
  '$.chart_data[*]'
  COLUMNS (
    indicator VARCHAR2(10) PATH '$.indicator',
    percentage_eg NUMBER PATH '$.percentage_eg'
  )
)
```

**Chart Settings:**
```
Label: Indicator
Value: Percentage E+G
Color Scheme: Sequential
Maximum: 100
Show Data Label: Yes
```

---

### 5.3 Region: Assessment Statistics Table

**Region Type: Interactive Report**

**Source:**
```sql
SELECT 
    indicator,
    e_count,
    g_count,
    f_count,
    i_count,
    total,
    e_percentage,
    g_percentage,
    f_percentage,
    i_percentage
FROM JSON_TABLE(
    :P1_ASSESSMENT_JSON,
    '$.assessment_data[*]'
    COLUMNS (
        indicator VARCHAR2(10) PATH '$.indicator',
        e_count NUMBER PATH '$.levels.E',
        g_count NUMBER PATH '$.levels.G',
        f_count NUMBER PATH '$.levels.F',
        i_count NUMBER PATH '$.levels.I',
        total NUMBER PATH '$.total',
        e_percentage NUMBER PATH '$.percentages.E',
        g_percentage NUMBER PATH '$.percentages.G',
        f_percentage NUMBER PATH '$.percentages.F',
        i_percentage NUMBER PATH '$.percentages.I'
    )
)
```

**Column Formatting:**
- E, G columns: Green highlight
- F, I columns: Red highlight
- Percentages: Number format with %

---

### 5.4 Region: Outcome Report (Modal Dialog)

**Page Type: Modal Dialog**

**Regions:**

1. **Course Information**
```html
<div class="outcome-header">
    <h2>UNIVERSIDAD TECNOLÓGICA DE BOLÍVAR</h2>
    <h3>FACULTY OF ENGINEERING</h3>
    <h3>STUDENT OUTCOMES &SO_NUMBER.</h3>
</div>
<div class="course-info">
    <p><strong>Code:</strong> &COURSE_CODE.</p>
    <p><strong>Course:</strong> &COURSE_NAME.</p>
    <p><strong>Professor:</strong> &PROFESSOR.</p>
    <p><strong>Students:</strong> &TOTAL_STUDENTS.</p>
</div>
```

2. **Compliance Gauge Chart**
```
Chart Type: Dial
Value: &COMPLIANCE_PERCENTAGE.
Maximum: 100
Thresholds:
  - 0-50: Red
  - 50-70: Yellow
  - 70-100: Green
```

3. **Indicators Status**
```sql
SELECT indicator,
       description,
       assessment_status,
       student_status,
       e_count || '/' || total as "E/Total",
       g_count || '/' || total as "G/Total"
FROM JSON_TABLE(
    :P2_REPORT_JSON,
    '$.indicators[*]'
    COLUMNS (
        indicator VARCHAR2(10) PATH '$.indicator',
        description VARCHAR2(500) PATH '$.description',
        assessment_status VARCHAR2(50) PATH '$.assessment_status',
        student_status VARCHAR2(50) PATH '$.student_status',
        e_count NUMBER PATH '$.evaluations.E',
        g_count NUMBER PATH '$.evaluations.G',
        total NUMBER PATH '$.evaluations.total'
    )
)
```

---

## 6. Código de Ejemplo

### 6.1 PL/SQL Process: Fetch API Data

**Process Name: FETCH_OUTCOME_DATA**
**Point: After Header**

```plsql
DECLARE
    l_response CLOB;
    l_url VARCHAR2(500);
    l_outcome_id NUMBER := :P1_SELECTED_OUTCOME;
BEGIN
    -- Configurar URL
    l_url := 'http://tu-servidor:8000/api/outcome-report/' || l_outcome_id;
    
    -- Llamar API usando APEX_WEB_SERVICE
    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        p_url => l_url,
        p_http_method => 'GET',
        p_credential_static_id => 'MOODLE_API_CREDENTIAL'
    );
    
    -- Guardar JSON en item de página
    :P1_REPORT_JSON := l_response;
    
    -- Extraer valores individuales usando JSON_VALUE
    :P1_SO_NUMBER := JSON_VALUE(l_response, '$.so_number');
    :P1_COMPLIANCE := JSON_VALUE(l_response, '$.compliance.percentage');
    :P1_COURSE_CODE := JSON_VALUE(l_response, '$.course.code');
    :P1_COURSE_NAME := JSON_VALUE(l_response, '$.course.name');
    :P1_PROFESSOR := JSON_VALUE(l_response, '$.course.professor');
    :P1_TOTAL_STUDENTS := JSON_VALUE(l_response, '$.students.total');
    
EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.ERROR('Error fetching API data: ' || SQLERRM);
        RAISE;
END;
```

---

### 6.2 PL/SQL Function: Get Compliance Color

```plsql
CREATE OR REPLACE FUNCTION get_compliance_color(
    p_percentage NUMBER
) RETURN VARCHAR2
IS
BEGIN
    CASE
        WHEN p_percentage >= 70 THEN RETURN 'u-success';
        WHEN p_percentage >= 50 THEN RETURN 'u-warning';
        ELSE RETURN 'u-danger';
    END CASE;
END;
```

**Uso en Cards:**
```sql
SELECT id,
       so_number,
       description,
       compliance_percentage,
       get_compliance_color(compliance_percentage) as css_class
FROM student_outcomes_view
```

---

### 6.3 Dynamic Action: Refresh Chart on Outcome Change

**Event: Change**
**Selection Type: Item**
**Item: P1_SELECTED_OUTCOME**

**True Action:**
```
Action: Execute JavaScript Code
Code:
    apex.region("chart_region").refresh();
    apex.region("assessment_table").refresh();
```

---

### 6.4 JavaScript: Custom Chart Formatting

**Page → JavaScript → Function and Global Variable Declaration**

```javascript
// Formato personalizado para Chart.js
function formatChartOptions() {
    return {
        scales: {
            y: {
                beginAtZero: true,
                max: 100,
                ticks: {
                    callback: function(value) {
                        return value + '%';
                    }
                }
            }
        },
        plugins: {
            datalabels: {
                anchor: 'end',
                align: 'top',
                formatter: function(value) {
                    return value + '%';
                },
                color: '#000',
                font: {
                    weight: 'bold'
                }
            },
            tooltip: {
                callbacks: {
                    label: function(context) {
                        return 'E+G Level: ' + context.parsed.y + '%';
                    }
                }
            }
        }
    };
}

// Colores por nivel de cumplimiento
function getBarColor(percentage) {
    if (percentage >= 70) return '#28a745'; // Verde
    if (percentage >= 50) return '#ffc107'; // Amarillo
    return '#dc3545'; // Rojo
}
```

---

### 6.5 CSS Personalizado

**Page → CSS → Inline**

```css
/* Header del reporte */
.outcome-header {
    text-align: center;
    background: #003f7f;
    color: white;
    padding: 20px;
    margin-bottom: 20px;
}

.outcome-header h2 {
    margin: 0;
    font-size: 18px;
}

.outcome-header h3 {
    margin: 5px 0;
    font-size: 16px;
}

/* Cards de outcomes */
.outcome-card {
    transition: transform 0.2s;
    cursor: pointer;
}

.outcome-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
}

/* Compliance Badge */
.compliance-badge {
    display: inline-block;
    padding: 5px 15px;
    border-radius: 20px;
    font-weight: bold;
}

.compliance-badge.high {
    background: #28a745;
    color: white;
}

.compliance-badge.medium {
    background: #ffc107;
    color: #000;
}

.compliance-badge.low {
    background: #dc3545;
    color: white;
}

/* Tabla de assessment */
.assessment-table .e-column,
.assessment-table .g-column {
    background: #d4edda;
    color: #155724;
    font-weight: bold;
}

.assessment-table .f-column,
.assessment-table .i-column {
    background: #f8d7da;
    color: #721c24;
    font-weight: bold;
}

/* Indicadores status */
.status-ok {
    color: #28a745;
    font-weight: bold;
}

.status-pending {
    color: #ffc107;
    font-weight: bold;
}

/* Responsive */
@media (max-width: 768px) {
    .outcome-header h2 {
        font-size: 14px;
    }
    
    .outcome-card {
        margin-bottom: 10px;
    }
}
```

---

## 7. Estructura de Páginas Completa

### Página 1: Dashboard Principal

```
┌─────────────────────────────────────────────────┐
│  🏠 Student Outcomes Dashboard                  │
├─────────────────────────────────────────────────┤
│  📊 Filter Region                               │
│  [Select Outcome ▼] [Refresh Button]           │
├─────────────────────────────────────────────────┤
│  📈 E+G Performance Chart                       │
│  ┌─────────────────────────────────────┐       │
│  │ Bar Chart: % by Indicator           │       │
│  └─────────────────────────────────────┘       │
├─────────────────────────────────────────────────┤
│  📋 Assessment Statistics                       │
│  ┌─────────────────────────────────────┐       │
│  │ Interactive Report: E/G/F/I Table   │       │
│  └─────────────────────────────────────┘       │
├─────────────────────────────────────────────────┤
│  📄 [View Full Report Button]                   │
└─────────────────────────────────────────────────┘
```

### Página 2: Full Report (Modal)

```
┌─────────────────────────────────────────────────┐
│  📄 Student Outcome Report - SO-2               │
├─────────────────────────────────────────────────┤
│  Course: TRATAMIENTO DE AGUA                    │
│  Professor: PASQUALINO JORGELINA                │
│  Students: 14                                   │
├─────────────────────────────────────────────────┤
│  ⚡ Compliance Gauge: 73%                       │
├─────────────────────────────────────────────────┤
│  📊 Indicators Status                           │
│  ┌─────────────────────────────────────┐       │
│  │ a: Ok / Pendiente                   │       │
│  │ b: Ok / Ok                          │       │
│  └─────────────────────────────────────┘       │
├─────────────────────────────────────────────────┤
│  [Download PDF] [Close]                         │
└─────────────────────────────────────────────────┘
```

---

## 8. Pasos de Implementación

### Paso 1: Configurar REST Data Sources (30 min)
1. Crear Web Credential
2. Crear 4 REST Data Sources
3. Probar cada endpoint con "Test"

### Paso 2: Crear Página Dashboard (1 hora)
1. Crear página en blanco
2. Agregar región de filtros
3. Agregar región de gráfico
4. Agregar región de tabla

### Paso 3: Configurar Data Binding (45 min)
1. Crear Page Items para almacenar JSON
2. Crear procesos PL/SQL para fetch
3. Configurar Dynamic Actions

### Paso 4: Crear Modal Report (1 hora)
1. Crear página modal
2. Agregar regiones de información
3. Configurar gauge chart
4. Agregar tabla de indicadores

### Paso 5: Aplicar Estilos (30 min)
1. Agregar CSS personalizado
2. Configurar colores de tema
3. Agregar íconos

### Paso 6: Testing (30 min)
1. Probar todos los endpoints
2. Verificar navegación
3. Probar en diferentes dispositivos

---

## 9. Mejoras Opcionales

### 9.1 Caché de Datos
```plsql
-- Crear tabla local para cache
CREATE TABLE outcome_cache (
    outcome_id NUMBER PRIMARY KEY,
    json_data CLOB,
    last_updated TIMESTAMP,
    CONSTRAINT check_json CHECK (json_data IS JSON)
);

-- Proceso de sincronización
CREATE OR REPLACE PROCEDURE sync_outcomes_cache
IS
    l_response CLOB;
BEGIN
    FOR outcome IN (SELECT id FROM student_outcomes) LOOP
        l_response := fetch_api_data('/api/outcome-report/' || outcome.id);
        
        MERGE INTO outcome_cache c
        USING (SELECT outcome.id as id, l_response as json FROM dual) s
        ON (c.outcome_id = s.id)
        WHEN MATCHED THEN
            UPDATE SET json_data = s.json, last_updated = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT VALUES (s.id, s.json, SYSTIMESTAMP);
    END LOOP;
    COMMIT;
END;
```

### 9.2 Export a PDF
```plsql
-- Usar APEX_UTIL.GET_PRINT_DOCUMENT
DECLARE
    l_blob BLOB;
BEGIN
    l_blob := APEX_UTIL.GET_PRINT_DOCUMENT(
        p_application_id => :APP_ID,
        p_report_query_name => 'OUTCOME_REPORT',
        p_format => 'PDF'
    );
    
    -- Download
    htp.init;
    owa_util.mime_header('application/pdf', FALSE);
    htp.p('Content-Length: ' || dbms_lob.getlength(l_blob));
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
END;
```

### 9.3 Real-time Updates
```javascript
// Actualización automática cada 5 minutos
setInterval(function() {
    apex.region("dashboard_region").refresh();
}, 300000);
```

---

## 10. Troubleshooting

### Problema: CORS Error
**Solución:** Verificar que tu API tenga CORS habilitado para el dominio de APEX

### Problema: JSON Parse Error
**Solución:** Usar `JSON_TABLE` con error handling:
```sql
SELECT * FROM JSON_TABLE(
    :JSON_DATA,
    '$' ERROR ON ERROR
    ...
)
```

### Problema: API Key no funciona
**Solución:** Verificar que Web Credential esté asignado al REST Data Source

---

## 📚 Recursos Adicionales

- **Oracle APEX REST Services:** https://docs.oracle.com/en/database/oracle/apex/
- **JSON_TABLE Documentation:** https://docs.oracle.com/en/database/oracle/oracle-database/
- **APEX Best Practices:** https://apex.oracle.com/pls/apex/

---

## ✅ Checklist Final

- [ ] Web Credentials configurado
- [ ] 4 REST Data Sources creados
- [ ] Página Dashboard creada
- [ ] Gráfico E+G funcionando
- [ ] Tabla Assessment funcionando
- [ ] Modal Report funcionando
- [ ] CSS aplicado
- [ ] Testing completo
- [ ] Documentación actualizada

---

**¡Dashboard listo para producción!** 🎉

---

## 11. Tipos de Items recomendados (por página y región)

Esta guía especifica exactamente qué tipo de Item crear en APEX, con nombre sugerido, configuración clave y dónde se usa. Sigue estos nombres para que los bindings y parámetros funcionen sin sorpresas.

### 11.1 Página 1: Student Outcomes Dashboard

- P1_SELECTED_OUTCOME
    - Tipo: Select List (Number)
    - Uso: Seleccionar el Outcome actual; alimenta Chart y Assessment
    - LOV (opciones):
        - Fuente: REST Data Source STUDENT_OUTCOMES o tabla local
        - Return value: ID
        - Display value: SO_NUMBER (y opcionalmente SO_NUMBER || ' - ' || DESCRIPTION)
    - Null Display Value: «Seleccione un Outcome…»
    - Cascading LOV: opcional si filtras por periodo/curso
    - Security: Session State Protection = Restricted
    - Importante: no uses “Submit when value changed”; en su lugar refrescaremos regiones con Acciones Dinámicas

- P1_TERM (opcional)
    - Tipo: Select List (Character)
    - Uso: Filtrar por periodo/semestre si la API lo soporta
    - LOV: estática (A/W/S) o desde tabla/servicio propio
    - Añadir a Items to Submit de las regiones que dependan de él

- P1_COURSE (opcional)
    - Tipo: Select List (Number/Character)
    - Uso: Filtrar por asignatura
    - LOV: dependiente de P1_TERM (cascading)
    - Añadir a Items to Submit de las regiones que dependan de él

- P1_ASSESSMENT_JSON (opcional)
    - Tipo: Textarea (CLOB) — Display = Hidden
    - Uso: Solo si eliges el enfoque PL/SQL + JSON_TABLE en lugar de regiones REST directas
    - Relleno: Proceso PL/SQL After Header que llama a /api/outcome-assessment/:OUTCOME_ID
    - No es necesario en Items to Submit a menos que lo referencies en regiones SQL

- P1_CHART_JSON (opcional)
    - Tipo: Textarea (CLOB) — Display = Hidden
    - Uso: Solo si eliges el enfoque PL/SQL + JSON_TABLE
    - Relleno: Proceso PL/SQL que llama a /api/outcome-chart/:OUTCOME_ID

#### Regiones y bindings en Página 1

- Región: Outcomes Overview (Cards)
    - Source Type: REST Data Source → STUDENT_OUTCOMES
    - Atributos:
        - Title: &SO_NUMBER.
        - Body: &DESCRIPTION.
    - Link:
        - Target: Page 2 (Outcome Detail Report)
        - Set Items: P2_OUTCOME_ID = &ID.
    - Static ID sugerida: cards_outcomes

- Región: E+G Performance (Bar Chart)
    - Source Type: REST Data Source → OUTCOME_CHART_DATA
    - Parámetros (Parameters): OUTCOME_ID = :P1_SELECTED_OUTCOME
    - Items to Submit (de la región): P1_SELECTED_OUTCOME (y filtros asociados)
    - Static ID sugerida: chart_eg
    - Configuración de serie:
        - Label: indicator
        - Value: percentage_eg (Y: 0–100, mostrar etiquetas)

- Región: Assessment Statistics (Interactive Report)
    - Source Type: REST Data Source → OUTCOME_ASSESSMENT
    - Parámetros (Parameters): OUTCOME_ID = :P1_SELECTED_OUTCOME
    - Items to Submit (de la región): P1_SELECTED_OUTCOME (y filtros asociados)
    - Static ID sugerida: assessment_table
    - Formato recomendado: porcentajes con “%”; resaltado verde (E/G) y rojo (F/I)

#### Acciones Dinámicas (Página 1)

- DA_Refresh_On_Change
    - Event: Change
    - Selection Type: Item(s)
    - Items: P1_SELECTED_OUTCOME (y otros filtros como P1_TERM/P1_COURSE si aplican)
    - True Actions (en este orden):
        1) Refresh → Region: chart_eg
        2) Refresh → Region: assessment_table
    - Nota: Asegúrate de que ambas regiones incluyan los items en “Items to Submit”

### 11.2 Página 2: Outcome Detail Report

- P2_OUTCOME_ID
    - Tipo: Hidden (Number)
    - Uso: Recibe el ID desde las Cards de la página 1
    - Security: Session State Protection = Restricted

- P2_REPORT_JSON (opcional)
    - Tipo: Textarea (CLOB) — Display = Hidden
    - Uso: Solo si usas PL/SQL + JSON_TABLE para parsear /api/outcome-report/:OUTCOME_ID

- P2_SO_NUMBER (opcional, si quieres mostrar como item)
    - Tipo: Display Only (Character)
    - Fuente: JSON_VALUE desde P2_REPORT_JSON o columna mapeada del REST

- P2_COMPLIANCE (opcional)
    - Tipo: Display Only (Number)
    - Fuente: compliance.percentage del reporte

- P2_COURSE_CODE, P2_COURSE_NAME, P2_PROFESSOR, P2_TOTAL_STUDENTS (opcionales)
    - Tipo: Display Only
    - Fuente: JSON_VALUE o columnas del REST (course.code, course.name, course.professor, students.total)

#### Regiones en Página 2

- Course Information
    - Opción A (simple): Source Type = REST Data Source → OUTCOME_REPORT
        - Parameters: OUTCOME_ID = :P2_OUTCOME_ID
        - Renderiza campos con plantilla/columnas mapeadas
    - Opción B (flexible): Proceso PL/SQL After Header → guarda JSON en P2_REPORT_JSON; regiones SQL con JSON_VALUE/JSON_TABLE

- Compliance Gauge (Dial Chart)
    - Value: P2_COMPLIANCE (Display Only) o columna del REST
    - Thresholds: 0–50 rojo, 50–70 amarillo, 70–100 verde

- Indicators Status (Interactive Report o Classic Report)
    - Opción REST directa: Row Selector $.indicators[*] y columnas indicator, description, evaluations.E/G/total, statuses
    - Opción JSON_TABLE: sobre P2_REPORT_JSON

### 11.3 Parámetros y seguridad

- Parámetro OUTCOME_ID en REST
    - Página 1: OUTCOME_CHART_DATA y OUTCOME_ASSESSMENT → OUTCOME_ID = :P1_SELECTED_OUTCOME
    - Página 2: OUTCOME_REPORT → OUTCOME_ID = :P2_OUTCOME_ID

- Items to Submit (crítico)
    - Región chart_eg: P1_SELECTED_OUTCOME, P1_TERM/P1_COURSE si aplican
    - Región assessment_table: P1_SELECTED_OUTCOME, P1_TERM/P1_COURSE si aplican

- Autenticación
    - Si la Credential da error de alcance, usa Request → Static HTTP Headers en el REST Data Source:
        - Name: X-API-Key
        - Value: tu_api_key

### 11.4 Comprobación rápida (checklist)

- [ ] P1_SELECTED_OUTCOME creado como Select List con Return=ID y Display=SO_NUMBER
- [ ] OUTCOME_CHART_DATA y OUTCOME_ASSESSMENT reciben OUTCOME_ID = :P1_SELECTED_OUTCOME
- [ ] Regiones chart_eg y assessment_table incluyen Items to Submit correctos
- [ ] DA refresca chart_eg y assessment_table al cambiar P1_SELECTED_OUTCOME
- [ ] Página 2 recibe P2_OUTCOME_ID desde las Cards y OUTCOME_REPORT usa ese parámetro
- [ ] Si usas JSON_TABLE, existen P1_/P2_…_JSON y procesos PL/SQL que los cargan

### 11.5 Cómo agregar bind variables en un Chart

Hay dos formas típicas de alimentar un Chart con variables de enlace (bind variables) en APEX: usando un REST Data Source (recomendado) o usando una consulta SQL local (JSON_TABLE/tabla).

#### A) Chart con REST Data Source

1) Define el parámetro en el Data Source
    - Shared Components → REST Data Sources → OUTCOME_CHART_DATA
    - Asegúrate de tener un parámetro (por ejemplo) OUTCOME_ID en la URL o como Query Parameter.
    - Test con un valor fijo (1) para validar el endpoint.

2) Asigna el parámetro en la región del Chart
    - Page Designer → Región del Chart (Bar) → Source Type: REST Data Source → OUTCOME_CHART_DATA
    - Panel derecho → pestaña Attributes (o Source) → Parameters
    - Agrega: Name = OUTCOME_ID, Value = :P1_SELECTED_OUTCOME (elige “Item” como fuente del valor si el UI lo solicita)

3) Envía el item en las llamadas AJAX
    - Región del Chart → pestaña Advanced → Items to Submit → agrega P1_SELECTED_OUTCOME (y cualquier otro filtro que uses)

4) Refresca la región cuando cambie el item
    - Dynamic Action (DA_Refresh_On_Change): Event = Change sobre P1_SELECTED_OUTCOME → True Actions: Refresh región del Chart

5) Ajusta Series/Ejes
    - Series: Label = indicator, Value = percentage_eg
    - Y Axis: 0–100, Show Data Labels = Yes

6) Errores comunes a evitar
    - No incluir “:” en el nombre del parámetro (OUTCOME_ID). El “:” solo va en el Value cuando apuntas a un item (:P1_SELECTED_OUTCOME).
    - Olvidar Items to Submit → el Chart no recibe el valor y no cambia.
    - Mismatch de nombres (OUTCOME_ID distinto al esperado por la API).

#### B) Chart con SQL (JSON_TABLE / tabla local)

1) Define el item que actúa como bind variable
    - P1_SELECTED_OUTCOME (Select List/Number) con Return = ID.

2) Carga el JSON (si usas API) en un item CLOB (opcional)
    - Proceso PL/SQL (After Header o On Demand) que llame a la API y asigne a :P1_CHART_JSON:
      - l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(... OUTCOME_ID => :P1_SELECTED_OUTCOME ...);
      - :P1_CHART_JSON := l_response;

3) Consulta del Chart con JSON_TABLE (ejemplo)
```sql
SELECT jt.indicator, jt.percentage_eg
FROM JSON_TABLE(
  :P1_CHART_JSON,
  '$.chart_data[*]'
  COLUMNS (
     indicator      VARCHAR2(10) PATH '$.indicator',
     percentage_eg  NUMBER       PATH '$.percentage_eg'
  )
) jt
```

4) Items to Submit y refresco
    - Región del Chart (SQL) → Advanced → Items to Submit: P1_SELECTED_OUTCOME, P1_CHART_JSON
    - DA: Change en P1_SELECTED_OUTCOME → (opcional) True Action 1: Execute PL/SQL (llama proceso On Demand para recargar :P1_CHART_JSON) → True Action 2: Refresh Chart

5) Alternativa sin JSON (tabla local)
    - Si tienes una tabla/vista local, usa directamente :P1_SELECTED_OUTCOME en el WHERE.

#### C) Verificación rápida

- Cambia P1_SELECTED_OUTCOME en runtime y verifica que el Chart se refresca.
- Si no cambia, revisa: Items to Submit, nombre del parámetro OUTCOME_ID, y la DA de Refresh.
- Usa el botón Test en el REST Data Source con OUTCOME_ID=1 para descartar problemas de API.

### 11.6 Dónde configurar el enlace (Card Link) y alternativas

Si no encuentras la propiedad «Link» en una región de tipo Cards, revisa estas situaciones y soluciones:

1) Verifica que la región sea realmente de tipo «Cards»
    - Page Designer → selecciona la región → en el panel “Identification”, el Type debe ser «Cards».
    - Si es «Classic Report» o «Interactive Report», el link se configura a nivel de columna (Column → Link), no en la región.

2) Activa/visibiliza el Link Target en Cards
    - Page Designer → Región (Cards) → pestaña Attributes → sección “Card”.
    - Asegúrate de tener mapeado al menos el «Title» (Title = &SO_NUMBER.) y que exista una columna «ID» en la fuente.
    - En algunas versiones, seleccionar «Primary Key Column = ID» hace aparecer/activar «Link Target».
    - Propiedad a configurar: «Link Target» → “Page in this Application” → Page = 2 → Set Items: P2_OUTCOME_ID = ID.

3) Si usas REST Data Source y no ves la columna ID
    - Shared Components → REST Data Sources → STUDENT_OUTCOMES → Response → Columns → agrega/asegura la columna «ID».
    - Vuelve al Page Designer, pulsa «Refresh» en la región Cards para que reconozca las columnas.

4) Alternativa: Classic Report con plantilla Cards
    - Crea una región «Classic Report» con SQL que devuelva ID, SO_NUMBER, DESCRIPTION.
    - Region Template: “Cards”.
    - En la columna que hace de título (SO_NUMBER), abre la columna → sección “Link” →
      - Link Target: Page 2
      - Set Items: P2_OUTCOME_ID = #ID#
    - Esta alternativa expone siempre el link por columna y es útil si el Cards “puro” no muestra «Link Target».

5) Último recurso: URL manual
    - Cards → Attributes → si aparece «Link Target = URL», usa:
      - URL: f?p=&APP_ID.:2:&SESSION.::&DEBUG.::P2_OUTCOME_ID:&ID.

6) Buenas prácticas
    - Region Static ID: cards_outcomes (para ubicarla fácil en DA/JS).
    - Verifica que la columna «ID» esté disponible en la fuente (REST Columns o SQL alias ID).
    - Tras cambios en REST Columns, refresca la región en Page Designer y guarda.


