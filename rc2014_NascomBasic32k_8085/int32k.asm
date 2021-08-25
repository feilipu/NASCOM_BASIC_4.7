;==============================================================================
;
; The rework to support MS Basic HLOAD and the 8085 instruction tuning are
; copyright (C) 2021 Phillip Stevens
;
; This Source Code Form is subject to the terms of the Mozilla Public
; License, v. 2.0. If a copy of the MPL was not distributed with this
; file, You can obtain one at http://mozilla.org/MPL/2.0/.
;
; ACIA 6850 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to allow run-on
; from the sender. Transmit and receive are interrupt driven using IRQ_65.
; 115200 baud, 8n2
;
; 8085 SID interrupt driven serial with full input buffering.
; Receive interrupt driven using IRQ_75.
; 115200 baud, 8n2
;
; feilipu, August 2021
;
;==============================================================================
;
; The updates to the original BASIC within this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.wales/
;
;==============================================================================
;
; NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft
; Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3
; (May-June 1983) to Vol 3, Issue 3 (May-June 1984)
; Adapted for the freeware Zilog Macro Assembler 2.10 to produce
; the original ROM code (checksum A934H). PA
;
;==============================================================================
;
; INCLUDES SECTION
;

INCLUDE "rc2014.inc"

;==============================================================================
;
; CODE SECTION
;

;------------------------------------------------------------------------------
SECTION serial_interrupt

.cpu_int
                                    ; 24 -> 38 max cycles before starting interrupt
        push af                     ; 12
                                    ; 36 -> 50 max cycles before reading start bit
        rim                         ;  4 get the status of the SID

        rla                         ;  4 check whether a byte is being received
        push hl                     ; 12
        jp C,cint_end               ; 10/7 no start bit, so exit

        ld hl, 0x0800               ; 10 8 bits per byte in H, clear L

.cint_loop
        push hl                     ; 12 delay
        pop hl                      ; 10 delay
                                    ; 31 -> 45 cycles required to middle of first bit

        rim                         ;  4 get received SID bit
        rla                         ;  4 SID bit to Carry
        ld a,l                      ;  4
        rra                         ;  4
        ld l,a                      ;  4 capture bit in L
        dec h                       ;  4
        nop                         ;  4 delay
        nop                         ;  4 delay
        jp NZ,cint_loop             ; 10/7
                                    ; 64 loop total for correct timing

        ld a,(serRxBufUsed)         ; 13 get the number of bytes in the Rx buffer
        cp SER_RX_BUFSIZE-1         ;  4 check whether there is space in the buffer
        jp NC,cint_end              ; 10/7 buffer full, exit

        ld a,l                      ;  4 get Rx byte from l
        ld hl,serRxBufUsed          ; 10
        inc (hl)                    ; 10 atomically increment Rx buffer count
        ld hl,(serRxInPtr)          ; 16 get the pointer to where we poke
        ld (hl),a                   ;  7 write the Rx byte to the serRxInPtr address

        inc l                       ;  4 move the Rx pointer low byte along, 0xFF rollover
        ld (serRxInPtr),hl          ; 16 write where the next byte should be poked

.cint_end
        ld hl,TXC                   ; 10 get address of cpu TXC
        ld (RST_08_ADDR),hl         ; 16 update RST_08 contents

        ld a,$10                    ;  7
        sim                         ;  4 reset R7.5

        pop hl                      ; 10
        pop af                      ; 10

        ei                          ;  4
        ret                         ; 10

                                    ; 186 cycles from last sample for buffer management
                                    ; 160 cycles budget (1/2 bit + 2 stop bit)

ALIGN $010

.acia_int
        push af
        push hl

        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        rrca                        ; check whether a byte has been received, via SER_RDRF
        jp NC,acia_tx_send          ; if not, go check for bytes to transmit

.acia_rx_get
        in a,(SER_DATA_ADDR)        ; Get the received byte from the ACIA 
        ld l,a                      ; Move Rx byte to l

        ld a,(serRxBufUsed)         ; Get the number of bytes in the Rx buffer
        cp SER_RX_BUFSIZE-1         ; check whether there is space in the buffer
        jp NC,acia_tx_check         ; buffer full, check if we can send something

        ld a,l                      ; get Rx byte from l
        ld hl,serRxBufUsed
        inc (hl)                    ; atomically increment Rx buffer count
        ld hl,(serRxInPtr)          ; get the pointer to where we poke
        ld (hl),a                   ; write the Rx byte to the serRxInPtr address

        inc l                       ; move the Rx pointer low byte along, 0xFF rollover
        ld (serRxInPtr),hl          ; write where the next byte should be poked

        ld a,(serRxBufUsed)         ; get the current Rx count
        cp SER_RX_FULLSIZE          ; compare the count with the preferred full size
        jp NZ,acia_tx_check         ; leave the RTS low, and check for Rx/Tx possibility

        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS1             ; Set RTS high, and disable Tx Interrupt
        ld (serControl),a           ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR),a       ; Set the ACIA CTRL register

.acia_tx_check
        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        rrca                        ; check whether a byte has been received, via SER_RDRF
        jp C,acia_rx_get            ; another byte received, go get it

.acia_tx_send
        rrca                        ; check whether a byte can be transmitted, via SER_TDRE
        jp NC,acia_txa_end          ; if not, we're done for now

        ld a,(serTxBufUsed)         ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jp Z,acia_tei_clear         ; if the count is zero, then disable the Tx Interrupt

        ld hl,(serTxOutPtr)         ; get the pointer to place where we pop the Tx byte
        ld a,(hl)                   ; get the Tx byte
        out (SER_DATA_ADDR),a       ; output the Tx byte to the ACIA

        inc l                       ; move the Tx pointer, just low byte, along
        ld a,SER_TX_BUFSIZE-1       ; load the buffer size, (n^2)-1
        and l                       ; range check
        or serTxBuf&0xFF            ; locate base
        ld l,a                      ; return the low byte to l
        ld (serTxOutPtr),hl         ; write where the next byte should be popped

        ld hl,serTxBufUsed
        dec (hl)                    ; atomically decrement current Tx count

        jp NZ,acia_txa_end          ; if we've more Tx bytes to send, we're done for now

.acia_tei_clear
        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_RTS0           ; mask out (disable) the Tx Interrupt
        ld (serControl),a           ; write the ACIA control byte back
        out (SER_CTRL_ADDR),a       ; Set the ACIA CTRL register

.acia_txa_end
        ld hl,TXA                   ; get address of ACIA TXA
        ld (RST_08_ADDR),hl         ; 16 update RST_08 contents

        pop hl
        pop af

        ei
        ret

;------------------------------------------------------------------------------
SECTION serial_rx                   ; ORG $00F0

.RX
        ld a,(serRxBufUsed)         ; get the number of bytes in the Rx buffer
        or a                        ; see if there are zero bytes available
        jp Z,RX                     ; wait, if there are no bytes available

        push hl                     ; store HL so we don't clobber it
        push bc                     ; store BC

        ld hl,(RST_08_ADDR)         ; get contents of RST_08 vector
        ld bc,TXC                   ; get address of cpu TXC
        sub hl,bc                   ; check whether we're using the cpu TXC
        jp Z,rx_get_byte            ; then skip the ACIA control clean up

        cp SER_RX_EMPTYSIZE         ; compare the count with the preferred empty size
        jp NZ,rx_get_byte           ; if the buffer is too full, don't change the RTS

        di                          ; critical section begin
        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; set RTS low.
        ld (serControl),a           ; write the ACIA control echo byte back
        ei                          ; critical section end
        out (SER_CTRL_ADDR),a       ; set the ACIA CTRL register

.rx_get_byte
        ld hl,(serRxOutPtr)         ; get the pointer to place where we pop the Rx byte
        ld a,(hl)                   ; get the Rx byte
        inc l                       ; move the Rx pointer low byte along
        ld (serRxOutPtr),hl         ; write where the next byte should be popped

        ld hl,serRxBufUsed
        dec (hl)                    ; atomically decrement Rx count

        pop bc                      ; recover BC
        pop hl                      ; recover HL
        ret                         ; char ready in A

;------------------------------------------------------------------------------
SECTION serial_tx                   ; ORG $0130

.TXC                                ; output a character in A
        di
        push hl

        ld h,11                     ; 11 bits per byte (1 start, 2 stop bits)
        ld l,a
        xor a                       ; clear carry for start bit

.txc_loop
        ld a,$80                    ;  7 set eventual SOD enable bit
        rra                         ;  4 move carry into SOD bit
        sim                         ;  4 output bit data

        dec hl                      ;  6 delay for a bit time
        inc hl                      ;  6 delay
        ld a,0                      ;  7 delay

        scf                         ;  4 set eventual stop bit(s)
        ld a,l                      ;  4
        rra                         ;  4
        ld l,a                      ;  4
        dec h                       ;  4
        jp NZ,txc_loop              ; 10/7
                                    ; 64 total for correct timing
        pop hl
        ei
        ret

ALIGN $010

.TXA
        push hl                     ; store HL so we don't clobber it
        ld l,a                      ; store Tx character

        ld a,(serTxBufUsed)         ; Get the number of bytes in the Tx buffer
        or a                        ; check whether the buffer is empty
        jp NZ,txa_buffer_out        ; buffer not empty, so abandon immediate Tx

        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        and SER_TDRE                ; check whether a byte can be transmitted
        jp Z,txa_buffer_out         ; if not, so abandon immediate Tx

        ld a,l                      ; Retrieve Tx character for immediate Tx
        out (SER_DATA_ADDR),a       ; immediately output the Tx byte to the ACIA

        pop hl                      ; recover HL
        ret                         ; and just complete

.txa_buffer_out
        ld a,(serTxBufUsed)         ; Get the number of bytes in the Tx buffer
        cp SER_TX_BUFSIZE-1         ; check whether there is space in the buffer
        jp NC,txa_buffer_out        ; buffer full, so wait till it has space

        ld a,l                      ; Retrieve Tx character

        ld hl,serTxBufUsed
        di
        inc (hl)                    ; atomic increment of Tx count
        ld hl,(serTxInPtr)          ; get the pointer to where we poke
        ei
        ld (hl),a                   ; write the Tx byte to the serTxInPtr

        inc l                       ; move the Tx pointer, just low byte along
        ld a,SER_TX_BUFSIZE-1       ; load the buffer size, (n^2)-1
        and l                       ; range check
        or serTxBuf&0xFF            ; locate base
        ld l,a                      ; return the low byte to l
        ld (serTxInPtr),hl          ; write where the next byte should be poked

        pop hl                      ; recover HL

        ld a,(serControl)           ; get the ACIA control echo byte
        and SER_TEI_RTS0            ; test whether ACIA interrupt is set
        ret NZ                      ; if so then just return

        di                          ; critical section begin
        ld a,(serControl)           ; get the ACIA control echo byte again
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TEI_RTS0             ; set RTS low. if the TEI was not set, it will work again
        ld (serControl),a           ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR),a       ; set the ACIA CTRL register
        ei                          ; critical section end
        ret

;------------------------------------------------------------------------------
SECTION serial_print                ; ORG $01A0

.APRINT
        LD A,(HL)                   ; get character
        OR A                        ; is it $00 ?
        RET Z                       ; then RETurn on terminator
        CALL TXA                    ; print it
        INC HL                      ; next Character
        JP APRINT                   ; continue until $00

.CPRINT
        ld a,(hl)                   ; get next character
        or a                        ; check if null (end of string)
        ret Z
        call TXC                    ; output character in A
        inc hl                      ; next character
        jp CPRINT                   ; continue until $00

;------------------------------------------------------------------------------
SECTION init                        ; ORG $01B8

PUBLIC  INIT

.INIT
        LD SP,TEMPSTACK             ; Set up a temporary stack

        LD HL,VECTOR_PROTO          ; Establish 8085 RST Vector Table
        LD DE,VECTOR_BASE
        LD C,VECTOR_SIZE
.COPY
        LD A,(HL)
        LD (DE),A
        INC HL
        INC DE
        DEC C
        JP NZ,COPY

        LD HL,serRxBuf              ; Initialise Rx Buffer
        LD (serRxInPtr),HL
        LD (serRxOutPtr),HL

        LD HL,serTxBuf              ; Initialise Tx Buffer
        LD (serTxInPtr),HL
        LD (serTxOutPtr),HL

        XOR A                       ; 0 the RXA & TXA Buffer Counts
        LD (serRxBufUsed),A
        LD (serTxBufUsed),A

        LD A,$19
        SIM                         ; reset R7.5, Set MSE to mask R5.5

        LD A,SER_RESET              ; Master Reset the ACIA
        OUT (SER_CTRL_ADDR),A

        LD A,SER_REI|SER_TDI_RTS0|SER_8N2|SER_CLK_DIV_64
                                    ; load the default ACIA configuration
                                    ; 8n2 at 115200 baud
                                    ; receive interrupt enabled
                                    ; transmit interrupt disabled
                            
        LD (serControl),A           ; write the ACIA control byte echo
        OUT (SER_CTRL_ADDR),A       ; output to the ACIA control byte

        EI                          ; enable interrupts

.START
        LD HL,SIGNON1               ; Sign-on message
        CALL CPRINT                 ; Output string
        LD HL,SIGNON1               ; Sign-on message
        CALL APRINT                 ; Output string
        LD A,(basicStarted)         ; Check the BASIC STARTED flag
        CP 'Y'                      ; to see if this is power-up
        JP NZ,COLDSTART             ; If not BASIC started then always do cold start
        LD HL,SIGNON2               ; Cold/warm message
        CALL CPRINT                 ; Output string
        LD HL,SIGNON2               ; Cold/warm message
        CALL APRINT                 ; Output string
.CORW
        RST 10H
        AND 11011111B               ; lower to uppercase
        CP 'C'
        JP NZ,CHECKWARM
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
.COLDSTART
        LD A,'Y'                    ; Set the BASIC STARTED flag
        LD (basicStarted),A
        JP $02D0                    ; <<<< Start Basic COLD:
.CHECKWARM
        CP 'W'
        JP NZ,CORW
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
.WARMSTART
        JP $02D3                    ; <<<< Start Basic WARM:

;==============================================================================
;
; STRINGS
;
SECTION         init_strings        ; ORG $0240

.SIGNON1
                DEFM    CR,LF
                DEFM    "RC2014/8085 - MS Basic Loader",CR,LF
                DEFM    "z88dk - feilipu",CR,LF,0

.SIGNON2
                DEFM    CR,LF
                DEFM    "Cold | Warm start (C|W) ? ",0

;==============================================================================
;
; 8085 INTERRUPT VECTOR PROTOTYPE ASSIGNMENTS
;

EXTERN  NULL_RET, NULL_INT

PUBLIC  RST_00, RST_08, RST_10; RST_18
PUBLIC  RST_20, RST_28, RST_30, RST_38

PUBLIC  TRAP, IRQ_55, IRQ_65, IRQ_75, RST_40

DEFC    RST_00      =       INIT            ; Initialise, should never get here
DEFC    RST_08      =       TXC             ; TX character, loop until space
DEFC    RST_10      =       RX              ; RX character, loop until byte
;       RST_18      =       RX_CHK          ; Check receive buffer status, return # bytes available
DEFC    RST_20      =       NULL_RET        ; RET
DEFC    TRAP        =       NULL_INT        ; 8085 TRAP - RC2014 Bus /NMI
DEFC    RST_28      =       NULL_RET        ; RET
DEFC    IRQ_55      =       NULL_INT        ; 8085 IRQ 5.5 - 8085 CPU Module
DEFC    RST_30      =       NULL_RET        ; RET
DEFC    IRQ_65      =       acia_int        ; 8085 IRQ 6.5 - RC2014 Bus /INT
DEFC    RST_38      =       NULL_RET        ; RET
DEFC    IRQ_75      =       cpu_int         ; 8085 IRQ 7.5 - RC2014 Bus /RX
DEFC    RST_40      =       NULL_RET        ; 8085 JP V Overflow

;==============================================================================

