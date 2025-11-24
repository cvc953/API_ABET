# Test del endpoint /api/outcome-summary/{outcome_id}

import requests
import json

# Configuración
BASE_URL = "http://localhost:8000"
API_KEY = "tu_api_key_aqui"  # Cambia esto por tu API key real
OUTCOME_ID = 1  # ID del outcome a probar

headers = {
    "X-API-Key": API_KEY
}

def test_health():
    """Probar que la API está funcionando"""
    print("🔍 Probando /health...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")
    return response.status_code == 200

def test_outcome_summary():
    """Probar el endpoint /api/outcome-summary/{outcome_id}"""
    print(f"🔍 Probando /api/outcome-summary/{OUTCOME_ID}...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/api/outcome-summary/{OUTCOME_ID}",
            headers=headers
        )
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Endpoint funcionando correctamente!")
            data = response.json()
            print(f"\n📊 Datos recibidos:")
            print(f"   - Outcome ID: {data.get('id')}")
            print(f"   - SO Number: {data.get('so_number')}")
            print(f"   - Indicadores: {len(data.get('indicators', []))}")
            
            # Mostrar estructura completa
            print(f"\n📄 Respuesta completa:")
            print(json.dumps(data, indent=2, ensure_ascii=False))
            
        elif response.status_code == 404:
            print(f"⚠️  Outcome con ID {OUTCOME_ID} no encontrado")
            print(f"Response: {response.json()}")
            
        elif response.status_code == 403:
            print("❌ Error de autenticación - Verifica tu API Key")
            print(f"Response: {response.json()}")
            
        else:
            print(f"❌ Error: Status {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ No se pudo conectar al servidor")
        print("   Asegúrate de que la API esté ejecutándose en http://localhost:8000")
        print("   Ejecuta: uvicorn main:app --reload")
        
    except Exception as e:
        print(f"❌ Error inesperado: {str(e)}")

if __name__ == "__main__":
    print("=" * 60)
    print("  TEST: Endpoint /api/outcome-summary/{outcome_id}")
    print("=" * 60)
    print()
    
    # Primero probar health
    if test_health():
        print("-" * 60)
        # Si health funciona, probar el endpoint
        test_outcome_summary()
    else:
        print("❌ La API no está respondiendo correctamente")
    
    print()
    print("=" * 60)
