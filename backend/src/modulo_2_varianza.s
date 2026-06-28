.global _start

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

.text
_start:
    mov x19, sp                  // x19 = sp original

    // leyendo columna desde el argumento
    ldr x0, [x19, #16]           // x0 = argv[1]
    ldrb w11, [x0]               // primer caracter ASCII
    sub x11, x11, #48            // ASCII -> entero -> columna en x11

    // Leyendo la clomuna de datos que se pidio en el argumento
    bl utils_read_column_to_stack
    mov x20, x0                  // x20 = inicio de los datos
    mov x21, x2                  // x21 = cantidad (30)
    mov x25, x3                  // x25 = posicion para restaurar el stack

    // Llamando a los calculos a realizar
    bl med
    bl var
    bl dsvs

    // Escribir la salida
    bl guardar_txt

    // Restaurar stack y salir
    mov sp, x25
    mov x0, #0
    mov x8, #93
    svc #0

med:
    mov x10, #0             // x10 va a ser el registro en el que voy a guardar todas la suma de los datos, va a funcionar como un acumulador por eso lo inicializo en 0
    mov x4, x20             // x4 es el puntero a los datos, o sea, el primer dato a procesar
    mov x5, x21             // x5 es la cantidad de datos de la columna, este sera mi control para el loop
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
    mov x5, x21             // x5 cantidad de datos totales
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
    mov x24, x5             // una vez termino el loop ya tengo el resultado de la raiz cuadrada
    ret                     // termino la funcion

// Escritura de la salida
guardar_txt:
    stp x29, x30, [sp, #-16]!    // hago un substack para colocar ahi la salida para el txt

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

    .include "utils.s"