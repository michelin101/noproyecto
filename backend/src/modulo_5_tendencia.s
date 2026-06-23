/*
    ===========================================================================
    Módulo 5: Tendencia Acumulada Avanzada
    Proyecto: Invernadero Inteligente IoT (Raspberry Pi ARM64)
    ===========================================================================
    Responsable: Integrante 5
    Descripción: Lee una columna de lecturas.csv, calcula incrementos,
                 decrementos, rachas máximas, diferencia acumulada y la
                 tendencia general.
    ===========================================================================
*/

.data
    // Cadenas de texto fijas para el formato de salida
    str_mod:  .asciz "MODULE=ADVANCED_TREND\n"
    str_tot:  .asciz "TOTAL_VALUES="
    str_inc:  .asciz "INCREMENTS="
    str_dec:  .asciz "DECREMENTS="
    str_mxu:  .asciz "MAX_UP_STREAK="
    str_mxd:  .asciz "MAX_DOWN_STREAK="
    str_acc:  .asciz "ACCUM_DIFF="
    str_tr:   .asciz "TREND="
    str_up:   .asciz "UP\n"
    str_dw:   .asciz "DOWN\n"
    str_st:   .asciz "STABLE\n"
    str_neg:  .asciz "-"
    
    // Archivo de salida requerido
    file_out: .asciz "resultado_tendencia.txt"

.bss
    // Buffer masivo para ensamblar el texto final antes de escribir al archivo
    out_buf:  .skip 2048

.text
.global _start

_start:
    // ========================================================================
    // 1. OBTENER COLUMNA DESDE LOS ARGUMENTOS DEL SISTEMA (argv[1])
    // ========================================================================
    ldr x0, [sp]            // Cargar argc (Cantidad de argumentos)
    cmp x0, #2
    blt exit_err            // Si argc < 2, no se pasó columna, abortar

    ldr x0, [sp, #16]       // Cargar puntero al string de argv[1]
    mov x11, #0             // x11 almacenará el número de columna parseado
    mov x1, #10             // Multiplicador base 10
parse_col:
    ldrb w2, [x0], #1       // Leer 1 byte de argv[1] y avanzar
    cbz w2, col_parsed      // Si es nulo ('\0'), terminamos de leer
    sub w2, w2, '0'         // Convertir ASCII a valor numérico
    mul x11, x11, x1        // x11 = x11 * 10
    add x11, x11, x2        // x11 = x11 + digito
    b parse_col

col_parsed:
    // ========================================================================
    // 2. EXTRAER DATOS CON UTILS.S
    // ========================================================================
    // x11 ya contiene la columna. Llamamos a la rutina común.
    bl utils_read_column_to_stack
    // Retornos: x0 = Top del stack (X_30), x1 = Fondo del stack original

    // ========================================================================
    // 3. INICIALIZAR REGISTROS DE LÓGICA
    // ========================================================================
    mov x19, #0             // Contador total de INCREMENTS
    mov x20, #0             // Contador total de DECREMENTS
    mov x21, #0             // Racha actual de crecimiento (Current Up)
    mov x22, #0             // Racha MÁXIMA de crecimiento (Max Up Streak)
    mov x23, #0             // Racha actual de decremento (Current Down)
    mov x24, #0             // Racha MÁXIMA de decremento (Max Down Streak)

    // El primer dato guardado está en el fondo del stack. Nos ubicamos ahí.
    sub x4, x1, #16         // x4 = Puntero al PRIMER dato cronológico (X_1)
    
    ldr x26, [x4]           // Resguardar X_1 absoluto en x26 para la formula ACCUM_DIFF
    mov x25, x26            // Inicializar "Dato Anterior" (Prev) = X_1
    
    sub x4, x4, #16         // Avanzar el puntero hacia arriba del stack (X_2)

    // ========================================================================
    // 4. CICLO DE ANÁLISIS DE TENDENCIA
    // ========================================================================
loop_data:
    cmp x4, x0              // Comprobar si ya cruzamos el top del stack
    blt end_loop            // Si es menor, ya leímos los 30 datos

    ldr x5, [x4]            // Cargar Dato Actual (X_i)

    cmp x5, x25             // Comparar Dato Actual (X_i) con Dato Anterior (X_i-1)
    bgt is_greater          // Si es mayor, saltar a lógica de incremento
    blt is_less             // Si es menor, saltar a lógica de decremento

is_equal:
    // Si son iguales, se rompen ambas rachas actuales
    mov x21, #0             
    mov x23, #0             
    b next_iter

is_greater:
    add x19, x19, #1        // INCREMENTS++
    add x21, x21, #1        // Racha actual de subida++
    mov x23, #0             // Romper racha de bajada
    
    cmp x21, x22            // ¿Racha actual supera a la racha máxima registrada?
    ble next_iter           
    mov x22, x21            // MAX_UP_STREAK = racha actual
    b next_iter

is_less:
    add x20, x20, #1        // DECREMENTS++
    add x23, x23, #1        // Racha actual de bajada++
    mov x21, #0             // Romper racha de subida
    
    cmp x23, x24            // ¿Racha actual supera a la racha máxima registrada?
    ble next_iter
    mov x24, x23            // MAX_DOWN_STREAK = racha actual

next_iter:
    mov x25, x5             // El dato actual se convierte en el "Anterior"
    sub x4, x4, #16         // Mover puntero 16 bytes arriba (Siguiente dato cronológico)
    b loop_data

end_loop:
    // Al salir, x25 contiene el último dato procesado (X_30)
    // OPTIMIZACIÓN MATEMÁTICA: Suma Telescópica -> Sigma(X_i - X_i-1) = X_30 - X_1
    sub x27, x25, x26       // x27 = ACCUM_DIFF

    // ========================================================================
    // 5. CONSTRUCCIÓN DEL BUFFER DE TEXTO DE SALIDA
    // ========================================================================
    ldr x1, =out_buf
    strb wzr, [x1]          // Colocar byte nulo inicial por seguridad

    ldr x0, =str_mod        // "MODULE=ADVANCED_TREND"
    bl append_string

    ldr x0, =str_tot        // "TOTAL_VALUES="
    bl append_string
    mov x0, #30             // Hardcodeado a 30 por restricción del enunciado
    bl append_number

    ldr x0, =str_inc        // "INCREMENTS="
    bl append_string
    mov x0, x19
    bl append_number

    ldr x0, =str_dec        // "DECREMENTS="
    bl append_string
    mov x0, x20
    bl append_number

    ldr x0, =str_mxu        // "MAX_UP_STREAK="
    bl append_string
    mov x0, x22
    bl append_number

    ldr x0, =str_mxd        // "MAX_DOWN_STREAK="
    bl append_string
    mov x0, x24
    bl append_number

    ldr x0, =str_acc        // "ACCUM_DIFF="
    bl append_string

    // Verificar si ACCUM_DIFF es negativo para colocar el guión manualmente
    mov x0, x27
    cmp x27, #0
    bge diff_positive       // Si es >= 0, imprimir numero normal
    
    // Lógica para números negativos
    ldr x0, =str_neg        
    bl append_string        // Añadir "-"
    neg x0, x27             // Volver el número positivo temporalmente para itoa
diff_positive:
    bl append_number        // Añadir el número al buffer

    ldr x0, =str_tr         // "TREND="
    bl append_string

    // Evaluar estado final de la tendencia
    cmp x27, #0
    bgt trend_up
    blt trend_down

trend_stable:
    ldr x0, =str_st         // "STABLE"
    bl append_string
    b write_file

trend_up:
    ldr x0, =str_up         // "UP"
    bl append_string
    b write_file

trend_down:
    ldr x0, =str_dw         // "DOWN"
    bl append_string

    // ========================================================================
    // 6. ESCRITURA FÍSICA AL ARCHIVO .TXT
    // ========================================================================
write_file:
    // Calcular longitud exacta del buffer dinámico creado
    ldr x0, =out_buf
    mov x1, #0
len_loop:
    ldrb w2, [x0, x1]       // Leer byte
    cbz w2, exec_write      // Si es nulo, terminamos de contar
    add x1, x1, #1          // Longitud++
    b len_loop
    
exec_write:
    // x0 ya tiene la direccion del buffer de texto
    // x1 ya tiene la longitud calculada
    ldr x2, =file_out       // x2 recibe el nombre del archivo final
    bl utils_write_result   // Llamada al syscall 64 de utilidades

    // ========================================================================
    // 7. RESTAURACIÓN Y SALIDA
    // ========================================================================
    mov sp, x3              // Restaurar el stack a como estaba antes de leer CSV

exit_err:
    mov x0, #0
    mov x8, #93             // Syscall: exit
    svc #0


// ============================================================================
// SUBRUTINA LOCAL: append_string
// Busca el final de out_buf y concatena la cadena apuntada por x0
// ============================================================================
append_string:
    ldr x1, =out_buf
find_end:
    ldrb w2, [x1]           // Leer byte del destino
    cbz w2, copy_str        // Si encontramos el '\0', empezamos a copiar acá
    add x1, x1, #1
    b find_end
copy_str:
    ldrb w2, [x0], #1       // Leer byte del origen
    strb w2, [x1], #1       // Escribir byte en destino
    cbnz w2, copy_str       // Repetir hasta que el origen mande su '\0'
    ret

// ============================================================================
// SUBRUTINA LOCAL: append_number
// Convierte entero en x0 a ASCII usando utils.s y lo concatena al out_buf
// ============================================================================
append_number:
    stp x29, x30, [sp, #-16]!   // Guardar link register
    ldr x1, =write_buffer       // Buffer temporal para itoa
    bl utils_itoa               // utils_itoa genera "numero\n\0"
    
    ldr x0, =write_buffer       // Tomar el resultado de itoa
    bl append_string            // Enviarlo al concatenador general
    
    ldp x29, x30, [sp], #16     // Restaurar link register
    ret

// ============================================================================
// INCLUSIÓN DE LA LIBRERÍA COMÚN DEL EQUIPO
// ============================================================================
.include "utils.s"