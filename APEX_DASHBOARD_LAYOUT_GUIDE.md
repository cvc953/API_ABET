# Guía de Layout APEX – Resultado como la captura

Esta guía te lleva paso a paso para construir una página igual a la captura: filtro arriba, fila de 4 tarjetas (Compliance, Missing, Total Students, Program), una fila con gráfico de barras a la izquierda y tabla de indicadores a la derecha, y dos cajas de "Continuous Improvement" al final.

---

## 1) Objetivo del layout

Estructura de la página:
- Fila A: Select List (SO) en la esquina superior izquierda.
- Fila B: 4 tarjetas resumen (Compliance, Missing, Total Students, Program).
- Fila C: Dos columnas
  - Izquierda (≈ 2/3): Bar Chart "Outcome Performance" con etiquetas.
  - Derecha (≈ 1/3): Tabla "Indicators" con badges de estado y columnas E/G/F.
- Fila D: Dos cajas de "Continuous Improvement" lado a lado.

---

## 2) Prerrequisitos

- APEX con Universal Theme.
- Origen de datos listo (REST Data Sources o vistas SQL locales):
  - STUDENT_OUTCOMES (id, so_number, description)
  - OUTCOME_CHART_DATA (indicator, percentage_eg) por outcome
  - OUTCOME_INDICATORS (indicator, description, assessment_status, e_count, g_count, f_count) por outcome
  - Métricas para tarjetas (compliance%, missing%, total students, program)

Si usas REST, asegúrate de que cada REST Data Source tiene su parámetro OUTCOME_ID y que responde 200 OK.

---

## 3) Crear la Página 1

App Builder → Create → Page → Blank Page
- Page Name: Student Outcomes Dashboard
- Page Number: 1

Usaremos Grid de APEX para cuatro filas (A–D). Puedes crear regiones dentro de cada fila.

---

## 4) Item de página (filtro)

Crea `P1_SELECTED_OUTCOME` (Select List):
- Type: Select List
- Label: SO
- List of Values (SQL):
```sql
SELECT id AS return_value,
       so_number || ' - ' || SUBSTR(description,1,60) AS display_value
FROM STUDENT_OUTCOMES
ORDER BY so_number;
```
- Null Display Value: Seleccionar Outcome…
- Colócalo en la Fila A (arriba a la izquierda).

---

## 5) Fila B: Tarjetas Summary

Crea una región "Static Content" con Static ID `summary_cards` y pega este HTML:
```html
<div class="row summary-cards">
  <div class="col-md-3">
    <div class="stat-card stat-green">
      <div class="stat-title">Compliance</div>
      <div class="stat-value">&P1_COMPLIANCE.</div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="stat-card stat-orange">
      <div class="stat-title">Missing</div>
      <div class="stat-value">&P1_MISSING.</div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="stat-card stat-blue">
      <div class="stat-title">Total Students</div>
      <div class="stat-value">&P1_TOTAL_STUDENTS.</div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="stat-card stat-gray">
      <div class="stat-title">Program</div>
      <div class="stat-value">&P1_PROGRAM.</div>
    </div>
  </div>
</div>
```
Crea los items `P1_COMPLIANCE`, `P1_MISSING`, `P1_TOTAL_STUDENTS`, `P1_PROGRAM` (Display Only) y un proceso PL/SQL (Before Header o After Refresh) para llenarlos, por ejemplo:
```plsql
DECLARE
  l_comp NUMBER;
  l_miss NUMBER;
  l_total NUMBER;
  l_prog VARCHAR2(200);
BEGIN
  SELECT ROUND(AVG(compliance_percent)),
         ROUND(AVG(missing_percent))
    INTO l_comp, l_miss
    FROM outcomes_summary
   WHERE outcome_id = :P1_SELECTED_OUTCOME;

  SELECT COUNT(*) INTO l_total
    FROM evaluations
   WHERE outcome_id = :P1_SELECTED_OUTCOME;

  SELECT program_name INTO l_prog
    FROM outcomes_program
   WHERE outcome_id = :P1_SELECTED_OUTCOME;

  :P1_COMPLIANCE := NVL(l_comp,0) || '%';
  :P1_MISSING := NVL(l_miss,0) || '%';
  :P1_TOTAL_STUDENTS := NVL(l_total,0);
  :P1_PROGRAM := NVL(l_prog,'—');
END;
```

---

## 6) Fila C – Izquierda: Bar Chart (Outcome Performance)

Crea una región Chart → Bar Chart, Static ID `outcome_chart`.
- Source Type: SQL Query (o REST OUTCOME_CHART_DATA).
- SQL ejemplo:
```sql
SELECT indicator   AS label,
       percentage_eg AS value
  FROM outcome_chart_view
 WHERE outcome_id = :P1_SELECTED_OUTCOME
 ORDER BY indicator;
```
- Series: Label = LABEL, Value = VALUE
- Y Axis: min 0, max 100
- Mostrar etiquetas: si tu versión soporta data labels, actívalo. Si no, puedes añadir JS (ver sección 9).

Coloca esta región en una columna de ancho ~8/12 (dos tercios).

---

## 7) Fila C – Derecha: Tabla de Indicators

Crea una región "Interactive Report" con Static ID `indicators_table`.
- Source Type: SQL Query
- SQL ejemplo con badges HTML:
```sql
SELECT indicator,
       description,
       CASE 
         WHEN assessment_status IN ('Ok','OK') THEN '<span class="badge badge-ok">Ok</span>'
         WHEN assessment_status IN ('Pen','Pending') THEN '<span class="badge badge-pen">Pending</span>'
         ELSE '<span class="badge badge-na">N/A</span>'
       END AS assessment,
       e_count AS e,
       g_count AS g,
       f_count AS f
  FROM outcome_indicators_view
 WHERE outcome_id = :P1_SELECTED_OUTCOME
 ORDER BY indicator;
```
- Para la columna `ASSESSMENT`: setea "Escape special characters" = No para que renderice HTML.
- Centra E/G/F si quieres (Alignment = Center).

Pon esta región en una columna de ancho ~4/12 (un tercio).

---

## 8) Fila D – Cajas de Continuous Improvement

Crea dos regiones "Static Content", lado a lado (col-md-6 cada una). HTML ejemplo:
```html
<div class="ci-box">
  <span class="ci-chip ci-ok"><i class="fa fa-check-circle"></i> Current Results</span>
  <span class="ci-chip ci-outline"><i class="fa fa-clipboard-list"></i> Activities Applied</span>
</div>
```
Y en la segunda:
```html
<div class="ci-box">
  <span class="ci-chip ci-ok"><i class="fa fa-check-circle"></i> Current Results</span>
  <span class="ci-chip ci-warn"><i class="fa fa-lightbulb"></i> Actions Proposed</span>
</div>
```

---

## 9) CSS (pegar en Page → CSS → Inline)

```css
/* Summary cards */
.summary-cards .stat-card{ border-radius:8px; padding:18px; color:#fff; margin-bottom:12px; box-shadow:0 1px 3px rgba(0,0,0,.08); }
.stat-title{ font-size:16px; opacity:.9; }
.stat-value{ font-size:32px; font-weight:700; margin-top:6px; }
.stat-green{ background:#2ecc71; }
.stat-orange{ background:#f4a261; }
.stat-blue{ background:#6fa8dc; }
.stat-gray{ background:#f8f9fa; color:#111; }

/* Indicators badges */
.badge{ display:inline-block; padding:6px 10px; border-radius:6px; font-weight:600; }
.badge-ok{ background:#d4edda; color:#155724; }
.badge-pen{ background:#ffe3b8; color:#7a4f19; }
.badge-na{ background:#e9ecef; color:#495057; }

/* Continuous Improvement chips */
.ci-box{ padding:10px; background:#fff; border:1px solid #e9ecef; border-radius:8px; }
.ci-chip{ display:inline-block; padding:8px 12px; border-radius:20px; margin-right:8px; font-weight:600; }
.ci-ok{ background:#e6f4ea; color:#1e7e34; }
.ci-outline{ background:#fff; color:#333; border:1px solid #e9ecef; }
.ci-warn{ background:#fff3cd; color:#856404; }

/* IR table fine-tuning */
.apexir_DATA td{ vertical-align: middle; }
```

---

## 10) Dynamic Actions (refrescos)

Crea una DA "Refresh on Outcome Change":
- Event: Change
- Selection Type: Item(s) → `P1_SELECTED_OUTCOME`
- True Actions:
  1) Refresh → Region: `outcome_chart`
  2) Refresh → Region: `indicators_table`
- En cada región (Chart y IR) asegúrate de poner en "Page Items to Submit": `P1_SELECTED_OUTCOME`.

---

## 11) Opcional: JavaScript para etiquetas en barras

Dependiendo de la versión de APEX (Chart.js / ApexCharts), puedes necesitar activar data labels. Si tu propiedad de Data Labels no existe o no funciona, añade código en Page → JavaScript → Execute when Page Loads ajustado a tu engine. (Si me indicas tu versión de APEX te doy el snippet exacto.)

---

## 12) Checklist final

- [ ] P1_SELECTED_OUTCOME (Select List) creado y con LOV válida.
- [ ] Tarjetas muestran valores (P1_COMPLIANCE, P1_MISSING, P1_TOTAL_STUDENTS, P1_PROGRAM) llenados por proceso PL/SQL.
- [ ] Chart: SQL/REST devuelve indicator, percentage_eg; Y 0–100; refresca al cambiar el filtro.
- [ ] Indicators (IR): muestra badges HTML; columna assessment con Escape=No; E/G/F centradas.
- [ ] Dos cajas "Continuous Improvement" creadas y estilizadas.
- [ ] DA de Refresh funcionando; Page Items to Submit configurados.
- [ ] Visual igual o muy cercana a la captura en desktop y bien en móvil.

---

## 13) Troubleshooting

- Chart no cambia al seleccionar SO: añade `P1_SELECTED_OUTCOME` en Page Items to Submit de la región y revisa la DA de Refresh.
- Badges no se ven: marca "Escape special characters = No" en la columna assessment.
- Tarjetas no muestran valores: valida el proceso PL/SQL y que items estén en Session State.
- Colores/espacios distintos: ajusta CSS (márgenes y paddings) según tu tema.

---

## 14) Opción 1 (sin PL/SQL): Tarjetas con REST Data Source y Post-Processing

Esta opción construye las 4 tarjetas "Compliance / Missing / Total Students / Program" solo con configuración, sin procesos PL/SQL.

### 14.1 Crear REST Data Source OUTCOME_SUMMARY

1) Shared Components → REST Data Sources → Create → Simple HTTP
2) Name: OUTCOME_SUMMARY
3) URL Endpoint: `http://20.81.213.16:8000/api/outcome-report/:OUTCOME_ID`
4) Parameters → Add
   - Name: OUTCOME_ID
   - Value (temporal para Test): 1
5) Authentication
   - Si tu Credential funciona: selecciónala
   - Si no: Request → Static HTTP Headers → Add → Name: `X-API-Key` Value: `TU_API_KEY`
6) Test → debe responder 200 OK y JSON

### 14.2 Mapear columnas base del JSON

En OUTCOME_SUMMARY → Response → Columns (Row Selector: `$`):
- `compliance_percentage` (NUMBER) → Path: `$.compliance.percentage`
- `students_total` (NUMBER) → Path: `$.students.total`
- `program_name_1` (VARCHAR2(200)) → Path: `$.program.name`  (si existe)
- `program_name_2` (VARCHAR2(200)) → Path: `$.course.program` (alternativa si el JSON usa `course`)

### 14.3 Post-Processing (transformar a 4 filas)

Habilita Post-Processing (si tu versión lo soporta):

SQL Query:
```sql
select 'Compliance' as title,
       to_char(compliance_percentage) || '%' as value,
       'stat-green' as css
  from #APEX$SOURCE#
union all
select 'Missing' as title,
       to_char(100 - nvl(compliance_percentage,0)) || '%' as value,
       'stat-orange' as css
  from #APEX$SOURCE#
union all
select 'Total Students' as title,
       to_char(nvl(students_total,0)) as value,
       'stat-blue' as css
  from #APEX$SOURCE#
union all
select 'Program' as title,
       nvl(program_name_1, program_name_2) as value,
       'stat-gray' as css
  from #APEX$SOURCE#
```

Resultado: el REST DS entregará 4 filas (una por tarjeta) con columnas TITLE, VALUE, CSS.

### 14.4 Crear la Región Cards basada en REST

1) Page Designer → Create Region → Type: Cards → Title: Summary (REST)
2) Source Type: REST Source → OUTCOME_SUMMARY
3) Parameters (en la región): OUTCOME_ID = `:P1_SELECTED_OUTCOME`
4) Advanced → Page Items to Submit: `P1_SELECTED_OUTCOME`
5) Attributes → Card → Column Mapping:
   - Title: `TITLE`
   - Body: `VALUE`
   - CSS Classes Column (si existe): `CSS`
6) Layout: 4 columnas (Cards por fila) → usa Template Options para ajustar la grilla.

Con esto ya no necesitas el HTML manual de las tarjetas. Si prefieres mantener tu HTML, puedes dejar la región Cards para producir datos y usar otra región para mostrarlos, pero lo anterior es suficiente.

### 14.5 Refresco por filtro (DA)

DA "Refresh on Outcome Change":
- Event: Change → Item: `P1_SELECTED_OUTCOME`
- True Action: Refresh → Region: Summary (REST)
- Asegúrate de que la región tenga `P1_SELECTED_OUTCOME` en Items to Submit.

### 14.6 Variantes si no tienes Post-Processing en tu versión

- Crea 4 regiones Cards separadas, cada una con OUTCOME_SUMMARY como fuente y su propio Post-Processing sencillo, por ejemplo:
  - Compliance: `select to_char(compliance_percentage)||'%' as value from #APEX$SOURCE#`
  - Missing:   `select to_char(100 - nvl(compliance_percentage,0))||'%' as value from #APEX$SOURCE#`
  - Total:     `select to_char(nvl(students_total,0)) as value from #APEX$SOURCE#`
  - Program:   `select nvl(program_name_1, program_name_2) as value from #APEX$SOURCE#`
- En cada Cards: Title fijo (Compliance / Missing / …), Body = `VALUE`, y CSS fijo por tarjeta (stat-green, etc.).

Si quieres, puedo adaptar los SQL exactamente a tu esquema (dime nombres de tablas/campos) o generar los procesos PL/SQL On Demand para cargar datos desde tu API REST.
