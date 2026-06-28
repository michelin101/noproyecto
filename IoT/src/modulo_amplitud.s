.global amplitud_reciente
/*  REGISTROS:
        x0 = puntero al buffer del sensor (ej. temp_buffer)

    -----------------------------------------------------
    amplitud_reciente
        Retorno: x0 = AMPLITUD = MAXIMO - MINIMO
        Requiere: N >= 1

*/

.text
amplitud_reciente:
    ldr x1, =cantidad
    ldr x1, [x1]
    mov x2, x0                  //Puntero actual del buffer
    ldr x3, [x2]                //buscador de Máx
    ldr x4, [x2]                //buscador de mín
    mov x5, #0                  //contador i

_buscador:
    cmp x5, x1                  //i == N?
    beq fin_amplitud

    ldr x9, [x2]
    cmp x9, x3
    bgt actualizar_max

    cmp x9, x4
    blt actualizar_min

    add x2, x2, #8
    add x5, x5, #1
    b _buscador

fin_amplitud:
    sub x0, x3, x4              //x0 = Amplitud

    ret

actualizar_max:
    mov x3, x9

    b _buscador

actualizar_min:
    mov x4, x9
    b _buscador
