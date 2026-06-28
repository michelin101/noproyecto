from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import os
from datetime import datetime
from database import get_db
from generador_csv import crear_lecturas_csv
from dotenv import load_dotenv


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_PATH = os.path.join(BASE_DIR, '.env')
load_dotenv(dotenv_path=ENV_PATH, override=True)

app = Flask(__name__)
CORS(app) 

db = get_db()

LOGIN_USER = os.getenv("LOGIN_USER")
LOGIN_PASS = os.getenv("LOGIN_PASS")

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

@app.route('/api/login', methods=['POST'])
def login():
    try: 
        payload = request.get_json(silent=True) or {}
        usuario = str(payload.get("usuario", "")).strip()
        password = str(payload.get("password", "")).strip()

        if not usuario or not password:
            return jsonify({"error": "Usuario y contraseña son necesarios"}), 400
        
        if not LOGIN_USER or not LOGIN_PASS:
            return jsonify({"error": "Credenciales no configuradas en el servidor"}), 500
        
        if usuario == LOGIN_USER and password == LOGIN_PASS:
            return jsonify({"estado": "exito", "usuario":usuario}), 200
        
        return jsonify({"error": "Usuario o contraseña incorrectos"}), 401
    except Exception as e:
        print(f"ERROR DETECTADO EN /api/login: {e}")
        return jsonify({"error": f"Error en Login: {str(e)}"}), 500

@app.route('/api/historico/sensores', methods=['GET'])
def get_historico_sensores():
    try:
        cursor = db["sensor_readings"].find({}, {"_id": 0}).sort("fecha_y_hora", -1).limit(100)
        datos = list(cursor)
        datos.reverse()  
        return jsonify(datos), 200
    except Exception as e:
        print(f"ERROR DETECTADO EN /api/historico/sensores: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/historico/eventos', methods=['GET'])
def get_historico_eventos():
    try:
        cursor = db["events"].find({}, {"_id": 0}).sort("fecha_y_hora", -1).limit(20)
        return jsonify(list(cursor)), 200
    except Exception as e:
        print(f"ERROR DETECTADO EN /api/historico/eventos: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/historico/comandos', methods=['GET'])
def get_historico_comandos():
    try:
        cursor = db["commands"].find({}, {"_id": 0}).sort("fecha_y_hora", -1).limit(20)
        return jsonify(list(cursor)), 200
    except Exception as e:
        print(f"ERROR DETECTADO EN /api/historico/comandos: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/historico/analizador', methods=['GET'])
def get_historico_analizador():
    try:
        cursor = db["arm64_results"].find({}, {"_id":0}).sort("fecha_y_hora", -1).limit(50)
        return jsonify(list(cursor)), 200
    except Exception as e:
        print(f"ERROR DETECTADO EN /api/historico/analizador: {e}")
        return jsonify({"error": str(e)}), 500
    
@app.route('/api/historico/arm64', methods=['GET'])
def get_arm64_vivo():
    try:
        cursor = db["arm64_results"].find({"source": "live_engine"}, {"_id": 0}).sort("fecha_y_hora", -1).limit(1)
        ultimo = list(cursor)
        if not ultimo:
            return jsonify(None), 200
        return jsonify(ultimo[0]), 200
    except Exception as e:
        print(f"ERROR REAL DETECTADO EN /api/historico/arm64: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/api/analizar", methods=["POST"])
def analizar_datos_invernadero():
    try:
        payload = request.get_json()
        if not payload:
            return jsonify({"error": "Petición inválida. Cuerpo JSON requerido."}), 400

        columna = str(payload.get("columna", "")).strip()
        linea_inicial = payload.get("linea_inicial")
        linea_final = payload.get("linea_final")

        if not columna.isdigit():
            return jsonify({"error": "El identificador de columna debe ser un valor entero numérico válido."}), 400

        try:
            linea_inicial = int(linea_inicial)
            linea_final = int(linea_final)
        except (TypeError, ValueError):
            return jsonify({"error": "linea_inicial y linea_final deben ser valores enteros."}), 400

        if linea_inicial < 1:
            return jsonify({"error": "linea_inicial debe ser mayor o igual a 1."}), 400

        if linea_final < linea_inicial:
            return jsonify({"error": "linea_final debe ser mayor o igual a linea_inicial."}), 400

        
        estado_csv = crear_lecturas_csv(db, n=linea_final)
        if "error" in estado_csv:
            return jsonify(estado_csv), 400

        if linea_final > estado_csv["total"]:
            return jsonify({
                "error": f"linea_final ({linea_final}) excede el total de registros disponibles ({estado_csv['total']})."
            }), 400

        #añadimos las nuevas rutinas tanto de la fase 1 como de la fase 2.
        config_rutinas = [
            {"id": "media", "binario": "modulo_1_media", "salida": "resultado_media.txt"},
            {"id": "rmse", "binario": "modulo_1_rmse", "salida": "resultado_rmse.txt"},
            {"id": "regresion", "binario": "modulo_2_regresion", "salida": "resultado_regresion.txt"},
            {"id": "varianza", "binario": "modulo_2_varianza", "salida": "resultado_varianza.txt"},
            {"id": "anomalias", "binario": "modulo_3_anomalias", "salida": "resultado_anomalias.txt"},
            {"id": "prediccion_m3", "binario": "modulo_3_prediccion", "salida": "resultado_prediccion_3.txt"},
            {"id": "integral_error", "binario": "modulo_4_integral_error", "salida": "errores_integral.txt"},
            {"id": "prediccion_m4", "binario": "modulo_4_prediccion", "salida": "resultado_prediccion_4.txt"},
            {"id": "derivada_local", "binario": "modulo_5_derivada_local", "salida": "resultado_derivada.txt"},
            {"id": "tendencia", "binario": "modulo_5_tendencia", "salida": "resultado_tendencia.txt"}
        ]

        documento_maestro = {
            "fecha_y_hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "tipo_de_dato": "procesamiento_estadistico_arm64",
            "origen": "Subprocess_Engine_AArch64",
            "source": "historical_analyzer",
            "columna_analizada": int(columna),
            "linea_inicial": linea_inicial,
            "linea_final": linea_final,
            "total_registros": linea_final - linea_inicial + 1,
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
                        [ruta_binario, "lecturas.csv", str(linea_inicial), str(linea_final), columna],
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
                    print(f"ERROR EN SUBPROCESO DE ANALIZAR: {e}")
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
        print(f"ERROR DETECTADO EN /api/analizar: {e}")
        return jsonify({"error": f"Fallo crítico en el orquestador: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)