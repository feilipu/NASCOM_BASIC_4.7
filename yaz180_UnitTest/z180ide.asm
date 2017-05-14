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

;routines within paulmon2.  To make this code stand-alone, just copy
;and paste these bits of code from the pmon21.asm file.

;cout    .equ    $0030           ;Send Acc to serial port
;cin     .equ    $0032           ;Get Acc from serial port
;phex    .equ    $0034           ;Print Hex value of Acc
;pstr    .equ    $0038           ;Print string pointed to by DPTR,
;upper   .equ    $0040           ;Convert Acc to uppercase
;newline .equ    $0048           ;print CR/LF (13 and 10)
;pint8u  .equ    $004D           ;print Acc at an integer, 0 to 255
;pint16u .equ    $0053           ;print DPTR as an integer, 0 to 65535
;cin_filter  .equ    $0062       ;get a character, but look for esc sequences

;==============================================================================
;
; INCLUDES SECTION
;

#include    "d:/yaz180.h"

;==============================================================================
;
; DEFINES SECTION
;

;   from Nascom Basic Symbol Tables .ORIG $0390
DEINT       .EQU    $0C47       ; Function DEINT to get USR(x) into DE registers
ABPASS      .EQU    $13BD       ; Function ABPASS to put output into AB register

program     .equ    $4000       ; Where this program will exist
location    .equ    $3000       ; Where this driver will exist

;------------------------------------------------------------------
;
; IDE reg: A0-A2: /CS0: /CS1: Use:
;
;       $0	000    0    1     IDE Data Port
;       $1	001    0    1     Read: Error code (also see $$)
;       $2	010    0    1     Number Of Sectors To Transfer
;       $3	011    0    1     Sector address LBA 0 (0:7)
;       $4	100    0    1     Sector address LBA 1 (8:15)
;       $5	101    0    1     Sector address LBA 2 (16:23)
;       $6	110    0    1     Head Register, Sector address LBA 3 (24:27) (also see **)
;       $7	111    0    1     Read: "Status", Write: Issue command (also see ##)
;       $8	000    1    0     Not Important
;       $9	001    1    0     Not Important
;       $A	010    1    0     Not Important
;       $B	011    1    0     Not Important
;       $C	100    1    0     Not Important
;       $D	101    1    0     Not Important
;       $E	110    1    0     2nd Status, Interrupt, and Reset
;       $F	111    1    0     Active Status Register 
;
;       $$ Bits in Error Register $1
;
;       Bit 7   = BBLK  Bad Block Detected
;       Bit 6   = UNC   Uncorrectable Error
;       Bit 5   = IDNF  Selector Id
;       Bit 4   = MCR   Media Change requested
;       Bit 3   = ABRT  Indecent Command - Doh!
;       Bit 2   = TK0NF Track 0 unavailable -> Trash
;       Bit 1   = AMNF  Address mark not found

;       ** Bits in LBA 3 Register $6:
;
;       Bit 7   = Always set to 1
;       Bit 6   = Always Set to 1 for LBA Mode Access
;       Bit 5   = Always set to 1
;       Bit 4   = Select Master (0) or Slave (1) drive
;       Bit 0:3 = LBA bits (24:27)
;
;       ## Bits in Command / Status Register $7:
;
;       Bit 7   = BUSY	1=busy, 0=not busy
;       Bit 6   = RDY   1=ready for command, 0=not ready yet
;       Bit 5   = WFT	1=fault occured inside drive
;       Bit 4   = SKC	1=seek complete
;       Bit 3   = DRQ	1=data request ready, 0=not ready to xfer yet
;       Bit 2   = ECC	1=correctable error occured
;       Bit 1   = IDX	vendor specific
;       Bit 0   = ERR	1=error occured

;------------------------------------------------------------------
; Hardware Configuration

; 8255 PIO chip.  Change these to specify where the PIO is addressed,
; and which of the 8255's ports are connected to which ide signals.
; The first three control which 8255 ports have the control signals,
; upper and lower data bytes.  The last two are mode setting for the
; 8255 to configure its ports, which must correspond to the way that
; the first three lines define which ports are connected.
PIO_IDE_LSB     .equ    PIOA        ;IDE lower 8 bits
PIO_IDE_MSB     .equ    PIOB        ;IDE upper 8 bits
PIO_IDE_CTL     .equ    PIOC        ;IDE control lines
PIO_IDE_CFG     .equ    PIOCNTL     ;PIO configuration
PIO_IDE_RD      .equ    PIOCNTL10   ;PIO_IDE_CTL out, PIO_IDE_LSB/MSB input
PIO_IDE_WR      .equ    PIOCNTL00   ;all PIO ports output

; IDE control lines for use with PIO_IDE_CTL. Change these 8
; constants to reflect where each signal of the 8255 each of the
; IDE control signals is connected.  All the control signals must
; be on the same port, but these 8 lines let you connect them to
; whichever pins on that port.
IDE_A0_LINE     .equ    $04	    ;direct from 8255 to ide interface
IDE_A1_LINE     .equ    $10	    ;direct from 8255 to ide interface
IDE_A2_LINE     .equ    $40	    ;direct from 8255 to ide interface
IDE_CS0_LINE    .equ    $08	    ;inverter between 8255 and ide interface
IDE_CS1_LINE    .equ    $20	    ;inverter between 8255 and ide interface
IDE_WR_LINE     .equ    $01	    ;inverter between 8255 and ide interface
IDE_RD_LINE     .equ    $02	    ;inverter between 8255 and ide interface
IDE_RST_LINE    .equ    $80	    ;inverter between 8255 and ide interface


;------------------------------------------------------------------------------
; IDE I/O Register Addressing
;

; IDE control lines for use with PIO_IDE_CTL. Symbolic constants
; for the IDE registers, which makes the code more readable than
; always specifying the address pins
IDE_DATA        .equ    IDE_CS0_LINE
IDE_ERROR       .equ    IDE_CS0_LINE + IDE_A0_LINE
IDE_SEC_CNT     .equ    IDE_CS0_LINE + IDE_A1_LINE  ;Typically 1 Sector only
IDE_SECTOR      .equ    IDE_CS0_LINE + IDE_A1_LINE + IDE_A0_LINE    ;LBA0
IDE_CYL_LSB     .equ    IDE_CS0_LINE + IDE_A2_LINE                  ;LBA1
IDE_CYL_MSB     .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A0_LINE    ;LBA2
IDE_HEAD        .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE    ;LBA3
IDE_COMMAND     .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE + IDE_A0_LINE
IDE_STATUS      .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE + IDE_A0_LINE
IDE_CONTROL     .equ    IDE_CS1_LINE + IDE_A2_LINE + IDE_A1_LINE
IDE_ALT_STATUS  .equ    IDE_CS1_LINE + IDE_A2_LINE + IDE_A1_LINE + IDE_A0_LINE

IDE_LBA0        .equ    IDE_CS0_LINE + IDE_A1_LINE + IDE_A0_LINE    ;SECTOR
IDE_LBA1        .equ    IDE_CS0_LINE + IDE_A2_LINE                  ;CYL_LSB
IDE_LBA2        .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A0_LINE    ;CYL_MSB
IDE_LBA3        .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE    ;HEAD

; IDE Command Constants.  These should never change.
IDE_CMD_RECAL       .equ    $10 ;recalibrate the disk, wait for ready status
IDE_CMD_READ        .equ    $20 ;read with retry - $21 read no retry
IDE_CMD_WRITE       .equ    $30 ;write with retry - $31 write no retry
IDE_CMD_INIT        .equ    $91 ;initialize drive parameters
IDE_CMD_ID          .equ    $EC ;identify drive
IDE_CMD_SPINDOWN    .equ    $E0 ;immediate spindown of disk
IDE_CMD_SPINUP      .equ    $E1 ;immediate spinup of disk
IDE_CMD_POWERDOWN   .equ    $E2 ;auto powerdown - sector count 5 sec units

;==============================================================================
;
; VARIABLES SECTION
;

;LBA of desired sector LSB
idelba0    .equ    Z180_VECTOR_BASE+Z180_VECTOR_SIZE+$30
idelba1    .equ    idelba0+1
idelba2    .equ    idelba1+1
idelba3    .equ    idelba2+1    ;LBA of desired sector MSB

idestatus  .equ    idelba3+1   ;set bit 0 : User selects master (0) or slave (1) drive
                                ;bit 1 : Flag 0 = master not previously accessed 
                                ;bit 2 : Flag 0 = slave not previously accessed

;a 512 byte sector buffer origin
ide_buffer  .equ    APUPTRBuf+APU_PTR_BUFSIZE+1

;==============================================================================
;
; CODE SECTION
;

;------------------------------------------------------------------
; Main Program, a simple menu driven interface.

    .org	program

begin:
	ld (STACKTOP), sp
	ld	sp, STACKTOP

	ld hl, msg_1        ;print a welcome message
	call pstr 

	;reset the drive
	call ide_hard_reset

	;initialize the drive.  If there is no drive, this may hang
	call ide_init

	;get the drive id info.  If there is no drive, this may hang
	call drive_id

	;print the drive's model number
	ld hl, msg_mdl
	call pstr
	ld hl, ide_buffer + 54
	ld b, 20
	call print_name
	call newline

	;print the drive's serial number
	ld hl, msg_sn
	call pstr
	ld hl, ide_buffer + 20
	ld b, 10
	call print_name
	call newline

	;print the drive's firmware revision string
	ld hl, msg_rev
	call pstr
	ld hl, ide_buffer + 46
	ld b, 4
	call print_name
	call newline

	;print the drive's cylinder, head, and sector specs
	ld hl, msg_cy
	call pstr
	ld hl, ide_buffer + 2
	call phex16
	ld hl, msg_hd
	call	pstr
	ld hl, ide_buffer + 6
	call phex16
	ld hl, msg_sc
	call pstr
	ld hl, ide_buffer + 12
	call phex16
	call	newline
	call	newline

	;default position will be first block (master boot record)
	xor	a
	ld	(idelba0), a
	ld	(idelba1), a
	ld	(idelba2), a
	ld	(idelba3), a

	;cause the drive to spin down
	call	spindown
    ret


msg_1:	.db	"IDE Disk Drive Test "
        .db "Program",13,10,13,10,0
msg_mdl:.db	"Model: ",0
msg_sn: .db	"S/N:   ",0
msg_rev:.db	"Rev:   ",0
msg_cy:	.db	"Cylinders: ", 0
msg_hd:	.db	", Heads: ", 0
msg_sc:	.db	", Sectors: ", 0

;------------------------------------------------------------------
; Extra routines


print_name:
    ld      A,(HL)          ; Get a byte
    or      A               ; Is it null $00 ?
    ret     Z               ; Then RETurn on terminator
    rst     08              ; Print it
    inc     HL              ; Next byte
	djnz	print_name      ; Continue until $00
    ret

pstr:
    ld      A,(HL)          ; Get a byte
    or      A               ; Is it null $00 ?
    ret     Z               ; Then RETurn on terminator
    rst     08              ; Print it
    inc     HL              ; Next byte
    jr      pstr

newline:
    rst     08
    ld      A, CR
    rst     08
    ld      A, LF
    rst     08
    ret

phex16:
	push af
	ld a, h
    call phex
	ld a, l
	call phex
	pop	af
	ret

phex:
    push af             ;store the binary value
    rlca                ;shift accumulator left by 4 bits
    rlca
    rlca
    rlca
    and	$0F             ;now high nibble is low position
    cp 10
    jr c, phex_b        ;jump if high nibble < 10
    add	a, 7            ;otherwise add 7 before adding '0'
phex_b:
    add a, '0'          ;add ASCII 0 to make a character
    rst 08              ;print high nibble
    pop af              ;recover the binary value
phex1:
    and	$0F
    cp 10
    jr c, phex_c        ;jump if low nibble < 10
    add	a, 7
phex_c:
    add	a, '0'
    rst 08              ;print low nibble
    ret

;------------------------------------------------------------------
; Routines that talk with the IDE drive, these should be called by
; the main program.

    .org	location

	;read a sector, specified by the 4 bytes in "lba",
	;return zero on success, non-zero for an error
	;call should be modifed to have the LBA & buffer to fill in IX or IY - FIXME
read_sector:
	call ide_wait_not_busy  ;make sure drive is ready
	call ide_setup_lba      ;tell it which sector we want
	ld a, IDE_COMMAND
	ld e, IDE_CMD_READ
	call ide_wr_8           ;ask the drive to read it
	call ide_wait_drq       ;wait until it's got the data
	and $01
	jr nz, get_err
	ld hl, ide_buffer       ;put the data in the 
	call ide_read_data		;grab the data
	xor	a
	ret

	;write a sector, specified by the 4 bytes in "lba",
	;whatever is in the ide_buffer gets written to the drive!
	;Return, acc is zero on success, non-zero for an error
	;call should be modifed to have the LBA & buffer to fill in IX or IY - FIXME
write_sector:
	call ide_wait_not_busy  ;make sure drive is ready
	call ide_setup_lba      ;tell it which sector we want
	ld a, IDE_COMMAND
	ld e, IDE_CMD_WRITE
	call ide_wr_8           ;tell drive to write a sector
	call ide_wait_drq       ;wait unit it wants the data
	and $01
	jr nz, get_err
	ld hl, ide_buffer
	call ide_write_data         ;give the data to the drive
	call ide_wait_not_busy  ;wait until the write is complete
	and $01
	jr nz, get_err
	xor	a
	ret

	;when an error occurs, we get acc.0 set from a call to ide_drq
	;or ide_wait_not_busy (which read the drive's status register).  If
	;that error bit is set, we should jump here to read the drive's
	;explaination of the error, to be returned to the user.  If for
	;some reason the error code is zero (shouldn't happen), we'll
	;return 255, so that the main program can always depend on a
	;return of zero to indicate success, non-zero for an error
get_err:
    ld a, IDE_ERROR
	call ide_rd_8
	xor a
	or e
	jr z, gerr2
	ret
gerr2:
    ld a, $FF
	ret

;------------------------------------------------------------------------------

	;do the identify drive command, and return with the ide_buffer
	;filled with info about the drive.
	;call should be modifed to have the buffer to fill in HL - FIXME
drive_id:
	call ide_wait_not_busy
	ld e, 11100000b
	ld a, IDE_HEAD
    call ide_wr_8		    ;select the master device, LBA mode
	call ide_wait_ready
	ld e, IDE_CMD_ID	
	ld a, IDE_COMMAND
	call ide_wr_8		    ;issue the command
	call ide_wait_drq
	ld hl, ide_buffer
	jp ide_read_data      ;store the data in ide_buffer

;------------------------------------------------------------------------------

	;tell the drive to spin down
spindown:
	call ide_wait_not_busy
	ld e, IDE_CMD_SPINDOWN
	jr spup2

	;tell the drive to spin up
spinup:
	call ide_wait_not_busy
	ld e, IDE_CMD_SPINUP
spup2:
    ld	a, IDE_COMMAND
	call ide_wr_8
	jp ide_wait_not_busy

;------------------------------------------------------------------------------

	;initialize the ide drive
ide_init:
	ld e, 11100000b
	ld a, IDE_HEAD
	call ide_wr_8		    ;select the master device, LBA mode
	
;   ld e, IDE_CMD_INIT
;   ld a, IDE_COMMAND
;   call ide_wr_8           ;do init parameters command
	jp ide_wait_ready

;------------------------------------------------------------------------------

    ;by writing to the IDE_CONTROL register, a software reset
    ;can be initiated.
    ;this should be followed with a call to "ide_init".
ide_soft_reset:
	ld bc, PIO_IDE_CFG
	ld a, PIO_IDE_RD
	out (c), a              ;config 8255 chip, read mode
	ld e, 00000110b         ;no interrupt, reset drive = 1
	ld a, IDE_CONTROL
	call ide_wr_8
	ld e, 00000010b	        ;no interrupt, reset drive = 0
	ld a, IDE_CONTROL	
	call ide_wr_8
	jp ide_wait_ready

;------------------------------------------------------------------------------

	;do a hard reset on the drive, by pulsing its reset pin.
	;do this first, and if a soft reset doesn't work.
	;this should be followed with a call to "ide_init".
ide_hard_reset:
	ld bc, PIO_IDE_CFG
	ld a, PIO_IDE_RD
	out (c), a              ;config 8255 chip, read mode
	ld bc, PIO_IDE_CTL
	ld a, IDE_RST_LINE
	out (c),a               ;hard reset the disk drive
	ld bc, $0
ide_rst_dly:
    djnz ide_rst_dly
    dec c
	jr nz, ide_rst_dly      ;delay 256x256 nop (reset pulse width)
    ld bc, PIO_IDE_CTL
	xor a
	out (c),a               ;no ide control lines asserted
	ret

;----------------------------------------------------------------------------

    ;load the IDE status register and if there is an error noted,
    ;then load the IDE error register to provide details.
ide_test_error:
	scf			            ;carry set = all OK
	ld a, IDE_STATUS        ;select status register
	call ide_rd_8           ;get status in A
	bit 0, a                ;test error bit
	ret z
	
	bit 5, a
	jr nz, ide_err          ;test write error bit
	
	ld a, IDE_ERROR         ;select error register
	call ide_rd_8           ;get error register in A
ide_err:
	or a                    ;make carry flag zero = error!
	ret                     ;if a = 0, ide busy timed out

;------------------------------------------------------------------
; Mid level I/O.  These routines talk to the drive,
; using the low level I/O.
; Normally a program should not call these directly.

	;Read a block of 512 bytes (one sector) from the drive
	;and store it in memory at (HL)
ide_read_data:
	ld b, $0
ide_rdblk2:
    push bc
	ld a, IDE_DATA
	call ide_rd_16
	pop	bc
	ld (hl), e
	inc hl
	ld (hl), d
	inc	hl
	djnz ide_rdblk2
	ret


	;Write a block of 512 bytes from (HL) to the drive
ide_write_data:
	ld b, $0
ide_wrblk2: 
	ld e, (hl)
	inc	hl
	ld d, (hl)
	inc hl
	push bc
	ld a, IDE_DATA
	call ide_wr_16
	pop	bc
	djnz ide_wrblk2
	ret

;-----------------------------------------------------------------------------

ide_setup_lba:
	ld e,1
    ld a, IDE_SEC_CNT	
	call ide_wr_8	        ;set sector count to 1
	ld hl, idelba0
	ld e, (hl)
	ld a, IDE_LBA0
	call ide_wr_8	        ;set LBA0 0:7
	inc hl
	ld e, (hl)
	ld a, IDE_LBA1
	call ide_wr_8	        ;set LBA1 8:15
	inc hl
	ld e, (hl)
	ld a, IDE_LBA2
	call ide_wr_8	        ;set LBA2 16:23
	inc hl
	ld a,(hl)
	and 00001111b           ;lowest 4 bits used only
	or 11100000b            ;to enable LBA address mode
	call ide_drive_select	;set bit 4 accordingly
	ld e, a
	ld a, IDE_LBA3
	jp ide_wr_8	            ;set LBA3 24:27 + bits 5:7=111

;------------------------------------------------------------------------------

ide_drive_select:
	push hl
	ld hl, idestatus
	bit 0,(hl)
	jr z, ide_master
	or $10
ide_master:
	pop hl
	ret

;------------------------------------------------------------------------------
; Low Level Status - Busy Wait

ide_wait_not_busy:
	ld a, IDE_STATUS		;get IDE status register
	call ide_rd_8
	ld a, e
	;should probably check for a timeout here
	and 10000000b		    ;wait for BUSY bit to be clear
	jr nz, ide_wait_not_busy
	ld	a, e
	ret

ide_wait_ready:
	ld a, IDE_STATUS		;get IDE status register
	call ide_rd_8
	ld a, e
	;should probably check for a timeout here
	and 11000000b		    ;mask off BUSY and RDY bits
	xor 01000000b	        ;wait for RDY to be set and BUSY to be clear 
	jr nz, ide_wait_ready
	ld	a, e
	ret

	;Wait for the drive to be ready to transfer data.
	;Returns the drive's status in A
ide_wait_drq:
	ld a, IDE_STATUS		;get IDE status register
	call ide_rd_8
	ld a, e
	;should probably check for a timeout here
	and 10001000b		    ;mask off BUSY and DRQ bits
	xor 00001000b	        ;wait for DRQ to be set and BUSY to be clear
	jr nz, ide_wait_drq
	ld	a, e
	ret

;------------------------------------------------------------------------------
; Low Level I/O
; These routines talk directly to the drive, via the 8255 chip.

	;Do a read bus cycle to the drive, using the 8255.
	;input a = ide register address
	;output e = lower byte read from IDE drive
	;output d = upper byte read from IDE drive
	;bc is changed
ide_rd_16:
	ld bc, PIO_IDE_CTL
	out (c), a              ;drive address onto control lines,
	or IDE_RD_LINE	
	out (c), a              ;and assert read pin
	ld bc, PIO_IDE_MSB
	in d, (c)	            ;read the upper byte
	ld bc, PIO_IDE_LSB
	in e, (c)	            ;read the lower byte
	ld bc, PIO_IDE_CTL
	xor	a
	out (c), a		        ;deassert all control pins
	ret

ide_rd_8:
	ld bc, PIO_IDE_CTL
	out (c), a              ;drive address onto control lines,
	or IDE_RD_LINE	
	out (c), a              ;and assert read pin
	ld bc, PIO_IDE_LSB
	in e, (c)	            ;read the lower byte
	ld bc, PIO_IDE_CTL
	xor	a
	out (c), a		        ;deassert all control pins
	ret

	;Do a write bus cycle to the drive, via the 8255
	;input a = ide register address
	;input e = lsb to write to IDE drive
	;input d = msb to write to IDE drive
	;bc is changed
ide_wr_16:
	ld r, a                 ;copy address to r
	ld bc, PIO_IDE_CFG
	ld a, PIO_IDE_WR
	out (c), a              ;config 8255 chip, write mode
	ld bc, PIO_IDE_LSB
	out (c), e	            ;drive lower lines with lsb
	ld bc, PIO_IDE_MSB
	out (c), d	            ;drive upper lines with msb
	ld bc, PIO_IDE_CTL
	ld a, r
	out (c), a              ;drive address onto control lines,
	or IDE_WR_LINE	
	out (c), a              ;and assert write pin
	nop
	nop
	ld	a, r
	out (c), a              ;deassert write pin
;	xor	a
;	out (c), a		        ;deassert all control pins
	ld bc, PIO_IDE_CFG
	ld a, PIO_IDE_RD
	out (c), a              ;config 8255 chip, read mode
	ret

ide_wr_8:
	ld r, a                 ;copy address to r
	ld bc, PIO_IDE_CFG
	ld a, PIO_IDE_WR
	out (c), a              ;config 8255 chip, write mode
	ld bc, PIO_IDE_LSB
	out (c), e	            ;drive lower lines with lsb
	ld bc, PIO_IDE_CTL
	ld a, r
	out (c), a              ;drive address onto control lines,
	or IDE_WR_LINE	
	out (c), a              ;and assert write pin
	nop
	nop
	ld	a, r
	out (c), a              ;deassert write pin
;	xor	a
;	out (c), a		        ;deassert all control pins
	ld bc, PIO_IDE_CFG
	ld a, PIO_IDE_RD
	out (c), a              ;config 8255 chip, read mode
	ret

    .end



