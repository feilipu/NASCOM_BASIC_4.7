;==================================================================================
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
;==================================================================================
;
; Z180 Register Mnemonics
;

IO_BASE         .EQU    $00     ; Internal I/O Base Address (ICR) <<< SET THIS AS DESIRED >>>

CNTLA0          .EQU    IO_BASE+$00     ; ASCI Control Reg A Ch 0
CNTLA1          .EQU    IO_BASE+$01     ; ASCI Control Reg A Ch 1
CNTLB0          .EQU    IO_BASE+$02     ; ASCI Control Reg B Ch 0
CNTLB1          .EQU    IO_BASE+$03     ; ASCI Control Reg B Ch 1
STAT0           .EQU    IO_BASE+$04     ; ASCI Status  Reg   Ch 0
STAT1           .EQU    IO_BASE+$05     ; ASCI Status  Reg   Ch 1
TDR0            .EQU    IO_BASE+$06     ; ASCI Tx Data Reg   Ch 0
TDR1            .EQU    IO_BASE+$07     ; ASCI Tx Data Reg   Ch 1
RDR0            .EQU    IO_BASE+$08     ; ASCI Rx Data Reg   Ch 0
RDR1            .EQU    IO_BASE+$09     ; ASCI Rx Data Reg   Ch 1

ASEXT0          .EQU    IO_BASE+$12     ; ASCI Extension Control Reg Ch 0 (Z8S180 & higher Only)
ASEXT1          .EQU    IO_BASE+$13     ; ASCI Extension Control Reg Ch 1 (Z8S180 & higher Only)

ASTC0L          .EQU    IO_BASE+$1A     ; ASCI Time Constant Ch 0 Low (Z8S180 & higher Only)
ASTC0H          .EQU    IO_BASE+$1B     ; ASCI Time Constant Ch 0 High (Z8S180 & higher Only)
ASTC1L          .EQU    IO_BASE+$1C     ; ASCI Time Constant Ch 1 Low (Z8S180 & higher Only)
ASTC1H          .EQU    IO_BASE+$1D     ; ASCI Time Constant Ch 1 High (Z8S180 & higher Only)

CNTR            .EQU    IO_BASE+$0A     ; CSI/O Control Reg
TRDR            .EQU    IO_BASE+$0B     ; CSI/O Tx/Rx Data Reg

TMDR0L          .EQU    IO_BASE+$0C     ; Timer Data Reg Ch 0 Low
TMDR0H          .EQU    IO_BASE+$0D     ; Timer Data Reg Ch 0 High
RLDR0L          .EQU    IO_BASE+$0E     ; Timer Reload Reg Ch 0 Low
RLDR0H          .EQU    IO_BASE+$0F     ; Timer Reload Reg Ch 0 High
TCR             .EQU    IO_BASE+$10     ; Timer Control Reg

TMDR1L          .EQU    IO_BASE+$14     ; Timer Data Reg Ch 1 Low
TMDR1H          .EQU    IO_BASE+$15     ; Timer Data Reg Ch 1 High
RLDR1L          .EQU    IO_BASE+$16     ; Timer Reload Reg Ch 1 Low
RLDR1H          .EQU    IO_BASE+$17     ; Timer Reload Reg Ch 1 High

FRC             .EQU    IO_BASE+$18     ; Free-Running Counter

CMR             .EQU    IO_BASE+$1E     ; CPU Clock Multiplier Reg (Z8S180 & higher Only)
CCR             .EQU    IO_BASE+$1F     ; CPU Control Reg (Z8S180 & higher Only)

SAR0L           .EQU    IO_BASE+$20     ; DMA Source Addr Reg Ch0-Low
SAR0H           .EQU    IO_BASE+$21     ; DMA Source Addr Reg Ch0-High
SAR0B           .EQU    IO_BASE+$22     ; DMA Source Addr Reg Ch0-Bank
DAR0L           .EQU    IO_BASE+$23     ; DMA Dest Addr Reg Ch0-Low
DAR0H           .EQU    IO_BASE+$24     ; DMA Dest Addr Reg Ch0-High
DAR0B           .EQU    IO_BASE+$25     ; DMA Dest ADDR REG CH0-Bank
BCR0L           .EQU    IO_BASE+$26     ; DMA Byte Count Reg Ch0-Low
BCR0H           .EQU    IO_BASE+$27     ; DMA Byte Count Reg Ch0-High
MAR1L           .EQU    IO_BASE+$28     ; DMA Memory Addr Reg Ch1-Low
MAR1H           .EQU    IO_BASE+$29     ; DMA Memory Addr Reg Ch1-High
MAR1B           .EQU    IO_BASE+$2A     ; DMA Memory Addr Reg Ch1-Bank
IAR1L           .EQU    IO_BASE+$2B     ; DMA I/O Addr Reg Ch1-Low
IAR1H           .EQU    IO_BASE+$2C     ; DMA I/O Addr Reg Ch2-High
BCR1L           .EQU    IO_BASE+$2E     ; DMA Byte Count Reg Ch1-Low
BCR1H           .EQU    IO_BASE+$2F     ; DMA Byte Count Reg Ch1-High
DSTAT           .EQU    IO_BASE+$30     ; DMA Status Reg
DMODE           .EQU    IO_BASE+$31     ; DMA Mode Reg
DCNTL           .EQU    IO_BASE+$32     ; DMA/Wait Control Reg

IL              .EQU    IO_BASE+$33     ; INT Vector Low Reg
ITC             .EQU    IO_BASE+$34     ; INT/TRAP Control Reg

RCR             .EQU    IO_BASE+$36     ; Refresh Control Reg

CBR             .EQU    IO_BASE+$38     ; MMU Common Base Reg
BBR             .EQU    IO_BASE+$39     ; MMU Bank Base Reg
CBAR            .EQU    IO_BASE+$3A     ; MMU Common/Bank Area Reg

OMCR            .EQU    IO_BASE+$3E     ; Operation Mode Control Reg
ICR             .EQU    IO_BASE+$3F     ; I/O Control Reg


;==================================================================================
;
; Interrupt vectors (offsets) for Z180/HD64180 internal interrupts
;

VECTOR_BASE     .EQU   $80      ; Vector Base address (IL) <<< SET THIS AS DESIRED >>>

VECTOR_INT1     .EQU   VECTOR_BASE+$00    ; external /INT1 
VECTOR_INT2     .EQU   VECTOR_BASE+$02    ; external /INT2 
VECTOR_PRT0     .EQU   VECTOR_BASE+$04    ; PRT channel 0 
VECTOR_PRT1     .EQU   VECTOR_BASE+$06    ; PRT channel 1 
VECTOR_DMA0     .EQU   VECTOR_BASE+$08    ; DMA channel 0 
VECTOR_DMA1     .EQU   VECTOR_BASE+$0A    ; DMA Channel 1 
VECTOR_CSIO     .EQU   VECTOR_BASE+$0C    ; Clocked serial I/O 
VECTOR_ASCI0    .EQU   VECTOR_BASE+$0E    ; Async channel 0 
VECTOR_ASCI1    .EQU   VECTOR_BASE+$10    ; Async channel 1

;==================================================================================
;
; Some bit definitions used with the Z-180 on-chip peripherals:
;

; ASCI Control Reg A (CNTLAn)

SER_MPE         .EQU   $80    ; Multi Processor Enable
SER_RE          .EQU   $40    ; Receive Enable
SER_TE          .EQU   $20    ; Transmit Enable
SER_RTS0        .EQU   $10    ; _RTS Request To Send
SER_EFR         .EQU   $08    ; Error Flag Reset

SER_7N1         .EQU   $00    ; 7 Bits No Parity 1 Stop Bit
SER_7N2         .EQU   $01    ; 7 Bits No Parity 2 Stop Bits
SER_7P1         .EQU   $02    ; 7 Bits    Parity 1 Stop Bit
SER_7P2         .EQU   $03    ; 7 Bits    Parity 2 Stop Bits
SER_8N1         .EQU   $04    ; 8 Bits No Parity 1 Stop Bit
SER_8N2         .EQU   $05    ; 8 Bits No Parity 2 Stop Bits
SER_8P1         .EQU   $06    ; 8 Bits    Parity 1 Stop Bit
SER_8P2         .EQU   $07    ; 8 Bits    Parity 2 Stop Bits

; ASCI Control Reg B (CNTLBn)
                              ; BAUD Rate = PHI / PS / SS / DR

SER_MPBT        .EQU   $80    ; Multi Processor Bit Transmit
SER_MP          .EQU   $40    ; Multi Processor
SER_PS          .EQU   $20    ; Prescale PHI by 10 (PS 0) or 30 (PS 1)
SER_PEO         .EQU   $10    ; Parity Even or Odd
SER_DR          .EQU   $08    ; Divide SS by 16 (DR 0) or 64 (DR 1)

SER_SS_DIV_1    .EQU   $00    ; Divide PS by  1
SER_SS_DIV_2    .EQU   $01    ; Divide PS by  2
SER_SS_DIV_4    .EQU   $02    ; Divide PS by  4
SER_SS_DIV_8    .EQU   $03    ; Divide PS by  8
SER_SS_DIV_16   .EQU   $04    ; Divide PS by 16
SER_SS_DIV_32   .EQU   $05    ; Divide PS by 32
SER_SS_DIV_64   .EQU   $06    ; Divide PS by 64
SER_SS_EXT      .EQU   $07    ; External Clock Source <= PHI / 40

; ASCI Status Reg (STATn)

SER_RDRF        .EQU   $80    ; Receive Data Register Full
SER_OVRN        .EQU   $40    ; Overrun (Received Byte)
SER_PE          .EQU   $20    ; Parity Error (Received Byte)
SER_FE          .EQU   $10    ; Framing Error (Received Byte)
SER_RIE         .EQU   $08    ; Receive Interrupt Enabled
SER_DCD0        .EQU   $04    ; _DCD0 Data Carrier Detect USART0
SER_CTS1        .EQU   $04    ; _CTS1 Clear To Send USART1
SER_TDRE        .EQU   $02    ; Transmit Data Register Empty
SER_TIE         .EQU   $01    ; Transmit Interrupt Enabled

; CPU Clock Multiplier Reg (CMR) (Z8S180 & higher Only)

CMR_X2          .EQU   $80    ; CPU x2 XTAL Multiplier Mode
CMR_LN_XTAL     .EQU   $40    ; Low Noise Crystal 

; CPU Control Reg (CCR) (Z8S180 & higher Only)

CCR_XTAL_X2     .EQU   $80    ; PHI = XTAL Mode
CCR_STANDBY     .EQU   $40    ; STANDBY after SLEEP
CCR_BREXT       .EQU   $20    ; Exit STANDBY on BUSREQ
CCR_LNPHI       .EQU   $10    ; Low Noise PHI (30% Drive)
CCR_IDLE        .EQU   $08    ; IDLE after SLEEP
CCR_LNIO        .EQU   $04    ; Low Noise I/O Signals (30% Drive)
CCR_LNCPUCTL    .EQU   $02    ; Low Noise CPU Control Signals (30% Drive)
CCR_LNAD        .EQU   $01    ; Low Noise Address and Data Signals (30% Drive)

; DMA/Wait Control Reg (DCNTL)

DCNTL_MWI1      .EQU   $80    ; Memory Wait Insertion 1 (1 Default)
DCNTL_MWI0      .EQU   $40    ; Memory Wait Insertion 0 (1 Default)
DCNTL_IWI1      .EQU   $20    ; I/O Wait Insertion 1 (1 Default)
DCNTL_IWI0      .EQU   $10    ; I/O Wait Insertion 0 (1 Default)
DCNTL_DMS1      .EQU   $08    ; DMA Request Sense 1
DCNTL_DMS0      .EQU   $04    ; DMA Request Sense 0
DCNTL_DIM1      .EQU   $02    ; DMA Channel 1 I/O & Memory Mode
DCNTL_DIM0      .EQU   $01    ; DMA Channel 1 I/O & Memory Mode


; INT/TRAP Control Register (ITC)

ITC_ITE2        .EQU   $04    ; Interrupt Enable #2
ITC_ITE1        .EQU   $02    ; Interrupt Enable #1
ITC_ITE0        .EQU   $01    ; Interrupt Enable #0 (1 Default)

; Refresh Control Reg (RCR)

RCR_REFE        .EQU   $80    ; DRAM Refresh Enable
RCR_REFW        .EQU   $40    ; DRAM Refresh 2 or 3 Wait states

; Operation Mode Control Reg (OMCR)

OMCR_M1E        .EQU   $80    ; M1 Enable (0 Disabled)
OMCR_M1TE       .EQU   $40    ; M1 Temporary Enable
OMCR_IOC        .EQU   $20    ; IO Control (1 64180 Mode)

;==================================================================================
;
; Some definitions used with the YAZ-180 on-board peripherals:
;

; BREAK for Single Step Mode
BREAK           .EQU    $2000      ; Any value written to $2000, halts CPU

; 82C55 PIO Port Definitions

PIO             .EQU    $4000      ; Base Address for 82C55
PIOA            .EQU    PIO+$00    ; Address for Port A
PIOB            .EQU    PIO+$01    ; Address for Port B
PIOC            .EQU    PIO+$02    ; Address for Port C
PIOCNTL         .EQU    PIO+$03    ; Address for Control Byte

; PIO Mode Definitions

; Mode 0 - Basic Input / Output

PIOCNTL00       .EQU    $80        ; A->, B->, CH->, CL->
PIOCNTL01       .EQU    $81        ; A->, B->, CH->, ->CL
PIOCNTL0        .EQU    $82        ; A->, ->B, CH->, CL->
PIOCNTL03       .EQU    $83        ; A->, ->B, CH->, ->CL

PIOCNTL04       .EQU    $88        ; A->, B->, ->CH, CL->
PIOCNTL05       .EQU    $89        ; A->, B->, ->CH, ->CL
PIOCNTL06       .EQU    $8A        ; A->, ->B, ->CH, CL->
PIOCNTL07       .EQU    $8B        ; A->, ->B, ->CH, ->CL

PIOCNTL08       .EQU    $90        ; ->A, B->, CH->, CL->
PIOCNTL09       .EQU    $91        ; ->A, B->, CH->, ->CL
PIOCNTL10       .EQU    $92        ; ->A, ->B, CH->, CL->
PIOCNTL11       .EQU    $83        ; ->A, ->B, CH->, ->CL

PIOCNTL12       .EQU    $98        ; ->A, B->, ->CH, CL-> (Default Setting)
PIOCNTL13       .EQU    $99        ; ->A, B->, ->CH, ->CL
PIOCNTL14       .EQU    $9A        ; ->A, ->B, ->CH, CL->
PIOCNTL15       .EQU    $9B        ; ->A, ->B, ->CH, ->CL

; Mode 1 - Strobed Input / Output
; TBA Later

; Mode 2 - Strobed Bidirectional Bus Input / Output
; TBA Later

; Am9511A-1 FPU Port Address

FPU             .EQU    $C000      ; Base Address for Am9511A
FPUDATA         .EQU    FPU+$00    ; FPU Data Port
FPUCNTL         .EQU    FPU+$01    ; FPU Control Port


;==================================================================================
;
; DEFINES SECTION
;

ROMSTART        .EQU     $0000 ; Bottom of FLASH
ROMSTOP         .EQU     $1FFF ; Top of FLASH

RAMSTART_CA0    .EQU     $2000 ; Bottom of Common 0 RAM
RAMSTOP_CA0     .EQU     $3FFF ; Top of Common 0 RAM

RAMSTART_BANK   .EQU     $4000 ; Bottom of Banked RAM
RAMSTOP_BANK    .EQU     $7FFF ; Top of Banked RAM

RAMSTART_CA1    .EQU     $8000 ; Bottom of Common 1 RAM
RAMSTOP_CA1     .EQU     $FFFF ; Top of Common 1 RAM

RAMSTART        .EQU     RAMSTART_CA0
RAMSTOP         .EQU     RAMSTOP_CA1

INT0_FPU        .EQU     $3800 ; start of the FPU Interrupt 1 asm code (RAM)

                               ; Top of BASIC line input buffer (CURPOS WRKSPC+0ABH)
                               ; so it is "free ram" when BASIC resets
                               ; set BASIC Work space WRKSPC $8000, in CA1 RAM
WRKSPC          .EQU     $RAMSTART_CA1 

TEMPSTACK       .EQU     WRKSPC+$AB

CR              .EQU     0DH
LF              .EQU     0AH

;==================================================================================
;
; VARIABLES SECTION
;

SER_RX0_BUFSIZE .EQU     $FF   ; FIXED Rx buffer size, 256 Bytes, no range checking
SER_TX0_BUFSIZE .EQU     $FF   ; FIXED Tx buffer size, 256 Bytes, no range checking
     
serRx0Buf       .EQU     RAMSTART_CA0 ; must start on 0xnn00 for low byte roll-over
serTx0Buf       .EQU     serRx0Buf+SER_RX0_BUFSIZE+1
serRx0InPtr     .EQU     serTx0Buf+SER_TX0_BUFSIZE+1
serRx0OutPtr    .EQU     serRx0InPtr+2
serTx0InPtr     .EQU     serRx0OutPtr+2
serTx0OutPtr    .EQU     serTx0InPtr+2
serRx0BufUsed   .EQU     serTx0OutPtr+2
serTx0BufUsed   .EQU     serRx0BufUsed+1
basicStarted    .EQU     serTx0BufUsed+1   ; end of ASCI0 stuff is $220A

;==================================================================================
;
; Z80 INTERRUPT VECTOR SECTION 
;

;------------------------------------------------------------------------------
; RESET - Reset

                .ORG     0000H
RST00:          DI                  ; Disable interrupts
                JP       INIT       ; Initialize Hardware and go

;------------------------------------------------------------------------------
; RST08 - TX a character over ASCI

                .ORG     0008H
RST08:          JP       TX0

;------------------------------------------------------------------------------
; RST10 - RX a character over ASCI Channel [Console], hold here until char ready.

                .ORG     0010H
RST10:          JP       RX0

;------------------------------------------------------------------------------
; RST18 - Check serial status

                .ORG     0018H
RST18:          JP       RX0_CHK
             
;------------------------------------------------------------------------------
; RST 20

                .ORG     0020H
RST20:          RET                 ; just return

;------------------------------------------------------------------------------
; RST 28

                .ORG     0028H
RST28:          RET                 ; just return

;------------------------------------------------------------------------------
; RST 30
;
                .ORG     0030H
RST30:          RET                 ; just return

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR INT0 [ with IM 1 ]

                .ORG     0038H
RST38:          JP       INT0_FPU   ; Jump into FPU Interrupt

;------------------------------------------------------------------------------
; NMI - INTERRUPT VECTOR NMI

                .ORG     0066H
NMI:            RETN                ; just return
  

;==================================================================================
;
; Z180 INTERRUPT VECTOR SECTION 
;

;------------------------------------------------------------------------------
; INTERRUPT VECTOR ASCI Channel 0 [ Vector at $8E ]

                .ORG     VECTOR_ASCI0
                JP       ASCI0_INTERRUPT

;==================================================================================
;
; CODE SECTION
;

                .ORG     0100H                              
ASCI0_INTERRUPT:

        push af
        push hl
                                    ; start doing the Rx stuff

        in0 a, (STAT0)              ; load the ASCI0 status register
        tst SER_RDRF                ; test whether we have received on ASCI0
        jr z, ASCI0_TX_CHECK        ; if not, go check for bytes to transmit

ASCI0_RX_GET:

        in0 l, (RDR0)               ; move Rx byte from the ASCI0 to l

        ld a, (serRx0BufUsed)       ; get the number of bytes in the Rx buffer      
        cp SER_RX0_BUFSIZE          ; check whether there is space in the buffer
        jr nc, ASCI0_RX_CHECK       ; buffer full, check whether we need to drain H/W FIFO

        ld a, l                     ; get Rx byte from l
        ld hl, (serRx0InPtr)        ; get the pointer to where we poke
        ld (hl), a                  ; write the Rx byte to the serRx0InPtr target

        inc l                       ; move the Rx pointer low byte along
        ld (serRx0InPtr), hl        ; write where the next byte should be poked

        ld hl, serRx0BufUsed
        inc (hl)                    ; atomically increment Rx buffer count

ASCI0_RX_CHECK:
                                    ; Z8S180 has 4 byte Rx H/W FIFO
        in0 a, (STAT0)              ; load the ASCI0 status register
        tst SER_RDRF                ; test whether we have received on ASCI0
        jr nz, ASCI0_RX_GET         ; if still more bytes in H/W FIFO, get them

ASCI0_TX_CHECK:                     ; now start doing the Tx stuff

        ld a, (serTx0BufUsed)       ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jr z, ASCI0_TX_TIE0_CLEAR   ; if the count is zero, then disable the Tx Interrupt

        in0 a, (STAT0)              ; load the ASCI0 status register
        tst SER_TDRE                ; test whether we can transmit on ASCI0
        jr z, ASCI0_TX_END          ; if not, then end

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
RX0_WAIT_FOR_BYTE:

        ld a, (serRx0BufUsed)       ; get the number of bytes in the Rx buffer

        or a                        ; see if there are zero bytes available
        jr z, RX0_WAIT_FOR_BYTE     ; wait, if there are no bytes available
        
        push hl                     ; Store HL so we don't clobber it

        ld hl, (serRx0OutPtr)       ; get the pointer to place where we pop the Rx byte
        ld a, (hl)                  ; get the Rx byte
        push af                     ; save the Rx byte on stack

        inc l                       ; move the Rx pointer low byte along
        ld (serRx0OutPtr), hl       ; write where the next byte should be popped

        ld hl, serRx0BufUsed
        dec (hl)                    ; atomically decrement Rx count

        pop af                      ; get the Rx byte from stack
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
        tst SER_TDRE                ; test whether we can transmit on ASCI0
        jr z, TX0_BUFFER_OUT        ; if not, so abandon immediate Tx
        
        ld a, l                     ; Retrieve Tx character for immediate Tx
        out0 (TDR0), a              ; output the Tx byte to the ASCI0
        
        jr TX0_CLEAN_UP             ; and just complete

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

        in0 a, (STAT0)              ; load the ASCI0 status register
        tst SER_TIE                 ; test whether ASCI0 interrupt is set        
        jr nz, TX0_CLEAN_UP         ; if so then just clean up        

        di                          ; critical section begin
        in0 a, (STAT0)              ; so get the ASCI status register   
        or SER_TIE                  ; mask in (enable) the Tx Interrupt
        out0 (STAT0), a             ; set the ASCI status register
        ei                          ; critical section end

TX0_CLEAN_UP:

        pop hl                      ; recover HL
        ret

;------------------------------------------------------------------------------
RX0_CHK:       LD        A,(serRx0BufUsed)
               CP        $0
               RET

;------------------------------------------------------------------------------
PRINT:         LD        A,(HL)          ; Get character
               OR        A               ; Is it $00 ?
               RET       Z               ; Then RETurn on terminator
               RST       08H             ; Print it
               INC       HL              ; Next Character
               JR        PRINT           ; Continue until $00
               RET

;------------------------------------------------------------------------------
HEX_START:      
            ld hl, initString
            call PRINT
            
            ld c,0          ; non zero c is our ESA flag

HEX_WAIT_COLON:
            RST 10H         ; Rx byte
            cp ':'          ; wait for ':'
            jr nz, HEX_WAIT_COLON
            ld hl, 0        ; reset hl to compute checksum
            call HEX_READ_BYTE  ; read byte count
            ld b, a         ; store it in b
            call HEX_READ_BYTE  ; read upper byte of address
            ld d, a         ; store in d
            call HEX_READ_BYTE  ; read lower byte of address
            ld e, a         ; store in e
            call HEX_READ_BYTE  ; read record type
            cp 02           ; check if record type is 02 (ESA)
            jr z, HEX_ESA_DATA
            cp 01           ; check if record type is 01 (end of file)
            jr z, HEX_END_LOAD
            cp 00           ; check if record type is 00 (data)
            jr nz, HEX_INVAL_TYPE ; if not, error
HEX_READ_DATA:
            ld a, '*'       ; "*" per byte loaded  # DEBUG
            call TX0        ; Print it             # DEBUG
            call HEX_READ_BYTE
            ld (de), a      ; write the byte at the RAM address
            inc de
            djnz HEX_READ_DATA  ; if b non zero, loop to get more data
HEX_READ_CHKSUM:
            call HEX_READ_BYTE  ; read checksum, but we don't need to keep it
            ld a, l         ; lower byte of hl checksum should be 0
            or a
            jr nz, HEX_BAD_CHK  ; non zero, we have an issue
            ld a, '#'       ; "#" per line loaded
            call TX0        ; Print it
            ld a, CR        ; CR                   # DEBUG
            call TX0        ; Print it             # DEBUG
            ld a, LF        ; LF                   # DEBUG
            call TX0        ; Print it             # DEBUG
            jr HEX_WAIT_COLON

HEX_ESA_DATA:
            in0 a, (BBR)    ; grab the current Bank Base Value
            ld c, a         ; store BBR for later recovery
            call HEX_READ_BYTE  ; get high byte of ESA
            out0 (BBR), a   ; write it to the BBR  
            call HEX_READ_BYTE  ; get low byte of ESA, abandon it, but calc checksum
            jr HEX_READ_CHKSUM  ; calculate checksum

HEX_END_LOAD:
            call HEX_BBR_RESTORE   ; clean up the BBR
            ld hl, LoadOKStr
            call PRINT
            jp WARMSTART    ; ready to run our loaded program from Basic
            
HEX_INVAL_TYPE:
            call HEX_BBR_RESTORE   ; clean up the BBR
            ld hl, invalidTypeStr
            call PRINT
            jp START        ; go back to start

HEX_BAD_CHK:
            call HEX_BBR_RESTORE   ; clean up the BBR
            ld hl, badCheckSumStr
            call PRINT
            jp START        ; go back to start

HEX_BBR_RESTORE:
            ld a, c         ; get our BBR back
            ret z           ; if it is zero, chances are we don't need it
            out0 (BBR), a   ; write it to the BBR
            ret

HEX_READ_BYTE:              ; Returns byte in a, checksum in hl
            push bc
            RST 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, HEX_READ_NBL2 ; if a<10 read the second nibble
            sub 7           ; else subtract 'A'-'0' (17) and add 10
HEX_READ_NBL2:
            rlca            ; shift accumulator left by 4 bits
            rlca
            rlca
            rlca
            ld c, a         ; temporarily store the first nibble in c
            RST 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, HEX_READ_END  ; if a<10 finalize
            sub 7           ; else subtract 'A' (17) and add 10
HEX_READ_END:
            or c            ; assemble two nibbles into one byte in a
            ld b, 0         ; add the byte read to hl (for checksum)
            ld c, a
            add hl, bc
            pop bc
            ret             ; return the byte read in a


;------------------------------------------------------------------------------
INIT:
                                         ; Set I/O Control Reg (ICR)
               LD        A,IO_BASE       ; ICR = $00 [xx00 0000] for I/O Registers at $00 - $3F
               OUT0      (ICR),A         ; Standard I/O Mapping (0 Enabled)

                                         ; Set interrupt vector base (IL)
               LD        A,VECTOR_BASE   ; IL = $80 [001x xxxx] for Vectors at $80 - $90
               OUT0      (IL),A          ; Output to the Interrupt Vector Low reg
                                        
               IM        1               ; Interrupt mode 1 for INT0 (used for FPU)
                     
               XOR       A               ; Zero Accumulator

                                         ; Clear Refresh Control Reg (RCR)
               OUT0      (RCR),A         ; DRAM Refresh Enable (0 Disabled)

               OUT0      (TCR),A         ; Disable PRT downcounting

                                         ; Set Operation Mode Control Reg (OMCR)
                                         ; Disable M1, disable 64180 I/O _RD Mode
               OUT0      (OMCR),A        ; X80 Mode (M1 Disabled, IOC Disabled)

                                         ; Set INT/TRAP Control Register (ITC)
               LD        A, ITC_ITE0     ; Enable (default) Interrupt INT0 for FPU               
               OUT0      (ITC),A         ; Enable external interrupt INT0 

                                         ; Set internal clock = crystal x 2 = 36.864MHz
                                         ; if using ZS8180 or Z80182 at High-Speed
               LD        A,CMR_X2        ; Set Hi-Speed flag
               OUT0      (CMR),A         ; CPU Clock Multiplier Reg (CMR)

  ;                                      ; Bypass PHI = internal clock / 2
  ;                                      ; if using ZS8180 or Z80182 at High-Speed
  ;            LD        A,CCR_XTAL_X2   ; Set Hi-Speed flag: PHI = internal clock
  ;            OUT0      (CCR),A         ; CPU Control Reg (CCR)

               EX        (SP),IY         ; (settle)
               EX        (SP),IY         ; (settle)
               
                                         ; DMA/Wait Control Reg Set I/O Wait States
               LD A, DCNTL_IWI1 | DCNTL_IWI0
               OUT0      (DCNTL),A       ; 0 Memory Wait & 4 I/O Wait

                                         ; Set Logical Addresses
                                         ; $8000-$FFFF RAM CA1 -> 80H
                                         ; $4000-$7FFF RAM BANK -> 04H
                                         ; $2000-$3FFF RAM CA0
                                         ; $0000-$1FFF Flash CA0
               LD        A,84H           ; Set New Common / Bank Areas
               OUT0      (CBAR),A        ; for RAM

                                         ; Physical Addresses
               LD        A,78H           ; Set Common 1 Area Physical $80000 -> 78H
               OUT0      (CBR),A
               
               LD        A,3CH           ; Set Bank Area Physical $40000 -> 3CH
               OUT0      (BBR),A

               LD        HL,TEMPSTACK    ; Temp stack
               LD        SP,HL           ; Set up a temporary stack

               LD        HL,serRx0Buf    ; Initialise Rx Buffer
               LD        (serRx0InPtr),HL
               LD        (serRx0OutPtr),HL

               LD        HL,serTx0Buf    ; Initialise Tx Buffer
               LD        (serTx0InPtr),HL
               LD        (serTx0OutPtr),HL              

               XOR       A               ; 0 the accumulator
               LD        (serRx0BufUsed),A
               LD        (serTx0BufUsed),A

                                         ; load the default ASCI configuration
                                         ; 
                                         ; BAUD = 115200 8n1
                                         ; receive enabled
                                         ; transmit enabled                                         
                                         ; receive interrupt enabled
                                         ; transmit interrupt disabled
                                         
               LD        A,SER_RE|SER_TE|SER_8N1
               OUT0      (CNTLA0),A      ; output to the ASCI0 control A reg

                                         ; PHI / PS / SS / DR = BAUD Rate
                                         ; PHI = 18.432MHz
                                         ; BAUD = 115200 = 18432000 / 10 / 1 / 16 
                                         ; PS 0, SS_DIV_1 0, DR 0           
               XOR        A              ; BAUD = 115200
               OUT0      (CNTLB0),A      ; output to the ASCI0 control B reg
                              
               LD        A,SER_RIE       ; receive interrupt enabled
               OUT0      (STAT0),A       ; output to the ASCI0 status reg

                                         ; Set up 82C55 PIO in Mode 0 #12
               LD        BC,PIOCNTL      ; 82C55 CNTL address in bc
               LD        A,PIOCNTL12     ; Set Mode 12 ->A, B->, ->CH, CL->
               OUT       (C),A           ; output to the PIO control reg
               
               LD        A,$C9           ; load the RET instruction, temporarily
               LD        (INT0_FPU),A    ; at the location of FPU code

               EI                        ; enable interrupts

START:                                     
               LD        HL,SIGNON1      ; Sign-on message
               CALL      PRINT           ; Output string              
               LD        A,(basicStarted); Check the BASIC STARTED flag
               CP        'Y'             ; to see if this is power-up
               JR        NZ,COLDSTART    ; If not BASIC started then always do cold start
               LD        HL,SIGNON2      ; Cold/warm message
               CALL      PRINT           ; Output string
CORW:
               CALL      RX0
               AND       %11011111       ; lower to uppercase
               CP        'H'             ; are we trying to load an Intel HEX program?
               JP        Z, HEX_START    ; then jump to HexLoadr
               CP        'C'
               JR        NZ, CHECKWARM
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
COLDSTART:     LD        A,'Y'           ; Set the BASIC STARTED flag
               LD        (basicStarted),A
               JP        $0380           ; <<<< Start Basic COLD:
CHECKWARM:
               CP        'W'
               JR        NZ, CORW
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
WARMSTART:
               JP        $0383           ; <<<< Start Basic WARM:

SIGNON1:       .BYTE     "YAZ180 - feilipu",CR,LF,0
SIGNON2:       .BYTE     CR,LF
               .BYTE     "Cold or Warm start, "
               .BYTE     "or Hexloadr (C|W|H) ? ",0

initString:        .BYTE CR,LF,"HexLoadr> "
                   .BYTE CR,LF,0

invalidTypeStr:    .BYTE "Inval Type",CR,LF,0
badCheckSumStr:    .BYTE "Chksum Error",CR,LF,0
LoadOKStr:         .BYTE "Done",CR,LF,0
                              
               .END
