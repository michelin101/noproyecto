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

modulo:
	.ascii "MODULE=WEIGHTED_MEAN\n"				// Nombre del Modulo
	len_modulo = . - modulo					// Longitud del string, calculada automáticamente

total:
	.ascii "TOTAL_VALUES=30\n"				// Total de valores, fijos (30)
	len_total = . - total					// Longitud, (.) es la direccion actual de la memoria

suma:
	.ascii "SUM_X="						// Suma de cada valor sin su peso
	len_suma = . - suma					// Longitud, se necesita para indicar cuantos bytes hay que escribir

peso_suma:
	.ascii "WEIGHT_SUM=465\n"				// Suma de los pesos, siempre sera 465
	len_peso = . -peso_suma					// Longitud, len_peso = posicion_actual - posicion_inicial

media:
	.ascii "WEIGHTED_MEAN="					// Media Ponderada
	len_media = . - media

.bss
out_buffer: .skip 512						// Buffer Principal, texto que se escribira en el archivo
num_buffer: .skip 32						// Buffer temporal para la conversion itoa


.text
_start:
	mov x20, sp						// Guarda el sp antes
	stp x29, x30, [sp, #-16]!				// Guardamos x29 (frame pointer) y x30 (link register) en el stack
	mov x29, sp						// Actualiza el frame pointer, apunta al stack actual

// =============================================================
// Leer argumento de linea de comando y cargar datos del .csv
// =============================================================

	ldr x0, [x20, #16]					// x0 = puntero al string del argumento
	ldrb w11, [x0]						// w11 = primer byte = caracter ASCII del numero
	sub x11, x11, #48					// Convertir ASCII a entero

	bl utils_read_column_to_stack				// Resive en x11 el numero de la columa y con esto recorre las filas y extrae solo esa columna, lee columna

	mov x24, x0						// x24 = inicio de datos en el stack (mas baja)
	mov x25, x1						// x25 = limite de datos en el stack (mas alta)
	mov x26, x3						// x26 = sp a restaurar despues


// =============================================================
// Ciclo de Calculo
// =============================================================

	mov x4, #0						// x4 = SUM_X = 0, acumulador SUM_X (suma simple de todos los valores sin peso)
	mov x5, #0						// x5 = WEIGHTED_SUM = 0, acumulador WEIGHTED_SUM (suma de X_i*W_i, suma ponderada)
	mov x14, #1						// x14 = Peso W_i =1, (crece: 1 hasta 30)
	mov x7, x25						// x7 = Puntero al dato actual = inicio

ciclo_suma:
	sub x7, x7, #16						// Bajar 16 bytes primero antes de leer
	cmp x7, x24						// Pregunta si el puntero actual llego al limite
	blt fin_ciclo						// Si x7 < x24, sale del ciclo

	ldr x8, [x7]						// x8 = X_i (valor del dato actual)
	add x4, x4, x8						// SUM_X += X_i

	mul x9, x8, x14						// x9 = X_i*W_i
	add x5, x5, x9						// WEIGHTED_SUM += X_i*W_i

	add x14, x14, #1					// W_i++, siguiente peso
	b ciclo_suma						// salto incodicional, regresa al inicio del ciclo, repetir ciclo

fin_ciclo:							// Calcular la media ponderada: WEIGHTED_SUM/465
	mov x10, #465						// x10 = 465, valor fijo
	udiv x11, x5, x10					// x11 = WEIGHTED_SUM/465
	mov x23, x11						// x23 = guarda WEIGHTED_MEAN aca

	mov sp, x26						// Restaura el stack pointer


// =============================================================
// Armar texto de salida en out_buffer
// =============================================================

	ldr x15, =out_buffer					// x15 = cursor de escritura, empieza al inicio

	//"MODULE=WEIGHTE_MEAN\n"
	ldr x0, =modulo						// x0 = direccion donde esta guardado el string
	mov x1, len_modulo					// x1 = longitud del string
	bl copiar_string					// Subrutina que toma x0 y x1, y los copia uno a uno hacia donde apunta x15

	//"TOTAL_VALUES=30\n"
	ldr x0, =total
	mov x1, len_total
	bl copiar_string

	//SUM_X= "valor calculado"
	ldr x0, =suma
	mov x1, len_suma
	bl copiar_string

	mov x0, x4						// x0 = SUM_X (numero a convertir)
	ldr x1, =num_buffer					// x1 = buffer temporal para itoa
	bl utils_itoa						// Convierte el numero entero que esta en x0 a texto ASCII

	ldr x0, =num_buffer					// Apunta x0 al indicion del texto que se acaba de producir
	bl copiar_cstr						// Copia num_buffer hacia out_buffer hasta encontrar \n o \0

	//WEIGHTED_SUM
	ldr x0, =peso_suma
	mov x1, len_peso
	bl copiar_string

	//WEIGHTED_MEAN="valor calculado"
	ldr x0, =media
	mov x1, len_media
	bl copiar_string

	mov x0, x23						// x0 = x23 (WEIGHTED_MEAN guardado antes)

	ldr x1, =num_buffer
	bl utils_itoa
	ldr x0, =num_buffer
	bl copiar_cstr


// ============================================================
// Escribir out_buffer al archivo resultado_media.s
// ============================================================

	ldr x0, =out_buffer					// x0 = inicio del buffer
	sub x1, x15, x0						// x1, longitud = cursor - inicio
	ldr x2, =output_file					// x2 = nombre del archivo
	bl utils_write_result					// crera resultado_media.txt

// =============================================================
// Salir
// =============================================================

	mov x0, #0						// Codigo 0 = exito
	mov x8, #93						// Syscall exit
	svc #0

// =============================================================
// Subrutinas
// =============================================================

copiar_string:							// Copia exactamente x1  bytes
	stp x29, x30, [sp, #-16]!
	mov x29, sp

	mov x16, x0						// x16 = puntero fuente
	mov x17, x1						// x17 = Contador de Bytes

copiar_loop:
	cbz x17, copiar_fin					// Compara si x17 == 0, Si si salta a copiar_fin
	ldrb w18, [x16], #1					// Lee el byte y avanza la fuente
	strb w18, [x15], #1					// Escribe el byte y avanza la fuente
	sub x17, x17, #1					// Decrementa el contador x17--
	b copiar_loop

copiar_fin:
	ldp x29, x30, [sp], #16
	ret

copiar_cstr:							// Copia hasta encontra /n o /0
	stp x29, x30, [sp, #-16]!
	mov x29, sp

cstr_loop:
	ldrb w16, [x0], #1					// Lee 1 byte desde x0 y avanza
	cbz w16, cstr_fin					// Si el byte leido es cero, terminar sin copiarlo
	strb w16, [x15], #1					// Copia el byte al buffer de salia y avanza
	cmp w16, #10						// Compara si es \n
	beq cstr_fin						// Si es \n termina
	b cstr_loop						// Si no es \n o \0 vuelve al inicio para leer el siguiente byte

cstr_fin:
	ldp x29, x30, [sp], #16
	ret

