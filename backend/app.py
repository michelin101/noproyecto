from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import os
from datetime import datetime
from database import get_db
from generador_csv import crear_lecturas_csv

app = Flask(__name__)
CORS(app) 

db = get_db()
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def extraer_metricas_txt(ruta_txt):
    metricas = {}
    if not os.path.exists(ruta_txt):
        return {"status": "error", "message": f"El archivo {ruta_txt} no fue generado por el módulo."}
        
    with open(ruta_txt, "r") as file:
        for linea in file:
            linea = linea.strip()
            if "=" in linea:
                clave, valor = linea.split("=", 1)
                metricas[clave.strip()] = valor.strip()
    return metricas

@app.route('/', methods=['GET'])
def index():
    return jsonify({"estado": "Backend Funcionando :)", "proyecto": "Invernadero G19"})

@app.route('/api/historico/sensores', methods=['GET'])
def get_historico_sensores():
    try:
        
        cursor = db["sensor_readings"].find({}, {"_id": 0}).sort("fecha_y_hora", -1).limit(100)
        datos = list(cursor)
        datos.reverse()  
        return jsonify(datos), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/historico/eventos', methods=['GET'])
def get_historico_eventos():
    try:
        
        cursor = db["events"].find({}, {"_id": 0}).sort("fecha_y_hora", -1).limit(20)
        return jsonify(list(cursor)), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/historico/comandos', methods=['GET'])
def get_historico_comandos():
    try:
        
        cursor = db["commands"].find({}, {"_id": 0}).sort("fecha_y_hora", -1).limit(20)
        return jsonify(list(cursor)), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500



@app.route("/api/analizar", methods=["POST"])
def analizar_datos_invernadero():
    try:
        payload = request.get_json()
        if not payload or "columna" not in payload:
            return jsonify({"error": "Petición inválida. Se requiere especificar el parámetro 'columna'."}), 400
            
        columna = str(payload["columna"]).strip()
        if not columna.isdigit():
            return jsonify({"error": "El identificador de columna debe ser un valor entero numérico válido."}), 400

        estado_csv = crear_lecturas_csv(db)
        if "error" in estado_csv:
            return jsonify(estado_csv), 400

        config_rutinas = [
            {"id": "media", "binario": "modulo_1_media", "salida": "resultado_media.txt"},
            {"id": "varianza", "binario": "modulo_2_varianza", "salida": "resultado_varianza.txt"},
            {"id": "anomalias", "binario": "modulo_3_anomalias", "salida": "resultado_anomalias.txt"},
            {"id": "prediccion", "binario": "modulo_4_prediccion", "salida": "resultado_prediccion.txt"},
            {"id": "tendencia", "binario": "modulo_5_tendencia", "salida": "resultado_tendencia.txt"}
        ]

        documento_maestro = {
            "fecha_y_hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "tipo_de_dato": "procesamiento_estadistico_arm64",
            "origen": "Subprocess_Engine_AArch64",
            "columna_analizada": int(columna),
            "total_registros": estado_csv["total"],
            "resultados": {}
        }

        for rutina in config_rutinas:
            ruta_binario = os.path.join(BASE_DIR, "build", rutina["binario"])
            ruta_archivo_salida = os.path.join(BASE_DIR, "arm64_data", rutina["salida"])
            cwd_data = os.path.join(BASE_DIR, "arm64_data")

            resultado_modulo = {
                "estado_ejecucion": "pendiente",
                "metricas": None,
                "exit_code": None,
                "stderr_raw": None,
                "error_detalle": None
            }

            if not os.path.exists(ruta_binario):
                resultado_modulo["estado_ejecucion"] = "fallido"
                resultado_modulo["error_detalle"] = "Binario no encontrado. Requiere compilación previa."
            else:
                try:
                    ejecucion = subprocess.run(
                        [ruta_binario, columna],
                        cwd=cwd_data,
                        capture_output=True,
                        text=True,
                        timeout=8
                    )

                    datos_modulo = extraer_metricas_txt(ruta_archivo_salida)

                    if "error" in datos_modulo:
                        resultado_modulo["estado_ejecucion"] = "fallido"
                        resultado_modulo["error_detalle"] = datos_modulo["message"]
                        resultado_modulo["exit_code"] = ejecucion.returncode
                        resultado_modulo["stderr_raw"] = ejecucion.stderr.strip()
                    else:
                        resultado_modulo["estado_ejecucion"] = "exitoso" if ejecucion.returncode == 0 else "fallido"
                        resultado_modulo["metricas"] = datos_modulo
                        resultado_modulo["exit_code"] = ejecucion.returncode
                        resultado_modulo["stderr_raw"] = ejecucion.stderr.strip()

                except subprocess.TimeoutExpired:
                    resultado_modulo["estado_ejecucion"] = "fallido"
                    resultado_modulo["error_detalle"] = "Timeout: El módulo excedió el tiempo límite de 8 segundos."
                except Exception as e:
                    resultado_modulo["estado_ejecucion"] = "fallido"
                    resultado_modulo["error_detalle"] = f"Error de subproceso: {str(e)}"

            documento_maestro["resultados"][rutina["id"]] = resultado_modulo

        db["arm64_results"].insert_one(documento_maestro)

        if "_id" in documento_maestro:
            del documento_maestro["_id"]

        return jsonify({
            "status": "success",
            "message": "Procesamiento finalizado.",
            "payload": documento_maestro
        }), 200

    except Exception as e:
        return jsonify({"error": f"Fallo crítico en el orquestador: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
