;==============================================================================
; Contents of this file are copyright Phillip Stevens
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; Initialisation routines to suit Z8S180 CPU, with internal USART.
;
; Internal USART interrupt driven serial I/O
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
#include    "d:/z80intr.asm"
#include    "d:/z180intr.asm"

;==============================================================================
;
; DEFINES SECTION
;

; Top of BASIC line input buffer (CURPOS WRKSPC+0ABH)
; so it is "free ram" when BASIC resets
; set BASIC Work space WRKSPC $8000, in CA1 RAM

WRKSPC      .EQU     RAMSTART_CA1 
TEMPSTACK   .EQU     WRKSPC+$AB

;==============================================================================
;
; CODE SECTION
;

        .ORG    0100H

;------------------------------------------------------------------------------
ASCI0_INTERRUPT:
        push af
        push hl
                                    ; start doing the Rx stuff
        in0 a, (STAT0)              ; load the ASCI0 status register
        tst SER_RDRF                ; test whether we have received on ASCI0
        jr z, ASCI0_TX_CHECK        ; if not, go check for bytes to transmit

ASCI0_RX_GET:
        in0 l, (RDR0)               ; move Rx byte from the ASCI0 RDR to l
        
        and SER_OVRN|SER_PE|SER_FE  ; test whether we have error on ASCI0
        jr nz, ASCI0_RX_ERROR       ; drop this byte, clear error, and get the next byte

        ld a, (serRx0BufUsed)       ; get the number of bytes in the Rx buffer      
        cp SER_RX0_BUFSIZE          ; check whether there is space in the buffer
        jr nc, ASCI0_RX_CHECK       ; buffer full, check whether we need to drain H/W FIFO

        ld a, l                     ; get Rx byte from l
        ld hl, (serRx0InPtr)        ; get the pointer to where we poke
        ld (hl), a                  ; write the Rx byte to the serRx0InPtr target

        inc l                       ; move the Rx pointer low byte along, 0xFF rollover
        ld (serRx0InPtr), hl        ; write where the next byte should be poked

        ld hl, serRx0BufUsed
        inc (hl)                    ; atomically increment Rx buffer count
        jr ASCI0_RX_CHECK           ; check for additional bytes

ASCI0_RX_ERROR:
        in0 a, (CNTLA0)             ; get the CNTRLA0 register
        and ~SER_EFR                ; to clear the error flag, EFR, to 0 
        out0 (CNTLA0), a            ; and write it back

ASCI0_RX_CHECK:                     ; Z8S180 has 4 byte Rx H/W FIFO
        in0 a, (STAT0)              ; load the ASCI0 status register
        tst SER_RDRF                ; test whether we have received on ASCI0
        jr nz, ASCI0_RX_GET         ; if still more bytes in H/W FIFO, get them

ASCI0_TX_CHECK:                     ; now start doing the Tx stuff
        and SER_TDRE                ; test whether we can transmit on ASCI0
        jr z, ASCI0_TX_END          ; if not, then end

        ld a, (serTx0BufUsed)       ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jr z, ASCI0_TX_TIE0_CLEAR   ; if the count is zero, then disable the Tx Interrupt

        ld hl, (serTx0OutPtr)       ; get the pointer to place where we pop the Tx byte
        ld a, (hl)                  ; get the Tx byte
        out0 (TDR0), a              ; output the Tx byte to the ASCI0

        inc l                       ; move the Tx pointer low byte along, 0xFF rollover
        ld (serTx0OutPtr), hl       ; write where the next byte should be popped

        ld hl, serTx0BufUsed
        dec (hl)                    ; atomically decrement current Tx count

        jr nz, ASCI0_TX_END         ; if we've more Tx bytes to send, we're done for now

ASCI0_TX_TIE0_CLEAR:
        in0 a, (STAT0)              ; get the ASCI0 status register
        and ~SER_TIE                ; mask out (disable) the Tx Interrupt
        out0 (STAT0), a             ; set the ASCI0 status register

ASCI0_TX_END:
        pop hl
        pop af

        ei
        ret

;------------------------------------------------------------------------------
RX0:
        ld a, (serRx0BufUsed)       ; get the number of bytes in the Rx buffer
        or a                        ; see if there are zero bytes available
        jr z, RX0                   ; wait, if there are no bytes available

        push hl                     ; Store HL so we don't clobber it

        ld hl, (serRx0OutPtr)       ; get the pointer to place where we pop the Rx byte
        ld a, (hl)                  ; get the Rx byte

        inc l                       ; move the Rx pointer low byte along, 0xFF rollover
        ld (serRx0OutPtr), hl       ; write where the next byte should be popped

        ld hl, serRx0BufUsed
        dec (hl)                    ; atomically decrement Rx count

        pop hl                      ; recover HL
        ret                         ; char ready in A

;------------------------------------------------------------------------------
TX0:
        push hl                     ; store HL so we don't clobber it        
        ld l, a                     ; store Tx character 

        ld a, (serTx0BufUsed)       ; get the number of bytes in the Tx buffer
        or a                        ; check whether the buffer is empty
        jr nz, TX0_BUFFER_OUT       ; buffer not empty, so abandon immediate Tx

        in0 a, (STAT0)              ; get the ASCI0 status register
        and SER_TDRE                ; test whether we can transmit on ASCI0
        jr z, TX0_BUFFER_OUT        ; if not, so abandon immediate Tx

        ld a, l                     ; Retrieve Tx character for immediate Tx
        out0 (TDR0), a              ; output the Tx byte to the ASCI0

        pop hl                      ; recover HL
        ret                         ; and just complete

TX0_BUFFER_OUT:
        ld a, (serTx0BufUsed)       ; Get the number of bytes in the Tx buffer
        cp SER_TX0_BUFSIZE          ; check whether there is space in the buffer
        jr nc, TX0_BUFFER_OUT       ; buffer full, so wait for free buffer for Tx

        ld a, l                     ; retrieve Tx character
        ld hl, (serTx0InPtr)        ; get the pointer to where we poke
        ld (hl), a                  ; write the Tx byte to the serTx0InPtr   

        inc l                       ; move the Tx pointer low byte along, 0xFF rollover
        ld (serTx0InPtr), hl        ; write where the next byte should be poked

        ld hl, serTx0BufUsed
        inc (hl)                    ; atomic increment of Tx count

        pop hl                      ; recover HL

        in0 a, (STAT0)              ; load the ASCI0 status register
        and SER_TIE                 ; test whether ASCI0 interrupt is set
        ret nz                      ; if so then just return

        di                          ; critical section begin
        in0 a, (STAT0)              ; get the ASCI status register again
        or SER_TIE                  ; mask in (enable) the Tx Interrupt
        out0 (STAT0), a             ; set the ASCI status register
        ei                          ; critical section end
        ret

;------------------------------------------------------------------------------
RX0_CHK:
        LD      A,(serRx0BufUsed)
        CP      $0
        RET

;------------------------------------------------------------------------------
TX0_PRINT:
        LD      A,(HL)              ; Get a byte
        OR      A                   ; Is it $00 ?
        RET     Z                   ; Then RETurn on terminator
        CALL    TX0                 ; Print it
        INC     HL                  ; Next byte
        JR      TX0_PRINT           ; Continue until $00

;------------------------------------------------------------------------------
HEX_START:
            ld hl, initString
            call TX0_PRINT

            ld c,0                  ; non zero c is our ESA flag

HEX_WAIT_COLON:
            call RX0                ; Rx byte
            cp ':'                  ; wait for ':'
            jr nz, HEX_WAIT_COLON
            ld hl, 0                ; reset hl to compute checksum
            call HEX_READ_BYTE      ; read byte count
            ld b, a                 ; store it in b
            call HEX_READ_BYTE      ; read upper byte of address
            ld d, a                 ; store in d
            call HEX_READ_BYTE      ; read lower byte of address
            ld e, a                 ; store in e
            call HEX_READ_BYTE      ; read record type
            cp 02                   ; check if record type is 02 (ESA)
            jr z, HEX_ESA_DATA
            cp 01                   ; check if record type is 01 (end of file)
            jr z, HEX_END_LOAD
            cp 00                   ; check if record type is 00 (data)
            jr nz, HEX_INVAL_TYPE   ; if not, error
HEX_READ_DATA:
            ld a, '*'               ; "*" per byte loaded  # DEBUG
            call TX0                ; Print it             # DEBUG
            call HEX_READ_BYTE
            ld (de), a              ; write the byte at the RAM address
            inc de
            djnz HEX_READ_DATA      ; if b non zero, loop to get more data
HEX_READ_CHKSUM:
            call HEX_READ_BYTE      ; read checksum, but we don't need to keep it
            ld a, l                 ; lower byte of hl checksum should be 0
            or a
            jr nz, HEX_BAD_CHK      ; non zero, we have an issue
            ld a, '#'               ; "#" per line loaded
            call TX0                ; Print it
            ld a, CR                ; CR                   # DEBUG
            call TX0                ; Print it             # DEBUG
            ld a, LF                ; LF                   # DEBUG
            call TX0                ; Print it             # DEBUG
            jr HEX_WAIT_COLON

HEX_ESA_DATA:
            in0 a, (BBR)            ; grab the current Bank Base Value
            ld c, a                 ; store BBR for later recovery
            call HEX_READ_BYTE      ; get high byte of ESA
            out0 (BBR), a           ; write it to the BBR  
            call HEX_READ_BYTE      ; get low byte of ESA, abandon it, but calc checksum
            jr HEX_READ_CHKSUM      ; calculate checksum

HEX_END_LOAD:
            call HEX_READ_BYTE      ; read checksum, but we don't need to keep it
            ld a, l                 ; lower byte of hl checksum should be 0
            or a
            jr nz, HEX_BAD_CHK      ; non zero, we have an issue
            call HEX_BBR_RESTORE    ; clean up the BBR
            ld hl, LoadOKStr
            call TX0_PRINT
            jp WARMSTART            ; ready to run our loaded program from Basic
            
HEX_INVAL_TYPE:
            call HEX_BBR_RESTORE    ; clean up the BBR
            ld hl, invalidTypeStr
            call TX0_PRINT
            jp START                ; go back to start

HEX_BAD_CHK:
            call HEX_BBR_RESTORE    ; clean up the BBR
            ld hl, badCheckSumStr
            call TX0_PRINT
            jp START                ; go back to start

HEX_BBR_RESTORE:
            ld a, c                 ; get our BBR back
            ret z                   ; if it is zero, chances are we don't need it
            out0 (BBR), a           ; write it to the BBR
            ret

HEX_READ_BYTE:                      ; Returns byte in a, checksum in hl
            push bc
            call RX0                ; Rx byte
            sub '0'
            cp 10
            jr c, HEX_READ_NBL2     ; if a<10 read the second nibble
            sub 7                   ; else subtract 'A'-'0' (17) and add 10
HEX_READ_NBL2:
            rlca                    ; shift accumulator left by 4 bits
            rlca
            rlca
            rlca
            ld c, a                 ; temporarily store the first nibble in c
            call RX0                ; Rx byte
            sub '0'
            cp 10
            jr c, HEX_READ_END      ; if a<10 finalize
            sub 7                   ; else subtract 'A' (17) and add 10
HEX_READ_END:
            or c                    ; assemble two nibbles into one byte in a
            ld b, 0                 ; add the byte read to hl (for checksum)
            ld c, a
            add hl, bc
            pop bc
            ret                     ; return the byte read in a

;------------------------------------------------------------------------------

Z180_INIT:
                                    ; Set Logical RAM Addresses
                                    ; $8000-$FFFF RAM CA1 -> 80H
                                    ; $4000-$7FFF RAM BANK -> 04H
                                    ; $2000-$3FFF RAM CA0
                                    ; $0000-$1FFF Flash CA0
                                    
            LD      A,84H           ; Set New Common / Bank Areas for RAM
            OUT0    (CBAR),A
            LD      A,78H           ; Set Common 1 Area Physical $80000 -> 78H
            OUT0    (CBR),A
            LD      A,3CH           ; Set Bank Area Physical $40000 -> 3CH
            OUT0    (BBR),A

                                    ; load the default ASCI configuration
                                    ; BAUD = 115200 8n1
                                    ; receive enabled
                                    ; transmit enabled
                                    ; receive interrupt enabled
                                    ; transmit interrupt disabled

            LD      A,SER_RE|SER_TE|SER_8N1
            OUT0    (CNTLA0),A      ; output to the ASCI0 control A reg

                                    ; PHI / PS / SS / DR = BAUD Rate
                                    ; PHI = 18.432MHz
                                    ; BAUD = 115200 = 18432000 / 10 / 1 / 16 
                                    ; PS 0, SS_DIV_1 0, DR 0           
            XOR     A               ; BAUD = 115200
            OUT0    (CNTLB0),A      ; output to the ASCI0 control B reg
                          
            LD      A,SER_RIE       ; receive interrupt enabled
            OUT0    (STAT0),A       ; output to the ASCI0 status reg

                                    ; Set up 82C55 PIO in Mode 0 #12
            LD      BC,PIOCNTL      ; 82C55 CNTL address in bc
            LD      A,PIOCNTL12     ; Set Mode 12 ->A, B->, ->CH, CL->
            OUT     (C),A           ; output to the PIO control reg

            LD      SP,TEMPSTACK    ; Set up a temporary stack

            LD      HL,serRx0Buf    ; Initialise Rx0 Buffer
            LD      (serRx0InPtr),HL
            LD      (serRx0OutPtr),HL

            LD      HL,serTx0Buf    ; Initialise Tx0 Buffer
            LD      (serTx0InPtr),HL
            LD      (serTx0OutPtr),HL              

            XOR     A               ; 0 the Tx0 & Rx0 Buffer Counts
            LD      (serRx0BufUsed),A
            LD      (serTx0BufUsed),A

            EI                      ; enable interrupts

START:                                     
            LD      HL,SIGNON1      ; Sign-on message
            CALL    TX0_PRINT       ; Output string
            LD      A,(basicStarted); Check the BASIC STARTED flag
            CP      'Y'             ; to see if this is power-up
            JR      NZ,COLDSTART    ; If not BASIC started then always do cold start
            LD      HL,SIGNON2      ; Cold/warm message
            CALL    TX0_PRINT       ; Output string
CORW:
            RST     10H             ; get a byte from ASCI0
            AND     11011111B       ; lower to uppercase
            CP      'H'             ; are we trying to load an Intel HEX program?
            JP      Z, HEX_START    ; then jump to HexLoadr
            CP      'C'
            JR      NZ, CHECKWARM
            RST     08H
            LD      A, CR
            RST     08H
            LD      A, LF
            RST     08H
COLDSTART:
            LD      A,'Y'           ; Set the BASIC STARTED flag
            LD      (basicStarted),A
            JP      $0390           ; <<<< Start Basic COLD:

CHECKWARM:
            CP      'W'
            JR      NZ, CORW
            RST     08H
            LD      A, CR
            RST     08H
            LD      A, LF
            RST     08H
WARMSTART:
            JP      $0393          ; <<<< Start Basic WARM:


;==============================================================================
;
; STRINGS
;
SIGNON1:    .BYTE   "YAZ180 - feilipu",CR,LF,0

SIGNON2:    .BYTE   CR,LF
            .BYTE   "Cold or Warm start, "
            .BYTE   "or HexLoadr (C|W|H) ? ",0

initString: .BYTE CR,LF
            .BYTE "HexLoadr: "
            .BYTE CR,LF,0

invalidTypeStr: .BYTE "Inval Type",CR,LF,0
badCheckSumStr: .BYTE "Chksum Error",CR,LF,0
LoadOKStr:      .BYTE "Done",CR,LF,0

;==============================================================================
;
; Z80 INTERRUPT VECTOR SERVICE ROUTINES
;

RST_08      .EQU    TX0             ; TX a byte over ASCI0
RST_10      .EQU    RX0             ; RX a byte over ASCI0, loop byte available
RST_18      .EQU    RX0_CHK         ; Check ASCI0 status, return # bytes available
RST_20      .EQU    NULL_RET        ; RET
RST_28      .EQU    NULL_RET        ; RET
RST_30      .EQU    NULL_RET        ; RET
INT_INT0    .EQU    NULL_INT        ; EI RETI
INT_NMI     .EQU    NULL_NMI        ; RETN

;==============================================================================
;
; Z180 INTERRUPT VECTOR SERVICE ROUTINES
;

INT_INT1    .EQU    NULL_RET        ; external /INT1
INT_INT2    .EQU    NULL_RET        ; external /INT2
INT_PRT0    .EQU    NULL_RET        ; PRT channel 0
INT_PRT1    .EQU    NULL_RET        ; PRT channel 1
INT_DMA0    .EQU    NULL_RET        ; DMA channel 0
INT_DMA1    .EQU    NULL_RET        ; DMA Channel 1
INT_CSIO    .EQU    NULL_RET        ; Clocked serial I/O
INT_ASCI0   .EQU    ASCI0_INTERRUPT ; Async channel 0
INT_ASCI1   .EQU    NULL_RET        ; Async channel 1

;==============================================================================
;
            .END
;
;==============================================================================


