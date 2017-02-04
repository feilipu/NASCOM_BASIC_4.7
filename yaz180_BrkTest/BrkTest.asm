
IO_BASE         .EQU    $00     ; Internal I/O Base Address (ICR) <<< SET THIS AS DESIRED >>>

; Operation Mode Control Reg (OMCR)
OMCR            .EQU    IO_BASE+$3E     ; Operation Mode Control Reg

OMCR_M1E        .EQU   $80    ; M1 Enable (0 Disabled)
OMCR_M1TE       .EQU   $40    ; M1 Temporary Enable
OMCR_IOC        .EQU   $20    ; IO Control (1 64180 Mode)

        .org 3000H      ; start in 'X' jump, Basic prompt

                        ; Set Operation Mode Control Reg (OMCR)
        LD A,OMCR_M1E   ; Enable M1, but disable 64180 I/O _RD Mode
        OUT0 (OMCR),A   ; X80 Mode (M1E Enabled, OIC Disabled)
        
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
        
        .end
