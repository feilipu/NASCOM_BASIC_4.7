

WRKSPC  .EQU   $8000    ; Workspace for 32k Basic for yaz180

        .org 3000H      ; start from 'X' jump, Basic prompt
        
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
