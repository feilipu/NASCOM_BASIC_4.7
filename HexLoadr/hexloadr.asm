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

HEX_START:      
            ld hl, initString
            call HEX_PRINT
            
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
            jr z, ESA_DATA
            cp 01           ; check if record type is 01 (end of file)
            jr z, HEX_END_LOAD
            cp 00           ; check if record type is 00 (data)
            jr nz, HEX_INVAL_TYPE ; if not, error

HEX_READ_DATA:
            ;ld a, '*'       ; "*" per byte loaded  # DEBUG
            ;RST 08H         ; Print it             # DEBUG

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
            RST 08H         ; Print it
            ;ld a, CR        ; CR                   # DEBUG
            ;RST 08H         ; Print it             # DEBUG
            ;ld a, LF        ; LF                   # DEBUG
            ;RST 08H         ; Print it             # DEBUG
            
            jr HEX_WAIT_COLON

ESA_DATA:
            in0 a, (BBR)    ; grab the current Bank Base Value
            ld c, a         ; store BBR for later recovery
            call HEX_READ_BYTE  ; get high byte of ESA
            out0 (BBR), a   ; write it to the BBR  
            call HEX_READ_BYTE  ; get low byte of ESA, abandon it, but calc checksum
            jr HEX_READ_CHKSUM  ; calculate checksum

HEX_END_LOAD:
            call HEX_BBR_RESTORE   ; clean up the BBR
            ld hl, LoadOKStr
            call HEX_PRINT
            ret             ; ready to run our loaded program from Basic
            
HEX_INVAL_TYPE:
            call HEX_BBR_RESTORE   ; clean up the BBR
            ld hl, invalidTypeStr
            call HEX_PRINT
            ret             ; return to Basic

HEX_BAD_CHK:
            call HEX_BBR_RESTORE   ; clean up the BBR
            ld hl, badCheckSumStr
            call HEX_PRINT
            ret             ; return to Basic

HEX_BBR_RESTORE:
            ld a, c         ; get our BBR back
            ret z           ; if it is zero, chances are we don't need it
            out0 (BBR), a   ; write it to the BBR
            ret

HEX_PRINT:                  ; String address hl, destroys a
            LD A,(HL)       ; Get character
            OR A            ; Is it $00 ?
            RET Z           ; Then Return on terminator
            RST 08H         ; Print it
            INC HL          ; Next Character
            JR HEX_PRINT    ; Continue until $00

HEX_READ_BYTE:                  ; Returns byte in a, checksum in hl
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


initString:        .BYTE CR,LF,"HexLoadr> "
                   .BYTE CR,LF,0

invalidTypeStr:    .BYTE "Invalid Type",CR,LF,0
badCheckSumStr:    .BYTE "Checksum Error",CR,LF,0
LoadOKStr:         .BYTE "Done",CR,LF,0


            .END
