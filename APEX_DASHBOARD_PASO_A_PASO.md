# Dashboard APEX – Paso a paso (solo REST Source)

Este tutorial te guía, clic a clic, para construir un dashboard igual a la captura: selector arriba, 4 tarjetas (Compliance, Missing, Total Students, Program), gráfico de barras a la izquierda, tabla de indicadores a la derecha y dos cajas de "Continuous Improvement" al final. No usaremos tablas locales ni procesos PL/SQL: únicamente regiones con Source Type = REST Data Source (con Post-Processing cuando haga falta).

---

## 0) Qué necesitas antes

- Oracle APEX 21.x o superior (Universal Theme)
- Tu API REST funcionando y accesible desde APEX
- API Key por header `X-API-Key`
- Endpoints típicos (ajústalos a tus URLs):
  - `GET /api/outcomes` → lista (id, so_number, description)
  - `GET /api/outcome-report/:OUTCOME_ID` → resumen + indicadores
  - `GET /api/outcome-chart/:OUTCOME_ID` → gráfico (indicator, percentage_eg)

> Si tus rutas/JSON cambian, el tutorial sigue siendo igual; solo ajusta los JSON Path.

---

## 1) Crea la credencial web (API Key) – 3 min

App Builder → tu aplicación → Shared Components → Web Credentials → Create

- Name: `MOODLE_API_CREDENTIAL`
- Authentication Type: HTTP Header
- Header Name: `X-API-Key`
- Header Value: `TU_API_KEY`
- Create

---

## 2) Crea los REST Data Sources – 10–15 min

Shared Components → REST Data Sources → Create → Simple HTTP

1) `STUDENT_OUTCOMES`
- URL Endpoint: `http://tu-servidor:8000/api/outcomes`
- Credentials: `MOODLE_API_CREDENTIAL`
- Method: GET → Discover/Test → Create Data Profile
- Verifica columnas: `ID (NUMBER)`, `SO_NUMBER (VARCHAR2)`, `DESCRIPTION (VARCHAR2)`

2) `OUTCOME_REPORT`
- URL Endpoint: `http://tu-servidor:8000/api/outcome-report/:OUTCOME_ID`
- Parameters → Add: `OUTCOME_ID` (URL Path Parameter, NUMBER)
- Credentials: `MOODLE_API_CREDENTIAL`
- Test con `OUTCOME_ID = 1` → Create Data Profile

3) `OUTCOME_CHART_DATA`
- URL Endpoint: `http://tu-servidor:8000/api/outcome-chart/:OUTCOME_ID`
- Parameters: `OUTCOME_ID`
- Credentials: `MOODLE_API_CREDENTIAL`
- Test → Create Data Profile
  - Si tu JSON trae un arreglo `chart_data`, define Row Selector: `$.chart_data[*]` con columnas `indicator` y `percentage_eg`.

4) `OUTCOME_INDICATORS` (usando outcome-report con selector de filas)
- URL Endpoint: `http://tu-servidor:8000/api/outcome-report/:OUTCOME_ID`
- Parameters: `OUTCOME_ID`
- Response → Columns:
  - Row Selector: `$.indicators[*]`
  - Columns:
    - `indicator` → `$.indicator`
    - `description` → `$.description`
    - `assessment_status` → `$.assessment_status`
    - `e` → `$.evaluations.E`
    - `g` → `$.evaluations.G`
    - `f` → `$.evaluations.F`
- Test → deben salir varias filas (una por indicador)

> Tip: si el profile no calza con tu JSON, abre Sample Response y ajusta los JSON Path. Todo seguirá siendo REST: no necesitas crear vistas/tablas.

---

## 3) Crea la página del Dashboard – 2 min

Application → Create Page → Blank Page
- Page Name: `Student Outcomes Dashboard` (Page 1)

---

## 4) Filtro: Select List (SO) – 3 min (LOV desde REST)

En la página 1 → Create Region → Static Content (Title: `Filters`).

Dentro de esa región → Create Page Item:
- Name: `P1_SELECTED_OUTCOME`
- Type: Select List
- Label: `SO`
- List of Values: `REST Source`
  - REST Data Source: `STUDENT_OUTCOMES`
  - Display Column: `SO_NUMBER`
  - Return Column: `ID`
- Null Display Value: `Selecciona un Outcome…`

No marques Submit on change; refrescaremos con Acciones Dinámicas.

### ¿No ves la opción "REST Source" en la LOV del item?

Algunas versiones de APEX no muestran "REST Source" directamente en los items. En ese caso crea primero un **Shared LOV** basado en tu REST Data Source y luego asígnalo al item.

1) Shared Components → **List of Values** → **Create**
2) Elige **From REST Data Source** (o "From Web Source" en versiones antiguas)
3) Selecciona el DS: `STUDENT_OUTCOMES`
4) Mapea columnas:
  - Display Column = `SO_NUMBER`
  - Return Column  = `ID`
  - (Si te pide Row Selector y tu JSON es un arreglo en la raíz, usa: `$[*]`)
5) Name: `LOV_STUDENT_OUTCOMES` → Create
6) Vuelve al item `P1_SELECTED_OUTCOME` → List of Values → **Type: Shared Component** → **List of Values** = `LOV_STUDENT_OUTCOMES`

Con esto sigues 100% REST, solo que la LOV vive como componente compartido.

---

## 5) Tarjetas Summary – 8–10 min (REST con Post-Processing)

La forma más simple es generar 4 filas (una por tarjeta) desde `OUTCOME_REPORT` usando Post-Processing.

- Crea una región: Type `Cards`, Title `Summary`.
- Source Type: `REST Source` → `OUTCOME_REPORT`
- Parameters (Region): `OUTCOME_ID = :P1_SELECTED_OUTCOME`
- Advanced → `Page Items to Submit`: `P1_SELECTED_OUTCOME`
- **IMPORTANTE:** El Post-Processing en muchas versiones de APEX tiene limitaciones con `union all` y funciones complejas. **La forma más confiable es crear 4 regiones Cards separadas** (una por tarjeta), cada una con Source Type = REST (`OUTCOME_REPORT`) y su propio Post-Processing simple:

  **OPCIÓN A: Con columnas mapeadas del REST (sin Post-Processing, más simple)**
  
  1. En REST Data Source `OUTCOME_REPORT` → Response → Columns, mapea:
     - `COMPLIANCE_PERCENTAGE` (NUMBER) → JSON Path: `$.compliance.percentage`
     - `STUDENTS_TOTAL` (NUMBER) → `$.students.total`
     - `PROGRAM_NAME` (VARCHAR2) → `$.program.name`
  
  2. Crea 4 regiones Cards:
     - **Card 1 - Compliance:** Title fijo: "Compliance", Body: `&COMPLIANCE_PERCENTAGE.%`, CSS: `stat-green`
     - **Card 2 - Missing:** Title: "Missing", Body: calculado con función SQL en columna (ver abajo), CSS: `stat-orange`
     - **Card 3 - Total Students:** Title: "Total Students", Body: `&STUDENTS_TOTAL.`, CSS: `stat-blue`
     - **Card 4 - Program:** Title: "Program", Body: `&PROGRAM_NAME.`, CSS: `stat-gray`
  
  > Para "Missing", agrega una columna calculada en el Data Profile o usa Display Only item: `100 - &COMPLIANCE_PERCENTAGE.`

  **OPCIÓN B: Con Post-Processing (prueba estas variantes)**
  
  Si prefieres Post-Processing, **prueba estos nombres de variable en orden** hasta que uno funcione:

  **Variante 1:** `#APEX$SOURCE#` (sin `_DATA`)
  ```sql
  select 'Compliance' as title,
         JSON_VALUE(#APEX$SOURCE#, '$.compliance.percentage')||'%' as value
  from dual
  ```

  **Variante 2:** Sin `#` (versiones antiguas)
  ```sql
  select 'Compliance' as title,
         JSON_VALUE(APEX$SOURCE, '$.compliance.percentage')||'%' as value
  from dual
  ```

  **Variante 3:** Referencia directa a columna del REST (si ya mapeaste `COMPLIANCE_PERCENTAGE`)
  ```sql
  select 'Compliance' as title,
         COMPLIANCE_PERCENTAGE||'%' as value
  from #APEX$SOURCE#
  ```

  > **Cada región:** Source Type = REST Source → `OUTCOME_REPORT`, Parameters: `OUTCOME_ID = :P1_SELECTED_OUTCOME`, Items to Submit: `P1_SELECTED_OUTCOME`. Layout: 4 regiones en fila (col-3 cada una).
  >
  > **Recomendación:** Usa **Opción A** (mapear columnas) si tu versión de APEX da problemas con Post-Processing.
- Card Attributes:
  - Title: `TITLE`
  - Body: `VALUE`
  - CSS Classes Column: `CSS`
- Layout: 4 columnas (Cards per Row = 4)

CSS opcional (Page → CSS → Inline):
```css
.stat-green{background:#2ecc71;color:#fff}
.stat-orange{background:#f4a261;color:#fff}
.stat-blue{background:#6fa8dc;color:#fff}
.stat-gray{background:#f8f9fa;color:#111}
.t-Card{border-radius:8px}
.t-Card-wrap{box-shadow:0 1px 3px rgba(0,0,0,.08)}
```

> Alternativa: crear 4 regiones Cards pequeñas, cada una con Post-Processing que devuelva 1 fila. Seguimos 100% REST.

---

## 6) Gráfico de Barras “Outcome Performance” – 5–7 min

- Create Region → Type: `Chart` → Chart Type: `Bar` → Title: `Outcome Performance`
- Source Type: `REST Data Source` → `OUTCOME_CHART_DATA`
- Parameters: `OUTCOME_ID = :P1_SELECTED_OUTCOME`
- Advanced → Items to Submit: `P1_SELECTED_OUTCOME`
- Series mapping:
  - Label = `indicator`
  - Value = `percentage_eg`
- Y Axis: Min 0; Max 100; Show Data Labels = Yes
- Colócalo en la columna izquierda (Grid: 8/12).

> Si tu DS usa Row Selector `$.chart_data[*]`, asegúrate de que las columnas `indicator` y `percentage_eg` existen.

---

## 7) Tabla “Indicators” con semáforos – 7–10 min (REST con Post-Processing)

- Create Region → Type: `Interactive Report` → Title: `Indicators`
- Source Type: `REST Data Source` → `OUTCOME_INDICATORS`
- Parameters: `OUTCOME_ID = :P1_SELECTED_OUTCOME`
- Advanced → Items to Submit: `P1_SELECTED_OUTCOME`
- Post-Processing (en la región) para generar una columna ya formateada sin tocar la API:
  ```sql
  select indicator,
         description,
         case 
           when assessment_status in ('Ok','OK') then '<span class="badge badge-ok">Ok</span>'
           when assessment_status like 'Pen%' then '<span class="badge badge-pen">Pending</span>'
           else '<span class="badge badge-na">N/A</span>'
         end as assessment_badge,
         e,
         g,
         f
  from #APEX$SOURCE#
  order by indicator
  ```
- Columnas (en el informe):
  - `INDICATOR` (Indicator)
  - `DESCRIPTION` (Description)
  - `ASSESSMENT_BADGE` (Assessment) → Display As: Text; **Escape special characters = No**
  - `E`, `G`, `F` (centradas)
- CSS (Page → CSS → Inline):
  ```css
  .badge{display:inline-block;padding:6px 10px;border-radius:6px;font-weight:600}
  .badge-ok{background:#d4edda;color:#155724}
  .badge-pen{background:#ffe3b8;color:#7a4f19}
  .badge-na{background:#e9ecef;color:#495057}
  ```
- Colócala a la derecha (Grid: 4/12).

---

## 8) Cajas “Continuous Improvement” – 3 min

Crea dos regiones `Static Content` lado a lado (6/12 + 6/12).

HTML (Caja 1):
```html
<div class="ci-box">
  <span class="ci-chip ci-ok"><i class="fa fa-check-circle"></i> Current Results</span>
  <span class="ci-chip ci-outline"><i class="fa fa-clipboard-list"></i> Activities Applied</span>
</div>
```
HTML (Caja 2):
```html
<div class="ci-box">
  <span class="ci-chip ci-ok"><i class="fa fa-check-circle"></i> Current Results</span>
  <span class="ci-chip ci-warn"><i class="fa fa-lightbulb"></i> Actions Proposed</span>
</div>
```
CSS:
```css
.ci-box{padding:10px;background:#fff;border:1px solid #e9ecef;border-radius:8px}
.ci-chip{display:inline-block;padding:8px 12px;border-radius:20px;margin-right:8px;font-weight:600}
.ci-ok{background:#e6f4ea;color:#1e7e34}
.ci-outline{background:#fff;color:#333;border:1px solid #e9ecef}
.ci-warn{background:#fff3cd;color:#856404}
```

---

## 9) Acciones Dinámicas (refrescar por filtro) – 2 min

Dynamic Actions → Create → `Refresh on Outcome Change`
- Event: `Change`
- Selection Type: `Item` → `P1_SELECTED_OUTCOME`
- True Actions (en orden):
  1) Refresh → Region: `Summary` (Cards)
  2) Refresh → Region: `Outcome Performance` (Chart)
  3) Refresh → Region: `Indicators` (IR)

Asegúrate de que cada región dependiente tiene `P1_SELECTED_OUTCOME` en “Page Items to Submit”.

---

## 10) Layout como la captura – 2 min

- Fila 1: Filters (12/12)
- Fila 2: Summary cards (12/12, 4 columnas)
- Fila 3: Chart (8/12) + Indicators (4/12)
- Fila 4: Dos cajas (6/12 + 6/12)

> Si ves espacios distintos, ajusta márgenes/paddings en el CSS anterior.

---

## 11) Prueba rápida (checklist)

- [ ] El Select List carga SOs (tiene valores)
- [ ] Al cambiar SO se refrescan Cards, Chart y Indicators
- [ ] El gráfico muestra 0–100 y etiquetas
- [ ] La columna Assessment muestra badges (sin escapar HTML)
- [ ] Las dos cajas se ven lado a lado

---

## 12) Problemas comunes y solución

- No cambia el Chart/Tabla al cambiar SO
  - Falta `P1_SELECTED_OUTCOME` en Items to Submit de la región
  - La Dynamic Action no apunta a las regiones correctas
- El REST falla o devuelve vacío
  - Test en el Data Source con `OUTCOME_ID=1`
  - Verifica `MOODLE_API_CREDENTIAL` y CORS
- La tabla no trae filas o no se ve el badge
  - Revisa Row Selector `$.indicators[*]` y paths `$.evaluations.E/G/F`
  - Verifica que agregaste el Post-Processing de la región para crear `ASSESSMENT_BADGE` y que la columna tiene “Escape = No”
- Los porcentajes superan 100 o aparecen null
  - Ajusta JSON Path y usa NVL/0; fija Y Axis 0–100

---

## 13) Bonus (opcional, 100% REST)

- Modal "Full Report": crea una página Modal y usa regiones con Source Type = REST (`OUTCOME_REPORT`) para mostrar cabecera, un Dial Chart (valor = `$.compliance.percentage`) y una tabla de indicadores (Row Selector `$.indicators[*]`).
- Auto-refresh del dashboard: JavaScript en la página (no afecta el enfoque REST):
  ```javascript
  setInterval(function(){
    apex.region("Summary").refresh();
    apex.region("Outcome Performance").refresh();
    apex.region("Indicators").refresh();
  }, 300000); // cada 5 minutos
  ```

---

## 14) Tiempo estimado

- Configuración inicial (credencial + DS): 15–20 min
- Página y regiones: 15–20 min
- Estilos y pruebas: 5–10 min

Total: ~45 min la primera vez (luego es mucho más rápido).

---

¿Quieres que agregue la página modal “Full Report” ya configurada (solo REST) según tu JSON exacto? Pásame un ejemplo real del `outcome-report` y lo dejo listo.

---

## Anexo A — Cómo mapear columnas (REST) paso a paso

Este anexo te guía pantalla por pantalla para que cada REST Data Source exponga columnas listas para usar en Cards/Chart/Report, sin SQL ni PL/SQL.

### A.1 STUDENT_OUTCOMES (para el Select List)
1) Shared Components → REST Data Sources → STUDENT_OUTCOMES → Response → Columns
2) Si tu endpoint devuelve un arreglo así:
```json
[
  {"id":1,"so_number":"SO A","description":"..."},
  {"id":2,"so_number":"SO B","description":"..."}
]
```
configura:
- Row Selector: `$[*]`
- Columns:
  - ID (NUMBER) → Path: `$.id`
  - SO_NUMBER (VARCHAR2) → Path: `$.so_number`
  - DESCRIPTION (VARCHAR2/CLOB) → Path: `$.description`
3) Test → deben aparecer filas. Con esto podrás crear una LOV REST (Display=SO_NUMBER, Return=ID).

### A.2 OUTCOME_REPORT (para las 4 tarjetas y más datos)
1) REST Data Sources → OUTCOME_REPORT → Response → Columns
2) Paths típicos (ajústalos a tu JSON real):
- COMPLIANCE_PERCENTAGE (NUMBER) → `$.compliance.percentage`
- STUDENTS_TOTAL (NUMBER) → `$.students.total`
- PROGRAM_NAME (VARCHAR2) → `$.program.name` (o `$.course.program` si tu JSON usa `course`)
3) Guarda. Ya puedes usar en Cards sin Post‑Processing:
- Compliance Body: `&COMPLIANCE_PERCENTAGE.%`
- Missing Body: `&COMPLIANCE_PERCENTAGE.` → en la tarjeta escribe `100 - &COMPLIANCE_PERCENTAGE.` (o crea una columna derivada en el Data Source si tu versión lo permite)
- Total Students Body: `&STUDENTS_TOTAL.`
- Program Body: `&PROGRAM_NAME.`

### A.3 OUTCOME_INDICATORS (tabla “Indicators”)
Si extraes indicadores del mismo `outcome-report`, crea un DS separado apuntando al mismo endpoint con selector de filas.
1) REST Data Sources → OUTCOME_INDICATORS → Response → Columns
2) Configura Row Selector según tu JSON. Si viene así:
```json
{
  "outcome_id": 1,
  "indicators": [
    {
      "indicator": "A",
      "description": "...",
      "assessment_status": "Ok",
      "evaluations": {"E":6, "G":2, "F":8}
    }
  ]
}
```
usa:
- Row Selector: `$.indicators[*]`
- Columns:
  - INDICATOR (VARCHAR2) → `$.indicator`
  - DESCRIPTION (CLOB/VARCHAR2) → `$.description`
  - ASSESSMENT_STATUS (VARCHAR2) → `$.assessment_status`
  - E (NUMBER) → `$.evaluations.E`
  - G (NUMBER) → `$.evaluations.G`
  - F (NUMBER) → `$.evaluations.F`
3) En la región del reporte (IR/Classic):
- Para la columna `ASSESSMENT_STATUS`, pon “Escape special characters = No” y, si quieres badges, usa Template/HTML Expression con `<span class="badge ...">…</span>`.

### A.4 OUTCOME_CHART_DATA (gráfico de barras)
Si tu endpoint específico del gráfico responde así:
```json
{
  "outcome_id":1,
  "chart_data":[
    {"indicator":"A","percentage_eg":95,"count_eg":12,"total":13},
    {"indicator":"B","percentage_eg":96,"count_eg":26,"total":27}
  ]
}
```
entonces:
1) REST Data Sources → OUTCOME_CHART_DATA → Response → Columns
2) Row Selector: `$.chart_data[*]`
3) Columns:
- INDICATOR (VARCHAR2) → `$.indicator`
- PERCENTAGE_EG (NUMBER) → `$.percentage_eg`
- COUNT_EG (NUMBER) → `$.count_eg`
- TOTAL (NUMBER) → `$.total`
4) En la región Chart (Bar):
- Label Column = INDICATOR
- Value Column = PERCENTAGE_EG
- Y Axis: 0–100; Show Data Labels = Yes

### A.5 Parámetros y pruebas
- En cada región que dependa del filtro, pon Parameters: `OUTCOME_ID = :P1_SELECTED_OUTCOME` y “Page Items to Submit” = `P1_SELECTED_OUTCOME`.
- En cada REST Data Source, usa “Test” con un OUTCOME_ID real para validar paths.

### A.6 Si tu JSON tiene otra forma
Usa estas guías:
- Array raíz → Row Selector: `$[*]`
- Array dentro de un nodo → `$.nodo[*]`
- Campo simple → `$.campo`
- Campo anidado → `$.nodo1.nodo2.campo`
- Si una propiedad a veces no existe, mapea la principal (ej. `$.program.name`) y en la Card usa `NVL` en Post‑Processing o una alternativa en el Body (ej. mostrar "—").

---

¿Quieres que valide tus JSON reales y te deje los paths exactos listos para copiar? Pásame 1–2 ejemplos de respuesta de tus endpoints y lo adapto línea por línea.
