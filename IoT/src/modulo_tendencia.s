.global tendencia_acumulada
/*  REGISTROS
        x0 = puntero al buffer del sensor (ej. temp_buffer)

    -----------------------------------------------------
    tendencia_acumulada
        Retorno: 
                x0 = DIF_ACUM = suma(X_i - X_(i-1)), con signo
                x0 > 0 → tendencia ascendente
                x0 < 0 → tendencia descendente
                x0 = 0 → tendencia estable
        Requiere: N >= 2 (con N=1 no existe ninguna diferencia que calcular)

*/

.text
tendencia_acumulada:
    mov x6, x0                  //puntero base

    ldr x1, =cantidad
    ldr x1, [x1]                //x1 = N
    ldr x2, =posicion
    ldr x2, [x2]                //x2 = índice del dato más viejo
    
    cmp x1, #2
    blt tendencia_cero

    mov x3, #0                  //DIF_ACUM(Acumulador de la tendencia)
    mov x4, #0                  //Vuelta i (0 hasta N-2)
    sub x5, x1, #1

calcular_tendencia:
    //cálculo de índice cronológico actual: crono_actual = (posicion + i) % 5
    add x7, x2, x4
    udiv x9, x7, x1
    mul x9, x9, x1
    sub x7, x7, x9              //x7 = indice más viejo

    //cálculo de índice cronológico actual: crono_sig = (posición + i + 1) % 5
    add x10, x2, x4
    add x10, x10, #1
    udiv x9, x10, x1
    mul x9, x9, x1
    sub x10, x10, x9            //x10 = indicie siguiente más viejo

    lsl x11, x7, #3
    add x11, x11, x6
    ldr x11, [x11]              //x_(i-1)

    lsl x12, x10, #3
    add x12, x12, x6
    ldr x12, [x12]              //x_i

    sub x13, x12, x11
    add x3, x3, x13

    add x4, x4, #1
    cmp x4, x5
    blt calcular_tendencia

    mov x0, x3                  //x0 = DIF_ACUM
    b fin_tendencia

tendencia_cero:
    mov x0, #0

fin_tendencia:
    ret
