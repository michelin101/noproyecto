.global _start
.include "utils.s"

.data
.align 3

salida_calculo: .asciz "CALC=ERROR_INTEGRAL\n"
salida_columna: .asciz "COLUMN="
salida_inicio: .asciz "WINDOW_START="
salida_final: .asciz "WINDOW_END="
salida_contador: .asciz "COUNT="
salida_ideal: .asciz "IDEAL="
salida_integral: .asciz "ERROR_INTEGRAL="

error_error: .asciz "ERROR="
error_detalle: .asciz "DETAIL="

status_ok: .asciz "STATUS=OK\n"
status_error: .asciz "STATUS=ERROR\n"

argumentos_insuficientes: .asciz "INSUFFICIENT_ARGUMENTS\n"
datos_insuficientes: .asciz "INSUFFICIENT_DATA\n"
columna_invalida: .asciz "INVALID_COLUMN\n"
rango_invalido: .asciz "INVALID_RANGE\n"

detalle_args: .asciz "INVALID_ARGUMENT_COUNT\n"
detalle_datos: .asciz "ERROR_INTEGRAL_REQUIRES_AT_LEAST_2_VALUES\n"
detalle_columna: .asciz "INVALID_COLUMN_PROVIDED\n"
detalle_rango: .asciz "INVALID_RANGE_PROVIDED\n"

columna_dos: .asciz "TEMP\n"
columna_tres: .asciz "HUM_AIRE\n"
columna_cuatro: .asciz "SOIL1\n"
columna_cinco: .asciz "SOIL2\n"
columna_seis: .asciz "LUZ\n"
columna_siete: .asciz "GAS\n"

salto_linea: .asciz "\n"
simbolo_neg: .asciz "-"
archivo_salida: .asciz "resultado_integral.txt"

.bss
.align 4

num_buffer: .skip 32
buffer_resultado: .skip 512

.text
_start:
    //comprobar que se pasaron todos los argumentos necesarios
    ldr x0, [sp]                        //x0 = argc (debería ser 5)
    cmp x0, #5
    bne error_argumentos

    ldr x21, [sp, #16]                   //x1 = nombre_archivo_lectura

    ldr x0, [sp, #24]
    bl atoi_argv
    mov x24, x10                         //x24 = línea inicial a leer

    ldr x0, [sp, #32]
    bl atoi_argv
    mov x25, x10                         //x25 = línea final a leer

    ldr x0, [sp, #40]
    bl atoi_argv
    mov x11, x10                         //x11 = columna de sensor a leer
    
    cmp x11, #2
    beq .ideal_temp

    cmp x11, #3
    beq .ideal_hum
    
    cmp x11, #4
    beq .ideal_soil1
    
    cmp x11, #5
    beq .ideal_soil2

    cmp x11, #6
    beq .ideal_luz

    cmp x11, #7
    beq .ideal_gas
//asignar valor ideal constante
.ideal_temp:
    mov x6, #28
    b .ideal_fin
.ideal_hum:
    mov x6, #60
    b .ideal_fin
.ideal_soil1:
    mov x6, #45
    b .ideal_fin
.ideal_soil2:
    mov x6, #50
    b .ideal_fin
.ideal_luz:
    mov x6, #500
    b .ideal_fin
.ideal_gas:
    mov x6, #1200
.ideal_fin:
    //x6 = valor ideal
    bl utils_read_column_to_stack


    mov x19, x1                         //x19 = dirección de datos[0]
    mov x20, x2                         //x20 = cantidad de números guardados
    mov x22, x3                         //x22 = posición para restaurar el stack pointer
    mov x23, x6                         //x23 = IDEAL

    //Comprobando que todo OK
    cmp x4, #1
    beq error_columna
    cmp x4, #2
    beq error_rango

    //Comprondo que N>=2
    cmp x2, #2
    blt error_datos

    sub x19, x19, #16
    sub x21, x20, #1

    mov x4, #0                          //índice i inicializado en 0
    mov x5, #2                          //divisor de AREA_TRAPECIO
    mov x6, #0                          //AREA_ERROR, acumulador inicializado en 0

calculo_area_error:
    //array[i] = dirección_base + (i * tam_bytes)
    //array[i] = x19 + (x4 * 8)
    //ERROR_i = |Y_i - IDEAL|
    lsl x2, x4, #4
    sub x2, x19, x2
    ldr x0, [x2]        //x0 = Y_i
    sub x0, x0, x23
    bl valor_absoluto
    mov x1, x0          //x1 = ERROR_i

    //array[i+1] = dirección_base + ((i+1) * tam_bytes)
    //array[i] = x19 + ((x4 + 1) * 8)
    //ERROR_NEXT = |Y_(i+1) - IDEAL|
    add x2, x4, #1
    lsl x2, x2, #4
    sub x2, x19, x2
    ldr x0, [x2]        //x0 = Y_(i + 1)
    sub x0, x0, x23
    bl valor_absoluto   //x0 = ERROR_NEXT

    //AREA_TRAPECIO = (ERROR_i + ERROR_NEXT) / 2
    add x9, x1, x0      //ERROR_i + ERROR_NEXT
    udiv x9, x9, x5     //AREA_TRAPECIO = (ERROR_i + ERROR_NEXT) / 2

    //AREA_ERROR
    add x6, x6, x9      //AREA_ERROR = AREA_ERROR + AREA_TRAPECIO

    add x4, x4, #1
    cmp x4, x21
    blt calculo_area_error

fin_integral:
    mov sp, x22
    b escribir_resultado

escribir_resultado:
    ldr x27, [x22, #40]
    ldr x26, =buffer_resultado

    //CALC=ERROR_INTEGRAL\n
    mov x0, x26
    ldr x1, =salida_calculo
    bl utilidad_concatenar_cadena
    mov x26, x0

    
    //COLUMN=<x15>
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
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //WINDOW_START=<x24>
        //WINDOW_START=
    mov x0, x26
    ldr x1, =salida_inicio
    bl utilidad_concatenar_cadena
    mov x26, x0

        //<x24>
    mov x9, x24
    bl utilidad_escribir_entero
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //WINDOW_END=<x24>
        //WINDOW_END=
    mov x0, x26
    ldr x1, =salida_final
    bl utilidad_concatenar_cadena
    mov x26, x0

        //<x25>
    mov x9, x25
    bl utilidad_escribir_entero
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //COUNT=<x20>
        //COUNT=
    mov x0, x26
    ldr x1, =salida_contador
    bl utilidad_concatenar_cadena
    mov x26, x0

        //<x20>
    mov x9, x20
    bl utilidad_escribir_entero
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //IDEAL=<x23>
        //IDEAL=
    mov x0, x26
    ldr x1, =salida_ideal
    bl utilidad_concatenar_cadena
    mov x26, x0

        //<x23>
    mov x9, x23
    bl utilidad_escribir_entero
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //ERROR_INTEGRAL=<x6>
        //ERROR_INTEGRAL=
    mov x0, x26
    ldr x1, =salida_integral
    bl utilidad_concatenar_cadena
    mov x26, x0

        //<x6>
    mov x9, x6
    bl utilidad_escribir_entero
    mov x0, x26
    ldr x1, =salto_linea
    bl utilidad_concatenar_cadena
    mov x26, x0

    //STATUS=OK\n
    mov x0, x26
    ldr x1, =status_ok
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calcular longitud y escribir archivo
    ldr x5, =buffer_resultado
    sub x1, x26, x5             //x1 = longitud total

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result

    mov x0, #0
    mov x8, #93
    svc #0

//ESCRIBIR ERRORES
error_argumentos:
    ldr x26, =buffer_resultado

    //STATUS=ERROR\n
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0

    
    //ERROR=INSUFFICIENT_ARGUMENTS
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0

        //INSUFFICIENT_AGUMENTS
    mov x0, x26
    ldr x1, =argumentos_insuficientes
    bl utilidad_concatenar_cadena
    mov x26, x0


    //DETAIL=INVALID_ARGUMENT_COUNT
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0

    mov x0, x26
    ldr x1, =detalle_args
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calcular longitud y escribir archivo
    ldr x5, =buffer_resultado
    sub x1, x26, x5             //x1 = longitud total

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result

    mov x0, #0
    mov x8, #93
    svc #0

error_datos:
    ldr x26, =buffer_resultado

    //STATUS=ERROR\n
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0

    
    //ERROR=INSUFFICIENT_DATA
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0

        //INSUFFICIENT_DATA
    mov x0, x26
    ldr x1, =datos_insuficientes
    bl utilidad_concatenar_cadena
    mov x26, x0


    //DETAIL=ERROR_INTEGRAL_REQUIRES_AT_LEAST_2_VALUES\n
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0

    mov x0, x26
    ldr x1, =detalle_datos
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calcular longitud y escribir archivo
    ldr x5, =buffer_resultado
    sub x1, x26, x5             //x1 = longitud total

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result

    mov x0, #0
    mov x8, #93
    svc #0

error_columna:
    ldr x26, =buffer_resultado

    //STATUS=ERROR\n
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0

    
    //ERROR=INVALID_COLUMN
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0

        //INVALID_COLUMN
    mov x0, x26
    ldr x1, =columna_invalida
    bl utilidad_concatenar_cadena
    mov x26, x0


    //DETAIL=INVALID_COLUMN_PROVIDED\n
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0

    mov x0, x26
    ldr x1, =detalle_columna
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calcular longitud y escribir archivo
    ldr x5, =buffer_resultado
    sub x1, x26, x5             //x1 = longitud total

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result

    mov x0, #0
    mov x8, #93
    svc #0

error_rango:
    ldr x26, =buffer_resultado

    //STATUS=ERROR\n
    mov x0, x26
    ldr x1, =status_error
    bl utilidad_concatenar_cadena
    mov x26, x0

    
    //ERROR=INVALID_RANGE
        //ERROR=
    mov x0, x26
    ldr x1, =error_error
    bl utilidad_concatenar_cadena
    mov x26, x0

        //INVALID_RANGE
    mov x0, x26
    ldr x1, =rango_invalido
    bl utilidad_concatenar_cadena
    mov x26, x0


    //DETAIL=INVALID_RANGE_PROVIDED\n
    mov x0, x26
    ldr x1, =error_detalle
    bl utilidad_concatenar_cadena
    mov x26, x0

    mov x0, x26
    ldr x1, =detalle_rango
    bl utilidad_concatenar_cadena
    mov x26, x0

    //calcular longitud y escribir archivo
    ldr x5, =buffer_resultado
    sub x1, x26, x5             //x1 = longitud total

    ldr x0, =buffer_resultado
    ldr x2, =archivo_salida
    bl utils_write_result

    mov x0, #0
    mov x8, #93
    svc #0

//Utilidad de valor absoluto
valor_absoluto:
    cmp x0, #0
    bge num_positivo
    neg x0, x0

num_positivo:
    ret


//utilidades auxiliares para salida
utilidad_escribir_entero:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cmp x9, #0
    bge .ue_positivo

    mov x0, x26
    ldr x1, =simbolo_neg
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
