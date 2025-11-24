# 🎯 Configuración Paso a Paso - Oracle APEX Dashboard

## 📌 Configuración Rápida (Quick Start)

### Paso 1: Crear Web Credential (5 min)

1. **App Builder** → Tu aplicación → **Shared Components**
2. **Web Credentials** → **Create**
3. Completar formulario:

```
Name: MOODLE_API_CREDENTIAL
Static Identifier: MOODLE_API_CREDENTIAL
Authentication Type: HTTP Header
Credential Name: X-API-Key
Credential Secret: [tu_api_key_aqui]
Valid for URLs: http://tu-servidor:8000/*
```

4. **Create Credential**

---

### Paso 2: Crear REST Data Source - Outcomes (10 min)

1. **Shared Components** → **REST Data Sources** → **Create**

```
REST Data Source Type: Simple HTTP
Name: STUDENT_OUTCOMES
URL Endpoint: http://tu-servidor:8000/api/outcomes
Remote Server: (Create New)
  - Base URL: http://tu-servidor:8000
  - Service URL Path: /api/outcomes
```

2. **Authentication**:
```
Authentication Required: Yes
Credentials: MOODLE_API_CREDENTIAL
```

3. **Operations** → **POST**:
   - Cambiar a **GET**

4. **Discover** → **Sample Response**:

```json
[
  {
    "id": 1,
    "so_number": "SO-1",
    "description": "Outcome description"
  }
]
```

5. **Parse Response** → **Create Data Profile**

6. **Columns** - Verificar:
   - `ID` (NUMBER)
   - `SO_NUMBER` (VARCHAR2)
   - `DESCRIPTION` (VARCHAR2)

7. **Apply Changes**

---

### Paso 3: Crear REST Data Source - Outcome Report (10 min)

Repetir proceso anterior con:

```
Name: OUTCOME_REPORT
URL: http://tu-servidor:8000/api/outcome-report/:OUTCOME_ID

Parameters:
  - Name: OUTCOME_ID
  - Type: URL Path Parameter
  - Is Static: No
  - Data Type: NUMBER
```

**Sample Request:**
```
http://tu-servidor:8000/api/outcome-report/1
```

**Sample Response:** (Copiar de tu API)

---

### Paso 4: Crear Página Dashboard (15 min)

#### 4.1 Crear Página

1. **Application** → **Create Page** → **Blank Page**

```
Page Number: 1
Name: Student Outcomes Dashboard
Page Mode: Normal
Navigation Menu: Yes
Breadcrumb: No
```

#### 4.2 Agregar Región de Filtros

1. **Create Region**

```
Title: Filters
Type: Static Content
Template: Blank with Attributes
```

2. **Agregar Page Items**:

**Item 1:**
```
Name: P1_SELECTED_OUTCOME
Type: Select List
Label: Select Outcome
LOV Type: SQL Query
LOV SQL Query:
  SELECT so_number as d, id as r
  FROM STUDENT_OUTCOMES
  ORDER BY so_number
```

**Item 2:**
```
Name: P1_OUTCOME_JSON
Type: Hidden
Value Protected: No
```

#### 4.3 Agregar Región de Gráfico

1. **Create Region**

```
Title: E+G Performance by Indicator
Type: Chart
Chart Type: Bar
```

2. **Source**:

```sql
SELECT indicator,
       percentage_eg,
       bar_color
FROM v_chart_eg_performance
WHERE outcome_id = :P1_SELECTED_OUTCOME
ORDER BY indicator
```

3. **Chart Attributes**:

```
Label Column: INDICATOR
Value Column: PERCENTAGE_EG
Color Column: BAR_COLOR

Orientation: Vertical
Stack: No
Show Legend: No
```

4. **Axes**:

```
X Axis - Title: Indicator
Y Axis - Title: Percentage (%)
Y Axis - Minimum: 0
Y Axis - Maximum: 100
```

5. **Appearance**:

```
Show Value: Yes
Value Decimal Places: 0
Value Suffix: %
```

#### 4.4 Agregar Tabla de Assessment

1. **Create Region**

```
Title: Assessment Statistics
Type: Interactive Report
```

2. **Source**:

```sql
SELECT 
    indicator as "Indicator",
    e_count as "E",
    g_count as "G",
    f_count as "F",
    i_count as "I",
    total as "Total",
    ROUND(e_percentage, 1) || '%' as "E %",
    ROUND(g_percentage, 1) || '%' as "G %",
    ROUND(f_percentage, 1) || '%' as "F %",
    ROUND(i_percentage, 1) || '%' as "I %",
    ROUND(eg_percentage, 1) || '%' as "E+G %"
FROM v_assessment_statistics
WHERE outcome_id = :P1_SELECTED_OUTCOME
ORDER BY indicator
```

3. **Interactive Report Attributes**:

```
Search: Yes
Rows Per Page: 25
Enable Users To:
  - Sort: Yes
  - Control Break: Yes
  - Download: Yes (CSV, HTML, PDF)
```

4. **Column Formatting** - Para columnas E y G:

```
Highlight:
  - Type: Cell
  - Background Color: #d4edda
  - Text Color: #155724
```

5. **Column Formatting** - Para columnas F y I:

```
Highlight:
  - Type: Cell
  - Background Color: #f8d7da
  - Text Color: #721c24
```

---

### Paso 5: Agregar Procesos (15 min)

#### 5.1 Proceso: Fetch Outcome Data

1. **Processing** → **Create Process**

```
Name: FETCH_OUTCOME_DATA
Type: PL/SQL Code
Point: After Header
```

2. **PL/SQL Code**:

```plsql
DECLARE
    l_response CLOB;
    l_url VARCHAR2(500);
BEGIN
    -- Solo ejecutar si hay un outcome seleccionado
    IF :P1_SELECTED_OUTCOME IS NOT NULL THEN
        
        -- Construir URL
        l_url := 'http://tu-servidor:8000/api/outcome-report/' || 
                 :P1_SELECTED_OUTCOME;
        
        -- Llamar API
        l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
            p_url => l_url,
            p_http_method => 'GET',
            p_credential_static_id => 'MOODLE_API_CREDENTIAL'
        );
        
        -- Guardar en item
        :P1_OUTCOME_JSON := l_response;
        
        -- Log de éxito
        APEX_DEBUG.INFO('API Response received for outcome: ' || 
                        :P1_SELECTED_OUTCOME);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.ERROR('Error fetching outcome data: ' || SQLERRM);
        -- No lanzar error, dejar que la página se cargue
        :P1_OUTCOME_JSON := NULL;
END;
```

3. **Execution Options**:

```
Sequence: 10
Point: After Header
Condition Type: Item is NOT NULL
Condition Item: P1_SELECTED_OUTCOME
```

#### 5.2 Proceso: Initialize Default Outcome

1. **Processing** → **Create Process**

```
Name: SET_DEFAULT_OUTCOME
Type: PL/SQL Code
Point: Before Header
```

2. **PL/SQL Code**:

```plsql
BEGIN
    -- Si no hay outcome seleccionado, seleccionar el primero
    IF :P1_SELECTED_OUTCOME IS NULL THEN
        SELECT MIN(id) INTO :P1_SELECTED_OUTCOME
        FROM STUDENT_OUTCOMES;
    END IF;
END;
```

---

### Paso 6: Agregar Dynamic Actions (10 min)

#### 6.1 DA: Refresh on Outcome Change

1. **Dynamic Actions** → **Create**

```
Name: Refresh on Outcome Change
Event: Change
Selection Type: Item
Item: P1_SELECTED_OUTCOME
```

2. **True Action 1**:

```
Action: Execute Server-side Code
PL/SQL Code:
    -- El proceso FETCH_OUTCOME_DATA se ejecutará automáticamente
    NULL;
Items to Submit: P1_SELECTED_OUTCOME
```

3. **True Action 2**:

```
Action: Refresh
Selection Type: Region
Region: E+G Performance by Indicator
```

4. **True Action 3**:

```
Action: Refresh
Selection Type: Region
Region: Assessment Statistics
```

---

### Paso 7: Agregar CSS Personalizado (5 min)

1. **Page** → **CSS** → **Inline**

```css
/* Cards de outcomes */
.outcome-card {
    transition: all 0.3s ease;
    cursor: pointer;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.outcome-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 8px 16px rgba(0,0,0,0.2);
}

/* Compliance badges */
.compliance-high {
    background-color: #28a745;
    color: white;
    padding: 5px 15px;
    border-radius: 20px;
    font-weight: bold;
}

.compliance-medium {
    background-color: #ffc107;
    color: #000;
    padding: 5px 15px;
    border-radius: 20px;
    font-weight: bold;
}

.compliance-low {
    background-color: #dc3545;
    color: white;
    padding: 5px 15px;
    border-radius: 20px;
    font-weight: bold;
}

/* Header personalizado */
.dashboard-header {
    background: linear-gradient(135deg, #003f7f 0%, #0066cc 100%);
    color: white;
    padding: 30px;
    text-align: center;
    border-radius: 8px;
    margin-bottom: 20px;
}

.dashboard-header h1 {
    margin: 0;
    font-size: 28px;
}

.dashboard-header p {
    margin: 10px 0 0 0;
    opacity: 0.9;
}

/* Chart customization */
.apex-chart {
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

/* Interactive Report styling */
.t-Report-cell--highlight-success {
    background-color: #d4edda !important;
    color: #155724 !important;
    font-weight: bold;
}

.t-Report-cell--highlight-danger {
    background-color: #f8d7da !important;
    color: #721c24 !important;
    font-weight: bold;
}
```

---

### Paso 8: Agregar JavaScript (5 min)

1. **Page** → **JavaScript** → **Function and Global Variable Declaration**

```javascript
// Formatear números con separador de miles
function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// Actualizar automáticamente cada 5 minutos
var autoRefreshInterval = setInterval(function() {
    apex.region("chart_region").refresh();
    apex.region("assessment_table").refresh();
}, 300000); // 5 minutos

// Limpiar interval al salir
window.addEventListener('beforeunload', function() {
    clearInterval(autoRefreshInterval);
});

// Color dinámico para barras del gráfico
function getBarColor(percentage) {
    if (percentage >= 70) return '#28a745';
    if (percentage >= 50) return '#ffc107';
    return '#dc3545';
}

// Tooltip personalizado
apex.jQuery(document).ready(function() {
    // Agregar tooltips a elementos
    apex.jQuery('[data-toggle="tooltip"]').tooltip();
});
```

---

## 🎨 Crear Página de Reporte Completo (Modal)

### Paso 9: Crear Modal Page (20 min)

#### 9.1 Crear Página

1. **Create Page** → **Blank Page**

```
Page Number: 2
Name: Outcome Full Report
Page Mode: Modal Dialog
Dialog Width: 800
Dialog Height: 600
```

#### 9.2 Agregar Item de Entrada

```
Name: P2_OUTCOME_ID
Type: Hidden
```

#### 9.3 Agregar Región: Header

1. **Create Region**

```
Title: (leave blank)
Type: Static Content
Template: Blank with Attributes
```

2. **HTML**:

```html
<div class="outcome-header">
    <h2>UNIVERSIDAD TECNOLÓGICA DE BOLÍVAR</h2>
    <h3>FACULTY OF ENGINEERING</h3>
    <h3>STUDENT OUTCOMES &P2_SO_NUMBER.</h3>
</div>

<div class="course-info">
    <div class="info-row">
        <strong>Code:</strong> &P2_COURSE_CODE.
    </div>
    <div class="info-row">
        <strong>Course:</strong> &P2_COURSE_NAME.
    </div>
    <div class="info-row">
        <strong>Professor:</strong> &P2_PROFESSOR.
    </div>
    <div class="info-row">
        <strong>Total Students:</strong> &P2_TOTAL_STUDENTS.
    </div>
</div>
```

#### 9.4 Agregar Región: Compliance Gauge

1. **Create Region**

```
Title: Compliance
Type: Chart
Chart Type: Dial
```

2. **Source**:

```sql
SELECT 
    'Compliance' as label,
    :P2_COMPLIANCE_PERCENTAGE as value,
    100 as maximum
FROM dual
```

3. **Dial Attributes**:

```
Minimum: 0
Maximum: 100
Value Decimal Places: 0
Value Suffix: %

Thresholds:
  - Value: 0-50, Color: #dc3545 (Red)
  - Value: 50-70, Color: #ffc107 (Yellow)
  - Value: 70-100, Color: #28a745 (Green)
```

#### 9.5 Agregar Región: Indicators Table

```sql
SELECT 
    indicator as "Indicator",
    description as "Description",
    CASE assessment_status
        WHEN 'Ok' THEN '<span class="status-ok">✓ Ok</span>'
        ELSE '<span class="status-pending">⚠ Pendiente</span>'
    END as "Assessment",
    CASE student_status
        WHEN 'Ok' THEN '<span class="status-ok">✓ Ok</span>'
        ELSE '<span class="status-pending">⚠ Pendiente</span>'
    END as "Students",
    e_count || '/' || total as "E/Total",
    g_count || '/' || total as "G/Total",
    f_count || '/' || total as "F/Total",
    i_count || '/' || total as "I/Total"
FROM JSON_TABLE(
    :P2_REPORT_JSON,
    '$.indicators[*]'
    COLUMNS (
        indicator VARCHAR2(10) PATH '$.indicator',
        description CLOB PATH '$.description',
        assessment_status VARCHAR2(50) PATH '$.assessment_status',
        student_status VARCHAR2(50) PATH '$.student_status',
        e_count NUMBER PATH '$.evaluations.E',
        g_count NUMBER PATH '$.evaluations.G',
        f_count NUMBER PATH '$.evaluations.F',
        i_count NUMBER PATH '$.evaluations.I',
        total NUMBER PATH '$.evaluations.total'
    )
)
ORDER BY indicator
```

**Column Settings** - Para "Assessment" y "Students":
```
Display As: Display as Text (escape special characters: No)
```

#### 9.6 Agregar Botones

**Button 1:**
```
Label: Download PDF
Position: Create
Action: Redirect to URL
URL: javascript:exportPDF();
```

**Button 2:**
```
Label: Close
Position: Close
Action: Cancel Dialog
```

---

## 🧪 Testing Checklist

### Test 1: API Connection
```
- [ ] Web Credential funciona
- [ ] REST Data Source conecta
- [ ] Sample response se parsea correctamente
```

### Test 2: Dashboard Principal
```
- [ ] Select List carga outcomes
- [ ] Gráfico se muestra correctamente
- [ ] Tabla muestra datos
- [ ] Colores se aplican según thresholds
- [ ] Refresh funciona al cambiar outcome
```

### Test 3: Modal Report
```
- [ ] Modal se abre correctamente
- [ ] Información se muestra completa
- [ ] Gauge chart funciona
- [ ] Tabla de indicadores se carga
- [ ] Botones funcionan
```

### Test 4: Performance
```
- [ ] Página carga en < 3 segundos
- [ ] No hay errores en consola
- [ ] Responsive en móvil
```

---

## 🚀 Deploy a Producción

1. **Exportar aplicación**: App Builder → Export
2. **Importar en producción**: Import → Choose File
3. **Actualizar configuración**:
   - Web Credential → URL producción
   - REST Data Sources → URLs producción
4. **Ejecutar sincronización inicial**:
   ```sql
   BEGIN
       sync_outcomes_from_api();
   END;
   ```
5. **Verificar Job automático**: `SYNC_OUTCOMES_JOB`

---

## 📚 Recursos

- **APEX Documentation**: https://docs.oracle.com/en/database/oracle/apex/
- **REST Services Guide**: https://docs.oracle.com/en/database/oracle/apex/23.1/htmdb/
- **Chart Documentation**: https://apex.oracle.com/pls/apex/apex_pm/r/ut/charts

---

¡Dashboard listo para usar! 🎉
