.global _start
.global reg_lin_spl

.data
str_modulo:         .asciz "CALC=LINEAR_REGRESION\n"
str_columna:        .asciz "COLUMN="
str_f_inicio:       .asciz "WINDOW_START="
str_f_final:        .asciz "WINDOW_ENDE="
str_contados:       .asciz "COUNT="
str_pendiente:      .asciz "SLOPE_X100="
str_tendencia:      .asciz "TREND="
str_status:         .asciz "STATUS=OK\n"
str_descendente:    .asciz "DESCENDINDG\n"
str_ascendente:     .asciz "ASCENDING\n"
str_estable:        .asciz "STABLE\n"
out_filename:       .asciz "resultado_regresion.txt"

.bss
buffer_var: .skip 256 //jalado tambien del modulo 2, le de las varianzas

.text
_start:
    mov x19, sp

    //leyendo los argumentos
    ldr x0, [x19, #16]
    ldrb w11, [x0]          //todo esto fue solo la columna xd
    sub x11, x11, #48

    ldr x0, [x19, #24]
    bl atoi_argv            //este si no estoy mal es el inicio de las filas
    mov x24, x10

    ldr x0, [x19, #32]
    bl atoi_argv            //y este el final
    mov x25, x10

    bl utils_read_column_to_stack
    mov x20, x0             //inicio de los datos
    mov x21, x1             //tope 
    mov x22, x2             //cantidad de datos que se leyeron
    mov x23, x3             //posicion de retorno
    mov x26, x4             //estatus
    mov x27, x11            //ya ni me acuerdo en que use esto//revisar mas tarde

    bl reg_lin_spl
    mov x28, x0

    bl guardar_txt

    mov sp, x23             // regresamos al sp original
    mov x0, #0              
    mov x8, #93             //saliendo 
    svc #0

reg_lin_spl:
    mov x0, #0              //este lo voy a usar como el contador de los subindices y las x
    mov x1, #0              //este el de (x_i * y_i)
    mov x2, #0              //este el de (x_i)
    mov x3, #0              //este el de (y_i)
    mov x4, #0              //este el de (x_i * x_i)
    mov x5, x21             //copia el inicio de los datos
    mov x6, x22             //copia de cantidad N

loop:
    ldr x9, [x5, #-16]!
    mul x7, x0, x9          //mi (x_i * y_i)
    add x1, x1, x7          //el sum(x_i * y_i)
    add x2, x2, x0          //segun yo aqui estoy haciendo mi sumador de las x
    add x3, x3, x9          //lo mismo pero con las y
    mul x10, x0, x0         //este es el (x_i) * (x_i)
    add x4, x4, x10         //el sum((x_i) * (x_i))
    add x0, x0, #1          //aumento el contador del subindice y las x
    cmp x0, x6              //comparando para el n-1
    blt loop                //retorno al loop por si es cierto el n-1

m_x100:
    mul x11, x6, x1         //el N(sum(x_i * y_i))
    mul x12, x2, x3         //(suma(X_i) * suma(Y_i))
    sub x13, x11, x12       //pos el numerador completo
    mul x14, x6, x4         //el N(sum((x_i) * (x_i)))
    mul x15, x2, x2         //esta cosa (suma(X_i) * suma(X_i))
    sub x16, x14, x15       //denominador completo
    mov x8, #100
    mul x17, x13, x8        //numerador * 100
    sdiv x18, x17, x16      //(numerador * 100)/ denominador
    mov x0, x18
    ret 
//todo esto lo jale de mi modulo2 original xd, agregando el manejo del negativo
guardar_txt:
    stp x29, x30, [sp, #-16]!
    ldr x1, =buffer_var          //x1 = posicion de escritura

    ldr x3, =str_modulo          //"CALC=LINEAR_REGRESSION\n"
    bl copiar_str

    ldr x3, =str_columna         //"COLUMN="
    bl copiar_str
    mov x0, x27                  //numero de columna
    bl escribir_num

    ldr x3, =str_f_inicio        //"WINDOW_START="
    bl copiar_str
    mov x0, x24                 //la linea de inicio
    bl escribir_num

    ldr x3, =str_f_final         //"WINDOW_END="
    bl copiar_str
    mov x0, x25                 //linea final
    bl escribir_num

    ldr x3, =str_contados        //"COUNT="
    bl copiar_str
    mov x0, x22                 //cantidad de datos contados
    bl escribir_num

    ldr x3, =str_pendiente       //"SLOPE_X100="
    bl copiar_str
    mov x0, x28                  //puede ser negativo
    bl escribir_num

    ldr x3, =str_tendencia       //"TREND="
    bl copiar_str
    cmp x28, #0
    bgt trend_asc
    blt trend_desc
    ldr x3, =str_estable
    b trend_emit

trend_asc:
    ldr x3, =str_ascendente         //cuando la tendencia sea positiva pos vengo aqui
    b trend_emit
trend_desc:
    ldr x3, =str_descendente        //lo mismo pero negativa
trend_emit:
    bl copiar_str

    ldr x3, =str_status          //"STATUS=OK\n"
    bl copiar_str

    ldr x0, =buffer_var          //inicio del buffer
    sub x1, x1, x0               //longitud = posicion actual - inicio
    ldr x2, =out_filename
    bl utils_write_result

    ldp x29, x30, [sp], #16
    ret
    
copiar_str:
copiar_loop:
    ldrb w4, [x3], #1
    cbz w4, copiar_fin
    strb w4, [x1], #1
    b copiar_loop
copiar_fin:
    ret

escribir_num:
    stp x29, x30, [sp, #-16]!
    cmp x0, #0
    bge num_pos
    mov w4, '-'
    strb w4, [x1], #1            //signo negativo al buffer
    neg x0, x0
num_pos:
    bl utils_itoa
avanzar:
    ldrb w2, [x1], #1
    cbnz w2, avanzar
    sub x1, x1, #1
    ldp x29, x30, [sp], #16
    ret
