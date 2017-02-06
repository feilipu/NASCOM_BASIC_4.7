
                             ; from Nascom Basic Symbol Tables

WRKSPC    .EQU    $8000      ; Workspace for 32k Basic for yaz180

DEINT     .EQU    $0BB7      ; Function DEINT to get USR(x) into DE registers
ABPASS    .EQU    $132D      ; Function ABPASS to put output into AB register for return

; 82C55 Port Definitions

PIO       .EQU    $4000      ; Base Address for 82C55
PIOA      .EQU    PIO+$00    ; Address for Port A
PIOB      .EQU    PIO+$01    ; Address for Port B
PIOC      .EQU    PIO+$02    ; Address for Port C
PIOCTL    .EQU    PIO+$03    ; Address for Control Byte

; PIO Mode Definitions

; Mode 0 - Basic Input / Output

PIOCTL00  .EQU    $80        ; A->, B->, CH->, CL->
PIOCTL01  .EQU    $81        ; A->, B->, CH->, ->CL
PIOCTL02  .EQU    $82        ; A->, ->B, CH->, CL->
PIOCTL03  .EQU    $83        ; A->, ->B, CH->, ->CL

PIOCTL04  .EQU    $88        ; A->, B->, ->CH, CL->
PIOCTL05  .EQU    $89        ; A->, B->, ->CH, ->CL
PIOCTL06  .EQU    $8A        ; A->, ->B, ->CH, CL->
PIOCTL07  .EQU    $8B        ; A->, ->B, ->CH, ->CL

PIOCTL08  .EQU    $90        ; ->A, B->, CH->, CL->
PIOCTL09  .EQU    $91        ; ->A, B->, CH->, ->CL
PIOCTL10  .EQU    $92        ; ->A, ->B, CH->, CL->
PIOCTL11  .EQU    $83        ; ->A, ->B, CH->, ->CL

PIOCTL12  .EQU    $98        ; ->A, B->, ->CH, CL->
PIOCTL13  .EQU    $99        ; ->A, B->, ->CH, ->CL
PIOCTL14  .EQU    $9A        ; ->A, ->B, ->CH, CL->
PIOCTL15  .EQU    $9B       ; ->A, ->B, ->CH, ->CL

; Mode 1 - Strobed Input / Output
; TBA Later

; Mode 2 - Strobed Bidirectional Bus Input / Output
; TBA Later


        .org 3000H      ; start from 'X' jump, Basic prompt

                        ; 82C55 I/O is from $4000 to $4003
                        ; Set Basic I/O Mode 0 Config #12

        call DEINT      ; get the USR(x) argument in de

        ld bc,PIOCTL    ; 82C55 CTL address in bc
        ld a,PIOCTL12   ; Set Mode 12 ->A, B->, ->CH, CL->
        out (c),a       ;
                
        ld bc,PIOB      ; Output onto Port B
        out (c),e       ; put LSB of USR(x) onto Port B
               
        ld bc,PIOA      ; Input form Port A
        in a,(c)        ; get LSB from Port A into a
        
        ld b,a          ; move Port A into b  
        
        xor a           ; zero a         

        jp ABPASS       ; return the Port A value to USR(x)
        
        
        .org WRKSPC+3H  ; at the USR(0) jump in Basic
        
        JP 3000H        ; jump to the I/O code.
        
        .end
