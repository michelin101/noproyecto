/*
    ===========================================================================
    Módulo: MODULO 1
    Rutina: RMSE 
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
//nombre del archivo de salida
file_out:    .asciz "resultado_rmse.txt"

//aqui definimos los strings que se van a concatenar en la salida estructurada, por ahora solo estamos probando el MSE, asi que solo mostraremos eso.
str_mse:    .asciz "MSE="
str_ok:      .asciz "STATUS=OK\n"


// Salidas de error estructuradas
err_args:
    .ascii "STATUS=ERROR\nERROR=INVALID_INPUT\nDETAIL=EXPECTED_3_ARGS\n"
    len_err_args = . - err_args

err_col:
    .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_NOT_SUPPORTED\n"
    len_err_col = . - err_col

err_insuff:
    .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=RMSE_REQUIRES_AT_LEAST_2_VALUES\n"
    len_err_insuff = . - err_insuff

.bss
out_buf: .skip 1024          // Buffer donde se va armando el texto de salida
num_buf: .skip 32            // Buffer local para conversiones itoa 

.text
.global _start

_start:
    mov x9, sp               // x9 = referencia fija al inicio del stack de args
    ldr x0, [x9]              // x0 = argc
    cmp x0, #5                 // se necesitan: prog, archivo, inicio, fin, columna
    blt arg_error               //si no hay suficientes argumentos, error

    ldr x21, [x9, #16]         // argv[1] = puntero a archivo_entrada, este argumento lo requiere utils en x21

    // parseo de la linea inicial
    ldr x0, [x9, #24]
    bl atoi_argv               // llama a util para convertir el string a entero
    mov x24, x10               // x24 = linea_inicial (atoi_argv retorna en x10)

    // parseo de la linea final
    ldr x0, [x9, #32]
    bl atoi_argv
    mov x25, x10               // x25 = linea_final, utils lo requiere en x25

    // parseo del numero de columna del sensor
    ldr x0, [x9, #40]
    bl atoi_argv
    mov x11, x10               // x11 = numero de columna , utils lo requiere en x11


    // Recibe: x21=puntero a archivo, x24=linea_inicial, x25=linea_final, x11=columna_sensor
    bl utils_read_column_to_stack
    // Retorna: x0=tope(reciente) x1=limite(viejo) x2=cantidad x3=restore_sp x4=status

    cmp x4, #1                  // 1 = la columna no existe en el encabezado del CSV
    beq col_error

    cmp x2, #2                  // RMSE requiere al menos 2 datos
    blt insuff_error

    mov x19, x0                 // x19 = dato mas reciente (direccion mas baja)
    mov x20, x1                 // x20 = limite superior (dato mas viejo + 16)
    mov x22, x2                 // x22 = cantidad de datos (N)
    mov x23, x3                 // x23 = direccion para restaurar el stack al final

    // ----------------------------------------------------------------------
    // AQUI REDIRIGIMOS SEGUN LA COLUMNA SOLICITADA PARA ASIGNAR EL VALOR IDEAL RESPECTIVO
    // ----------------------------------------------------------------------
    cmp x11, #2
    beq ideal_temp               // TEMP
    cmp x11, #3
    beq ideal_hum                // HUM_AIRE
    cmp x11, #4
    beq ideal_s1                 // HUM_SUELO_1
    cmp x11, #5
    beq ideal_s2                 // HUM_SUELO_2
    cmp x11, #6
    beq ideal_luz                // LUZ
    cmp x11, #7
    beq ideal_gas                // GAS
    b col_error                  // ID, RIEGO_1, RIEGO_2 u otra columna no soportada, error de columna no soportada

    // ----------------------------------------------------------------------
    // AQUI ASIGNAMOS EL VALOR IDEAL SEGUN LA COLUMNA SOLICITADA (x11) EN x21
    // ----------------------------------------------------------------------
ideal_temp:
    mov x21, #28                 // Temperatura ideal de invernadero
    b ideal_done
ideal_hum:
    mov x21, #60                 // Humedad ambiental ideal
    b ideal_done
ideal_s1:
    mov x21, #45                 // Humedad de suelo ideal (area 1)
    b ideal_done
ideal_s2:
    mov x21, #50                 // Humedad de suelo ideal (area 2)
    b ideal_done
ideal_luz:
    mov x21, #500                // Nivel de luz ideal
    b ideal_done
ideal_gas:
    mov x21, #1100                // Nivel de gas base, seguro
ideal_done:

    // ----------------------------------------------------------------------
    // Calculo: ERROR_i = Y_i - IDEAL , ERROR2_i = ERROR_i^2 , MSE = suma/N, RMSE = sqrt(MSE)
    // ----------------------------------------------------------------------

    mov x6, #0                   // x6 = acumulador de ERROR2_i (suma)
    mov x7, x20                  // x7 = esto va a apuntar a Y_i cuando iteremos
    
sum_loop:
    sub x7, x7, #16               // bajar al siguiente dato guardado (apuntamos al Y_i)
    cmp x7, x19     
    blt sum_done                  // ¿ya recorrimos todos los N datos ? entonces nos vamos a sum_done, si no iteramos otra vez más
    ldr x8, [x7]                  // x8 = Y_i
    sub x9, x8, x21                // x9 = ERROR_i = Y_i - IDEAL
    mul x9, x9, x9                 // x9 = ERROR2_i (esto de aqui siempre nos quedara positivo)
    add x6, x6, x9                 // acumular
    b sum_loop
sum_done: // terminamos de iterar, ahora vamos a hacer los calculos finales para obtener el MSE y luego el RMSE
    udiv x10, x6, x22              // MSE = suma(ERROR2_i) / N 
    mov x26, x10                    // x26 = MSE final  NOTA: por ahora no hemos implementado la raiz cuadrado asi que por ahora solo mostraremos el MSE, no el RMSE
    
    //aqui haremos la raiz cuadrada del valor en x10 

    mov sp, x23                    // restaurar el stack al estado previo a la lectura

    // ----------------------------------------------------------------------
    // Empezamos a escribir todo en el buffer de salida out_buf, para luego escribirlo a disco
    // ----------------------------------------------------------------------

    ldr x1, =out_buf
    strb wzr, [x1]                 // asegurar que el buffer empiece vacio

    ldr x0, =str_mse
    bl append_string
    mov x0, x26                   
    bl append_number

    ldr x0, =str_ok
    bl append_string

    // Calcular longitud real del buffer armado y escribirlo a disco
    ldr x0, =out_buf
    mov x1, #0

len_loop:
    ldrb w2, [x0, x1]
    cbz w2, exec_write
    add x1, x1, #1
    b len_loop
exec_write:
    ldr x2, =file_out

    // recibe: x0=puntero a buffer, x1=longitud, x2=puntero a nombre de archivo
    bl utils_write_result

    mov x0, #0
    mov x8, #93                    // syscall exit
    svc #0


// ============================================================================
// Manejo de errores estructurados
// ============================================================================
arg_error:
    ldr x0, =err_args
    mov x1, len_err_args
    ldr x2, =file_out
    bl utils_write_result
    mov x0, #1
    mov x8, #93
    svc #0

col_error:
    ldr x0, =err_col
    mov x1, len_err_col
    ldr x2, =file_out
    bl utils_write_result
    mov x0, #1
    mov x8, #93
    svc #0

insuff_error:
    ldr x0, =err_insuff
    mov x1, len_err_insuff
    ldr x2, =file_out
    bl utils_write_result
    mov x0, #1
    mov x8, #93
    svc #0



// ============================================================================
// append_string: concatena el string apuntado por x0 al final de out_buf
// ============================================================================
append_string:
    ldr x1, =out_buf
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

// ============================================================================
// append_number: convierte x0 a texto (usando utils_itoa) y lo concatena
// ============================================================================
append_number:
    stp x29, x30, [sp, #-16]!
    ldr x1, =num_buf             
    bl utils_itoa
    ldr x0, =num_buf
    bl append_string
    ldp x29, x30, [sp], #16
    ret
