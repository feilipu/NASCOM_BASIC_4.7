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
; UART 16550 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to
; allow run-on from the sender. Receive is interrupt driven.
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

DEFC    UART_RX_SIZE        = $100      ; FIXED Rx buffer size, 256 Bytes, no range checking
DEFC    UART_RX_FULLISH     = UART_RX_SIZE - $10
                                        ; Fullness of the Rx Buffer, when not RTS is signalled
DEFC    UART_RX_EMPTYISH    = $08       ; Fullness of the Rx Buffer, when RTS is signalled

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
;DEFC       RST_08          =   TX          TX a character over SOD / UART
;DEFC       RST_10          =   RX          RX a character over SID / UART, block no bytes available
;DEFC       RST_18          =   RX_CHK      Check SID / UART status, return # bytes available
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
; UART 16550 Register Mnemonics
;

DEFC    UARTA_DATA_REGISTER     = 0x80
DEFC    UARTA_IER_REGISTER      = 0x81
DEFC    UARTA_IIR_REGISTER      = 0x82
DEFC    UARTA_FCR_REGISTER      = 0x82
DEFC    UARTA_LCR_REGISTER      = 0x83
DEFC    UARTA_MCR_REGISTER      = 0x84
DEFC    UARTA_LSR_REGISTER      = 0x85
DEFC    UARTA_MSR_REGISTER      = 0x86
DEFC    UARTA_SCRATCH_REGISTER  = 0x87

DEFC    UARTA_DLL_REGISTER      = 0x80
DEFC    UARTA_DLM_REGISTER      = 0x81

DEFC    UARTB_DATA_REGISTER     = 0x88
DEFC    UARTB_IER_REGISTER      = 0x89
DEFC    UARTB_IIR_REGISTER      = 0x8a
DEFC    UARTB_FCR_REGISTER      = 0x8a
DEFC    UARTB_LCR_REGISTER      = 0x8b
DEFC    UARTB_MCR_REGISTER      = 0x8c
DEFC    UARTB_LSR_REGISTER      = 0x8d
DEFC    UARTB_MSR_REGISTER      = 0x8e
DEFC    UARTB_SCRATCH_REGISTER  = 0x8f

DEFC    UARTB_DLL_REGISTER      = 0x88
DEFC    UARTB_DLM_REGISTER      = 0x89

DEFC    UART_IER_ERBI           = 0x01
DEFC    UART_IER_ETBEI          = 0x02
DEFC    UART_IER_ETSI           = 0x04
DEFC    UART_IER_EDSSI          = 0x08

DEFC    UART_IIR_PENDING        = 0x01
DEFC    UART_IIR_ID_1           = 0x02
DEFC    UART_IIR_ID_2           = 0x04
DEFC    UART_IIR_ID_3           = 0x08
DEFC    UART_IIR_FIFO_LSB       = 0x40
DEFC    UART_IIR_FIFO_MSB       = 0x80

DEFC    UART_IIR_THRE           = 0x02
DEFC    UART_IIR_DATA           = 0x04
DEFC    UART_IIR_RLS            = 0x06
DEFC    UART_IIR_TIMEOUT        = 0x0C
DEFC    UART_IIR_MASK           = 0x0E

DEFC    UART_FCR_FIFO_ENABLE        = 0x01
DEFC    UART_FCR_FIFO_RX_RESET      = 0x02
DEFC    UART_FCR_FIFO_TX_RESET      = 0x04
DEFC    UART_FCR_DMA_MODE_SELECT    = 0x08
DEFC    UART_FCR_RECEIVER_LSB       = 0x40
DEFC    UART_FCR_RECEIVER_MSB       = 0x80

DEFC    UART_FCR_FIFO_01        = 0x00
DEFC    UART_FCR_FIFO_04        = 0x40
DEFC    UART_FCR_FIFO_08        = 0x80
DEFC    UART_FCR_FIFO_14        = 0xC0

DEFC    UART_LCR_5BIT           = 0x00
DEFC    UART_LCR_6BIT           = 0x01
DEFC    UART_LCR_7BIT           = 0x02
DEFC    UART_LCR_8BIT           = 0x03
DEFC    UART_LCR_STOP           = 0x04

DEFC    UART_LCR_PARITY_ENABLE      = 0x08
DEFC    UART_LCR_PARITY_EVEN        = 0x10
DEFC    UART_LCR_PARITY_STICK       = 0x20
DEFC    UART_LCR_BREAK_CONTROL      = 0x40
DEFC    UART_LCR_DLAB               = 0x80

DEFC    UART_MCR_DTR                = 0x01
DEFC    UART_MCR_RTS                = 0x02
DEFC    UART_MCR_OUTPUT1            = 0x04
DEFC    UART_MCR_INT_ENABLE         = 0x08
DEFC    UART_MCR_LOOPBACK           = 0x10
DEFC    UART_MCR_AUTO_FLOW_CONTROL  = 0x20

DEFC    UART_LSR_DATA_READY         = 0x01
DEFC    UART_LSR_OVERRUN_ERROR      = 0x02
DEFC    UART_LSR_PARITY_ERROR       = 0x04
DEFC    UART_LSR_FRAMING_ERROR      = 0x08
DEFC    UART_LSR_BREAK_INTERRUPT    = 0x10
DEFC    UART_LSR_TX_HOLDING_THRE    = 0x20
DEFC    UART_LSR_TX_EMPTY_TEMT      = 0x40
DEFC    UART_LSR_RX_FIFO_ERROR      = 0x80

DEFC    UART_MSR_CTS_DELTA      = 0x01
DEFC    UART_MSR_DSR_DELTA      = 0x02
DEFC    UART_MSR_TERI           = 0x04
DEFC    UART_MSR_DCD_DELTA      = 0x08
DEFC    UART_MSR_CTS            = 0x10
DEFC    UART_MSR_DSR            = 0x20
DEFC    UART_MSR_RING_INDICATOR = 0x40
DEFC    UART_MSR_DCD            = 0x80

DEFC    UART_DLL_115200         = 0x01
DEFC    UART_DLL_57600          = 0x02
DEFC    UART_DLL_38400          = 0x03
DEFC    UART_DLL_19200          = 0x06
DEFC    UART_DLL_9600           = 0x0C
DEFC    UART_DLL_2400           = 0x30

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

DEFC    uartRxIn        =     VECTOR_BASE+VECTOR_SIZE
DEFC    uartRxOut       =     uartRxIn+2
DEFC    uartRxCount     =     uartRxOut+2

DEFC    uartaControl    =     uartRxCount+1
DEFC    uartbControl    =     uartaControl+1

DEFC    basicStarted    =     uartbControl+1

; I/O Rx Buffer must start on 0xnn00 because we increment low byte to roll-over
DEFC    BUFSTART_RX_IO  =     VECTOR_BASE-(VECTOR_BASE%$100) + $100

DEFC    uartRxBuffer    =     BUFSTART_RX_IO

;==============================================================================
