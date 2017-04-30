;==============================================================================
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

;   Top of BASIC line input buffer (CURPOS WRKSPC+0ABH)
;   so it is "free ram" when BASIC resets
;   set BASIC Work space WRKSPC $8000, in CA1 RAM

WRKSPC      .EQU     RAMSTART_CA1

;==================================================================================
;
; CODE SECTION
;

        .org USRSTART   ; start from 'X' jump, Basic prompt

;        XOR A           ; Zero Accumulator

                        ; Set INT/TRAP Control Register (ITC)             
;        OUT0 (ITC),A    ; Disable all external interrupts.

;        di

        ld hl, INT_INT0_ADDR    ; load the address of the INT0 jump
        dec hl                  ; initially there is a RET 0xC9 there.
;        ld (hl), $00           ; load a EI 0xFB, or DI 0xF3, or NOP 0x00
;        ld (hl), $c9           ; load a RET 0xC9
;        ld (hl), $ed           ; load a RETI 0xED4D
;        inc hl
;        ld (hl), $4d

        ld (hl), $c3    ; load a JP $0020
        inc hl
        ld (hl), $20
        inc hl
        ld (hl), $00

;        ei

APU_AB_RES:
        xor a
        ld b, a      
        jp ABPASS       ; return the 16 bit value to USR(x)


        .end
