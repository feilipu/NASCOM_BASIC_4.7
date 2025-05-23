;==============================================================================
;
; The rework to support MS Basic HLOAD, RESET, MEEK, MOKE,
; and the 8085 instruction tuning are copyright (C) 2021-23 Phillip Stevens
;
; This Source Code Form is subject to the terms of the Mozilla Public
; License, v. 2.0. If a copy of the MPL was not distributed with this
; file, You can obtain one at http://mozilla.org/MPL/2.0/.
;
; The HLOAD function supports Intel HEX encoded program upload.
; Updates LSTRAM and STRSPC, adds program origin address to USR+1.
; It resets and clears runtime variables.
;
; The RESET function returns to cold start status.
;
; feilipu, March 2025
;
;==============================================================================
;
; The updates to the original BASIC within this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.wales/
;
;==============================================================================
;
; NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft
; Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3
; (May-June 1983) to Vol 3, Issue 3 (May-June 1984)
; Adapted for the freeware Zilog Macro Assembler 2.10 to produce
; the original ROM code (checksum A934H). PA
;
;==============================================================================


; GENERAL EQUATES

        DEFC    CTRLC   =   03H         ; Control "C"
        DEFC    CTRLG   =   07H         ; Control "G"
        DEFC    BKSP    =   08H         ; Back space
        DEFC    LF      =   0AH         ; Line feed
        DEFC    FF      =   0CH         ; Form feed
        DEFC    CR      =   0DH         ; Carriage return
        DEFC    CTRLO   =   0FH         ; Control "O"
        DEFC    CTRLQ   =   11H         ; Control "Q"
        DEFC    CTRLR   =   12H         ; Control "R"
        DEFC    CTRLS   =   13H         ; Control "S"
        DEFC    CTRLU   =   15H         ; Control "U"
        DEFC    ESC     =   1BH         ; Escape
        DEFC    DEL     =   7FH         ; Delete

; BASIC WORK SPACE LOCATIONS

        PUBLIC WRKSPC                   ; Start of BASIC RAM

        DEFC    WRKSPC  =   8200H       ; <<<< BASIC Work space ** Rx buffer & Tx buffer located from 8080H **
        DEFC    USR     =   WRKSPC+003H ; "USR (x)" jump
        DEFC    OUTSUB  =   WRKSPC+006H ; "OUT p,n"
        DEFC    OTPORT  =   WRKSPC+007H ; Port (p)

        DEFC    SEED    =   WRKSPC+017H ; Random number seed
        DEFC    LSTRND  =   WRKSPC+03AH ; Last random number
        DEFC    INPSUB  =   WRKSPC+03EH ; #INP (x)" Routine
        DEFC    INPORT  =   WRKSPC+03FH ; PORT (x)
        DEFC    NULLS   =   WRKSPC+041H ; Number of nulls
        DEFC    LWIDTH  =   WRKSPC+042H ; Terminal width
        DEFC    COMMAN  =   WRKSPC+043H ; Width for commas
        DEFC    NULFLG  =   WRKSPC+044H ; Null after input byte flag
        DEFC    CTLOFG  =   WRKSPC+045H ; Control "O" flag
        DEFC    LINESC  =   WRKSPC+046H ; Lines counter
        DEFC    LINESN  =   WRKSPC+048H ; Lines number
        DEFC    CHKSUM  =   WRKSPC+04AH ; Array load/save check sum
        DEFC    NMIFLG  =   WRKSPC+04CH ; Flag for NMI break routine
        DEFC    BRKFLG  =   WRKSPC+04DH ; Break flag
        DEFC    RINPUT  =   WRKSPC+04EH ; Input reflection
        DEFC    STRSPC  =   WRKSPC+051H ; Bottom of string space
        DEFC    LINEAT  =   WRKSPC+053H ; Current line number
        DEFC    BASTXT  =   WRKSPC+055H ; Pointer to start of program
        DEFC    BUFFER  =   WRKSPC+058H ; Input buffer
        DEFC    STACK   =   WRKSPC+05DH ; Initial stack
        DEFC    CURPOS  =   WRKSPC+0A2H ; <<<< Character position on line ** Top of Loader TEMPSTACK **
        DEFC    LCRFLG  =   WRKSPC+0A3H ; Locate/Create flag
        DEFC    TYPE    =   WRKSPC+0A4H ; Data type flag
        DEFC    DATFLG  =   WRKSPC+0A5H ; Literal statement flag
        DEFC    LSTRAM  =   WRKSPC+0A6H ; Last available RAM
        DEFC    TMSTPT  =   WRKSPC+0A8H ; Temporary string pointer
        DEFC    TMSTPL  =   WRKSPC+0AAH ; Temporary string pool
        DEFC    TMPSTR  =   WRKSPC+0B6H ; Temporary string
        DEFC    STRBOT  =   WRKSPC+0BAH ; Bottom of string space
        DEFC    CUROPR  =   WRKSPC+0BCH ; Current operator in EVAL
        DEFC    LOOPST  =   WRKSPC+0BEH ; First statement of loop
        DEFC    DATLIN  =   WRKSPC+0C0H ; Line of current DATA item
        DEFC    FORFLG  =   WRKSPC+0C2H ; "FOR" loop flag
        DEFC    LSTBIN  =   WRKSPC+0C3H ; Last byte entered
        DEFC    READFG  =   WRKSPC+0C4H ; Read/Input flag
        DEFC    BRKLIN  =   WRKSPC+0C5H ; Line of break
        DEFC    NXTOPR  =   WRKSPC+0C7H ; Next operator in EVAL
        DEFC    ERRLIN  =   WRKSPC+0C9H ; Line of error
        DEFC    CONTAD  =   WRKSPC+0CBH ; Where to CONTinue
        DEFC    PROGND  =   WRKSPC+0CDH ; End of program
        DEFC    VAREND  =   WRKSPC+0CFH ; End of variables
        DEFC    ARREND  =   WRKSPC+0D1H ; End of arrays
        DEFC    NXTDAT  =   WRKSPC+0D3H ; Next data item
        DEFC    FNRGNM  =   WRKSPC+0D5H ; Name of FN argument
        DEFC    FNARG   =   WRKSPC+0D7H ; FN argument value
        DEFC    FPREG   =   WRKSPC+0DBH ; Floating point register
        DEFC    FPEXP   =   FPREG+3     ; Floating point exponent
        DEFC    SGNRES  =   WRKSPC+0DFH ; Sign of result
        DEFC    PBUFF   =   WRKSPC+0E0H ; Number print buffer

        DEFC    PROGST  =   WRKSPC+0F0H ; Start of program text area
        DEFC    STLOOK  =   WRKSPC+154H ; Start of memory test

; BASIC ERROR CODE VALUES

        PUBLIC  UFERR           ; User Function undefined (RSTnn) error

        DEFC    NF      =   00H ; NEXT without FOR
        DEFC    SN      =   02H ; Syntax error
        DEFC    RG      =   04H ; RETURN without GOSUB
        DEFC    OD      =   06H ; Out of DATA
        DEFC    FC      =   08H ; Function call error
        DEFC    OV      =   0AH ; Overflow
        DEFC    OM      =   0CH ; Out of memory
        DEFC    UL      =   0EH ; Undefined line number
        DEFC    BS      =   10H ; Bad subscript
        DEFC    DD      =   12H ; Re-DIMensioned array
        DEFC    DZ      =   14H ; Division by zero (/0)
        DEFC    ID      =   16H ; Illegal direct
        DEFC    TM      =   18H ; Type miss-match
        DEFC    OS      =   1AH ; Out of string space
        DEFC    LS      =   1CH ; String too long
        DEFC    ST      =   1EH ; String formula too complex
        DEFC    CN      =   20H ; Can't CONTinue
        DEFC    UF      =   22H ; UnDEFined user function FN
        DEFC    MO      =   24H ; Missing operand
        DEFC    HX      =   26H ; HEX error
        DEFC    BN      =   28H ; BIN error

; AM9511A APU EQUATES

        DEFC    IO_APU_DATA         =   042h
        DEFC    IO_APU_CONTROL      =   043h
        DEFC    IO_APU_STATUS       =   043h

        DEFC    IO_APU_STATUS_BUSY  =   080h
        DEFC    IO_APU_STATUS_SIGN  =   040h
        DEFC    IO_APU_STATUS_ZERO  =   020h
        DEFC    IO_APU_STATUS_DIV0  =   010h
        DEFC    IO_APU_STATUS_NEGRT =   008h
        DEFC    IO_APU_STATUS_UNDFL =   004h
        DEFC    IO_APU_STATUS_OVRFL =   002h
        DEFC    IO_APU_STATUS_CARRY =   001h

        DEFC    IO_APU_OP_SADD      =   06Ch
        DEFC    IO_APU_OP_SSUB      =   06Dh
        DEFC    IO_APU_OP_SMUL      =   06Eh
        DEFC    IO_APU_OP_SMUU      =   076h
        DEFC    IO_APU_OP_SDIV      =   06Fh

        DEFC    IO_APU_OP_DADD      =   02Ch
        DEFC    IO_APU_OP_DSUB      =   02Dh
        DEFC    IO_APU_OP_DMUL      =   02Eh
        DEFC    IO_APU_OP_DMUU      =   036h
        DEFC    IO_APU_OP_DDIV      =   02Fh

        DEFC    IO_APU_OP_FADD      =   010h
        DEFC    IO_APU_OP_FSUB      =   011h
        DEFC    IO_APU_OP_FMUL      =   012h
        DEFC    IO_APU_OP_FDIV      =   013h

        DEFC    IO_APU_OP_SQRT      =   001h
        DEFC    IO_APU_OP_SIN       =   002h
        DEFC    IO_APU_OP_COS       =   003h
        DEFC    IO_APU_OP_TAN       =   004h
        DEFC    IO_APU_OP_ASIN      =   005h
        DEFC    IO_APU_OP_ACOS      =   006h
        DEFC    IO_APU_OP_ATAN      =   007h
        DEFC    IO_APU_OP_LOG       =   008h
        DEFC    IO_APU_OP_LN        =   009h
        DEFC    IO_APU_OP_EXP       =   00Ah
        DEFC    IO_APU_OP_PWR       =   00Bh

; BASIC CODE COMMENCES

        ORG     0240H           ; <<<< Modified to allow for UART Tx/Rx on RST6.5

COLD:   JP      CSTART          ; Jump in for cold start (0x0240)
WARM:   JP      WARMST          ; Jump in for warm start (0x0243)

        DEFS    5               ; pad so DEINT is 0x024B, ABPASS is 0x024D

        DEFW    DEINT           ; 0x024B Get integer -32768 to 32767
        DEFW    ABPASS          ; 0x024D Return integer in AB

RESET:  RET     NZ              ; Return if any more on line
CSTART: LD      HL,WRKSPC       ; Start of workspace RAM
        LD      SP,HL           ; Set up a temporary stack
        XOR     A               ; Clear break flag
        LD      (BRKFLG),A

INIT:   LD      DE,INITAB       ; Initialise workspace
        LD      B,INITBE-INITAB+3; Bytes to copy
        LD      HL,WRKSPC       ; Into workspace RAM
COPY:   LD      A,(DE+)         ; Get source, increment
        LD      (HL+),A         ; To destination, increment
        DEC     B               ; Count bytes
        JP      NZ,COPY         ; More to move
        LD      SP,HL           ; Temporary stack
        CALL    CLREG           ; Clear registers and stack
        CALL    PRNTCRLF        ; Output CRLF
        LD      (BUFFER+72+1),A ; Mark end of buffer
        LD      (PROGST),A      ; Initialise program area
MSIZE:  LD      HL,MEMMSG       ; Point to message
        CALL    PRS             ; Output "Memory size"
        CALL    PROMPT          ; Get input with '?'
        CALL    GETCHR          ; Get next character
        JP      NZ,TSTMEM       ; If number - Test if RAM there
        LD      HL,STLOOK       ; Point to start of RAM
MLOOP:  INC     HL              ; Next byte
                                ; Above address FFFF ?
        JP      K,SETTOP        ; Yes - 64K RAM
        LD      A,(HL)          ; Get contents
        LD      B,A             ; Save it
        CPL                     ; Flip all bits
        LD      (HL),A          ; Put it back
        CP      (HL)            ; RAM there if same
        LD      (HL),B          ; Restore old contents
        JP      Z,MLOOP         ; If RAM - test next byte
        JP      SETTOP          ; Top of RAM found

TSTMEM: CALL    ATOH            ; Get high memory into DE
        OR      A               ; Set flags on last byte
        JP      NZ,SNERR        ; ?SN Error if bad character
        EX      DE,HL           ; Address into HL
        DEC     HL              ; Back one byte
        LD      A,11011001B     ; Test byte
        LD      B,(HL)          ; Get old contents
        LD      (HL),A          ; Load test byte
        CP      (HL)            ; RAM there if same
        LD      (HL),B          ; Restore old contents
        JP      NZ,MSIZE        ; Ask again if no RAM

SETTOP: DEC     HL              ; Back one byte
        LD      DE,STLOOK-1     ; See if enough RAM
        CALL    CPDEHL          ; Compare DE with HL
        JP      C,MSIZE         ; Ask again if not enough RAM
        LD      DE,-50          ; 50 Bytes string space
        LD      (LSTRAM),HL     ; Save last available RAM
        ADD     HL,DE           ; Allocate string space
        LD      (STRSPC),HL     ; Save string space
        CALL    CLRPTR          ; Clear program area
        LD      HL,(STRSPC)     ; Get end of memory
        LD      DE,-17          ; Offset for free bytes
        ADD     HL,DE           ; Adjust HL
        LD      DE,PROGST       ; Start of program text
        LD      A,L             ; Get LSB
        SUB     E               ; Adjust it
        LD      L,A             ; Re-save
        LD      A,H             ; Get MSB
        SBC     A,D             ; Adjust it
        LD      H,A             ; Re-save
        PUSH    HL              ; Save bytes free
        LD      HL,SIGNON       ; Sign-on message
        CALL    PRS             ; Output string
        POP     HL              ; Get bytes free back
        CALL    PRNTHL          ; Output amount of free memory
        LD      HL,BFREE        ; " Bytes free" message
        CALL    PRS             ; Output string

WARMST: LD      SP,STACK        ; Temporary stack
BRKRET: CALL    CLREG           ; Clear registers and stack
        JP      PRNTOK          ; Go to get command line

BFREE:  DEFB    " Bytes free",CR,LF,0,0

SIGNON: DEFB    "8085+APU BASIC Ver 4.7c",CR,LF
        DEFB    "Copyright ",40,"C",41
        DEFB    " 1978 by Microsoft",CR,LF,0,0

MEMMSG: DEFB    "Memory top",0

; FUNCTION ADDRESS TABLE

FNCTAB: DEFW    SGN
        DEFW    INT
        DEFW    ABS
        DEFW    USR
        DEFW    FRE
        DEFW    INP
        DEFW    POS
        DEFW    SQR
        DEFW    RND
        DEFW    LOG
        DEFW    EXP
        DEFW    COS
        DEFW    SIN
        DEFW    TAN
        DEFW    ACS
        DEFW    ASN
        DEFW    ATN
        DEFW    PEEK
        DEFW    DEEK
        DEFW    LEN
        DEFW    STR
        DEFW    VAL
        DEFW    ASC
        DEFW    CHR
        DEFW    HEX
        DEFW    LEFT
        DEFW    RIGHT
        DEFW    MID

; RESERVED WORD LIST

WORDS:  DEFB    'E'+80H,"ND"    ; 80h
        DEFB    'F'+80H,"OR"
        DEFB    'N'+80H,"EXT"
        DEFB    'D'+80H,"ATA"
        DEFB    'I'+80H,"NPUT"
        DEFB    'D'+80H,"IM"
        DEFB    'R'+80H,"EAD"
        DEFB    'L'+80H,"ET"
        DEFB    'G'+80H,"OTO"
        DEFB    'R'+80H,"UN"
        DEFB    'I'+80H,"F"
        DEFB    'R'+80H,"ESTORE"
        DEFB    'G'+80H,"OSUB"
        DEFB    'R'+80H,"ETURN"
        DEFB    'R'+80H,"EM"
        DEFB    'S'+80H,"TOP"
        DEFB    'O'+80H,"UT"    ; 90h
        DEFB    'O'+80H,"N"
        DEFB    'N'+80H,"ULL"
        DEFB    'W'+80H,"AIT"
        DEFB    'D'+80H,"EF"
        DEFB    'P'+80H,"OKE"
        DEFB    'D'+80H,"OKE"
        DEFB    'M'+80H,"OKE"
        DEFB    'M'+80H,"EEK"
        DEFB    'L'+80H,"INES"
        DEFB    'C'+80H,"LS"
        DEFB    'W'+80H,"IDTH"
        DEFB    'M'+80H,"ONITOR"
        DEFB    'R'+80H,"ESET"
        DEFB    'P'+80H,"RINT"
        DEFB    'C'+80H,"ONT"
        DEFB    'L'+80H,"IST"   ; A0h
        DEFB    'C'+80H,"LEAR"
        DEFB    'H'+80H,"LOAD"
        DEFB    'N'+80H,"EW"

        DEFB    'T'+80H,"AB("
        DEFB    'T'+80H,"O"
        DEFB    'F'+80H,"N"
        DEFB    'S'+80H,"PC("
        DEFB    'T'+80H,"HEN"
        DEFB    'N'+80H,"OT"
        DEFB    'S'+80H,"TEP"

        DEFB    '&'+80H
        DEFB    '+'+80H
        DEFB    '-'+80H
        DEFB    '*'+80H
        DEFB    '/'+80H
        DEFB    '^'+80H        ; B0h
        DEFB    'A'+80H,"ND"
        DEFB    'O'+80H,"R"
        DEFB    '>'+80H
        DEFB    '='+80H
        DEFB    '<'+80H

        DEFB    'S'+80H,"GN"
        DEFB    'I'+80H,"NT"
        DEFB    'A'+80H,"BS"
        DEFB    'U'+80H,"SR"
        DEFB    'F'+80H,"RE"
        DEFB    'I'+80H,"NP"
        DEFB    'P'+80H,"OS"
        DEFB    'S'+80H,"QR"
        DEFB    'R'+80H,"ND"
        DEFB    'L'+80H,"OG"
        DEFB    'E'+80H,"XP"    ; C0h
        DEFB    'C'+80H,"OS"
        DEFB    'S'+80H,"IN"
        DEFB    'T'+80H,"AN"
        DEFB    'A'+80H,"CS"
        DEFB    'A'+80H,"SN"
        DEFB    'A'+80H,"TN"
        DEFB    'P'+80H,"EEK"
        DEFB    'D'+80H,"EEK"
        DEFB    'L'+80H,"EN"
        DEFB    'S'+80H,"TR$"
        DEFB    'V'+80H,"AL"
        DEFB    'A'+80H,"SC"
        DEFB    'C'+80H,"HR$"
        DEFB    'H'+80H,"EX$"
        DEFB    'L'+80H,"EFT$"
        DEFB    'R'+80H,"IGHT$" ; D0h
        DEFB    'M'+80H,"ID$"
        DEFB    80H             ; End of list marker

; KEYWORD ADDRESS TABLE

WORDTB: DEFW    PEND
        DEFW    FOR
        DEFW    NEXT
        DEFW    DATA
        DEFW    INPUT
        DEFW    DIM
        DEFW    READ
        DEFW    LET
        DEFW    GOTO
        DEFW    RUN
        DEFW    IF
        DEFW    RESTOR
        DEFW    GOSUB
        DEFW    RETURN
        DEFW    REM
        DEFW    STOP
        DEFW    POUT
        DEFW    ON
        DEFW    NULL
        DEFW    WAIT
        DEFW    DEF
        DEFW    POKE
        DEFW    DOKE
        DEFW    MOKE
        DEFW    MEEK
        DEFW    LINES
        DEFW    CLS
        DEFW    WIDTH
        DEFW    MONITR
        DEFW    RESET
        DEFW    PRINT
        DEFW    CONT
        DEFW    LIST
        DEFW    CLEAR
        DEFW    HLOAD
        DEFW    NEW

; RESERVED WORD TOKEN VALUES

        DEFC    ZEND    =   080H        ; END
        DEFC    ZFOR    =   081H        ; FOR
        DEFC    ZDATA   =   083H        ; DATA
        DEFC    ZGOTO   =   088H        ; GOTO
        DEFC    ZGOSUB  =   08CH        ; GOSUB
        DEFC    ZREM    =   08EH        ; REM
        DEFC    ZPRINT  =   09EH        ; PRINT
        DEFC    ZNEW    =   0A3H        ; NEW

        DEFC    ZTAB    =   0A4H        ; TAB
        DEFC    ZTO     =   0A5H        ; TO
        DEFC    ZFN     =   0A6H        ; FN
        DEFC    ZSPC    =   0A7H        ; SPC
        DEFC    ZTHEN   =   0A8H        ; THEN
        DEFC    ZNOT    =   0A9H        ; NOT
        DEFC    ZSTEP   =   0AAH        ; STEP

        DEFC    ZAMP    =   0ABH        ; &
        DEFC    ZPLUS   =   0ACH        ; +
        DEFC    ZMINUS  =   0ADH        ; -
        DEFC    ZTIMES  =   0AEH        ; *
        DEFC    ZDIV    =   0AFH        ; /
        DEFC    ZOR     =   0B2H        ; OR
        DEFC    ZGTR    =   0B3H        ; >
        DEFC    ZEQUAL  =   0B4H        ; =
        DEFC    ZLTH    =   0B5H        ; <
        DEFC    ZSGN    =   0B6H        ; SGN
        DEFC    ZLEFT   =   0CFH        ; LEFT$

; ARITHMETIC PRECEDENCE TABLE

PRITAB: DEFB    79H             ; Precedence value
        DEFW    PADD            ; FPREG = <last> + FPREG

        DEFB    79H             ; Precedence value
        DEFW    PSUB            ; FPREG = <last> - FPREG

        DEFB    7CH             ; Precedence value
        DEFW    MULT            ; FPREG = <last> * FPREG

        DEFB    7CH             ; Precedence value
        DEFW    DIV             ; FPREG = <last> / FPREG

        DEFB    7FH             ; Precedence value
        DEFW    POWER           ; FPREG = <last> ^ FPREG

        DEFB    50H             ; Precedence value
        DEFW    PAND            ; FPREG = <last> AND FPREG

        DEFB    46H             ; Precedence value
        DEFW    POR             ; FPREG = <last> OR FPREG

; BASIC ERROR CODE LIST

ERRORS: DEFB    "NF"            ; NEXT without FOR
        DEFB    "SN"            ; Syntax error
        DEFB    "RG"            ; RETURN without GOSUB
        DEFB    "OD"            ; Out of DATA
        DEFB    "FC"            ; Illegal function call
        DEFB    "OV"            ; Overflow error
        DEFB    "OM"            ; Out of memory
        DEFB    "UL"            ; Undefined line
        DEFB    "BS"            ; Bad subscript
        DEFB    "DD"            ; Re-DIMensioned array
        DEFB    "/0"            ; Division by zero
        DEFB    "ID"            ; Illegal direct
        DEFB    "TM"            ; Type mis-match
        DEFB    "OS"            ; Out of string space
        DEFB    "LS"            ; String too long
        DEFB    "ST"            ; String formula too complex
        DEFB    "CN"            ; Can't CONTinue
        DEFB    "UF"            ; Undefined FN function
        DEFB    "MO"            ; Missing operand
        DEFB    "HX"            ; HEX error

; INITIALISATION TABLE --------------------------------------------------------

INITAB: JP      WARMST          ; Warm start jump
        JP      FCERR           ; "USR (X)" jump (Set to Error)

        OUT     (0),A           ; "OUT p,n" skeleton
        RET

        DEFS    14              ; Division support routine - unused

        DEFB    0,0,0                   ; Random number seed
                                        ; table used by RND
        DEFB    035H,04AH,0CAH,099H     ;-2.65145E+07
        DEFB    039H,01CH,076H,098H     ; 1.61291E+07
        DEFB    022H,095H,0B3H,098H     ;-1.17691E+07
        DEFB    00AH,0DDH,047H,098H     ; 1.30983E+07
        DEFB    053H,0D1H,099H,099H     ;-2-01612E+07
        DEFB    00AH,01AH,09FH,098H     ;-1.04269E+07
        DEFB    065H,0BCH,0CDH,098H     ;-1.34831E+07
        DEFB    0D6H,077H,03EH,098H     ; 1.24825E+07
        DEFB    052H,0C7H,04FH,080H     ; Last random number

        IN      A,(0)           ; INP (x) skeleton
        RET

        DEFB    1               ; POS (x) number (1)
        DEFB    255             ; Terminal width (255 = no auto CRLF)
        DEFB    70              ; Width for commas (6 columns of 14 width)
        DEFB    0               ; No nulls after input bytes
        DEFB    0               ; Output enabled (^O off)

        DEFW    20              ; Initial lines counter
        DEFW    20              ; Initial lines number
        DEFW    0               ; Array load/save check sum

        DEFB    0               ; Break not by NMI
        DEFB    0               ; Break flag

        JP      TTYLIN          ; Input reflection (set to TTY)

        DEFW    STLOOK          ; Temp string space
        DEFW    -2              ; Current line number (cold)
        DEFW    PROGST+1        ; Start of program text
INITBE:
        DEFS    3               ; Fill 3 Bytes for copy

; END OF INITIALISATION TABLE -------------------------------------------------

ERRMSG: DEFB    " Error",0
INMSG:  DEFB    " in ",0
        DEFC    ZERBYT  =   $-1 ; A zero byte
OKMSG:  DEFB    "Ok",CR,LF,0,0
BRKMSG: DEFB    "Break",0

BAKSTK: LD      HL,4            ; Look for "FOR" block with
        ADD     HL,SP           ; same index as specified
LOKFOR: LD      A,(HL)          ; Get block ID
        INC     HL              ; Point to index address
        CP      ZFOR            ; Is it a "FOR" token
        RET     NZ              ; No - exit
        LD      C,(HL)          ; BC = Address of "FOR" index
        INC     HL
        LD      B,(HL)
        INC     HL              ; Point to sign of STEP
        PUSH    HL              ; Save pointer to sign
        LD      HL,BC           ; HL = address of "FOR" index
        LD      A,D             ; See if an index was specified
        OR      E               ; DE = 0 if no index specified
        EX      DE,HL           ; Specified index into HL
        JP      Z,INDFND        ; Skip if no index given
        EX      DE,HL           ; Index back into DE
        CALL    CPDEHL          ; Compare index with one given
INDFND: LD      BC,16-3         ; Offset to next block
        POP     HL              ; Restore pointer to sign
        RET     Z               ; Return if block found
        ADD     HL,BC           ; Point to next block
        JP      LOKFOR          ; Keep on looking

MOVUP:  CALL    ENFMEM          ; See if enough memory
MOVSTR: PUSH    BC              ; Save end of source
        EX      (SP),HL         ; Swap source and dest" end
        POP     BC              ; Get end of destination
MOVLP:  CALL    CPDEHL          ; See if list moved
        LD      A,(HL)          ; Get byte
        LD      (BC),A          ; Move it
        RET     Z               ; Exit if all done
        DEC     BC              ; Next byte to move to
        DEC     HL              ; Next byte to move
        JP      MOVLP           ; Loop until all bytes moved

CHKSTK: PUSH    HL              ; Save code string address
        LD      HL,(ARREND)     ; Lowest free memory
        LD      B,0             ; BC = Number of levels to test
        ADD     HL,BC           ; 2 Bytes for each level
        ADD     HL,BC
        DEFB    3EH             ; Skip "PUSH HL"
ENFMEM: PUSH    HL              ; Save code string address
        LD      A,0D0H          ; 48 Bytes minimum RAM
        SUB     L
        LD      L,A
        LD      A,0FFH          ; 48 Bytes minimum RAM
        SBC     A,H
        JP      C,OMERR         ; Not enough - ?OM Error
        LD      H,A
        ADD     HL,SP           ; Test if stack is overflowed
        POP     HL              ; Restore code string address
        RET     C               ; Return if enough mmory
OMERR:  LD      E,OM            ; ?OM Error
        JP      ERROR

DATSNR: LD      HL,(DATLIN)     ; Get line of current DATA item
        LD      (LINEAT),HL     ; Save as current line
SNERR:  LD      E,SN            ; ?SN Error
        DEFB    01H             ; Skip "LD E,DZ"
DZERR:  LD      E,DZ            ; ?/0 Error
        DEFB    01H             ; Skip "LD E,NF"
NFERR:  LD      E,NF            ; ?NF Error
        DEFB    01H             ; Skip "LD E,DD"
DDERR:  LD      E,DD            ; ?DD Error
        DEFB    01H             ; Skip "LD E,UF"
UFERR:  LD      E,UF            ; ?UF Error
        DEFB    01H             ; Skip "LD E,OV
OVERR:  LD      E,OV            ; ?OV Error
        DEFB    01H             ; Skip "LD E,TM"
TMERR:  LD      E,TM            ; ?TM Error
        DEFB    01H             ; Skip "LD E,HX"
HXERR:  LD      E,HX            ; ?HEX Error

ERROR:  CALL    CLREG           ; Clear registers and stack
        LD      (CTLOFG),A      ; Enable output (A is 0)
        CALL    STTLIN          ; Start new line
        LD      HL,ERRORS       ; Point to error codes
        LD      D,A             ; D = 0 (A is 0)
        LD      A,'?'
        CALL    OUTC            ; Output '?'
        ADD     HL,DE           ; Offset to correct error code
        LD      A,(HL)          ; First character
        CALL    OUTC            ; Output it
        CALL    GETCHR          ; Get next character
        CALL    OUTC            ; Output it
        LD      HL,ERRMSG       ; "Error" message
ERRIN:  CALL    PRS             ; Output message
        LD      HL,(LINEAT)     ; Get line of error
        LD      DE,-2           ; Cold start error if -2
        CALL    CPDEHL          ; See if cold start error
        JP      Z,CSTART        ; Cold start error - Restart
        LD      A,H             ; Was it a direct error?
        AND     L               ; Line = -1 if direct error
        INC     A
        CALL    NZ,LINEIN       ; No - output line of error
        DEFB    3EH             ; Skip "POP BC"
POPNOK: POP     BC              ; Drop address in input buffer

PRNTOK: XOR     A               ; Output "Ok" and get command
        LD      (CTLOFG),A      ; Enable output
        CALL    STTLIN          ; Start new line
        LD      HL,OKMSG        ; "Ok" message
        CALL    PRS             ; Output "Ok"
GETCMD: LD      HL,-1           ; Flag direct mode
        LD      (LINEAT),HL     ; Save as current line
        CALL    RINPUT          ; Get an input line
        JP      C,GETCMD        ; Get line again if break
        CALL    GETCHR          ; Get first character
        JP      Z,GETCMD        ; Nothing entered - Get another
        PUSH    AF              ; Save Carry status
        CALL    ATOH            ; Get line number into DE
        PUSH    DE              ; Save line number
        CALL    CRUNCH          ; Tokenise rest of line
        LD      B,A             ; Length of tokenised line
        POP     DE              ; Restore line number
        POP     AF              ; Restore Carry
        JP      NC,EXCUTE       ; No line number - Direct mode
        PUSH    DE              ; Save line number
        PUSH    BC              ; Save length of tokenised line
        XOR     A
        LD      (LSTBIN),A      ; Clear last byte input
        CALL    GETCHR          ; Get next character
        PUSH    AF              ; Save flags
        CALL    SRCHLN          ; Search for line number in DE
        JP      C,LINFND        ; Jump if line found
        POP     AF              ; Get status
        PUSH    AF              ; And re-save
        JP      Z,ULERR         ; Nothing after number - Error
        OR      A               ; Clear Carry
LINFND: PUSH    BC              ; Save address of line in prog
        JP      NC,INEWLN       ; Line not found - Insert new
        EX      DE,HL           ; Next line address in DE
        LD      HL,(PROGND)     ; End of program
SFTPRG: LD      A,(DE)          ; Shift rest of program down
        LD      (BC),A
        INC     BC              ; Next destination
        INC     DE              ; Next source
        CALL    CPDEHL          ; All done?
        JP      NZ,SFTPRG       ; More to do
        LD      HL,BC           ; HL - New end of program
        LD      (PROGND),HL     ; Update end of program

INEWLN: POP     DE              ; Get address of line,
        POP     AF              ; Get status
        JP      Z,SETPTR        ; No text - Set up pointers
        LD      HL,(PROGND)     ; Get end of program
        EX      (SP),HL         ; Get length of input line
        POP     BC              ; End of program to BC
        ADD     HL,BC           ; Find new end
        PUSH    HL              ; Save new end
        CALL    MOVUP           ; Make space for line
        POP     HL              ; Restore new end
        LD      (PROGND),HL     ; Update end of program pointer
        EX      DE,HL           ; Get line to move up in HL
        LD      (HL),H          ; Save MSB
        POP     DE              ; Get new line number
        INC     HL              ; Skip pointer
        INC     HL
        LD      (HL),E          ; Save LSB of line number
        INC     HL
        LD      (HL),D          ; Save MSB of line number
        INC     HL              ; To first byte in line
        LD      DE,BUFFER       ; Copy buffer to program
MOVBUF: LD      A,(DE)          ; Get source
        LD      (HL),A          ; Save destinations
        INC     HL              ; Next source
        INC     DE              ; Next destination
        OR      A               ; Done?
        JP      NZ,MOVBUF       ; No - Repeat
SETPTR: CALL    RUNFST          ; Set line pointers
        INC     HL              ; To LSB of pointer
        EX      DE,HL           ; Address to DE
PTRLP:  LD      HL,DE           ; Address to HL
        LD      A,(HL)          ; Get LSB of pointer
        INC     HL              ; To MSB of pointer
        OR      (HL)            ; Compare with MSB pointer
        JP      Z,GETCMD        ; Get command line if end
        INC     HL              ; To LSB of line number
        INC     HL              ; Skip line number
        INC     HL              ; Point to first byte in line
        XOR     A               ; Looking for 00 byte
FNDEND: CP      (HL)            ; Found end of line?
        INC     HL              ; Move to next byte
        JP      NZ,FNDEND       ; No - Keep looking
        EX      DE,HL           ; Next line address to HL
        LD      (HL),E          ; Save LSB of pointer
        INC     HL
        LD      (HL),D          ; Save MSB of pointer
        JP      PTRLP           ; Do next line

SRCHLN: LD      HL,(BASTXT)     ; Start of program text
SRCHLP: LD      BC,HL           ; BC = Address to look at
        LD      A,(HL)          ; Get address of next line
        INC     HL
        OR      (HL)            ; End of program found?
        DEC     HL
        RET     Z               ; Yes - Line not found
        INC     HL
        INC     HL
        LD      A,(HL)          ; Get LSB of line number
        INC     HL
        LD      H,(HL)          ; Get MSB of line number
        LD      L,A
        CALL    CPDEHL          ; Compare with line in DE
        LD      HL,BC           ; HL = Start of this line
        LD      A,(HL)          ; Get LSB of next line address
        INC     HL
        LD      H,(HL)          ; Get MSB of next line address
        LD      L,A             ; Next line to HL
        CCF
        RET     Z               ; Lines found - Exit
        CCF
        RET     NC              ; Line not found,at line after
        JP      SRCHLP          ; Keep looking

NEW:    RET     NZ              ; Return if any more on line
CLRPTR: LD      HL,(BASTXT)     ; Point to start of program
        XOR     A               ; Set program area to empty
        LD      (HL),A          ; Save LSB = 00
        INC     HL
        LD      (HL),A          ; Save MSB = 00
        INC     HL
        LD      (PROGND),HL     ; Set program end

RUNFST: LD      HL,(BASTXT)     ; Clear all variables
        DEC     HL

INTVAR: LD      (BRKLIN),HL     ; Initialise RUN variables
        LD      HL,(LSTRAM)     ; Get end of RAM
        LD      (STRBOT),HL     ; Clear string space
        XOR     A
        CALL    RESTOR          ; Reset DATA pointers
        LD      HL,(PROGND)     ; Get end of program
        LD      (VAREND),HL     ; Clear variables
        LD      (ARREND),HL     ; Clear arrays

CLREG:  POP     BC              ; Save return address
        LD      HL,(STRSPC)     ; Get end of working RAM
        LD      SP,HL           ; Set stack
        LD      HL,TMSTPL       ; Temporary string pool
        LD      (TMSTPT),HL     ; Reset temporary string ptr
        XOR     A               ; A = 00
        LD      L,A             ; HL = 0000
        LD      H,A
        LD      (CONTAD),HL     ; No CONTinue
        LD      (FORFLG),A      ; Clear FOR flag
        LD      (FNRGNM),HL     ; Clear FN argument
        PUSH    HL              ; HL = 0000
        PUSH    BC              ; Put back return
DOAGN:  LD      HL,(BRKLIN)     ; Get address of code to RUN
        RET                     ; Return to execution driver

PROMPT: LD      A,'?'           ; '?'
        CALL    OUTC            ; Output character
        LD      A,' '           ; Space
        CALL    OUTC            ; Output character
        JP      RINPUT          ; Get input line

CRUNCH: XOR     A               ; Tokenise line @ HL to BUFFER
        LD      (DATFLG),A      ; Reset literal flag
        LD      C,2+3           ; 2 byte number and 3 nulls
        LD      DE,BUFFER       ; Start of input buffer
CRNCLP: LD      A,(HL)          ; Get byte
        CP      ' '             ; Is it a space?
        JP      Z,MOVDIR        ; Yes - Copy direct
        LD      B,A             ; Save character
        CP      '"'             ; Is it a quote?
        JP      Z,CPYLIT        ; Yes - Copy literal string
        OR      A               ; Is it end of buffer?
        JP      Z,ENDBUF        ; Yes - End buffer
        LD      A,(DATFLG)      ; Get data type
        OR      A               ; Literal?
        LD      A,(HL)          ; Get byte to copy
        JP      NZ,MOVDIR       ; Literal - Copy direct
        CP      '?'             ; Is it '?' short for PRINT
        LD      A,ZPRINT        ; "PRINT" token
        JP      Z,MOVDIR        ; Yes - replace it
        LD      A,(HL)          ; Get byte again
        CP      '0'             ; Is it less than '0'
        JP      C,FNDWRD        ; Yes - Look for reserved words
        CP      60              ; ';'+1 Is it "0123456789:;" ?
        JP      C,MOVDIR        ; Yes - copy it direct
FNDWRD: PUSH    DE              ; Look for reserved words
        LD      DE,WORDS-1      ; Point to table
        PUSH    BC              ; Save count
        LD      BC,RETNAD       ; Where to return to
        PUSH    BC              ; Save return address
        LD      B,ZEND-1        ; First token value -1
        LD      A,(HL)          ; Get byte
        CP      'a'             ; Less than 'a' ?
        JP      C,SEARCH        ; Yes - search for words
        CP      'z'+1           ; Greater than 'z' ?
        JP      NC,SEARCH       ; Yes - search for words
        AND     01011111B       ; Force upper case
        LD      (HL),A          ; Replace byte
SEARCH: LD      C,(HL)          ; Search for a word
        EX      DE,HL
GETNXT: INC     HL              ; Get next reserved word
        OR      (HL)            ; Start of word?
        JP      P,GETNXT        ; No - move on
        INC     B               ; Increment token value
        LD      A,(HL)          ; Get byte from table
        AND     01111111B       ; Strip bit 7
        RET     Z               ; Return if end of list
        CP      C               ; Same character as in buffer?
        JP      NZ,GETNXT       ; No - get next word
        EX      DE,HL
        PUSH    HL              ; Save start of word

NXTBYT: INC     DE              ; Look through rest of word
        LD      A,(DE)          ; Get byte from table
        OR      A               ; End of word ?
        JP      M,MATCH         ; Yes - Match found
        LD      C,A             ; Save it
        LD      A,B             ; Get token value
        CP      ZGOTO           ; Is it "GOTO" token ?
        JP      NZ,NOSPC        ; No - Don't allow spaces
        CALL    GETCHR          ; Get next character
        DEC     HL              ; Cancel increment from GETCHR
NOSPC:  INC     HL              ; Next byte
        LD      A,(HL)          ; Get byte
        CP      'a'             ; Less than 'a' ?
        JP      C,NOCHNG        ; Yes - don't change
        AND     01011111B       ; Make upper case
NOCHNG: CP      C               ; Same as in buffer ?
        JP      Z,NXTBYT        ; Yes - keep testing
        POP     HL              ; Get back start of word
        JP      SEARCH          ; Look at next word

MATCH:  LD      C,B             ; Word found - Save token value
        POP     AF              ; Throw away return
        EX      DE,HL
        RET                     ; Return to "RETNAD"
RETNAD: EX      DE,HL           ; Get address in string
        LD      A,C             ; Get token value
        POP     BC              ; Restore buffer length
        POP     DE              ; Get destination address
MOVDIR: INC     HL              ; Next source in buffer
        LD      (DE),A          ; Put byte in buffer
        INC     DE              ; Move up buffer
        INC     C               ; Increment length of buffer
        SUB     ':'             ; End of statement?
        JP      Z,SETLIT        ; Jump if multi-statement line
        CP      ZDATA-3AH       ; Is it DATA statement ?
        JP      NZ,TSTREM       ; No - see if REM
SETLIT: LD      (DATFLG),A      ; Set literal flag
TSTREM: SUB     ZREM-3AH        ; Is it REM?
        JP      NZ,CRNCLP       ; No - Leave flag
        LD      B,A             ; Copy rest of buffer
NXTCHR: LD      A,(HL)          ; Get byte
        OR      A               ; End of line ?
        JP      Z,ENDBUF        ; Yes - Terminate buffer
        CP      B               ; End of statement ?
        JP      Z,MOVDIR        ; Yes - Get next one
CPYLIT: INC     HL              ; Move up source string
        LD      (DE),A          ; Save in destination
        INC     C               ; Increment length
        INC     DE              ; Move up destination
        JP      NXTCHR          ; Repeat

ENDBUF: LD      HL,BUFFER-1     ; Point to start of buffer
        LD      (DE),A          ; Mark end of buffer (A = 00)
        INC     DE
        LD      (DE),A          ; A = 00
        INC     DE
        LD      (DE),A          ; A = 00
        RET

DODEL:  LD      A,(NULFLG)      ; Get null flag status
        OR      A               ; Is it zero?
        LD      A,0             ; Zero A - Leave flags
        LD      (NULFLG),A      ; Zero null flag
        JP      NZ,ECHDEL       ; Set - Echo it
        DEC     B               ; Decrement length
        JP      Z,RINPUT        ; Get line again if empty
        CALL    OUTC            ; Output null character
        DEFB    3EH             ; Skip "DEC B"
ECHDEL: DEC     B               ; Count bytes in buffer
        DEC     HL              ; Back space buffer
        JP      Z,OTKLN         ; No buffer - Try again
        LD      A,(HL)          ; Get deleted byte
        CALL    OUTC            ; Echo it
        JP      MORINP          ; Get more input

DELCHR: CALL    OUTC            ; Output character in A
        DEC     HL              ; Back space buffer
        DEC     B               ; Count bytes in buffer
        JP      NZ,MORINP       ; Not end - Get more
OTKLN:  CALL    OUTC            ; Output character in A
KILIN:  CALL    PRNTCRLF        ; Output CRLF
        JP      RINPUT          ; Get line again

TTYLIN: LD      HL,BUFFER       ; Get a line by character
        LD      B,1             ; Set buffer as empty
        XOR     A
        LD      (NULFLG),A      ; Clear null flag
MORINP: CALL    CLOTST          ; Get character and test ^O
        LD      C,A             ; Save character in C
        CP      DEL             ; Delete character?
        JP      Z,DODEL         ; Yes - Process it
        LD      A,(NULFLG)      ; Get null flag
        OR      A               ; Test null flag status
        JP      Z,PROCES        ; Reset - Process character
        LD      A,0             ; Set a null
        CALL    OUTC            ; Output null
        XOR     A               ; Clear A
        LD      (NULFLG),A      ; Reset null flag
PROCES: LD      A,C             ; Get character
        CP      CTRLG           ; Bell?
        JP      Z,PUTCTL        ; Yes - Save it
        CP      CTRLC           ; Is it control "C"?
        CALL    Z,PRNTCRLF      ; Yes - Output CRLF
        SCF                     ; Flag break
        RET     Z               ; Return if control "C"
        CP      CR              ; Is it enter?
        JP      Z,ENDINP        ; Yes - Terminate input
        CP      CTRLU           ; Is it control "U"?
        JP      Z,KILIN         ; Yes - Get another line
        CP      '@'             ; Is it "kill line"?
        JP      Z,OTKLN         ; Yes - Kill line
        CP      '_'             ; Is it delete?
        JP      Z,DELCHR        ; Yes - Delete character
        CP      BKSP            ; Is it backspace?
        JP      Z,DELCHR        ; Yes - Delete character
        CP      CTRLR           ; Is it control "R"?
        JP      NZ,PUTBUF       ; No - Put in buffer
        PUSH    BC              ; Save buffer length
        PUSH    DE              ; Save DE
        PUSH    HL              ; Save buffer address
        LD      (HL),0          ; Mark end of buffer
        CALL    OUTNCR          ; Output and do CRLF
        LD      HL,BUFFER       ; Point to buffer start
        CALL    PRS             ; Output buffer
        POP     HL              ; Restore buffer address
        POP     DE              ; Restore DE
        POP     BC              ; Restore buffer length
        JP      MORINP          ; Get another character

PUTBUF: CP      ' '             ; Is it a control code?
        JP      C,MORINP        ; Yes - Ignore
PUTCTL: LD      A,B             ; Get number of bytes in buffer
        CP      72+1            ; Test for line overflow
        LD      A,CTRLG         ; Set a bell
        JP      NC,OUTNBS       ; Ring bell if buffer full
        LD      A,C             ; Get character
        LD      (HL),C          ; Save in buffer
        LD      (LSTBIN),A      ; Save last input byte
        INC     HL              ; Move up buffer
        INC     B               ; Increment length
OUTIT:  CALL    OUTC            ; Output the character entered
        JP      MORINP          ; Get another character

OUTNBS: CALL    OUTC            ; Output bell and back over it
        LD      A,BKSP          ; Set back space
        JP      OUTIT           ; Output it and get more

CPDEHL: LD      A,H             ; Get H
        SUB     D               ; Compare with D
        RET     NZ              ; Different - Exit
        LD      A,L             ; Get L
        SUB     E               ; Compare with E
        RET                     ; Return status

CHKSYN: LD      A,(HL)          ; Check syntax of character
        EX      (SP),HL         ; Address of test byte
        CP      (HL)            ; Same as in code string?
        INC     HL              ; Return address
        EX      (SP),HL         ; Put it back
        JP      Z,GETCHR        ; Yes - Get next character
        JP      SNERR           ; Different - ?SN Error

OUTC:   PUSH    AF              ; Save character
        LD      A,(CTLOFG)      ; Get control "O" flag
        OR      A               ; Is it set?
        JP      NZ,POPAF        ; Yes - don't output
        POP     AF              ; Restore character
        PUSH    BC              ; Save buffer length
        PUSH    AF              ; Save character
        CP      ' '             ; Is it a control code?
        JP      C,DINPOS        ; Yes - Don't INC POS(X)
        LD      A,(LWIDTH)      ; Get line width
        LD      B,A             ; To B
        LD      A,(CURPOS)      ; Get cursor position
        INC     B               ; Width 255?
        JP      Z,INCLEN        ; Yes - No width limit
        DEC     B               ; Restore width
        CP      B               ; At end of line?
        CALL    Z,PRNTCRLF      ; Yes - output CRLF
INCLEN: INC     A               ; Move on one character
        LD      (CURPOS),A      ; Save new position
DINPOS: POP     AF              ; Restore character
        POP     BC              ; Restore buffer length
        JP      $0008           ; Send it via RST 08

OUTNCR: CALL    OUTC            ; Output character in A
        JP      PRNTCRLF        ; Output CRLF

CLOTST: RST     10H             ; Get input character
        AND     01111111B       ; Strip bit 7
        CP      CTRLO           ; Is it control "O"?
        RET     NZ              ; No don't flip flag
        LD      A,(CTLOFG)      ; Get flag
        CPL                     ; Flip it
        LD      (CTLOFG),A      ; Put it back
        XOR     A               ; Null character
        RET

LIST:   CALL    ATOH            ; ASCII number to DE
        RET     NZ              ; Return if anything extra
        POP     BC              ; Rubbish - Not needed
        CALL    SRCHLN          ; Search for line number in DE
        PUSH    BC              ; Save address of line
        CALL    SETLIN          ; Set up lines counter
LISTLP: POP     HL              ; Restore address of line
        LD      C,(HL)          ; Get LSB of next line
        INC     HL
        LD      B,(HL)          ; Get MSB of next line
        INC     HL
        LD      A,B             ; BC = 0 (End of program)?
        OR      C
        JP      Z,PRNTOK        ; Yes - Go to command mode
        CALL    COUNT           ; Count lines
        CALL    TSTBRK          ; Test for break key
        PUSH    BC              ; Save address of next line
        CALL    PRNTCRLF        ; Output CRLF
        LD      E,(HL)          ; Get LSB of line number
        INC     HL
        LD      D,(HL)          ; Get MSB of line number
        INC     HL
        PUSH    HL              ; Save address of line start
        EX      DE,HL           ; Line number to HL
        CALL    PRNTHL          ; Output line number in decimal
        LD      A,' '           ; Space after line number
        POP     HL              ; Restore start of line address
LSTLP2: CALL    OUTC            ; Output character in A
LSTLP3: LD      A,(HL)          ; Get next byte in line
        OR      A               ; End of line?
        INC     HL              ; To next byte in line
        JP      Z,LISTLP        ; Yes - get next line
        JP      P,LSTLP2        ; No token - output it
        SUB     ZEND-1          ; Find and output word
        LD      C,A             ; Token offset+1 to C
        LD      DE,WORDS        ; Reserved word list
FNDTOK: LD      A,(DE)          ; Get character in list
        INC     DE              ; Move on to next
        OR      A               ; Is it start of word?
        JP      P,FNDTOK        ; No - Keep looking for word
        DEC     C               ; Count words
        JP      NZ,FNDTOK       ; Not there - keep looking
OUTWRD: AND     01111111B       ; Strip bit 7
        CALL    OUTC            ; Output first character
        LD      A,(DE)          ; Get next character
        INC     DE              ; Move on to next
        OR      A               ; Is it end of word?
        JP      P,OUTWRD        ; No - output the rest
        JP      LSTLP3          ; Next byte in line

SETLIN: PUSH    HL              ; Set up LINES counter
        LD      HL,(LINESN)     ; Get LINES number
        LD      (LINESC),HL     ; Save in LINES counter
        POP     HL
        RET

COUNT:  PUSH    HL              ; Save code string address
        PUSH    BC
        LD      HL,(LINESC)     ; Get LINES counter
        LD      BC,1
        SUB     HL,BC           ; Decrement
        LD      (LINESC),HL     ; Put it back
        POP     BC
        POP     HL              ; Restore code string address
        RET     P               ; Return if more lines to go
        PUSH    HL              ; Save code string address
        LD      HL,(LINESN)     ; Get LINES number
        LD      (LINESC),HL     ; Reset LINES counter
        RST     10H             ; Get input character
        CP      CTRLC           ; Is it control "C"?
        JP      Z,RSLNBK        ; Yes - Reset LINES and break
        POP     HL              ; Restore code string address
        JP      COUNT           ; Keep on counting

RSLNBK: LD      HL,(LINESN)     ; Get LINES number
        LD      (LINESC),HL     ; Reset LINES counter
        JP      BRKRET          ; Go and output "Break"

FOR:    LD      A,64H           ; Flag "FOR" assignment
        LD      (FORFLG),A      ; Save "FOR" flag
        CALL    LET             ; Set up initial index
        POP     BC              ; Drop RETurn address
        PUSH    HL              ; Save code string address
        CALL    DATA            ; Get next statement address
        LD      (LOOPST),HL     ; Save it for start of loop
        LD      HL,2            ; Offset for "FOR" block
        ADD     HL,SP           ; Point to it
FORSLP: CALL    LOKFOR          ; Look for existing "FOR" block
        POP     DE              ; Get code string address
        JP      NZ,FORFND       ; No nesting found
        ADD     HL,BC           ; Move into "FOR" block
        PUSH    DE              ; Save code string address
        DEC     HL
        LD      D,(HL)          ; Get MSB of loop statement
        DEC     HL
        LD      E,(HL)          ; Get LSB of loop statement
        INC     HL
        INC     HL
        PUSH    HL              ; Save block address
        LD      HL,(LOOPST)     ; Get address of loop statement
        CALL    CPDEHL          ; Compare the FOR loops
        POP     HL              ; Restore block address
        JP      NZ,FORSLP       ; Different FORs - Find another
        POP     DE              ; Restore code string address
        LD      SP,HL           ; Remove all nested loops

FORFND: EX      DE,HL           ; Code string address to HL
        LD      C,8
        CALL    CHKSTK          ; Check for 8 levels of stack
        PUSH    HL              ; Save code string address
        LD      HL,(LOOPST)     ; Get first statement of loop
        EX      (SP),HL         ; Save and restore code string
        PUSH    HL              ; Re-save code string address
        LD      HL,(LINEAT)     ; Get current line number
        EX      (SP),HL         ; Save and restore code string
        CALL    TSTNUM          ; Make sure it's a number
        CALL    CHKSYN          ; Make sure "TO" is next
        DEFB    ZTO             ; "TO" token
        CALL    GETNUM          ; Get "TO" expression value
        PUSH    HL              ; Save code string address
        CALL    BCDEFP          ; Move "TO" value to BCDE
        POP     HL              ; Restore code string address
        PUSH    BC              ; Save "TO" value in block
        PUSH    DE
        LD      BC,8100H        ; BCDE - 1 (default STEP)
        LD      D,C             ; C=0
        LD      E,D             ; D=0
        LD      A,(HL)          ; Get next byte in code string
        CP      ZSTEP           ; See if "STEP" is stated
        LD      A,1             ; Sign of step = 1
        JP      NZ,SAVSTP       ; No STEP given - Default to 1
        CALL    GETCHR          ; Jump over "STEP" token
        CALL    GETNUM          ; Get step value
        PUSH    HL              ; Save code string address
        CALL    BCDEFP          ; Move STEP to BCDE
        CALL    TSTSGN          ; Test sign of FPREG
        POP     HL              ; Restore code string address
SAVSTP: PUSH    BC              ; Save the STEP value in block
        PUSH    DE
        PUSH    AF              ; Save sign of STEP
        INC     SP              ; Don't save flags
        PUSH    HL              ; Save code string address
        LD      HL,(BRKLIN)     ; Get address of index variable
        EX      (SP),HL         ; Save and restore code string
PUTFID: LD      B,ZFOR          ; "FOR" block marker
        PUSH    BC              ; Save it
        INC     SP              ; Don't save C

RUNCNT: CALL    TSTBRK          ; Execution driver - Test break
        LD      (BRKLIN),HL     ; Save code address for break
        LD      A,(HL)          ; Get next byte in code string
        CP      ':'             ; Multi statement line?
        JP      Z,EXCUTE        ; Yes - Execute it
        OR      A               ; End of line?
        JP      NZ,SNERR        ; No - Syntax error
        INC     HL              ; Point to address of next line
        LD      A,(HL)          ; Get LSB of line pointer
        INC     HL
        OR      (HL)            ; Is it zero (End of prog)?
        JP      Z,ENDPRG        ; Yes - Terminate execution
        INC     HL              ; Point to line number
        LD      E,(HL)          ; Get LSB of line number
        INC     HL
        LD      D,(HL)          ; Get MSB of line number
        LD      (LINEAT),DE     ; Save as current line number
EXCUTE: CALL    GETCHR          ; Get key word
        LD      DE,RUNCNT       ; Where to RETurn to
        PUSH    DE              ; Save for RETurn
IFJMP:  RET     Z               ; Go to RUNCNT if end of STMT
ONJMP:  SUB     ZEND            ; Is it a token?
        JP      C,LET           ; No - try to assign it
        CP      ZNEW+1-ZEND     ; END to NEW ?
        JP      NC,SNERR        ; Not a key word - ?SN Error
        RLCA                    ; Double it
        LD      C,A             ; BC = Offset into table
        LD      B,0
        EX      DE,HL           ; Save code string address
        LD      HL,WORDTB       ; Keyword address table
        ADD     HL,BC           ; Point to routine address
        LD      C,(HL)          ; Get LSB of routine address
        INC     HL
        LD      B,(HL)          ; Get MSB of routine address
        PUSH    BC              ; Save routine address
        EX      DE,HL           ; Restore code string address

GETCHR: INC     HL              ; Point to next character
        LD      A,(HL)          ; Get next code string byte
        CP      ':'             ; Z if ':'
        RET     NC              ; NC if > "9"
        CP      ' '
        JP      Z,GETCHR        ; Skip over spaces
        CP      '0'
        CCF                     ; NC if < '0'
        INC     A               ; Test for zero - Leave carry
        DEC     A               ; Z if Null
        RET

RESTOR: EX      DE,HL           ; Save code string address
        LD      HL,(BASTXT)     ; Point to start of program
        JP      Z,RESTNL        ; Just RESTORE - reset pointer
        EX      DE,HL           ; Restore code string address
        CALL    ATOH            ; Get line number to DE
        PUSH    HL              ; Save code string address
        CALL    SRCHLN          ; Search for line number in DE
        LD      HL,BC           ; HL = Address of line
        POP     DE              ; Restore code string address
        JP      NC,ULERR        ; ?UL Error if not found
RESTNL: DEC     HL              ; Byte before DATA statement
UPDATA: LD      (NXTDAT),HL     ; Update DATA pointer
        EX      DE,HL           ; Restore code string address
        RET


TSTBRK: RST     18H             ; Check input status
        OR      A               ; Check count Zero
        RET     Z               ; No key, go back
        RST     10H             ; Get the key into A
        CP      ESC             ; Escape key?
        JP      Z,BRK           ; Yes, break
        CP      CTRLC           ; <Ctrl-C>
        JP      Z,BRK           ; Yes, break
        CP      CTRLS           ; Stop scrolling?
        RET     NZ              ; Other key, ignore


STALL:  RST     10H             ; Wait for key
        CP      CTRLQ           ; Resume scrolling?
        RET      Z              ; Release the chokehold
        CP      CTRLC           ; Second break?
        JP      Z,STOP          ; Break during hold exits prog
        JP      STALL           ; Loop until <Ctrl-Q> or <brk>

BRK:    LD      A,$FF           ; Set BRKFLG
        LD      (BRKFLG),A      ; Store it


STOP:   RET     NZ              ; Exit if anything else
        DEFB    0F6H            ; Flag "STOP"
PEND:   RET     NZ              ; Exit if anything else
        LD      (BRKLIN),HL     ; Save point of break
        DEFB    21H             ; Skip "OR 11111111B"
INPBRK: OR      11111111B       ; Flag "Break" wanted
        POP     BC              ; Return not needed and more
ENDPRG: LD      HL,(LINEAT)     ; Get current line number
        PUSH    AF              ; Save STOP / END status
        LD      A,L             ; Is it direct break?
        AND     H
        INC     A               ; Line is -1 if direct break
        JP      Z,NOLIN         ; Yes - No line number
        LD      (ERRLIN),HL     ; Save line of break
        LD      HL,(BRKLIN)     ; Get point of break
        LD      (CONTAD),HL     ; Save point to CONTinue
NOLIN:  XOR     A
        LD      (CTLOFG),A      ; Enable output
        CALL    STTLIN          ; Start a new line
        POP     AF              ; Restore STOP / END status
        LD      HL,BRKMSG       ; "Break" message
        JP      NZ,ERRIN        ; "in line" wanted?
        JP      PRNTOK          ; Go to command mode

CONT:   LD      HL,(CONTAD)     ; Get CONTinue address
        LD      A,H             ; Is it zero?
        OR      L
        LD      E,CN            ; ?CN Error
        JP      Z,ERROR         ; Yes - output "?CN Error"
        EX      DE,HL           ; Save code string address
        LD      HL,(ERRLIN)     ; Get line of last break
        LD      (LINEAT),HL     ; Set up current line number
        EX      DE,HL           ; Restore code string address
        RET                     ; CONTinue where left off

NULL:   CALL    GETINT          ; Get integer 0-255
        RET     NZ              ; Return if bad value
        LD      (NULLS),A       ; Set nulls number
        RET

ACCSUM: PUSH    HL              ; Save address in array
        LD      HL,(CHKSUM)     ; Get check sum
        LD      B,0             ; BC - Value of byte
        LD      C,A
        ADD     HL,BC           ; Add byte to check sum
        LD      (CHKSUM),HL     ; Re-save check sum
        POP     HL              ; Restore address in array
        RET

CHKLTR: LD      A,(HL)          ; Get byte
        CP      'A'             ; < 'a' ?
        RET     C               ; Carry set if not letter
        CP      'Z'+1           ; > 'z' ?
        CCF
        RET                     ; Carry set if not letter

FPSINT: CALL    GETCHR          ; Get next character
POSINT: CALL    GETNUM          ; Get integer 0 to 32767
DEPINT: CALL    TSTSGN          ; Test sign of FPREG
        JP      M,FCERR         ; Negative - ?FC Error
DEINT:  LD      A,(FPEXP)       ; Get integer value to DE
        CP      80H+16          ; Exponent in range (16 bits)?
        JP      C,FPINT         ; Yes - convert it
        LD      BC,9080H        ; BCDE = -32768
        LD      DE,0000
        PUSH    HL              ; Save code string address
        CALL    CMPNUM          ; Compare FPREG with BCDE
        POP     HL              ; Restore code string address
        LD      D,C             ; MSB to D
        RET     Z               ; Return if in range
FCERR:  LD      E,FC            ; ?FC Error
        JP      ERROR           ; Output error-

ATOH:   DEC     HL              ; ASCII number to DE binary
GETLN:  LD      DE,0            ; Get number to DE
GTLNLP: CALL    GETCHR          ; Get next character
        RET     NC              ; Exit if not a digit
        PUSH    HL              ; Save code string address
        PUSH    AF              ; Save digit
        LD      HL,65529/10     ; Largest number 65529
        CALL    CPDEHL          ; Number in range?
        JP      C,SNERR         ; No - ?SN Error
        LD      HL,DE           ; HL = Number
        ADD     HL,DE           ; Times 2
        ADD     HL,HL           ; Times 4
        ADD     HL,DE           ; Times 5
        ADD     HL,HL           ; Times 10
        POP     AF              ; Restore digit
        SUB     '0'             ; Make it 0 to 9
        LD      E,A             ; DE = Value of digit
        LD      D,0
        ADD     HL,DE           ; Add to number
        EX      DE,HL           ; Number to DE
        POP     HL              ; Restore code string address
        JP      GTLNLP          ; Go to next character

CLEAR:  JP      Z,INTVAR        ; Just "CLEAR" Keep parameters
        CALL    POSINT          ; Get integer 0 to 32767 to DE
        DEC     HL              ; Cancel increment
        CALL    GETCHR          ; Get next character
        PUSH    HL              ; Save code string address
        LD      HL,(LSTRAM)     ; Get end of RAM
        JP      Z,STORED        ; No value given - Use stored
        POP     HL              ; Restore code string address
        CALL    CHKSYN          ; Check for comma
        DEFB    ','
        PUSH    DE              ; Save number
        CALL    POSINT          ; Get integer 0 to 32767
        DEC     HL              ; Cancel increment
        CALL    GETCHR          ; Get next character
        JP      NZ,SNERR        ; ?SN Error if more on line
        EX      (SP),HL         ; Save code string address
        EX      DE,HL           ; Number to DE
STORED: LD      A,L             ; Get LSB of new RAM top
        SUB     E               ; Subtract LSB of string space
        LD      E,A             ; Save LSB
        LD      A,H             ; Get MSB of new RAM top
        SBC     A,D             ; Subtract MSB of string space
        LD      D,A             ; Save MSB
        JP      C,OMERR         ; ?OM Error if not enough mem
        PUSH    HL              ; Save RAM top
        LD      HL,(PROGND)     ; Get program end
        LD      BC,40           ; 40 Bytes minimum working RAM
        ADD     HL,BC           ; Get lowest address
        CALL    CPDEHL          ; Enough memory?
        JP      NC,OMERR        ; No - ?OM Error
        EX      DE,HL           ; RAM top to HL
        LD      (STRSPC),HL     ; Set new string space
        POP     HL              ; End of memory to use
        LD      (LSTRAM),HL     ; Set new top of RAM
        POP     HL              ; Restore code string address
        JP      INTVAR          ; Initialise variables

RUN:    JP      Z,RUNFST        ; RUN from start if just RUN
        CALL    INTVAR          ; Initialise variables
        LD      BC,RUNCNT       ; Execution driver loop
        JP      RUNLIN          ; RUN from line number

GOSUB:  LD      C,3             ; 3 Levels of stack needed
        CALL    CHKSTK          ; Check for 3 levels of stack
        POP     BC              ; Get return address
        PUSH    HL              ; Save code string for RETURN
        PUSH    HL              ; And for GOSUB routine
        LD      HL,(LINEAT)     ; Get current line
        EX      (SP),HL         ; Into stack - Code string out
        LD      A,ZGOSUB        ; "GOSUB" token
        PUSH    AF              ; Save token
        INC     SP              ; Don't save flags

RUNLIN: PUSH    BC              ; Save return address
GOTO:   CALL    ATOH            ; ASCII number to DE binary
        CALL    REM             ; Get end of line
        PUSH    HL              ; Save end of line
        LD      HL,(LINEAT)     ; Get current line
        CALL    CPDEHL          ; Line after current?
        POP     HL              ; Restore end of line
        INC     HL              ; Start of next line
        CALL    C,SRCHLP        ; Line is after current line
        CALL    NC,SRCHLN       ; Line is before current line
        LD      HL,BC           ; Set up code string address
        DEC     HL              ; Incremented after
        RET     C               ; Line found
ULERR:  LD      E,UL            ; ?UL Error
        JP      ERROR           ; Output error message

RETURN: RET     NZ              ; Return if not just RETURN
        LD      D,-1            ; Flag "GOSUB" search
        CALL    BAKSTK          ; Look "GOSUB" block
        LD      SP,HL           ; Kill all FORs in subroutine
        CP      ZGOSUB          ; Test for "GOSUB" token
        LD      E,RG            ; ?RG Error
        JP      NZ,ERROR        ; Error if no "GOSUB" found
        POP     HL              ; Get RETURN line number
        LD      (LINEAT),HL     ; Save as current
        INC     HL              ; Was it from direct statement?
        LD      A,H
        OR      L               ; Return to line
        JP      NZ,RETLIN       ; No - Return to line
        LD      A,(LSTBIN)      ; Any INPUT in subroutine?
        OR      A               ; If so buffer is corrupted
        JP      NZ,POPNOK       ; Yes - Go to command mode
RETLIN: LD      HL,RUNCNT       ; Execution driver loop
        EX      (SP),HL         ; Into stack - Code string out
        DEFB    3EH             ; Skip "POP HL"
NXTDTA: POP     HL              ; Restore code string address

DATA:   DEFB    01H,3AH         ; ':' End of statement
REM:    LD      C,0             ; 00  End of statement
        LD      B,0
NXTSTL: LD      A,C             ; Statement and byte
        LD      C,B
        LD      B,A             ; Statement end byte
NXTSTT: LD      A,(HL)          ; Get byte
        OR      A               ; End of line?
        RET     Z               ; Yes - Exit
        CP      B               ; End of statement?
        RET     Z               ; Yes - Exit
        INC     HL              ; Next byte
        CP      '"'             ; Literal string?
        JP      Z,NXTSTL        ; Yes - Look for another '"'
        JP      NXTSTT          ; Keep looking

LET:    CALL    GETVAR          ; Get variable name
        CALL    CHKSYN          ; Make sure "=" follows
        DEFB    ZEQUAL          ; "=" token
        PUSH    DE              ; Save address of variable
        LD      A,(TYPE)        ; Get data type
        PUSH    AF              ; Save type
        CALL    EVAL            ; Evaluate expression
        POP     AF              ; Restore type
        EX      (SP),HL         ; Save code - Get var addr
        LD      (BRKLIN),HL     ; Save address of variable
        RRA                     ; Adjust type
        CALL    CHKTYP          ; Check types are the same
        JP      Z,LETNUM        ; Numeric - Move value
LETSTR: PUSH    HL              ; Save address of string var
        LD      HL,(FPREG)      ; Pointer to string entry
        PUSH    HL              ; Save it on stack
        INC     HL              ; Skip over length
        INC     HL
        LD      E,(HL)          ; LSB of string address
        INC     HL
        LD      D,(HL)          ; MSB of string address
        LD      HL,(BASTXT)     ; Point to start of program
        CALL    CPDEHL          ; Is string before program?
        JP      NC,CRESTR       ; Yes - Create string entry
        LD      HL,(STRSPC)     ; Point to string space
        CALL    CPDEHL          ; Is string literal in program?
        POP     DE              ; Restore address of string
        JP      NC,MVSTPT       ; Yes - Set up pointer
        LD      HL,TMPSTR       ; Temporary string pool
        CALL    CPDEHL          ; Is string in temporary pool?
        JP      NC,MVSTPT       ; No - Set up pointer
        DEFB    3EH             ; Skip "POP DE"
CRESTR: POP     DE              ; Restore address of string
        CALL    BAKTMP          ; Back to last tmp-str entry
        EX      DE,HL           ; Address of string entry
        CALL    SAVSTR          ; Save string in string area
MVSTPT: CALL    BAKTMP          ; Back to last tmp-str entry
        POP     HL              ; Get string pointer
        CALL    DETHL4          ; Move string pointer to var
        POP     HL              ; Restore code string address
        RET

LETNUM: PUSH    HL              ; Save address of variable
        CALL    FPTHL           ; Move FPREG to variable
        POP     DE              ; Restore address of variable
        POP     HL              ; Restore code string address
        RET

ON:     CALL    GETINT          ; Get integer 0-255
        LD      A,(HL)          ; Get "GOTO" or "GOSUB" token
        LD      B,A             ; Save in B
        CP      ZGOSUB          ; "GOSUB" token?
        JP      Z,ONGO          ; Yes - Find line number
        CALL    CHKSYN          ; Make sure it's "GOTO"
        DEFB    ZGOTO           ; "GOTO" token
        DEC     HL              ; Cancel increment
ONGO:   LD      C,E             ; Integer of branch value
ONGOLP: DEC     C               ; Count branches
        LD      A,B             ; Get "GOTO" or "GOSUB" token
        JP      Z,ONJMP         ; Go to that line if right one
        CALL    GETLN           ; Get line number to DE
        CP      ','             ; Another line number?
        RET     NZ              ; No - Drop through
        JP      ONGOLP          ; Yes - loop

IF:     CALL    EVAL            ; Evaluate expression
        LD      A,(HL)          ; Get token
        CP      ZGOTO           ; "GOTO" token?
        JP      Z,IFGO          ; Yes - Get line
        CALL    CHKSYN          ; Make sure it's "THEN"
        DEFB    ZTHEN           ; "THEN" token
        DEC     HL              ; Cancel increment
IFGO:   CALL    TSTNUM          ; Make sure it's numeric
        CALL    TSTSGN          ; Test state of expression
        JP      Z,REM           ; False - Drop through
        CALL    GETCHR          ; Get next character
        JP      C,GOTO          ; Number - GOTO that line
        JP      IFJMP           ; Otherwise do statement

MRPRNT: DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    GETCHR          ; Get next character
PRINT:  JP      Z,PRNTCRLF      ; CRLF if just PRINT
PRNTLP: RET     Z               ; End of list - Exit
        CP      ZTAB            ; "TAB(" token?
        JP      Z,DOTAB         ; Yes - Do TAB routine
        CP      ZSPC            ; "SPC(" token?
        JP      Z,DOTAB         ; Yes - Do SPC routine
        PUSH    HL              ; Save code string address
        CP      ','             ; Comma?
        JP      Z,DOCOM         ; Yes - Move to next zone
        CP      59              ; ';' Semi-colon?
        JP      Z,NEXITM        ; Do semi-colon routine
        POP     BC              ; Code string address to BC
        CALL    EVAL            ; Evaluate expression
        PUSH    HL              ; Save code string address
        LD      A,(TYPE)        ; Get variable type
        OR      A               ; Is it a string variable?
        JP      NZ,PRNTST       ; Yes - Output string contents
        CALL    NUMASC          ; Convert number to text
        CALL    CRTST           ; Create temporary string
        LD      (HL),' '        ; Followed by a space
        LD      HL,(FPREG)      ; Get length of output
        INC     (HL)            ; Plus 1 for the space
        LD      HL,(FPREG)      ; < Not needed >
        LD      A,(LWIDTH)      ; Get width of line
        LD      B,A             ; To B
        INC     B               ; Width 255 (No limit)?
        JP      Z,PRNTNB        ; Yes - Output number string
        INC     B               ; Adjust it
        LD      A,(CURPOS)      ; Get cursor position
        ADD     A,(HL)          ; Add length of string
        DEC     A               ; Adjust it
        CP      B               ; Will output fit on this line?
        CALL    NC,PRNTCRLF     ; No - CRLF first
PRNTNB: CALL    PRS1            ; Output string at (HL)
        XOR     A               ; Skip CALL by setting 'z' flag
PRNTST: CALL    NZ,PRS1         ; Output string at (HL)
        POP     HL              ; Restore code string address
        JP      MRPRNT          ; See if more to PRINT

STTLIN: LD      A,(CURPOS)      ; Make sure on new line
        OR      A               ; Already at start?
        RET     Z               ; Yes - Do nothing
        JP      PRNTCRLF        ; Start a new line

ENDINP: LD      (HL),0          ; Mark end of buffer
        LD      HL,BUFFER-1     ; Point to buffer
PRNTCRLF: LD    A,CR            ; Load a CR
        CALL    OUTC            ; Output character
        LD      A,LF            ; Load a LF
        CALL    OUTC            ; Output character
DONULL: XOR     A               ; Set to position 0
        LD      (CURPOS),A      ; Store it
        LD      A,(NULLS)       ; Get number of nulls
NULLP:  DEC     A               ; Count them
        RET     Z               ; Return if done
        PUSH    AF              ; Save count
        XOR     A               ; Load a null
        CALL    OUTC            ; Output it
        POP     AF              ; Restore count
        JP      NULLP           ; Keep counting

DOCOM:  LD      A,(COMMAN)      ; Get comma width
        LD      B,A             ; Save in B
        LD      A,(CURPOS)      ; Get current position
        CP      B               ; Within the limit?
        CALL    NC,PRNTCRLF     ; No - output CRLF
        JP      NC,NEXITM       ; Get next item
ZONELP: SUB     14              ; Next zone of 14 characters
        JP      NC,ZONELP       ; Repeat if more zones
        CPL                     ; Number of spaces to output
        JP      ASPCS           ; Output them

DOTAB:  PUSH    AF              ; Save token
        CALL    FNDNUM          ; Evaluate expression
        CALL    CHKSYN          ; Make sure ")" follows
        DEFB    ")"
        DEC     HL              ; Back space on to ")"
        POP     AF              ; Restore token
        SUB     ZSPC            ; Was it "SPC(" ?
        PUSH    HL              ; Save code string address
        JP      Z,DOSPC         ; Yes - Do 'E' spaces
        LD      A,(CURPOS)      ; Get current position
DOSPC:  CPL                     ; Number of spaces to print to
        ADD     A,E             ; Total number to print
        JP      NC,NEXITM       ; TAB < Current POS(X)
ASPCS:  INC     A               ; Output A spaces
        LD      B,A             ; Save number to print
        LD      A,' '           ; Space
SPCLP:  CALL    OUTC            ; Output character in A
        DEC     B               ; Count them
        JP      NZ,SPCLP        ; Repeat if more
NEXITM: POP     HL              ; Restore code string address
        CALL    GETCHR          ; Get next character
        JP      PRNTLP          ; More to print

REDO:   DEFB    "?Redo from start",CR,LF,0

BADINP: LD      A,(READFG)      ; READ or INPUT?
        OR      A
        JP      NZ,DATSNR       ; READ - ?SN Error
        POP     BC              ; Throw away code string addr
        LD      HL,REDO         ; "Redo from start" message
        CALL    PRS             ; Output string
        JP      DOAGN           ; Do last INPUT again

INPUT:  CALL    IDTEST          ; Test for illegal direct
        LD      A,(HL)          ; Get character after "INPUT"
        CP      '"'             ; Is there a prompt string?
        LD      A,0             ; Clear A and leave flags
        LD      (CTLOFG),A      ; Enable output
        JP      NZ,NOPMPT       ; No prompt - get input
        CALL    QTSTR           ; Get string terminated by '"'
        CALL    CHKSYN          ; Check for ';' after prompt
        DEFB    ';'
        PUSH    HL              ; Save code string address
        CALL    PRS1            ; Output prompt string
        DEFB    3EH             ; Skip "PUSH HL"
NOPMPT: PUSH    HL              ; Save code string address
        CALL    PROMPT          ; Get input with "? " prompt
        POP     BC              ; Restore code string address
        JP      C,INPBRK        ; Break pressed - Exit
        INC     HL              ; Next byte
        LD      A,(HL)          ; Get it
        OR      A               ; End of line?
        DEC     HL              ; Back again
        PUSH    BC              ; Re-save code string address
        JP      Z,NXTDTA        ; Yes - Find next DATA stmt
        LD      (HL),','        ; Store comma as separator
        JP      NXTITM          ; Get next item

READ:   PUSH    HL              ; Save code string address
        LD      HL,(NXTDAT)     ; Next DATA statement
        DEFB    0F6H            ; Flag "READ"
NXTITM: XOR     A               ; Flag "INPUT"
        LD      (READFG),A      ; Save "READ"/"INPUT" flag
        EX      (SP),HL         ; Get code str' , Save pointer
        JP      GTVLUS          ; Get values

NEDMOR: CALL    CHKSYN          ; Check for comma between items
        DEFB    ','
GTVLUS: CALL    GETVAR          ; Get variable name
        EX      (SP),HL         ; Save code str" , Get pointer
        PUSH    DE              ; Save variable address
        LD      A,(HL)          ; Get next "INPUT"/"DATA" byte
        CP      ','             ; Comma?
        JP      Z,ANTVLU        ; Yes - Get another value
        LD      A,(READFG)      ; Is it READ?
        OR      A
        JP      NZ,FDTLP        ; Yes - Find next DATA stmt
        LD      A,'?'           ; More INPUT needed
        CALL    OUTC            ; Output character
        CALL    PROMPT          ; Get INPUT with prompt
        POP     DE              ; Variable address
        POP     BC              ; Code string address
        JP      C,INPBRK        ; Break pressed
        INC     HL              ; Point to next DATA byte
        LD      A,(HL)          ; Get byte
        OR      A               ; Is it zero (No input) ?
        DEC     HL              ; Back space INPUT pointer
        PUSH    BC              ; Save code string address
        JP      Z,NXTDTA        ; Find end of buffer
        PUSH    DE              ; Save variable address
ANTVLU: LD      A,(TYPE)        ; Check data type
        OR      A               ; Is it numeric?
        JP      Z,INPBIN        ; Yes - Convert to binary
        CALL    GETCHR          ; Get next character
        LD      D,A             ; Save input character
        LD      B,A             ; Again
        CP      '"'             ; Start of literal sting?
        JP      Z,STRENT        ; Yes - Create string entry
        LD      A,(READFG)      ; "READ" or "INPUT" ?
        OR      A
        LD      D,A             ; Save 00 if "INPUT"
        JP      Z,ITMSEP        ; "INPUT" - End with 00
        LD      D,':'           ; "DATA" - End with 00 or ':'
ITMSEP: LD      B,','           ; Item separator
        DEC     HL              ; Back space for DTSTR
STRENT: CALL    DTSTR           ; Get string terminated by D
        EX      DE,HL           ; String address to DE
        LD      HL,LTSTND       ; Where to go after LETSTR
        EX      (SP),HL         ; Save HL , get input pointer
        PUSH    DE              ; Save address of string
        JP      LETSTR          ; Assign string to variable

INPBIN: CALL    GETCHR          ; Get next character
        CALL    ASCTFP          ; Convert ASCII to FP number
        EX      (SP),HL         ; Save input ptr, Get var addr
        CALL    FPTHL           ; Move FPREG to variable
        POP     HL              ; Restore input pointer
LTSTND: DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    GETCHR          ; Get next character
        JP      Z,MORDT         ; End of line - More needed?
        CP      ','             ; Another value?
        JP      NZ,BADINP       ; No - Bad input
MORDT:  EX      (SP),HL         ; Get code string address
        DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    GETCHR          ; Get next character
        JP      NZ,NEDMOR       ; More needed - Get it
        POP     DE              ; Restore DATA pointer
        LD      A,(READFG)      ; "READ" or "INPUT" ?
        OR      A
        EX      DE,HL           ; DATA pointer to HL
        JP      NZ,UPDATA       ; Update DATA pointer if "READ"
        PUSH    DE              ; Save code string address
        OR      (HL)            ; More input given?
        LD      HL,EXTIG        ; "?Extra ignored" message
        CALL    NZ,PRS          ; Output string if extra given
        POP     HL              ; Restore code string address
        RET

EXTIG:  DEFB    "?Extra ignored",CR,LF,0

FDTLP:  CALL    DATA            ; Get next statement
        OR      A               ; End of line?
        JP      NZ,FANDT        ; No - See if DATA statement
        INC     HL
        LD      A,(HL)          ; End of program?
        INC     HL
        OR      (HL)            ; 00 00 Ends program
        LD      E,OD            ; ?OD Error
        JP      Z,ERROR         ; Yes - Out of DATA
        INC     HL
        LD      E,(HL)          ; LSB of line number
        INC     HL
        LD      D,(HL)          ; MSB of line number
        LD      (DATLIN),DE     ; Set line of current DATA item
FANDT:  CALL    GETCHR          ; Get next character
        CP      ZDATA           ; "DATA" token
        JP      NZ,FDTLP        ; No "DATA" - Keep looking
        JP      ANTVLU          ; Found - Convert input

NEXT:   LD      DE,0            ; In case no index given
NEXT1:  CALL    NZ,GETVAR       ; Get index address
        LD      (BRKLIN),HL     ; Save code string address
        CALL    BAKSTK          ; Look for "FOR" block
        JP      NZ,NFERR        ; No "FOR" - ?NF Error
        LD      SP,HL           ; Clear nested loops
        PUSH    DE              ; Save index address
        LD      A,(HL)          ; Get sign of STEP
        INC     HL
        PUSH    AF              ; Save sign of STEP
        PUSH    DE              ; Save index address
        CALL    PHLTFP          ; Move index value to FPREG
        EX      (SP),HL         ; Save address of TO value
        PUSH    HL              ; Save address of index
        CALL    ADDPHL          ; Add STEP to index value
        POP     HL              ; Restore address of index
        CALL    FPTHL           ; Move FPREG to index variable
        POP     HL              ; Restore address of TO value
        CALL    LOADFP          ; Move TO value to BCDE
        PUSH    HL              ; Save address of line of FOR
        CALL    CMPNUM          ; Compare index with TO value
        POP     HL              ; Restore address of line num
        POP     BC              ; Address of sign of STEP
        SUB     B               ; Compare with expected sign
        CALL    LOADFP          ; BC = Loop stmt,DE = Line num
        JP      Z,KILFOR        ; Loop finished - Terminate it
        EX      DE,HL           ; Loop statement line number
        LD      (LINEAT),HL     ; Set loop line number
        LD      HL,BC           ; Set code string to loop
        JP      PUTFID          ; Put back "FOR" and continue

KILFOR: LD      SP,HL           ; Remove "FOR" block
        LD      HL,(BRKLIN)     ; Code string after "NEXT"
        LD      A,(HL)          ; Get next byte in code string
        CP      ','             ; More NEXTs ?
        JP      NZ,RUNCNT       ; No - Do next statement
        CALL    GETCHR          ; Position to index name
        CALL    NEXT1           ; Re-enter NEXT routine
; < will not RETurn to here , Exit to RUNCNT or Loop >

GETNUM: CALL    EVAL            ; Get a numeric expression
TSTNUM: DEFB    0F6H            ; Clear carry (numeric)
TSTSTR: SCF                     ; Set carry (string)
CHKTYP: LD      A,(TYPE)        ; Check types match
        ADC     A,A             ; Expected + actual
        OR      A               ; Clear carry , set parity
        RET     PE              ; Even parity - Types match
        JP      TMERR           ; Different types - Error

OPNPAR: CALL    CHKSYN          ; Make sure "(" follows
        DEFB    "("
EVAL:   DEC     HL              ; Evaluate expression & save
        LD      D,0             ; Precedence value
EVAL1:  PUSH    DE              ; Save precedence
        LD      C,1
        CALL    CHKSTK          ; Check for 1 level of stack
        CALL    OPRND           ; Get next expression value
EVAL2:  LD      (NXTOPR),HL     ; Save address of next operator
EVAL3:  LD      HL,(NXTOPR)     ; Restore address of next opr
        POP     BC              ; Precedence value and operator
        LD      A,B             ; Get precedence value
        CP      78H             ; "AND" or "OR" ?
        CALL    NC,TSTNUM       ; No - Make sure it's a number
        LD      A,(HL)          ; Get next operator / function
        LD      D,0             ; Clear Last relation
RLTLP:  SUB     ZGTR            ; ">" Token
        JP      C,FOPRND        ; + - * / ^ AND OR - Test it
        CP      ZLTH+1-ZGTR     ; < = >
        JP      NC,FOPRND       ; Function - Call it
        CP      ZEQUAL-ZGTR     ; "="
        RLA                     ; <- Test for legal
        XOR     D               ; <- combinations of < = >
        CP      D               ; <- by combining last token
        LD      D,A             ; <- with current one
        JP      C,SNERR         ; Error if "<<" "==" or ">>"
        LD      (CUROPR),HL     ; Save address of current token
        CALL    GETCHR          ; Get next character
        JP      RLTLP           ; Treat the two as one

FOPRND: LD      A,D             ; < = > found ?
        OR      A
        JP      NZ,TSTRED       ; Yes - Test for reduction
        LD      A,(HL)          ; Get operator token
        LD      (CUROPR),HL     ; Save operator address
        SUB     ZPLUS           ; Operator or function?
        RET     C               ; Neither - Exit
        CP      ZOR+1-ZPLUS     ; Is it + - * / ^ AND OR ?
        RET     NC              ; No - Exit
        LD      E,A             ; Coded operator
        LD      A,(TYPE)        ; Get data type
        DEC     A               ; FF = numeric , 00 = string
        OR      E               ; Combine with coded operator
        LD      A,E             ; Get coded operator
        JP      Z,CONCAT        ; String concatenation
        RLCA                    ; Times 2
        ADD     A,E             ; Times 3
        LD      E,A             ; To DE (D is 0)
        LD      HL,PRITAB       ; Precedence table
        ADD     HL,DE           ; To the operator concerned
        LD      A,B             ; Last operator precedence
        LD      D,(HL)          ; Get evaluation precedence
        CP      D               ; Compare with eval precedence
        RET     NC              ; Exit if higher precedence
        INC     HL              ; Point to routine address
        CALL    TSTNUM          ; Make sure it's a number

STKTHS: PUSH    BC              ; Save last precedence & token
        LD      BC,EVAL3        ; Where to go on prec' break
        PUSH    BC              ; Save on stack for return
        LD      BC,HL
        LD      HL,(FPREG)      ; LSB,NLSB of FPREG
        PUSH    HL              ; Stack them
        LD      HL,(FPREG+2)    ; MSB and exponent of FPREG
        PUSH    HL              ; Stack them
        LD      HL,BC
        LD      C,(HL)          ; Get LSB of routine address
        INC     HL
        LD      B,(HL)          ; Get MSB of routine address
        INC     HL
        PUSH    BC              ; Save routine address
        LD      HL,(CUROPR)     ; Address of current operator
        JP      EVAL1           ; Loop until prec' break

OPRND:  XOR     A               ; Get operand routine
        LD      (TYPE),A        ; Set numeric expected
        CALL    GETCHR          ; Get next character
        LD      E,MO            ; ?MO Error
        JP      Z,ERROR         ; No operand - Error
        JP      C,ASCTFP        ; Number - Get value
        CALL    CHKLTR          ; See if a letter
        JP      NC,CONVAR       ; Letter - Find variable
        CP      ZPLUS           ; '+' Token ?
        JP      Z,OPRND         ; Yes - Look for operand
        CP      '.'             ; '.' ?
        JP      Z,ASCTFP        ; Yes - Create FP number
        CP      ZMINUS          ; '-' Token ?
        JP      Z,MINUS         ; Yes - Do minus
        CP      '"'             ; Literal string ?
        JP      Z,QTSTR         ; Get string terminated by '"'
        CP      ZNOT            ; "NOT" Token ?
        JP      Z,EVNOT         ; Yes - Eval NOT expression
        CP      ZFN             ; "FN" Token ?
        JP      Z,DOFN          ; Yes - Do FN routine
        CP      ZAMP            ; &H = HEX
        JP      Z,HEXTFP        ; Convert Hex to FPREG
        SUB     ZSGN            ; Is it a function?
        JP      NC,FNOFST       ; Yes - Evaluate function
EVLPAR: CALL    OPNPAR          ; Evaluate expression in "()"
        CALL    CHKSYN          ; Make sure ")" follows
        DEFB    ")"
        RET

MINUS:  LD      D,7DH           ; '-' precedence
        CALL    EVAL1           ; Evaluate until prec' break
        LD      HL,(NXTOPR)     ; Get next operator address
        PUSH    HL              ; Save next operator address
        CALL    INVSGN          ; Negate value
RETNUM: CALL    TSTNUM          ; Make sure it's a number
        POP     HL              ; Restore next operator address
        RET

CONVAR: CALL    GETVAR          ; Get variable address to DE
FRMEVL: PUSH    HL              ; Save code string address
        EX      DE,HL           ; Variable address to HL
        LD      (FPREG),HL      ; Save address of variable
        LD      A,(TYPE)        ; Get type
        OR      A               ; Numeric?
        CALL    Z,PHLTFP        ; Yes - Move contents to FPREG
        POP     HL              ; Restore code string address
        RET

FNOFST: LD      B,0             ; Get address of function
        RLCA                    ; Double function offset
        LD      C,A             ; BC = Offset in function table
        PUSH    BC              ; Save adjusted token value
        CALL    GETCHR          ; Get next character
        LD      A,C             ; Get adjusted token value
        CP      2*(ZLEFT-ZSGN)-1; Adj' LEFT$,RIGHT$ or MID$ ?
        JP      C,FNVAL         ; No - Do function
        CALL    OPNPAR          ; Evaluate expression  (X,...
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        CALL    TSTSTR          ; Make sure it's a string
        EX      DE,HL           ; Save code string address
        LD      HL,(FPREG)      ; Get address of string
        EX      (SP),HL         ; Save address of string
        PUSH    HL              ; Save adjusted token value
        EX      DE,HL           ; Restore code string address
        CALL    GETINT          ; Get integer 0-255
        EX      DE,HL           ; Save code string address
        EX      (SP),HL         ; Save integer,HL = adj' token
        JP      GOFUNC          ; Jump to string function

FNVAL:  CALL    EVLPAR          ; Evaluate expression
        EX      (SP),HL         ; HL = Adjusted token value
        LD      DE,RETNUM       ; Return number from function
        PUSH    DE              ; Save on stack
GOFUNC: LD      BC,FNCTAB       ; Function routine addresses
        ADD     HL,BC           ; Point to right address
        LD      C,(HL)          ; Get LSB of address
        INC     HL              ;
        LD      H,(HL)          ; Get MSB of address
        LD      L,C             ; Address to HL
        JP      (HL)            ; Jump to function

SGNEXP: DEC     D               ; Dee to flag negative exponent
        CP      ZMINUS          ; '-' token ?
        RET     Z               ; Yes - Return
        CP      '-'             ; '-' ASCII ?
        RET     Z               ; Yes - Return
        INC     D               ; Inc to flag positive exponent
        CP      '+'             ; '+' ASCII ?
        RET     Z               ; Yes - Return
        CP      ZPLUS           ; '+' token ?
        RET     Z               ; Yes - Return
        DEC     HL              ; DEC 'cos GETCHR INCs
        RET                     ; Return "NZ"

POR:    DEFB    0F6H            ; Flag "OR"
PAND:   XOR     A               ; Flag "AND"
        PUSH    AF              ; Save "AND" / "OR" flag
        CALL    TSTNUM          ; Make sure it's a number
        CALL    DEINT           ; Get integer -32768 to 32767
        POP     AF              ; Restore "AND" / "OR" flag
        EX      DE,HL           ; <- Get last
        POP     BC              ; <-  value
        EX      (SP),HL         ; <-  from
        EX      DE,HL           ; <-  stack
        CALL    FPBCDE          ; Move last value to FPREG
        PUSH    AF              ; Save "AND" / "OR" flag
        CALL    DEINT           ; Get integer -32768 to 32767
        POP     AF              ; Restore "AND" / "OR" flag
        POP     BC              ; Get value
        LD      A,C             ; Get LSB
        LD      HL,ACPASS       ; Address of save AC as current
        JP      NZ,POR1         ; Jump if OR
        AND     E               ; "AND" LSBs
        LD      C,A             ; Save LSB
        LD      A,B             ; Get MBS
        AND     D               ; "AND" MSBs
        JP      (HL)            ; Save AC as current (ACPASS)

POR1:   OR      E               ; "OR" LSBs
        LD      C,A             ; Save LSB
        LD      A,B             ; Get MSB
        OR      D               ; "OR" MSBs
        JP      (HL)            ; Save AC as current (ACPASS)

TSTRED: LD      HL,CMPLOG       ; Logical compare routine
        LD      A,(TYPE)        ; Get data type
        RRA                     ; Carry set = string
        LD      A,D             ; Get last precedence value
        RLA                     ; Times 2 plus carry
        LD      E,A             ; To E
        LD      D,64H           ; Relational precedence
        LD      A,B             ; Get current precedence
        CP      D               ; Compare with last
        RET     NC              ; Eval if last was rel' or log'
        JP      STKTHS          ; Stack this one and get next

CMPLOG: DEFW    CMPLG1          ; Compare two values / strings
CMPLG1: LD      A,C             ; Get data type
        OR      A
        RRA
        POP     BC              ; Get last expression to BCDE
        POP     DE
        PUSH    AF              ; Save status
        CALL    CHKTYP          ; Check that types match
        LD      HL,CMPRES       ; Result to comparison
        PUSH    HL              ; Save for RETurn
        JP      Z,CMPNUM        ; Compare values if numeric
        XOR     A               ; Compare two strings
        LD      (TYPE),A        ; Set type to numeric
        PUSH    DE              ; Save string name
        CALL    GSTRCU          ; Get current string
        LD      A,(HL)          ; Get length of string
        INC     HL
        INC     HL
        LD      C,(HL)          ; Get LSB of address
        INC     HL
        LD      B,(HL)          ; Get MSB of address
        POP     DE              ; Restore string name
        PUSH    BC              ; Save address of string
        PUSH    AF              ; Save length of string
        CALL    GSTRDE          ; Get second string
        CALL    LOADFP          ; Get address of second string
        POP     AF              ; Restore length of string 1
        LD      D,A             ; Length to D
        POP     HL              ; Restore address of string 1
CMPSTR: LD      A,E             ; Bytes of string 2 to do
        OR      D               ; Bytes of string 1 to do
        RET     Z               ; Exit if all bytes compared
        LD      A,D             ; Get bytes of string 1 to do
        SUB     1
        RET     C               ; Exit if end of string 1
        XOR     A
        CP      E               ; Bytes of string 2 to do
        INC     A
        RET     NC              ; Exit if end of string 2
        DEC     D               ; Count bytes in string 1
        DEC     E               ; Count bytes in string 2
        LD      A,(BC)          ; Byte in string 2
        CP      (HL)            ; Compare to byte in string 1
        INC     HL              ; Move up string 1
        INC     BC              ; Move up string 2
        JP      Z,CMPSTR        ; Same - Try next bytes
        CCF                     ; Flag difference (">" or "<")
        JP      FLGDIF          ; "<" gives -1 , ">" gives +1

CMPRES: INC     A               ; Increment current value
        ADC     A,A             ; Double plus carry
        POP     BC              ; Get other value
        AND     B               ; Combine them
        ADD     A,-1            ; Carry set if different
        SBC     A,A             ; 00 - Equal , FF - Different
        JP      FLGREL          ; Set current value & continue

EVNOT:  LD      D,5AH           ; Precedence value for "NOT"
        CALL    EVAL1           ; Eval until precedence break
        CALL    TSTNUM          ; Make sure it's a number
        CALL    DEINT           ; Get integer -32768 - 32767
        LD      A,E             ; Get LSB
        CPL                     ; Invert LSB
        LD      C,A             ; Save "NOT" of LSB
        LD      A,D             ; Get MSB
        CPL                     ; Invert MSB
        CALL    ACPASS          ; Save AC as current
        POP     BC              ; Clean up stack
        JP      EVAL3           ; Continue evaluation

DIMRET: DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    GETCHR          ; Get next character
        RET     Z               ; End of DIM statement
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
DIM:    LD      BC,DIMRET       ; Return to "DIMRET"
        PUSH    BC              ; Save on stack
        DEFB    0F6H            ; Flag "Create" variable
GETVAR: XOR     A               ; Find variable address,to DE
        LD      (LCRFLG),A      ; Set locate / create flag
        LD      B,(HL)          ; Get First byte of name
GTFNAM: CALL    CHKLTR          ; See if a letter
        JP      C,SNERR         ; ?SN Error if not a letter
        XOR     A
        LD      C,A             ; Clear second byte of name
        LD      (TYPE),A        ; Set type to numeric
        CALL    GETCHR          ; Get next character
        JP      C,SVNAM2        ; Numeric - Save in name
        CALL    CHKLTR          ; See if a letter
        JP      C,CHARTY        ; Not a letter - Check type
SVNAM2: LD      C,A             ; Save second byte of name
ENDNAM: CALL    GETCHR          ; Get next character
        JP      C,ENDNAM        ; Numeric - Get another
        CALL    CHKLTR          ; See if a letter
        JP      NC,ENDNAM       ; Letter - Get another
CHARTY: SUB     '$'             ; String variable?
        JP      NZ,NOTSTR       ; No - Numeric variable
        INC     A               ; A = 1 (string type)
        LD      (TYPE),A        ; Set type to string
        RRCA                    ; A = 80H , Flag for string
        ADD     A,C             ; 2nd byte of name has bit 7 on
        LD      C,A             ; Resave second byte on name
        CALL    GETCHR          ; Get next character
NOTSTR: LD      A,(FORFLG)      ; Array name needed ?
        DEC     A
        JP      Z,ARLDSV        ; Yes - Get array name
        JP      P,NSCFOR        ; No array with "FOR" or "FN"
        LD      A,(HL)          ; Get byte again
        SUB     '('             ; Subscripted variable?
        JP      Z,SBSCPT        ; Yes - Sort out subscript

NSCFOR: XOR     A               ; Simple variable
        LD      (FORFLG),A      ; Clear "FOR" flag
        PUSH    HL              ; Save code string address
        LD      DE,BC           ; DE = Variable name to find
        LD      HL,(FNRGNM)     ; FN argument name
        CALL    CPDEHL          ; Is it the FN argument?
        LD      DE,FNARG        ; Point to argument value
        JP      Z,POPHRT        ; Yes - Return FN argument value
        LD      HL,(VAREND)     ; End of variables
        EX      DE,HL           ; Address of end of search
        LD      HL,(PROGND)     ; Start of variables address
FNDVAR: CALL    CPDEHL          ; End of variable list table?
        JP      Z,CFEVAL        ; Yes - Called from EVAL?
        LD      A,C             ; Get second byte of name
        SUB     (HL)            ; Compare with name in list
        INC     HL              ; Move on to first byte
        JP      NZ,FNTHR        ; Different - Find another
        LD      A,B             ; Get first byte of name
        SUB     (HL)            ; Compare with name in list
FNTHR:  INC     HL              ; Move on to LSB of value
        JP      Z,RETADR        ; Found - Return address
        INC     HL              ; <- Skip
        INC     HL              ; <- over
        INC     HL              ; <- F.P.
        INC     HL              ; <- value
        JP      FNDVAR          ; Keep looking

CFEVAL: POP     HL              ; Restore code string address
        EX      (SP),HL         ; Get return address
        PUSH    DE              ; Save address of variable
        LD      DE,FRMEVL       ; Return address in EVAL
        CALL    CPDEHL          ; Called from EVAL ?
        POP     DE              ; Restore address of variable
        JP      Z,RETNUL        ; Yes - Return null variable
        EX      (SP),HL         ; Put back return
        PUSH    HL              ; Save code string address
        PUSH    BC              ; Save variable name
        LD      BC,6            ; 2 byte name plus 4 byte data
        LD      HL,(ARREND)     ; End of arrays
        PUSH    HL              ; Save end of arrays
        ADD     HL,BC           ; Move up 6 bytes
        POP     BC              ; Source address in BC
        PUSH    HL              ; Save new end address
        CALL    MOVUP           ; Move arrays up
        POP     HL              ; Restore new end address
        LD      (ARREND),HL     ; Set new end address
        LD      HL,BC           ; End of variables to HL
        LD      (VAREND),HL     ; Set new end address

ZEROLP: DEC     HL              ; Back through to zero variable
        LD      (HL),0          ; Zero byte in variable
        CALL    CPDEHL          ; Done them all?
        JP      NZ,ZEROLP       ; No - Keep on going
        POP     DE              ; Get variable name
        LD      (HL),E          ; Store second character
        INC     HL
        LD      (HL),D          ; Store first character
        INC     HL
RETADR: EX      DE,HL           ; Address of variable in DE
        POP     HL              ; Restore code string address
        RET

RETNUL: LD      (FPEXP),A       ; Set result to zero
        LD      HL,ZERBYT       ; Also set a null string
        LD      (FPREG),HL      ; Save for EVAL
        POP     HL              ; Restore code string address
        RET

SBSCPT: PUSH    HL              ; Save code string address
        LD      HL,(LCRFLG)     ; Locate/Create and Type
        EX      (SP),HL         ; Save and get code string
        LD      D,A             ; Zero number of dimensions
SCPTLP: PUSH    DE              ; Save number of dimensions
        PUSH    BC              ; Save array name
        CALL    FPSINT          ; Get subscript (0-32767)
        POP     BC              ; Restore array name
        POP     AF              ; Get number of dimensions
        EX      DE,HL
        EX      (SP),HL         ; Save subscript value
        PUSH    HL              ; Save LCRFLG and TYPE
        EX      DE,HL
        INC     A               ; Count dimensions
        LD      D,A             ; Save in D
        LD      A,(HL)          ; Get next byte in code string
        CP      ','             ; Comma (more to come)?
        JP      Z,SCPTLP        ; Yes - More subscripts
        CALL    CHKSYN          ; Make sure ")" follows
        DEFB    ")"
        LD      (NXTOPR),HL     ; Save code string address
        POP     HL              ; Get LCRFLG and TYPE
        LD      (LCRFLG),HL     ; Restore Locate/create & type
        LD      E,0             ; Flag not CSAVE* or CLOAD*
        PUSH    DE              ; Save number of dimensions (D)
        DEFB    11H             ; Skip "PUSH HL" and "PUSH AF'

ARLDSV: PUSH    HL              ; Save code string address
        PUSH    AF              ; A = 00 , Flags set = Z,N
        LD      HL,(VAREND)     ; Start of arrays
        DEFB    3EH             ; Skip "ADD HL,DE"
FNDARY: ADD     HL,DE           ; Move to next array start
        LD      DE,(ARREND)     ; End of arrays
        CALL    CPDEHL          ; End of arrays found?
        JP      Z,CREARY        ; Yes - Create array
        LD      A,(HL)          ; Get second byte of name
        CP      C               ; Compare with name given
        INC     HL              ; Move on
        JP      NZ,NXTARY       ; Different - Find next array
        LD      A,(HL)          ; Get first byte of name
        CP      B               ; Compare with name given
NXTARY: INC     HL              ; Move on
        LD      E,(HL)          ; Get LSB of next array address
        INC     HL
        LD      D,(HL)          ; Get MSB of next array address
        INC     HL
        JP      NZ,FNDARY       ; Not found - Keep looking
        LD      A,(LCRFLG)      ; Found Locate or Create it?
        OR      A
        JP      NZ,DDERR        ; Create - ?DD Error
        POP     AF              ; Locate - Get number of dim'ns
        LD      BC,HL           ; BC Points to array dim'ns
        JP      Z,POPHRT        ; Jump if array load/save
        SUB     (HL)            ; Same number of dimensions?
        JP      Z,FINDEL        ; Yes - Find element
BSERR:  LD      E,BS            ; ?BS Error
        JP      ERROR           ; Output error

CREARY: LD      DE,4            ; 4 Bytes per entry
        POP     AF              ; Array to save or 0 dim'ns?
        JP      Z,FCERR         ; Yes - ?FC Error
        LD      (HL),C          ; Save second byte of name
        INC     HL
        LD      (HL),B          ; Save first byte of name
        INC     HL
        LD      C,A             ; Number of dimensions to C
        CALL    CHKSTK          ; Check if enough memory
        INC     HL              ; Point to number of dimensions
        INC     HL
        LD      (CUROPR),HL     ; Save address of pointer
        LD      (HL),C          ; Set number of dimensions
        INC     HL
        LD      A,(LCRFLG)      ; Locate of Create?
        RLA                     ; Carry set = Create
        LD      A,C             ; Get number of dimensions
CRARLP: LD      BC,10+1         ; Default dimension size 10
        JP      NC,DEFSIZ       ; Locate - Set default size
        POP     BC              ; Get specified dimension size
        INC     BC              ; Include zero element
DEFSIZ: LD      (HL),C          ; Save LSB of dimension size
        INC     HL
        LD      (HL),B          ; Save MSB of dimension size
        INC     HL
        PUSH    AF              ; Save num' of dim'ns an status
        PUSH    HL              ; Save address of dim'n size
        CALL    MLDEBC          ; Multiply DE by BC to HL
        EX      DE,HL           ; amount of mem needed (to DE)
        POP     HL              ; Restore address of dimension
        POP     AF              ; Restore number of dimensions
        DEC     A               ; Count them
        JP      NZ,CRARLP       ; Do next dimension if more
        PUSH    AF              ; Save locate/create flag
        LD      B,D             ; MSB of memory needed
        LD      C,E             ; LSB of memory needed
        EX      DE,HL
        ADD     HL,DE           ; Add bytes to array start
        JP      C,OMERR         ; Too big - Error
        CALL    ENFMEM          ; See if enough memory
        LD      (ARREND),HL     ; Save new end of array

ZERARY: DEC     HL              ; Back through array data
        LD      (HL),0          ; Set array element to zero
        CALL    CPDEHL          ; All elements zeroed?
        JP      NZ,ZERARY       ; No - Keep on going
        INC     BC              ; Number of bytes + 1
        LD      D,A             ; A=0
        LD      HL,(CUROPR)     ; Get address of array
        LD      E,(HL)          ; Number of dimensions
        EX      DE,HL           ; To HL
        ADD     HL,HL           ; Two bytes per dimension size
        ADD     HL,BC           ; Add number of bytes
        EX      DE,HL           ; Bytes needed to DE
        DEC     HL
        DEC     HL
        LD      (HL),E          ; Save LSB of bytes needed
        INC     HL
        LD      (HL),D          ; Save MSB of bytes needed
        INC     HL
        POP     AF              ; Locate / Create?
        JP      C,ENDDIM        ; A is 0 , End if create
FINDEL: LD      B,A             ; Find array element
        LD      C,A
        LD      A,(HL)          ; Number of dimensions
        INC     HL
        DEFB    16H             ; Skip "POP HL"
FNDELP: POP     HL              ; Address of next dim' size
        LD      E,(HL)          ; Get LSB of dim'n size
        INC     HL
        LD      D,(HL)          ; Get MSB of dim'n size
        INC     HL
        EX      (SP),HL         ; Save address - Get index
        PUSH    AF              ; Save number of dim'ns
        CALL    CPDEHL          ; Dimension too large?
        JP      NC,BSERR        ; Yes - ?BS Error
        PUSH    HL              ; Save index
        CALL    MLDEBC          ; Multiply previous by size
        POP     DE              ; Index supplied to DE
        ADD     HL,DE           ; Add index to pointer
        POP     AF              ; Number of dimensions
        DEC     A               ; Count them
        LD      BC,HL           ; MSB, LSB of pointer
        JP      NZ,FNDELP       ; More - Keep going
        ADD     HL,HL           ; 4 Bytes per element
        ADD     HL,HL
        POP     BC              ; Start of array
        ADD     HL,BC           ; Point to element
        EX      DE,HL           ; Address of element to DE
ENDDIM: LD      HL,(NXTOPR)     ; Got code string address
        RET

FRE:    LD      HL,(ARREND)     ; Start of free memory
        EX      DE,HL           ; To DE
        LD      HL,0            ; End of free memory
        ADD     HL,SP           ; Current stack value
        LD      A,(TYPE)        ; Dummy argument type
        OR      A
        JP      Z,FRENUM        ; Numeric - Free variable space
        CALL    GSTRCU          ; Current string to pool
        CALL    GARBGE          ; Garbage collection
        LD      HL,(STRSPC)     ; Bottom of string space in use
        EX      DE,HL           ; To DE
        LD      HL,(STRBOT)     ; Bottom of string space
FRENUM: LD      A,L             ; Get LSB of end
        SUB     E               ; Subtract LSB of beginning
        LD      C,A             ; Save difference in C
        LD      A,H             ; Get MSB of end
        SBC     A,D             ; Subtract MSB of beginning
ACPASS: LD      B,C             ; Return integer AC
ABPASS: LD      D,B             ; Return integer AB
        LD      E,0
        LD      HL,TYPE         ; Point to type
        LD      (HL),E          ; Set type to numeric
        LD      B,80H+16        ; 16 bit integer
        JP      RETINT          ; Return the integr

POS:    LD      A,(CURPOS)      ; Get cursor position
PASSA:  LD      B,A             ; Put A into AB
        XOR     A               ; Zero A
        JP      ABPASS          ; Return integer AB

DEF:    CALL    CHEKFN          ; Get "FN" and name
        CALL    IDTEST          ; Test for illegal direct
        LD      BC,DATA         ; To get next statement
        PUSH    BC              ; Save address for RETurn
        PUSH    DE              ; Save address of function ptr
        CALL    CHKSYN          ; Make sure "(" follows
        DEFB    "("
        CALL    GETVAR          ; Get argument variable name
        PUSH    HL              ; Save code string address
        EX      DE,HL           ; Argument address to HL
        DEC     HL
        LD      D,(HL)          ; Get first byte of arg name
        DEC     HL
        LD      E,(HL)          ; Get second byte of arg name
        POP     HL              ; Restore code string address
        CALL    TSTNUM          ; Make sure numeric argument
        CALL    CHKSYN          ; Make sure ")" follows
        DEFB    ")"
        CALL    CHKSYN          ; Make sure "=" follows
        DEFB    ZEQUAL          ; "=" token
        LD      BC,HL           ; Code string address to BC
        EX      (SP),HL         ; Save code str , Get FN ptr
        LD      (HL),C          ; Save LSB of FN code string
        INC     HL
        LD      (HL),B          ; Save MSB of FN code string
        JP      SVSTAD          ; Save address and do function

DOFN:   CALL    CHEKFN          ; Make sure FN follows
        PUSH    DE              ; Save function pointer address
        CALL    EVLPAR          ; Evaluate expression in "()"
        CALL    TSTNUM          ; Make sure numeric result
        EX      (SP),HL         ; Save code str , Get FN ptr
        LD      E,(HL)          ; Get LSB of FN code string
        INC     HL
        LD      D,(HL)          ; Get MSB of FN code string
        INC     HL
        LD      A,D             ; And function DEFined?
        OR      E
        JP      Z,UFERR         ; No - ?UF Error
        LD      A,(HL)          ; Get LSB of argument address
        INC     HL
        LD      H,(HL)          ; Get MSB of argument address
        LD      L,A             ; HL = Arg variable address
        PUSH    HL              ; Save it
        LD      HL,(FNRGNM)     ; Get old argument name
        EX      (SP),HL         ; Save old , Get new
        LD      (FNRGNM),HL     ; Set new argument name
        LD      HL,(FNARG+2)    ; Get LSB,NLSB of old arg value
        PUSH    HL              ; Save it
        LD      HL,(FNARG)      ; Get MSB,EXP of old arg value
        PUSH    HL              ; Save it
        LD      HL,FNARG        ; HL = Value of argument
        PUSH    DE              ; Save FN code string address
        CALL    FPTHL           ; Move FPREG to argument
        POP     HL              ; Get FN code string address
        CALL    GETNUM          ; Get value from function
        DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    GETCHR          ; Get next character
        JP      NZ,SNERR        ; Bad character in FN - Error
        POP     HL              ; Get MSB,EXP of old arg
        LD      (FNARG),HL      ; Restore it
        POP     HL              ; Get LSB,NLSB of old arg
        LD      (FNARG+2),HL    ; Restore it
        POP     HL              ; Get name of old arg
        LD      (FNRGNM),HL     ; Restore it
        POP     HL              ; Restore code string address
        RET

IDTEST: PUSH    HL              ; Save code string address
        LD      HL,(LINEAT)     ; Get current line number
        INC     HL              ; -1 means direct statement
        LD      A,H
        OR      L
        POP     HL              ; Restore code string address
        RET     NZ              ; Return if in program
        LD      E,ID            ; ?ID Error
        JP      ERROR

CHEKFN: CALL    CHKSYN          ; Make sure FN follows
        DEFB    ZFN             ; "FN" token
        LD      A,80H
        LD      (FORFLG),A      ; Flag FN name to find
        OR      (HL)            ; FN name has bit 7 set
        LD      B,A             ; in first byte of name
        CALL    GTFNAM          ; Get FN name
        JP      TSTNUM          ; Make sure numeric function

STR:    CALL    TSTNUM          ; Make sure it's a number
        CALL    NUMASC          ; Turn number into text
STR1:   CALL    CRTST           ; Create string entry for it
        CALL    GSTRCU          ; Current string to pool
        LD      BC,TOPOOL       ; Save in string pool
        PUSH    BC              ; Save address on stack

SAVSTR: LD      A,(HL)          ; Get string length
        INC     HL
        INC     HL
        PUSH    HL              ; Save pointer to string
        CALL    TESTR           ; See if enough string space
        POP     HL              ; Restore pointer to string
        LD      C,(HL)          ; Get LSB of address
        INC     HL
        LD      B,(HL)          ; Get MSB of address
        CALL    CRTMST          ; Create string entry
        PUSH    HL              ; Save pointer to MSB of addr
        LD      L,A             ; Length of string
        CALL    TOSTRA          ; Move to string area
        POP     DE              ; Restore pointer to MSB
        RET

MKTMST: CALL    TESTR           ; See if enough string space
CRTMST: LD      HL,TMPSTR       ; Temporary string
        PUSH    HL              ; Save it
        LD      (HL),A          ; Save length of string
        INC     HL
SVSTAD: INC     HL
        LD      (HL),E          ; Save LSB of address
        INC     HL
        LD      (HL),D          ; Save MSB of address
        POP     HL              ; Restore pointer
        RET

CRTST:  DEC     HL              ; DEC - INCed after
QTSTR:  LD      B,'"'           ; Terminating quote
        LD      D,B             ; Quote to D
DTSTR:  PUSH    HL              ; Save start
        LD      C,-1            ; Set counter to -1
QTSTLP: INC     HL              ; Move on
        LD      A,(HL)          ; Get byte
        INC     C               ; Count bytes
        OR      A               ; End of line?
        JP      Z,CRTSTE        ; Yes - Create string entry
        CP      D               ; Terminator D found?
        JP      Z,CRTSTE        ; Yes - Create string entry
        CP      B               ; Terminator B found?
        JP      NZ,QTSTLP       ; No - Keep looking
CRTSTE: CP      '"'             ; End with '"'?
        CALL    Z,GETCHR        ; Yes - Get next character
        EX      (SP),HL         ; Starting quote
        INC     HL              ; First byte of string
        EX      DE,HL           ; To DE
        LD      A,C             ; Get length
        CALL    CRTMST          ; Create string entry
TSTOPL: LD      DE,TMPSTR       ; Temporary string
        LD      HL,(TMSTPT)     ; Temporary string pool pointer
        LD      (FPREG),HL      ; Save address of string ptr
        LD      A,1
        LD      (TYPE),A        ; Set type to string
        CALL    DETHL4          ; Move string to pool
        CALL    CPDEHL          ; Out of string pool?
        LD      (TMSTPT),HL     ; Save new pointer
        POP     HL              ; Restore code string address
        LD      A,(HL)          ; Get next code byte
        RET     NZ              ; Return if pool OK
        LD      E,ST            ; ?ST Error
        JP      ERROR           ; String pool overflow

PRNUMS: INC     HL              ; Skip leading space
PRS:    CALL    CRTST           ; Create string entry for it
PRS1:   CALL    GSTRCU          ; Current string to pool
        CALL    LOADFP          ; Move string block to BCDE
        INC     E               ; Length + 1
PRSLP:  DEC     E               ; Count characters
        RET     Z               ; End of string
        LD      A,(BC)          ; Get byte to output
        CALL    OUTC            ; Output character in A
        CP      CR              ; Return?
        CALL    Z,DONULL        ; Yes - Do nulls
        INC     BC              ; Next byte in string
        JP      PRSLP           ; More characters to output

TESTR:  OR      A               ; Test if enough room
        DEFB    0EH             ; No garbage collection done
GRBDON: POP     AF              ; Garbage collection done
        PUSH    AF              ; Save status
        LD      HL,(STRSPC)     ; Bottom of string space in use
        EX      DE,HL           ; To DE
        LD      HL,(STRBOT)     ; Bottom of string area
        CPL                     ; Negate length (Top down)
        LD      C,A             ; -Length to BC
        LD      B,-1            ; BC = -ve length of string
        ADD     HL,BC           ; Add to bottom of space in use
        INC     HL              ; Plus one for 2's complement
        CALL    CPDEHL          ; Below string RAM area?
        JP      C,TESTOS        ; Tidy up if not done else err
        LD      (STRBOT),HL     ; Save new bottom of area
        INC     HL              ; Point to first byte of string
        EX      DE,HL           ; Address to DE
POPAF:  POP     AF              ; Throw away status push
        RET

TESTOS: POP     AF              ; Garbage collect been done?
        LD      E,OS            ; ?OS Error
        JP      Z,ERROR         ; Yes - Not enough string apace
        CP      A               ; Flag garbage collect done
        PUSH    AF              ; Save status
        LD      BC,GRBDON       ; Garbage collection done
        PUSH    BC              ; Save for RETurn
GARBGE: LD      HL,(LSTRAM)     ; Get end of RAM pointer
GARBLP: LD      (STRBOT),HL     ; Reset string pointer
        LD      HL,0
        PUSH    HL              ; Flag no string found
        LD      HL,(STRSPC)     ; Get bottom of string space
        PUSH    HL              ; Save bottom of string space
        LD      HL,TMSTPL       ; Temporary string pool
GRBLP:  LD      DE,(TMSTPT)     ; Temporary string pool pointer
        CALL    CPDEHL          ; Temporary string pool done?
        LD      BC,GRBLP        ; Loop until string pool done
        JP      NZ,STPOOL       ; No - See if in string area
        LD      HL,(PROGND)     ; Start of simple variables
SMPVAR: LD      DE,(VAREND)     ; End of simple variables
        CALL    CPDEHL          ; All simple strings done?
        JP      Z,ARRLP         ; Yes - Do string arrays
        LD      A,(HL)          ; Get type of variable
        INC     HL
        INC     HL
        OR      A               ; "S" flag set if string
        CALL    STRADD          ; See if string in string area
        JP      SMPVAR          ; Loop until simple ones done

GNXARY: POP     BC              ; Scrap address of this array
ARRLP:  LD      DE,(ARREND)     ; End of string arrays
        CALL    CPDEHL          ; All string arrays done?
        JP      Z,SCNEND        ; Yes - Move string if found
        CALL    LOADFP          ; Get array name to BCDE
        LD      A,E             ; Get type of array
        PUSH    HL              ; Save address of num of dim'ns
        ADD     HL,BC           ; Start of next array
        OR      A               ; Test type of array
        JP      P,GNXARY        ; Numeric array - Ignore it
        LD      (CUROPR),HL     ; Save address of next array
        POP     HL              ; Get address of num of dim'ns
        LD      C,(HL)          ; BC = Number of dimensions
        LD      B,0
        ADD     HL,BC           ; Two bytes per dimension size
        ADD     HL,BC
        INC     HL              ; Plus one for number of dim'ns
GRBARY: LD      DE,(CUROPR)     ; Get address of next array
        CALL    CPDEHL          ; Is this array finished?
        JP      Z,ARRLP         ; Yes - Get next one
        LD      BC,GRBARY       ; Loop until array all done
STPOOL: PUSH    BC              ; Save return address
        OR      80H             ; Flag string type
STRADD: LD      A,(HL)          ; Get string length
        INC     HL
        INC     HL
        LD      E,(HL)          ; Get LSB of string address
        INC     HL
        LD      D,(HL)          ; Get MSB of string address
        INC     HL
        RET     P               ; Not a string - Return
        OR      A               ; Set flags on string length
        RET     Z               ; Null string - Return
        LD      BC,HL           ; Save variable pointer
        LD      HL,(STRBOT)     ; Bottom of new area
        CALL    CPDEHL          ; String been done?
        LD      HL,BC           ; Restore variable pointer
        RET     C               ; String done - Ignore
        POP     HL              ; Return address
        EX      (SP),HL         ; Lowest available string area
        CALL    CPDEHL          ; String within string area?
        EX      (SP),HL         ; Lowest available string area
        PUSH    HL              ; Re-save return address
        LD      HL,BC           ; Restore variable pointer
        RET     NC              ; Outside string area - Ignore
        POP     BC              ; Get return , Throw 2 away
        POP     AF              ;
        POP     AF              ;
        PUSH    HL              ; Save variable pointer
        PUSH    DE              ; Save address of current
        PUSH    BC              ; Put back return address
        RET                     ; Go to it

SCNEND: POP     DE              ; Addresses of strings
        POP     HL              ;
        LD      A,L             ; HL = 0 if no more to do
        OR      H
        RET     Z               ; No more to do - Return
        DEC     HL
        LD      B,(HL)          ; MSB of address of string
        DEC     HL
        LD      C,(HL)          ; LSB of address of string
        PUSH    HL              ; Save variable address
        DEC     HL
        DEC     HL
        LD      L,(HL)          ; HL = Length of string
        LD      H,0
        ADD     HL,BC           ; Address of end of string+1
        LD      D,B             ; String address to DE
        LD      E,C
        DEC     HL              ; Last byte in string
        LD      BC,HL           ; Address to BC
        LD      HL,(STRBOT)     ; Current bottom of string area
        CALL    MOVSTR          ; Move string to new address
        POP     HL              ; Restore variable address
        LD      (HL),C          ; Save new LSB of address
        INC     HL
        LD      (HL),B          ; Save new MSB of address
        LD      HL,BC           ; Next string area+1 to HL
        DEC     HL              ; Next string area address
        JP      GARBLP          ; Look for more strings

CONCAT: PUSH    BC              ; Save prec' opr & code string
        PUSH    HL              ;
        LD      HL,(FPREG)      ; Get first string
        EX      (SP),HL         ; Save first string
        CALL    OPRND           ; Get second string
        EX      (SP),HL         ; Restore first string
        CALL    TSTSTR          ; Make sure it's a string
        LD      A,(HL)          ; Get length of second string
        PUSH    HL              ; Save first string
        LD      HL,(FPREG)      ; Get second string
        PUSH    HL              ; Save second string
        ADD     A,(HL)          ; Add length of second string
        LD      E,LS            ; ?LS Error
        JP      C,ERROR         ; String too long - Error
        CALL    MKTMST          ; Make temporary string
        POP     DE              ; Get second string to DE
        CALL    GSTRDE          ; Move to string pool if needed
        EX      (SP),HL         ; Get first string
        CALL    GSTRHL          ; Move to string pool if needed
        PUSH    HL              ; Save first string
        LD      HL,(TMPSTR+2)   ; Temporary string address
        EX      DE,HL           ; To DE
        CALL    SSTSA           ; First string to string area
        CALL    SSTSA           ; Second string to string area
        LD      HL,EVAL2        ; Return to evaluation loop
        EX      (SP),HL         ; Save return,get code string
        PUSH    HL              ; Save code string address
        JP      TSTOPL          ; To temporary string to pool

SSTSA:  POP     HL              ; Return address
        EX      (SP),HL         ; Get string block,save return
        LD      A,(HL)          ; Get length of string
        INC     HL
        INC     HL
        LD      C,(HL)          ; Get LSB of string address
        INC     HL
        LD      B,(HL)          ; Get MSB of string address
        LD      L,A             ; Length to L
TOSTRA: INC     L               ; INC - DECed after
TSALP:  DEC     L               ; Count bytes moved
        RET     Z               ; End of string - Return
        LD      A,(BC)          ; Get source
        LD      (DE),A          ; Save destination
        INC     BC              ; Next source
        INC     DE              ; Next destination
        JP      TSALP           ; Loop until string moved

GETSTR: CALL    TSTSTR          ; Make sure it's a string
GSTRCU: LD      HL,(FPREG)      ; Get current string
GSTRHL: EX      DE,HL           ; Save DE
GSTRDE: CALL    BAKTMP          ; Was it last tmp-str?
        EX      DE,HL           ; Restore DE
        RET     NZ              ; No - Return
        PUSH    DE              ; Save string
        LD      D,B             ; String block address to DE
        LD      E,C
        DEC     DE              ; Point to length
        LD      C,(HL)          ; Get string length
        LD      HL,(STRBOT)     ; Current bottom of string area
        CALL    CPDEHL          ; Last one in string area?
        JP      NZ,POPHL        ; No - Return
        LD      B,A             ; Clear B (A=0)
        ADD     HL,BC           ; Remove string from str' area
        LD      (STRBOT),HL     ; Save new bottom of str' area
POPHRT:                         ; Restore address of number
POPHL:  POP     HL              ; Restore string
        RET

BAKTMP: LD      HL,(TMSTPT)     ; Get temporary string pool top
        DEC     HL              ; Back
        LD      B,(HL)          ; Get MSB of address
        DEC     HL              ; Back
        LD      C,(HL)          ; Get LSB of address
        DEC     HL              ; Back
        DEC     HL              ; Back
        CALL    CPDEHL          ; String last in string pool?
        RET     NZ              ; Yes - Leave it
        LD      (TMSTPT),HL     ; Save new string pool top
        RET

LEN:    LD      BC,PASSA        ; To return integer A
        PUSH    BC              ; Save address
GETLEN: CALL    GETSTR          ; Get string and its length
        XOR     A
        LD      D,A             ; Clear D
        LD      (TYPE),A        ; Set type to numeric
        LD      A,(HL)          ; Get length of string
        OR      A               ; Set status flags
        RET

ASC:    LD      BC,PASSA        ; To return integer A
        PUSH    BC              ; Save address
GTFLNM: CALL    GETLEN          ; Get length of string
        JP      Z,FCERR         ; Null string - Error
        INC     HL
        INC     HL
        LD      E,(HL)          ; Get LSB of address
        INC     HL
        LD      D,(HL)          ; Get MSB of address
        LD      A,(DE)          ; Get first byte of string
        RET

CHR:    LD      A,1             ; One character string
        CALL    MKTMST          ; Make a temporary string
        CALL    MAKINT          ; Make it integer A
        LD      HL,(TMPSTR+2)   ; Get address of string
        LD      (HL),E          ; Save character
TOPOOL: POP     BC              ; Clean up stack
        JP      TSTOPL          ; Temporary string to pool

LEFT:   CALL    LFRGNM          ; Get number and ending ")"
        XOR     A               ; Start at first byte in string
RIGHT1: EX      (SP),HL         ; Save code string,Get string
        LD      C,A             ; Starting position in string
MID1:   PUSH    HL              ; Save string block address
        LD      A,(HL)          ; Get length of string
        CP      B               ; Compare with number given
        JP      C,ALLFOL        ; All following bytes required
        LD      A,B             ; Get new length
        DEFB    11H             ; Skip "LD C,0"
ALLFOL: LD      C,0             ; First byte of string
        PUSH    BC              ; Save position in string
        CALL    TESTR           ; See if enough string space
        POP     BC              ; Get position in string
        POP     HL              ; Restore string block address
        PUSH    HL              ; And re-save it
        INC     HL
        INC     HL
        LD      B,(HL)          ; Get LSB of address
        INC     HL
        LD      H,(HL)          ; Get MSB of address
        LD      L,B             ; HL = address of string
        LD      B,0             ; BC = starting address
        ADD     HL,BC           ; Point to that byte
        LD      BC,HL           ; BC = source string
        CALL    CRTMST          ; Create a string entry
        LD      L,A             ; Length of new string
        CALL    TOSTRA          ; Move string to string area
        POP     DE              ; Clear stack
        CALL    GSTRDE          ; Move to string pool if needed
        JP      TSTOPL          ; Temporary string to pool

RIGHT:  CALL    LFRGNM          ; Get number and ending ")"
        POP     DE              ; Get string length
        PUSH    DE              ; And re-save
        LD      A,(DE)          ; Get length
        SUB     B               ; Move back N bytes
        JP      RIGHT1          ; Go and get sub-string

MID:    EX      DE,HL           ; Get code string address
        LD      A,(HL)          ; Get next byte ',' or ")"
        CALL    MIDNUM          ; Get number supplied
        INC     B               ; Is it character zero?
        DEC     B
        JP      Z,FCERR         ; Yes - Error
        PUSH    BC              ; Save starting position
        LD      E,255           ; All of string
        CP      ')'             ; Any length given?
        JP      Z,RSTSTR        ; No - Rest of string
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        CALL    GETINT          ; Get integer 0-255
RSTSTR: CALL    CHKSYN          ; Make sure ")" follows
        DEFB    ")"
        POP     AF              ; Restore starting position
        EX      (SP),HL         ; Get string,8ave code string
        LD      BC,MID1         ; Continuation of MID$ routine
        PUSH    BC              ; Save for return
        DEC     A               ; Starting position-1
        CP      (HL)            ; Compare with length
        LD      B,0             ; Zero bytes length
        RET     NC              ; Null string if start past end
        LD      C,A             ; Save starting position-1
        LD      A,(HL)          ; Get length of string
        SUB     C               ; Subtract start
        CP      E               ; Enough string for it?
        LD      B,A             ; Save maximum length available
        RET     C               ; Truncate string if needed
        LD      B,E             ; Set specified length
        RET                     ; Go and create string

VAL:    CALL    GETLEN          ; Get length of string
        JP      Z,RESZER        ; Result zero
        LD      E,A             ; Save length
        INC     HL
        INC     HL
        LD      A,(HL)          ; Get LSB of address
        INC     HL
        LD      H,(HL)          ; Get MSB of address
        LD      L,A             ; HL = String address
        PUSH    HL              ; Save string address
        ADD     HL,DE
        LD      B,(HL)          ; Get end of string+1 byte
        LD      (HL),D          ; Zero it to terminate
        EX      (SP),HL         ; Save string end,get start
        PUSH    BC              ; Save end+1 byte
        LD      A,(HL)          ; Get starting byte
        CALL    ASCTFP          ; Convert ASCII string to FP
        POP     BC              ; Restore end+1 byte
        POP     HL              ; Restore end+1 address
        LD      (HL),B          ; Put back original byte
        RET

LFRGNM: EX      DE,HL           ; Code string address to HL
        CALL    CHKSYN          ; Make sure ")" follows
        DEFB    ")"
MIDNUM: POP     BC              ; Get return address
        POP     DE              ; Get number supplied
        PUSH    BC              ; Re-save return address
        LD      B,E             ; Number to B
        RET

INP:    CALL    MAKINT          ; Make it integer A
        LD      (INPORT),A      ; Set input port
        CALL    INPSUB          ; Get input from port
        JP      PASSA           ; Return integer A

POUT:   CALL    SETIO           ; Set up port number
        JP      OUTSUB          ; Output data and return

WAIT:   CALL    SETIO           ; Set up port number
        PUSH    AF              ; Save AND mask
        LD      E,0             ; Assume zero if none given
        DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    GETCHR          ; Get next character
        JP      Z,NOXOR         ; No XOR byte given
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        CALL    GETINT          ; Get integer 0-255 to XOR with
NOXOR:  POP     BC              ; Restore AND mask
WAITLP: CALL    INPSUB          ; Get input
        XOR     E               ; Flip selected bits
        AND     B               ; Result non-zero?
        JP      Z,WAITLP        ; No = keep waiting
        RET

SETIO:  CALL    GETINT          ; Get integer 0-255
        LD      (INPORT),A      ; Set input port
        LD      (OTPORT),A      ; Set output port
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        JP      GETINT          ; Get integer 0-255 and return

FNDNUM: CALL    GETCHR          ; Get next character
GETINT: CALL    GETNUM          ; Get a number from 0 to 255
MAKINT: CALL    DEPINT          ; Make sure value 0 - 255
        LD      A,D             ; Get MSB of number
        OR      A               ; Zero?
        JP      NZ,FCERR        ; No - Error
        DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    GETCHR          ; Get next character
        LD      A,E             ; Get number to A
        RET

PEEK:   CALL    DEINT           ; Get memory address
        LD      A,(DE)          ; Get byte in memory
        JP      PASSA           ; Return integer A

POKE:   CALL    GETNUM          ; Get memory address
        CALL    DEINT           ; Get integer -32768 to 3276
        PUSH    DE              ; Save memory address
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        CALL    GETINT          ; Get integer 0-255
        POP     DE              ; Restore memory address
        LD      (DE),A          ; Load it into memory
        RET

ROUND:  LD      HL,HALF         ; Add 0.5 to FPREG
ADDPHL: CALL    LOADFP          ; Load FP at (HL) to BCDE
        JP      FPADD           ; Add BCDE to FPREG

PSUB:   POP     BC              ; Get FP number from stack
        POP     DE
FPSUB:  LD      A,B             ; Get FP exponent
        OR      A               ; Is number zero?
        JP      Z,INVSGN        ; Yes, Negate and return
        LD      A,(FPEXP)       ; Get exponent of FPREG
        OR      A               ; Is this number zero?
        JP      Z,FPBCDE        ; Yes - Move BCDE to FPREG

        LD      HL,BC           ; Move FP to HLDE
        CALL    PUSHF_HLDE      ; Load HLDE to APU
        CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_FSUB
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

PADD:   POP     BC              ; Get FP number from stack
        POP     DE
FPADD:  LD      A,B             ; Get FP exponent
        OR      A               ; Is number zero?
        RET     Z               ; Yes - Nothing to add
        LD      A,(FPEXP)       ; Get exponent of FPREG
        OR      A               ; Is this number zero?
        JP      Z,FPBCDE        ; Yes - Move BCDE to FPREG

        LD      HL,BC           ; Move FP to HLDE
        CALL    PUSHF_HLDE      ; Load HLDE to APU
        CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_FADD
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

CONPOS: CALL    C,COMPL         ; Overflow - Make it positive

BNORM:  LD      L,B             ; L = Exponent
        LD      H,E             ; H = LSB
        XOR     A
BNRMLP: LD      B,A             ; Save bit count
        LD      A,C             ; Get MSB
        OR      A               ; Is it zero?
        JP      NZ,PNORM        ; No - Do it bit at a time
        LD      C,D             ; MSB = NMSB
        LD      D,H             ; NMSB= LSB
        LD      H,L             ; LSB = VLSB
        LD      L,A             ; VLSB= 0
        LD      A,B             ; Get exponent
        SUB     8               ; Count 8 bits
        CP      -24-8           ; Was number zero?
        JP      NZ,BNRMLP       ; No - Keep normalising
RESZER: XOR     A               ; Result is zero
SAVEXP: LD      (FPEXP),A       ; Save result as zero
        RET

NORMAL: DEC     B               ; Count bits
        ADD     HL,HL           ; Shift HL left
        LD      A,D             ; Get NMSB
        RLA                     ; Shift left with last bit
        LD      D,A             ; Save NMSB
        LD      A,C             ; Get MSB
        ADC     A,A             ; Shift left with last bit
        LD      C,A             ; Save MSB
PNORM:  JP      P,NORMAL        ; Not done - Keep going
        LD      A,B             ; Number of bits shifted
        LD      E,H             ; Save HL in EB
        LD      B,L
        OR      A               ; Any shifting done?
        JP      Z,RONDUP        ; No - Round it up
        LD      HL,FPEXP        ; Point to exponent
        ADD     A,(HL)          ; Add shifted bits
        LD      (HL),A          ; Re-save exponent
        JP      NC,RESZER       ; Underflow - Result is zero
        RET     Z               ; Result is zero
RONDUP: LD      A,B             ; Get VLSB of number
RONDB:  LD      HL,FPEXP        ; Point to exponent
        OR      A               ; Any rounding?
        CALL    M,FPROND        ; Yes - Round number up
        LD      B,(HL)          ; B = Exponent
        INC     HL
        LD      A,(HL)          ; Get sign of result
        AND     10000000B       ; Only bit 7 needed
        XOR     C               ; Set correct sign
        LD      C,A             ; Save correct sign in number
        JP      FPBCDE          ; Move BCDE to FPREG

FPROND: INC     E               ; Round LSB
        RET     NZ              ; Return if ok
        INC     D               ; Round NMSB
        RET     NZ              ; Return if ok
        INC     C               ; Round MSB
        RET     NZ              ; Return if ok
        LD      C,80H           ; Set normal value
        INC     (HL)            ; Increment exponent
        RET     NZ              ; Return if ok
        JP      OVERR           ; Overflow error

PLUCDE: LD      A,(HL)          ; Get LSB of FPREG
        ADD     A,E             ; Add LSB of BCDE
        LD      E,A             ; Save LSB of BCDE
        INC     HL
        LD      A,(HL)          ; Get NMSB of FPREG
        ADC     A,D             ; Add NMSB of BCDE
        LD      D,A             ; Save NMSB of BCDE
        INC     HL
        LD      A,(HL)          ; Get MSB of FPREG
        ADC     A,C             ; Add MSB of BCDE
        LD      C,A             ; Save MSB of BCDE
        RET

COMPL:  LD      HL,SGNRES       ; Sign of result
        LD      A,(HL)          ; Get sign of result
        CPL                     ; Negate it
        LD      (HL),A          ; Put it back
        XOR     A
        LD      L,A             ; Set L to zero
        SUB     B               ; Negate exponent,set carry
        LD      B,A             ; Re-save exponent
        LD      A,L             ; Load zero
        SBC     A,E             ; Negate LSB
        LD      E,A             ; Re-save LSB
        LD      A,L             ; Load zero
        SBC     A,D             ; Negate NMSB
        LD      D,A             ; Re-save NMSB
        LD      A,L             ; Load zero
        SBC     A,C             ; Negate MSB
        LD      C,A             ; Re-save MSB
        RET

SCALE:  LD      B,0             ; Clear underflow
SCALLP: SUB     8               ; 8 bits (a whole byte)?
        JP      C,SHRITE        ; No - Shift right A bits
        LD      B,E             ; <- Shift
        LD      E,D             ; <- right
        LD      D,C             ; <- eight
        LD      C,0             ; <- bits
        JP      SCALLP          ; More bits to shift

SHRITE: ADD     A,8+1           ; Adjust count
        LD      L,A             ; Save bits to shift
SHRLP:  XOR     A               ; Flag for all done
        DEC     L               ; All shifting done?
        RET     Z               ; Yes - Return
        LD      A,C             ; Get MSB
        RRA                     ; Shift it right
        LD      C,A             ; Re-save
        LD      A,D             ; Get NMSB
        RRA                     ; Shift right with last bit
        LD      D,A             ; Re-save it
        LD      A,E             ; Get LSB
        RRA                     ; Shift right with last bit
        LD      E,A             ; Re-save it
        LD      A,B             ; Get underflow
        RRA                     ; Shift right with last bit
        LD      B,A             ; Re-save underflow
        JP      SHRLP           ; More bits to do

UNITY:  DEFB    000H,000H,000H,081H     ; 1.00000

LOG:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_LN
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

MULT:   POP     HL              ; Get number from stack
        POP     DE
FPMULT: LD      A,(FPEXP)       ; Get exponent of FPREG
        OR      A
        RET     Z               ; RETurn if number is zero

        CALL    PUSHF_HLDE      ; Load HLDE to APU
        CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_FMUL
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

DIV10:  LD      HL,(FPREG)      ; LSB,NLSB of FPREG
        PUSH    HL              ; Stack them
        LD      HL,(FPREG+2)    ; MSB and exponent of FPREG
        PUSH    HL              ; Stack them
        LD      BC,8420H        ; BCDE = 10.
        LD      DE,0000H
        CALL    FPBCDE          ; Move 10 to FPREG

DIV:    POP     HL              ; Get number from stack
        POP     DE
FPDIV:  LD      A,(FPEXP)       ; Get exponent of FPREG
        OR      A
        JP      Z,DZERR         ; Error if division by zero

        CALL    PUSHF_HLDE      ; Load HLDE to APU
        CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_FDIV
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

MLSP10: CALL    BCDEFP          ; Move FPREG to BCDE
        LD      A,B             ; Get exponent
        OR      A               ; Is it zero?
        RET     Z               ; Yes - Result is zero
        ADD     A,2             ; Multiply by 4
        JP      C,OVERR         ; Overflow - ?OV Error
        LD      B,A             ; Re-save exponent
        CALL    FPADD           ; Add BCDE to FPREG (Times 5)
        LD      HL,FPEXP        ; Point to exponent
        INC     (HL)            ; Double number (Times 10)
        RET     NZ              ; Ok - Return
        JP      OVERR           ; Overflow error

TSTSGN: LD      A,(FPEXP)       ; Get sign of FPREG
        OR      A
        RET     Z               ; RETurn if number is zero
        LD      A,(FPREG+2)     ; Get MSB of FPREG
        DEFB    0FEH            ; Test sign
RETREL: CPL                     ; Invert sign
        RLA                     ; Sign bit to carry
FLGDIF: SBC     A,A             ; Carry to all bits of A
        RET     NZ              ; Return -1 if negative
        INC     A               ; Bump to +1
        RET                     ; Positive - Return +1

SGN:    CALL    TSTSGN          ; Test sign of FPREG
FLGREL: LD      B,80H+8         ; 8 bit integer in exponent
        LD      DE,0            ; Zero NMSB and LSB
RETINT: LD      HL,FPEXP        ; Point to exponent
        LD      C,A             ; CDE = MSB,NMSB and LSB
        LD      (HL),B          ; Save exponent
        LD      B,0             ; CDE = integer to normalise
        INC     HL              ; Point to sign of result
        LD      (HL),80H        ; Set sign of result
        RLA                     ; Carry = sign of integer
        JP      CONPOS          ; Set sign of result

ABS:    CALL    TSTSGN          ; Test sign of FPREG
        RET     P               ; Return if positive
INVSGN: LD      HL,FPREG+2      ; Point to MSB
        LD      A,(HL)          ; Get sign of mantissa
        XOR     80H             ; Invert sign of mantissa
        LD      (HL),A          ; Re-save sign of mantissa
        RET

STAKFP: EX      DE,HL           ; Save code string address
        LD      HL,(FPREG)      ; LSB and NLSB of FPREG
        EX      (SP),HL         ; Stack them,get return
        PUSH    HL              ; Re-save return
        LD      HL,(FPREG+2)    ; MSB and exponent of FPREG
        EX      (SP),HL         ; Stack them,get return
        PUSH    HL              ; Re-save return
        EX      DE,HL           ; Restore code string address
        RET

PHLTFP: CALL    LOADFP          ; Number at HL to BCDE
FPBCDE: EX      DE,HL           ; Save code string address
        LD      (FPREG),HL      ; Save LSB and NLSB of number
        LD      HL,BC           ; Exponent and MSB of number
        LD      (FPREG+2),HL    ; Save MSB and exponent
        EX      DE,HL           ; Restore code string address
        RET

BCDEFP: LD      HL,FPREG        ; Point to FPREG
LOADFP: LD      E,(HL+)         ; Get LSB of number, increment
        LD      D,(HL+)         ; Get NMSB of number, increment
        LD      C,(HL+)         ; Get MSB of number, increment
        LD      B,(HL)          ; Get exponent of number
INCHL:  INC     HL              ; Used for conditional "INC HL"
        RET

FPTHL:  LD      DE,FPREG        ; Point to FPREG
DETHL4: LD      A,(DE+)         ; Get source, increment
        LD      (HL+),A         ; Save destination, increment
        LD      A,(DE+)         ; Get source, increment
        LD      (HL+),A         ; Save destination, increment
        LD      A,(DE+)         ; Get source, increment
        LD      (HL+),A         ; Save destination, increment
        LD      A,(DE+)         ; Get source, increment
        LD      (HL+),A         ; Save destination, increment
        RET

SIGNS:  LD      HL,FPREG+2      ; Point to MSB of FPREG
        LD      A,(HL)          ; Get MSB
        RLCA                    ; Old sign to carry
        SCF                     ; Set MSBit
        RRA                     ; Set MSBit of MSB
        LD      (HL),A          ; Save new MSB
        CCF                     ; Complement sign
        RRA                     ; Old sign to carry
        INC     HL
        INC     HL
        LD      (HL),A          ; Set sign of result SGNRES
        LD      A,C             ; Get MSB
        RLCA                    ; Old sign to carry
        SCF                     ; Set MSBit
        RRA                     ; Set MSBit of MSB
        LD      C,A             ; Save MSB
        RRA
        XOR     (HL)            ; New sign of result
        RET

CMPNUM: LD      A,B             ; Get exponent of number
        OR      A
        JP      Z,TSTSGN        ; Zero - Test sign of FPREG
        LD      HL,RETREL       ; Return relation routine
        PUSH    HL              ; Save for return
        CALL    TSTSGN          ; Test sign of FPREG
        LD      A,C             ; Get MSB of number
        RET     Z               ; FPREG zero - Number's MSB
        LD      HL,FPREG+2      ; MSB of FPREG
        XOR     (HL)            ; Combine signs
        LD      A,C             ; Get MSB of number
        RET     M               ; Exit if signs different
        CALL    CMPFP           ; Compare FP numbers
        RRA                     ; Get carry to sign
        XOR     C               ; Combine with MSB of number
        RET

CMPFP:  INC     HL              ; Point to exponent
        LD      A,B             ; Get exponent
        CP      (HL)            ; Compare exponents
        RET     NZ              ; Different
        DEC     HL              ; Point to MBS
        LD      A,C             ; Get MSB
        CP      (HL)            ; Compare MSBs
        RET     NZ              ; Different
        DEC     HL              ; Point to NMSB
        LD      A,D             ; Get NMSB
        CP      (HL)            ; Compare NMSBs
        RET     NZ              ; Different
        DEC     HL              ; Point to LSB
        LD      A,E             ; Get LSB
        SUB     (HL)            ; Compare LSBs
        RET     NZ              ; Different
        POP     HL              ; Drop RETurn
        POP     HL              ; Drop another RETurn
        RET

FPINT:  LD      B,A             ; <- Move
        LD      C,A             ; <- exponent
        LD      D,A             ; <- to all
        LD      E,A             ; <- bits
        OR      A               ; Test exponent
        RET     Z               ; Zero - Return zero
        PUSH    HL              ; Save pointer to number
        CALL    BCDEFP          ; Move FPREG to BCDE
        CALL    SIGNS           ; Set MSBs & sign of result
        XOR     (HL)            ; Combine with sign of FPREG
        LD      H,A             ; Save combined signs
        CALL    M,DCBCDE        ; Negative - Decrement BCDE
        LD      A,80H+24        ; 24 bits
        SUB     B               ; Bits to shift
        CALL    SCALE           ; Shift BCDE
        LD      A,H             ; Get combined sign
        RLA                     ; Sign to carry
        CALL    C,FPROND        ; Negative - Round number up
        LD      B,0             ; Zero exponent
        CALL    C,COMPL         ; If negative make positive
        POP     HL              ; Restore pointer to number
        RET

DCBCDE: DEC     DE              ; Decrement BCDE
        JP      NK,$+4          ; Exit if LSBs not FFFF
        DEC     BC              ; Decrement MSBs
        RET

INT:    LD      HL,FPEXP        ; Point to exponent
        LD      A,(HL)          ; Get exponent
        CP      80H+24          ; Integer accuracy only?
        LD      A,(FPREG)       ; Get LSB
        RET     NC              ; Yes - Already integer
        LD      A,(HL)          ; Get exponent
        CALL    FPINT           ; F.P to integer
        LD      (HL),80H+24     ; Save 24 bit integer
        LD      A,E             ; Get LSB of number
        PUSH    AF              ; Save LSB
        LD      A,C             ; Get MSB of number
        RLA                     ; Sign to carry
        CALL    CONPOS          ; Set sign of result
        POP     AF              ; Restore LSB of number
        RET

MLDEBC:                         ; Multiply DE by BC to HL
        LD      HL,0            ; Clear partial product
        LD      A,B             ; Test multiplier
        OR      C
        RET     Z               ; Return zero if zero
        LD      A,8             ; 16 bits (8 iterations)
MLDBLP: ADD     HL,HL           ; Shift partial product left
        RL      DE              ; Shift (rotate) multiplier left
        JP      NC,NOMLAD0      ; Bit was zero - No add
        ADD     HL,BC           ; Add multiplicand
        JP      NC,NOMLAD0      ; No carry
        INC     DE              ; Capture carry for 32 bit overflow
NOMLAD0:ADD     HL,HL           ; Shift partial product left
        RL      DE              ; Shift (rotate) multiplier left
        JP      NC,NOMLAD1      ; Bit was zero - No add
        ADD     HL,BC           ; Add multiplicand
        JP      NC,NOMLAD1      ; No carry
        INC     DE              ; Capture carry for 32 bit overflow
NOMLAD1:DEC     A               ; Count bits
        JP      NZ,MLDBLP       ; More
        LD      A,D
        OR      E
        RET     Z               ; No overflow  
        JP      BSERR           ; ?BS Error if overflow

ASCTFP: CP      '-'             ; Negative?
        PUSH    AF              ; Save it and flags
        JP      Z,CNVNUM        ; Yes - Convert number
        CP      '+'             ; Positive?
        JP      Z,CNVNUM        ; Yes - Convert number
        DEC     HL              ; DEC 'cos GETCHR INCs
CNVNUM: CALL    RESZER          ; Set result to zero
        LD      B,A             ; Digits after point counter
        LD      D,A             ; Sign of exponent
        LD      E,A             ; Exponent of ten
        CPL
        LD      C,A             ; Before or after point flag
MANLP:  CALL    GETCHR          ; Get next character
        JP      C,ADDIG         ; Digit - Add to number
        CP      '.'
        JP      Z,DPOINT        ; '.' - Flag point
        CP      'E'
        JP      NZ,CONEXP       ; Not 'E' - Scale number
        CALL    GETCHR          ; Get next character
        CALL    SGNEXP          ; Get sign of exponent
EXPLP:  CALL    GETCHR          ; Get next character
        JP      C,EDIGIT        ; Digit - Add to exponent
        INC     D               ; Is sign negative?
        JP      NZ,CONEXP       ; No - Scale number
        XOR     A
        SUB     E               ; Negate exponent
        LD      E,A             ; And re-save it
        INC     C               ; Flag end of number
DPOINT: INC     C               ; Flag point passed
        JP      Z,MANLP         ; Zero - Get another digit
CONEXP: PUSH    HL              ; Save code string address
        LD      A,E             ; Get exponent
        SUB     B               ; Subtract digits after point
SCALMI: CALL    P,SCALPL        ; Positive - Multiply number
        JP      P,ENDCON        ; Positive - All done
        PUSH    AF              ; Save number of times to /10
        CALL    DIV10           ; Divide by 10
        POP     AF              ; Restore count
        INC     A               ; Count divides

ENDCON: JP      NZ,SCALMI       ; More to do
        POP     DE              ; Restore code string address
        POP     AF              ; Restore sign of number
        CALL    Z,INVSGN        ; Negative - Negate number
        EX      DE,HL           ; Code string address to HL
        RET

SCALPL: RET     Z               ; Exit if no scaling needed
MULTEN: PUSH    AF              ; Save count
        CALL    MLSP10          ; Multiply number by 10
        POP     AF              ; Restore count
        DEC     A               ; Count multiplies
        RET

ADDIG:  PUSH    DE              ; Save sign of exponent
        LD      D,A             ; Save digit
        LD      A,B             ; Get digits after point
        ADC     A,C             ; Add one if after point
        LD      B,A             ; Re-save counter
        PUSH    BC              ; Save point flags
        PUSH    HL              ; Save code string address
        PUSH    DE              ; Save digit
        CALL    MLSP10          ; Multiply number by 10
        POP     AF              ; Restore digit
        SUB     '0'             ; Make it absolute
        CALL    RSCALE          ; Re-scale number
        POP     HL              ; Restore code string address
        POP     BC              ; Restore point flags
        POP     DE              ; Restore sign of exponent
        JP      MANLP           ; Get another digit

RSCALE: LD      HL,(FPREG)      ; LSB and NLSB of FPREG
        PUSH    HL              ; Stack them
        LD      HL,(FPREG+2)    ; MSB and exponent of FPREG
        PUSH    HL              ; Stack them
        CALL    FLGREL          ; Digit to add to FPREG
        JP      PADD            ; Add stack to FPREG and return

EDIGIT: LD      A,E             ; Get digit
        RLCA                    ; Times 2
        RLCA                    ; Times 4
        ADD     A,E             ; Times 5
        RLCA                    ; Times 10
        ADD     A,(HL)          ; Add next digit
        SUB     '0'             ; Make it absolute
        LD      E,A             ; Save new digit
        JP      EXPLP           ; Look for another digit

LINEIN: PUSH    HL              ; Save code string address
        LD      HL,INMSG        ; Output " in "
        CALL    PRS             ; Output string at HL
        POP     HL              ; Restore code string address
PRNTHL: EX      DE,HL           ; Code string address to DE
        XOR     A
        LD      B,80H+24        ; 24 bits
        CALL    RETINT          ; Return the integer
        LD      HL,PRNUMS       ; Print number string
        PUSH    HL              ; Save for return
NUMASC: LD      HL,PBUFF        ; Convert number to ASCII
        PUSH    HL              ; Save for return
        CALL    TSTSGN          ; Test sign of FPREG
        LD      (HL),' '        ; Space at start
        JP      P,SPCFST        ; Positive - Space to start
        LD      (HL),'-'        ; '-' sign at start
SPCFST: INC     HL              ; First byte of number
        LD      (HL),'0'        ; '0' if zero
        JP      Z,JSTZER        ; Return '0' if zero
        PUSH    HL              ; Save buffer address
        CALL    M,INVSGN        ; Negate FPREG if negative
        XOR     A               ; Zero A
        PUSH    AF              ; Save it
        CALL    RNGTST          ; Test number is in range
SIXDIG: LD      BC,9143H        ; BCDE - 99999.9
        LD      DE,4FF8H
        CALL    CMPNUM          ; Compare numbers
        OR      A
        JP      PO,INRNG        ; > 99999.9 - Sort it out
        POP     AF              ; Restore count
        CALL    MULTEN          ; Multiply by ten
        PUSH    AF              ; Re-save count
        JP      SIXDIG          ; Test it again

GTSIXD: CALL    DIV10           ; Divide by 10
        POP     AF              ; Get count
        INC     A               ; Count divides
        PUSH    AF              ; Re-save count
        CALL    RNGTST          ; Test number is in range
INRNG:  CALL    ROUND           ; Add 0.5 to FPREG
        INC     A
        CALL    FPINT           ; F.P to integer
        CALL    FPBCDE          ; Move BCDE to FPREG
        LD      BC,0306H        ; 1E+06 to 1E-03 range
        POP     AF              ; Restore count
        ADD     A,C             ; 6 digits before point
        INC     A               ; Add one
        JP      M,MAKNUM        ; Do it in 'E' form if < 1E-02
        CP      6+1+1           ; More than 999999 ?
        JP      NC,MAKNUM       ; Yes - Do it in 'E' form
        INC     A               ; Adjust for exponent
        LD      B,A             ; Exponent of number
        LD      A,2             ; Make it zero after

MAKNUM: DEC     A               ; Adjust for digits to do
        DEC     A
        POP     HL              ; Restore buffer address
        PUSH    AF              ; Save count
        LD      DE,POWERS       ; Powers of ten
        DEC     B               ; Count digits before point
        JP      NZ,DIGTXT       ; Not zero - Do number
        LD      (HL),'.'        ; Save point
        INC     HL              ; Move on
        LD      (HL),'0'        ; Save zero
        INC     HL              ; Move on
DIGTXT: DEC     B               ; Count digits before point
        LD      (HL),'.'        ; Save point in case
        CALL    Z,INCHL         ; Last digit - move on
        PUSH    BC              ; Save digits before point
        PUSH    HL              ; Save buffer address
        PUSH    DE              ; Save powers of ten
        CALL    BCDEFP          ; Move FPREG to BCDE
        POP     HL              ; Powers of ten table
        LD      B,'0'-1         ; ASCII '0' - 1
TRYAGN: INC     B               ; Count subtractions
        LD      A,E             ; Get LSB
        SUB     (HL)            ; Subtract LSB
        LD      E,A             ; Save LSB
        INC     HL
        LD      A,D             ; Get NMSB
        SBC     A,(HL)          ; Subtract NMSB
        LD      D,A             ; Save NMSB
        INC     HL
        LD      A,C             ; Get MSB
        SBC     A,(HL)          ; Subtract MSB
        LD      C,A             ; Save MSB
        DEC     HL              ; Point back to start
        DEC     HL
        JP      NC,TRYAGN       ; No overflow - Try again
        CALL    PLUCDE          ; Restore number
        INC     HL              ; Start of next number
        CALL    FPBCDE          ; Move BCDE to FPREG
        EX      DE,HL           ; Save point in table
        POP     HL              ; Restore buffer address
        LD      (HL),B          ; Save digit in buffer
        INC     HL              ; And move on
        POP     BC              ; Restore digit count
        DEC     C               ; Count digits
        JP      NZ,DIGTXT       ; More - Do them
        DEC     B               ; Any decimal part?
        JP      Z,DOEBIT        ; No - Do 'E' bit
SUPTLZ: DEC     HL              ; Move back through buffer
        LD      A,(HL)          ; Get character
        CP      '0'             ; '0' character?
        JP      Z,SUPTLZ        ; Yes - Look back for more
        CP      '.'             ; A decimal point?
        CALL    NZ,INCHL        ; Move back over digit

DOEBIT: POP     AF              ; Get 'E' flag
        JP      Z,NOENED        ; No 'E' needed - End buffer
        LD      (HL),'E'        ; Put 'E' in buffer
        INC     HL              ; And move on
        LD      (HL),'+'        ; Put '+' in buffer
        JP      P,OUTEXP        ; Positive - Output exponent
        LD      (HL),'-'        ; Put '-' in buffer
        CPL                     ; Negate exponent
        INC     A
OUTEXP: LD      B,'0'-1         ; ASCII '0' - 1
EXPTEN: INC     B               ; Count subtractions
        SUB     10              ; Tens digit
        JP      NC,EXPTEN       ; More to do
        ADD     A,'0'+10        ; Restore and make ASCII
        INC     HL              ; Move on
        LD      (HL),B          ; Save MSB of exponent
JSTZER: INC     HL              ;
        LD      (HL),A          ; Save LSB of exponent
        INC     HL
NOENED: LD      (HL),C          ; Mark end of buffer
        POP     HL              ; Restore code string address
        RET

RNGTST: LD      BC,9474H        ; BCDE = 999999.
        LD      DE,23F7H
        CALL    CMPNUM          ; Compare numbers
        OR      A
        POP     HL              ; Return address to HL
        JP      PO,GTSIXD       ; Too big - Divide by ten
        JP      (HL)            ; Otherwise return to caller

HALF:   DEFB    00H,00H,00H,80H ; 0.5

POWERS: DEFB    0A0H,086H,001H  ; 100000
        DEFB    010H,027H,000H  ;  10000
        DEFB    0E8H,003H,000H  ;   1000
        DEFB    064H,000H,000H  ;    100
        DEFB    00AH,000H,000H  ;     10
        DEFB    001H,000H,000H  ;      1

NEGAFT: LD      HL,INVSGN       ; Negate result
        EX      (SP),HL         ; To be done after caller
        JP      (HL)            ; Return to caller

SQR:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_SQRT
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

POWER:  POP     HL              ; Get base from stack
        POP     DE
        CALL    PUSHF_HLDE      ; Load HLDE to APU
        CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_PWR
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

EXP:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_EXP
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

RND:    CALL    TSTSGN          ; Test sign of FPREG
        LD      HL,SEED+2       ; Random number seed
        JP      M,RESEED        ; Negative - Re-seed
        LD      HL,LSTRND       ; Last random number
        CALL    PHLTFP          ; Move last RND to FPREG
        LD      HL,SEED+2       ; Random number seed
        RET     Z               ; Return if RND(0)
        ADD     A,(HL)          ; Add (SEED)+2)
        AND     00000111B       ; 0 to 7
        LD      B,0
        LD      (HL),A          ; Re-save seed
        INC     HL              ; Move to coefficient table
        ADD     A,A             ; 4 bytes
        ADD     A,A             ; per entry
        LD      C,A             ; BC = Offset into table
        ADD     HL,BC           ; Point to coefficient
        CALL    LOADFP          ; Coefficient to BCDE
        CALL    FPMULT          ; Multiply FPREG by coefficient
        LD      A,(SEED+1)      ; Get (SEED+1)
        INC     A               ; Add 1
        AND     00000011B       ; 0 to 3
        LD      B,0
        CP      1               ; Is it zero?
        ADC     A,B             ; Yes - Make it 1
        LD      (SEED+1),A      ; Re-save seed
        LD      HL,RNDTAB-4     ; Addition table
        ADD     A,A             ; 4 bytes
        ADD     A,A             ; per entry
        LD      C,A             ; BC = Offset into table
        ADD     HL,BC           ; Point to value
        CALL    ADDPHL          ; Add value to FPREG
RND1:   CALL    BCDEFP          ; Move FPREG to BCDE
        LD      A,E             ; Get LSB
        LD      E,C             ; LSB = MSB
        XOR     01001111B       ; Fiddle around
        LD      C,A             ; New MSB
                                ; HL is pointing to SGNRES
        LD      (HL),80H        ; Set saved signed bit to positive
        DEC     HL              ; Point to Exponent
        LD      B,(HL)          ; Get Exponent to BCDE
        LD      (HL),80H        ; Makes Exponent 1
        LD      HL,SEED         ; Random number seed
        INC     (HL)            ; Count seed
        LD      A,(HL)          ; Get seed
        SUB     171             ; Do it modulo 171
        JP      NZ,RND2         ; Non-zero - Ok
        LD      (HL),A          ; Zero seed
        INC     C               ; Fillde about
        DEC     D               ; with the
        INC     E               ; number
RND2:   CALL    BNORM           ; Normalise number
        LD      HL,LSTRND       ; Save random number
        JP      FPTHL           ; Move FPREG to last and return

RESEED: LD      (HL),A          ; Re-seed random numbers
        DEC     HL
        LD      (HL),A
        DEC     HL
        LD      (HL),A
        JP      RND1            ; Return RND seed

RNDTAB: DEFB    068H,0B1H,046H,068H ; Table used by RND
        DEFB    099H,0E9H,092H,069H
        DEFB    010H,0D1H,075H,068H

COS:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_COS
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

SIN:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_SIN
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

TAN:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_TAN
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

ACS:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_ACOS
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

ASN:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_ASIN
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

ATN:    CALL    PUSHF_FPREG     ; Load FPREG to APU
        LD      A,IO_APU_OP_ATAN
        OUT     (IO_APU_CONTROL),A
        JP      POPF_FPREG

ARET:   RET                     ; A RETurn instruction

CLS:    PUSH    HL              ; Save code string address
        LD      HL,CLRSCRN      ; ASCII Clear screen
        CALL    PRS             ; Output string
        POP     HL              ; Restore code string address
        RET

CLRSCRN:
        DEFB    ESC,"[2J",0     ; VT100 Clear screen escape code

WIDTH:  CALL    GETINT          ; Get integer 0-255 in A
        LD      (LWIDTH),A      ; Set width
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        CALL    GETINT          ; Get integer 0-255 in A
        LD      (COMMAN),A      ; Set comma width
        RET

LINES:  CALL    GETNUM          ; Get a number
        CALL    DEINT           ; Get integer -32768 to 32767
        EX      DE,HL
        LD      (LINESC),HL     ; Set lines counter
        LD      (LINESN),HL     ; Set lines number
        EX      DE,HL           ; Restore code string address
        RET

DEEK:   CALL    DEINT           ; Get integer -32768 to 32767
        PUSH    DE              ; Save number
        POP     HL              ; Number to HL
        LD      B,(HL)          ; Get LSB of contents
        INC     HL
        LD      A,(HL)          ; Get MSB of contents
        JP      ABPASS          ; Return integer AB

DOKE:   CALL    GETNUM          ; Get a number
        CALL    DEINT           ; Get integer -32768 to 32767
        PUSH    DE              ; Save address
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        CALL    GETNUM          ; Get a number
        CALL    DEINT           ; Get integer -32768 to 32767
        EX      (SP),HL         ; Save value, get address
        LD      (HL),E          ; Save LSB of value
        INC     HL
        LD      (HL),D          ; Save MSB of value
        POP     HL              ; Restore code string address
        RET

MONITR: JP      $0000           ; Cold Start (Normally Monitor Start)


        ; push MBF32 floating point in FPREG into Am9511 stack.
        ; Convert from MBF32_float to am9511_float.
        ; (C) feilipu
        ; 
        ; uses  : af, de, hl

PUSHF_FPREG:
        ld hl,(FPREG)           ; store mantissa LSW in DE
        ex de,hl
        ld hl,(FPREG+2)         ; store mantissa MSW in HL

        ; push MBF32 floating point in HLDE into Am9511 stack.
        ; Convert from MBF32_float to am9511_float.
        ; (C) feilipu
        ; 
        ; uses  : af, de, hl

PUSHF_HLDE:
        ld a,h                  ; capture exponent
        or a                    ; check for zero
        jp Z,PUSHF_HLDE_ZERO
        cp 80h+63               ; check for overflow
        jp NC,OVERR             ; overflow error
        cp 80h-64               ; check for underflow
        jp C,PUSHF_HLDE_ZERO
        sub 80h                 ; remove bias
        ld h,a                  ; return exponent

        add hl,hl               ; shift sign into exponent byte

        ld a,h
        rrca                    ; get sign into correct place
        ld h,a                  ; restore exponent & sign

        ld a,l
        scf                     ; set mantissa leading 1
        rra                     ; restore mantissa with leading 1
        ld l,a

PUSHF_HLDE_REJOIN:
;       Assuming we are the only ones to use the APU
;       it is likely to be ready when we start.
;       in a,(IO_APU_STATUS)    ; read the APU status register
;       rlca                    ; busy? IO_APU_STATUS_BUSY
;       jp C,PUSHF_HLDE_REJOIN

        ld a,e
        out (IO_APU_DATA),a     ; load mantissa into APU
        ld a,d
        out (IO_APU_DATA),a
        ld a,l
        out (IO_APU_DATA),a
        ld a,h
        out (IO_APU_DATA),a     ; load exponent into APU
        ret

PUSHF_HLDE_ZERO:
        ld hl,0                 ; no signed zero available
        ld de,hl
        jp PUSHF_HLDE_REJOIN


        ; float primitive
        ; pop a MBF32 floating point from the Am9511 stack.
        ; Convert from am9511_float to MBF32_float.
        ; (C) feilipu
        ; 
        ; uses  : af, de, hl

POPF_FPREG_WAIT:
        ex (sp),hl
        ex (sp),hl

POPF_FPREG:
        in a,(IO_APU_STATUS)    ; read the APU status register
        rlca                    ; busy? IO_APU_STATUS_BUSY
        jp C,POPF_FPREG_WAIT

        and 07ch                ; errors from status register
        jp NZ,POPF_FPREG_ERRORS

        in a,(IO_APU_DATA)      ; read the APU data register
        ld h,a                  ; load MSW from APU
        in a,(IO_APU_DATA)
        ld l,a
        in a,(IO_APU_DATA)
        ld d,a                  ; load LSW from APU
        in a,(IO_APU_DATA)
        ld e,a

        ld a,l                  ; load mantissa
        add a,a                 ; remove leading 1 from mantissa
        add hl,hl               ; adjust twos complement exponent, sign to carry
        rra                     ; move sign to mantissa MSB
        sra hl                  ; sign extension on exponent
        ld l,a                  ; store mantissa
        ld a,h
        add a,80h               ; add bias
        ld h,a

POPF_FPREG_REJOIN:
        ld (FPREG+2),hl         ; store mantissa MSB and exponent
        ex de,hl
        ld (FPREG),hl           ; store mantissa LSW
        ret

POPF_FPREG_ERRORS:
        rrca                    ; relocate status bits
        rrca
        rrca
        jp C,OVERR              ; overflow
        rrca
        rrca
        jp C,FCERR              ; negative sqr or log
        rrca
        jp C,DZERR              ; division by zero

POPF_FPREG_ZERO:                ; zero or underflow
        ld hl,0
        ld de,hl
        jp POPF_FPREG_REJOIN


        ; MEEK I,J where I is signed integer and J is 16 byte blocks
        ; uses  : af, bc, de, hl
        ; (C) feilipu

MEEK:
        CALL    GETNUM          ; Get address
        CALL    DEINT           ; Get integer -32768 to 32767 to DE
        PUSH    DE              ; Save address
        CALL    CHKSYN          ; Make sure ',' follows
        DEFB    ','
        CALL    GETINT          ; Get integer 0-255 in A
        LD      C,A             ; Get blocks (of 16 bytes) to C
        OR      A               ; Check for zero blocks
        EX      (SP),HL         ; Recover address, save code string address
MEEKLP:
        JP      Z,POPHL         ; Return
        CALL    PRNTCRLF        ; New line
        CALL    PRHL            ; Print address
        LD      A,':'           ; Load colon
        CALL    OUTC            ; Output character
        LD      A,' '           ; Load space
        CALL    OUTC            ; Output character
        PUSH    HL              ; Preserve block base address
        LD      B,16            ; 16 byte blocks
MEEKLLP:
        LD      A,' '           ; Load space
        CALL    OUTC            ; Output character
        LD      A,(HL)          ; Read byte at address
        CALL    PRHEX           ; Print byte in HEX
        INC     HL              ; Get next address
        DJNZ    MEEKLLP         ; Do 16 byte blocks

        LD      A,' '           ; Load space
        CALL    OUTC            ; Output character
        LD      A,' '           ; Load space
        CALL    OUTC            ; Output character
        POP     HL              ; Recover block base address
        LD      B,16            ; 16 byte blocks
MEEKASC:
        LD      A,(HL)          ; Read byte at address
        CP      DEL             ; Greater than ASCII DEL?
        JP      NC,MEEKDOT
        CP      ' '             ; Less than ASCII space?
        JP      C,MEEKDOT
        DEFB    11H             ; Skip "LD A,'.'"
MEEKDOT:
        LD      A,'.'           ; Load an ASCII dot
        CALL    OUTC            ; Output ASCII character
        INC     HL              ; Get next address
        DJNZ    MEEKASC         ; Do 16 byte blocks

        DEC     C               ; Decrement block count
        JP      MEEKLP


        ; MOKE I where I is signed integer
        ; uses  : af, de, hl
        ; (C) feilipu

MOKE:
        CALL    GETNUM          ; Get address
        CALL    DEINT           ; Get integer -32768 to 32767
        EX      DE,HL           ; Move address
MOKELP:
        PUSH    HL              ; Save address
        CALL    PRHL            ; Print address in HEX
        LD      A,':'           ; Load colon
        CALL    OUTC            ; Output character
        LD      A,' '           ; Space
        CALL    OUTC            ; Output character
        LD      A,' '           ; Space
        CALL    OUTC            ; Output character
        LD      A,(HL)          ; Read byte at address
        CALL    PRHEX           ; Print byte in HEX
        LD      A,' '           ; Space
        CALL    OUTC            ; Output character
        CALL    PROMPT          ; Output "? ", get input RINPUT
        JP      C,BRKRET        ; CTRLC - break to command line
        CALL    GETCHR          ; Get next character
        JP      Z,MOKESKP       ; CR - skip byte store
        DEC     HL              ; DEC 'cos GETCHR INCs
        CALL    HLHEX           ; Get (HL) HEX into HL
        POP     DE              ; Restore address
        EX      DE,HL
        LD      (HL),E          ; Save byte in address
        INC     HL              ; Next address
        JP      MOKELP          ; Do another address

MOKESKP:
        POP     HL              ; Restore address
        INC     HL              ; Next address
        JP      MOKELP          ; Do another address


        ; To print HEX numbers from HL
        ; uses  : af, hl
        ; (C) feilipu

PRHL:
        LD      A,H             ; Load high byte
        CALL    PRHEX
        LD      A,L             ; Load low byte
PRHEX:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    PRHEXN
        POP     AF
PRHEXN:
        AND     0FH
        ADD     A,90H           ; Standard HEX to ASCII routine
        DAA
        ADC     A,40H
        DAA
        JP      OUTC            ; Output character


        ; To get number in (HL) HEX into HL
        ; uses  : af, de, hl
        ; (C) feilipu

HLHEX:
        EX      DE,HL           ; Move address to DE
        LD      HL,0            ; Zero out the value
        CALL    GETHEX          ; Check the address (DE) for valid hex
        JP      C,HXERR         ; First value wasn't hex, HX error
        JP      HLHEXH          ; Convert first character
HLHEXL:
        CALL    GETHEX          ; Get second and additional characters
        RET     C               ; Exit if not a hex character
HLHEXH:
        ADD     HL,HL           ; Shift 4 bits to the left
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        OR      L               ; Add in D0-D3 into L
        LD      L,A             ; Save new value
        JP      HLHEXL          ; And continue until all hex characters are in HL


        ; Load Intel HEX into program memory.
        ; uses  : af, bc, de, hl
        ; (C) feilipu

HLOAD:
        ret NZ                  ; return if any more on line
        call HLD_WAIT_COLON     ; wait for first colon and address data
        ld hl,(ARREND)          ; start of free memory
        sub hl,bc
        jp NC,OMERR             ; if address is below array end, out of memory
        dec bc                  ; go one Byte lower
        ld hl,(LSTRAM)          ; get last ram address
        sub hl,bc
        jp C,HLD_HIGH_RAM       ; if last ram lower leave it, otherwise
        ld hl,bc
        ld (LSTRAM),hl          ; store new last ram location
        ld hl,-50               ; reserve 50 bytes for string space
        add hl,bc               ; allocate string space
        ld (STRSPC),hl          ; save string space location
HLD_HIGH_RAM:
        inc bc
        ld hl,bc
        ld (USR+1),hl           ; store first address as "USR(x)" location
        jp HLD_READ_DATA        ; now get the first data

HLD_WAIT_COLON:
        rst 10h                 ; Rx byte in A
        cp ':'                  ; wait for ':'
        jp NZ,HLD_WAIT_COLON
        ld e,0                  ; reset E to compute checksum
        call HLD_READ_BYTE      ; read byte count
        ld d,a                  ; store it in D
        call HLD_READ_BYTE      ; read upper byte of address
        ld b,a                  ; store in B
        call HLD_READ_BYTE      ; read lower byte of address
        ld c,a                  ; store in C
        call HLD_READ_BYTE      ; read record type
        dec a                   ; check if record type is 01 (end of file)
        jp Z,HLD_END_LOAD
        inc a                   ; check if record type is 00 (data)
        jp NZ,TMERR             ; if not, type mismatch error
        ret

HLD_READ:
        call HLD_WAIT_COLON     ; wait for the next colon and address data
HLD_READ_DATA:
        call HLD_READ_BYTE
        ld (bc+),a              ; write the byte at the RAM address, increment
        dec d
        jp NZ,HLD_READ_DATA     ; if d non zero, loop to get more data

HLD_READ_CHKSUM:
        call HLD_READ_BYTE      ; read checksum, but we don't need to keep it
        ld a,e                  ; lower byte of E checksum should be 0
        or a
        jp NZ,HXERR             ; non zero, we have an issue
        jp HLD_READ

HLD_END_LOAD:
        call HLD_READ_BYTE      ; read checksum, but we don't need to keep it
        ld a,e                  ; lower byte of E checksum should be 0
        or a
        jp NZ,HXERR             ; non zero, we have an issue
        jp BRKRET               ; return to command line

HLD_READ_BYTE:                  ; returns byte in A, checksum in E
        call HLD_READ_NIBBLE    ; read the first nibble
        rlca                    ; shift it left by 4 bits
        rlca
        rlca
        rlca
        ld l,a                  ; temporarily store the first nibble in L
        call HLD_READ_NIBBLE    ; get the second (low) nibble
        or l                    ; assemble two nibbles into one byte in A
        ld l,a                  ; put assembled byte back into L
        add a,e                 ; add the byte read to E (for checksum)
        ld e,a
        ld a,l
        ret                     ; return the byte read in A (L = char received too)

HLD_READ_NIBBLE:
        rst 10h                 ; Rx byte in A
        sub '0'
        cp 10
        ret C                   ; if A<10 just return
        sub 7                   ; else subtract 'A'-'0' (17) and add 10
        ret

        ; HEX$(nn) Convert signed 16 bit number to Hexadecimal string
        ; (C) Searle

HEX:    CALL    DEINT           ; Get integer -32768 to 32767
        PUSH    BC              ; Save contents of BC
        LD      HL,PBUFF
        LD      A,D             ; Get high order into A
        CP      $0
        JP      Z,HEX2          ; Skip output if both high digits are zero
        CALL    BYT2ASC         ; Convert D to ASCII
        LD      A,B
        CP      '0'
        JP      Z,HEX1          ; Don't store high digit if zero
        LD      (HL),B          ; Store it to PBUFF
        INC     HL              ; Next location
HEX1:   LD      (HL),C          ; Store C to PBUFF+1
        INC     HL              ; Next location
HEX2:   LD      A,E             ; Get lower byte
        CALL    BYT2ASC         ; Convert E to ASCII
        LD      A,D
        CP      $0
        JP      NZ,HEX3         ; If upper byte was not zero then always print lower byte
        LD      A,B
        CP      '0'             ; If high digit of lower byte is zero then don't print
        JP      Z,HEX4
HEX3:   LD      (HL),B          ; to PBUFF+2
        INC     HL              ; Next location
HEX4:   LD      (HL),C          ; to PBUFF+3
        INC     HL              ; PBUFF+4 to zero
        XOR     A               ; Terminating character
        LD      (HL),A          ; Store zero to terminate
        INC     HL              ; Make sure PBUFF is terminated
        LD      (HL),A          ; Store the double zero there
        POP     BC              ; Get BC back
        LD      HL,PBUFF        ; Reset to start of PBUFF
        JP      STR1            ; Convert the PBUFF to a string and return it

BYT2ASC:LD      B,A             ; Save original value
        AND     $0F             ; Strip off upper nybble
        CP      $0A             ; 0-9?
        JP      C,ADD30         ; If A-F, add 7 more
        ADD     A,$07           ; Bring value up to ASCII A-F
ADD30:  ADD     A,$30           ; And make ASCII
        LD      C,A             ; Save converted char to C
        LD      A,B             ; Retrieve original value
        RRCA                    ; and Rotate it right
        RRCA
        RRCA
        RRCA
        AND     $0F             ; Mask off upper nybble
        CP      $0A             ; 0-9? < A hex?
        JP      C,ADD301        ; Skip Add 7
        ADD     A,$07           ; Bring it up to ASCII A-F
ADD301: ADD     A,$30           ; And make it full ASCII
        LD      B,A             ; Store high order byte
        RET

        ; Convert "&nnnn" ASCII HEX to FPREG
        ; Gets a character from (HL) checks for Hexadecimal ASCII numbers "&nnnn"
        ; Char is in A, NC if char is ;<=>?@ A-z, CY is set if 0-9
        ; (C) Searle

HEXTFP: EX      DE,HL           ; Move code string pointer to DE
        LD      HL,0            ; Zero out the value
        CALL    GETHEX          ; Check the number for valid hex
        JP      C,HXERR         ; First value wasn't hex, HX error
        JP      HEXLP1          ; Convert first character
HEXLP:  CALL    GETHEX          ; Get second and additional characters
        JP      C,HEXIT         ; Exit if not a hex character
HEXLP1: ADD     HL,HL           ; Shift 4 bits to the left
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        OR      L               ; Add in D0-D3 into L
        LD      L,A             ; Save new value
        JP      HEXLP           ; And continue until all hex characters are in

GETHEX: INC     DE              ; Next location
        LD      A,(DE)          ; Load character at pointer
        CP      'H'
        JP      Z,GETHEX        ; Skip "H"
        CP      ' '
        JP      Z,GETHEX        ; Skip spaces
        SUB     $30             ; Get absolute value
        RET     C               ; < "0", error
        CP      $0A
        JP      C,NOSUB7        ; Is already in the range 0-9
        SUB     $07             ; Reduce to A-F
        CP      $0A             ; Value should be $0A-$0F at this point
        RET     C               ; CY set if was :            ; < = > ? @
NOSUB7: CP      $10             ; > Greater than "F"?
        CCF
        RET                     ; CY set if it wasn't valid hex

HEXIT:  EX      DE,HL           ; Value into DE, Code string into HL
        LD      A,D             ; Load DE into AC
        LD      C,E             ; For prep to
        PUSH    HL
        CALL    ACPASS          ; ACPASS to set AC as integer into FPREG
        POP     HL
        RET

END:

