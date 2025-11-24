-- ============================================================================
-- ORACLE APEX: Scripts SQL para Dashboard de Student Outcomes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLA DE CACHÉ LOCAL (Opcional pero recomendado)
-- ----------------------------------------------------------------------------

-- Tabla principal de outcomes (sincronizada con API)
CREATE TABLE apex_student_outcomes (
    id NUMBER PRIMARY KEY,
    so_number VARCHAR2(50) NOT NULL,
    description_en CLOB,
    description_es CLOB,
    compliance_percentage NUMBER(5,2),
    total_students NUMBER,
    last_sync TIMESTAMP DEFAULT SYSTIMESTAMP,
    json_data CLOB CONSTRAINT ensure_json_outcomes CHECK (json_data IS JSON)
);

-- Tabla de indicadores
CREATE TABLE apex_indicators (
    id NUMBER PRIMARY KEY,
    outcome_id NUMBER REFERENCES apex_student_outcomes(id),
    indicator_letter VARCHAR2(10),
    description_en CLOB,
    e_count NUMBER DEFAULT 0,
    g_count NUMBER DEFAULT 0,
    f_count NUMBER DEFAULT 0,
    i_count NUMBER DEFAULT 0,
    total NUMBER DEFAULT 0,
    last_sync TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Índices para performance
CREATE INDEX idx_indicators_outcome ON apex_indicators(outcome_id);

-- ----------------------------------------------------------------------------
-- 2. VISTA PARA DASHBOARD PRINCIPAL
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_outcomes_dashboard AS
SELECT 
    o.id,
    o.so_number,
    o.description_en as description,
    o.compliance_percentage,
    o.total_students,
    CASE 
        WHEN o.compliance_percentage >= 70 THEN 'high'
        WHEN o.compliance_percentage >= 50 THEN 'medium'
        ELSE 'low'
    END as compliance_level,
    CASE 
        WHEN o.compliance_percentage >= 70 THEN 'u-success'
        WHEN o.compliance_percentage >= 50 THEN 'u-warning'
        ELSE 'u-danger'
    END as css_class,
    ROUND(AVG(i.e_count + i.g_count) / NULLIF(AVG(i.total), 0) * 100, 0) as avg_eg_percentage,
    COUNT(i.id) as total_indicators,
    o.last_sync
FROM apex_student_outcomes o
LEFT JOIN apex_indicators i ON i.outcome_id = o.id
GROUP BY o.id, o.so_number, o.description_en, o.compliance_percentage, 
         o.total_students, o.last_sync;

-- ----------------------------------------------------------------------------
-- 3. VISTA PARA GRÁFICO E+G
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_chart_eg_performance AS
SELECT 
    i.outcome_id,
    o.so_number,
    i.indicator_letter as indicator,
    ROUND((i.e_count + i.g_count) / NULLIF(i.total, 0) * 100, 0) as percentage_eg,
    i.e_count + i.g_count as count_eg,
    i.total,
    CASE 
        WHEN ROUND((i.e_count + i.g_count) / NULLIF(i.total, 0) * 100, 0) >= 70 THEN '#28a745'
        WHEN ROUND((i.e_count + i.g_count) / NULLIF(i.total, 0) * 100, 0) >= 50 THEN '#ffc107'
        ELSE '#dc3545'
    END as bar_color
FROM apex_indicators i
JOIN apex_student_outcomes o ON o.id = i.outcome_id
ORDER BY i.outcome_id, i.indicator_letter;

-- ----------------------------------------------------------------------------
-- 4. VISTA PARA TABLA DE ASSESSMENT
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_assessment_statistics AS
SELECT 
    i.outcome_id,
    o.so_number,
    i.indicator_letter as indicator,
    i.e_count,
    i.g_count,
    i.f_count,
    i.i_count,
    i.total,
    ROUND(i.e_count / NULLIF(i.total, 0) * 100, 1) as e_percentage,
    ROUND(i.g_count / NULLIF(i.total, 0) * 100, 1) as g_percentage,
    ROUND(i.f_count / NULLIF(i.total, 0) * 100, 1) as f_percentage,
    ROUND(i.i_count / NULLIF(i.total, 0) * 100, 1) as i_percentage,
    i.e_count + i.g_count as eg_count,
    ROUND((i.e_count + i.g_count) / NULLIF(i.total, 0) * 100, 1) as eg_percentage
FROM apex_indicators i
JOIN apex_student_outcomes o ON o.id = i.outcome_id
ORDER BY i.outcome_id, i.indicator_letter;

-- ----------------------------------------------------------------------------
-- 5. FUNCIÓN: Fetch API Data
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fetch_api_endpoint(
    p_endpoint VARCHAR2,
    p_api_key VARCHAR2 DEFAULT NULL
) RETURN CLOB
IS
    l_response CLOB;
    l_url VARCHAR2(1000);
BEGIN
    -- Construir URL completa
    l_url := 'http://tu-servidor:8000' || p_endpoint;
    
    -- Hacer request HTTP
    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        p_url => l_url,
        p_http_method => 'GET',
        p_credential_static_id => 'MOODLE_API_CREDENTIAL'
    );
    
    -- Verificar si la respuesta es válida
    IF l_response IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'API returned empty response');
    END IF;
    
    RETURN l_response;
    
EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.ERROR('Error fetching API: ' || SQLERRM);
        RAISE;
END;
/

-- ----------------------------------------------------------------------------
-- 6. PROCEDIMIENTO: Sincronizar Outcomes
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sync_outcomes_from_api(
    p_api_key VARCHAR2 DEFAULT NULL
)
IS
    l_response CLOB;
    l_outcome_json CLOB;
    l_outcome_id NUMBER;
BEGIN
    APEX_DEBUG.INFO('Starting sync_outcomes_from_api');
    
    -- 1. Obtener lista de outcomes
    l_response := fetch_api_endpoint('/api/outcomes', p_api_key);
    
    -- 2. Procesar cada outcome
    FOR outcome IN (
        SELECT 
            jt.id,
            jt.so_number,
            jt.description
        FROM JSON_TABLE(
            l_response, '$[*]'
            COLUMNS (
                id NUMBER PATH '$.id',
                so_number VARCHAR2(50) PATH '$.so_number',
                description CLOB PATH '$.description'
            )
        ) jt
    ) LOOP
        -- 3. Obtener detalle completo del outcome
        l_outcome_json := fetch_api_endpoint(
            '/api/outcome-report/' || outcome.id, 
            p_api_key
        );
        
        -- 4. Extraer compliance percentage
        l_outcome_id := JSON_VALUE(l_outcome_json, '$.outcome_id');
        
        -- 5. Merge en tabla local
        MERGE INTO apex_student_outcomes dst
        USING (
            SELECT 
                outcome.id as id,
                outcome.so_number as so_number,
                outcome.description as description_en,
                outcome.description as description_es,
                TO_NUMBER(JSON_VALUE(l_outcome_json, '$.compliance.percentage')) as compliance_percentage,
                TO_NUMBER(JSON_VALUE(l_outcome_json, '$.students.total')) as total_students,
                l_outcome_json as json_data
            FROM dual
        ) src
        ON (dst.id = src.id)
        WHEN MATCHED THEN
            UPDATE SET 
                dst.so_number = src.so_number,
                dst.description_en = src.description_en,
                dst.compliance_percentage = src.compliance_percentage,
                dst.total_students = src.total_students,
                dst.json_data = src.json_data,
                dst.last_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (id, so_number, description_en, description_es, 
                    compliance_percentage, total_students, json_data)
            VALUES (src.id, src.so_number, src.description_en, src.description_es,
                    src.compliance_percentage, src.total_students, src.json_data);
        
        -- 6. Sincronizar indicadores
        sync_indicators_from_json(outcome.id, l_outcome_json);
        
        APEX_DEBUG.INFO('Synced outcome: ' || outcome.so_number);
    END LOOP;
    
    COMMIT;
    APEX_DEBUG.INFO('Sync completed successfully');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        APEX_DEBUG.ERROR('Error in sync_outcomes_from_api: ' || SQLERRM);
        RAISE;
END;
/

-- ----------------------------------------------------------------------------
-- 7. PROCEDIMIENTO: Sincronizar Indicadores
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sync_indicators_from_json(
    p_outcome_id NUMBER,
    p_json_data CLOB
)
IS
BEGIN
    -- Eliminar indicadores existentes
    DELETE FROM apex_indicators WHERE outcome_id = p_outcome_id;
    
    -- Insertar indicadores desde JSON
    INSERT INTO apex_indicators (
        id, outcome_id, indicator_letter, description_en,
        e_count, g_count, f_count, i_count, total
    )
    SELECT 
        jt.indicator_id,
        p_outcome_id,
        jt.indicator,
        jt.description,
        jt.e_count,
        jt.g_count,
        jt.f_count,
        jt.i_count,
        jt.total
    FROM JSON_TABLE(
        p_json_data, '$.indicators[*]'
        COLUMNS (
            indicator VARCHAR2(10) PATH '$.indicator',
            indicator_id NUMBER PATH '$.indicator_id',
            description CLOB PATH '$.description',
            e_count NUMBER PATH '$.evaluations.E',
            g_count NUMBER PATH '$.evaluations.G',
            f_count NUMBER PATH '$.evaluations.F',
            i_count NUMBER PATH '$.evaluations.I',
            total NUMBER PATH '$.evaluations.total'
        )
    ) jt;
    
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        APEX_DEBUG.ERROR('Error syncing indicators: ' || SQLERRM);
        RAISE;
END;
/

-- ----------------------------------------------------------------------------
-- 8. JOB: Sincronización Automática (Cada 1 hora)
-- ----------------------------------------------------------------------------

BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'SYNC_OUTCOMES_JOB',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN sync_outcomes_from_api(); END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=HOURLY; INTERVAL=1',
        enabled => TRUE,
        comments => 'Sincroniza outcomes desde API REST cada hora'
    );
END;
/

-- ----------------------------------------------------------------------------
-- 9. QUERY PARA APEX CARDS REGION
-- ----------------------------------------------------------------------------

-- Usar esta query en la región Cards del dashboard
SELECT 
    id,
    so_number as title,
    description,
    compliance_percentage,
    total_students,
    compliance_level,
    css_class,
    'Page 2' as target_page,
    id as target_item_value,
    CASE compliance_level
        WHEN 'high' THEN 'fa-check-circle'
        WHEN 'medium' THEN 'fa-exclamation-triangle'
        ELSE 'fa-times-circle'
    END as icon_class
FROM v_outcomes_dashboard
ORDER BY so_number;

-- ----------------------------------------------------------------------------
-- 10. QUERY PARA APEX CHART REGION
-- ----------------------------------------------------------------------------

-- Bar Chart: E+G Performance
SELECT 
    indicator,
    percentage_eg,
    bar_color
FROM v_chart_eg_performance
WHERE outcome_id = :P1_SELECTED_OUTCOME
ORDER BY indicator;

-- ----------------------------------------------------------------------------
-- 11. QUERY PARA INTERACTIVE REPORT
-- ----------------------------------------------------------------------------

-- Assessment Statistics Table
SELECT 
    indicator as "Indicator",
    e_count as "E",
    g_count as "G",
    f_count as "F",
    i_count as "I",
    total as "Total",
    e_percentage || '%' as "E %",
    g_percentage || '%' as "G %",
    f_percentage || '%' as "F %",
    i_percentage || '%' as "I %",
    eg_percentage || '%' as "E+G %"
FROM v_assessment_statistics
WHERE outcome_id = :P1_SELECTED_OUTCOME
ORDER BY indicator;

-- ----------------------------------------------------------------------------
-- 12. FUNCIÓN: Get Compliance Badge HTML
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_compliance_badge(
    p_percentage NUMBER
) RETURN VARCHAR2
IS
    l_html VARCHAR2(500);
    l_class VARCHAR2(50);
    l_label VARCHAR2(50);
BEGIN
    CASE 
        WHEN p_percentage >= 70 THEN
            l_class := 'compliance-badge high';
            l_label := 'High';
        WHEN p_percentage >= 50 THEN
            l_class := 'compliance-badge medium';
            l_label := 'Medium';
        ELSE
            l_class := 'compliance-badge low';
            l_label := 'Low';
    END CASE;
    
    l_html := '<span class="' || l_class || '">' || 
              p_percentage || '% - ' || l_label || 
              '</span>';
              
    RETURN l_html;
END;
/

-- ----------------------------------------------------------------------------
-- 13. PROCEDIMIENTO: Export Report to PDF (usando APEX_UTIL)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE export_outcome_pdf(
    p_outcome_id NUMBER,
    p_filename VARCHAR2 DEFAULT NULL
)
IS
    l_blob BLOB;
    l_filename VARCHAR2(200);
BEGIN
    -- Generar nombre de archivo
    l_filename := NVL(p_filename, 'Outcome_Report_' || p_outcome_id || '.pdf');
    
    -- Generar PDF usando APEX
    l_blob := APEX_UTIL.GET_PRINT_DOCUMENT(
        p_application_id => :APP_ID,
        p_report_query_name => 'OUTCOME_REPORT_' || p_outcome_id,
        p_format => 'PDF'
    );
    
    -- Descargar archivo
    htp.init;
    owa_util.mime_header('application/pdf', FALSE);
    htp.p('Content-Disposition: attachment; filename="' || l_filename || '"');
    htp.p('Content-Length: ' || DBMS_LOB.GETLENGTH(l_blob));
    owa_util.http_header_close;
    wpg_docload.download_file(l_blob);
    
EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.ERROR('Error generating PDF: ' || SQLERRM);
        RAISE;
END;
/

-- ----------------------------------------------------------------------------
-- 14. GRANTS (Si es necesario)
-- ----------------------------------------------------------------------------

GRANT EXECUTE ON sync_outcomes_from_api TO APEX_PUBLIC_USER;
GRANT EXECUTE ON fetch_api_endpoint TO APEX_PUBLIC_USER;
GRANT EXECUTE ON export_outcome_pdf TO APEX_PUBLIC_USER;

GRANT SELECT ON v_outcomes_dashboard TO APEX_PUBLIC_USER;
GRANT SELECT ON v_chart_eg_performance TO APEX_PUBLIC_USER;
GRANT SELECT ON v_assessment_statistics TO APEX_PUBLIC_USER;

-- ----------------------------------------------------------------------------
-- 15. EJEMPLO DE USO
-- ----------------------------------------------------------------------------

-- Sincronizar datos manualmente
BEGIN
    sync_outcomes_from_api(p_api_key => 'tu_api_key');
END;
/

-- Ver resultados
SELECT * FROM v_outcomes_dashboard;
SELECT * FROM v_chart_eg_performance WHERE outcome_id = 1;
SELECT * FROM v_assessment_statistics WHERE outcome_id = 1;

-- ----------------------------------------------------------------------------
-- FIN DEL SCRIPT
-- ----------------------------------------------------------------------------
