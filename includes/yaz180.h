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
; DEFINES SECTION
;

ROMSTART        .EQU    $0000   ; Bottom of FLASH
ROMSTOP         .EQU    $1FFF   ; Top of FLASH

RAMSTART_CA0    .EQU    $2000   ; Bottom of Common 0 RAM
RAMSTOP_CA0     .EQU    $3FFF   ; Top of Common 0 RAM

RAMSTART_BANK   .EQU    $4000   ; Bottom of Banked RAM
RAMSTOP_BANK    .EQU    $7FFF   ; Top of Banked RAM

RAMSTART_CA1    .EQU    $8000   ; Bottom of Common 1 RAM
RAMSTOP_CA1     .EQU    $FFFF   ; Top of Common 1 RAM

RAMSTART        .EQU    RAMSTART_CA0
RAMSTOP         .EQU    RAMSTOP_CA1

STACKTOP        .EQU    $2FFE   ; start of a global stack (any pushes pre-decrement)

APU_CMD_BUFSIZE .EQU    $FF     ; FIXED CMD buffer size, 256 CMDs
APU_PTR_BUFSIZE .EQU    $FF     ; FIXED DATA POINTER buffer size, 128 POINTERs

SER_RX0_BUFSIZE .EQU    $FF     ; FIXED Rx buffer size, 256 Bytes, no range checking
SER_TX0_BUFSIZE .EQU    $FF     ; FIXED Tx buffer size, 256 Bytes, no range checking

SER_RX1_BUFSIZE .EQU    $FF     ; FIXED Rx buffer size, 256 Bytes, no range checking
SER_TX1_BUFSIZE .EQU    $FF     ; FIXED Tx buffer size, 256 Bytes, no range checking

;==============================================================================
;
; Interrupt vectors (offsets) for Z80 RST, INT0, and NMI interrupts
;

;   Squeezed between INT0 0x0038 and NMI 0x0066
Z80_VECTOR_PROTO    .EQU    $0040
Z80_VECTOR_SIZE     .EQU    $20

;   RAM vector address for Z80 RST Table
Z80_VECTOR_BASE     .EQU    RAMSTART_CA0    ; <<< SET THIS AS DESIRED >>>

;   Prototype Interrupt Service Routines - complete in main program
;
;   RST_08          .EQU    TX0         TX a character over ASCI0
;   RST_10          .EQU    RX0         RX a character over ASCI0, block no bytes available
;   RST_18          .EQU    RX0_CHK     Check ASCI0 status, return # bytes available
;   RST_20          .EQU    NULL_INT
;   RST_28          .EQU    NULL_INT
;   RST_30          .EQU    NULL_INT
;   INT_INT0        .EQU    NULL_INT
;   INT_NMI         .EQU    NULL_NMI

;   Z80 Interrupt Service Routine Addresses - rewrite as needed
RST_08_ADDR     .EQU    Z80_VECTOR_BASE+$01
RST_10_ADDR     .EQU    Z80_VECTOR_BASE+$05
RST_18_ADDR     .EQU    Z80_VECTOR_BASE+$09
RST_20_ADDR     .EQU    Z80_VECTOR_BASE+$0D
RST_28_ADDR     .EQU    Z80_VECTOR_BASE+$11
RST_30_ADDR     .EQU    Z80_VECTOR_BASE+$15
INT_INT0_ADDR   .EQU    Z80_VECTOR_BASE+$19
INT_NMI_ADDR    .EQU    Z80_VECTOR_BASE+$1D

;==============================================================================
;
; Interrupt vectors (offsets) for Z180/HD64180 external and internal interrupts
;

;   Locate the TRAP management just after NMI
Z180_VECTOR_TRAP    .EQU    $0070

;   Locate the prototypes just after TRAP code
Z180_VECTOR_PROTO   .EQU    $00C0
Z180_VECTOR_SIZE    .EQU    $12

Z180_VECTOR_IL      .EQU    $20     ; Vector Base address (IL)
                                    ; [001x xxxx] for Vectors at $nn20 - $nn3F

;   Start Z180 Vectors immediately after the Z80 Vector Table.                                    
Z180_VECTOR_BASE    .EQU    Z80_VECTOR_BASE-(Z80_VECTOR_BASE%$100)+Z180_VECTOR_IL

;   Prototype Interrupt Service Routines - provide these in your main program
;
;   INT_INT1        .EQU    NULL_RET        ; external /INT1
;   INT_INT2        .EQU    NULL_RET        ; external /INT2
;   INT_PRT0        .EQU    NULL_RET        ; PRT channel 0
;   INT_PRT1        .EQU    NULL_RET        ; PRT channel 1
;   INT_DMA0        .EQU    NULL_RET        ; DMA channel 0
;   INT_DMA1        .EQU    NULL_RET        ; DMA Channel 1
;   INT_CSIO        .EQU    NULL_RET        ; Clocked serial I/O
;   INT_ASCI0       .EQU    ASCI0_INTERRUPT ; Async channel 0
;   INT_ASCI1       .EQU    NULL_RET        ; Async channel 1

;   Z180 Interrupt Service Routine Addresses - rewrite as needed
INT_INT1_ADDR   .EQU    Z180_VECTOR_BASE+$00
INT_INT2_ADDR   .EQU    Z180_VECTOR_BASE+$02
INT_PRT0_ADDR   .EQU    Z180_VECTOR_BASE+$04
INT_PRT1_ADDR   .EQU    Z180_VECTOR_BASE+$06
INT_DMA0_ADDR   .EQU    Z180_VECTOR_BASE+$08
INT_DMA1_ADDR   .EQU    Z180_VECTOR_BASE+$0A
INT_CSIO_ADDR   .EQU    Z180_VECTOR_BASE+$0C
INT_ASCI0_ADDR  .EQU    Z180_VECTOR_BASE+$0E
INT_ASCI1_ADDR  .EQU    Z180_VECTOR_BASE+$10

;==============================================================================
;
; Z180 Register Mnemonics
;

Z180_IO_BASE    .EQU    $00 ; Internal I/O Base Address (ICR) <<< SET THIS AS DESIRED >>>

CNTLA0          .EQU    Z180_IO_BASE+$00    ; ASCI Control Reg A Ch 0
CNTLA1          .EQU    Z180_IO_BASE+$01    ; ASCI Control Reg A Ch 1
CNTLB0          .EQU    Z180_IO_BASE+$02    ; ASCI Control Reg B Ch 0
CNTLB1          .EQU    Z180_IO_BASE+$03    ; ASCI Control Reg B Ch 1
STAT0           .EQU    Z180_IO_BASE+$04    ; ASCI Status  Reg   Ch 0
STAT1           .EQU    Z180_IO_BASE+$05    ; ASCI Status  Reg   Ch 1
TDR0            .EQU    Z180_IO_BASE+$06    ; ASCI Tx Data Reg   Ch 0
TDR1            .EQU    Z180_IO_BASE+$07    ; ASCI Tx Data Reg   Ch 1
RDR0            .EQU    Z180_IO_BASE+$08    ; ASCI Rx Data Reg   Ch 0
RDR1            .EQU    Z180_IO_BASE+$09    ; ASCI Rx Data Reg   Ch 1

ASEXT0          .EQU    Z180_IO_BASE+$12    ; ASCI Extension Control Reg Ch 0 (Z8S180 & higher Only)
ASEXT1          .EQU    Z180_IO_BASE+$13    ; ASCI Extension Control Reg Ch 1 (Z8S180 & higher Only)

ASTC0L          .EQU    Z180_IO_BASE+$1A    ; ASCI Time Constant Ch 0 Low (Z8S180 & higher Only)
ASTC0H          .EQU    Z180_IO_BASE+$1B    ; ASCI Time Constant Ch 0 High (Z8S180 & higher Only)
ASTC1L          .EQU    Z180_IO_BASE+$1C    ; ASCI Time Constant Ch 1 Low (Z8S180 & higher Only)
ASTC1H          .EQU    Z180_IO_BASE+$1D    ; ASCI Time Constant Ch 1 High (Z8S180 & higher Only)

CNTR            .EQU    Z180_IO_BASE+$0A    ; CSI/O Control Reg
TRDR            .EQU    Z180_IO_BASE+$0B    ; CSI/O Tx/Rx Data Reg

TMDR0L          .EQU    Z180_IO_BASE+$0C    ; Timer Data Reg Ch 0 Low
TMDR0H          .EQU    Z180_IO_BASE+$0D    ; Timer Data Reg Ch 0 High
RLDR0L          .EQU    Z180_IO_BASE+$0E    ; Timer Reload Reg Ch 0 Low
RLDR0H          .EQU    Z180_IO_BASE+$0F    ; Timer Reload Reg Ch 0 High
TCR             .EQU    Z180_IO_BASE+$10    ; Timer Control Reg

TMDR1L          .EQU    Z180_IO_BASE+$14    ; Timer Data Reg Ch 1 Low
TMDR1H          .EQU    Z180_IO_BASE+$15    ; Timer Data Reg Ch 1 High
RLDR1L          .EQU    Z180_IO_BASE+$16    ; Timer Reload Reg Ch 1 Low
RLDR1H          .EQU    Z180_IO_BASE+$17    ; Timer Reload Reg Ch 1 High

FRC             .EQU    Z180_IO_BASE+$18    ; Free-Running Counter

CMR             .EQU    Z180_IO_BASE+$1E    ; CPU Clock Multiplier Reg (Z8S180 & higher Only)
CCR             .EQU    Z180_IO_BASE+$1F    ; CPU Control Reg (Z8S180 & higher Only)

SAR0L           .EQU    Z180_IO_BASE+$20    ; DMA Source Addr Reg Ch0-Low
SAR0H           .EQU    Z180_IO_BASE+$21    ; DMA Source Addr Reg Ch0-High
SAR0B           .EQU    Z180_IO_BASE+$22    ; DMA Source Addr Reg Ch0-Bank
DAR0L           .EQU    Z180_IO_BASE+$23    ; DMA Dest Addr Reg Ch0-Low
DAR0H           .EQU    Z180_IO_BASE+$24    ; DMA Dest Addr Reg Ch0-High
DAR0B           .EQU    Z180_IO_BASE+$25    ; DMA Dest ADDR REG CH0-Bank
BCR0L           .EQU    Z180_IO_BASE+$26    ; DMA Byte Count Reg Ch0-Low
BCR0H           .EQU    Z180_IO_BASE+$27    ; DMA Byte Count Reg Ch0-High
MAR1L           .EQU    Z180_IO_BASE+$28    ; DMA Memory Addr Reg Ch1-Low
MAR1H           .EQU    Z180_IO_BASE+$29    ; DMA Memory Addr Reg Ch1-High
MAR1B           .EQU    Z180_IO_BASE+$2A    ; DMA Memory Addr Reg Ch1-Bank
IAR1L           .EQU    Z180_IO_BASE+$2B    ; DMA I/O Addr Reg Ch1-Low
IAR1H           .EQU    Z180_IO_BASE+$2C    ; DMA I/O Addr Reg Ch2-High
BCR1L           .EQU    Z180_IO_BASE+$2E    ; DMA Byte Count Reg Ch1-Low
BCR1H           .EQU    Z180_IO_BASE+$2F    ; DMA Byte Count Reg Ch1-High
DSTAT           .EQU    Z180_IO_BASE+$30    ; DMA Status Reg
DMODE           .EQU    Z180_IO_BASE+$31    ; DMA Mode Reg
DCNTL           .EQU    Z180_IO_BASE+$32    ; DMA/Wait Control Reg

IL              .EQU    Z180_IO_BASE+$33    ; INT Vector Low Reg
ITC             .EQU    Z180_IO_BASE+$34    ; INT/TRAP Control Reg

RCR             .EQU    Z180_IO_BASE+$36    ; Refresh Control Reg

CBR             .EQU    Z180_IO_BASE+$38    ; MMU Common Base Reg
BBR             .EQU    Z180_IO_BASE+$39    ; MMU Bank Base Reg
CBAR            .EQU    Z180_IO_BASE+$3A    ; MMU Common/Bank Area Reg

OMCR            .EQU    Z180_IO_BASE+$3E    ; Operation Mode Control Reg
ICR             .EQU    Z180_IO_BASE+$3F    ; I/O Control Reg

;==============================================================================
;
; Some bit definitions used with the Z-180 on-chip peripherals:
;

;   ASCI Control Reg A (CNTLAn)

SER_MPE         .EQU    $80     ; Multi Processor Enable
SER_RE          .EQU    $40     ; Receive Enable
SER_TE          .EQU    $20     ; Transmit Enable
SER_RTS0        .EQU    $10     ; _RTS Request To Send
SER_EFR         .EQU    $08     ; Error Flag Reset

SER_8P2         .EQU    $07     ; 8 Bits    Parity 2 Stop Bits
SER_8P1         .EQU    $06     ; 8 Bits    Parity 1 Stop Bit
SER_8N2         .EQU    $05     ; 8 Bits No Parity 2 Stop Bits
SER_8N1         .EQU    $04     ; 8 Bits No Parity 1 Stop Bit
SER_7P2         .EQU    $03     ; 7 Bits    Parity 2 Stop Bits
SER_7P1         .EQU    $02     ; 7 Bits    Parity 1 Stop Bit
SER_7N2         .EQU    $01     ; 7 Bits No Parity 2 Stop Bits
SER_7N1         .EQU    $00     ; 7 Bits No Parity 1 Stop Bit

;   ASCI Control Reg B (CNTLBn)
                                ; BAUD Rate = PHI / PS / SS / DR

SER_MPBT        .EQU    $80     ; Multi Processor Bit Transmit
SER_MP          .EQU    $40     ; Multi Processor
SER_PS          .EQU    $20     ; Prescale PHI by 10 (PS 0) or 30 (PS 1)
SER_PEO         .EQU    $10     ; Parity Even or Odd
SER_DR          .EQU    $08     ; Divide SS by 16 (DR 0) or 64 (DR 1)

SER_SS_EXT      .EQU    $07     ; External Clock Source <= PHI / 40
SER_SS_DIV_64   .EQU    $06     ; Divide PS by 64
SER_SS_DIV_32   .EQU    $05     ; Divide PS by 32
SER_SS_DIV_16   .EQU    $04     ; Divide PS by 16
SER_SS_DIV_8    .EQU    $03     ; Divide PS by  8
SER_SS_DIV_4    .EQU    $02     ; Divide PS by  4
SER_SS_DIV_2    .EQU    $01     ; Divide PS by  2
SER_SS_DIV_1    .EQU    $00     ; Divide PS by  1

;   ASCI Status Reg (STATn)

SER_RDRF        .EQU   $80    ; Receive Data Register Full
SER_OVRN        .EQU   $40    ; Overrun (Received Byte)
SER_PE          .EQU   $20    ; Parity Error (Received Byte)
SER_FE          .EQU   $10    ; Framing Error (Received Byte)
SER_RIE         .EQU   $08    ; Receive Interrupt Enabled
SER_DCD0        .EQU   $04    ; _DCD0 Data Carrier Detect USART0
SER_CTS1        .EQU   $04    ; _CTS1 Clear To Send USART1
SER_TDRE        .EQU   $02    ; Transmit Data Register Empty
SER_TIE         .EQU   $01    ; Transmit Interrupt Enabled

;   CPU Clock Multiplier Reg (CMR) (Z8S180 & higher Only)

CMR_X2          .EQU   $80    ; CPU x2 XTAL Multiplier Mode
CMR_LN_XTAL     .EQU   $40    ; Low Noise Crystal 

;   CPU Control Reg (CCR) (Z8S180 & higher Only)

CCR_XTAL_X2     .EQU   $80    ; PHI = XTAL Mode
CCR_STANDBY     .EQU   $40    ; STANDBY after SLEEP
CCR_BREXT       .EQU   $20    ; Exit STANDBY on BUSREQ
CCR_LNPHI       .EQU   $10    ; Low Noise PHI (30% Drive)
CCR_IDLE        .EQU   $08    ; IDLE after SLEEP
CCR_LNIO        .EQU   $04    ; Low Noise I/O Signals (30% Drive)
CCR_LNCPUCTL    .EQU   $02    ; Low Noise CPU Control Signals (30% Drive)
CCR_LNAD        .EQU   $01    ; Low Noise Address and Data Signals (30% Drive)

;   DMA/Wait Control Reg (DCNTL)

DCNTL_MWI1      .EQU   $80    ; Memory Wait Insertion 1 (1 Default)
DCNTL_MWI0      .EQU   $40    ; Memory Wait Insertion 0 (1 Default)
DCNTL_IWI1      .EQU   $20    ; I/O Wait Insertion 1 (1 Default)
DCNTL_IWI0      .EQU   $10    ; I/O Wait Insertion 0 (1 Default)
DCNTL_DMS1      .EQU   $08    ; DMA Request Sense 1
DCNTL_DMS0      .EQU   $04    ; DMA Request Sense 0
DCNTL_DIM1      .EQU   $02    ; DMA Channel 1 I/O & Memory Mode
DCNTL_DIM0      .EQU   $01    ; DMA Channel 1 I/O & Memory Mode

;   INT/TRAP Control Register (ITC)

ITC_TRAP        .EQU   $80    ; TRAP Encountered
ITC_UFO         .EQU   $40    ; Unidentified Fetch Object
ITC_ITE2        .EQU   $04    ; Interrupt Enable #2
ITC_ITE1        .EQU   $02    ; Interrupt Enable #1
ITC_ITE0        .EQU   $01    ; Interrupt Enable #0 (1 Default)

;   Refresh Control Reg (RCR)

RCR_REFE        .EQU   $80    ; DRAM Refresh Enable
RCR_REFW        .EQU   $40    ; DRAM Refresh 2 or 3 Wait states
RCR_CYC1        .EQU   $02    ; Cycles x4
RCR_CYC0        .EQU   $01    ; Cycles x2 on base 10 T states

;   Operation Mode Control Reg (OMCR)

OMCR_M1E        .EQU   $80    ; M1 Enable (0 Disabled)
OMCR_M1TE       .EQU   $40    ; M1 Temporary Enable
OMCR_IOC        .EQU   $20    ; IO Control (1 64180 Mode)

;==============================================================================
;
; Some definitions used with the YAZ-180 on-board peripherals:
;

;   BREAK for Single Step Mode

BREAK           .EQU    $2000       ; Any value written $2000->$21FF, halts CPU

;   82C55 PIO Port Definitions

PIO             .EQU    $4000       ; Base Address for 82C55
PIOA            .EQU    PIO+$00     ; Address for Port A
PIOB            .EQU    PIO+$01     ; Address for Port B
PIOC            .EQU    PIO+$02     ; Address for Port C
PIOCNTL         .EQU    PIO+$03     ; Address for Control Byte

;   PIO Mode Definitions

;   Mode 0 - Basic Input / Output

PIOCNTL00       .EQU    $80     ; A->, B->, CH->, CL->
PIOCNTL01       .EQU    $81     ; A->, B->, CH->, ->CL
PIOCNTL0        .EQU    $82     ; A->, ->B, CH->, CL->
PIOCNTL03       .EQU    $83     ; A->, ->B, CH->, ->CL

PIOCNTL04       .EQU    $88     ; A->, B->, ->CH, CL->
PIOCNTL05       .EQU    $89     ; A->, B->, ->CH, ->CL
PIOCNTL06       .EQU    $8A     ; A->, ->B, ->CH, CL->
PIOCNTL07       .EQU    $8B     ; A->, ->B, ->CH, ->CL

PIOCNTL08       .EQU    $90     ; ->A, B->, CH->, CL->
PIOCNTL09       .EQU    $91     ; ->A, B->, CH->, ->CL
PIOCNTL10       .EQU    $92     ; ->A, ->B, CH->, CL->
PIOCNTL11       .EQU    $83     ; ->A, ->B, CH->, ->CL

PIOCNTL12       .EQU    $98     ; ->A, B->, ->CH, CL-> (Default Setting)
PIOCNTL13       .EQU    $99     ; ->A, B->, ->CH, ->CL
PIOCNTL14       .EQU    $9A     ; ->A, ->B, ->CH, CL->
PIOCNTL15       .EQU    $9B     ; ->A, ->B, ->CH, ->CL

;   Mode 1 - Strobed Input / Output
;   TBA Later

;   Mode 2 - Strobed Bidirectional Bus Input / Output
;   TBA Later

;   Am9511A-1 APU Port Definitions

APU             .EQU    $C000   ; Base Address for Am9511A
APUDATA         .EQU    APU+$00 ; APU Data Port
APUCNTL         .EQU    APU+$01 ; APU Control Port

APU_OP_ENT      .EQU    $40
APU_OP_REM      .EQU    $50
APU_OP_ENT16    .EQU    $40
APU_OP_ENT32    .EQU    $41
APU_OP_REM16    .EQU    $50
APU_OP_REM32    .EQU    $51

APU_CNTL_BUSY   .EQU    $80
APU_CNTL_SIGN   .EQU    $40
APU_CNTL_ZERO   .EQU    $20
APU_CNTL_DIV0   .EQU    $10
APU_CNTL_NEGRT  .EQU    $08
APU_CNTL_UNDFL  .EQU    $04
APU_CNTL_OVRFL  .EQU    $02
APU_CNTL_CARRY  .EQU    $01

APU_CNTL_ERROR  .EQU    $1E

;   General TTY

CTRLC           .EQU    $03     ; Control "C"
CTRLG           .EQU    $07     ; Control "G"
BKSP            .EQU    $08     ; Back space
LF              .EQU    $0A     ; Line feed
CS              .EQU    $0C     ; Clear screen
CR              .EQU    $0D     ; Carriage return
CTRLO           .EQU    $0F     ; Control "O"
CTRLQ	        .EQU	$11     ; Control "Q"
CTRLR           .EQU    $12     ; Control "R"
CTRLS           .EQU    $13     ; Control "S"
CTRLU           .EQU    $15     ; Control "U"
ESC             .EQU    $1B     ; Escape
DEL             .EQU    $7F     ; Delete

;==============================================================================
;
; DRIVER VARIABLES SECTION - CAO
;

;   Starting immediately after the Z180 Vector Table.
serRx0InPtr     .EQU    Z180_VECTOR_BASE+Z180_VECTOR_SIZE
serRx0OutPtr    .EQU    serRx0InPtr+2
serTx0InPtr     .EQU    serRx0OutPtr+2
serTx0OutPtr    .EQU    serTx0InPtr+2
serRx0BufUsed   .EQU    serTx0OutPtr+2
serTx0BufUsed   .EQU    serRx0BufUsed+1

basicStarted    .EQU    serTx0BufUsed+1

serRx1InPtr     .EQU    Z180_VECTOR_BASE+Z180_VECTOR_SIZE+$10
serRx1OutPtr    .EQU    serRx1InPtr+2
serTx1InPtr     .EQU    serRx1OutPtr+2
serTx1OutPtr    .EQU    serTx1InPtr+2
serRx1BufUsed   .EQU    serTx1OutPtr+2
serTx1BufUsed   .EQU    serRx1BufUsed+1

APUCMDInPtr     .EQU    Z180_VECTOR_BASE+Z180_VECTOR_SIZE+$20
APUCMDOutPtr    .EQU    APUCMDInPtr+2
APUPTRInPtr     .EQU    APUCMDOutPtr+2
APUPTROutPtr    .EQU    APUPTRInPtr+2
APUCMDBufUsed   .EQU    APUPTROutPtr+2
APUPTRBufUsed   .EQU    APUCMDBufUsed+1
APUStatus       .EQU    APUPTRBufUsed+1
APUError        .EQU    APUStatus+1

;   $nn60 -> $nnFF is slack memory.

;   I/O Buffers must start on 0xnn00 because we increment low byte to roll-over
BUFSTART_IO     .EQU    (Z180_VECTOR_BASE-(Z180_VECTOR_BASE%$100) + $100

serRx0Buf       .EQU    BUFSTART_IO
serTx0Buf       .EQU    serRx0Buf+SER_RX0_BUFSIZE+1

serRx1Buf       .EQU    serTx0Buf+SER_TX0_BUFSIZE+1
serTx1Buf       .EQU    serRx1Buf+SER_RX1_BUFSIZE+1

APUCMDBuf       .EQU    serTx1Buf+SER_TX1_BUFSIZE+1
APUPTRBuf       .EQU    APUCMDBuf+APU_CMD_BUFSIZE+1

;==============================================================================
;
                .END
;
;==============================================================================


