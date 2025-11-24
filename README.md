# ABET Evaluation API - Guía de Prueba

## 🔧 Problema Resuelto

El endpoint `/api/outcome-summary/{outcome_id}` tenía un problema de manejo de conexiones a la base de datos que podía causar:
- Fugas de conexiones si ocurría una excepción
- Errores intermitentes bajo carga
- Conexiones no cerradas correctamente

### ✅ Corrección Aplicada
- Añadido bloque `try-finally` para garantizar cierre de conexiones
- Manejo apropiado de excepciones de base de datos
- Inicialización correcta de variables `conn` y `cursor`

## 📋 Pre-requisitos

1. **Python 3.8+** instalado
2. **MySQL/MariaDB** con base de datos Moodle configurada
3. Credenciales de acceso a la base de datos

## 🚀 Instalación y Configuración

### 1. Instalar dependencias

```powershell
# Crear entorno virtual (recomendado)
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Instalar dependencias
pip install -r requirements.txt
```

### 2. Configurar variables de entorno

```powershell
# Copiar el archivo de ejemplo
cp .env.example .env

# Editar .env con tus credenciales
notepad .env
```

Configuración necesaria en `.env`:
```env
DB_HOST=tu_host_mysql
DB_PORT=3306
DB_USER=tu_usuario
DB_PASSWORD=tu_password
DB_NAME=moodle
API_KEY=tu_api_key_opcional
```

### 3. Ejecutar la API

```powershell
# Opción 1: Con recarga automática (desarrollo)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Opción 2: Sin recarga (producción)
python main.py
```
# ABET Evaluation API — Instrucciones mínimas

Este repositorio contiene una pequeña API en FastAPI para consultar estadísticas y reportes de Student Outcomes (`mdl_gradingform_utb_*`) sobre una instalación Moodle.

Objetivo de esta limpieza: dejar sólo lo necesario para ejecutar la API localmente.

Archivos que quedan en el repositorio:
- `main.py` - La aplicación FastAPI.
- `requirements.txt` - Dependencias necesarias.
- `README.md` - Esta guía mínima.
- `.env.example` - Ejemplo de variables de entorno.

Requisitos
- Python 3.8+
- Acceso a la base de datos MySQL/MariaDB con las tablas de Moodle y del plugin `gradingform_utb`.

Variables de entorno (copiar `.env.example` a `.env` y rellenar):
- `DB_HOST` - host de la BD
- `DB_PORT` - puerto (por defecto 3306)
- `DB_USER` - usuario
- `DB_PASSWORD` - contraseña
- `DB_NAME` - nombre de la base de datos (p.ej. `moodle`)
- `API_KEY` - (opcional) clave para proteger los endpoints
- `SSL_CERTFILE` - (opcional) ruta a archivo PEM del certificado para HTTPS
- `SSL_KEYFILE` - (opcional) ruta a archivo PEM de la clave privada para HTTPS

Instalación rápida
1. Crear y activar entorno virtual
```bash
python -m venv .venv
source .venv/bin/activate
```
2. Instalar dependencias
```bash
pip install -r requirements.txt
```
3. Copiar y editar variables de entorno
```bash
cp .env.example .env
# editar .env con tus valores
```

Ejecutar la API
- Desarrollo (recarga automática):
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
- Ejecutar por defecto (el script `main.py` activará TLS si `SSL_CERTFILE` y `SSL_KEYFILE` están definidos):
```bash
python main.py
```

HTTPS local (desarrollo con certificado auto-firmado)
1. Generar certificado y clave para `localhost` (solo para pruebas):
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/CN=localhost"
```
2. Exportar variables de entorno y ejecutar:
```bash
export SSL_CERTFILE="$PWD/server.crt"
export SSL_KEYFILE="$PWD/server.key"
python main.py
```
Luego acceder por: `https://localhost:8000` (tu navegador mostrará advertencia por certificado auto-firmado).

Recomendación para producción
- Usa un reverse-proxy (Nginx, Caddy, Traefik) para gestionar TLS y exponer la app.
- No expongas Uvicorn directamente a Internet sin proxy.

Endpoints principales
- `GET /health` — comprobación de salud (no requiere API key)
- `GET /api/outcomes` — lista de student outcomes (soporta `teacher_id` y `teacher_name` como query params)
- `GET /api/outcome-report/{outcome_id}` — reporte enriquecido (cursos, profesores, estudiantes calificados, programas)

Probar la API (ejemplos)
```bash
# Health
curl https://localhost:8000/health --insecure

# Obtener reporte (con API key)
curl -H "X-API-Key: TU_API_KEY" https://localhost:8000/api/outcome-report/1 --insecure
```

Si necesitas que deje archivos o documentación adicionales, dime cuáles y los conservo. Esta limpieza elimina scripts de prueba y documentación interna relacionada con APEX para dejar un repo mínimo y operativo.

---
Actualizado: instrucciones mínimas para poner en marcha la API.
