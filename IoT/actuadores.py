import time 
import RPi.GPIO as GPIO 
from globals import shared 

PIN_BOMBA = 25
PIN_VENTILADOR = 23
PIN_LUCES = 18
PIN_BUZZER = 9
PIN_LED_VERDE = 27
PIN_LED_AMARILLO = 22 
PIN_LED_ROJO = 24

DURACION_MAXIMA_RIEGO = 10.0 
COOLDOWN_RIEGO = 15.0        

class Actuadores:
    def __init__(self):
        GPIO.setmode(GPIO.BCM) 
        GPIO.setwarnings(False) 
        
        pines_salida = [PIN_BOMBA, PIN_VENTILADOR, PIN_LUCES, PIN_BUZZER, 
                        PIN_LED_VERDE, PIN_LED_AMARILLO, PIN_LED_ROJO]
        
        for pin in pines_salida:
            GPIO.setup(pin, GPIO.OUT)
            GPIO.output(pin, GPIO.LOW)
            
        self.tiempo_inicio_riego = 0.0
        self.tiempo_fin_riego = 0.0
        
        self.led_verde = False
        self.led_amarillo = False
        self.led_rojo = False

    def update(self): 
        self._control_emergencias()
        self._control_riego()
        self._control_ventilacion()
        self._control_luces()
        self._control_leds_estado()
        self._aplicar_salidas_fisicas()

    def _control_emergencias(self): 
        if shared.comando_alarma_remoto is not None:
            if shared.comando_alarma_remoto == "TOGGLE":
                shared.buzzer_silenciado_manual = not shared.buzzer_silenciado_manual
            elif shared.comando_alarma_remoto == "ON":
                shared.buzzer_silenciado_manual = False
            elif shared.comando_alarma_remoto == "OFF":
                shared.buzzer_silenciado_manual = True
            shared.comando_alarma_remoto = None

        if shared.estado_gas == "GAS_EMERGENCIA":
            shared.estado_ventilacion = "VENTILACION_EMERGENCIA"
            shared.ventilador_encendido = True
            shared.buzzer_encendido = not shared.buzzer_silenciado_manual
            shared.mensaje_error_local = "PELIGRO: GAS DETECTADO"
        else:
            shared.buzzer_encendido = False

    def _control_riego(self): 
        tiempo_actual = time.time()
        
        if shared.bomba_encendida and (tiempo_actual - self.tiempo_inicio_riego > DURACION_MAXIMA_RIEGO):
            self._apagar_bomba()
            return

        if shared.estado_suelo1 == "SATURADO" or shared.estado_suelo2 == "SATURADO":
            if shared.bomba_encendida:
                self._apagar_bomba()
            shared.estado_riego = "BLOQUEADO_POR_SATURACION"
            return
            
        en_cooldown = (tiempo_actual - self.tiempo_fin_riego) < COOLDOWN_RIEGO

        if shared.comando_riego_remoto is not None:
            if not en_cooldown:
                if shared.comando_riego_remoto == "TOGGLE":
                    if shared.bomba_encendida:
                        self._apagar_bomba()
                    else:
                        self._encender_bomba("RIEGO_MANUAL")
                elif shared.comando_riego_remoto == "ON" and not shared.bomba_encendida:
                    self._encender_bomba("RIEGO_MANUAL")
                elif shared.comando_riego_remoto == "OFF" and shared.bomba_encendida:
                    self._apagar_bomba()
            else:
                shared.mensaje_error_local = "Riego en pausa (Cooldown)"
            shared.comando_riego_remoto = None 
            return 

        if shared.modo_operacion == "AUTOMATICO" and not en_cooldown:
            if shared.estado_suelo1 == "SECO" and not shared.bomba_encendida:
                self._encender_bomba("RIEGO_AREA_1")
            elif shared.estado_suelo2 == "SECO" and not shared.bomba_encendida:
                self._encender_bomba("RIEGO_AREA_2")
            elif shared.estado_suelo1 == "NORMAL" and shared.estado_suelo2 == "NORMAL":
                if shared.bomba_encendida:
                    self._apagar_bomba()

    def _encender_bomba(self, estado):
        shared.bomba_encendida = True
        shared.estado_riego = estado
        self.tiempo_inicio_riego = time.time()

    def _apagar_bomba(self):
        if shared.bomba_encendida:
            shared.bomba_encendida = False
            shared.estado_riego = "RIEGO_OFF"
            self.tiempo_fin_riego = time.time()

    def _control_ventilacion(self):
        if shared.estado_gas == "GAS_EMERGENCIA":
            return
            
        if shared.modo_operacion == "AUTOMATICO":
            if shared.temperature > 30.0:
                shared.estado_ventilacion = "VENTILACION_ON"
                shared.ventilador_encendido = True
            else:
                shared.estado_ventilacion = "VENTILACION_OFF"
                shared.ventilador_encendido = False
        else:
            shared.estado_ventilacion = "VENTILACION_MANUAL"
            if shared.comando_ventilador_remoto is not None:
                if shared.comando_ventilador_remoto == "TOGGLE":
                    shared.ventilador_encendido = not shared.ventilador_encendido
                elif shared.comando_ventilador_remoto == "ON":
                    shared.ventilador_encendido = True
                elif shared.comando_ventilador_remoto == "OFF":
                    shared.ventilador_encendido = False
                shared.comando_ventilador_remoto = None

    def _control_luces(self):
        if shared.modo_operacion == "AUTOMATICO":
            shared.luces_encendidas = (shared.estado_luz == "BAJA") 
        else:
            if shared.comando_luces_remoto is not None:
                if shared.comando_luces_remoto == "TOGGLE":
                    shared.luces_encendidas = not shared.luces_encendidas
                elif shared.comando_luces_remoto == "ON":
                    shared.luces_encendidas = True
                elif shared.comando_luces_remoto == "OFF":
                    shared.luces_encendidas = False
                shared.comando_luces_remoto = None
            
    def _control_leds_estado(self):
        estado = shared.estado_global
        self.led_verde = (estado == "NORMAL") 
        self.led_amarillo = (estado == "ADVERTENCIA" or estado == "RIEGO_ACTIVO") 
        self.led_rojo = (estado == "EMERGENCIA") 

    def _aplicar_salidas_fisicas(self): 
        GPIO.output(PIN_BOMBA, GPIO.HIGH if shared.bomba_encendida else GPIO.LOW)
        GPIO.output(PIN_VENTILADOR, GPIO.HIGH if shared.ventilador_encendido else GPIO.LOW)
        GPIO.output(PIN_LUCES, GPIO.HIGH if shared.luces_encendidas else GPIO.LOW)
        GPIO.output(PIN_BUZZER, GPIO.HIGH if shared.buzzer_encendido else GPIO.LOW)
        
        GPIO.output(PIN_LED_VERDE, GPIO.HIGH if self.led_verde else GPIO.LOW)
        GPIO.output(PIN_LED_AMARILLO, GPIO.HIGH if self.led_amarillo else GPIO.LOW)
        GPIO.output(PIN_LED_ROJO, GPIO.HIGH if self.led_rojo else GPIO.LOW)

    def cleanup(self): 
        pines = [PIN_BOMBA, PIN_VENTILADOR, PIN_LUCES, PIN_BUZZER, PIN_LED_VERDE, PIN_LED_AMARILLO, PIN_LED_ROJO]
        for pin in pines:
            GPIO.output(pin, GPIO.LOW)
