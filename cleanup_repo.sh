#!/usr/bin/env bash
set -euo pipefail

# Script de limpieza del repositorio: elimina archivos no esenciales para dejar
# solo los archivos necesarios para ejecutar la API.
# USO: revisar el listado y ejecutar: ./cleanup_repo.sh

FILES=(
  "test_quick.ps1"
  "test_outcome_report.ps1"
  "test_levels.ps1"
  "test_indicators_crud.ps1"
  "test_fixed_endpoints.ps1"
  "test_evaluations.ps1"
  "test_endpoint.py"
  "test_chart_data.ps1"
  "test_assessment_stats.ps1"
  "test_api_key.ps1"
  "SOLUCION_ERROR.md"
  "SOLUCION_ENDPOINTS.md"
  "ORACLE_APEX_INTEGRATION.md"
  "INDICATORS_API_EXAMPLES.md"
  "diagnose_db.ps1"
  "API_READ_ONLY.md"
  "API_KEY_FIX.md"
  "APEX_TROUBLESHOOTING.md"
  "APEX_SQL_SCRIPTS.sql"
  "APEX_SETUP_GUIDE.md"
  "APEX_DASHBOARD_PASO_A_PASO.md"
  "APEX_DASHBOARD_LAYOUT_GUIDE.md"
  ".env"
)

echo "Los siguientes archivos serán ELIMINADOS del repositorio (si existen):"
for f in "${FILES[@]}"; do
  echo " - $f"
done

read -p "¿Deseas continuar y eliminar estos archivos? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Cancelado. No se realizaron cambios."
  exit 0
fi

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    rm -v "$f"
  else
    echo "No existe: $f"
  fi
done

echo "Limpieza completada. Manteniendo: main.py, requirements.txt, README.md, .env.example"
chmod +x cleanup_repo.sh
