/* Funcionamiento general del modulo.
    1. solicitar al utils la extraccion de los datos de la columna 2 al stack
    2. recorrer la pila saltando de 16 en 16 bytes debido a la alineacion ARM64
    3. calcular la media
    4. calcular la varianza y la desviación calcular_desviacion_estandar
    5. evaluar cada lectura con la formula de Z-score y hacer el conteo de las anomalias encontradas
    6. determinar el niver de riesgo segun el total de las anomalias encontradas
    7. contruir el reporte y escribir el archivo resultado_anomalias.txt 
    
    Descripción:
       Detección estadística de anomalías utilizando el método matemático Z-Score.
       Adaptado a la librería dinámica orientada a Stack (utils.s).*/

/* ===========================================================================
   Mapeo del Uso de Registros (Preservados en subrutinas mediante la ABI):
   x19 - Puntero de lectura inicial a los datos en el Stack (Retornado en x0)
   x20 - Puntero límite final de los datos en el Stack (Retornado en x1)
   x21 - Cantidad total de registros leídos (Retornado en x2, debe ser 30)
   x22 - Dirección de control para restaurar el Stack Pointer original (Retornado en x3)
   x23 - Valor de la Media Aritmética calculada en el paso anterior
   x24 - Valor de la Desviación Estándar calculada
   x25 - Conteo final de anomalías detectadas (Z-Score >= 2)
   x26 - Puntero dinámico utilizado para la construcción del texto en el buffer
   =========================================================================== */

.global _start                              // Punto de entrada del programa para el enlazador

/* ===========================================================================
   SECCIÓN .data (Variables Inicializadas y Cadenas de Reporte)
   =========================================================================== */
.section .data
.align 3

archivo_salida:
    .asciz "resultado_anomalias.txt"

// encabezados y etiquetas textuales formateadas para el reporte de la salida
etq_module:   .asciz "MODULE=ANOMALY_DETECTION\n"
etq_total:    .asciz "TOTAL_VALUES=30\n"
etq_mean:     .asciz "MEAN="
etq_std:      .asciz "STD_DEV="
etq_anom:     .asciz "ANOMALIES="
etq_risk:     .asciz "SYSTEM_RISK="
etq_normal:   .asciz "NORMAL\n"
etq_medium:   .asciz "MEDIUM\n"
etq_high:     .asciz "HIGH\n"

/* ===========================================================================
   SECCIÓN .bss, variables en memoria RAM no inicializadas
   =========================================================================== */

.section.bss
.align 4

res_media:          .skip 8
res_desv:           .skip 8
res_anomalias:      .skip 8 
// el skip 8 es para reservar 8 bytes que es lo que ocupa un numero entero

buffer_salida:      .skip 512

/* ===========================================================================
   SECCION .text (codigo de ejecucion del programa)
   =========================================================================== */
.section .text

_start:
    // Paso 1: extraer los datos de la columna de temperatura usando el utils
    mov x11, #2                             // x11 = parametro para utils: columna 2
    bl utils_read_column_to_stack           // se llama la funcion y guarda los datos en el stack

    // se guardan los valores que retorna el utils
    mov x19, x0                             // x19 = puntero de inicio de los numeros en el stack
    mov x20, x1                             // x20 = puntero de fin de los numeros en el stack
    mov x21, x2                             // x21 = cantidad de los datos, osea 30
    mov x22, x3                             // x22 = direccion de restauracion de la pila original

    // Paso 2: llamada a las Funciones (subrutinas)
    bl calcular_media_aritmética
    bl calcular_desviacion_estandar
    bl detectar_y_contar_anomalias
    bl generar_reporte_salida

    // Paso 4: lineracion de la pila dinamica y salida del programa
    mov sp, x22                             // devuelve el sp a su estado original (restauracion), dejar el stack a como estaba antes
    
    mov x0, #0                              // codigo de retorno 0
    mov x8, #93                             // syscall id para sys_exit en linux ARM64
    svc #0                                  // llama al kernel del sistema operativo
    // se le pide al sistema operativo que ejecute la syscall número 93 (exit), es la única forma de terminar un programa en ensamblador

/* ===========================================================================
   Subrutina: calcular_media_aritmética
   Objetivo: Sumar las lecturas en la pila y dividirlas por N (30).
   =========================================================================== */
calcular_media_aritmética:
    // Prologo: Reservar espacio en la pila y guardar registros del llamador
    stp x29, x30, [sp, #-32]!               // guardar dos registros, reduce el stack pointer en 32 bytes y luego guarda
    mov x29, sp                             // actualizar el frame pointer al tope actual del stack
    stp x1, x2, [sp, #16]                   // registros guardados

    mov x4, x19                             // x4 = puntero del recorrido, inicia en x19 (el inicio del stack)
    mov x5, #0                              // x5 = acumulador de la suma, y se inicia en 0
    mov x6, #0                              // x6 = i, osea, el contador de los datos en el bucle

.loop_suma_media:
    cmp x6, x21                             // comparar x6 con x21 para sumar todos los datos
    bge .finalizar_media                    // si x6 es mayor a x21(30 datos), entonces se sale del loop, i >= 30

    ldr x7, [x4]                            // se carga el dato actual en x7
    add x5, x5, x7                          // suma += dato

    add x4, x4, #16                         // saltar 16 bits de la pila hacia x7
    add x6, x6, #1                          // i ++
    b   .loop_suma_media                    // se repite el ciclo

.finalizar_media:
    sdiv x5, x5, x21                        // total de la suma / total de datos
    mov  x23, x5                            // se conserva el valor del resultado en x23 (valor de la media)
    ldr  x1, =res_media                     // cargar la dirección de la variable res_media en x1
    str  x23, [x1]                          // Guarda el valor de x23 en la dirección de memoria que tiene x1

    // Epilogo: restaurar registros y regresar
    ldp x1, x2, [sp, #16]                   // el 16 deshace el espacio que se reservo
    ldp x29, x30, [sp], #32                 // el 32 deshace el espacio que se reservo
    ret                                     // salta a la direccion que guardaba x30 (return)

/* ===========================================================================
   Subrutina: calcular_desviacion_estandar
   Objetivo: Calcular la varianza poblacional y su raíz cuadrada entera.
   ========================================================================== */
calcular_desviacion_estandar:
    // Prologo: Reservar espacio en la pila y guardar registros del llamador
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x1, x2, [sp, #16]
    stp x4, x5, [sp, #32]

    mov x4, x19                             // reiniciar puntero al inicio del stack de datos
    mov x5, #0                              // acumuladro de la suma de las diferencias al cuadrado
    mov x6, #0                              // contador de los daros en el bucle

.loop_varianza:
    cmp x6, x21
    bge .finalizar_desv

    ldr x7, [x4]
    sub x7, x7, x23                         // x7 = dato - media
    mul x7, x7, x7                          // x7 = (dato - media)^2
    add x5, x5, x7                          // suma_cuadrados +=x7

    add x4, x4, #16                         // se avanzan 16 bytes al siguiente registro del stack
    add x6, x6, #1                          // i ++
    b   .loop_varianza

.finalizar_desv:
    sdiv x5, x5, x21                        // x5 = suma_cuadrados / 30 (Varianza entera)

    // algoritmo de newton para poder calcular la reiz cuadrada entera
    mov x0, x5                              // x0 = valor de entrada para la raiz (radicando)
    cbz x0, .raiz_cero                      // si la varianza es 0, la desviacion es 0
    mov x1, x0                              // x1 = estimacion inicial de la raiz

.loop_newton:
    sdiv x2, x0, x1                         // x2 = radicando / estimacion
    add  x2, x1, x2                         // x2 = estimado + (radicando / estimacion)
    lsr  x2, x2, #1                         // x2 = x2 / 2

    cmp x2, x1                              // se compara si la nueva aproximacion convergio, nueva >= actual
    bge .raiz_lista                         // si ya no disminuye, se encontro la raiz
    mov x1, x2                              // se actualiza la estimacion actual con la nueva
    b   .loop_newton

.raiz_lista:
    mov x0, x1                              // se mueve el resultado dela raiz a x0
.raiz_cero:
    mov x24, x0                             // se conserva la desviacion en el registro global x24
    ldr x1, =res_desv
    str x24, [x1]                           // se guarda la desviacion en la seccion .bss

    // Epilogo: restaurar registros y regresar
    ldp x4, x5, [sp, #32]
    ldp x1, x2, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

/* ===========================================================================
   Subrutina: detectar_y_contar_anomalias
   Objetivo: Identificar lecturas atípicas mediante la regla experimental Z >= 2.
   =========================================================================== */
detectar_y_contar_anomalias:
    // Prologo: Reservar espacio en la pila y guardar registros del llamador
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x1, x2, [sp, #16]
    stp x4, x5, [sp, #32]

    mov x4, x19                             // apuntar al inicio del stack de enteros
    mov x25, #0                             // inicializar contador de anomalias globales en 0
    mov x6, #0                              // i = 0

    cbz x24, .anomalias_cero_desv           // si la desviacion es 0, se omite 

.loop_anomalias:
    cmp x6, x21                             // comparar para hacer los 30 datos
    bge .finalizar_anomalias

    ldr x7, [x4]                            // cargar dato actual del stack
    sub x1, x7, x23                         // x1 = dato - media

    // operacion para valor absoluto manual
    tst x1, x1                              // evalua cual es el signo de x1
    bpl .signo_positivo                     // si es positivo, continuar
    neg x1, x1                              // si es negativo, se invierte el signo para pasarlo a absoluto

.signo_positivo:
    sdiv x2, x1, x24                        // x2 = z-score = diferencia / desviacion

    cmp x2, #2                              // evaluamos el valor para ver si es mayor a 2 o igual
    blt .lectura_normal                     // si es menor que 2, esta en el rango normal
    add x25, x25, #1                        // si Z >= 2, es anomalia,y se suma 1 al contador

.lectura_normal:
    add x4, x4, #16                         // avanza al siguiente dato
    add x6, x6, #1                          // i++
    b   .loop_anomalias

.finalizar_anomalias:
.anomalias_cero_desv:
    ldr x1, =res_anomalias
    str x25, [x1]                           // se almacena el total de las anomalias en la seccion .bss

    // Epilogo: restaurar registros y regresar
    ldp x4, x5, [sp, #32]
    ldp x1, x2, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

/* ===========================================================================
   Subrutina: generar_reporte_salida
   Objetivo: Ensamblar los strings informativos en el buffer RAM y llamar a utils.
   =========================================================================== */
generar_reporte_salida:
    // Prologo ABI: Guardar registros que vamos a usar y el link register (x30)
    stp x29, x30, [sp, #-48]!
    mov x29, sp                         // actualiza para que apunte al tope del stack
    stp x25, x26, [sp, #16]             // Preservar conteo de anomalías y puntero dinámico
    stp x23, x24, [sp, #32]             // Preservar media y desviación estándar

    ldr x26, =buffer_salida             // x26 = Puntero dinámico al inicio del buffer

    // 1. agregar la cabecera del modulo 
    mov x0, x26
    ldr x1, =etq_module
    bl utilidad_concatenar_cadena
    mov x26, x0                         // x26 avanza al final del texto insertado

    // 2. agregar el total de los datos procesados
    mov x0, x26
    ldr x1, =etq_total
    bl utilidad_concatenar_cadena
    mov x26, x0

    // 3. agregar campo "MEAN" y su valor numerico convertido
    mov x0, x26
    ldr x1, =etq_mean
    bl utilidad_concatenar_cadena
    mov x26, x0

    mov x0, x23                         // pasar la media calculada (x23)
    mov x1, x26                         // destino en el buffer
    bl utils_itoa                       // escribe el numero, añade \n y \0

    // avanzar puntero x26
    mov x0, x26
.avanza_mean:
    ldrb w2, [x0]                       // leer un byte
    cbz  w2, .fin_avanza_mean           // si es '\0', para
    add  x0, x0, #1                     // Si no, avanzar
    b    .avanza_mean
.fin_avanza_mean:
    mov x26, x0                         // x26 ahora apunta al '\0'

    // 4. agregar campo "STD_DEV" y su numero convertido
    mov x0, x26
    ldr x1, =etq_std
    bl  utilidad_concatenar_cadena
    mov x26, x0

    mov x0, x24                         // Pasar la desviación estándar (x24)
    mov x1, x26
    bl  utils_itoa
    
    mov x0, x26
.avanza_std:
    ldrb w2, [x0]
    cbz  w2, .fin_avanza_std
    add  x0, x0, #1
    b    .avanza_std
.fin_avanza_std:
    mov x26, x0

    // 5. agregar campo "ANOMALIES=" y su valor
    mov x0, x26
    ldr x1, =etq_anom
    bl  utilidad_concatenar_cadena
    mov x26, x0

    mov x0, x25                         // Pasar el conteo total de anomalías (x25)
    mov x1, x26
    bl  utils_itoa
    
    mov x0, x26
.avanza_anom:
    ldrb w2, [x0]
    cbz  w2, .fin_avanza_anom
    add  x0, x0, #1
    b    .avanza_anom
.fin_avanza_anom:
    mov x26, x0

    // 6. agregar campo de evaluacion "SYSTEM_RISK"
    mov x0, x26
    ldr x1, =etq_risk
    bl  utilidad_concatenar_cadena
    mov x26, x0

    // Clasificación del riesgo por umbrales estadísticos
    cmp x25, #0                         // si x25 es = 0
    beq .escribir_riesgo_normal         // 0 anomalias, NORMAL

    cmp x25, #4                         // si x25 es menor a 4
    blt .escribir_riesgo_medium         // 1, 2 o 3 anomalias, MEDIUM

.escribir_riesgo_high:
    mov x0, x26
    ldr x1, =etq_high                   // 4 o mas, HIGH
    bl  utilidad_concatenar_cadena
    mov x26, x0
    b   .guardar_archivo_fisico

.escribir_riesgo_normal:
    mov x0, x26
    ldr x1, =etq_normal
    bl  utilidad_concatenar_cadena
    mov x26, x0
    b   .guardar_archivo_fisico

.escribir_riesgo_medium:
    mov x0, x26
    ldr x1, =etq_medium
    bl  utilidad_concatenar_cadena
    mov x26, x0

.guardar_archivo_fisico:
    // 1. Calcular el tamaño real neto en bytes
    ldr x5, =buffer_salida      // x5 = Dirección inicial base del buffer
    sub x1, x26, x5             // x1 = Puntero_Final (x26) - Puntero_Inicial (x5) = Tamaño real

    // 2. Cargar parametros de la ABI para utils_write_result
    ldr x0, =buffer_salida      // buffer con el texto
    ldr x2, =archivo_salida     // nombre del archivo

    // 3. Invocar la escritura fisica
    bl  utils_write_result      // crear y escribir el archivo

    // Epilogo ABI: Restaurar todos los registros guardados y retornar
    ldp x23, x24, [sp, #32]
    ldp x25, x26, [sp, #16]
    ldp x29, x30, [sp], #48
    ret


utilidad_concatenar_cadena:
.loop_copia_bytes:
    ldrb w2, [x1], #1                   // Leer 1 byte de x1 y avanzar x1
    cbz  w2, .fin_copia_bytes           // Si es '\0', terminar
    strb w2, [x0], #1                   // Escribir byte en x0 y avanzar x0
    b    .loop_copia_bytes
.fin_copia_bytes:
    ret                                 // Retorna con x0 actualizado                            

// Esta funcion copia letra por letra desde el texto fuente (x1) hacia el buffer destino (x0) hasta encontrar el \0


utilidad_avanzar_puntero_itoa:
.loop_conteo_caracteres:
    ldrb w2, [x0]                       // Leer byte actual
    cbz  w2, .fin_conteo_caracteres     // Si encontramos el \0, aquí nos detenemos
    add  x0, x0, #1                     // Avanzar al siguiente byte
    b    .loop_conteo_caracteres
.fin_conteo_caracteres:
    ret                                 // Retorna x0 apuntando EXACTAMENTE al \0          
                                        // Retorna en x0 el nuevo puntero alineado al final de la cadena
.include "utils.s"