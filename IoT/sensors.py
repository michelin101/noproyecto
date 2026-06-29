import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn
import adafruit_dht
import RPi.GPIO as GPIO
from globals import shared

PIN_DHT = board.D17
PIN_BTN_MODO = 5
PIN_BTN_RIEGO = 6
PIN_BTN_LUCES = 13
PIN_BTN_SILENCIAR = 19

TEMP_MAXIMA = 30.0
HUM_AMBIENTE_MIN = 30.0
HUM_AMBIENTE_MAX = 80.0
HUM_SUELO_SECO = 30.0
HUM_SUELO_SATURADO = 60.0
LUZ_MINIMA_LUX = 150.0

GAS_UMBRAL_ADVERTENCIA_PPM = 1100.0 
GAS_UMBRAL_EMERGENCIA_PPM = 2000.0
DEBOUNCE_TIME = 0.3

VCC = 3.3
R_FIJA = 10000.0

class Sensors:
    def __init__(self):
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)

        self.dht_device = adafruit_dht.DHT11(PIN_DHT)
        
        self.i2c = busio.I2C(board.SCL, board.SDA)
        self.ads = ADS.ADS1115(self.i2c)
        
        self.canal_suelo1 = AnalogIn(self.ads, 0)
        self.canal_suelo2 = AnalogIn(self.ads, 1)
        self.canal_ldr = AnalogIn(self.ads, 2)
        self.canal_gas = AnalogIn(self.ads, 3)
        
        GPIO.setup(PIN_BTN_MODO, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(PIN_BTN_RIEGO, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(PIN_BTN_LUCES, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(PIN_BTN_SILENCIAR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        
        self.ultima_lectura_dht = 0
        self.ultimo_boton = 0
        self.ultima_lectura_ads = 0 

    def read_sensors(self):
        tiempo_actual = time.time()
        
        self._leer_botones(tiempo_actual)
            
        if tiempo_actual - self.ultima_lectura_dht > 2.0:
            self._leer_dht()
            self.ultima_lectura_dht = tiempo_actual
            
        if tiempo_actual - self.ultima_lectura_ads > 0.5:
            self._leer_analogicos()
            self._leer_gas()
            self.ultima_lectura_ads = tiempo_actual
            
        self._evaluar_estado_global()

    def _leer_botones(self, tiempo_actual):
        if tiempo_actual - self.ultimo_boton < DEBOUNCE_TIME:
            return 
            
        boton_presionado = False
        
        if GPIO.input(PIN_BTN_MODO) == GPIO.LOW:
            shared.modo_operacion = "MANUAL" if shared.modo_operacion == "AUTOMATICO" else "AUTOMATICO"
            shared.mensaje_error_local = f"Modo: {shared.modo_operacion}"
            boton_presionado = True
            
        elif GPIO.input(PIN_BTN_RIEGO) == GPIO.LOW:
            if shared.modo_operacion == "MANUAL":
                shared.comando_riego_remoto = "TOGGLE"
            else:
                shared.mensaje_error_local = "Error: Modo Auto"
            boton_presionado = True
            
        elif GPIO.input(PIN_BTN_LUCES) == GPIO.LOW:
            if shared.modo_operacion == "MANUAL":
                shared.comando_luces_remoto = "TOGGLE"
            else:
                shared.mensaje_error_local = "Error: Modo Auto"
            boton_presionado = True
            
        elif GPIO.input(PIN_BTN_SILENCIAR) == GPIO.LOW:
            shared.buzzer_silenciado_manual = True
            shared.mensaje_error_local = "Alarma Silenciada"
            boton_presionado = True
            
        if boton_presionado:
            self.ultimo_boton = tiempo_actual

    def _leer_dht(self):
        try:
            temp = self.dht_device.temperature
            hum = self.dht_device.humidity
            if temp is not None: shared.temperature = temp
            if hum is not None: shared.humidity = hum
            if temp is not None and temp > TEMP_MAXIMA:
                if shared.estado_gas != "GAS_EMERGENCIA":
                    shared.mensaje_error_local = "ALERTA: TEMP ALTA"
        except RuntimeError:
            pass 

    def _leer_analogicos(self):
        voltaje_s1 = self.canal_suelo1.voltage
        voltaje_s2 = self.canal_suelo2.voltage
        vout_ldr = self.canal_ldr.voltage
        
        val_s1 = max(0, min(100, (voltaje_s1 / 3.3) * 100))
        val_s2 = max(0, min(100, (voltaje_s2 / 3.3) * 100))
        shared.suelo_area1_pct = 100 - val_s1 
        shared.suelo_area2_pct = 100 - val_s2

        if vout_ldr <= 0.01:
            lux = 0.0  
        elif vout_ldr >= 3.29:
            lux = 0.0  
        else:
            r_ldr = R_FIJA * vout_ldr / (VCC - vout_ldr)
            r_ldr_k = r_ldr / 1000.0
            lux = 2000.0  * (r_ldr_k ** -1.4)
            
        shared.luz_lux = lux  

        if shared.suelo_area1_pct < HUM_SUELO_SECO: shared.estado_suelo1 = "SECO"
        elif shared.suelo_area1_pct > HUM_SUELO_SATURADO: shared.estado_suelo1 = "SATURADO"
        else: shared.estado_suelo1 = "NORMAL"
            
        if shared.suelo_area2_pct < HUM_SUELO_SECO: shared.estado_suelo2 = "SECO"
        elif shared.suelo_area2_pct > HUM_SUELO_SATURADO: shared.estado_suelo2 = "SATURADO"
        else: shared.estado_suelo2 = "NORMAL"
            
        shared.estado_luz = "BAJA" if shared.luz_lux < LUZ_MINIMA_LUX else "SUFICIENTE"

    def _leer_gas(self):
        voltaje = self.canal_gas.voltage
        shared.gas_ppm = max(0, (voltaje / 3.3) * 10000.0)
        
        if shared.gas_ppm > GAS_UMBRAL_EMERGENCIA_PPM:
            shared.estado_gas = "GAS_EMERGENCIA"
            shared.gas_detectado = True
        elif shared.gas_ppm > GAS_UMBRAL_ADVERTENCIA_PPM:
            shared.estado_gas = "GAS_ADVERTENCIA"
            shared.gas_detectado = False
            shared.buzzer_silenciado_manual = False
        else:
            shared.estado_gas = "GAS_NORMAL"
            shared.gas_detectado = False
            shared.buzzer_silenciado_manual = False

    def _evaluar_estado_global(self):
        if shared.estado_gas == "GAS_EMERGENCIA":
            shared.estado_global = "EMERGENCIA"
        elif shared.modo_operacion == "MANUAL":
            shared.estado_global = "MODO_MANUAL"
        elif shared.bomba_encendida:
            shared.estado_global = "RIEGO_ACTIVO"
        elif (shared.temperature > TEMP_MAXIMA or 
              shared.humidity < HUM_AMBIENTE_MIN or
              shared.humidity > HUM_AMBIENTE_MAX or
              shared.estado_luz == "BAJA" or 
              shared.estado_suelo1 == "SECO" or 
              shared.estado_suelo2 == "SECO" or
              shared.estado_suelo1 == "SATURADO" or
              shared.estado_suelo2 == "SATURADO" or
              shared.estado_gas == "GAS_ADVERTENCIA"):
            shared.estado_global = "ADVERTENCIA"
        else:
            shared.estado_global = "NORMAL"

    def cleanup(self):
        self.dht_device.exit()
        self.i2c.deinit()
