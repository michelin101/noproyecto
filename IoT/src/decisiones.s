.global tomar_decision

.data
act_alarm:  .ascii "ACTION=ALARM_ON;TARGET=GAS;RISK=CRITICAL;REASON=GAS_HIGH;VALUE="
    len_act_alarm = . - act_alarm
act_riego1: .ascii "ACTION=RIEGO_1_ON;TARGET=SOIL1;RISK=HIGH;REASON=SOIL_LOW;VALUE="
    len_act_riego1 = . - act_riego1
act_riego2: .ascii "ACTION=RIEGO_2_ON;TARGET=SOIL2;RISK=HIGH;REASON=SOIL_LOW;VALUE="
    len_act_riego2 = . - act_riego2
act_light:  .ascii "ACTION=LIGHT_ON;TARGET=LUZ;RISK=MEDIUM;REASON=LIGHT_LOW;VALUE="
    len_act_light = . - act_light
act_fan:    .ascii "ACTION=FAN_ON;TARGET=TEMP;RISK=MEDIUM;REASON=TEMP_HIGH;VALUE="
    len_act_fan = . - act_fan
act_green:  .ascii "ACTION=LED_GREEN;TARGET=NONE;RISK=LOW;REASON=ALL_OK;VALUE="
    len_act_green = . - act_green
indicador:    .ascii ";INDICATOR="
    len_indicador = . - indicador
status:     .ascii ";STATUS=OK\n"
    len_status = . - status
menos:      .ascii "-"

.bss
num_buffer:
    .skip 32  

.text
tomar_decision:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x29, sp

    // Maoyr prioridad gas alto
    ldr x0, =gas_buffer
    bl  promedio_reciente
    mov x19, x0                     //x19 = promedio_reciente de gas

    ldr x0, =gas_buffer
    bl amplitud_reciente
    mov x20, x0                     //x20 = amplitud_reciente de gas

    //Promedio alto O amplitud alta
        //Promedio alto
    ldr x1, =GAS_ALTO
    ldr x1, [x1]                    //pos al final esta cosa si funciono
    cmp x19, x1
    bge set_alarm
    //O

        //Amplitud  alta
    ldr x1, =GAS_AMP_ALTA
    ldr x1, [x1]
    cmp x20, x1
    bge set_alarm

.decision_suelo1:
    // suelo 1
    //promedio bajo Y tendencia descendente
        //tendencia descendente
    ldr x0, =soil1_buffer
    bl tendencia_acumulada                 //retorna la tendencia en x0
    cmp x0, #0
    bge .decision_suelo2

    //Y
        //promedio bajo
    ldr x0, =soil1_buffer
    bl  promedio_reciente
    ldr x1, =SOIL_BAJO
    ldr x1, [x1]
    cmp x0, x1
    blt set_riego1

.decision_suelo2:
    // suelo 2
    //promedio bajo Y tendencia descendente
        //tendencia descendente
    ldr x0, =soil2_buffer
    bl tendencia_acumulada                 //retorna la tendencia en x0
    cmp x0, #0
    bge .decision_luz

    //Y
        //promedio bajo
    ldr x0, =soil2_buffer
    bl  promedio_reciente
    ldr x1, =SOIL_BAJO
    ldr x1, [x1]
    cmp x0, x1
    blt set_riego2

.decision_luz:
    // luz baja
    //promedio bajo (con permiso del aux ;) )
        //promedio bajo
    ldr x0, =luz_buffer
    bl  promedio_reciente
    ldr x1, =LUZ_BAJA
    ldr x1, [x1]
    cmp x0, x1
    blt set_light

.decision_temperatura:
    // temperatura alta
    //promedio temperatura alto Y tendencia ascendente
        //tendencia ascendente
    ldr x0, =temp_buffer
    bl tendencia_acumulada
    cmp x0, #0
    ble .sin_condicion

    //Y
        //promedio temperatura alto
    ldr x0, =temp_buffer
    bl  promedio_reciente
    ldr x1, =TEMP_ALTA
    ldr x1, [x1]
    cmp x0, x1
    bgt set_fan

.sin_condicion:
    // sin condicion critica
    mov x19, #0
    ldr x1, =act_green
    mov x2, #len_act_green
    b   emitir


//aqui solo es para cargar la cadena para el mensaje de la accion// todavia le tengo que agregar acciones
set_alarm:
    mov x19, x0
    ldr x1, =act_alarm
    mov x2, #len_act_alarm
    b   emitir
set_riego1:
    mov x19, x0
    ldr x1, =act_riego1
    mov x2, #len_act_riego1
    b   emitir
set_riego2:
    mov x19, x0
    ldr x1, =act_riego2
    mov x2, #len_act_riego2
    b   emitir
set_light:
    mov x19, x0
    ldr x1, =act_light
    mov x2, #len_act_light
    b   emitir
set_fan:
    mov x19, x0
    ldr x1, =act_fan
    mov x2, #len_act_fan
    b   emitir

//aqui basicamente ya se maneja el stdout 
emitir:
    mov x0, #1           
    mov x8, #64          
    svc #0

    mov x0, x19
    bl  print_sint

    mov x0, #1
    ldr x1, =indicador
    mov x2, #len_indicador
    mov x8, #64
    svc #0

    mov x0, x19
    bl  print_sint

    mov x0, #1
    ldr x1, =status
    mov x2, #len_status
    mov x8, #64
    svc #0

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

//esta es solo para agregar el - por si queda negativo alguno de los resultados, creo que solo puede ser la tendencia, no he revisado todavia
print_sint:
    stp x29, x30, [sp, #-16]!   
    cmp x0, #0
    bge pi_pos
    mov x9, x0
    mov x0, #1
    ldr x1, =menos
    mov x2, #1
    mov x8, #64
    svc #0
    neg x0, x9 
pi_pos:
    bl  print_uint
    ldp x29, x30, [sp], #16
    ret

//esto solo lo pase para aca
print_uint:
    ldr x1, =num_buffer
    add x1, x1, #31
    mov w2, #0
    strb w2, [x1]
    mov x3, #10
    mov x4, #0
    cmp x0, #0
    bne convert_loop
    sub x1, x1, #1
    mov w2, '0'
    strb w2, [x1]
    mov x4, #1
    b write_number
convert_loop:
    udiv x9, x0, x3
    msub x6, x9, x3, x0
    add  x6, x6, '0'
    sub  x1, x1, #1
    strb w6, [x1]
    add  x4, x4, #1
    mov  x0, x9
    cbnz x0, convert_loop
write_number:
    mov x0, #1
    mov x2, x4
    mov x8, #64
    svc #0
    ret
