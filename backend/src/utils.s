/*
    ===========================================================================
    Módulo: utils.s 2
    Proyecto: Invernadero Inteligente IoT (Raspberry Pi ARM64)
    ===========================================================================
    Descripción general:
    Biblioteca común para la lectura de lecturas.csv, parseo de columnas,
    conversión ASCII <-> Entero, manejo de memoria dinámica (Stack) y
    escritura de resultados a archivos de salida.

    ---------------------------------------------------------------------------
    [ Función Principal de Lectura: utils_read_column_to_stack ]
    Entrada:
       x11 = número de columna seleccionada (1 = ID, 2 = TEMP, etc.)
       x24 = línea inicial del rango a procesar (1 = primera línea de datos,
             sin contar el encabezado)
       x25 = línea final del rango a procesar (>= x24)
    Salida:
       x0 = dirección de inicio de los datos en el stack
       x1 = dirección límite final de los datos en el stack
       x2 = cantidad de números guardados (variable segun rango)
       x3 = posición para restaurar el stack pointer (sp) al finalizar
       x4 = estado: 0 = OK, 1 = la columna solicitada no existe en el
            encabezado del archivo (en ese caso x2 = 0)
    ---------------------------------------------------------------------------
*/

.global utils_read_column_to_stack
.global utils_write_result
.global utils_itoa
.global atoi_argv

.data
err_open:
    .ascii "Error al abrir el archivo\n"
    len_err_open = . - err_open

err_read:
    .ascii "Error al leer el archivo\n"
    len_err_read = . - err_read


.bss
buffer:
    .skip 4096                  // Buffer para la lectura, se hacen lecturas en bucle

buf_pos:
    .skip 8                     // Posición actual dentro de "buffer"

buf_len:
    .skip 8                     // lo que de volvio la ultima llamada de read()

write_buffer:
    .skip 256                   // Buffer temporal para conversión de enteros a ASCII

.text

// ============================================================================
// 1. LECTURA Y EXTRACCIÓN DE COLUMNA AL STACK (rango variable)
// ============================================================================
utils_read_column_to_stack:
    stp x29, x30, [sp, #-16]!   // Guardar frame pointer (x29) y link register (x30)
    mov x29, sp                 // Actualizar frame pointer al stack actual

    mov x28, sp                 // x28 = límite superior de datos (dirección más alta)
    add x27, x28, #16           // x27 = posición segura para restaurar el stack original

    mov x22, #0                 // x22 = contador de números extraídos (variable)
    mov x4,  #0                 // x4  = estado de salida (0 = OK por defecto)

    // Abrir archivo y resetear buf_pos / buf_len
    bl utils_open_file          // Llamada para abrir lecturas.csv

    cmp x24, #1
    blt utils_invalid_range     // Si línea inicial < 1 - error de rango

    cmp x24, x25
    bgt utils_invalid_range     // Si línea inicial > línea final - error de rango

    mov x12, #1                 // x12 = contador de columna actual (inicia en la columna 1)

utils_count_header_columns:
    bl utils_next_char           // w23 = siguiente carácter del archivo
    cmp w23, '$'                 // archivo vacío
    beq utils_invalid_column
    cmp w23, #10                 // fin del encabezado
    beq utils_check_column_exists
    cmp w23, ','
    bne utils_count_header_columns
    add x12, x12, #1
    b utils_count_header_columns

utils_check_column_exists:       // verificar que la columna exista
    cmp x11, x12
    bgt utils_invalid_column     // la columna pedida no existe en el encabezado

    mov x26, #0                  // x26 = número de línea de datos actual (1-indexada)

    // Saltar las líneas anteriores a la línea inicial solicitada (x24)

utils_skip_before_start:
    add x26, x26, #1
    cmp x26, x24
    bge utils_process_line       // ya llegamos a la línea inicial solicitada

    bl utils_skip_to_next_line
    cmp w23, '$'                 // el archivo terminó antes de llegar al rango
    beq utils_done
    b utils_skip_before_start

// Procesar cada línea dentro del rango [x24, x25], y detenerse enla linea fina solicitada

utils_process_line:
    mov x12, #1                 // x12 = contador de columna actual (inicia en la columna 1)

utils_find_column:
    cmp x12, x11                // ¿La columna actual (x12) es la que buscamos (x11)?
    beq utils_read_column       // Si es igual, procedemos a leer y convertir el número

    bl utils_skip_to_next_column // Si no es la columna, saltamos los caracteres hasta la siguiente coma

    cmp w23, '$'                // ¿Llegamos al final del archivo mientras saltábamos?
    beq utils_done              // Terminar si es el caso

    cmp w23, #10                // ¿Llegamos al final de la línea (\n) prematuramente?
    beq utils_next_line_check   // Si es así, reiniciar búsqueda en la siguiente línea

    add x12, x12, #1            // Incrementar contador de columna (avanzamos de campo)
    b utils_find_column         // Repetir el ciclo de búsqueda de columna

utils_read_column:
    bl utils_atoi                // Llamar a subrutina propia para convertir string a entero en x10
    cbz x7, utils_after_column  // si x7==0, dato inválido/vacío, no guardar
    bl utils_save_number          // Guardar el valor entero extraído (x10) en el stack

utils_after_column:
    cmp w23, '$'                 // Verificar si atoi terminó por encontrar el EOF ('$')
    beq utils_done               // Si es fin de archivo, salir

    cmp w23, #10                 // Verificar si atoi terminó por encontrar el fin de línea (\n)
    beq utils_next_line_check    // Si fue fin de línea, saltar directamente a procesar la siguiente fila

    bl utils_skip_to_next_line   // Si había más datos en la fila, ignorarlos hasta la siguiente línea

    cmp w23, '$'                 // Comprobar nuevamente si al saltar llegamos al EOF
    beq utils_done               // Salir si terminamos
    
    b utils_next_line_check

// Decidir si continuar con la siguiente línea o detenerse porque ya llego al limitw

utils_next_line_check:
    cmp x26, x25
    bge utils_done                // ya procesamos la línea final solicitada

    add x26, x26, #1
    b utils_process_line

utils_done:
    bl utils_close_file         // Cerrar el archivo
    mov x0, sp                  // Salida: x0 = inicio de los datos almacenados en el stack
    mov x1, x28                 // Salida: x1 = límite final de los datos en memoria
    mov x2, x22                 // Salida: x2 = cantidad total de datos recolectados (variable)
    mov x3, x27                 // Salida: x3 = dirección para restaurar el stack posteriormente
    ldr x30, [x29, #8]          // Recuperar el link register original (dirección de retorno)
    ret                         // Retornar al módulo principal

utils_invalid_column:
    bl utils_close_file         // Cerrar el archivo antes de salir por error
    mov x22, #0                 // Asegurar que el contador queda en 0 (ningún dato extraído)
    mov x4,  #1                 // Estado: columna inválida
    b utils_error_return

utils_invalid_range:
    bl utils_close_file         // Cerrar el archivo antes de salir por error
    mov x22, #0                 // Asegurar que el contador queda en 0
    mov x4,  #2                 // Código de error 2: rango inválido (x24 > x25 o x24 < 1)
    b utils_error_return

utils_error_return:
    mov x0, sp                  // Salida: x0 = inicio del stack (sin datos útiles)
    mov x1, x28                 // Salida: x1 = límite superior
    mov x2, x22                 // Salida: x2 = 0 (ningún dato extraído)
    mov x3, x27                 // Salida: x3 = dirección para restaurar sp
    ldr x30, [x29, #8]          // Recuperar el link register original
    ret

// ============================================================================
// 2. ESCRITURA DE RESULTADOS A ARCHIVO
// Entrada: x0 = dirección del buffer de texto a escribir, x1 = longitud,
//          x2 = dirección del nombre del archivo de salida
// ============================================================================
utils_write_result:
    mov x19, x0                 // Salvar buffer origen en x19
    mov x20, x1                 // Salvar longitud en x20
    mov x21, x2                 // Salvar nombre de archivo en x21

    mov x0, #-100                // AT_FDCWD (directorio actual)
    mov x1, x21                  // Puntero al nombre del archivo de salida
    mov x2, #577                 // Banderas: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577
    mov x3, #0777                // Permisos de creación del archivo
    mov x8, #56                  // Syscall 56: openat
    svc #0                       // Ejecutar syscall
    mov x22, x0                  // Guardar File Descriptor devuelto en x22

    mov x0, x22                  // Param: File descriptor
    mov x1, x19                  // Param: Dirección del buffer a escribir
    mov x2, x20                  // Param: Cantidad de bytes a escribir
    mov x8, #64                  // Syscall 64: write
    svc #0                       // Ejecutar syscall

    mov x0, x22                  // Param: File descriptor a cerrar
    mov x8, #57                  // Syscall 57: close
    svc #0                       // Ejecutar syscall
    ret                          // Retornar

// ============================================================================
// 3. OPERACIONES DE ARCHIVO: ABRIR, CERRAR Y LEER POR BLOQUES DE 4K
// ============================================================================
utils_open_file:
    mov x0, #-100                // AT_FDCWD (indica que busque en el directorio actual)
    mov x1, x21                  // Puntero dinamico
    mov x2, #0                   // Bandera O_RDONLY (0 = solo lectura)
    mov x3, #0                   // Modo (sin permisos extra al solo leer)
    mov x8, #56                  // Syscall 56: openat
    svc #0                       // Interrupción de software

    cmp x0, #0                   // ¿El File Descriptor es menor a 0? (Error)
    blt utils_open_error         // Si es negativo, hubo error, saltar a rutina de fallo

    mov x19, x0                  // Guardar exitosamente el File Descriptor en x19

    // resetear estado del buffer de bloques
    ldr x9, =buf_pos
    str xzr, [x9]                // buf_pos = 0 (no hay bytes consumidos aún)
    ldr x9, =buf_len
    str xzr, [x9]                // buf_len = 0 (el buffer todavía está vacío)
    ret                          // Retornar al hilo principal

utils_read_file:
    mov x0, x19                 // Param: File Descriptor del archivo abierto
    ldr x1, =buffer             // Param: Dirección de memoria destino (bss buffer)
    mov x2, #4096               // Param: Tamaño máximo a leer en bytes
    mov x8, #63                 // Syscall 63: read
    svc #0                      // Ejecutar syscall

    cmp x0, #0                  // Comprobar bytes leídos
    blt utils_read_error        // Si es negativo, error de lectura

    mov x20, x0                 // Guardar la cantidad de bytes reales leídos en x20

    // sincronizar buf_len / buf_pos para que
    // utils_next_char pueda continuar desde donde utils_read_file dejó.
    ldr x9, =buf_len
    str x20, [x9]                // buf_len = bytes leídos
    ldr x9, =buf_pos
    str xzr, [x9]                // buf_pos = 0 (empezar desde el inicio del bloque)
    ret                          // Retornar

utils_close_file:
    mov x0, x19                  // Param: File Descriptor a cerrar
    mov x8, #57                  // Syscall 57: close
    svc #0                       // Ejecutar syscall
    ret                          // Retornar

//entrega uno por uno los caracteres del archivo, leyendo en bloques de 4k byte
utils_next_char:
    ldr x9,  =buf_pos
    ldr x13, [x9]                // x13 = buf_pos (próximo byte a entregar)
    ldr x14, =buf_len
    ldr x15, [x14]               // x15 = buf_len (bytes validos en el buffer)

    cmp x13, x15
    blt utils_nc_return_byte     // todavía quedan bytes sin entregar - usarlos

    // El buffer ya se agoto: pedir un nuevo bloque de hasta 4096 bytes.
    mov x0, x19                  
    ldr x1, =buffer              
    mov x2, #4096              
    mov x8, #63                  // Syscall 63: read
    svc #0                        
    cmp x0, #0
    blt utils_read_error         // error real de lectura - abortar el programa
    beq utils_nc_eof             // 0 bytes leídos = fin real del archivo

    str x0, [x14]                // Actualizar buf_len con los bytes recién leídos
    mov x13, #0                  // Resetear buf_pos al inicio del nuevo bloque

utils_nc_return_byte:
    ldr x9, =buffer
    ldrb w23, [x9, x13]              // w23 = buffer[buf_pos]
    add x13, x13, #1                 // avanzar la posición dentro del buffer
    ldr x9, =buf_pos
    str x13, [x9]                    // guardar buf_pos actualizado para la
                                     // próxima llamada
    ret

utils_nc_eof:
    mov w23, '$'                     // no había '$' explícito en el archivo
    ret

// ============================================================================
// 4. PARSEO DE CSV Y SALTOS EN CADENAS
// ============================================================================
utils_skip_to_next_line:
    stp x29, x30, [sp, #-16]!  
utils_stnl_loop:
    bl utils_next_char            // w23 = siguiente carácter
    cmp w23, '$'                  // Comparar con el carácter de fin de archivo
    beq utils_stnl_done           // Terminar salto si encontramos EOF
    cmp w23, #10                  // Comparar con salto de línea (\n en ASCII es 10)
    beq utils_stnl_done           // Terminar salto si encontramos nueva línea
    b utils_stnl_loop             // Iterar si es otro carácter
utils_stnl_done:
    ldp x29, x30, [sp], #16    
    ret                          

utils_skip_to_next_column:
    stp x29, x30, [sp, #-16]!  
utils_stnc_loop:
    bl utils_next_char            // w23 = siguiente carácter
    cmp w23, '$'                  // Evaluar si es fin de archivo ($)
    beq utils_stnc_done           // Detener si es EOF
    cmp w23, #10                  // Evaluar si es nueva línea (\n)
    beq utils_stnc_done           // Detener (columna vacía al final)
    cmp w23, ','                  // Evaluar si es separador de CSV (coma)
    beq utils_stnc_done           // Detener, encontramos la siguiente columna
    b utils_stnc_loop             // Continuar consumiendo caracteres de esta columna
utils_stnc_done:
    ldp x29, x30, [sp], #16    
    ret                          // Retornar de la rutina de salto

// ============================================================================
// 5. CONVERSIÓN DE DATOS ASCII <-> ENTERO
// ============================================================================

// --- utils_atoi ---
// Extrae los caracteres actuales hasta encontrar coma, salto de línea o
// fin de archivo, y los convierte a un entero que queda almacenado en x10.
utils_atoi:
    stp x29, x30, [sp, #-16]!  
    mov x10, #0                  // Inicializar acumulador numérico en 0
    mov x7,  #0                  // bandera de dígito válido (0 = ninguno leído aún)
    mov x5,  #10                 // Base 10 para multiplicaciones decimales
atoi_loop:
    bl utils_next_char            // w23 = siguiente carácter
    cmp w23, ','                  // Verificar si es delimitador (coma)
    beq atoi_done                // Finalizar conversión
    cmp w23, #10                 // Verificar si es salto de línea (\n)
    beq atoi_done                // Finalizar conversión
    cmp w23, '$'                 // Verificar si es delimitador de EOF
    beq atoi_done                // Finalizar conversión
    cmp w23, '0'                  // Verificar si es menor que '0' ASCII
    blt atoi_loop                // Ignorar caracteres basura
    cmp w23, '9'                  // Verificar si es mayor que '9' ASCII
    bgt atoi_loop                // Ignorar caracteres basura

    sub w23, w23, '0'            // Convertir de ASCII ('0'-'9') a valor entero (0-9)
    mul x10, x10, x5             // Multiplicar el acumulado por 10 (desplazamiento decimal)
    add x10, x10, x23            // Sumar el nuevo dígito al acumulado
    mov x7,  #1                  // Marcar que leímos al menos un dígito válido
    b atoi_loop                  // Procesar siguiente carácter
atoi_done:
    ldp x29, x30, [sp], #16    
    ret                          // Regresar (Valor entero final guardado en x10)

// --- utils_itoa ---
// Convierte el valor en x0 a una cadena ASCII en el buffer indicado por x1
// Entrada: x0 = número entero, x1 = dirección del buffer destino
utils_itoa:
    mov x9,  x0                  // Respaldar el número a convertir en x9
    mov x10, x1                  // Respaldar la dirección del buffer en x10
    mov x11, #10                 // Divisor constante base 10
    cbz x9, itoa_zero            // Si el número es 0, manejar caso especial

    mov x12, x9                  // Copia temporal para conteo de dígitos
    mov x13, #1                  // Iniciar contador de longitud (mínimo 1 por salto de línea)
itoa_count:
    cbz x12, itoa_end_count      // Si la copia llegó a 0, terminamos de contar
    udiv x12, x12, x11           // División entera por 10
    add x13, x13, #1             // Incrementar contador de tamaño
    b itoa_count                 // Repetir ciclo
itoa_end_count:
    add x10, x10, x13            // Desplazar puntero destino al final de la cadena calculada
    strb wzr, [x10]              // Colocar carácter nulo '\0' (wzr es registro cero)
    sub x10, x10, #1             // Retroceder 1 byte
    mov w14, #10                 // Cargar carácter de salto de línea '\n'
    strb w14, [x10]              // Colocar el '\n' antes del nulo
    sub x10, x10, #1             // Preparar puntero para el primer dígito (de derecha a izquierda)

itoa_loop:
    udiv x12, x9, x11            // x12 = num / 10
    mul x13, x12, x11            // x13 = (num / 10) * 10
    sub x13, x9, x13             // x13 = num - x13 (obtiene el residuo)
    add x13, x13, '0'            // Sumar base '0' ASCII para obtener el carácter
    strb w13, [x10]              // Guardar el byte del carácter en la memoria buffer
    sub x10, x10, #1             // Retroceder el puntero de memoria en 1
    mov x9, x12                  // num = num / 10 (actualizar para la siguiente iteración)
    cbnz x9, itoa_loop           // Si aún no es 0, continuar sacando dígitos
    ret                          // Terminar

itoa_zero:
    mov w9, '0'                  // Cargar el carácter '0'
    strb w9, [x10, #0]           // Escribir en primera posición
    mov w9, #10                  // Cargar salto de línea '\n'
    strb w9, [x10, #1]           // Escribir en segunda posición
    strb wzr, [x10, #2]          // Escribir terminador nulo '\0'
    ret                          // Terminar

// ============================================================================
// 6. ADMINISTRACIÓN DEL STACK
// ============================================================================
utils_save_number:
    sub sp, sp, #16              // Reservar 16 bytes en el stack (alineación obligatoria de ARM64)
    str x10, [sp]                // Guardar el entero extraído (x10) en el espacio reservado del stack
    add x22, x22, #1             // Aumentar en 1 el contador de números validados (x22)
    ret                          // Retornar

// ============================================================================
// 7. MANEJO Y SALIDAS DE ERRORES CON SYSCALLS
// ============================================================================
utils_open_error:
    mov x0, #1                   // Parámetro de salida STDOUT (1)
    ldr x1, =err_open            // Dirección del string de error en memoria
    mov x2, len_err_open         // Longitud de la cadena calculada dinámicamente
    mov x8, #64                  // Syscall 64: write
    svc #0                       // Escribir en terminal
    b utils_exit_error           // Abortar programa

utils_read_error:
    mov x0, #1                   // Parámetro STDOUT
    ldr x1, =err_read            // Dirección del mensaje
    mov x2, len_err_read         // Longitud
    mov x8, #64                  // Syscall 64: write
    svc #0                       // Ejecutar
    b utils_exit_error           // Abortar

utils_exit_error:
    mov x0, #1                   // Código de salida 1 (Error) para el sistema operativo
    mov x8, #93                  // Syscall 93: exit
    svc #0                       // Forzar cierre de ejecución

//atoi argumentos
//x0 = string
atoi_argv:
    mov x10, #0              // acumulador
    mov x7,  #0              // bandera de dígito válido
    mov x5,  #10             // base 10

atoi_argv_loop:
    ldrb w23, [x0], #1      // lee byte desde x0, avanza x0

    cmp w23, #0              // fin de string (\0)
    beq atoi_argv_done
    cmp w23, #10            // salto de línea \n
    beq atoi_argv_done
    cmp w23, '0'
    blt atoi_argv_loop      // ignorar no-dígitos
    cmp w23, '9'
    bgt atoi_argv_loop

    sub w23, w23, '0'       // ASCII - número
    mul x10, x10, x5        // acumulado × 10
    add x10, x10, x23       // + dígito
    mov x7, #1              // marcamos dígito válido
    b atoi_argv_loop

atoi_argv_done:
    ret