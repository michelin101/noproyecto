.global _start

.data                                       //tambien cambie la salida para que sea la de este formato nuevo
str_calc:       .asciz "CALC=VARIANCE\n"
str_col:        .asciz "COLUMN="
str_wstart:     .asciz "WINDOW_START="
str_wend:       .asciz "WINDOW_END="
str_count:      .asciz "COUNT="
str_med:        .asciz "MEAN="
str_varianza:   .asciz "VARIANCE="
str_dsvs:       .asciz "STD_DEV="
out_filename:   .asciz "resultado_varianza.txt"
str_status:     .asciz "STATUS=OK\n"
//agregando lo del manejo de errores del nuevo formato del utils
err_status:         .asciz "STATUS=ERROR\n"
err_args:           .asciz "ERROR=INSUFFICIENT_ARGUMENTS\n"
det_args:           .asciz "DETAIL=INVALID_ARGUMENT_COUNT\n"
err_col:            .asciz "ERROR=INVALID_COLUMN\n"
det_col:            .asciz "DETAIL=COLUMN_NOT_IN_HEADER\n"
err_rango:          .asciz "ERROR=INVALID_RANGE\n"
det_rango:          .asciz "DETAIL=START_GREATER_THAN_END\n"
err_data:           .asciz "ERROR=INSUFFICIENT_DATA\n"
det_data:           .asciz "DETAIL=AT_LEAST_1_VALUE_REQUIRED\n"

.bss
buffer_var:
    .skip 256

.text
_start:
    mov x19, sp                  // x19 = sp original
    //aqui solo copie y pegue de mi nuevo modulo
    ldr x0, [x19]
    cmp x0, #5
    blt arg_error           //pues faltaron argumentos si se llego hasta aqui

    ldr x21, [x19, #16]     //ahora esto es el nombre del archivo

    ldr x0, [x19, #24]
    bl atoi_argv            //este si no estoy mal es el inicio de las filas
    mov x24, x10

    ldr x0, [x19, #32]
    bl atoi_argv            //y este el final
    mov x25, x10

    ldr x0, [x19, #40]
    bl atoi_argv          //todo esto fue solo la columna xd//arreglando aqui tambien esto
    mov x11, x10

    // Leyendo la clomuna de datos que se pidio en el argumento
    bl utils_read_column_to_stack
    
    cmp x4, #1              
    beq col_error           // columna no existe
    cmp x4, #2
    beq rango_error         //si el rango es invalido, aunque creo que no valida como tal si las lineas existe (va a haber que revisar el utils)
    cmp x2, #1
    blt data_error

    mov x20, x0             //inicio de los datos
    mov x21, x1             //tope 
    mov x22, x2             //cantidad de datos que se leyeron
    mov x23, x3             //posicion de retorno
    mov x27, x23            //al final, voy a tener que hacer una copia de la direccion de retorno para no sobreescribirla en mis calculso 
    mov x28, x22            //tambien una copia pero ahora de la cantidad 

    // Llamando a los calculos a realizar
    bl med
    bl var
    bl dsvs

    // Escribir la salida
    bl guardar_txt

    // Restaurar stack y salir
    mov sp, x27
    mov x0, #0
    mov x8, #93
    svc #0

med:
    mov x10, #0             // x10 va a ser el registro en el que voy a guardar todas la suma de los datos, va a funcionar como un acumulador por eso lo inicializo en 0
    mov x4, x20             // x4 es el puntero a los datos, o sea, el primer dato a procesar
    mov x5, x22             // x5 es la cantidad de datos de la columna, este sera mi control para el loop
    mov x6, x5              // creo una copia de la cantidad de datos totales para usarla al final en la division

med_suma_loop:
    ldr x1, [x4], #16       // cargo el registro actual dentro del registro x1, luego hago un corrimiento de 16 bytes para llegar al siguiente numero en el stack
    add x10, x10, x1        // sumo el dato que acabo de leer en mi acumulador
    sub x5, x5, #1          // le resto 1 a mi control de loop
    cmp x5, #0              // comparo mi control de loop con 0 para ver si me detengo o no,
    bgt med_suma_loop       // si el resultado de la comparacion es mayor que 0 sigo con mi suma
    udiv x22, x10, x6       // si no es mayor que 0, hago la division final del total de datos sumados con el numero total de datos.
    ret                     // termino la funcion

var:
    mov x10, #0             // más de lo mismo que en media, acumulador iniciado en 0 
    mov x4, x20             // x4 puntero al primer dato
    mov x5, x28             // x5 cantidad de datos totales
    mov x6, x5              // copia para division final
    
var_suma_loop:              // no se por que lo llame asi porque no es solo la suma xd
    ldr x1, [x4], #16       // cargo el dato actual en x1 y hago el corrimiento de 16 bytes en el puntero original
    sub x1, x1, x22         // le quito al valor actual el valor de la media, actualmente guardado en x22
    mul x1, x1, x1          // multiplico el valor resultante por si mismo para lograr el (x-med)^2
    add x10, x10, x1        // coloco el resultado en mi acumulador
    sub x5, x5, #1          // resto 1 a mi control de loop
    cmp x5, #0              // comparo el control de loop para ver si sigo o no
    bgt var_suma_loop       // si la comparacion es mayor que 0, sigo con el loop
    udiv x23, x10, x6       // si no hago la division final que me dara el valor final de la varianza y la coloco en x23
    ret                     // termino la funcion

dsvs:
    mov x10, x23            // cargo la varianza recien calculada en x10 
    mov x4, x10             // La varianza que se calculo antes es el valor del que quiero la raiz
    mov x5, x10             // creo una copia de la varianza para usarla como valor inicial (x sub 0)

dsvs_loop:                  // voy a usar la forumla de newton para la raiz cuadrada que sale de un x^2 = S, la formula final es 1/2(x sub n + (S/x sub n))
    sdiv x1, x4, x5         // hago la division (S/x sub n) y la guardo en x1
    add  x2, x5, x1         // luego hago la suma (x sub n + (S/x sub n))
    mov  x6, #2             // al parecer sdiv solo funciona con registros asi que coloco un 2 en el registro x6 para usarlo en sdiv
    sdiv x3, x2, x6         // uso sdiv para hacer la ultima division por 2
    cmp  x3, x5             // hago una comparacion entre el resultado del metodo y la estimacion anterior 
    bhs dsvs_done           // si el resultado es mayor o igual a la aproximacion anterior salgo del loop
    mov x5, x3              // si no actualizo el valor de x sub n para la siguiente iteracion
    b dsvs_loop             // comienzo el loop de nuevo

dsvs_done:
    mov x26, x5             // una vez termino el loop ya tengo el resultado de la raiz cuadrada
    ret                     // termino la funcion
arg_error:
    ldr x9,  =err_args
    ldr x10, =det_args
    b guardar_error
col_error:
    ldr x9,  =err_col
    ldr x10, =det_col
    b guardar_error
rango_error:
    ldr x9,  =err_rango
    ldr x10, =det_rango
    b guardar_error
data_error:
    ldr x9,  =err_data
    ldr x10, =det_data
    b guardar_error

guardar_error:
    ldr x1, =buffer_var
    ldr x3, =err_status         // "STATUS=ERROR" //todas estas cosas las declare en el .data
    bl copiar_str
    mov x3, x9                  // "ERROR="
    bl copiar_str
    mov x3, x10                 // "DETAIL="
    bl copiar_str
    ldr x0, =buffer_var
    sub x1, x1, x0
    ldr x2, =out_filename
    bl utils_write_result
    mov x0, #1
    mov x8, #93
    svc #0

// Escritura de la salida
guardar_txt:
    stp x29, x30, [sp, #-16]!    // hago un substack para colocar ahi la salida para el txt

    ldr x1, =buffer_var              // x1 = posicion de escritura

    ldr x3, =str_calc         // "MODULE=VARIANCE\n"
    bl copiar_str

    ldr x3, =str_col             // "COLUMN="
    bl copiar_str
    mov x0, x11                  // numero de columna
    bl escribir_num

    ldr x3, =str_wstart          // "WINDOW_START="
    bl copiar_str
    mov x0, x24                  // inicio
    bl escribir_num

    ldr x3, =str_wend            // "WINDOW_END="
    bl copiar_str
    mov x0, x25                  // final
    bl escribir_num

    ldr x3, =str_count           // "COUNT="
    bl copiar_str
    mov x0, x28                  // cantidad de valores
    bl escribir_num              

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
    mov x0, x26                  // desviacion estandar
    bl escribir_num

    ldr x3, =str_status         // "STATUS=OK\n"
    bl copiar_str

    ldr x0, =buffer_var              // inicio del buffer
    sub x1, x1, x0               // longitud = posicion actual - inicio
    ldr x2, =out_filename
    bl utils_write_result

    ldp x29, x30, [sp], #16
    ret

copiar_str:

copiar_loop:
    ldrb w4, [x3], #1            // lee un byte de la fuente y avanza
    cbz w4, copiar_fin           // si es \0, termina (no lo copia)
    strb w4, [x1], #1            // escribe el byte en el buffer y avanza
    b copiar_loop
copiar_fin:
    ret

escribir_num:
    stp x29, x30, [sp, #-16]!
    bl utils_itoa
avanzar:
    ldrb w2, [x1], #1
    cbnz w2, avanzar
    sub x1, x1, #1
    ldp x29, x30, [sp], #16
    ret

.include "utils.s" //pos si iva xd, era por el makefile