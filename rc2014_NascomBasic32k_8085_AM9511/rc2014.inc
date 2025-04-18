;==============================================================================
; Contents of this file are copyright Phillip Stevens
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; https://github.com/feilipu/
;
; https://feilipu.me/
;
;==============================================================================
;
; ACIA 68B50 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to
; allow run-on from the sender. Transmit and receive are interrupt driven.
;
; https://github.com/feilipu/
; https://feilipu.me/
;
;==============================================================================
;
; INCLUDES SECTION
;

INCLUDE "rc2014_config.inc"

;==============================================================================
;
; DEFINES SECTION
;

DEFC    ROMSTART        =   $0000   ; Bottom of ROM

DEFC    RAMSTOP         =   $FFFF   ; Top of RAM

DEFC    SER_RX_BUFSIZE      = $100  ; FIXED Rx buffer size, 256 Bytes, no range checking
DEFC    SER_RX_FULLSIZE     = SER_RX_BUFSIZE - $10
                                    ; Fullness of the Rx Buffer, when not_RTS is signalled
DEFC    SER_RX_EMPTYSIZE    = $08   ; Fullness of the Rx Buffer, when RTS is signalled

DEFC    SER_TX_BUFSIZE      = $40   ; Size of the Tx Buffer, 2^n Bytes, n = 6 here

;==============================================================================
;
; Interrupt vectors (offsets) for 8085 RST and IRQ interrupts
;

DEFC    VECTOR_BASE         =   RAMSTART    ; RAM vector address for 8085 RST Table

; 8085 Following Overflow TRAP 0x0040

DEFC    VECTOR_PROTO        =   $0048
DEFC    VECTOR_SIZE         =   $34

;   Prototype Interrupt Service Routines - complete in main program
;
;DEFC       RST_00          =   INIT        Reboot
;DEFC       RST_08          =   TX          TX a character over SOD / ACIA
;DEFC       RST_10          =   RX          RX a character over SID / ACIA, block no bytes available
;DEFC       RST_18          =   RX_CHK      Check SID / ACIA status, return # bytes available
;DEFC       RST_20          =   UFERR       User Function undefined (RSTnn) error
;DEFC       TRAP            =   NULL_INT    8085 TRAP $0024
;DEFC       RST_28          =   UFERR       User Function undefined (RSTnn) error
;DEFC       IRQ_55          =   NULL_INT    8085 IRQ 5.5
;DEFC       RST_30          =   UFERR       User Function undefined (RSTnn) error
;DEFC       IRQ_65          =   NULL_INT    8085 IRQ 6.5
;DEFC       RST_38          =   UFERR       User Function undefined (RSTnn) error
;DEFC       IRQ_75          =   NULL_INT    8085 IRQ 7.5
;DEFC       RST_40          =   UFERR       8085 JP V Overflow

;   8085 Interrupt Service Routine Addresses - rewrite as needed

DEFC    RST_00_ADDR         =   VECTOR_BASE+$01
DEFC    RST_08_ADDR         =   VECTOR_BASE+$05
DEFC    RST_10_ADDR         =   VECTOR_BASE+$09
DEFC    RST_18_ADDR         =   VECTOR_BASE+$0D
DEFC    RST_20_ADDR         =   VECTOR_BASE+$11
DEFC    TRAP_ADDR           =   VECTOR_BASE+$15
DEFC    RST_28_ADDR         =   VECTOR_BASE+$19
DEFC    IRQ_55_ADDR         =   VECTOR_BASE+$1D
DEFC    RST_30_ADDR         =   VECTOR_BASE+$21
DEFC    IRQ_65_ADDR         =   VECTOR_BASE+$25
DEFC    RST_38_ADDR         =   VECTOR_BASE+$29
DEFC    IRQ_75_ADDR         =   VECTOR_BASE+$2D
DEFC    RST_40_ADDR         =   VECTOR_BASE+$31

;==============================================================================
;
; Some definitions used with the RC2014 on-board peripherals:
;

; ACIA 68B50 Register Mnemonics

DEFC    SER_CTRL_ADDR   =   $80    ; Address of Control Register (write only)
DEFC    SER_STATUS_ADDR =   $80    ; Address of Status Register (read only)
DEFC    SER_DATA_ADDR   =   $81    ; Address of Data Register

DEFC    SER_RESET       =   $03    ; Master Reset (issue before any other Control word)
DEFC    SER_CLK_DIV_64  =   $02    ; Divide the Clock by 64 (default value)
DEFC    SER_CLK_DIV_16  =   $01    ; Divide the Clock by 16
DEFC    SER_CLK_DIV_01  =   $00    ; Divide the Clock by 1

DEFC    SER_8O1         =   $1C    ; 8 Bits  Odd Parity 1 Stop Bit
DEFC    SER_8E1         =   $18    ; 8 Bits Even Parity 1 Stop Bit
DEFC    SER_8N1         =   $14    ; 8 Bits   No Parity 1 Stop Bit
DEFC    SER_8N2         =   $10    ; 8 Bits   No Parity 2 Stop Bits
DEFC    SER_7O1         =   $0C    ; 7 Bits  Odd Parity 1 Stop Bit
DEFC    SER_7E1         =   $08    ; 7 Bits Even Parity 1 Stop Bit
DEFC    SER_7O2         =   $04    ; 7 Bits  Odd Parity 2 Stop Bits
DEFC    SER_7E2         =   $00    ; 7 Bits Even Parity 2 Stop Bits

DEFC    SER_TDI_BRK     =   $60    ; _RTS low,  Transmitting Interrupt Disabled, BRK on Tx
DEFC    SER_TDI_RTS1    =   $40    ; _RTS high, Transmitting Interrupt Disabled
DEFC    SER_TEI_RTS0    =   $20    ; _RTS low,  Transmitting Interrupt Enabled
DEFC    SER_TDI_RTS0    =   $00    ; _RTS low,  Transmitting Interrupt Disabled

DEFC    SER_TEI_MASK    =   $60    ; Mask for the Tx Interrupt & RTS bits

DEFC    SER_REI         =   $80    ; Receive Interrupt Enabled

DEFC    SER_IRQ         =   $80    ; IRQ (Either Transmitted or Received Byte)
DEFC    SER_PE          =   $40    ; Parity Error (Received Byte)
DEFC    SER_OVRN        =   $20    ; Overrun (Received Byte
DEFC    SER_FE          =   $10    ; Framing Error (Received Byte)
DEFC    SER_CTS         =   $08    ; Clear To Send
DEFC    SER_DCD         =   $04    ; Data Carrier Detect
DEFC    SER_TDRE        =   $02    ; Transmit Data Register Empty
DEFC    SER_RDRF        =   $01    ; Receive Data Register Full

; General TTY

DEFC    CTRLC           =    03H     ; Control "C"
DEFC    CTRLG           =    07H     ; Control "G"
DEFC    BEL             =    07H     ; Bell
DEFC    BKSP            =    08H     ; Back space
DEFC    LF              =    0AH     ; Line feed
DEFC    CS              =    0CH     ; Clear screen
DEFC    CR              =    0DH     ; Carriage return
DEFC    CTRLO           =    0FH     ; Control "O"
DEFC    CTRLQ           =    11H     ; Control "Q"
DEFC    CTRLR           =    12H     ; Control "R"
DEFC    CTRLS           =    13H     ; Control "S"
DEFC    CTRLU           =    15H     ; Control "U"
DEFC    ESC             =    1BH     ; Escape
DEFC    DEL             =    7FH     ; Delete

;==============================================================================
;
; VARIABLES
;

DEFC    serRxInPtr      =     VECTOR_BASE+VECTOR_SIZE
DEFC    serRxOutPtr     =     serRxInPtr+2
DEFC    serTxInPtr      =     serRxOutPtr+2
DEFC    serTxOutPtr     =     serTxInPtr+2
DEFC    serRxBufUsed    =     serTxOutPtr+2
DEFC    serTxBufUsed    =     serRxBufUsed+1
DEFC    serControl      =     serTxBufUsed+1

DEFC    basicStarted    =     serControl+1

; I/O Tx Buffer must start on 0xnnn0 because we increment low byte to roll-over
DEFC    BUFSTART_TX_IO  =     VECTOR_BASE-(VECTOR_BASE%$100) + $80

; I/O Rx Buffer must start on 0xnn00 because we increment low byte to roll-over
DEFC    BUFSTART_RX_IO  =     VECTOR_BASE-(VECTOR_BASE%$100) + $100

DEFC    serTxBuf        =     BUFSTART_TX_IO
DEFC    serRxBuf        =     BUFSTART_RX_IO

;==============================================================================
