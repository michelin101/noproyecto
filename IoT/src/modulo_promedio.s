.global promedio_reciente
/*  REGISTROS
        x0 = puntero al buffer del sensor (ej. temp_buffer)

    -----------------------------------------------------
    promedio_reciente
        Retorno: x0 = PROMEDIO = suma(buffer) / N (división entera)
        Requiere: N >= 1

*/

.text
promedio_reciente:
    ldr x1, =cantidad
    ldr x1, [x1]
    mov x2, x0                  //Guardar el puntero al buffer en x2
    mov x3, #0                  //Acumulador de la suma
    mov x4, #0                  //Contador

sumatoria:
    cmp x4, x1                  //i == N?
    beq fin_sumatoria           //Si i == N, termina la sumatoria

    ldr x9, [x2]
    add x3, x3, x9              //suma += buffer[i]
    add x2, x2, #8
    add x4, x4, #1              //i++
    b sumatoria

fin_sumatoria:
    udiv x0, x3, x1             //x0 = Promedio

    ret
