;==============================================================================
;
; The rework to support MS Basic HLOAD, RESET, MEEK, MOKE,
; and the Z80 instruction tuning are copyright (C) 2020-23 Phillip Stevens
;
; This Source Code Form is subject to the terms of the Mozilla Public
; License, v. 2.0. If a copy of the MPL was not distributed with this
; file, You can obtain one at http://mozilla.org/MPL/2.0/.
;
; ACIA 6850 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to allow run-on
; from the sender. Transmit and receive are interrupt driven.
; 115200 baud, 8n2
;
; feilipu, August 2020
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
SECTION uart_interrupt              ; ORG $0070

.uart_interrupt
    push af
    push hl

.uarta
    in a,(UARTA_IIR_REGISTER)   ; get the status of the UART A
    rrca                        ; check whether an interrupt was generated
    jp C,uartb                  ; if not, go check UART B

.rxa_get
    ; read the IIR to access the relevant interrupts
    in a,(UARTA_IIR_REGISTER)   ; get the status of the UART A
    and UART_IIR_DATA           ; Rx data is available
                                ; XXX To do handle line errors
    jp Z,uartb                  ; if not, go check UART B

    in a,(UARTA_DATA_REGISTER)  ; Get the received byte from the UART A
    ld hl,(uartRxIn)            ; get the pointer to where we poke
    ld (hl),a                   ; write the Rx byte to the uartRxIn address

    inc l                       ; move the Rx pointer low byte along
IF UART_RX_SIZE != 0x100
    ld a,UART_RX_SIZE-1         ; load the buffer size, (n^2)-1
    and l                       ; range check
    or uartRxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
ENDIF
    ld (uartRxIn),hl            ; write where the next byte should be poked

    ld hl,uartRxCount
    inc (hl)                    ; atomically increment Rx buffer count

.rxa_dtr
    ld a,(uartRxCount)          ; get the current Rx count
    sub UART_RX_FULLISH         ; compare the count with the preferred full size
    jr C,rxa_check              ; leave the DTR low, and check for Rx possibility

    in a,(UARTA_MCR_REGISTER)       ; get the UART A MODEM Control Register
    and ~UART_MCR_RTS               ; set RTShigh
    out (UARTA_MCR_REGISTER),a      ; set the MODEM Control Register

.rxa_check
    in a,(UARTA_IIR_REGISTER)   ; get the status of the UART A
    rrca                        ; check whether an interrupt remains
    jr NC,rxa_get               ; another byte received, go get it

    ; now do the same with the UART B channel, because the interrupt is shared

.uartb
    ; check the UART B channel exists
    ld a,(uartbControl)         ; load the control flag
    or a                        ; check it is non-zero
    jp Z,int_end

    in a,(UARTB_IIR_REGISTER)   ; get the status of the UART B
    rrca                        ; check whether an interrupt was generated
    jp C,int_end                ; if not, exit interrupt

.rxb_get
    ; read the IIR to access the relevant interrupts
    in a,(UARTB_IIR_REGISTER)   ; get the status of the UART B
    and UART_IIR_DATA           ; Rx data is available
                                ; XXX To do handle line errors
    jr Z,int_end                ; if not exit

    in a,(UARTB_DATA_REGISTER)  ; Get the received byte from the UART B
    ld hl,(uartRxIn)            ; get the pointer to where we poke
    ld (hl),a                   ; write the Rx byte to the uartRxIn address

    inc l                       ; move the Rx pointer low byte along
IF UART_RX_SIZE != 0x100
    ld a,UART_RX_SIZE-1         ; load the buffer size, (n^2)-1
    and l                       ; range check
    or uartRxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
ENDIF
    ld (uartRxIn),hl            ; write where the next byte should be poked

    ld hl,uartRxCount
    inc (hl)                    ; atomically increment Rx buffer count

.rxb_dtr
    ld a,(uartRxCount)          ; get the current Rx count
    sub UART_RX_FULLISH         ; compare the count with the preferred full size
    jr C,rxb_check              ; leave the DTR low, and check for Rx possibility

    in a,(UARTB_MCR_REGISTER)       ; get the UART B MODEM Control Register
    and ~UART_MCR_RTS               ; set RTS & DTR high
    out (UARTB_MCR_REGISTER),a      ; set the MODEM Control Register

.rxb_check
    in a,(UARTB_IIR_REGISTER)   ; get the status of the UART B
    rrca                        ; check whether an interrupt remains
    jr NC,rxb_get               ; another byte received, go get it

.int_end
    pop hl
    pop af

    ei
    ret

;------------------------------------------------------------------------------
;
; .RXA_CHK                          ; insert directly into JumP table
;       ld a,(uartRxCount)
;       ret

;------------------------------------------------------------------------------
SECTION uart_rx_tx                  ; ORG $00F0

.RXA
        ld a,(uartRxCount)          ; get the number of bytes in the Rx buffer
        or a                        ; see if there are zero bytes available
        jr Z,RXA                    ; wait, if there are no bytes available

        sub UART_RX_EMPTYISH        ; compare the count with the preferred empty size
        jr NC,getc_clean_up_rx      ; if the buffer is too full, don't change the RTS

        in a,(UARTA_MCR_REGISTER)   ; get the UART A MODEM Control Register
        or UART_MCR_RTS             ; set RTS low
        out (UARTA_MCR_REGISTER),a  ; set the MODEM Control Register

.getc_clean_up_rx
        push hl                     ; store HL so we don't clobber it

        ld hl,(uartRxOut)           ; get the pointer to place where we pop the Rx byte
        ld a,(hl)                   ; get the Rx byte

        inc l                       ; move the Rx pointer low byte along
    IF UART_RX_SIZE != 0x100
        push af
        ld a,UART_RX_SIZE-1         ; load the buffer size, (n^2)-1
        and l                       ; range check
        or uartRxBuffer&0xFF        ; locate base
        ld l,a                      ; return the low byte to l
        pop af
    ENDIF
        ld (uartRxOut),hl           ; write where the next byte should be popped

        ld hl,uartRxCount
        dec (hl)                    ; atomically decrement Rx count

        pop hl                      ; recover HL
        ret                         ; char ready in A

;------------------------------------------------------------------------------

.TXA                                ; output a character in A via UART
        push af                     ; store TX character so we don't clobber it

.wait_thr
        ; check space is available in the Tx FIFO
        in a,(UARTA_LSR_REGISTER)       ; read the line status register
        and UART_LSR_TX_HOLDING_THRE    ; check the THRE is available
        jr Z,wait_thr                   ; keep trying until THR has space

        pop af                      ; retrieve Tx character
        out (UARTA_DATA_REGISTER),a ; output the Tx byte to the UART A
        ret                         ; and finish

;------------------------------------------------------------------------------

SECTION init                        ; ORG $0120

PUBLIC  INIT


.INIT
        ; initialise the UART(s)

        ; set the UART divisor latch register
        xor a
        out (UARTA_IER_REGISTER),a      ; clear any enabled interrupts

        ld a,UART_LCR_DLAB              ; DLAB enable bit
        out (UARTA_LCR_REGISTER),a      ; output to LCR

        ; set the divisor latch preferred baud
        ld a,UART_DLL_115200            ; default to 115200 baud
        out (UARTA_DLL_REGISTER),a      ; divisor LSB
        xor a
        out (UARTA_DLM_REGISTER),a      ; divisor MSB

        ; reset divisor latch bit DLAB
        ; set word length, parity, and stop bits
        ld a,UART_LCR_STOP|UART_LCR_8BIT    ; default to 8n2
        out (UARTA_LCR_REGISTER),a          ; output to LCR

        ; enable and reset the FIFOs
        ld a,UART_FCR_FIFO_08|UART_FCR_FIFO_TX_RESET|UART_FCR_FIFO_RX_RESET|UART_FCR_FIFO_ENABLE
        out (UARTA_FCR_REGISTER),a

        ; set up modem control register to enable auto flow control, interrupt line, and RTS
        ld a,UART_MCR_AUTO_FLOW_CONTROL|UART_MCR_INT_ENABLE|UART_MCR_RTS
        out (UARTA_MCR_REGISTER),a

        ; enable the receive interrupt (only)   XXX To do handle line errors
        ld a,UART_IER_ERBI
        out (UARTA_IER_REGISTER),a

        ; set the control flag, to signal that this channel exists
        ld a,UARTA_DATA_REGISTER
        ld (uartaControl),a

        ; now do UART B

.uart_enable_b

        ; clear the control flag, pending checking for existence
        xor a
        ld (uartbControl),a

        ; confirm it exists by checking the UART divisor latch register
        out (UARTB_IER_REGISTER),a      ; clear any enabled interrupts

        ld a,UART_LCR_DLAB              ; DLAB enable bit
        out (UARTB_LCR_REGISTER),a      ; output to LCR

        ld a,$aa                        ; load a test byte
        out (UARTB_DLM_REGISTER),a      ; write it to UART B DLM register
        in a,(UARTB_DLM_REGISTER)       ; read it back

        rrca
        out (UARTB_SCRATCH_REGISTER),a  ; write it to UART B SCRATCH register
        in a,(UARTB_SCRATCH_REGISTER)   ; read it back

        rlca
        cp $aa
        jr NZ,START                     ; UART B doesn't exist, just continue

        ; set the divisor latch preferred baud
        ld a,UART_DLL_115200            ; default to 115200 baud
        out (UARTB_DLL_REGISTER),a      ; divisor LSB
        xor a
        out (UARTB_DLM_REGISTER),a      ; divisor MSB

        ; reset divisor latch bit
        ; set word length, parity, and stop bits
        ld a,UART_LCR_STOP|UART_LCR_8BIT    ; default to 8n2
        out (UARTB_LCR_REGISTER),a          ; output to LCR

        ; enable and reset the FIFOs
        ld a,UART_FCR_FIFO_08|UART_FCR_FIFO_TX_RESET|UART_FCR_FIFO_RX_RESET|UART_FCR_FIFO_ENABLE
        out (UARTB_FCR_REGISTER),a

        ; set up modem control register to enable auto flow control, interrupt line, and RTS
        ld a,UART_MCR_AUTO_FLOW_CONTROL|UART_MCR_INT_ENABLE|UART_MCR_RTS
        out (UARTB_MCR_REGISTER),a

        ; enable the receive interrupt (only)   XXX To do handle line errors
        ld a,UART_IER_ERBI
        out (UARTB_IER_REGISTER),a

        ; set the control flag, to signal that this channel exists
        ld a,UARTB_DATA_REGISTER
        ld (uartbControl),a

.START
        LD SP,TEMPSTACK             ; set up a temporary stack

        LD HL,VECTOR_PROTO          ; establish Z80 RST Vector Table
        LD DE,VECTOR_BASE
        LD BC,VECTOR_SIZE
        LDIR

        LD HL,uartRxBuffer           ; initialise Rx Buffer
        LD (uartRxIn),HL
        LD (uartRxOut),HL

        XOR A                       ; zero the RXA Buffer Count
        LD (uartRxCount),A

        LD A,BEL                    ; prepare a BEL, to indicate normal boot
        RST 08H                     ; output the BEL

        IM 1                        ; interrupt mode 1
        EI                          ; enable interrupts

        LD HL,SIGNON1               ; sign-on message
        CALL PRINT                  ; output string
        LD A,(basicStarted)         ; check the BASIC STARTED flag
        CP 'Y'                      ; to see if this is power-up
        JP NZ,COLDSTART             ; if not BASIC started then always do cold start
        LD HL,SIGNON2               ; cold/warm message
        CALL PRINT                  ; output string
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
        LD A,'Y'                    ; set the BASIC STARTED flag
        LD (basicStarted),A
        JP $0240                    ; <<<< Start Basic COLD

.CHECKWARM
        CP 'W'
        JP NZ,CORW
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
.WARMSTART
        JP $0243                    ; <<<< Start Basic WARM

.PRINT
        LD A,(HL)                   ; get character
        OR A                        ; is it $00 ?
        RET Z                       ; then RETurn on terminator
        CALL TXA                    ; output character in A
        INC HL                      ; next Character
        JP PRINT                    ; continue until $00

;==============================================================================
;
; STRINGS
;
SECTION init_strings                ; ORG $01F0

.SIGNON1
        DEFM    CR,LF
        DEFM    "RC2014 - MS Basic Loader",CR,LF
        DEFM    "z88dk - feilipu",CR,LF,0

.SIGNON2
        DEFM    CR,LF
        DEFM    "Cold | Warm start (C|W) ? ",0

;==============================================================================
;
; Z80 INTERRUPT VECTOR PROTOTYPE ASSIGNMENTS
;

EXTERN  NULL_NMI                            ; RETN
EXTERN  UFERR                               ; User Function undefined (RSTnn) error

PUBLIC  RST_00, RST_08, RST_10; RST_18
PUBLIC  RST_20, RST_28, RST_30

PUBLIC  INT_INT, INT_NMI

DEFC    RST_00      =       INIT            ; Initialise, should never get here
DEFC    RST_08      =       TXA             ; TX character, loop until space
DEFC    RST_10      =       RXA             ; RX character, loop until byte
;       RST_18      =       RXA_CHK         ; Check receive buffer status, return # bytes available
DEFC    RST_20      =       UFERR           ; User Function undefined (RST20)
DEFC    RST_28      =       UFERR           ; User Function undefined (RST28)
DEFC    RST_30      =       UFERR           ; User Function undefined (RST30)
DEFC    INT_INT     =       uart_interrupt  ; UART interrupt
DEFC    INT_NMI     =       NULL_NMI        ; RETN

;==============================================================================
