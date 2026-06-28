//modulo 5: derivada Suavizada por regresion Local

.global _start


// DATA Contiene todas las cadenas de texto constantes usadas en el reporte
.section .data
.align 3

archivo_salida:  .asciz "resultado_derivada.txt"  //  nombre del archivo de salida

etq_calc:        .asciz "CALC=LOCAL_DERIVATIVE\n"
etq_column:      .asciz "COLUMN="
etq_win_start:   .asciz "WINDOW_START="             //donde inicia
etq_win_end:     .asciz "WINDOW_END="               //donde termina
etq_count:       .asciz "COUNT="                    //total de datos
etq_win_size:    .asciz "WINDOW_SIZE=5\n"           // constante
etq_max_slope:   .asciz "MAX_LOCAL_SLOPE_X100="
etq_status_ok:   .asciz "STATUS=OK\n"
etq_status_err:  .asciz "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=LOCAL_DERIVATIVE_REQUIRES_AT_LEAST_5_VALUES\n"
// esta es para cuando hay error, osea cuando el rango es menor a 5, ya que eso se requiere

//.bss — memoria reservada sin inicializar
.section .bss
.align 4

num_buffer:     .skip 32                // buffer temporal en donde el utils itoa escribe el numero convertido a texto 
buffer_salida:  .skip 512               // buffer en donde se va armando el reporte 

.section .text                          // codigo ejecutable

_start:
    ldr x0, [sp]                        // carga argss desde el stack 
    cmp x0, #5                          // se necesitan 4 argumentos mas el nombre del programa 
    blt salir_con_error                 // si hay menos de 5 - error 

    ldr x2, [sp, #16]                   //puntero de la cadena argv[1] 
    
    mov x21, x2                         //se copia el puntero del archivo en x21
//el utils usa el registro x21 para saber que archivo abrir 

    ldr x0, [sp, #24]                   // puntero de la cadena argv[2], linea inicial
    bl atoi_argv
    mov x24, x10                        // x24 es la linea inicial del rango que se procesa

    ldr x0, [sp, #32]                   // puntero argv[3], linea final
    bl atoi_argv
    mov x25, x10                        // x25 es la linea final del rango que se procesq

    ldr x0, [sp, #40]                   // puntero argv[4], columna que se analiza
    bl atoi_argv                        // convertir el string a entero 
    mov x11, x10

    bl utils_read_column_to_stack       // lee el archivo y extrae la columna

    cmp x4, #0                          // se verifica si hubo error de columna o de rango 
    bne salir_con_error                 // si si se termina el programa con codigo de error 

    mov x19, x0                         // inicio de los dato sen el stack 
    mov x20, x1                         // limite superior del stack
    mov x21, x2                         // cantitad total de valores extraidos
    mov x22, x3                         // valor del sp original, para restaurar el stack al terminar

    cmp x21, #5                         // se necesital al menos 5 datos para calcular la derivada local
    blt error_insuficiente              // si no, ir al mensaje de error estruturado 

    mov x23, #0                         // valor absoluto maximo en contrado de momento
    mov x8,  #0                         // indice de la ventana actual 

    sub x9, x21, #4                     // cantidad de ventanas posibles. n - 4

loop_ventanas:
    cmp x8, x9                          // ver si se procesaron ya todas las ventanas posibles
    bge fin_ventanas                    //si si, se termina el ciclo principal 

    sub x4, x20, #16                    // direccion del dato mas antiguo del rango leido
    mov x10, #16                        // tamaño de bytes de cada dato almacenado 
    mul x10, x8, x10                    // indice de ventana * 16
    sub x4, x4, x10                     // puntero al primer dato 

    mov x5, #0                          // suma(Y_i) - acumulador de los valores de y de la ventana 
    mov x6, #0                          // suma(X_i * Y_i) - acumulador de los productos x*y 
    mov x7, #0                          // X local, posicion dentro de la ventana: 0,1,2,3,4,

loop_5_puntos:                         
    cmp x7, #5                          // ver si ya se procesaron los 5 puntos de esta ventana 
    bge fin_5_puntos                    // si si, se sale del ciclo 

    ldr x0, [x4]                        //x0 = Y_i, el valor actual de la ventana 
    add x5, x5, x0                      // suma_Y += Y_i
    mul x0, x0, x7                      // X_i * Y_i, X_i es la posicion local de 0 a 4 dentro de la ventana 
    add x6, x6, x0                      // suma_XY += X_i * Y_i

    sub x4, x4, #16                     // se avanza el puntero al siguiente dato
    add x7, x7, #1                      // se incrementa X local 
    b loop_5_puntos                     // se repite hasta que se completen los 5 puntos 

fin_5_puntos:                           // se aplica la formula LOCAL_SLOPE_X100 = ((5 * suma_XY) - (10 * suma_Y)) * 100 / 50
    mov x0, #5                          // x0 = 5
    mul x0, x0, x6                      //x0 = 5 * suma_XY
    mov x1, #10                         // x1 = 10
    mul x1, x1, x5                      // x1 = 10* suma_Y
    sub x0, x0, x1                      // x0 = numerador = (5*suma_XY) - (10*suma_Y)
    mov x1, #100                      // x1= 100
    mul x0, x0, x1                      // x0 = numerador * 100
    mov x1, #50                         // x1 = 50
    sdiv x0, x0, x1                     // x0 = LOCAL_SLOPE_X100

// se calcula el valor absoluto de la pendiente para compararla con el maximo
    cmp x0, #0                          // se ver si es negativa
    bge slope_positivo                  // si no, no se hace nada
    neg x0, x0                          // si si, se cambia el signo 
slope_positivo:                         
    cmp x0, x23                         // se ver si la pendiente supera al maximo actual 
    ble slope_no_es_max                 // si no, no se actualiza 
    mov x23, x0                         // si si, se actualiza con la nueva pendiente 
slope_no_es_max:                        

    add x8, x8, #1                      // se avanza al indice de la siguiente ventana 
    b loop_ventanas                     // se repite el proceso 

// se contruye el reporte de texto en biffer_salida 
fin_ventanas:
    ldr x1, =buffer_salida              // rireccion del inicio del buffer de salida 
    strb wzr, [x1]                      // coloca 0 al inicio para vacial el biffer antes de escribir 

    ldr x0, =etq_calc                   // direccion de la etiqueta 
    bl append_string                    // se agrega al buffer 

    ldr x0, =etq_column
    bl append_string                    // agregar la etiqueta al biffer 
    mov x0, x11                         // x0 es el numero de la columna inicializada 
    bl append_number                    // convertir a texto y agregarlo

    ldr x0, =etq_win_start
    bl append_string
    mov x0, x24                         // valor de la linea inicial
    bl append_number

    ldr x0, =etq_win_end
    bl append_string
    mov x0, x25                         // valor de la linea final
    bl append_number

    ldr x0, =etq_count
    bl append_string
    mov x0, x21                         //cantidad total de datos procesados 
    bl append_number

    ldr x0, =etq_win_size
    bl append_string

    ldr x0, =etq_max_slope
    bl append_string
    mov x0, x23                         // valor maximo de pendiente local calculado 
    bl append_number

    ldr x0, =etq_status_ok
    bl append_string

    b escribir_resultado                // saltar a la seccion de que escribe el archivo 

// datos insuficientes, N es menos a 5
error_insuficiente:
    ldr x1, =buffer_salida              // direccion del inicio del buffer de salida 
    strb wzr, [x1]                      // vaciamos el buffer 
    ldr x0, =etq_status_err             // mensaje de error 
    bl append_string                    // agregarlo al buffer 

// longitud del texto almacenado en buffer_salida
escribir_resultado:
    ldr x0, =buffer_salida              // direccion del buffer de salida 
    mov x1, #0                          // contador de bytes 
calc_len:
    ldrb w2, [x0, x1]                   // se lee el byte que esta en la pusicion de x1 
    cbz w2, do_write                    // si es 0, ya se termino de contar 
    add x1, x1, #1                      // si no, se incrementa el contador y se sigue 
    b calc_len                          // se repite hasta encontrar el 0 
do_write:
    ldr x2, =archivo_salida             // direccion del nombre 
    bl utils_write_result               // ascribir el archivo 

    mov sp, x22                         // se restaura el stack pointer al valor que tenia antes de leer datos 
    mov x0, #0                          
    mov x8, #93
    svc #0

salir_con_error:
    mov x0, #1
    mov x8, #93
    svc #0

// busca el final actual del buffer_salida hasta encontrar el 0 de origen 
append_string:
    ldr x1, =buffer_salida              // puntero al inicio del buffer de salida 
find_end:
    ldrb w2, [x1]                       // lee el byte actual del bufer de salida 
    cbz w2, copy_str                    //si es 0, es que se encontro el final, y copia ahi 
    add x1, x1, #1                      // si no, avanza al siguiente byte 
    b find_end                          //se repite hasta encontrar el final del buffer 
copy_str:
    ldrb w2, [x0], #1                   //lee el byte de la cadena origen y avanza su puntero 
    strb w2, [x1], #1                   // escribe el byte en el buffer destino y avanza 
    cbnz w2, copy_str                   // si el byte copiado no era 0, sigue copiando 
    ret

// convierte el entero recibido en x0 a texto y concatena el texto al final del buffer_salida
append_number:
    stp x29, x30, [sp, #-16]!           // guardar frame pointer y link register en el stack 
    mov x29, sp                         // fijar el frame pointer al stack actual 
    ldr x1, =num_buffer                 //buffer temporal en donde se escribe el numero convertido 
    bl utils_itoa                       // convertir el numero a ASCII dentro de num_buffer
    ldr x0, =num_buffer                 //direccion del texto ya convertido 
    bl append_string                    // agregar el texto al final del buffer de salida 
    ldp x29, x30, [sp], #16
    ret

.include "utils.s"