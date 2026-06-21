.global _start


// ==========================================
// DATOS: etiquetas de texto y nombre de salida
// ==========================================
.data
str_modulo:     .asciz "MODULE=VARIANCE\n"
str_total:      .asciz "TOTAL_VALUES="
str_med:        .asciz "MEAN="
str_varianza:   .asciz "VARIANCE="
str_dsvs:       .asciz "STD_DEV="
out_filename:   .asciz "resultado_varianza.txt"

.bss
buffer_var:
    .skip 256

// ==========================================
// PROGRAMA PRINCIPAL
// ==========================================
.text
_start:
    mov x19, sp                  // x19 = sp original (apunta a argc/argv)

    // 1. Leer la columna desde argv[1]
    ldr x0, [x19, #16]           // x0 = argv[1] (cadena con el numero de columna)
    ldrb w11, [x0]               // primer caracter ASCII
    sub x11, x11, #48            // ASCII -> entero -> columna en x11

    // 2. Leer la columna del CSV al stack
    bl utils_read_column_to_stack
    mov x20, x0                  // x20 = inicio de los datos
    mov x21, x2                  // x21 = cantidad (30)
    mov x25, x3                  // x25 = posicion para restaurar el stack

    // 3. Calculos
    bl med
    bl var
    bl dsvs

    // 4. Escribir resultados con formato
    bl guardar_txt

    // 5. Restaurar stack y salir
    mov sp, x25
    mov x0, #0
    mov x8, #93
    svc #0

// ----------------------------------------------------
// CALCULOS (sin cambios respecto a tu version)
// ----------------------------------------------------
med:
    mov x10, #0
    mov x4, x20
    mov x5, x21
    mov x6, x5

med_suma_loop:
    ldr x1, [x4], #16
    add x10, x10, x1
    sub x5, x5, #1
    cmp x5, #0
    bgt med_suma_loop
    udiv x22, x10, x6
    ret

var:
    mov x10, #0
    mov x4, x20
    mov x5, x21
    mov x6, x5
    
var_suma_loop:
    ldr x1, [x4], #16
    sub x1, x1, x22
    mul x1, x1, x1
    add x10, x10, x1
    sub x5, x5, #1
    cmp x5, #0
    bgt var_suma_loop
    udiv x23, x10, x6
    ret

dsvs:
    mov x10, x23
    mov x4, x10
    mov x5, x10
dsvs_loop:
    sdiv x1, x4, x5
    add  x2, x5, x1
    mov  x6, #2
    sdiv x3, x2, x6
    cmp  x3, x5
    bhs dsvs_done
    mov x5, x3
    b dsvs_loop
dsvs_done:
    mov x24, x3
    ret

// ----------------------------------------------------
// GUARDAR RESULTADOS CON FORMATO ETIQUETADO
// ----------------------------------------------------
guardar_txt:
    stp x29, x30, [sp, #-16]!

    ldr x1, =buffer_var              // x1 = posicion de escritura

    ldr x3, =str_modulo          // "MODULE=VARIANCE\n"
    bl copiar_str

    ldr x3, =str_total           // "TOTAL_VALUES="
    bl copiar_str
    mov x0, x21                  // cantidad de valores
    bl escribir_num              // anade el numero + \n

    ldr x3, =str_med            // "MEAN="
    bl copiar_str
    mov x0, x22                  // media
    bl escribir_num

    ldr x3, =str_varianza        // "VARIANCE="
    bl copiar_str
    mov x0, x23                  // varianza
    bl escribir_num

    ldr x3, =str_dsvs          // "STD_DEV="
    bl copiar_str
    mov x0, x24                  // desviacion estandar
    bl escribir_num

    ldr x0, =buffer_var              // inicio del buffer
    sub x1, x1, x0               // longitud = posicion actual - inicio
    ldr x2, =out_filename
    bl utils_write_result

    ldp x29, x30, [sp], #16
    ret

// ----------------------------------------------------
// COPIAR CADENA (asciz) AL BUFFER
// Entrada: x3 = cadena fuente (termina en \0), x1 = destino
// Salida:  x1 queda despues del ultimo caracter copiado
// ----------------------------------------------------
copiar_str:
copiar_loop:
    ldrb w4, [x3], #1            // lee un byte de la fuente y avanza
    cbz w4, copiar_fin           // si es \0, termina (no lo copia)
    strb w4, [x1], #1            // escribe el byte en el buffer y avanza
    b copiar_loop
copiar_fin:
    ret

// ----------------------------------------------------
// ESCRIBIR NUMERO (igual que antes)
// ----------------------------------------------------
escribir_num:
    stp x29, x30, [sp, #-16]!
    bl utils_itoa
avanzar:
    ldrb w2, [x1], #1
    cbnz w2, avanzar
    sub x1, x1, #1
    ldp x29, x30, [sp], #16
    ret


.include "utils.s"
