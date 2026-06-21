AS = as
ASFLAGS = -I src
LD = ld

SRC_DIR = src
BUILD_DIR = build

MODULES = modulo_1_media modulo_2_varianza modulo_3_anomalias modulo_4_prediccion modulo_5_tendencia

all: $(BUILD_DIR) $(MODULES)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

modulo_1_media: $(SRC_DIR)/modulo_1_media.s
	$(AS) $(ASFLAGS) $(SRC_DIR)/modulo_1_media.s -o $(BUILD_DIR)/modulo_1_media.o
	$(LD) $(BUILD_DIR)/modulo_1_media.o -o $(BUILD_DIR)/modulo_1_media
	chmod +x $(BUILD_DIR)/modulo_1_media

modulo_2_varianza: $(SRC_DIR)/modulo_2_varianza.s
	$(AS) $(ASFLAGS) $(SRC_DIR)/modulo_2_varianza.s -o $(BUILD_DIR)/modulo_2_varianza.o
	$(LD) $(BUILD_DIR)/modulo_2_varianza.o -o $(BUILD_DIR)/modulo_2_varianza
	chmod +x $(BUILD_DIR)/modulo_2_varianza

modulo_3_anomalias: $(SRC_DIR)/modulo_3_anomalias.s
	$(AS) $(ASFLAGS) $(SRC_DIR)/modulo_3_anomalias.s -o $(BUILD_DIR)/modulo_3_anomalias.o
	$(LD) $(BUILD_DIR)/modulo_3_anomalias.o -o $(BUILD_DIR)/modulo_3_anomalias
	chmod +x $(BUILD_DIR)/modulo_3_anomalias

modulo_4_prediccion: $(SRC_DIR)/modulo_4_prediccion.s
	$(AS) $(ASFLAGS) $(SRC_DIR)/modulo_4_prediccion.s -o $(BUILD_DIR)/modulo_4_prediccion.o
	$(LD) $(BUILD_DIR)/modulo_4_prediccion.o -o $(BUILD_DIR)/modulo_4_prediccion
	chmod +x $(BUILD_DIR)/modulo_4_prediccion

modulo_5_tendencia: $(SRC_DIR)/modulo_5_tendencia.s
	$(AS) $(ASFLAGS) $(SRC_DIR)/modulo_5_tendencia.s -o $(BUILD_DIR)/modulo_5_tendencia.o
	$(LD) $(BUILD_DIR)/modulo_5_tendencia.o -o $(BUILD_DIR)/modulo_5_tendencia
	chmod +x $(BUILD_DIR)/modulo_5_tendencia

clean:
	rm -rf $(BUILD_DIR)/*
	rm -f $(SRC_DIR)/*.txt
