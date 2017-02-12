;==================================================================================
;
; DEFINES SECTION
;

USRSTART        .EQU     $FF00 ; start of hexloadr asm code

CR              .EQU     0DH
LF              .EQU     0AH

;==================================================================================
;
; CODE SECTION
;

            .ORG USRSTART   ; Set USR(x) jump location to here.

START:      
            ld hl, initString
            call PRINT

WAIT_COLON:
            RST 10H         ; Rx byte
            cp ':'          ; wait for ':'
            jr nz, WAIT_COLON
            ld hl, 0        ; reset hl to compute checksum
            call READ_BYTE  ; read byte count
            ld b, 0         ; zero b
            ld c, a         ; store it in bc
            call READ_BYTE  ; read upper byte of address
            ld d, a         ; store in d
            call READ_BYTE  ; read lower byte of address
            ld e, a         ; store in e
            call READ_BYTE  ; read record type
            cp 02           ; check if record type is 02 (ESA)
            jr z, ESA_LOAD
            cp 01           ; check if record type is 01 (end of file)
            jr z, END_LOAD
            cp 00           ; check if record type is 00 (data)
            jr nz, INVAL_TYPE ; if not, error

READ_DATA:
            ;ld a, '*'       ; "*" per byte loaded  # DEBUG
            ;RST 08H         ; Print it             # DEBUG

            call READ_BYTE
            ld (de), a      ; write the byte at the RAM address
            inc de
            dec bc
            xor a           ; check if bc==0,  clear a
            or b
            or c
            cp 0
            jr nz, READ_DATA ; if non zero, loop to get more data

            call READ_BYTE  ; read checksum, but we don't need to keep it
            ld a, l         ; lower byte of hl checksum should be 0
            cp 0
            jr nz, BAD_CHK  ; non zero, we have an issue

            ld a, '#'       ; "#" per line loaded
            RST 08H         ; Print it
            ;ld a, CR        ; CR                   # DEBUG
            ;RST 08H         ; Print it             # DEBUG
            ;ld a, LF        ; LF                   # DEBUG
            ;RST 08H         ; Print it             # DEBUG
            
            jr WAIT_COLON

ESA_LOAD:
            ld hl, esaLoadStr
            call PRINT
            ret             ; return to Basic

END_LOAD:
            ld hl, LoadOKStr
            call PRINT
            ret             ; ready to run our loaded program from Basic

INVAL_TYPE:
            ld hl, invalidTypeStr
            call PRINT
            ret             ; return to Basic

BAD_CHK:
            ld hl, badCheckSumStr
            call PRINT
            ret             ; return to Basic


PRINT:                      ; String address hl, destroys a
            LD A,(HL)       ; Get character
            OR A            ; Is it $00 ?
            RET Z           ; Then Return on terminator
            RST 08H         ; Print it
            INC HL          ; Next Character
            JR PRINT        ; Continue until $00

READ_BYTE:                  ; Returns byte in a, checksum in hl
            push bc
            RST 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, READ_NBL2 ; if a<10 read the second nibble
            sub 7           ; else subtract 'A'-'0' (17) and add 10
READ_NBL2:
            rlca            ; shift accumulator left by 4 bits
            rlca
            rlca
            rlca
            ld c, a         ; temporarily store the first nibble in c
            RST 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, READ_END  ; if a<10 finalize
            sub 7           ; else subtract 'A' (17) and add 10
READ_END:
            or c            ; assemble two nibbles into one byte in a
            ld b, 0         ; add the byte read to hl (for checksum)
            ld c, a
            add hl, bc
            pop bc
            ret             ; return the byte read in a


initString:        .BYTE CR,LF,"HexLoadr by "
                   .BYTE "Filippo & feilipu"
                   .BYTE CR,LF,0
esaLoadStr         .BYTE "ESA Unsupported",CR,LF,0
invalidTypeStr:    .BYTE "Invalid Type",CR,LF,0
badCheckSumStr:    .BYTE "Checksum Error",CR,LF,0
LoadOKStr:         .BYTE "OK",CR,LF,0

            
            .END
