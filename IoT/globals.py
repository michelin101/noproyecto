class GlobalState:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._init()
        return cls._instance

    def _init(self):
        self.estado_global = "NORMAL"
        self.modo_operacion = "AUTOMATICO"  
        self.mensaje_error_local = ""       
        
        self.temperature = 0.0
        self.humidity = 0.0
        
        self.suelo_area1_pct = 0.0
        self.suelo_area2_pct = 0.0
        self.estado_suelo1 = "NORMAL" 
        self.estado_suelo2 = "NORMAL"
        
        self.luz_lux = 0.0            
        self.estado_luz = "SUFICIENTE"

        self.gas_ppm = 0.0
        self.gas_detectado = False
        self.estado_gas = "GAS_NORMAL" 
        
        self.bomba_encendida = False
        self.estado_riego = "RIEGO_OFF" 
        self.ventilador_encendido = False
        self.estado_ventilacion = "VENTILACION_OFF"
        self.luces_encendidas = False
        self.buzzer_encendido = False
        self.buzzer_silenciado_manual = False
        
        self.comando_riego_remoto = None
        self.comando_luces_remoto = None
        self.comando_ventilador_remoto = None
        self.comando_alarma_remoto = None

shared = GlobalState()
