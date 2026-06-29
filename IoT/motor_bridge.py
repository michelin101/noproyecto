import subprocess
import select

#Este es el motor, aqui ejecutamos un subproceso que corre el motor ARM64 y le pasamos los datos de los sensores para que nos devuelva la decision de que hacer.
class MotorARM64:
    def __init__(self, executable_path="./motor"):
        
        self.proceso = subprocess.Popen(
            [executable_path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )

    def evaluar(self, temp, hum, s1, s2, luz, gas, modo):
        # El ARM64 solo entiende enteros, casteamos las lecturas
        modo_num = 1 if modo == "MANUAL" else 0
        linea = f"{int(temp)},{int(hum)},{int(s1)},{int(s2)},{int(luz)},{int(gas)},{modo_num}\n"

        try:
            # Enviar datos al motor
            print("PYTHON ENVIA A ARM64:", linea.strip())
            self.proceso.stdin.write(linea)
            self.proceso.stdin.flush()
            
            decisiones = []
            while True:
                # Esperar hasta 0.05 segundos por datos en el buffer para capturar múltiples líneas consecutivas
                listos, _, _ = select.select([self.proceso.stdout], [], [], 0.05)
                if listos:
                    # Leer la decisión generada por ARM64
                    respuesta = self.proceso.stdout.readline().strip()
                    if not respuesta: 
                        break
                    print("python RECIBE DE ARM64:", respuesta)
                    datos = self._parsear_respuesta(respuesta)
                    if datos: 
                        decisiones.append(datos)
                else:
                    break # Buffer vacío, terminó el ciclo completo de respuestas de este turno
            return decisiones
        except Exception as e:
            print(f"[ERROR ARM64] {e}")
            return []

    def _parsear_respuesta(self, respuesta):
        # Convierte "ACTION=RIEGO_1_ON;TARGET=SOIL1;RISK=HIGH..." en un diccionario
        datos = {}
        if not respuesta:
            return datos
            
        partes = respuesta.split(";")
        for parte in partes:
            if "=" in parte:
                clave, valor = parte.split("=", 1)
                datos[clave] = valor
        return datos

    def cleanup(self):
        try:
            # Enviamos el caracter de terminación programado en el motor ($) 
            self.proceso.stdin.write("$\n")
            self.proceso.stdin.flush()
            self.proceso.stdin.close()
            self.proceso.wait(timeout=2)
        except:
            pass
