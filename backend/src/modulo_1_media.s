// ============================================================
// Modulo: modulo_1_media.s
// Integrante: Jennifer Michelle Rosales Juarez
// Carne: 202400063
// Funcion: Media Ponderada
// ============================================================

.global _start

.include "utils.s"

.data
output_file:	
	.asciz "resultado_media.txt"				// Nombre del Archivo de Salida

calc:	
	.ascii "CALC=WEIGHTED_MEAN\n"				// Nombre del Modulo
	len_calc = . - calc					 		// Longitud del string, calculada automáticamente

col:
	.ascii "COLUMN="							// Columna en la cual estamos trabajando
	len_col = . - col

start:
	.ascii "WINDOW_START="						// Linea/Fila inicial
	len_start = . - start

w_end:
	.ascii "WINDOW_END="						// Linea/Fila final
	len_w_end = . - w_end

total:
	.ascii "TOTAL_VALUES="						// Total de valores
	len_total = . - total						// Longitud, (.) es la direccion actual de la memoria

suma:
	.ascii "SUM_X="								// Suma de cada valor sin su peso
	len_suma = . - suma							// Longitud, se necesita para indicar cuantos bytes hay que escribir

peso_suma:
	.ascii "WEIGHT_SUM="						// Suma de los pesos
	len_peso = . -peso_suma						// Longitud, len_peso = posicion_actual - posicion_inicial

media:
	.ascii "WEIGHTED_MEAN="						// Media Ponderada
	len_media = . - media

status_ok:
	.ascii "STATUS=OK\n"
	len_status_ok = . - status_ok

// Para el archivo de salida pero de lo errores
err_msg_col:
    .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_OUT_OF_RANGE\n"
    len_err_msg_col = . - err_msg_col

err_msg_rango:
    .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=END_LINE_EXCEEDS_FILE_LENGTH\n"
    len_err_msg_rango = . - err_msg_rango

err_msg_datos:
    .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=NO_VALID_DATA_IN_RANGE\n"
    len_err_msg_datos = . - err_msg_datos

.bss
out_buffer: .skip 512							// Buffer Principal, texto que se escribira en el archivo
num_buffer: .skip 32							// Buffer temporal para la conversion itoa


.text
_start:
// =============================================================
// Leer argumento de linea de comando y cargar datos del .csv
// =============================================================

	mov x19, sp									// Para no perder la direccion de los argumnetos 
	ldr x21, [x19, #16]							// Es la direccion de memoria del texto del archivo (o sea su nombre)

	// Convertir el argumento de la Linea Inicial 
	ldr x0, [x19, #24]							// x0 = Direccion de la linea inicial
	bl atoi_argv								// Ejecuta la funcion de conversion de texto a numero (atoi)
	mov x24, x10								// x24 = x10 (numero de la fila inicial, x10 porque la funcion retorna ahi)

	// Convertir el argumento de la Linea Final
	ldr x0, [x19, #32]							// x0 = Direccion de la linea final 
	bl atoi_argv
	mov x25, x10								// x25 = x10 (numero de fila final)

	// Convertir el argumente de la columna
	ldr x0, [x19, #40]							// x0 = Direccion del numero de columna
	bl atoi_argv
	mov x11, x10								// x11 = x10
	mov x18, x11								// x18 =x11 Volver a guardar la columna 
	bl utils_read_column_to_stack				// Resive en x11 el numero de la columa y filas (inicio y fin), y con esto recorre las filas y las extrae con columna, lee el bloque

	mov x13, x0									// x13 = inicio de datos en el stack (mas baja)
	mov x14, x1									// x14 = limite de datos en el stack (mas alta)
	mov x15, x2									// x15 = N (cantidad de datos reales/validos que se guardaron en total)
	mov x16, x3									// x16 = sp a restaurar despues (direccion)	
	mov x17, x4									// Codigo de error

	cbnz x17, error_salida						// Si x17 != 0, esto es de que el utils reporto el error
	cbz x15, error_datos						// Si N == 0, no hay datos

	sub x8, x25, x24 							// x8 = x25(fila final) - x24(fila inicial)
	add x8, x8, #1								// x8 = N esperado = x25 -x24 + 1
	cmp x15, x8
	blt error_rango_excedido					// si N real < N esperado, el archivo se queda corto

// =============================================================
// Ciclo de Calculo
// =============================================================

	mov x4, #0									// x4 = SUM_X = 0, acumulador SUM_X (suma simple de todos los valores sin peso)
	mov x5, #0									// x5 = WEIGHTED_SUM = 0, acumulador WEIGHTED_SUM (suma de X_i*W_i, suma ponderada)
	mov x12, #1									// x12 = Peso W_i =1, (crece de 1 hasta la linea final)
	mov x7, x14									// x7 = Puntero al dato actual = inicio

ciclo_suma:
	sub x7, x7, #16								// Bajar 16 bytes primero antes de leer
	cmp x7, x13									// Pregunta si el puntero actual llego al limite
	blt fin_ciclo								// Si x7 < x13, sale del ciclo

	ldr x8, [x7]								// x8 = X_i (valor del dato actual)
	add x4, x4, x8								// SUM_X += X_i
	
	mul x9, x8, x12								// x9 = X_i*W_i
	add x5, x5, x9								// WEIGHTED_SUM += X_i*W_i
	
	add x12, x12, #1							// W_i++, siguiente peso
	b ciclo_suma								// salto incodicional, regresa al inicio del ciclo, repetir ciclo

fin_ciclo:							// Calcular la media ponderada: WEIGHTED_SUM/WEIGHT_SUM
	// Calculo de la suma de los pesos (WEIGHT_SUM) - (N(N+1))/2
	add x9, x15, #1								// N + 1
	mul x7, x9, x15 							// N * (N + 1)
	lsr x10, x7, #1								// x10 = N * (N + 1) / 2
	mov x20, x10								// Salvar WEIGHT_SUM

	udiv x11, x5, x10							// x11 = WEIGHTED_SUM / x10 (WEIGHT_SUM)
	mov x23, x11								// x23 = guarda WEIGHTED_MEAN aca

	mov sp, x16									// Restaura el stack pointer
	mov x19, x15								// Salvar N antes de x15 cambie de rol

// =============================================================
// Armar texto de salida en out_buffer
// =============================================================

	ldr x15, =out_buffer						// x15 = cursor de escritura, empieza al inicio

	//"CALC=WEIGHTED_MEAN\n"
	ldr x0, =calc								// x0 = direccion donde esta guardado el string
	mov x1, len_calc							// x1 = longitud del string
	bl copiar_string							// Subrutina que toma x0 y x1, y los copia uno a uno hacia donde apunta x15

	//COLUMN= "columna"
	ldr x0, =col
	mov x1, len_col
	bl copiar_string
	mov x0, x18									// x0 = Columna
	ldr x1, =num_buffer							// x1 = buffer temporal para itoa
	bl utils_itoa								// Convierte el numero entero que esta en x0 a texto ASCII
	ldr x0, =num_buffer
	bl cstr_loop

	//WINDOW_START= "linea inicial"
	ldr x0, =start
	mov x1, len_start
	bl copiar_string
	mov x0, x24									// x0 = linea Incial
	ldr x1, =num_buffer							// x1 = buffer temporal para itoa
	bl utils_itoa								// Convierte el numero entero que esta en x0 a texto ASCII
	ldr x0, =num_buffer
	bl cstr_loop

	//WINDOW_END= "linea final"
	ldr x0, =w_end
	mov x1, len_w_end
	bl copiar_string
	mov x0, x25									// x0 = linea Final
	ldr x1, =num_buffer							// x1 = buffer temporal para itoa
	bl utils_itoa								// Convierte el numero entero que esta en x0 a texto ASCII
	ldr x0, =num_buffer
	bl cstr_loop

	//TOTAL_VALUES= "valor calculado"
	ldr x0, =total
	mov x1, len_total
	bl copiar_string
	mov x0, x19									// x0 = N (total de datos)
	ldr x1, =num_buffer							// x1 = buffer temporal para itoa
	bl utils_itoa								// Convierte el numero entero que esta en x0 a texto ASCII
	ldr x0, =num_buffer
	bl cstr_loop

	//SUM_X= "valor calculado"
	ldr x0, =suma
	mov x1, len_suma
	bl copiar_string
	mov x0, x4									// x0 = SUM_X (numero a convertir)
	ldr x1, =num_buffer							// x1 = buffer temporal para itoa
	bl utils_itoa								// Convierte el numero entero que esta en x0 a texto ASCII
	ldr x0, =num_buffer							// Apunta x0 al indicion del texto que se acaba de producir
	bl cstr_loop								// Copia num_buffer hacia out_buffer hasta encontrar \n o \0

	//WEIGHT_SUM= "valor calculado" 
	ldr x0, =peso_suma
	mov x1, len_peso
	bl copiar_string
	mov x0, x20									// x0 = WEIGHT_SUM
	ldr x1, =num_buffer
	bl utils_itoa
	ldr x0, =num_buffer
	bl cstr_loop

	//WEIGHTED_MEAN="valor calculado"
	ldr x0, =media
	mov x1, len_media
	bl copiar_string
	mov x0, x23									// x0 = x23 (WEIGHTED_MEAN guardado antes)
	ldr x1, =num_buffer
	bl utils_itoa
	ldr x0, =num_buffer
	bl cstr_loop

	//STATUS=OK
	ldr x0, =status_ok
	mov x1, len_status_ok
	bl copiar_string

// ============================================================
// Escribir out_buffer al archivo resultado_media.s
// ============================================================

	ldr x0, =out_buffer						// x0 = inicio del buffer
	sub x1, x15, x0							// x1, longitud = cursor - inicio
	ldr x2, =output_file					// x2 = nombre del archivo
	bl utils_write_result					// crera resultado_media.txt

// =============================================================
// Salir
// =============================================================
	
	mov x0, #0								// Codigo 0 = exito
	mov x8, #93								// Syscall exit
	svc #0

// =============================================================
// Errores
// =============================================================

error_salida:
	ldr x15, =out_buffer						// x15 = cursor de escritura

	ldr x0, =calc								// x0 = direccion donde se guarda "CALC=WEIGHTED_MEAN"
    mov x1, len_calc							// x1 = longitud
    bl copiar_string
    cmp x17, #1									// x17 == 1, salta al error_es_col, ya que el uno indica que es error de columna
    beq error_es_col
    cmp x17, #2									// x17 == 2, salta a error_es_rango, porque 2 es error del rango
    beq error_es_rango
    b error_fin									// Si todo bien se va a error fin, a terminar la estitura y salida del archivo

error_es_col:
    ldr x0, =err_msg_col
    mov x1, len_err_msg_col
    bl copiar_string
    b error_fin

error_es_rango:
    ldr x0, =err_msg_rango
    mov x1, len_err_msg_rango
    bl copiar_string
    b error_fin

error_rango_excedido:
	ldr x15, =out_buffer
	ldr x0, =calc
	mov x1, len_calc
	bl copiar_string
	ldr x0, =err_msg_rango
	mov x1, len_err_msg_rango
	bl copiar_string
	b error_fin

error_datos:
    ldr x15, =out_buffer

    ldr x0, =calc
    mov x1, len_calc
    bl copiar_string
    ldr x0, =err_msg_datos
    mov x1, len_err_msg_datos
    bl copiar_string

error_fin:										// salida
    ldr x0, =out_buffer
    sub x1, x15, x0
    ldr x2, =output_file
    bl utils_write_result

    mov x0, #1
    mov x8, #93
    svc #0

// =============================================================
// Subrutinas
// =============================================================

copiar_string:								// Copia exactamente x1  bytes
	mov x8, x0								// x8 = puntero fuente
	mov x9, x1								// x9 = Contador de Bytes

copiar_loop:
	cbz x9, copiar_fin						// Compara si x9 == 0, Si si salta a copiar_fin
	ldrb w10, [x8], #1						// Lee el byte y avanza la fuente
	strb w10, [x15], #1						// Escribe el byte y avanza la fuente
	sub x9, x9, #1							// Decrementa el contador x9--
	b copiar_loop

copiar_fin:
	ret

// Copia hasta encontra /n o /0
cstr_loop:
	ldrb w16, [x0], #1						// Lee 1 byte desde x0 y avanza
	cbz w16, cstr_fin						// Si el byte leido es cero, terminar sin copiarlo
	strb w16, [x15], #1						// Copia el byte al buffer de salia y avanza
	cmp w16, #10							// Compara si es \n
	beq cstr_fin							// Si es \n termina
	b cstr_loop								// Si no es \n o \0 vuelve al inicio para leer el siguiente byte

cstr_fin:
	ret
