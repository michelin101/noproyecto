.global tomar_decision

.data
act_alarm:  .ascii "ACTION=ALARM_ON;TARGET=GAS;RISK=CRITICAL;REASON=GAS_HIGH;VALUE="
    len_act_alarm = . - act_alarm
act_alarm_off: .ascii "ACTION=ALARM_OFF;TARGET=GAS;RISK=LOW;REASON=GAS_NORMAL;VALUE="
    len_act_alarm_off = . - act_alarm_off
act_riego1: .ascii "ACTION=RIEGO_1_ON;TARGET=SOIL1;RISK=HIGH;REASON=SOIL_LOW;VALUE="
    len_act_riego1 = . - act_riego1
act_riego1_off: .ascii "ACTION=RIEGO_1_OFF;TARGET=SOIL1;RISK=LOW;REASON=SOIL_OK;VALUE="
    len_act_riego1_off = . - act_riego1_off
act_riego2: .ascii "ACTION=RIEGO_2_ON;TARGET=SOIL2;RISK=HIGH;REASON=SOIL_LOW;VALUE="
    len_act_riego2 = . - act_riego2
act_riego2_off: .ascii "ACTION=RIEGO_2_OFF;TARGET=SOIL2;RISK=LOW;REASON=SOIL_OK;VALUE="
    len_act_riego2_off = . - act_riego2_off
act_light:  .ascii "ACTION=LIGHT_ON;TARGET=LUZ;RISK=MEDIUM;REASON=LIGHT_LOW;VALUE="
    len_act_light = . - act_light
act_light_off: .ascii "ACTION=LIGHT_OFF;TARGET=LUZ;RISK=LOW;REASON=LIGHT_OK;VALUE="
    len_act_light_off = . - act_light_off
act_fan:    .ascii "ACTION=FAN_ON;TARGET=TEMP;RISK=MEDIUM;REASON=TEMP_HIGH;VALUE="
    len_act_fan = . - act_fan
act_fan_off: .ascii "ACTION=FAN_OFF;TARGET=TEMP;RISK=LOW;REASON=TEMP_OK;VALUE="
    len_act_fan_off = . - act_fan_off
act_green:  .ascii "ACTION=LED_GREEN;TARGET=NONE;RISK=LOW;REASON=ALL_OK;VALUE="
    len_act_green = . - act_green
act_yellow: .ascii "ACTION=LED_YELLOW;TARGET=NONE;RISK=MEDIUM;REASON=WARNING;VALUE="
    len_act_yellow = . - act_yellow
act_red:    .ascii "ACTION=LED_RED;TARGET=NONE;RISK=CRITICAL;REASON=CRITICAL_CONDITION;VALUE="
    len_act_red = . - act_red
act_no_action: .ascii "ACTION=NO_ACTION;TARGET=NONE;RISK=LOW;REASON=MANUAL_MODE;VALUE="
    len_act_no_action = . - act_no_action
indicador:    .ascii ";INDICATOR="
    len_indicador = . - indicador
status:     .ascii ";STATUS=OK\n"
    len_status = . - status
menos:      .ascii "-"

// x21 guarda la prioridad de led acumulada durante el pipeline
// 0 = nada aun, 1 = yellow, 2 = red
// al final se emite solo uno segun ese valor

.bss
num_buffer:
    .skip 32  

.text
tomar_decision:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!   // guardamos x21 para la prioridad led
    mov x29, sp

    // si modo manual (x6 == 1) entonces NO_ACTION directo
    cmp x6, #1
    beq set_no_action

    mov x21, #0                  // iniciar prioridad led en 0

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

    // gas normal entonces apagar alarma
    mov x22, x20             // INDICATOR = amplitud reciente de gas (x19 sigue siendo el promedio)
    ldr x1, =act_alarm_off
    mov x2, #len_act_alarm_off
    bl  emitir_accion

.decision_suelo1:
    // suelo 1
    //promedio bajo Y tendencia descendente
        //tendencia descendente
    ldr x0, =soil1_buffer
    bl tendencia_acumulada                 //retorna la tendencia en x0
    mov x22, x0                             // INDICATOR = tendencia acumulada suelo1
    cmp x0, #0
    bge .suelo1_normal

    //Y
        //promedio bajo
    ldr x0, =soil1_buffer
    bl  promedio_reciente
    ldr x1, =SOIL_BAJO
    ldr x1, [x1]
    cmp x0, x1
    blt set_riego1

.suelo1_normal:
    // suelo 1 normal entonces apagar riego
    ldr x0, =soil1_buffer
    bl  promedio_reciente
    mov x19, x0
    ldr x1, =act_riego1_off
    mov x2, #len_act_riego1_off
    bl  emitir_accion

.decision_suelo2:
    // suelo 2
    //promedio bajo Y tendencia descendente
        //tendencia descendente
    ldr x0, =soil2_buffer
    bl tendencia_acumulada                 //retorna la tendencia en x0
    mov x22, x0                             // INDICATOR = tendencia acumulada suelo2
    cmp x0, #0
    bge .suelo2_normal

    //Y
        //promedio bajo
    ldr x0, =soil2_buffer
    bl  promedio_reciente
    ldr x1, =SOIL_BAJO
    ldr x1, [x1]
    cmp x0, x1
    blt set_riego2

.suelo2_normal:
    // suelo 2 normal entonces apagar riego
    ldr x0, =soil2_buffer
    bl  promedio_reciente
    mov x19, x0
    ldr x1, =act_riego2_off
    mov x2, #len_act_riego2_off
    bl  emitir_accion

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

    // luz normal entonces apagar luz
    mov x22, x0
    mov x19, x0
    ldr x1, =act_light_off
    mov x2, #len_act_light_off
    bl  emitir_accion

.decision_temperatura:
    // temperatura alta
    //promedio temperatura alto Y tendencia ascendente
        //tendencia ascendente
    ldr x0, =temp_buffer
    bl tendencia_acumulada
    mov x22, x0                            // INDICATOR = tendencia acumulada temperatura
    cmp x0, #0
    ble .temperatura_normal

    //Y
        //promedio temperatura alto
    ldr x0, =temp_buffer
    bl  promedio_reciente
    ldr x1, =TEMP_ALTA
    ldr x1, [x1]
    cmp x0, x1
    bgt set_fan

.temperatura_normal:
    // temperatura normal entonces apagar ventilador
    ldr x0, =temp_buffer
    bl  promedio_reciente
    mov x19, x0
    ldr x1, =act_fan_off
    mov x2, #len_act_fan_off
    bl  emitir_accion

.sin_condicion:
    // fin del pipeline, emitir el unico led segun prioridad acumulada en x21
    mov x19, #0
    mov x22, #0
    cmp x21, #2
    beq .emitir_led_red
    cmp x21, #1
    beq .emitir_led_yellow
    // x21 == 0, ninguna condicion activa entonces verde
    ldr x1, =act_green
    mov x2, #len_act_green
    b   emitir

.emitir_led_yellow:
    ldr x1, =act_yellow
    mov x2, #len_act_yellow
    b   emitir

.emitir_led_red:
    ldr x1, =act_red
    mov x2, #len_act_red
    b   emitir


//aqui solo es para cargar la cadena para el mensaje de la accion
set_alarm:
    mov x22, x20                    // INDICATOR = amplitud gas (x19 sigue siendo el promedio)
    ldr x1, =act_alarm
    mov x2, #len_act_alarm
    bl  emitir_accion
    mov x21, #2                     // red es la prioridad mas alta, siempre gana
    b   .decision_suelo1

set_riego1:
    mov x19, x0
    ldr x1, =act_riego1
    mov x2, #len_act_riego1
    bl  emitir_accion
    cmp x21, #2                     // solo subimos a yellow si no hay red ya
    bge .skip_yellow_r1
    mov x21, #1
.skip_yellow_r1:
    b   .decision_suelo2

set_riego2:
    mov x19, x0
    ldr x1, =act_riego2
    mov x2, #len_act_riego2
    bl  emitir_accion
    cmp x21, #2
    bge .skip_yellow_r2
    mov x21, #1
.skip_yellow_r2:
    b   .decision_luz

set_light:
    mov x19, x0
    mov x22, x0
    ldr x1, =act_light
    mov x2, #len_act_light
    bl  emitir_accion
    cmp x21, #2
    bge .skip_yellow_lt
    mov x21, #1
.skip_yellow_lt:
    b   .decision_temperatura

set_fan:
    mov x19, x0
    ldr x1, =act_fan
    mov x2, #len_act_fan
    bl  emitir_accion
    cmp x21, #2
    bge .skip_yellow_fn
    mov x21, #1
.skip_yellow_fn:
    b   .sin_condicion

set_no_action:
    mov x19, #0
    mov x22, #0
    ldr x1, =act_no_action
    mov x2, #len_act_no_action
    b   emitir

// emitir una acción sin retornar al llamador (para encadenamiento con bl)
// entrada: x1 = cadena, x2 = longitud, x19 = value, x22 = indicator
emitir_accion:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

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

    mov x0, x22
    bl  print_sint

    mov x0, #1
    ldr x1, =status
    mov x2, #len_status
    mov x8, #64
    svc #0

    ldp x29, x30, [sp], #16
    ret

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

    mov x0, x22
    bl  print_sint

    mov x0, #1
    ldr x1, =status
    mov x2, #len_status
    mov x8, #64
    svc #0

    ldp x21, x22, [sp], #16    // restaurar x21 antes de salir
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
