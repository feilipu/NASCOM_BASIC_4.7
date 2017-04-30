;==================================================================================
; Contents of this file are copyright Phillip Stevens
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; Initialisation routines to suit Z8S180 CPU, with internal USART.
;
; Internal USART interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering.
;
; https://github.com/feilipu/
;
; https://feilipu.me/
;

;==============================================================================
;
; INCLUDES SECTION
;

#include    "d:/yaz180.h"

;==============================================================================
;
; DEFINES SECTION
;

;   from Nascom Basic Symbol Tables .ORIG $0390
DEINT       .EQU    $0C47   ; Function DEINT to get USR(x) into DE registers
ABPASS      .EQU    $13BD   ; Function ABPASS to put output into AB register

USRSTART    .EQU    $3000

APU_TOS     .EQU    $36B0           ; CPU TOS Operand - 14000
APU_NOS     .EQU    APU_TOS+$04     ; CPU NOS Operand - 14004

;==================================================================================
;
; CODE SECTION
;

        .org USRSTART   ; start from 'X' jump, Basic prompt

                        ; Am9511A I/O is from $C000 to $C001

                        ; assume the operand byte code in function call
                        ; return 16 bit result (if relevant)
                        ; NOS, TOS, poked to relevant addresses
                        ; Result peeked from relevant address

        call DEINT      ; get the USR(x) argument in de

        XOR A           ; Set internal clock = crystal x 1 = 18.432MHz
                        ; That makes the PHI 9.216MHz
        OUT0 (CMR),A    ; CPU Clock Multiplier Reg (CMR)

        call APU_CHK_RDY ; check ready first

        ld a, e         ; check the operand, what are we doing?

        cp $00
        ret z           ; nope, nothing

        cp $0f          ; floating point 32 bit derived 
        jr c, APU_DO_D

        cp $14          ; floating point 32 bit
        jr c, APU_DO_4

        cp $2c          ; fixed point 32 bit
        jr z, APU_DO_4
        cp $2d
        jr z, APU_DO_4
        cp $2e
        jr z, APU_DO_4
        cp $2f
        jr z, APU_DO_4
        cp $3c
        jr z, APU_DO_4

        cp $6c          ; fixed point 16 bit
        jr z, APU_DO_2
        cp $6d
        jr z, APU_DO_2
        cp $6e
        jr z, APU_DO_2
        cp $6f
        jr z, APU_DO_2
        cp $7c
        jr z, APU_DO_2

        call APU_DO_OP  ; otherwise its data manipulation
        call APU_CHK_RDY ; check ready

APU_AB_RES:
                        ; Set internal clock = crystal x 2 = 36.864MHz
        LD A,CMR_X2     ; Set Hi-Speed flag
        OUT0 (CMR),A    ; CPU Clock Multiplier Reg (CMR)

        ld hl, APU_TOS  ; prep single result
        ld a, (hl)      ; read the LSB
        ld b, a         ; put it in b
        inc hl
        ld a, (hl)      ; read the MSB      
        jp ABPASS       ; return the 16 bit value to USR(x)


;------------------------------------------------------------------------------
;

APU_CHK_RDY:
        ld bc, APUCNTL  ; the address of the APU status port in bc
        in a, (c)       ; read the APU
        and $80         ; Busy?
        jr nz, APU_CHK_RDY
        ret

APU_DO_OP:
        ld bc, APUCNTL  ; the address of the APU control port in bc
        ld a, e         ; get the operand
        out (c),a       ; do the operation
        ret

APU_DO_D:
        ld bc, APUDATA+$300 ; the address of the APU data port in bc
        ld hl, APU_TOS      ; prep single operand
        call APU_PUSH_4
        call APU_DO_OP
        call APU_CHK_RDY
        ld bc, APUDATA+$300 ; the address of the APU data port in bc
        ld hl, APU_TOS+3    ; prep single result
        call APU_POP_4
        jr APU_AB_RES

APU_DO_4:
        ld bc, APUDATA+$700 ; the address of the APU data port in bc
        ld hl, APU_NOS      ; prep first operand
        call APU_PUSH_4
        ld hl, APU_TOS      ; prep second operand
        call APU_PUSH_4
        call APU_DO_OP
        call APU_CHK_RDY
        ld bc, APUDATA+$300 ; the address of the APU data port in bc
        ld hl, APU_TOS+3    ; prep single result
        call APU_POP_4
        jr APU_AB_RES

APU_DO_2:
        ld bc, APUDATA+$300 ; the address of the APU data port in bc
        ld hl, APU_NOS      ; prep first operand
        call APU_PUSH_2
        ld hl, APU_TOS      ; prep second operand
        call APU_PUSH_2
        call APU_DO_OP
        call APU_CHK_RDY
        ld bc, APUDATA+$100 ; the address of the APU data port in bc
        ld hl, APU_TOS+1    ; prep single result
        call APU_POP_2
        jr APU_AB_RES

APU_PUSH_4:                 ; Base Address in HL, Data port in BC
        outi
        outi
;        ld a, (hl)         ; get the byte
;        out (c), a         ; push to APU
;        inc hl
;        ld a, (hl)         ; get the byte
;        out (c), a         ; push to APU
;        inc hl
APU_PUSH_2:                 ; Base Address in HL, Data port in BC
        outi
        outi
;        ld a, (hl)         ; get the byte
;        out (c), a         ; push to APU
;        inc hl
;        ld a, (hl)         ; get the byte
;        out (c), a         ; push to APU
        ret

APU_POP_4:                  ; Base Address +3 in HL, Data port in BC
        ind
        ind
;        in a, (c)          ; pop the APU
;        ld (hl), a         ; store the byte
;        dec hl
;        in a, (c)          ; pop the APU
;        ld (hl), a         ; store the byte
;        dec hl
APU_POP_2:                  ; Base Address +1 in HL, Data port in BC
        ind
        ind
;        in a, (c)          ; pop the APU
;        ld (hl), a         ; store the byte
;        dec hl
;        in a, (c)          ; pop the APU
;        ld (hl), a         ; store the byte
        ret


        .end
