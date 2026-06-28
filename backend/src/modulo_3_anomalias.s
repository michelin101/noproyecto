// Modulo 3: Deteccion de Anomalias (Z-score)

.global _start

.section .data
.align 3
    archivo_salida: .asciz "resultado_anomalias.txt"

    // Etiquetas de reporte
    etq_module:   .asciz "MODULE=ANOMALY_DETECTION\n"
    etq_column:     .asciz "COLUMN="                  // columna analizada
    etq_win_start:  .asciz "WINDOW_START="            // linea inicial del rango
    etq_win_end:    .asciz "WINDOW_END="              // linea final del rango
    etq_count:      .asciz "COUNT="                   // cantidad de datos procesados
    etq_mean:     .asciz "MEAN="
    etq_std:      .asciz "STD_DEV="
    etq_anom:     .asciz "ANOMALIES="
    etq_risk:     .asciz "SYSTEM_RISK="
    etq_normal:   .asciz "NORMAL\n"
    etq_medium:   .asciz "MEDIUM\n"
    etq_high:     .asciz "HIGH\n"

    // etiquetas de error 
    etq_err_columna: .asciz "MODULE=ANOMALY_DETECTION\nSTATUS=ERROR\nERROR=INVALID_COLUMN\n"
    etq_err_rango:   .asciz "MODULE=ANOMALY_DETECTION\nSTATUS=ERROR\nERROR=INVALID_RANGE\n"

.section .bss
.align 4
    num_buffer:     .skip 32        // Buffer temporal para itoa
    buffer_salida:  .skip 512       // Buffer masivo para el .txt

.section .text

_start:
    // ========================================================================
    // 1. OBTENER COLUMNA DESDE ARGV[1]
    // ========================================================================
    ldr x0, [sp]                    // Cargar argc
    cmp x0, #5                      // se necesitan 4 argumentos + el nombre del programa
    blt salir_con_error             // Abortar si no hay suficientes argumentos

    ldr x2, [sp, #16]                // puntero a argv[1], archivo de entrada
    mov x21, x2                      // se copia el puntero del archivo en x21

    ldr x0, [sp, #24]                 // puntero a argv[2], linea inicial
    bl atoi_argv                      // convertir a entero
    mov x24, x10                      // x24 = linea inicial del rango que se procesa

    ldr x0, [sp, #32]                 // puntero a argv[3], linea final
    bl atoi_argv                      // convertir a entero
    mov x25, x10                      // x25 = linea final del rango que se procesa

    ldr x0, [sp, #40]                 // puntero a argv[4], columna que se analiza
    bl atoi_argv                      // convertir el string a entero
    mov x11, x10                      // x11 = numero de columna

    bl utils_read_column_to_stack

    cmp x4, #1                        // se verifica si la columna fue invalida
    beq error_columna
    cmp x4, #2                        // se verifica si el rango fue invalido
    beq error_rango

    mov x19, x0                     // x19 = Inicio de datos
    mov x20, x1                     // x20 = Fin de datos
    mov x21, x2                     // x21 = cantidad de datos
    mov x22, x3                     // x22 = SP original para restaurar

    mov x26, x24                    // x26 = linea inicial
    mov x28, x25                    // x28 = linea final

    // ========================================================================
    // 2. CÁLCULO DE MEDIA ARITMÉTICA (Resultado en x23)
    // ========================================================================
    mov x4, x19
    mov x5, #0                      // Acumulador
loop_media:
    cmp x4, x20
    bge fin_media
    ldr x7, [x4]
    add x5, x5, x7
    add x4, x4, #16
    b loop_media
fin_media:
    sdiv x23, x5, x21               // x23 = MEAN

    // ========================================================================
    // 3. CÁLCULO DE VARIANZA Y DESVIACIÓN ESTÁNDAR (Resultado en x24)
    // ========================================================================
    mov x4, x19
    mov x5, #0                      // Acumulador de cuadrados
loop_varianza:
    cmp x4, x20
    bge fin_varianza
    ldr x7, [x4]
    sub x7, x7, x23                 // x7 = dato - media
    mul x7, x7, x7                  // x7 = (dato - media)^2
    add x5, x5, x7
    add x4, x4, #16
    b loop_varianza
fin_varianza:
    sdiv x5, x5, x21                // x5 = Varianza
    
    // Algoritmo de Newton para Raíz Cuadrada (std_dev)
    mov x0, x5
    cbz x0, raiz_cero
    mov x1, x0                      // x1 = estimacion inicial
loop_newton:
    sdiv x2, x0, x1
    add  x2, x1, x2
    lsr  x2, x2, #1                 // x2 / 2
    cmp x2, x1
    bge raiz_lista
    mov x1, x2
    b loop_newton
raiz_lista:
    mov x0, x1
raiz_cero:
    mov x24, x0                     // x24 = STD_DEV

    // ========================================================================
    // 4. DETECCIÓN DE ANOMALÍAS (Z-Score >= 2) (Resultado en x25)
    // ========================================================================
    mov x4, x19
    mov x25, #0                     // Contador de anomalias
    cbz x24, fin_anomalias          // Evitar division por 0
loop_anomalias:
    cmp x4, x20
    bge fin_anomalias
    ldr x7, [x4]
    sub x1, x7, x23                 // x1 = dato - media
    cmp x1, #0
    bge es_positivo
    neg x1, x1                      // Valor absoluto
es_positivo:
    sdiv x2, x1, x24                // z-score = abs / std_dev
    cmp x2, #2
    blt dato_normal
    add x25, x25, #1                // Anomalia detectada ++
dato_normal:
    add x4, x4, #16
    b loop_anomalias
fin_anomalias:

    // ========================================================================
    // 5. CONSTRUCCIÓN DEL REPORTE (Usando abstracción de strings)
    // ========================================================================
    ldr x1, =buffer_salida
    strb wzr, [x1]                  // Limpiar buffer colocando '\0' inicial

    ldr x0, =etq_module
    bl append_string

    ldr x0, =etq_column
    bl append_string
    mov x0, x11
    bl append_number

    ldr x0, =etq_win_start
    bl append_string
    mov x0, x26                     
    bl append_number

    ldr x0, =etq_win_end
    bl append_string
    mov x0, x28                     
    bl append_number

    ldr x0, =etq_count
    bl append_string
    mov x0, x21
    bl append_number
    
    ldr x0, =etq_mean
    bl append_string
    mov x0, x23
    bl append_number                // Convierte y pega la media

    ldr x0, =etq_std
    bl append_string
    mov x0, x24
    bl append_number                // Convierte y pega la desviacion

    ldr x0, =etq_anom
    bl append_string
    mov x0, x25
    bl append_number                // Convierte y pega el conteo

    ldr x0, =etq_risk
    bl append_string

    // Evaluacion del nivel de riesgo
    cmp x25, #0
    beq riesgo_normal
    cmp x25, #4
    blt riesgo_medium
riesgo_high:
    ldr x0, =etq_high
    b write_riesgo
riesgo_normal:
    ldr x0, =etq_normal
    b write_riesgo
riesgo_medium:
    ldr x0, =etq_medium
write_riesgo:
    bl append_string

    // ========================================================================
    // 6. ESCRITURA FÍSICA AL ARCHIVO .TXT
    // ========================================================================
escribir_archivo:
    ldr x0, =buffer_salida
    mov x1, #0
len_loop:                           // Calcular tamaño dinámico del texto
    ldrb w2, [x0, x1]
    cbz w2, exec_write
    add x1, x1, #1
    b len_loop
    
exec_write:
    ldr x2, =archivo_salida
    bl utils_write_result

    // ========================================================================
    // 7. RESTAURACIÓN Y SALIDA
    // ========================================================================
    mov sp, x22                     // Restaurar el stack a como estaba
    mov x0, #0
    mov x8, #93
    svc #0

salir_con_error:
    mov x0, #1
    mov x8, #93
    svc #0

// MANEJO DE ERRORES DE VALIDACIO
// Construye un reporte de eror y lo escribe en el archivo
error_columna:
    ldr x1, =buffer_salida           // direccion del inicio del buffer de salida
    strb wzr, [x1]                   // se vacia el buffer
    ldr x0, =etq_err_columna         // mensaje de error por columna invalida
    bl append_string                 // se agrega al buffer
    b escribir_archivo               // saltar directo a escribir el archivo

error_rango:
    ldr x1, =buffer_salida           // direccion del inicio del buffer de salida
    strb wzr, [x1]                   // se vacia el buffer
    ldr x0, =etq_err_rango           // mensaje de error por rango invalido
    bl append_string                 // se agrega al buffer
    b escribir_archivo               // saltar directo a escribir el archivo

// ============================================================================
// SUBRUTINAS ABSTRAÍDAS PARA MANEJO DE STRINGS
// ============================================================================

// Busca el final de buffer_salida y concatena la cqdena apuntada por x0
append_string:
    ldr x1, =buffer_salida
find_end:
    ldrb w2, [x1]
    cbz w2, copy_str
    add x1, x1, #1
    b find_end
copy_str:
    ldrb w2, [x0], #1
    strb w2, [x1], #1
    cbnz w2, copy_str
    ret

// Convierte el numero en x0 a texto y lo pega al final del buffer_salida
append_number:
    stp x29, x30, [sp, #-16]!
    ldr x1, =num_buffer
    bl utils_itoa                   // Genera texto numerico en num_buffer
    ldr x0, =num_buffer
    bl append_string                // Lo envia al buffer masivo
    ldp x29, x30, [sp], #16
    ret

.include "utils.s"