// =============================================================================
// Modulo: modulo_3_prediccion.s
// Integrante: Jennifer Michelle Rosales Juarez
// Carne: 202400063
// Funcion: Prediccion Futura por Regresion
// =============================================================================

.global _start

.include "utils.s"

.data 
output_file: 
    .asciz "resultado_prediccion.txt"

calc:
    .ascii "CALC=PREDICTION\n"                  // Nombre del calculo
    len_calc = . - calc                         // Longitud del string

col:
    .ascii "COLUMN="
    len_col = . - col

start:
    .ascii "WINDOW_START="
    len_start = . - start

end:
    .ascii "WINDOW_END="
    len_end = . - end

count:
    .ascii "COUNT="
    len_count = . - count

k:
    .ascii "K=5\n"
    len_k = . - k

slope:
    .ascii "SLOPE_X100="
    len_slope = . - slope

intercept:
    .ascii "INTERCEPT_X100="
    len_intercept = . - intercept

predicted:
    .ascii "PREDICTED_5="                       // 5, porque k es valor fijo
    len_predicted = . - predicted

status:
    .ascii "STATUS=OK\n"
    len_status = . - status

.bss
out_buffer: .skip 512							// Buffer Principal, texto que se escribira en el archivo
num_buffer: .skip 32							// Buffer temporal para la conversion itoa

.text
_start:
// =============================================================================
// Leer argumentos (Fila inicial, Fila Final, Numero de Columna)
// =============================================================================
    
    mov x19, sp
    ldr x21, [x19, #16]                         // Direccion de memoria del texto del archivo

    ldr x0, [x19, #24]                          // x0 = Direccion de la fila inicial
    bl atoi_argv                                // Funcion que convierte de texto a numero, esta en el utils
    mov x24, x10                                // x24 = x10 (numero de la fila inicial)

    ldr x0, [x19, #32]                          // x0 = Direccion de la fila final
    bl atoi_argv                                // Funcion que convierte de texto a numero
    mov x25, x10                                // x25 = x10 (numero de la fila final)

    ldr x0, [x19, #40]                          // x0 = Direccion de la columna
    bl atoi_argv                                // Funcion que convierte de texto a numero
    mov x11, x10                                // x11 = x10 (numero de la columna)
    mov x18, x11                                // Guardar la columna, ya que se pierde por la funcion del utils 
	bl utils_read_olumn_to_stack		        // Resive en x11 el numero de filas (inicio y fin) y la columa

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

    mov x4, #0                                  // x4 = 0, suma(Y_i)
    mov x5, #0                                  // x5 = 0, suma(X_i)
    mov x12, #0                                 // x12 = 0, no es peso, lo pense como en mi modulo de la fase anterior, es el indice
    mov x7, x14                                 // puntero actual al inicio x14

ciclo_suma:
    sub x7, x7, #16                             // Baja el puntero a 16 bytes 
    cmp x7, x13                                 // Compara para ver si se llego al limite (x13)
    blt fin_ciclo                               // Salta a fin ciclo, si x7 < x13 (limite mas alto < limite mas bajo)

    ldr x8, [x7]                                // Lee el dato actual que tenemos en el stack
    add x4, x4, x8                              // SUMA(Y_i), suma todos lo calores de la columna
    add x5, x5, x12                             // SUMA(X_i), suma los indices 

    add x12, x12, #1                            // Avanza al siguiente indice, contador++
    b ciclo_suma                                // Repite el ciclo

fin_ciclo:
    // Moverlos a un registro seguro 
    mov x22, x4                                 // x22 = x4, se mueve suma(Y_i) al registro x22, porque el bl ren_lin_spl destruye x4
    mov x23, x5                                 // x23 = x5, hace lo mismo con la anterior, pero para suma(X_i)
    mov x26, x15                                // x26 = x15 (N), igual que lo anterior
    bl reg_lin_spl                              // Llamamos a la funcion y nos retorna M_X100 en x0

    mov x27, x0                                 // x27 = M_X100, ya esta el calculo 

    // Calculos para B_X100
    mov x0, #100                              // x0 = 100
    mul x8, x22, x0                             // x8 = x22 * x0 es suma(Y_i) * 100
    mul x9, x27, x23                            // x9 = x27 * x23 es M_X100 * suma(X_i)
    sub x10, x8, x9                             // x10 = x8 - x9 es ( suma(Y_i) * 100 ) - ( M_X100 * suma(X_i) )
    sdiv x28, x10, x26                          // x28 (B_X100) = x10 / x26 es [( suma(Y_i) * 100 ) - ( M_X100 * suma(X_i) )] / N

    // Calculos para X_FUTURE
    add x6, x26, #5                             // x29 (X_FUTURE) = x26 + x1 es N + k

    // Calcula para Y_PREC
    mul x8, x27, x6                             // x8 = x27 * x29 = M_100 * X_FUTURE
    add x9, x8, x28                             // x9 = x8 + x28  = ( ( M_100 * X_FUTURE) + B_X100 )
    sdiv x1, x9, x0                             // x1 = x9 / x0   = [( ( M_100 * X_FUTURE) + B_X100 )] / 100

    mov x20, x1                                 // Guardamos Y_PRED en x1 para que no se pierda

// =============================================================
// Armar texto de salida en out_buffer (resultado_prediccion.txt)
// =============================================================

    mov sp, x16                                 // Restaurar el stack pointer
    mov x21, x15                                // Guardar x15 (N) antes de que cambiar de rol ya que ese registro lo uso para la escritura

    ldr x15, =out_buffer                        // x15 = Cursor de escritura

    // CALC=PREDICTION
    ldr x0, =calc                               // Direccion donde esta el string
    mov x1, len_calc                            // Longitud del string
    bl copiar_string                       

    // COLUMN=  
    ldr x0, =col
    mov x1, len_col
    bl copiar_string

    //para que muestre el valor
    mov x0, x18                                 // Numero de la columna
    ldr x1, =num_buffer                         // Buffer temporal para el itoa
    bl utils_itoa
    ldr x0, =num_buffer
    bl cstr_loop

    // WINDOW_START=  
    ldr x0, =start
    mov x1, len_start
    bl copiar_string

    //para que muestre el valor
    mov x0, x24                                 // Numero de fila inicial
    ldr x1, =num_buffer                         // Buffer temporal para el itoa
    bl utils_itoa
    ldr x0, =num_buffer
    bl cstr_loop

    // WINDOW_ENDT=  
    ldr x0, =end
    mov x1, len_end
    bl copiar_string

    //para que muestre el valor
    mov x0, x25                                 // Numero de fila final
    ldr x1, =num_buffer                         // Buffer temporal para el itoa
    bl utils_itoa
    ldr x0, =num_buffer
    bl cstr_loop

    // COUNT=  
    ldr x0, =count
    mov x1, len_count
    bl copiar_string

    //para que muestre el valor
    mov x0, x21                                 // Numero de datos
    ldr x1, =num_buffer                         // Buffer temporal para el itoa
    bl utils_itoa
    ldr x0, =num_buffer
    bl cstr_loop

    // K=5
    ldr x0, =k
    mov x1, len_k
    bl copiar_string

     // SLOPE_X100=  
    ldr x0, =slope
    mov x1, len_slope
    bl copiar_string

    //para que muestre el valor
    mov x0, x27                                 // Promedio*100 = M_X100
    ldr x1, =num_buffer                         // Buffer temporal para el itoa
    cmp x0, #0                                  // Ve si es negativ
    bge slope_positivo                          // M_X100 >= 0, si es mayor o igual que 0 salta directamente al itoa porque es positivo y si es negtivo sigue
    
    // Si es negativo escribir - primero
    mov w9, #45                                 // 45 es el ASCII de "-"
    strb w9, [x15], #1                          // Escribir - en el buffer de salida
    neg x0, x0                                  // convertir en positivo

slope_positivo:   
    bl utils_itoa
    ldr x0, =num_buffer
    bl cstr_loop

    // INTERCEP_X100=  
    ldr x0, =intercept
    mov x1, len_intercept
    bl copiar_string

    //para que muestre el valor
    mov x0, x28                                 // Intercepto*100 = B_X100
    ldr x1, =num_buffer                         // Buffer temporal para el itoa
    bl utils_itoa
    ldr x0, =num_buffer
    bl cstr_loop

    // PREDICTEC_5=  
    ldr x0, =predicted
    mov x1, len_predicted
    bl copiar_string

    //para que muestre el valor
    mov x0, x20                                 // Valor futuro estimado = Y_PRED
    ldr x1, =num_buffer                         // Buffer temporal para el itoa
    bl utils_itoa
    ldr x0, =num_buffer
    bl cstr_loop

    // STATUS=OK
    ldr x0, =status
    mov x1, len_status
    bl copiar_string

// Todo eso es lo mismo del modulo 1 del proyecto 1, que fue el que trabaje anteriormente, so copiado
// ============================================================
// Escribir out_buffer al archivo resultado_prediccion_3.s (lleva un tres porque en el proyecto ya hay un modulo que genera esa salida, so para evitar confusiones)
// ============================================================

	ldr x0, =out_buffer							// x0 = inicio del buffer
	sub x1, x15, x0								// x1, longitud = cursor - inicio
	ldr x2, =output_file						// x2 = nombre del archivo
	bl utils_write_result						// crea el archivo resultado_prediccion_3.txt

// =============================================================
// Salir
// =============================================================

	mov x0, #0									// Codigo 0 = exito
	mov x8, #93									// Syscall exit
	svc #0

// =============================================================
// Subrutinas (copiado de mi otro modulo del proyecto 1)
// =============================================================

copiar_string:									// Copia exactamente x1  bytes
	mov x2, x0									// x2 = puntero fuente
	mov x3, x1									// x3 = Contador de Bytes

copiar_loop:
	cbz x3, copiar_fin							// Compara si x3 == 0, Si si salta a copiar_fin
	ldrb w4, [x2], #1							// Lee el byte y avanza la fuente
	strb w4, [x15], #1							// Escribe el byte y avanza la fuente
	sub x3, x3, #1							    // Decrementa el contador x3--
	b copiar_loop

copiar_fin:
	ret

// Copia hasta encontra /n o /0
cstr_loop:
	ldrb w2, [x0], #1							// Lee 1 byte desde x0 y avanza
	cbz w2, cstr_fin							// Si el byte leido es cero, terminar sin copiarlo
	strb w2, [x15], #1							// Copia el byte al buffer de salia y avanza
	cmp w2, #10								    // Compara si es \n
	beq cstr_fin								// Si es \n termina
	b cstr_loop									// Si no es \n o \0 vuelve al inicio para leer el siguiente byte

cstr_fin:
	ret

// ===========================================================
// Aca esta el calculo para M_X100, Copiado del modulo de regresion
// ===========================================================
reg_lin_spl:
    mov x0, #0                                  // x0 = contador del indice X_im 
    mov x1, #0                                  // x1 = suma(x_i * y_i)
    mov x2, #0                                  // x2 = suma(x_i)
    mov x3, #0                                  // x3 = suma(y_i)
    mov x4, #0                                  // x4 = (x_i * x_i)
    mov x5, x14                                 // x5 = copia el inicio de los datos (limite alto)
    mov x6, x26                                 // x6 = N (cantidad de datos)

loop:
    ldr x9, [x5, #-16]!                         // Esto va a leer Y_i y baja el puntero 
    mul x7, x0, x9                              // x7 = (x_i * y_i)
    add x1, x1, x7                              // x1 = suma(x_i * y_i) acumula
    add x2, x2, x0                              // x2 = suma(X_i) acumula
    add x3, x3, x9                              // x3 = suma(Y_i) acumula
    mul x10, x0, x0                             // x10 = (x_i) * (x_i)
    add x4, x4, x10                             // x4 = suma((x_i) * (x_i)) acumulado
    add x0, x0, #1                              // x0 = aumento el contador del subindice y las x / el siguiente indice
    cmp x0, x6                                  // comparando para el n-1, para ver si se llego a N
    blt loop                                    // retorno al loop por si es cierto el n-1 (que si no se llego a N, repite) 

// Calculo de M_X100
    mul x11, x6, x1                             // N(sum(x_i * y_i))
    mul x12, x2, x3                             // (suma(X_i) * suma(Y_i))
    sub x13, x11, x12                           // El numerador completo
    mul x3, x6, x4                              // N(sum((x_i) * (x_i)))
    mul x4, x2, x2                              // (suma(X_i) * suma(X_i))
    sub x5, x3, x4                              // x5 = Denominador completo
    mov x8, #100
    mul x11, x13, x8                            // numerador * 100
    sdiv x0, x11, x5                            // x0 (M_X100) = (numerador * 100)/ denominador
    ret 
