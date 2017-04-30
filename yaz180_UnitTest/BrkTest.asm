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

;==============================================================================
;
; CODE SECTION
;

        .org USRSTART   ; start from 'X' jump, Basic prompt
        
        ld bc, $2000    ; Break is anything from $2000 to $3FFF
        out (c), A      ; output the 0 to Break to Single Step mode
        ret             ; return to where we started
        
                        ; mb = &h3000
                        ; print mb
                        ; poke mb, &h01
                        ; poke mb+1, &h00
                        ; poke mb+2, &h20
                        ; poke mb+3, &hed
                        ; poke mb+4, &h79
                        ; poke mb+5, &hc9


        .org WRKSPC+3H  ; at the USR(0) jump in Basic
        
        JP 3000H        ; jump to the BREAK code.
        
        .end
