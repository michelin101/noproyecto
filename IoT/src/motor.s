.global _start

.data
err_input:
    .ascii "ERROR\n"
    len_err_input = . - err_input

.bss
buffer:
    .skip 64                // linea de entrada               

.text

_start:
    mov x28, #10             // constante base 10 para atoi

main_loop:
    mov x0, #0              // descriptor 0 = stdin
    ldr x1, =buffer
    mov x2, #64             // tama;o
    mov x8, #63             // syscall read
    svc #0

    cmp x0, #0
    beq exit_ok            // 0 bytes (EOF)
    blt exit_error         // negativo, sale con error

    ldr x21, =buffer       // x21 inicio de la linea
    ldrb w0, [x21]
    cmp w0, '$'            // cerrar cuando el python envie $
    beq exit_ok

    bl atoi_csv
    cbz x7, print_error    // x7 == 0, no se leyo digito, error
    mov x19, x10           // TEMP

    bl atoi_csv
    cbz x7, print_error
    mov x20, x10           // HUM_AIRE

    bl atoi_csv
    cbz x7, print_error
    mov x22, x10           // SOIL1

    bl atoi_csv
    cbz x7, print_error
    mov x24, x10           // SOIL2

    bl atoi_csv
    cbz x7, print_error
    mov x25, x10           // LUZ

    bl atoi_csv
    cbz x7, print_error
    mov x26, x10           // GAS

    bl atoi_csv
    cbz x7, print_error
    mov x27, x10           // MODO

    //los pase a estos registros porque ya los habia quemado en el historial
    mov x0, x19
    mov x1, x20
    mov x2, x22
    mov x3, x24
    mov x4, x25
    mov x5, x26
    bl insertar_lectura

    bl tomar_decision
    
    b main_loop

print_error:
    mov x0, #1
    ldr x1, =err_input
    mov x2, #len_err_input
    mov x8, #64            // write
    svc #0
    b main_loop

exit_ok:
    mov x0, #0
    mov x8, #93            // exit
    svc #0

exit_error:
    mov x0, #1
    mov x8, #93            // exit
    svc #0