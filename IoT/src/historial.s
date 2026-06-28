.global insertar_lectura

.global temp_buffer
.global hum_buffer
.global soil1_buffer
.global soil2_buffer
.global luz_buffer
.global gas_buffer
.global posicion
.global cantidad

.data
temp_buffer:    .quad 0, 0, 0, 0, 0
hum_buffer:     .quad 0, 0, 0, 0, 0
soil1_buffer:   .quad 0, 0, 0, 0, 0
soil2_buffer:   .quad 0, 0, 0, 0, 0
luz_buffer:     .quad 0, 0, 0, 0, 0
gas_buffer:     .quad 0, 0, 0, 0, 0
posicion:       .quad 0     
cantidad:       .quad 0     

.text
insertar_lectura:
    ldr  x10, =posicion
    ldr  x11, [x10]             // x11 = posicion actual (0..4)
    lsl  x12, x11, #3           // desplazamiento en bytes es al final use el lsl xd (el 3 es la potencia)
    ldr  x13, =temp_buffer
    str  x0, [x13, x12]         // temp_buffer[posicion] = TEMP

    ldr  x13, =hum_buffer
    str  x1, [x13, x12]         // hum_buffer[posicion] = HUM_AIRE

    ldr  x13, =soil1_buffer
    str  x2, [x13, x12]         // soil1_buffer[posicion] = SOIL1

    ldr  x13, =soil2_buffer
    str  x3, [x13, x12]         // soil2_buffer[posicion] = SOIL2

    ldr  x13, =luz_buffer
    str  x4, [x13, x12]         // luz_buffer[posicion] = LUZ

    ldr  x13, =gas_buffer
    str  x5, [x13, x12]         // gas_buffer[posicion] = GAS

    add  x11, x11, #1
    cmp  x11, #5
    b.lt guardar_posicion       // si no llego a 5, se queda como esta
    mov  x11, #0                // si llego a 5, da la vuelta a 0
guardar_posicion:
    str  x11, [x10]             // guardando la nueva posicion
    ldr  x10, =cantidad
    ldr  x11, [x10]
    cmp  x11, #5
    b.ge fin_insertar           // buffer esta lleno
    add  x11, x11, #1
    str  x11, [x10]
fin_insertar:
    ret