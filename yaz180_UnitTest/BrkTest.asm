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


;==============================================================================
;
; DEFINES SECTION
;

;==============================================================================
;
; CODE SECTION
;
        
_main:
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


