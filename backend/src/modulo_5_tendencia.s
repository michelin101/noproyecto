/*
    ===========================================================================
    Módulo: MODULO 5
    Rutina: Tendencia Acumulada Avanzada
    Proyecto: Invernadero Inteligente IoT - Fase 2
    Responsable: Juan Manuel Ordoñez Sandoval - 202400006 
    ===========================================================================
    Parámetros esperados (argv):
       argv[1] = archivo_entrada   
       argv[2] = linea_inicial
       argv[3] = linea_final
       argv[4] = columna_sensor (numero)
    ===========================================================================
*/

.data
    // Archivo de salida requerido
    file_out:    .asciz "resultado_tendencia.txt"

    // Cadenas de texto fijas para el formato de salida
    str_calc:    .asciz "CALC=ADVANCED_TREND\n"
    str_col:     .asciz "COLUMN="
    str_wstart:  .asciz "WINDOW_START="
    str_wend:    .asciz "WINDOW_END="
    str_count:   .asciz "COUNT="
    str_inc:     .asciz "INCREMENTS="
    str_dec:     .asciz "DECREMENTS="
    str_mxu:     .asciz "MAX_UP_STREAK="
    str_mxd:     .asciz "MAX_DOWN_STREAK="
    str_acc:     .asciz "ACCUM_DIFF="
    str_tr:      .asciz "TREND="
    str_up:      .asciz "UP\n"
    str_dw:      .asciz "DOWN\n"
    str_st:      .asciz "STABLE\n"
    str_neg:     .asciz "-"
    str_ok:      .asciz "STATUS=OK\n"

    // Salidas de error estructuradas
    err_args:
        .ascii "STATUS=ERROR\nERROR=INVALID_INPUT\nDETAIL=EXPECTED_3_ARGS\n"
        len_err_args = . - err_args

    err_col:
        .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_NOT_SUPPORTED\n"
        len_err_col = . - err_col

    err_insuff:
        .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=TREND_REQUIRES_AT_LEAST_2_VALUES\n"
        len_err_insuff = . - err_insuff

.bss
    // Buffer masivo para ensamblar el texto final antes de escribir al archivo
    out_buf:  .skip 2048
    num_buf:  .skip 32            // Buffer local para conversiones itoa 

.text
.global _start

_start:
    // ========================================================================
    // 1. OBTENER ARGUMENTOS DEL SISTEMA (argv)
    // ========================================================================
    mov x9, sp               // x9 = referencia fija al inicio del stack de args
    ldr x0, [x9]             // Cargar argc (Cantidad de argumentos)
    cmp x0, #5               // Se necesitan: prog, archivo, inicio, fin, columna
    blt exit_err_args        // Si no hay suficientes argumentos, abortar

    ldr x21, [x9, #16]       // argv[1] = puntero a archivo_entrada

    // Parseo de la linea inicial
    ldr x0, [x9, #24]
    bl atoi_argv
    mov x24, x10             // x24 = linea_inicial

    // Parseo de la linea final
    ldr x0, [x9, #32]
    bl atoi_argv
    mov x25, x10             // x25 = linea_final

    // Parseo de la columna seleccionada
    ldr x0, [x9, #40]
    bl atoi_argv
    mov x11, x10             // x11 almacenará el número de columna parseado

    // ========================================================================
    // 2. EXTRAER DATOS CON UTILS.S
    // ========================================================================
    // Llamamos a la rutina común de lectura
    bl utils_read_column_to_stack
    // Retornos: x0 = Top del stack (X_n), x1 = Fondo del stack original

    cmp x4, #1               // 1 = la columna no existe en el encabezado
    beq exit_err_col
    cmp x4, #2               // 2 = rango invalido (lineas fuera de limite)
    beq exit_err_args
    cmp x2, #2               // Tendencia requiere al menos 2 datos
    blt exit_err_insuff

    mov x19, x0              // Guardar el top del stack (dato mas reciente)
    mov x20, x1              // Guardar el fondo del stack (dato mas viejo)
    mov x22, x2              // Cantidad de datos leidos
    mov x23, x3              // Posicion para restaurar el stack pointer (sp)

    // ========================================================================
    // 3. INICIALIZAR REGISTROS DE LÓGICA
    // ========================================================================
    mov x6, #0               // Contador total de INCREMENTS
    mov x7, #0               // Contador total de DECREMENTS 
    mov x15, #0              // Racha actual de crecimiento (Current Up)
    mov x16, #0              // Racha MÁXIMA de crecimiento (Max Up Streak)
    mov x17, #0              // Racha actual de decremento (Current Down)
    mov x18, #0              // Racha MÁXIMA de decremento (Max Down Streak)

    // El primer dato guardado está en el fondo del stack. Nos ubicamos ahí.
    mov x4, x20
    sub x4, x4, #16          // x4 = Puntero al PRIMER dato cronológico (X_1)
    
    ldr x26, [x4]            // Resguardar X_1 absoluto en x26 para la formula ACCUM_DIFF
    mov x8, x26             // Inicializar "Dato Anterior" (Prev) = X_1
    
    // ========================================================================
    // 4. CICLO DE ANÁLISIS DE TENDENCIA
    // ========================================================================
loop_data:
    sub x4, x4, #16          // Mover puntero 16 bytes arriba (Siguiente dato cronológico)
    cmp x4, x19              // Comprobar si ya cruzamos el top del stack
    blt end_loop             // Si es menor, ya leímos los datos correspondientes

    ldr x5, [x4]             // Cargar Dato Actual (X_i)

    cmp x5, x8              // Comparar Dato Actual (X_i) con Dato Anterior (X_i-1)
    bgt is_greater           // Si es mayor, saltar a lógica de incremento
    blt is_less              // Si es menor, saltar a lógica de decremento

is_equal:
    // Si son iguales, se rompen ambas rachas actuales
    mov x15, #0             
    mov x17, #0             
    b next_iter

is_greater:
    add x6, x6, #1           // INCREMENTS++
    add x15, x15, #1         // Racha actual de subida++
    mov x17, #0              // Romper racha de bajada
    
    cmp x15, x16             // ¿Racha actual supera a la racha máxima registrada?
    ble next_iter           
    mov x16, x15             // MAX_UP_STREAK = racha actual
    b next_iter

is_less:
    add x7, x7, #1           // DECREMENTS++
    add x17, x17, #1         // Racha actual de bajada++
    mov x15, #0              // Romper racha de subida
    
    cmp x17, x18             // ¿Racha actual supera a la racha máxima registrada?
    ble next_iter
    mov x18, x17             // MAX_DOWN_STREAK = racha actual

next_iter:
    mov x8, x5              // El dato actual se convierte en el "Anterior"
    b loop_data

end_loop:
    // Al salir, x8 contiene el último dato procesado (X_n)
    // OPTIMIZACIÓN MATEMÁTICA: Suma Telescópica -> Sigma(X_i - X_i-1) = X_n - X_1
    sub x27, x8, x26        // x27 = ACCUM_DIFF

    // ========================================================================
    // 5. CONSTRUCCIÓN DEL BUFFER DE TEXTO DE SALIDA
    // ========================================================================
    ldr x1, =out_buf
    strb wzr, [x1]           // Colocar byte nulo inicial por seguridad

    ldr x0, =str_calc
    bl append_string

    ldr x0, =str_col
    bl append_string
    mov x0, x11
    bl append_number

    ldr x0, =str_wstart
    bl append_string
    mov x0, x24
    bl append_number

    ldr x0, =str_wend
    bl append_string
    mov x0, x25
    bl append_number

    ldr x0, =str_count
    bl append_string
    mov x0, x22
    bl append_number

    ldr x0, =str_inc         // "INCREMENTS="
    bl append_string
    mov x0, x6
    bl append_number

    ldr x0, =str_dec         // "DECREMENTS="
    bl append_string
    mov x0, x7
    bl append_number

    ldr x0, =str_mxu         // "MAX_UP_STREAK="
    bl append_string
    mov x0, x16
    bl append_number

    ldr x0, =str_mxd         // "MAX_DOWN_STREAK="
    bl append_string
    mov x0, x18
    bl append_number

    ldr x0, =str_acc         // "ACCUM_DIFF="
    bl append_string

    // Verificar si ACCUM_DIFF es negativo para colocar el guión manualmente
    mov x0, x27
    cmp x27, #0
    bge diff_positive        // Si es >= 0, imprimir numero normal
    
    // Lógica para números negativos
    ldr x0, =str_neg        
    bl append_string         // Añadir "-"
    neg x0, x27              // Volver el número positivo temporalmente para itoa
diff_positive:
    bl append_number         // Añadir el número al buffer

    ldr x0, =str_tr          // "TREND="
    bl append_string

    // Evaluar estado final de la tendencia
    cmp x27, #0
    bgt trend_up
    blt trend_down

trend_stable:
    ldr x0, =str_st          // "STABLE"
    bl append_string
    b finish_trend

trend_up:
    ldr x0, =str_up          // "UP"
    bl append_string
    b finish_trend

trend_down:
    ldr x0, =str_dw          // "DOWN"
    bl append_string

finish_trend:
    ldr x0, =str_ok
    bl append_string

    // ========================================================================
    // 6. ESCRITURA FÍSICA AL ARCHIVO .TXT
    // ========================================================================
write_file:
    // Calcular longitud exacta del buffer dinámico creado
    ldr x0, =out_buf
    mov x1, #0
len_loop:
    ldrb w2, [x0, x1]        // Leer byte
    cbz w2, exec_write       // Si es nulo, terminamos de contar
    add x1, x1, #1           // Longitud++
    b len_loop
    
exec_write:
    ldr x2, =file_out        // x2 recibe el nombre del archivo final
    bl utils_write_result    // Llamada al syscall 64 de utilidades

    // ========================================================================
    // 7. RESTAURACIÓN Y SALIDA
    // ========================================================================
    mov sp, x23              // Restaurar el stack a como estaba antes de leer CSV
    mov x0, #0
    mov x8, #93              // Syscall: exit
    svc #0

// --- Control de errores de argumentos ---
exit_err_args:
    ldr x0, =err_args
    mov x1, len_err_args
    ldr x2, =file_out
    bl utils_write_result
    mov x0, #1
    mov x8, #93
    svc #0

exit_err_col:
    ldr x0, =err_col
    mov x1, len_err_col
    ldr x2, =file_out
    bl utils_write_result
    mov x0, #1
    mov x8, #93
    svc #0

exit_err_insuff:
    ldr x0, =err_insuff
    mov x1, len_err_insuff
    ldr x2, =file_out
    bl utils_write_result
    mov x0, #1
    mov x8, #93
    svc #0


// ============================================================================
// SUBRUTINA LOCAL: append_string
// Busca el final de out_buf y concatena la cadena apuntada por x0
// ============================================================================
append_string:
    ldr x1, =out_buf
find_end:
    ldrb w2, [x1]            // Leer byte del destino
    cbz w2, copy_str         // Si encontramos el '\0', empezamos a copiar acá
    add x1, x1, #1
    b find_end
copy_str:
    ldrb w2, [x0], #1        // Leer byte del origen
    strb w2, [x1], #1        // Escribir byte en destino
    cbnz w2, copy_str        // Repetir hasta que el origen mande su '\0'
    ret

// ============================================================================
// SUBRUTINA LOCAL: append_number
// Convierte entero en x0 a ASCII usando utils.s y lo concatena al out_buf
// ============================================================================
append_number:
    stp x29, x30, [sp, #-16]!   // Guardar link register
    ldr x1, =num_buf            // Buffer temporal para itoa
    bl utils_itoa               // utils_itoa genera "numero\n\0"
    
    ldr x0, =num_buf            // Tomar el resultado de itoa
    bl append_string            // Enviarlo al concatenador general
    
    ldp x29, x30, [sp], #16     // Restaurar link register
    ret

    .include "utils.s"