import time
import threading
import os
import certifi
import paho.mqtt.client as mqtt
from datetime import datetime
from dotenv import load_dotenv
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi
import RPi.GPIO as GPIO


from globals import shared
from sensors import Sensors
from actuadores import Actuadores
from display import Display
from motor_bridge import MotorARM64

PREFIX = "grupo19/"
BROKER = "broker.emqx.io"
PORT = 1883

TOPICS_PUBLISH = {
    "temp":          PREFIX + "invernadero/sensores/temperatura",
    "hum_amb":       PREFIX + "invernadero/sensores/humedad_ambiente",
    "suelo1":        PREFIX + "invernadero/sensores/humedad_suelo_area1",
    "suelo2":        PREFIX + "invernadero/sensores/humedad_suelo_area2",
    "luz":           PREFIX + "invernadero/sensores/luz",
    "gas_ppm":       PREFIX + "invernadero/sensores/gas_ppm",
    "global_status": PREFIX + "invernadero/estado/global",
    "riego":         PREFIX + "invernadero/actuadores/riego",
    "ventilador":    PREFIX + "invernadero/actuadores/ventilador",
    "luces":         PREFIX + "invernadero/actuadores/luces",
    "alarma":        PREFIX + "invernadero/actuadores/alarma"
}

TOPICS_SUBSCRIBE = [
    PREFIX + "invernadero/control/remoto",
    PREFIX + "invernadero/control/manual",
    PREFIX + "invernadero/actuadores/riego/control",       
    PREFIX + "invernadero/actuadores/ventilador/control",  
    PREFIX + "invernadero/actuadores/luces/control",
    PREFIX + "invernadero/actuadores/alarma/control"
]

class IOT:
    def __init__(self):
        self.running = True
        
        self.intervals = {
            "principal": 0.2,  
            "MQTT": 2.0,       
            "MongoDB": 5.0     
        }
        
        current_t = time.time() 
        self.last_run = { 
            "MQTT": current_t,
            "MongoDB": current_t
        }

        self.estado_anterior = "NORMAL"

        self.actuadores_anteriores = {
            "bomba": False,
            "ventilador": "VENTILACION_OFF",
            "luces": False,
            "buzzer": False
        }

        self.Sensors = Sensors()
        self.Display = Display()
        self.Actuadores = Actuadores()
        self.Motor = MotorARM64("./src/motor")  
        
        self._init_mongo()
        self._init_mqtt()

    def _init_mongo(self):
        load_dotenv()
        uri = os.getenv("MONGODB_URI")
        self.db_name = os.getenv("MONGODB_DB", "invernadero_g19")
        
        print("Iniciando conexion a MongoDB Atlas...")
        try:
            self.mongo_client = MongoClient(uri, server_api=ServerApi("1"), tlsCAFile=certifi.where())
            self.mongo_client.admin.command('ping')
            self.db = self.mongo_client[self.db_name]
            print("Conexion exitosa a MongoDB.")
        except Exception as e:
            print(f"Error critico al conectar a MongoDB: {e}")
            self.db = None

    def _init_mqtt(self):
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self.client.on_connect = self.on_connect_mqtt
        self.client.on_message = self.on_message_mqtt

    def on_connect_mqtt(self, client, userdata, flags, reason_code, properties):
        if reason_code == 0:
            print("Conectado exitosamente al Broker MQTT.")
            for topic in TOPICS_SUBSCRIBE:
                client.subscribe(topic)
        else:
            print(f"Error de conexion MQTT. Codigo: {reason_code}")

    def on_message_mqtt(self, client, userdata, msg):
        payload = msg.payload.decode('utf-8').upper()
        topic = msg.topic

        print(f"[MQTT] Comando recibido: {topic} -> {payload}")
        
        self.insertar_mongo("commands", {
            "fecha_y_hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "tipo_de_dato": "comando_remoto",
            "valor": payload,
            "origen": topic,
            "estado_relacionado": shared.estado_global
        })

        if "control/manual" in topic and payload == "TOGGLE_MODO":
            shared.modo_operacion = "MANUAL" if shared.modo_operacion == "AUTOMATICO" else "AUTOMATICO"
            
        elif shared.modo_operacion == "MANUAL":
            if "actuadores/riego/control" in topic and payload in ["TOGGLE", "ON", "OFF"]:
                shared.comando_riego_remoto = payload
            elif "actuadores/luces/control" in topic and payload in ["TOGGLE", "ON", "OFF"]:
                shared.comando_luces_remoto = payload
            elif "actuadores/ventilador/control" in topic and payload in ["TOGGLE", "ON", "OFF"]:
                shared.comando_ventilador_remoto = payload
            elif "actuadores/alarma/control" in topic and payload in ["TOGGLE", "ON", "OFF"]:
                shared.comando_alarma_remoto = payload
        else:
            shared.mensaje_error_local = "Error: Modo Auto"
            print("[INFO] Comando ignorado, sistema en AUTOMATICO.")

    def insertar_mongo(self, coleccion, documento):
        if self.db is None: return
        try:
            self.db[coleccion].insert_one(documento)
        except Exception as e:
            print(f"Error guardando en {coleccion}: {e}")

    def mqtt_tasks(self):
        print("Iniciando hilo MQTT...")
        try:
            self.client.connect(BROKER, PORT, 60)
            self.client.loop_start()
        except Exception as e:
            print(f"Error iniciando loop MQTT: {e}")

        while self.running:
            tiempo_actual = time.time()
            if (tiempo_actual - self.last_run["MQTT"]) >= self.intervals["MQTT"]:
                try:
                    self.client.publish(TOPICS_PUBLISH["temp"], f"{shared.temperature:.1f}")
                    self.client.publish(TOPICS_PUBLISH["hum_amb"], f"{shared.humidity:.1f}")
                    self.client.publish(TOPICS_PUBLISH["suelo1"], f"{shared.suelo_area1_pct:.1f}")
                    self.client.publish(TOPICS_PUBLISH["suelo2"], f"{shared.suelo_area2_pct:.1f}")
                    self.client.publish(TOPICS_PUBLISH["luz"], f"{shared.luz_lux:.1f}")
                    self.client.publish(TOPICS_PUBLISH["gas_ppm"], f"{shared.gas_ppm:.1f}")
                    self.client.publish(TOPICS_PUBLISH["global_status"], shared.estado_global)          
                    self.client.publish(TOPICS_PUBLISH["riego"], shared.estado_riego)
                    self.client.publish(TOPICS_PUBLISH["ventilador"], shared.estado_ventilacion)
                    self.client.publish(TOPICS_PUBLISH["luces"], "ON" if shared.luces_encendidas else "OFF")
                    self.client.publish(TOPICS_PUBLISH["alarma"], "ON" if shared.buzzer_encendido else "OFF")
                except Exception:
                    pass 
                
                self.last_run["MQTT"] = tiempo_actual
            time.sleep(0.5)

    def mongodb_tasks(self):
        while self.running:
            tiempo_actual = time.time()
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            if shared.estado_global != self.estado_anterior:
                self.insertar_mongo("events", {
                    "fecha_y_hora": now,
                    "tipo_de_dato": "cambio_estado",
                    "valor": shared.estado_global,
                    "origen": "Python",
                    "estado_relacionado": shared.estado_global
                })
                self.estado_anterior = shared.estado_global

            actuadores_actuales = {
                "bomba": shared.bomba_encendida,
                "ventilador": shared.estado_ventilacion,
                "luces": shared.luces_encendidas,
                "buzzer": shared.buzzer_encendido
            }

            for actuador, estado_actual in actuadores_actuales.items():
                if estado_actual != self.actuadores_anteriores[actuador]:
                    if actuador == "ventilador":
                        valor_log = estado_actual
                    else:
                        valor_log = "ON" if estado_actual else "OFF"
                    
                    self.insertar_mongo("actuator_logs", {
                        "fecha_y_hora": now,
                        "tipo_de_dato": f"activacion_{actuador}",
                        "valor": valor_log,
                        "origen": "Python",
                        "estado_relacionado": shared.estado_global
                    })
                    self.actuadores_anteriores[actuador] = estado_actual

            if (tiempo_actual - self.last_run["MongoDB"]) >= self.intervals["MongoDB"]:
                self.insertar_mongo("sensor_readings", {
                    "fecha_y_hora": now,
                    "tipo_de_dato": "lectura_sensores",
                    "valor": {
                        "temp": shared.temperature, "hum": shared.humidity,
                        "suelo1": shared.suelo_area1_pct, "suelo2": shared.suelo_area2_pct,
                        "luz": shared.luz_lux, "gas": shared.gas_ppm
                    },
                    "origen": "Sensores",
                    "estado_relacionado": shared.estado_global
                })
                
                self.insertar_mongo("system_status", {
                    "fecha_y_hora": now,
                    "tipo_de_dato": "reporte_estado",
                    "valor": shared.estado_global,
                    "origen": "Python",
                    "estado_relacionado": shared.estado_global
                })
                
                self.last_run["MongoDB"] = tiempo_actual
            time.sleep(1)

    def main_loop(self):
        mqtt_thread = threading.Thread(target=self.mqtt_tasks, daemon=True)
        mongo_thread = threading.Thread(target=self.mongodb_tasks, daemon=True)
        
        mqtt_thread.start()
        mongo_thread.start()

        try:
            print("Sistema de Invernadero Iniciado...")
            while self.running:
                self.Sensors.read_sensors()


                decision = self.Motor.evaluar(
                    shared.temperature, shared.humidity,
                    shared.suelo_area1_pct, shared.suelo_area2_pct,
                    shared.luz_lux, shared.gas_ppm,
                    shared.modo_operacion
                )

                if decision:
                    shared.arm64_decision = decision
                    
                    # Registrar en MongoDB 
                    if shared.modo_operacion == "AUTOMATICO":
                        self.insertar_mongo("arm64_results", {
                            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                            "source": "live_engine",
                            "input": f"{shared.temperature},{shared.humidity},{shared.suelo_area1_pct},{shared.suelo_area2_pct},{shared.luz_lux},{shared.gas_ppm}",
                            "decision": decision.get("ACTION", "NO_ACTION"),
                            "result": decision
                        })

                self.Actuadores.update()
                self.Display.update()

                time.sleep(self.intervals["principal"])
                
        except KeyboardInterrupt:
            print("Deteniendo sistema de forma segura...")
            self.Motor.cleanup()
            self.running = False
            self.Sensors.cleanup()      
            self.Actuadores.cleanup()   
            self.Display.cleanup()      
            GPIO.cleanup()              
            self.client.loop_stop()
            self.client.disconnect()
            if self.db is not None:
                self.mongo_client.close()

if __name__ == "__main__":
    app = IOT()
    app.main_loop()
