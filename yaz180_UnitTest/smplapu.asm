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

INT0_FPU    .EQU    $3800   ; start of the FPU Interrupt 1 asm code (RAM)

;   Top of BASIC line input buffer (CURPOS WRKSPC+0ABH)
;   so it is "free ram" when BASIC resets
;   set BASIC Work space WRKSPC $8000, in CA1 RAM

WRKSPC      .EQU     RAMSTART_CA1

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


;        ld hl, INStr
;        call PRINT
;        ld hl, NOSStr
;        call PRINT

;        ld bc, APUDATA  ; the address of the APU data port in bc
;        ld hl, APU_NOS  ; prep first operand
;        call APU_PUSH_2

;        call APU_CHK_RDY ; check ready again

;        ld hl, INStr
;        call PRINT
;        ld hl, TOSStr
;        call PRINT

        ld bc, APUDATA  ; the address of the APU data port in bc
        ld hl, APU_TOS  ; prep second operand
        call APU_PUSH_4
        
;        ld hl, OUTStr
;        call PRINT
;        ld hl, TOSStr
;        call PRINT

        ld bc, APUDATA   ; the address of the APU data port in bc
        ld hl, APU_TOS+3 ; recover second operand
        call APU_POP_4
        
                        ; Set internal clock = crystal x 2 = 36.864MHz
        LD A,CMR_X2     ; Set Hi-Speed flag
        OUT0 (CMR),A    ; CPU Clock Multiplier Reg (CMR)

;        call APU_CHK_RDY ; check ready again

;        ld hl, OUTStr
;        call PRINT
;        ld hl, NOSStr
;        call PRINT

;        ld bc, APUDATA+$100 ; the address of the APU data port in bc
;        ld hl, APU_NOS+1    ; recover first operand
;        call APU_POP_2

APU_AB_RES:
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


;------------------------------------------------------------------------------
;

PRINT:                  ; String address hl, destroys a
        LD A,(HL)       ; Get character
        OR A            ; Is it $00 ?
        RET Z           ; Then Return on terminator
        RST 08H         ; Print it
        INC HL          ; Next Character
        JR PRINT        ; Continue until $00

TOSStr: .BYTE "TOS_",0
NOSStr: .BYTE "NOS_",0
INStr:  .BYTE CR,LF,"IN  ",0
OUTStr  .BYTE CR,LF,"OUT ",0


        .end
