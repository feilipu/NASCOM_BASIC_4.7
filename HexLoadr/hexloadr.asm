;==================================================================================
;
; Z180 Register Mnemonics
;

IO_BASE         .EQU    $00     ; Internal I/O Base Address (ICR) <<< SET THIS AS DESIRED >>>

CBR             .EQU    IO_BASE+$38     ; MMU Common Base Reg
BBR             .EQU    IO_BASE+$39     ; MMU Bank Base Reg
CBAR            .EQU    IO_BASE+$3A     ; MMU Common/Bank Area Reg

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
            
            ld c,0          ; non zero c is our ESA flag

WAIT_COLON:
            RST 10H         ; Rx byte
            cp ':'          ; wait for ':'
            jr nz, WAIT_COLON
            ld hl, 0        ; reset hl to compute checksum
            call READ_BYTE  ; read byte count
            ld b, a         ; store it in b
            call READ_BYTE  ; read upper byte of address
            ld d, a         ; store in d
            call READ_BYTE  ; read lower byte of address
            ld e, a         ; store in e
            call READ_BYTE  ; read record type
            cp 02           ; check if record type is 02 (ESA)
            jr z, ESA_DATA
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
            djnz READ_DATA  ; if b non zero, loop to get more data
READ_CHKSUM:
            call READ_BYTE  ; read checksum, but we don't need to keep it
            ld a, l         ; lower byte of hl checksum should be 0
            or a
            jr nz, BAD_CHK  ; non zero, we have an issue

            ld a, '#'       ; "#" per line loaded
            RST 08H         ; Print it
            ;ld a, CR        ; CR                   # DEBUG
            ;RST 08H         ; Print it             # DEBUG
            ;ld a, LF        ; LF                   # DEBUG
            ;RST 08H         ; Print it             # DEBUG
            
            jr WAIT_COLON

ESA_DATA:
            in0 a, (BBR)    ; grab the current Bank Base Value
            ld c, a         ; store BBR for later recovery
            call READ_BYTE  ; get high byte of ESA
            out0 (BBR), a   ; write it to the BBR  
            call READ_BYTE  ; get low byte of ESA, abandon it, but calc checksum
            jr READ_CHKSUM  ; calculate checksum

END_LOAD:
            call BBR_RESTORE   ; clean up the BBR
            ld hl, LoadOKStr
            call PRINT
            ret             ; ready to run our loaded program from Basic
            
INVAL_TYPE:
            call BBR_RESTORE   ; clean up the BBR
            ld hl, invalidTypeStr
            call PRINT
            ret             ; return to Basic

BAD_CHK:
            call BBR_RESTORE   ; clean up the BBR
            ld hl, badCheckSumStr
            call PRINT
            ret             ; return to Basic

BBR_RESTORE:
            ld a, c         ; get our BBR back
            ret z           ; if it is zero, chances are we don't need it
            out0 (BBR), a   ; write it to the BBR
            ret

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

invalidTypeStr:    .BYTE "Invalid Type",CR,LF,0
badCheckSumStr:    .BYTE "Checksum Error",CR,LF,0
LoadOKStr:         .BYTE "OK",CR,LF,0

            
            .END
