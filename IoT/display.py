import time
from rpi_lcd import LCD
from globals import shared

class Display:
    def __init__(self):
        self.lcd = LCD(0x27, 1, 16, 2, True) 
        self.last_t = 0
        self.threshold_data = 2.0     
        self.threshold_message = 3.0  
        self.lcd.clear()
        self.lcd.backlight(True)
        
        self.vista_actual = 0
        self.mostrando_error = False
        self.inicio_error = 0.0

    def display_data(self):
        self.lcd.clear()
        
        if self.vista_actual == 0:
            self.lcd.text(f"Temp: {shared.temperature:.1f}C", 1)
            self.lcd.text(f"Hum: {shared.humidity:.1f}%", 2)
        elif self.vista_actual == 1:
            self.lcd.text(f"Suelo Z1: {shared.suelo_area1_pct:.1f}%", 1)
            self.lcd.text(f"Est: {shared.estado_suelo1}", 2)
        elif self.vista_actual == 2:
            self.lcd.text(f"Suelo Z2: {shared.suelo_area2_pct:.1f}%", 1)
            self.lcd.text(f"Est: {shared.estado_suelo2}", 2)
        elif self.vista_actual == 3:
            self.lcd.text(f"Nivel Luz: {int(shared.luz_lux)} lx", 1)
            self.lcd.text(f"Est: {shared.estado_luz}", 2)
        elif self.vista_actual == 4:
            self.lcd.text(f"Gas: {int(shared.gas_ppm)} ppm", 1)
            self.lcd.text(shared.estado_gas[:16], 2)
        elif self.vista_actual == 5:
            self.lcd.text("Sistema Riego:", 1)
            self.lcd.text(shared.estado_riego[:16], 2)
        elif self.vista_actual == 6:
            self.lcd.text("Ventilacion:", 1)
            estado_v = "ON" if shared.ventilador_encendido else "OFF"
            self.lcd.text(f"Estado: {estado_v}", 2)
        elif self.vista_actual == 7:
            self.lcd.text("Iluminacion:", 1)
            estado_l = "ON" if shared.luces_encendidas else "OFF"
            self.lcd.text(f"Estado: {estado_l}", 2)
        elif self.vista_actual == 8:
            self.lcd.text("Estado Global:", 1)
            self.lcd.text(shared.estado_global, 2)
        elif self.vista_actual == 9:
            self.lcd.text("Modo Operacion:", 1)
            self.lcd.text(shared.modo_operacion, 2)

        self.vista_actual = (self.vista_actual + 1) % 10
        self.last_t = time.time()

    def display_message(self, message): 
        self.lcd.clear()
        self.lcd.text("! ATENCION !", 1)
        self.lcd.text(message[:16], 2)
        self.mostrando_error = True
        self.inicio_error = time.time()
        
        shared.mensaje_error_local = ""

    def update(self):
        tiempo_actual = time.time()
        
        if shared.mensaje_error_local != "":
            self.display_message(shared.mensaje_error_local)
            return

        if self.mostrando_error:
            if shared.estado_global == "EMERGENCIA":
                return
                
            if tiempo_actual - self.inicio_error > self.threshold_message:
                self.mostrando_error = False
                self.last_t = tiempo_actual - self.threshold_data 
            else:
                return

        if tiempo_actual - self.last_t >= self.threshold_data:
            self.display_data()

    def cleanup(self):
        self.lcd.clear()
        self.lcd.backlight(False)
