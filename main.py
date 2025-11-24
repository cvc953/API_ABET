from fastapi import FastAPI, HTTPException, Depends, Security, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security.api_key import APIKeyHeader
from pydantic import BaseModel
from typing import List, Optional
import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv

load_dotenv()

# Seguridad
API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

async def verify_api_key(api_key: str = Security(api_key_header)):
    correct_api_key = os.getenv("API_KEY")
    if not correct_api_key:
        return None
    if not api_key or api_key != correct_api_key:
        raise HTTPException(status_code=403, detail="API Key inválida o faltante")
    return api_key

# App
app = FastAPI(title="ABET Evaluation API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["GET"],  # Solo permitir GET (read-only API)
    allow_headers=["*"],
)

# DB Config
DB_CONFIG = {
    "host": os.getenv("DB_HOST"),
    "port": int(os.getenv("DB_PORT", 3306)),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME"),
}

def get_db_connection():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Error as e:
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

def close_db_connection(conn, cursor):
    if cursor: cursor.close()
    if conn and conn.is_connected(): conn.close()

# Modelos
class StudentOutcome(BaseModel):
    id: int
    so_number: str
    description: str

class PerformanceIndicator(BaseModel):
    id: int
    student_outcome_id: int
    indicator_letter: str
    description: str

class PerformanceLevel(BaseModel):
    id: int
    indicator_id: int
    title: str
    description: str
    minscore: float
    maxscore: float

class StudentScore(BaseModel):
    student_code: str
    first_name: str
    last_name: str
    program: str
    indicator_a: float
    indicator_b: float
    indicator_c: float

class EvaluationResult(BaseModel):
    id: int
    instanceid: int
    studentid: int
    courseid: int
    activityid: int
    activityname: str
    student_outcome_id: int
    indicator_id: int
    performance_level_id: int
    score: float
    feedback: str | None = None
    timecreated: int
    timemodified: int

# Endpoints
@app.get("/health")
def health_check():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
        close_db_connection(conn, cursor)
        return {"status": "healthy"}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}

@app.get("/api/outcomes", response_model=List[StudentOutcome], dependencies=[Depends(verify_api_key)])
def get_outcomes(teacher_id: Optional[int] = Query(None), teacher_name: Optional[str] = Query(None)):
    """Listar outcomes. Opcionalmente filtrar por profesor (`teacher_id` o `teacher_name`).
    El filtrado busca outcomes que tengan evaluaciones en cursos donde el usuario
    está asignado con un rol cuyo `shortname` contiene 'teacher'.
    """
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    # Sin filtro, devolver todos los outcomes
    if not teacher_id and not teacher_name:
        cursor.execute("SELECT id, so_number, description_es AS description FROM mdl_gradingform_utb_outcomes")
        results = cursor.fetchall()
        close_db_connection(conn, cursor)
        return results

    # Con filtro por profesor: buscar outcomes que tengan evaluaciones en cursos
    # donde ese usuario está asignado como profesor.
    try:
        if teacher_id:
            sql = """
                SELECT DISTINCT o.id, o.so_number, o.description_es AS description
                FROM mdl_gradingform_utb_outcomes o
                JOIN mdl_gradingform_utb_indicators i ON i.student_outcome_id = o.id
                JOIN mdl_gradingform_utb_evaluations e ON e.indicator_id = i.id
                JOIN mdl_context c ON c.instanceid = e.courseid AND c.contextlevel = 50
                JOIN mdl_role_assignments ra ON ra.contextid = c.id
                JOIN mdl_role r ON r.id = ra.roleid
                JOIN mdl_user u ON u.id = ra.userid
                WHERE r.shortname LIKE %s AND u.id = %s
            """
            params = ("%teacher%", teacher_id)
            cursor.execute(sql, params)
        else:
            # Filtrado por nombre (buscar coincidencias parciales en nombre y apellido)
            name_like = f"%{teacher_name}%"
            sql = """
                SELECT DISTINCT o.id, o.so_number, o.description_es AS description
                FROM mdl_gradingform_utb_outcomes o
                JOIN mdl_gradingform_utb_indicators i ON i.student_outcome_id = o.id
                JOIN mdl_gradingform_utb_evaluations e ON e.indicator_id = i.id
                JOIN mdl_context c ON c.instanceid = e.courseid AND c.contextlevel = 50
                JOIN mdl_role_assignments ra ON ra.contextid = c.id
                JOIN mdl_role r ON r.id = ra.roleid
                JOIN mdl_user u ON u.id = ra.userid
                WHERE r.shortname LIKE %s AND CONCAT(u.firstname, ' ', u.lastname) LIKE %s
            """
            params = ("%teacher%", name_like)
            cursor.execute(sql, params)

        results = cursor.fetchall()
        return results
    finally:
        close_db_connection(conn, cursor)

@app.get("/api/indicators/{outcome_id:path}", response_model=List[PerformanceIndicator], dependencies=[Depends(verify_api_key)])
def get_indicators(outcome_id: str):
    """Obtener todos los indicadores de un outcome específico"""
    conn = None
    cursor = None
    try:
        # Limpiar y validar outcome_id
        clean_id = outcome_id.strip('{}').strip()
        try:
            outcome_id_int = int(clean_id)
        except ValueError:
            raise HTTPException(status_code=422, detail=f"ID inválido: '{outcome_id}'. Debe ser un número entero.")
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Obtener indicadores (retorna lista vacía si no hay)
        cursor.execute("SELECT id, student_outcome_id, indicator_letter, description_es AS description FROM mdl_gradingform_utb_indicators WHERE student_outcome_id = %s", (outcome_id_int,))
        results = cursor.fetchall()
        return results
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar indicadores: {str(e)}")
    finally:
        close_db_connection(conn, cursor)

@app.get("/api/levels/{indicator_id:path}", response_model=List[PerformanceLevel], dependencies=[Depends(verify_api_key)])
def get_levels(indicator_id: str):
    """Obtener todos los niveles de desempeño de un indicador específico"""
    conn = None
    cursor = None
    try:
        # Limpiar y validar indicator_id
        clean_id = indicator_id.strip('{}').strip()
        try:
            indicator_id_int = int(clean_id)
        except ValueError:
            raise HTTPException(status_code=422, detail=f"ID inválido: '{indicator_id}'. Debe ser un número entero.")
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Obtener niveles y mapear los campos correctamente
        cursor.execute("""
            SELECT id, indicator_id, 
                   title_es AS title, 
                   description_es AS description, 
                   minscore, maxscore
            FROM mdl_gradingform_utb_lvl 
            WHERE indicator_id = %s 
            ORDER BY sortorder DESC
        """, (indicator_id_int,))
        results = cursor.fetchall()
        return results
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar niveles: {str(e)}")
    finally:
        close_db_connection(conn, cursor)

@app.get("/api/evaluations/{student_id:path}", response_model=List[EvaluationResult], dependencies=[Depends(verify_api_key)])
def get_evaluations(student_id: str):
    """Obtener todas las evaluaciones de un estudiante específico por su ID"""
    conn = None
    cursor = None
    try:
        # Limpiar y validar student_id
        clean_id = student_id.strip('{}').strip()
        try:
            student_id_int = int(clean_id)
        except ValueError:
            raise HTTPException(status_code=422, detail=f"ID inválido: '{student_id}'. Debe ser un número entero.")
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT id, instanceid, studentid, courseid, activityid, activityname,
                   student_outcome_id, indicator_id, performance_level_id, 
                   score, feedback, timecreated, timemodified
            FROM mdl_gradingform_utb_evaluations
            WHERE studentid = %s
            ORDER BY timecreated DESC
        """, (student_id_int,))
        results = cursor.fetchall()
        
        # Retorna lista vacía si no hay evaluaciones (no es error)
        return results
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar evaluaciones: {str(e)}")
    finally:
        close_db_connection(conn, cursor)

@app.get("/api/outcome-summary/{outcome_id}", dependencies=[Depends(verify_api_key)])
def get_outcome_summary(outcome_id: int):
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM mdl_gradingform_utb_outcomes WHERE id = %s", (outcome_id,))
        outcome = cursor.fetchone()
        if not outcome:
            raise HTTPException(status_code=404, detail="Outcome no encontrado")
        cursor.execute("SELECT * FROM mdl_gradingform_utb_indicators WHERE student_outcome_id = %s", (outcome_id,))
        indicators = cursor.fetchall()
        for indicator in indicators:
            cursor.execute("SELECT * FROM mdl_gradingform_utb_lvl WHERE indicator_id = %s", (indicator["id"],))
            indicator["levels"] = cursor.fetchall()
        outcome["indicators"] = indicators
        return outcome
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar resumen: {str(e)}")
    finally:
        close_db_connection(conn, cursor)

@app.get("/api/outcome-assessment/{outcome_id}", dependencies=[Depends(verify_api_key)])
def get_outcome_assessment(outcome_id: int):
    """
    Obtener estadísticas de evaluación directa por nivel de desempeño (E, G, F, I)
    para cada indicador de performance de un outcome específico.
    """
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Verificar que el outcome existe
        cursor.execute("SELECT id, so_number FROM mdl_gradingform_utb_outcomes WHERE id = %s", (outcome_id,))
        outcome = cursor.fetchone()
        if not outcome:
            raise HTTPException(status_code=404, detail=f"Outcome con ID {outcome_id} no encontrado")
        
        # Obtener indicadores del outcome
        cursor.execute("""
            SELECT id, indicator_letter 
            FROM mdl_gradingform_utb_indicators 
            WHERE student_outcome_id = %s 
            ORDER BY indicator_letter
        """, (outcome_id,))
        indicators = cursor.fetchall()
        
        if not indicators:
            return {
                "outcome_id": outcome_id,
                "so_number": outcome["so_number"],
                "indicators": [],
                "summary": {}
            }
        
        # Para cada indicador, obtener estadísticas por nivel
        indicator_stats = []
        
        for indicator in indicators:
            indicator_id = indicator["id"]
            indicator_letter = indicator["indicator_letter"]
            
            # Obtener mapeo de performance_level_id a título (E, G, F, I)
            cursor.execute("""
                SELECT id, title_en, sortorder
                FROM mdl_gradingform_utb_lvl 
                WHERE indicator_id = %s
                ORDER BY sortorder DESC
            """, (indicator_id,))
            levels = cursor.fetchall()
            
            # Crear mapeo de ID a letra de nivel
            level_map = {}
            for level in levels:
                title = level["title_en"].upper()
                # Mapear títulos a letras E, G, F, I
                if "EXCELLENT" in title or "EXCELENTE" in title:
                    level_map[level["id"]] = "E"
                elif "GOOD" in title or "BUENO" in title:
                    level_map[level["id"]] = "G"
                elif "FAIR" in title or "REGULAR" in title:
                    level_map[level["id"]] = "F"
                elif "INADEQUATE" in title or "INADECUADO" in title:
                    level_map[level["id"]] = "I"
                else:
                    # Si no coincide, usar primera letra del título
                    level_map[level["id"]] = title[0] if title else "U"
            
            # Obtener conteo de evaluaciones por nivel para este indicador
            cursor.execute("""
                SELECT performance_level_id, COUNT(*) as count
                FROM mdl_gradingform_utb_evaluations
                WHERE indicator_id = %s
                GROUP BY performance_level_id
            """, (indicator_id,))
            level_counts = cursor.fetchall()
            
            # Calcular total de evaluaciones
            total = sum(row["count"] for row in level_counts)
            
            # Organizar estadísticas por nivel (E, G, F, I)
            stats = {
                "E": {"count": 0, "percentage": 0},
                "G": {"count": 0, "percentage": 0},
                "F": {"count": 0, "percentage": 0},
                "I": {"count": 0, "percentage": 0}
            }
            
            for row in level_counts:
                level_id = row["performance_level_id"]
                count = row["count"]
                level_letter = level_map.get(level_id, "U")
                
                if level_letter in stats:
                    stats[level_letter]["count"] = count
                    if total > 0:
                        stats[level_letter]["percentage"] = round((count / total) * 100)
            
            # Calcular E+G y F+I
            eg_count = stats["E"]["count"] + stats["G"]["count"]
            fi_count = stats["F"]["count"] + stats["I"]["count"]
            eg_percentage = round((eg_count / total) * 100) if total > 0 else 0
            fi_percentage = round((fi_count / total) * 100) if total > 0 else 0
            
            indicator_stats.append({
                "indicator": indicator_letter,
                "indicator_id": indicator_id,
                "total_evaluations": total,
                "levels": stats,
                "summary": {
                    "E_plus_G": {"count": eg_count, "percentage": eg_percentage},
                    "F_plus_I": {"count": fi_count, "percentage": fi_percentage}
                }
            })
        
        return {
            "outcome_id": outcome_id,
            "so_number": outcome["so_number"],
            "indicators": indicator_stats
        }
        
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al calcular estadísticas: {str(e)}")
    finally:
        close_db_connection(conn, cursor)

@app.get("/api/outcome-chart/{outcome_id}", dependencies=[Depends(verify_api_key)])
def get_outcome_chart(outcome_id: int):
    """
    Obtener datos para gráfico de barras: porcentaje de estudiantes que alcanzaron
    nivel E+G por cada indicador de performance.
    """
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Verificar que el outcome existe
        cursor.execute("SELECT id, so_number FROM mdl_gradingform_utb_outcomes WHERE id = %s", (outcome_id,))
        outcome = cursor.fetchone()
        if not outcome:
            raise HTTPException(status_code=404, detail=f"Outcome con ID {outcome_id} no encontrado")
        
        # Obtener indicadores del outcome
        cursor.execute("""
            SELECT id, indicator_letter 
            FROM mdl_gradingform_utb_indicators 
            WHERE student_outcome_id = %s 
            ORDER BY indicator_letter
        """, (outcome_id,))
        indicators = cursor.fetchall()
        
        if not indicators:
            return {
                "outcome_id": outcome_id,
                "so_number": outcome["so_number"],
                "chart_data": []
            }
        
        # Para cada indicador, calcular porcentaje de E+G
        chart_data = []
        
        for indicator in indicators:
            indicator_id = indicator["id"]
            indicator_letter = indicator["indicator_letter"]
            
            # Obtener mapeo de performance_level_id a nivel (E, G, F, I)
            cursor.execute("""
                SELECT id, title_en, sortorder
                FROM mdl_gradingform_utb_lvl 
                WHERE indicator_id = %s
                ORDER BY sortorder DESC
            """, (indicator_id,))
            levels = cursor.fetchall()
            
            # Crear mapeo de ID a letra de nivel
            level_map = {}
            for level in levels:
                title = level["title_en"].upper()
                if "EXCELLENT" in title or "EXCELENTE" in title:
                    level_map[level["id"]] = "E"
                elif "GOOD" in title or "BUENO" in title:
                    level_map[level["id"]] = "G"
                elif "FAIR" in title or "REGULAR" in title:
                    level_map[level["id"]] = "F"
                elif "INADEQUATE" in title or "INADECUADO" in title:
                    level_map[level["id"]] = "I"
                else:
                    level_map[level["id"]] = title[0] if title else "U"
            
            # Obtener conteo de evaluaciones por nivel
            cursor.execute("""
                SELECT performance_level_id, COUNT(*) as count
                FROM mdl_gradingform_utb_evaluations
                WHERE indicator_id = %s
                GROUP BY performance_level_id
            """, (indicator_id,))
            level_counts = cursor.fetchall()
            
            # Calcular total
            total = sum(row["count"] for row in level_counts)
            
            # Contar E y G
            e_count = 0
            g_count = 0
            
            for row in level_counts:
                level_id = row["performance_level_id"]
                count = row["count"]
                level_letter = level_map.get(level_id, "U")
                
                if level_letter == "E":
                    e_count += count
                elif level_letter == "G":
                    g_count += count
            
            # Calcular porcentaje E+G
            eg_count = e_count + g_count
            eg_percentage = round((eg_count / total) * 100) if total > 0 else 0
            
            chart_data.append({
                "indicator": indicator_letter,
                "indicator_id": indicator_id,
                "percentage_eg": eg_percentage,
                "count_eg": eg_count,
                "total": total
            })
        
        return {
            "outcome_id": outcome_id,
            "so_number": outcome["so_number"],
            "title": f"Percentage of student relates can attained E+G Level",
            "chart_data": chart_data
        }
        
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al generar datos del gráfico: {str(e)}")
    finally:
        close_db_connection(conn, cursor)

@app.get("/api/outcome-report/{outcome_id:path}")
async def get_outcome_report(outcome_id: str, api_key: str = Depends(verify_api_key)):
    """
    Obtiene el reporte completo del Student Outcome incluyendo:
    - Información del curso y profesor
    - Porcentajes de cumplimiento y faltante
    - Estado de los indicadores (Assessment y Students)
    - Resultados de mejora continua
    - Total de estudiantes
    """
    conn, cursor = None, None
    
    try:
        # Limpiar el outcome_id (remover llaves si las tiene)
        outcome_id = outcome_id.strip('{}').strip()
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # 1. Obtener información del outcome
        cursor.execute("""
            SELECT id, so_number, description_en, description_es
            FROM mdl_gradingform_utb_outcomes
            WHERE id = %s
        """, (outcome_id,))
        outcome = cursor.fetchone()
        
        if not outcome:
            raise HTTPException(status_code=404, detail="Outcome no encontrado")
        
        # 2. Obtener indicadores del outcome
        cursor.execute("""
            SELECT id, indicator_letter, description_en AS description
            FROM mdl_gradingform_utb_indicators
            WHERE student_outcome_id = %s
            ORDER BY indicator_letter
        """, (outcome_id,))
        indicators = cursor.fetchall()
        
        # 3. Para cada indicador, obtener niveles de desempeño
        indicators_status = []
        total_students = 0
        
        for indicator in indicators:
            indicator_id = indicator["id"]
            indicator_letter = indicator["indicator_letter"]
            
            # Obtener niveles
            cursor.execute("""
                SELECT id, title_en, title_es
                FROM mdl_gradingform_utb_lvl
                WHERE indicator_id = %s
                ORDER BY id
            """, (indicator_id,))
            levels = cursor.fetchall()
            
            # Mapear niveles a E/G/F/I
            level_map = {}
            for level in levels:
                title = level["title_en"].upper()
                if "EXCELLENT" in title or "EXCELENTE" in title:
                    level_map[level["id"]] = "E"
                elif "GOOD" in title or "BUENO" in title:
                    level_map[level["id"]] = "G"
                elif "FAIR" in title or "REGULAR" in title:
                    level_map[level["id"]] = "F"
                elif "INADEQUATE" in title or "INADECUADO" in title:
                    level_map[level["id"]] = "I"
                else:
                    level_map[level["id"]] = title[0] if title else "U"
            
            # Obtener evaluaciones del indicador
            cursor.execute("""
                SELECT performance_level_id, COUNT(*) as count
                FROM mdl_gradingform_utb_evaluations
                WHERE indicator_id = %s
                GROUP BY performance_level_id
            """, (indicator_id,))
            level_counts = cursor.fetchall()
            
            # Calcular total de evaluaciones
            total_evaluations = sum(row["count"] for row in level_counts)
            if total_evaluations > total_students:
                total_students = total_evaluations
            
            # Contar por nivel
            e_count = g_count = f_count = i_count = 0
            for row in level_counts:
                level_id = row["performance_level_id"]
                count = row["count"]
                level_letter = level_map.get(level_id, "U")
                
                if level_letter == "E":
                    e_count += count
                elif level_letter == "G":
                    g_count += count
                elif level_letter == "F":
                    f_count += count
                elif level_letter == "I":
                    i_count += count
            
            # Determinar estado: Ok si tiene evaluaciones, Pendiente si no
            assessment_status = "Ok" if total_evaluations > 0 else "Pendiente"
            student_status = "Pendiente" if (f_count + i_count) > 0 else "Ok"
            
            indicators_status.append({
                "indicator": indicator_letter,
                "indicator_id": indicator_id,
                "description": indicator["description"],
                "assessment_status": assessment_status,
                "student_status": student_status,
                "evaluations": {
                    "E": e_count,
                    "G": g_count,
                    "F": f_count,
                    "I": i_count,
                    "total": total_evaluations
                }
            })
        
        # 4. Calcular porcentajes de cumplimiento
        # Compliance = (E + G) / Total
        total_eg = sum(ind["evaluations"]["E"] + ind["evaluations"]["G"] for ind in indicators_status)
        total_all = sum(ind["evaluations"]["total"] for ind in indicators_status)
        
        compliance_percentage = round((total_eg / total_all) * 100) if total_all > 0 else 0
        missing_percentage = 100 - compliance_percentage
        
        # 5. Información del/los curso(s) y profesores relacionados con este outcome
        # Obtener los courseids que tienen evaluaciones para este outcome
        cursor.execute("""
            SELECT DISTINCT e.courseid
            FROM mdl_gradingform_utb_evaluations e
            JOIN mdl_gradingform_utb_indicators i ON e.indicator_id = i.id
            WHERE i.student_outcome_id = %s
        """, (outcome_id,))
        course_rows = cursor.fetchall()
        courses = []
        professors_set = set()

        for crow in course_rows:
            courseid = crow["courseid"]
            # Obtener nombre del curso
            cursor.execute("SELECT id, fullname FROM mdl_course WHERE id = %s", (courseid,))
            course = cursor.fetchone()
            course_name = course["fullname"] if course else f"course_{courseid}"

            # Obtener profesores asignados al curso (buscar roles cuyo shortname contenga 'teacher')
            cursor.execute("""
                SELECT DISTINCT u.id, u.firstname, u.lastname
                FROM mdl_user u
                JOIN mdl_role_assignments ra ON ra.userid = u.id
                JOIN mdl_context c ON c.id = ra.contextid
                JOIN mdl_role r ON r.id = ra.roleid
                WHERE c.contextlevel = 50 AND c.instanceid = %s AND r.shortname LIKE %s
            """, (courseid, "%teacher%"))
            prof_rows = cursor.fetchall()
            profs = []
            for p in prof_rows:
                name = f"{p['firstname']} {p['lastname']}"
                profs.append({"id": p["id"], "name": name})
                professors_set.add(name)

            courses.append({"id": courseid, "name": course_name, "professors": profs})

        # 6. Lista de estudiantes calificados para este outcome (nombres y programa)
        cursor.execute("""
            SELECT DISTINCT u.id, u.firstname, u.lastname, u.idnumber, u.department
            FROM mdl_user u
            JOIN mdl_gradingform_utb_evaluations e ON e.studentid = u.id
            JOIN mdl_gradingform_utb_indicators i ON e.indicator_id = i.id
            WHERE i.student_outcome_id = %s
        """, (outcome_id,))
        student_rows = cursor.fetchall()

        # Intentar resolver el campo personalizado que contiene el programa del estudiante
        cursor.execute("SELECT id FROM mdl_user_info_field WHERE shortname LIKE %s OR name LIKE %s OR name LIKE %s", ("%program%", "%program%", "%programa%"))
        field_rows = cursor.fetchall()
        program_field_ids = [r['id'] for r in field_rows] if field_rows else []

        graded_students = []
        for s in student_rows:
            program = None
            if program_field_ids:
                placeholders = ','.join(['%s'] * len(program_field_ids))
                params = [s['id']] + program_field_ids
                cursor.execute(f"SELECT data FROM mdl_user_info_data WHERE userid = %s AND fieldid IN ({placeholders})", tuple(params))
                pdata = cursor.fetchone()
                if pdata and pdata.get('data'):
                    program = pdata.get('data')

            # Fallbacks si no se encontró programa en campos personalizados
            if not program:
                # Usar department o idnumber si están presentes
                program = s.get('department') or s.get('idnumber') or None

            graded_students.append({
                "id": s['id'],
                "name": f"{s['firstname']} {s['lastname']}",
                "program": program
            })

        return {
            "outcome_id": outcome_id,
            "so_number": outcome["so_number"],
            "description": outcome["description_en"],
            "courses": courses,
            "professors": list(professors_set),
            "programs": ["IAMB"],
            "students": {
                "total": total_students,
                "type_of_assessment": "Continuous Assessment",
                "graded_students": graded_students
            },
            "compliance": {
                "percentage": compliance_percentage,
                "missing_percentage": missing_percentage
            },
            "indicators": indicators_status,
            "continuous_improvement": {
                "activities_applied": "Ok",
                "current_results": "Ok",
                "actions_proposed": "Ok"
            }
        }
        
    except HTTPException:
        raise
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error al generar reporte: {str(e)}")
    finally:
        close_db_connection(conn, cursor)

if __name__ == "__main__":
    import uvicorn
    import os

    HOST = os.getenv("HOST", "0.0.0.0")
    PORT = int(os.getenv("PORT", 8000))
    SSL_CERTFILE = os.getenv("SSL_CERTFILE")
    SSL_KEYFILE = os.getenv("SSL_KEYFILE")

    # Si se proporcionan rutas a certificado y key via env vars, iniciar uvicorn con TLS
    if SSL_CERTFILE and SSL_KEYFILE:
        uvicorn.run(app, host=HOST, port=PORT, ssl_certfile=SSL_CERTFILE, ssl_keyfile=SSL_KEYFILE)
    else:
        uvicorn.run(app, host=HOST, port=PORT)
