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

;==============================================================================
;
; CODE SECTION
;

        .org USRSTART   ; start from 'X' jump, Basic prompt

                        ; 82C55 I/O is from $4000 to $4003
                        ; Set Basic I/O Mode 0 Config #12

        call DEINT      ; get the USR(x) argument in de
               
        ld bc,PIOB      ; Output onto Port B
        out (c),e       ; put LSB of USR(x) onto Port B
               
        ld bc,PIOA      ; Input form Port A
        in a,(c)        ; get LSB from Port A into a
        
        ld b,a          ; move Port A into b  
        
        xor a           ; zero a         

        jp ABPASS       ; return the Port A value to USR(x)
       
        .end
