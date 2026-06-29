.global _start
.include "utils.s"

/* Guía de registros:
    x19: Inicio de datos en stack
    x20: Límite superior del stack de datos (x1 de utils)
    x21: Cantidad de datos (x2 de utils)
    x22: Dirección para restaurar sp (x3 de utils)
    x23: X_inicial (primer dato del CSV)
    x24: X_final (último dato del CSV)   ← Nota: se sobrescribe el valor original de línea final
    x25: DIF = X_final - X_inicial
    x27: Columna leída (sensor)
    x6:  PROMEDIO_CAMBIO = DIF / (N-1)
    x7:  PREDICCIÓN = X_final + PROMEDIO_CAMBIO
    x26: Puntero dinámico de escritura en buffer_resultado
*/

.section .data
.align 3

salida_calculo:     .asciz "CALC=PREDICTION\n"
salida_columna:     .asciz "COLUMN="
salida_inicio:      .asciz "WINDOW_START="
salida_final:       .asciz "WINDOW_END="
salida_contador:    .asciz "COUNT="
salida_next:        .asciz "NEXT_VALUE="

error_error:        .asciz "ERROR="
error_detalle:      .asciz "DETAIL="

status_ok:          .asciz "STATUS=OK\n"
status_error:       .asciz "STATUS=ERROR\n"

argumentos_insuficientes: .asciz "INSUFFICIENT_ARGUMENTS\n"
datos_insuficientes:      .asciz "INSUFFICIENT_DATA\n"
columna_invalida:         .asciz "INVALID_COLUMN\n"
rango_invalido:           .asciz "INVALID_RANGE\n"

detalle_args:    .asciz "INVALID_ARGUMENT_COUNT\n"
detalle_datos:   .asciz "PREDICTION_REQUIRES_AT_LEAST_2_VALUES\n"
detalle_columna: .asciz "INVALID_COLUMN_PROVIDED\n"
detalle_rango:   .asciz "INVALID_RANGE_PROVIDED\n"

salto_linea:     .asciz "\n"
simbolo_neg:     .asciz "-"

archivo_salida:  .asciz "resultado_prediccion.txt"

.section .bss
.align 4

num_buffer:    .skip 32            //Buffer temporal para utils_itoa
buffer_resultado: .skip 512           //Buffer del reporte completo


.section .text

_start:
    ldr x0, [sp]
    cmp x0, #5
    bne error_argumentos

    ldr x21, [sp, #16]              //x21 = nombre archivo de lectura
    
    ldr x0, [sp, #24]
    bl atoi_argv
    mov x24, x10                    //x24 = linea inicial a leer

    ldr x0, [sp, #32]
    bl atoi_argv
    mov x25, x10                    //x25 = linea final a leer

    ldr x0, [sp, #40]
    bl atoi_argv
    mov x11, x10                    //x11 = columna de sensor a leer
    //LEER COLUMNA A STACK
    bl utils_read_column_to_stack

    //comprobando que todo OK
    cmp x4, #1
    beq error_columna
    cmp x4, #2
    beq error_rango
    cmp x2, #2
    blt error_datos

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

    //PROMEDIO_CAMBIO = DIF / (N-1)
    sub x3, x21, #1
    sdiv x6, x25, x3                 //x6 = PROMEDIO_CAMBIO

    //PREDICCIÓN= X_final + PROMEDIO_CAMBIO
    add x7, x24, x6                  //x7 = PREDICCIÓN

    //GENERAR Y ESCRIBIR REPORTE DE SALIDA
    bl  escribir_resultado



escribir_resultado:
    ldr x27, [x22, #40]
    ldr x0, [x22, #24]
    bl atoi_argv
    mov x24, x10

    ldr x0, [x22, #32]
    bl atoi_argv
    mov x25, x10

    ldr x26, =buffer_resultado

    //CALC=PREDICTION\n
    mov x0, x26
    ldr x1, =salida_calculo
    bl utilidad_concatenar_cadena
    mov x26, x0

    //COLUMN=<x27>\n
        //COLUMN=
    mov x0, x26
    ldr x1, =salida_columna
    bl utilidad_concatenar_cadena
    mov x26, x0

        //<x27>
    mov x0, x26
    mov x1, x27
    bl utilidad_concatenar_cadena
    mov x26, x0
        //\n
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //WINDOW_START=<x24>
        //WINDOW_START=<x0>
    mov x0, x26
    ldr x1, =salida_inicio
    bl utilidad_concatenar_cadena
    mov x26, x0
        //<x24>
    mov x9, x24                 // línea inicial
    bl utilidad_escribir_entero
        //\n
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //WINDOW_END=<x25>
        //WINDOW_END=
    mov x0, x26
    ldr x1, =salida_final
    bl utilidad_concatenar_cadena
    mov x26, x0
        //<x25>
    mov x9, x25                 // línea final original (antes de sobrescribir)
    bl utilidad_escribir_entero
        //\n
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //COUNT=<x21>
        //COUNT=
    mov x0, x26
    ldr x1, =salida_contador
    bl utilidad_concatenar_cadena
    mov x26, x0
        //<x21>
    mov x9, x21
    bl utilidad_escribir_entero
        //\n
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //NEXT_VALUE=<x7>
        //NEXT_VALUE=
    mov x0, x26
    ldr x1, =salida_next
    bl utilidad_concatenar_cadena
    mov x26, x0
        //<x7>
    mov x9, x7
    bl utilidad_escribir_entero
        //\n
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //STATUS=OK
    mov x0, x26
    ldr x1, =status_ok
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calculo de longitud y escribir archivo de salida
    ldr x5, =buffer_resultado
    sub x1, x26, x5

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result

    mov x0, #0
    mov x8, #93
    svc #0


//generación de errores
error_argumentos:
    ldr x26, =buffer_resultado
    
    //STATUS=ERROR
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0
    
    //ERROR=INSUFFICIENT_ARGUMENTS\n
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0
        //INSUFFICIENT_ARGUMENTS\n
    mov x0, x26
    ldr x1, =argumentos_insuficientes
    bl utilidad_concatenar_cadena
    mov x26, x0

    //DETAIL=INVALID_ARGUMENT_COUNT\n
        //DETAIL=
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0
        //INVALID_ARGUMENT_COUNT\n
    mov x0, x26
    ldr x1, =detalle_args
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calculo de longitud y escribir archivo de salida
    ldr x5, =buffer_resultado
    sub x1, x26, x5

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result
    b exit_error


error_datos:
    ldr x26, =buffer_resultado
    
    //STATUS=ERROR\n
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0
    
    //ERROR=INSUFFICIENT_DATA\n
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0
        //INSUFFICIENT_DATA\n
    mov x0, x26
    ldr x1, =datos_insuficientes
    bl utilidad_concatenar_cadena
    mov x26, x0

    //DETAIL=PREDICTION_REQUIRES_AT_LEAST_2_VALUES\n
        //DETAIL=
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0
        //PREDICTION_REQUIRES_AT_LEAST_2_VALUES\n
    mov x0, x26
    ldr x1, =detalle_datos
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calculo de longitud y escribir archivo de salida
    ldr x5, =buffer_resultado
    sub x1, x26, x5

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result
    b exit_error


error_columna:
    ldr x26, =buffer_resultado
    
    //STATUS=ERROR\n
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0

    //ERROR=INVALID_COLUMN\n
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0
        //INVALID_COLUMN\n
    mov x0, x26
    ldr x1, =columna_invalida
    bl utilidad_concatenar_cadena
    mov x26, x0

    //DETAIL=INVALID_COLUMN_PROVIDED\n
        //DETAIL=
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0
        //INVALID_COLUMN_PROVIDED\n
    mov x0, x26
    ldr x1, =detalle_columna
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calculo de longitud y escribir archivo de salida
    ldr x5, =buffer_resultado
    sub x1, x26, x5

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result
    b exit_error


error_rango:
    ldr x26, =buffer_resultado

    //STATUS=ERROR\n
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0

    //ERROR=INVALID_RANGE\n
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0
        //INVALID_RANGE\n
    mov x0, x26
    ldr x1, =rango_invalido
    bl utilidad_concatenar_cadena
    mov x26, x0

    //DETAIL=INVALID_RANGE_PROVIDED\n
        //DETAIL=
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0
        //INVALID_RANGE_PROVIDED\n
    mov x0, x26
    ldr x1, =detalle_rango
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calculo de longitud y escribir archivo de salida
    ldr x5, =buffer_resultado
    sub x1, x26, x5

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result


exit_error:
    mov x0, #0
    mov x8, #93
    svc #0

//utilidades
utilidad_escribir_entero:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cmp x9, #0
    bge .ue_positivo

    mov x0, x26
    ldr x1, =simbolo_neg
    bl utilidad_concatenar_cadena
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
    cbz w2, .fin_copia_bytes
    strb w2, [x0], #1
    b .loop_copia_bytes
.fin_copia_bytes:
    ret
