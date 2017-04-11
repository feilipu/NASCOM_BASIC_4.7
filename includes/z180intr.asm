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
; REQUIRES
;
; Z180_VECTOR_BASE  .EQU   RAM vector address for Z180 Vectors
;
;
; #include          "d:/yaz180.h"
; #include          "d:/z80intr.asm"

;==============================================================================
;
; Z180 TRAP HANDLING
;
            .ORG    Z180_VECTOR_TRAP
INIT:
            PUSH    AF
                                    ; Set I/O Control Reg (ICR)
            LD      A,Z180_IO_BASE  ; ICR = $00 [xx00 0000] for I/O Registers at $00 - $3F
            OUT0    (ICR),A         ; Standard I/O Mapping (0 Enabled)

            IN0     A,(ITC)         ; Check whether TRAP is set, or normal RESET
            AND     ITC_TRAP
            JR      NZ, Z180_TRAP   ; Handle the TRAP event

            POP     AF
                                    ; Set interrupt vector address high byte (I)
            LD      A,Z180_VECTOR_BASE/$100
            LD      I,A
                                    ; Set interrupt vector address low byte (IL)
                                    ; IL = $20 [001x xxxx] for Vectors at $nn20 - $nn2F
            LD      A,Z180_VECTOR_BASE%$100
            OUT0    (IL),A          ; Set the interrupt vector low byte

            IM      1               ; Interrupt mode 1 for INT0

            XOR     A               ; Zero Accumulator

                                    ; Clear Refresh Control Reg (RCR)
            OUT0    (RCR),A         ; DRAM Refresh Enable (0 Disabled)

            OUT0    (TCR),A         ; Disable PRT downcounting

                                    ; Clear Operation Mode Control Reg (OMCR)
                                    ; Disable M1, disable 64180 I/O _RD Mode
            OUT0    (OMCR),A        ; X80 Mode (M1 Disabled, IOC Disabled)

                                    ; Clear INT/TRAP Control Register (ITC)             
            OUT0    (ITC),A         ; Disable all external interrupts. 

                                    ; Set internal clock = crystal x 2 = 36.864MHz
                                    ; if using ZS8180 or Z80182 at High-Speed
            LD      A,CMR_X2        ; Set Hi-Speed flag
            OUT0    (CMR),A         ; CPU Clock Multiplier Reg (CMR)

                                    ; DMA/Wait Control Reg Set I/O Wait States
            LD      A,DCNTL_IWI0
            OUT0    (DCNTL),A       ; 0 Memory Wait & 2 I/O Wait

            LD      HL,Z80_VECTOR_PROTO ; Establish Z80 RST Vector Table
            LD      DE,Z80_VECTOR_BASE
            LD      BC,Z80_VECTOR_SIZE
            LDIR

            LD      HL,Z180_VECTOR_PROTO ; Establish Z180 Vector Table
            LD      DE,Z180_VECTOR_BASE
            LD      BC,Z180_VECTOR_SIZE
            LDIR

            JP      Z180_INIT       ; Start normal Configuration

Z180_TRAP:
            LD      A,~ITC_TRAP     ; Clear TRAP bit
            OUT0    (ITC),A 
                                    ; TODO Build proper TRAP handling
            POP     AF
            HALT                    

;==============================================================================
;
; Z180 INTERRUPT VECTOR TABLE PROTOTYPE
;
; WILL BE DUPLICATED DURING INIT TO:
;
;           .ORG    Z180_VECTOR_BASE

            .ORG    Z180_VECTOR_PROTO
;------------------------------------------------------------------------------
; Z180_VECTOR_INT1
            .WORD   INT_INT1

;------------------------------------------------------------------------------
; Z180_VECTOR_INT2
            .WORD   INT_INT2

;------------------------------------------------------------------------------
; Z180_VECTOR_PRT0
            .WORD   INT_PRT0

;------------------------------------------------------------------------------
; Z180_VECTOR_PRT1
            .WORD   INT_PRT1

;------------------------------------------------------------------------------
; Z180_VECTOR_DMA0
            .WORD   INT_DMA0

;------------------------------------------------------------------------------
; Z180_VECTOR_DMA1
            .WORD   INT_DMA1

;------------------------------------------------------------------------------
; Z180_VECTOR_CSIO
            .WORD   INT_CSIO

;------------------------------------------------------------------------------
; Z180_VECTOR_ASCI0
            .WORD   INT_ASCI0

;------------------------------------------------------------------------------
; Z180_VECTOR_ASCI1
            .WORD   INT_ASCI1

;==============================================================================
;
            .END
;
;==============================================================================


