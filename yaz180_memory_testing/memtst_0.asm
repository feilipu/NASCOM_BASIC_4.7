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
; CODE SECTION
;

            .ORG    0300H
Z180_INIT:
                                    ; Set Logical Addresses
                                    ; $8000-$FFFF RAM CA1 -> 80H
                                    ; $4000-$7FFF RAM BANK -> 04H
                                    ; $2000-$3FFF RAM CA0
                                    ; $0000-$1FFF Flash CA0
            LD      A,$84           ; Set New Common / Bank Areas
            OUT0    (CBAR),A        ; for RAM

                                    ; Physical Addresses
            LD      A,$78           ; Set Common 1 Area Physical $80000 -> $78
            OUT0    (CBR),A

            LD      A,$3C           ; Set Bank Area Physical $40000 -> $3C
            OUT0    (BBR),A

                                    ; load the default ASCI configuration
                                    ; 
                                    ; BAUD = 115200 8n1
                                    ; receive enabled
                                    ; transmit enabled
                                    ; receive interrupt enabled
                                    ; transmit interrupt disabled
            LD      A,ASCI_RE|ASCI_TE|ASCI_8N1
            OUT0    (CNTLA0),A      ; output to the ASCI0 control A reg

                                    ; PHI / PS / SS / DR = BAUD Rate
                                    ; PHI = 18.432MHz
                                    ; BAUD = 115200 = 18432000 / 10 / 1 / 16 
                                    ; PS 0, SS_DIV_1 0, DR 0           
            XOR     A               ; BAUD = 115200
            OUT0    (CNTLB0),A      ; output to the ASCI0 control B reg

;            LD      A,ASCI_RIE       ; receive interrupt enabled
;            OUT0    (STAT0),A       ; output to the ASCI0 status reg

                                    ; Set up 82C55 PIO in Mode 0 #12
            LD      BC,PIOCNTL      ; 82C55 CNTL address in bc
            LD      A,PIOCNTL12     ; Set Mode 12 ->A, B->, ->CH, CL->
            OUT     (C),A           ; output to the PIO control reg

            LD      BC,PIOB         ; 82C55 IO PORT B address in BC
            LD      A,$01           ; Set Port B TIL311 XXX
            OUT     (C),A           ; put debug HEX Code onto Port B

            JP      RAMTST          ; test RAM

;------------------------------------------------------------------------------

            .ORG    0400H

MEMTEST_HALT:
                                    ; halt if there's an error
            LD      BC,PIOB         ; 82C55 IO PORT B address in BC
            OUT     (C),H           ; put address HEX Code onto Port B
            HALT
;------------------------------------------------------------------------------
; Test a RAM area
;
; if the program finds an error, it exits immediately with the Carry flag set
; and indicates where the error occured and what value it used in the test.
;
; Entry
;       IX = return address
;       HL = base address of test area
;       DE = size of the area to test in bytes
;
; Exit Success
;       Carry flag = 0 and all test RAM is set to 0x00
;
; Exit Failure
;       Carry flag = 1
;       HL = address of error
;       A  = expected value of byte written
;
; Registers used
;       AF, BC, DE, HL, IX
;

RAMTST:
            ; EXIT WITH NO ERRORS IF AREA SIZE IS 0
            LD      A,D         ; TEST AREA SIZE
            OR      E
            HALT           ; EXIT WITH NO ERRORS IF SIZE IS ZERO
            LD      B,D         ; BC = AREA SIZE
            LD      C,E

            ; FILL MEMORY WITH 0 AND TEST
            SUB     A
            CALL    RAMTST_FC
            RET     C           ; EXIT IF ERROR FOUND

            ; FILL MEMORY WITH 0xFF AND TEST
            LD      A,0FFH
            CALL    RAMTST_FC
            RET     C           ; EXIT IF ERROR FOUND

            ; FILL MEMORY WITH 0xAA AND TEST
            LD      A,0AAH
            CALL    RAMTST_FC
            RET     C           ; EXIT IF ERROR FOUND

            ; FILL MEMORY WITH 0x55 AND TEST
            LD      A,055H
            CALL    RAMTST_FC
            RET     C           ; EXIT IF ERROR FOUND
            

RAMTST_FC:
            PUSH    HL          ; SAVE BASE ADDRESS
            PUSH    BC          ; SAVE SIZE OF AREA
            LD      E,A         ; SAVE TEST VALUE
            LD      (HL),A      ; STORE TEST VALUE IN FIRST BYTE
            DEC     BC          ; REMAINING AREA = SIZE -1
            LD      A,B         ; CHECK IF ANYTHING IN REMAINING AREA
            OR      C
            LD      A,E         ; RESTORE TEST VALUE
            JR      Z,RAMTST_COMP   ; BRANCH IF AREA WAS ONLY 1 BYTE

            ; FILE REST OF AREA WITH BLOCK MOVE
            ; EACH ITERATION MOVES TEST VALUE TO NEXT HIGHER ADDRESS
            LD      D,H         ; DESTINATION IS ALWAYS SOURCE +1
            LD      E,L
            INC     DE
            LDIR                ; FILL MEMORY

            ; NOW THAT EACH LOCATION HAS BEEN FILLED, TEST TO SEE IF
            ; EACH BYTE CAN BE READ BACK CORRECTLY
RAMTST_COMP:
            POP     BC          ; RESTORE SIZE OF AREA
            POP     HL          ; RESTORE BASE ADDRESS
            PUSH    HL          ; SAVE BASE ADDRESS
            PUSH    BC          ; SAVE SIZE OF AREA

            ; RAMTST_COMP MEMORY AND TEST VALUE
RAMTST_CMPLP:
            CPI
            CALL    RAMTST_IO       ; WRITE PAGE ADDRESS TO PORT B
            JR      NZ,RAMTST_CMPER ; JUMP IF NOT EQUAL
            JP      PE,RAMTST_CMPLP ; CONTINUE THROUGH ENTIRE AREA
                                    ; NOTE CPI CLEARS P/V FLAG IF IT
                                    ; DECREMENTS BC TO 0

            ; NO ERRORS FOUND, SO CLEAR CARRY
            POP     BC          ; BC = SIZE OF AREA
            POP     HL          ; HL = BASE ADDRESS
            OR      A           ; CLEAR CARRY, INDICATING NO ERRORS
            RET

            ; ERROR EXIT, SET CARRY
            ; HL = ADDRESS OF ERROR
            ; A  = TEST VALUE
RAMTST_CMPER:
            POP     BC          ; BC = SIZE OF AREA 
            POP     DE          ; DE = BASE ADDRESS
            SCF                 ; SET CARRY, INDICATING AN ERROR
            RET

            ; WRITE BANK (UPPER 8 BITS) TO PIO PORT B TIL311
            ; HL = ADDRESS (OF WHICH ONLY H IS WRITTEN)
RAMTST_IO:
            PUSH    BC
            LD      BC,PIOB      ; 82C55 IO PORT B address in BC
            OUT     (C),H        ; output upper adddress byte to PIO Port B
            POP     BC
            RET

;==============================================================================
;
; Z80 INTERRUPT VECTOR DESTINATION ADDRESS ASSIGNMENTS
;

RST_08      .EQU    NULL_RET        ; RET
RST_10      .EQU    NULL_RET        ; RET
RST_18      .EQU    NULL_RET        ; RET
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
INT_ASCI0   .EQU    NULL_RET        ; Async channel 0
INT_ASCI1   .EQU    NULL_RET        ; Async channel 1

;==============================================================================
;
            .END
;
;==============================================================================


