.global _start

/*Guía de registros:
    x19: Inicio de datos en stack
    x20: Límite superior del stack de datos (x1 de utils, x28)
    x21: Cantidad de datos (x2 de utils, deberían de ser 30)
    x22: Dirección para restaurar sp (x3 de utils)
    x23: X_inicial (primer dato del CSV)
    x24: X_final (último dato del CSV)
    x25: DIF = X_final - X_inicial
    x6:  PROMEDIO_CAMBIO = DIF / 29
    x7:  PREDICCIÓN = X_final + PROMEDIO_CAMBIO
    x26: Puntero dinámico de escritura en buffer_salida
*/

.section .data
.align 3

archivo_salida:
    .asciz "resultado_prediccion.txt"

etq_module:  .asciz "MODULE=PREDICTION\n"
etq_initial: .asciz "INITIAL_VALUE="
etq_final:   .asciz "FINAL_VALUE="
etq_diff:    .asciz "TOTAL_DIFF="
etq_avg:     .asciz "AVG_CHANGE="
etq_next:    .asciz "NEXT_VALUE="
str_nl:      .asciz "\n"
str_neg:     .asciz "-"

.section .bss
.align 4

num_buffer:    .skip 32            //Buffer temporal para utils_itoa
buffer_salida: .skip 512           //Buffer del reporte completo

.section .text

_start:
    mov x27, sp                    //x27 = sp original (apunta a argc/argv)
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, [x27, #16]             //x0 = argv[1]
    ldrb w11, [x0]                 //primer carácter ASCII
    sub x11, x11, #48              //ASCII -> entero -> x11 = número de columna

    //LEER COLUMNA A STACK
    bl  utils_read_column_to_stack

    mov x19, x0                    //x19 = inicio datos (dirección más baja = X_final)
    mov x20, x1                    //x20 = límite (x28, dirección más alta)
    mov x21, x2                    //x21 = cantidad (30)
    mov x22, x3                    //x22 = sp a restaurar

    //OBTENER X_inicial Y X_final
    sub x0, x20, #16               //dirección de X_inicial
    ldr x23, [x0]                  //x23 = X_inicial

    ldr x24, [x19]                 //x24 = X_final

    //DIF = X_final - X_inicial
    sub x25, x24, x23                //x25 = TOTAL_DIFF

    //Restaurar sp, ya no se necesita el stack de datos
    mov sp, x22

    //PROMEDIO_CAMBIO = DIF / 29 (entero, con signo)
    mov x3, #29
    sdiv x6, x25, x3                 //x6 = PROMEDIO_CAMBIO

    //PREDICCIÓN= X_final + PROMEDIO_CAMBIO
    add x7, x24, x6                  //x7 = PREDICCIÓN

    //GENERAR Y ESCRIBIR REPORTE DE SALIDA
    bl  generar_reporte_salida

    mov x0, #0
    mov x8, #93
    svc #0


generar_reporte_salida:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x26, =buffer_salida

    //MODULE=PREDICTION
    mov x0, x26
    ldr x1, =etq_module
    bl  utilidad_concatenar_cadena
    mov x26, x0

    //INITIAL_VALUE=<x23>
    mov x0, x26
    ldr x1, =etq_initial
    bl  utilidad_concatenar_cadena
    mov x26, x0
    mov x9, x23
    bl  utilidad_escribir_entero
    mov x0, x26
    ldr x1, =str_nl
    bl  utilidad_concatenar_cadena
    mov x26, x0

    //FINAL_VALUE=<x24>
    mov x0, x26
    ldr x1, =etq_final
    bl  utilidad_concatenar_cadena
    mov x26, x0
    mov x9, x24
    bl  utilidad_escribir_entero
    mov x0, x26
    ldr x1, =str_nl
    bl  utilidad_concatenar_cadena
    mov x26, x0

    //TOTAL_DIFF=<x25>
    mov x0, x26
    ldr x1, =etq_diff
    bl  utilidad_concatenar_cadena
    mov x26, x0
    mov x9, x25
    bl  utilidad_escribir_entero
    mov x0, x26
    ldr x1, =str_nl
    bl  utilidad_concatenar_cadena
    mov x26, x0

    //AVG_CHANGE=<x6>
    mov x0, x26
    ldr x1, =etq_avg
    bl  utilidad_concatenar_cadena
    mov x26, x0
    mov x9, x6
    bl  utilidad_escribir_entero
    mov x0, x26
    ldr x1, =str_nl
    bl  utilidad_concatenar_cadena
    mov x26, x0

    //NEXT_VALUE=<x7>
    mov x0, x26
    ldr x1, =etq_next
    bl  utilidad_concatenar_cadena
    mov x26, x0
    mov x9, x7
    bl  utilidad_escribir_entero
    mov x0, x26
    ldr x1, =str_nl
    bl  utilidad_concatenar_cadena
    mov x26, x0

    //Calcular longitud y escribir archivo
    ldr x5, =buffer_salida
    sub x1, x26, x5                 //x1 = longitud total

    ldr x0, =buffer_salida
    ldr x2, =archivo_salida
    bl  utils_write_result

    ldp x29, x30, [sp], #16
    ret


utilidad_escribir_entero:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cmp x9, #0
    bge .ue_positivo

    mov x0, x26
    ldr x1, =str_neg
    bl  utilidad_concatenar_cadena
    mov x26, x0
    neg x9, x9

.ue_positivo:
    mov x0, x9
    ldr x1, =num_buffer
    bl  utils_itoa                   //num_buffer = "digitos\n\0"

    ldr x10, =num_buffer
.ue_copy:
    ldrb w12, [x10], #1
    cmp w12, #10                     //'\n' ?
    beq .ue_fin
    strb w12, [x26], #1
    b .ue_copy
.ue_fin:
    ldp x29, x30, [sp], #16
    ret


utilidad_concatenar_cadena:
.loop_copia_bytes:
    ldrb w2, [x1], #1
    cbz  w2, .fin_copia_bytes
    strb w2, [x0], #1
    b    .loop_copia_bytes
.fin_copia_bytes:
    ret

.include "utils.s"
