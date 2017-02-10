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

USRSTART        .EQU     $F800 ; start of USR(x) asm code

CR              .EQU     0DH
LF              .EQU     0AH

;==================================================================================
;
; VARIABLES SECTION
;



;==================================================================================
;
; CODE SECTION
;

            .ORG USRSTART   ; USR(*) jump location

START:      ld hl, initString
            call PRINT

WAIT_COLON:
            RST 10H         ; Rx byte
            cp ':'          ; wait for ':'
            jr nz, WAIT_COLON
            RST 08H         ; Tx byte                     # DEBUG
            ld ix, 0        ; reset ix to compute checksum
            call READ_BYTE  ; read byte count
            ld b, h         ; store it in bc
            ld c, l         ;
            call READ_BYTE  ; read upper byte of address
            ld d, l         ; store in d
            call READ_BYTE  ; read lower byte of address
            ld e, l         ; store in e
            call READ_BYTE  ; read record type
            ld a, l         ; store in a
            cp 01           ; check if record type is 01 (end of file)
            jr z, END_LOAD
            cp 00           ; check if record type is 00 (data)
            jr nz, INVAL_TYPE ; if not, error

READ_DATA:
            call READ_BYTE
            ld a, l
            RST 08H         ; Tx byte                     # DEBUG
            ld a, l         ;                             # DEBUG
            ld (de), a
            inc de
            dec bc
            ld a, 0         ; check if bc==0
            or b
            or c
            cp 0
            jr nz, READ_DATA ; if not, loop

            call READ_BYTE  ; read checksum
            ld a, ixl       ; lower byte of ix should be 0
            cp 0
            jr nz, BAD_CHK

            ld a, '*'
            RST       08H   ; Print it
            jr WAIT_COLON

END_LOAD:
            call READ_BYTE  ; read last checksum (not used)
            ld hl, LoadOKStr
            call PRINT
            RET             ; jump back into Basic


INVAL_TYPE:
            ld hl, invalidTypeStr
            call PRINT
            jr HANG

BAD_CHK:
            ld hl, badCheckSumStr
            call PRINT
            jr HANG

HANG:
            nop
            jr HANG


PRINT:
            LD        A,(HL)    ; Get character
            OR        A         ; Is it $00 ?
            RET       Z         ; Then Return on terminator
            RST       08H       ; Print it
            INC       HL        ; Next Character
            JR        PRINT     ; Continue until $00
            RET


READ_BYTE:
            push af
            push de
            RST 10H        ; Rx byte
            sub '0'
            cp 10
            jr c, RD_NBL_2 ; if a<10 read the second nibble
            sub 7          ; else subtract 'A'-'0' (17) and add 10
RD_NBL_2:   ld d, a        ; temporary store the first nibble in d
            RST 10H        ; Rx byte
            sub '0'
            cp 10
            jr c, READ_END ; if a<10 finalize
            sub 7          ; else subtract 'A' (17) and add 10
READ_END:   ld e, a        ; temporary store the second nibble in e
            sla d          ; shift register d left by 4 bits
            sla d
            sla d
            sla d
            or d
            pop de
            ld h, 0
            ld l, a
            pop af
            push bc         ; add the byte read to ix (for checksum)
            ld b, 0
            ld c, l
            add ix, bc
            pop bc
            ret


initString:        .BYTE "HEX LOADER by Filippo"
                   .BYTE " & feilipu",CR,LF,0
invalidTypeStr:    .BYTE "INV TYP",CR,LF,0
badCheckSumStr:    .BYTE "BAD CHK",CR,LF,0
LoadOKStr:         .BYTE "OK",CR,LF,0

            
            .END
