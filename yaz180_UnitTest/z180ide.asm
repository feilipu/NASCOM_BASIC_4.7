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

;8255 chip.  Change these to specify where the 8255 is addressed,
;and which of the 8255's ports are connected to which ide signals.
;The first three control which 8255 ports have the control signals,
;upper and lower data bytes.  The last two are mode setting for the
;8255 to configure its ports, which must correspond to the way that
;the first three lines define which ports are connected.
IDE_8255_LSB    .equ    PIOA  ;lower 8 bits
IDE_8255_MSB    .equ    PIOB  ;upper 8 bits
IDE_8255_CTL    .equ    PIOC  ;control lines
IDE_8255_CFG    .equ    PIOCNTL
IDE_8255_RD     .equ    PIOCNTL10   ;IDE_8255_ctl out, IDE_8255_lsb/msb input
IDE_8255_WR     .equ    PIOCNTL00   ;all three ports output

;ide control lines for use with IDE_8255_ctl.  Change these 8
;constants to reflect where each signal of the 8255 each of the
;ide control signals is connected.  All the control signals must
;be on the same port, but these 8 lines let you connect them to
;whichever pins on that port.
IDE_A0_LINE     .equ    $04	    ;direct from 8255 to ide interface
IDE_A1_LINE     .equ    $10	    ;direct from 8255 to ide interface
IDE_A2_LINE     .equ    $40	    ;direct from 8255 to ide interface
IDE_CS0_LINE    .equ    $08	    ;inverter between 8255 and ide interface
IDE_CS1_LINE    .equ    $20	    ;inverter between 8255 and ide interface
IDE_WR_LINE     .equ    $01	    ;inverter between 8255 and ide interface
IDE_RD_LINE     .equ    $02	    ;inverter between 8255 and ide interface
IDE_RST_LINE    .equ    $80	    ;inverter between 8255 and ide interface


;------------------------------------------------------------------------------
; IDE Register Addressing
;

;some symbolic constants for the ide registers, which makes the
;code more readable than always specifying the address pins
IDE_DATA        .equ    IDE_CS0_LINE
IDE_ERROR       .equ    IDE_CS0_LINE + IDE_A0_LINE
IDE_SEC_CNT     .equ    IDE_CS0_LINE + IDE_A1_LINE  ; Typically 1 Sector
IDE_SECTOR      .equ    IDE_CS0_LINE + IDE_A1_LINE + IDE_A0_LINE    ; LBA0
IDE_CYL_LSB     .equ    IDE_CS0_LINE + IDE_A2_LINE                  ; LBA1
IDE_CYL_MSB     .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A0_LINE    ; LBA2
IDE_HEAD        .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE    ; LBA3
IDE_COMMAND     .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE + IDE_A0_LINE
IDE_STATUS      .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE + IDE_A0_LINE
IDE_CONTROL     .equ    IDE_CS1_LINE + IDE_A2_LINE + IDE_A1_LINE
IDE_ALT_STATUS  .equ    IDE_CS1_LINE + IDE_A2_LINE + IDE_A1_LINE + IDE_A0_LINE

IDE_LBA0        .equ    IDE_CS0_LINE + IDE_A1_LINE + IDE_A0_LINE    ; SECTOR
IDE_LBA1        .equ    IDE_CS0_LINE + IDE_A2_LINE                  ; CYL_LSB
IDE_LBA2        .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A0_LINE    ; CYL_MSB
IDE_LBA3        .equ    IDE_CS0_LINE + IDE_A2_LINE + IDE_A1_LINE    ; HEAD

;IDE Command Constants.  These should never change.
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
idelba3    .equ    idelba2+1  ;LBA of desired sector MSB

ide_status  .equ    idelba3+1  ;set bit 0 : User selects master (0) or slave (1) drive
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

    .org	location

begin:
	ld (STACKTOP), sp
	ld	sp, STACKTOP    ;mov	sp, #stack

	ld hl, msg_1        ;mov	dptr, #msg_1	;print a welcome message
	call pstr           ;lcall	pstr

	;reset the drive
	call ide_hard_reset ;acall	ide_hard_reset

	;initialize the drive.  If there is no drive, this may hang
	call ide_init       ;acall	ide_init

	;get the drive id info.  If there is no drive, this may hang
	call drive_id       ;acall	drive_id

	; print the drive's model number
	ld hl msg_mdl       ;mov	dptr, #msg_mdl
	call pstr           ;lcall	pstr
	mov	dptr, #ide_buffer + 54
	mov	r0, #20
	acall	print_name
	lcall	newline

	; print the drive's serial number
	mov	dptr, #msg_sn
	lcall	pstr
	mov	dptr, #ide_buffer + 20
	mov	r0, #10
	acall	print_name
	lcall	newline

	; print the drive's firmware revision string
	mov	dptr, #msg_rev
	lcall	pstr
	mov	dptr, #ide_buffer + 46
	mov	r0, #4
	acall	print_name
	lcall	newline

	; print the drive's cylinder, head, and sector specs
	mov	dptr, #msg_cy
	lcall	pstr
	mov	dptr, #ide_buffer + 2
	acall	print_parm
	mov	dptr, #msg_hd
	lcall	pstr
	mov	dptr, #ide_buffer + 6
	acall	print_parm
	mov	dptr, #msg_sc
	lcall	pstr
	mov	dptr, #ide_buffer + 12
	acall	print_parm
	lcall	newline
	lcall	newline

	; default position will be first block (master boot record)
	clr	a
	mov	lba+0, a
	mov	lba+1, a
	mov	lba+2, a
	mov	lba+3, a


main_loop:				;print a 1-line prompt
	mov	dptr, #msg_l
	lcall	pstr
	mov	a, lba+3
	lcall	phex
	mov	a, lba+2
	lcall	phex
	mov	a, lba+1
	lcall	phex
	mov	a, lba+0
	lcall	phex
	mov	dptr, #msg_pmt
	lcall	pstr
	lcall	cin
	lcall	upper

main1:	cjne	a, #'R', main2		;read a sector
	acall	read_sector
	jz	main1b
	push	acc
	mov	dptr, #msg_err
	lcall	pstr
	pop	acc
	lcall	phex
	lcall	newline
	ajmp	main_loop
main1b:	mov	dptr, #msg_rd
	lcall	pstr
	ajmp	main_loop

main2:	cjne	a, #'W', main3		;write a sector
	mov	dptr, #msg_sure
	lcall	pstr
	lcall	cin
	lcall	upper
	cjne	a, #'Y', main2c
	acall	write_sector
	jz	main2b
	push	acc
	mov	dptr, #msg_err
	lcall	pstr
	pop	acc
	lcall	phex
	lcall	newline
	ajmp	main_loop
main2b:	mov	dptr, #msg_wr
	lcall	pstr
main2c: ajmp	main_loop

main3:	cjne	a, #'L', main4		;set the logical block address
	mov	dptr, #msg_cyh
	lcall	pstr
	lcall	ghex32_lba
	jc	main3b
	mov	lba+0, r3
	mov	lba+1, r4
	mov	lba+2, r5
	mov	lba+3, r6
main3b:	lcall	newline
	ajmp	main_loop

main4:	cjne	a, #'U', main5		;cause the drive to spin up
	acall	spinup
	ajmp	main_loop

main5:	cjne	a, #'D', main6		;cause the drive to spin down
	acall	spindown
	ajmp	main_loop

main6:	cjne	a, #'Q', main7		;quit
	ljmp	0

main7:	cjne	a, #'H', main8
	acall	hexdump
	ajmp	main_loop

main8:	ajmp	main_loop


msg_1:	.db	"IDE Disk Drive Test "
        .db "Program",13,10,13,10,0
msg_mdl:.db	"Model: ",0
msg_sn: .db	"S/N:   ",0
msg_rev:.db	"Rev:   ",0
msg_cy:	.db	"Cylinders: ", 0
msg_hd:	.db	", Heads: ", 0
msg_sc:	.db	", Sectors: ", 0
msg_cyh:.db	"Enter LBA (in hex): ", 0
msg_l:	.db	"LBA=0x",0
msg_pmt:.db	", (R)ead (W)rite (L)BA "
        .db "(U)p (D)own (H)exdump "
        .db "(Q)uit",13,10,0
msg_sure:.db    "Warning: this will "
        .db "change data on the drive, "
        .db "are you sure?",13,10,0
msg_rd:	.db	"Sector Read OK",13,10,0
msg_wr:	.db	"Sector Write OK",13,10,0
msg_err:.db	"Error, code = ",0





;------------------------------------------------------------------
; Routines that talk with the IDE drive, these should be called by
; the main program.


	;read a sector, specified by the 4 bytes in "lba",
	;return zero on success, non-zero for an error
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
	or	a, e
	jr z, gerr2
	ret
gerr2:
    ld a, $FF
	ret

;------------------------------------------------------------------------------

	;do the identify drive command, and return with the ide_buffer
	;filled with info about the drive
drive_id:
	call ide_wait_not_busy
	ld e, %11100000
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
	ld e, IDE_CMD_SPINUP
spup2:
    ld	a, IDE_COMMAND
	call ide_wr_8
	jp ide_wait_not_busy

;------------------------------------------------------------------------------

	;initialize the ide drive
ide_init:
	ld e, %11100000
	ld a, IDE_HEAD
	call ide_wr_8		    ;select the master device, LBA mode
	ld	a, IDE_STATUS
	call ide_rd_8
	ld a, e
	;should probably check for a timeout here
	and %11000000		    ;mask off BUSY and RDY bits
	xor %01000000	        ;wait for BUSY to be clear and RDY to be set
	jr nz, ide_init
	
;   ld e, IDE_CMD_INIT
;   ld a, IDE_COMMAND
;   call ide_wr_8           ;do init parameters command
	ret

;------------------------------------------------------------------------------

    ;by writing to the IDE_CONTROL register, a software reset
    ;can be initiated.
    ;this should usually be followed with a call to "ide_init".
ide_soft_reset:	
	ld e, %00000110		    ;no interrupt, reset drive = 1
	ld a, IDE_CONTROL
	call ide_wr_8
	ld e, %00000010		    ;no interrupt, reset drive = 0
	ld a, IDE_CONTROL	
	call ide_wr_8
	jp ide_wait_busy_ready

;------------------------------------------------------------------------------

	;do a hard reset on the drive, by pulsing its reset pin.
	;do this first, and if a soft reset doesn't work.
	;this should usually be followed with a call to "ide_init".
ide_hard_reset:
	ld bc, IDE_8255_CFG
	ld a, IDE_8255_RD
	out (c), a              ;config 8255 chip, read mode
	ld bc, IDE_8255_CTL
	ld a, IDE_RST_LINE
	out (c),a               ;hard reset the disk drive
	ld bc, $0
ide_rst_dly:
    djnz ide_rst_dly
    dec c
	jr nz, ide_rst_dly      ;delay (reset pulse width)
    ld bc, IDE_8255_CTL
	xor a
	out (c),a               ;no ide control lines asserted
	ret

;----------------------------------------------------------------------------

ide_test_error:
	scf			            ;carry set = all OK
	ld a, IDE_STATUS        ;select status register
	call ide_rd_8           ;get status in A
	bit 0,a			        ;test error bit
	ret z
	
	bit 5,a
	jr nz, ide_err		    ;test write error bit
	
	ld a, IDE_ERROR         ;select error register
	call ide_rd_8           ;get error register in A
ide_err:
	or a			        ;make carry flag zero = error!
	ret			            ;if a = 0, ide busy timed out

;------------------------------------------------------------------
; Not quite as low, low level I/O.  These routines talk to the drive,
; using the low level I/O.  Normally a main program should not call
; directly to these.

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
	and %00001111		    ;lowest 4 bits used only
	or  %11100000		    ;to enable lba mode
	call ide_drive_select	;set bit 4 accordingly
	ld e, a
	ld a, IDE_LBA3
	jp ide_wr_8	            ;set lba 24:27 + bits 5:7=111

;------------------------------------------------------------------------------

ide_drive_select:
	push hl
	ld hl, ide_status
	bit 0,(hl)
	jr z, ide_master
	or $10
ide_master:
	pop hl
	ret

;------------------------------------------------------------------------------

ide_wait_not_busy:
	ld a, IDE_STATUS		;wait for BUSY bit to be clear
	call ide_rd_8
	ld a, e
	;should probably check for a timeout here
	tst %10000000		    ;test BUSY bit
	jr nz, ide_wait_not_busy
	ret

ide_wait_ready:
	ld a, IDE_STATUS		;wait for RDY bit to be set
	call ide_rd_8
	ld a, e
	;should probably check for a timeout here
	and %11000000		    ;mask off BUSY and RDY bits
	xor %01000000	        ;wait for BUSY to be clear and RDY to be set
	jr nz, ide_wait_ready
	ld	a, e
	ret

	;Wait for the drive to be ready to transfer data.
	;Returns the drive's status in A
ide_wait_drq:
	ld a, IDE_STATUS		;wait for DRQ bit to be set
	call ide_rd_8
	ld a, e
	;should probably check for a timeout here
	and %10001000		    ;mask off BUSY and DRQ bits
	xor %00001000	        ;wait for BUSY to be clear and DRQ to be set
	jr nz, ide_wait_drq
	ld	a, e
	ret

;------------------------------------------------------------------------------
; Low Level I/O to the drive.  These are the routines that talk
; directly to the drive, via the 8255 chip. 

	;Do a read bus cycle to the drive, using the 8255.
	;input a = ide register address
	;output e = lower byte read from ide drive
	;output d = upper byte read from ide drive
	;bc is changed
ide_rd_16:
	ld bc, IDE_8255_CTL
	out (c), a              ;drive address onto control lines,
	or a, IDE_RD_LINE	
	out (c), a              ;and assert read pin
	ld bc, IDE_8255_MSB
	in d, (c),	            ;read the upper byte
	ld bc, IDE_8255_LSB
	in e, (c),	            ;read the lower byte
	ld bc, IDE_8255_CTL
	xor	a
	out (c), a		        ;deassert all control pins
	ret

ide_rd_8:
	ld bc, IDE_8255_CTL
	out (c), a              ;drive address onto control lines,
	or a, IDE_RD_LINE	
	out (c), a              ;and assert read pin
	ld bc, IDE_8255_LSB
	in e, (c),	            ;read the lower byte
	ld bc, IDE_8255_CTL
	xor	a
	out (c), a		        ;deassert all control pins
	ret

	;Do a write bus cycle to the drive, via the 8255
	;input a = ide register address
	;input e = lsb to write
	;input d = msb to write
	;bc is changed
ide_wr_16:
	ld r, a                 ;address in r
	ld bc, IDE_8255_CFG
	ld a, IDE_8255_WR
	out (c), a              ;config 8255 chip, write mode
	ld bc, IDE_8255_LSB
	out (c), e	            ;drive lower lines with lsb
	ld bc, IDE_8255_MSB
	out (c), d	            ;drive upper lines with msb
	ld bc, IDE_8255_CTL
	ld a, r
	out (c), a              ;drive address onto control lines,
	or	a, IDE_WR_LINE	
	out (c), a              ;and assert write pin
	nop
	nop
	ld	a, r
	out (c), a              ;deassert write pin
	xor	a
	out (c), a		        ;deassert all control pins
	ld bc, IDE_8255_CFG
	ld a, IDE_8255_RD
	out (c), a              ;config 8255 chip, read mode
	ret

ide_wr_8:
	ld r, a                 ;address in r
	ld bc, IDE_8255_CFG
	ld a, IDE_8255_WR
	out (c), a              ;config 8255 chip, write mode
	ld bc, IDE_8255_LSB
	out (c), e	            ;drive lower lines with lsb
	ld bc, IDE_8255_CTL
	ld a, r
	out (c), a              ;drive address onto control lines,
	or a, IDE_WR_LINE	
	out (c), a              ;and assert write pin
	nop
	nop
	ld	a, r
	out (c), a              ;deassert write pin
	xor	a
	out (c), a		        ;deassert all control pins
	ld bc, IDE_8255_CFG
	ld a, IDE_8255_RD
	out (c), a              ;config 8255 chip, read mode
	ret

    .end



