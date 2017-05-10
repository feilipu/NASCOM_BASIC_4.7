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

; Simple communication with an IDE disk drive
; see http://www.pjrc.com/tech/8051/ide/ for more info

; Modified, January 2005:
;   - Update for rev 4/5 8051 development board
;   - Fix hold time bug when writing to some drives
;   - Improve reporting of drive's model/serial/revision
;   - Added (commented out) status output while waiting for drive
;   - Other minor cleanup

;  This code is an original work by Paul Stoffregen, written
;  in December 1999 (modified 2005).  This code has been placed
;  in the ;  public domain.  You may use it without any restrictions.
;  You may include it in your own projects, even commercial
;  (for profit) products.

;  This code is distributed in the hope that they will be useful,
;  but without any warranty; without even the implied warranty of
;  merchantability or fitness for a particular purpose.

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
DEINT       .EQU    $0C47   ; Function DEINT to get USR(x) into DE registers
ABPASS      .EQU    $13BD   ; Function ABPASS to put output into AB register

;==============================================================================
;
; CODE SECTION
;

.equ	location, 0x2100	;where this program will exist
.equ	buffer, 0x3000		;a 512 byte buffer

;------------------------------------------------------------------
; Hardware Configuration

;8255 chip.  Change these to specify where the 8255 is addressed,
;and which of the 8255's ports are connected to which ide signals.
;The first three control which 8255 ports have the control signals,
;upper and lower data bytes.  The last two are mode setting for the
;8255 to configure its ports, which must correspond to the way that
;the first three lines define which ports are connected.
.equ	ide_8255_lsb, 0xF800	;lower 8 bits
.equ	ide_8255_msb, 0xF801	;upper 8 bits
.equ	ide_8255_ctl, 0xF802	;control lines
.equ	cfg_8255, 0xF803
.equ	rd_ide_8255, 10010010b	;ide_8255_ctl out, ide_8255_lsb/msb input
.equ	wr_ide_8255, 10000000b	;all three ports output

;ide control lines for use with ide_8255_ctl.  Change these 8
;constants to reflect where each signal of the 8255 each of the
;ide control signals is connected.  All the control signals must
;be on the same port, but these 8 lines let you connect them to
;whichever pins on that port.
.equ	ide_a0_line, 0x01	;direct from 8255 to ide interface
.equ	ide_a1_line, 0x02	;direct from 8255 to ide interface
.equ	ide_a2_line, 0x04	;direct from 8255 to ide interface
.equ	ide_cs0_line, 0x08	;inverter between 8255 and ide interface
.equ	ide_cs1_line, 0x10	;inverter between 8255 and ide interface
.equ	ide_wr_line, 0x20	;inverter between 8255 and ide interface
.equ	ide_rd_line, 0x40	;inverter between 8255 and ide interface
.equ	ide_rst_line, 0x80	;inverter between 8255 and ide interface


;------------------------------------------------------------------
; More symbolic constants... these should not be changed, unless of
; course the IDE drive interface changes, perhaps when drives get
; to 128G and the PC industry will do yet another kludge.

;some symbolic constants for the ide registers, which makes the
;code more readable than always specifying the address pins
.equ	ide_data,	ide_cs0_line
.equ	ide_err,	ide_cs0_line + ide_a0_line
.equ	ide_sec_cnt,	ide_cs0_line + ide_a1_line
.equ	ide_sector,	ide_cs0_line + ide_a1_line + ide_a0_line
.equ	ide_cyl_lsb,	ide_cs0_line + ide_a2_line
.equ	ide_cyl_msb,	ide_cs0_line + ide_a2_line + ide_a0_line
.equ	ide_head,	ide_cs0_line + ide_a2_line + ide_a1_line
.equ	ide_command,	ide_cs0_line + ide_a2_line + ide_a1_line + ide_a0_line
.equ	ide_status,	ide_cs0_line + ide_a2_line + ide_a1_line + ide_a0_line
.equ	ide_control,	ide_cs1_line + ide_a2_line + ide_a1_line
.equ	ide_astatus,	ide_cs1_line + ide_a2_line + ide_a1_line + ide_a0_line

;IDE Command Constants.  These should never change.
.equ	ide_cmd_recal, 0x10
.equ	ide_cmd_read, 0x20
.equ	ide_cmd_write, 0x30
.equ	ide_cmd_init, 0x91
.equ	ide_cmd_id, 0xEC
.equ	ide_cmd_spindown, 0xE0
.equ	ide_cmd_spinup, 0xE1


;------------------------------------------------------------------
;internal ram usage

.equ	lba, 0x10		;4 bytes, 28 bit Logical Block Address
.equ	stack, 0x40



;routines within paulmon2.  To make this code stand-alone, just copy
;and paste these bits of code from the paulmon2.asm file.

.equ    cout, 0x0030            ;Send Acc to serial port
.equ    cin, 0x0032             ;Get Acc from serial port
.equ    phex, 0x0034            ;Print Hex value of Acc
.equ    pstr, 0x0038            ;Print string pointed to by DPTR,
.equ    upper, 0x0040           ;Convert Acc to uppercase
.equ    newline, 0x0048         ;print CR/LF (13 and 10)
.equ    pint8u, 0x004D          ;print Acc at an integer, 0 to 255
.equ    pint16u, 0x0053         ;print DPTR as an integer, 0 to 65535
.equ    cin_filter, 0x0062      ;get a character, but look for esc sequences


;------------------------------------------------------------------
; Main Program, a simple menu driven interface.


.org	location
.db     0xA5,0xE5,0xE0,0xA5     ;signiture bytes
.db     35,255,0,0              ;id, 35=program
.db     0,0,0,0                 ;reserved
.db     0,0,0,0                 ;reserved
.db     0,0,0,0                 ;reserved
.db     0,0,0,0                 ;reserved
.db     0,0,0,0                 ;user defined
.db     255,255,255,255         ;length and checksum (255=unused)
.db     "IDE Disk Drive Test",0
.org    location+64             ;executable code begins here


begin:
	mov	sp, #stack
	mov	dptr, #msg_1	;print a welcome message
	lcall	pstr

	;reset the drive
	acall	ide_hard_reset

	;initialize the drive.  If there is no drive, this may hang
	acall	ide_init

	;get the drive id info.  If there is no drive, this may hang
	acall	drive_id

	; print the drive's model number
	mov	dptr, #msg_mdl
	lcall	pstr
	mov	dptr, #buffer + 54
	mov	r0, #20
	acall	print_name
	lcall	newline

	; print the drive's serial number
	mov	dptr, #msg_sn
	lcall	pstr
	mov	dptr, #buffer + 20
	mov	r0, #10
	acall	print_name
	lcall	newline

	; print the drive's firmware revision string
	mov	dptr, #msg_rev
	lcall	pstr
	mov	dptr, #buffer + 46
	mov	r0, #4
	acall	print_name
	lcall	newline

	; print the drive's cylinder, head, and sector specs
	mov	dptr, #msg_cy
	lcall	pstr
	mov	dptr, #buffer + 2
	acall	print_parm
	mov	dptr, #msg_hd
	lcall	pstr
	mov	dptr, #buffer + 6
	acall	print_parm
	mov	dptr, #msg_sc
	lcall	pstr
	mov	dptr, #buffer + 12
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


msg_1:	.db	"IDE Disk Drive Test Program",13,10,13,10,0
msg_mdl:.db	"Model: ",0
msg_sn: .db	"S/N:   ",0
msg_rev:.db	"Rev:   ",0
msg_cy:	.db	"Cylinders: ", 0
msg_hd:	.db	", Heads: ", 0
msg_sc:	.db	", Sectors: ", 0
msg_cyh:.db	"Enter LBA (in hex): ", 0
msg_l:	.db	"LBA=0x",0
msg_pmt:.db	", (R)ead (W)rite (L)BA (U)p (D)own (H)exdump (Q)uit",13,10,0
msg_sure:.db	"Warning: this will change data on the drive, are you sure?",13,10,0

msg_rd:	.db	"Sector Read OK",13,10,0
msg_wr:	.db	"Sector Write OK",13,10,0
msg_err:.db	"Error, code = ",0





;------------------------------------------------------------------
; Routines that talk with the IDE drive, these should be called by
; the main program.


	;read a sector, specified by the 4 bytes in "lba",
	;Return, acc is zero on success, non-zero for an error
read_sector:
	acall	ide_wait_not_busy	;make sure drive is ready
	acall	wr_lba			;tell it which sector we want
	mov	a, #ide_command
	mov	r2, #ide_cmd_read
	acall	ide_wr_8		;ask the drive to read it
	acall	ide_wait_drq		;wait until it's got the data
	jb	acc.0, get_err
	mov	dptr, #buffer
	acall	read_data		;grab the data
	clr	a
	ret


	;when an error occurs, we get acc.0 set from a call to ide_drq
	;or ide_wait_not_busy (which read the drive's status register).  If
	;that error bit is set, we should jump here to read the drive's
	;explaination of the error, to be returned to the user.  If for
	;some reason the error code is zero (shouldn't happen), we'll
	;return 255, so that the main program can always depend on a
	;return of zero to indicate success.
get_err:mov	a, #ide_err
	acall	ide_rd_8
	mov	a, r2
	jz	gerr2
	ret
gerr2:	mov	a, #255
	ret


	;write a sector, specified by the 4 bytes in "lba",
	;whatever is in the buffer gets written to the drive!
	;Return, acc is zero on success, non-zero for an error
write_sector:
	acall	ide_wait_not_busy	;make sure drive is ready
	acall	wr_lba			;tell it which sector we want
	mov	a, #ide_command
	mov	r2, #ide_cmd_write
	acall	ide_wr_8		;tell drive to write a sector
	acall	ide_wait_drq		;wait unit it wants the data
	jb	acc.0, get_err
	mov	dptr, #buffer
	acall	write_data		;give the data to the drive
	acall	ide_wait_not_busy	;wait until the write is complete
	jb	acc.0, get_err
	clr	a
	ret



	;do the identify drive command, and return with the buffer
	;filled with info about the drive
drive_id:
	acall	ide_wait_not_busy
	mov	a, #ide_head
	mov	r2, #10100000b
	acall	ide_wr_8		;select the master device
	acall	ide_wait_ready
	mov	a, #ide_command
	mov	r2, #0xEC
	acall	ide_wr_8		;issue the command
	acall	ide_wait_drq
	mov	dptr, #buffer
	acall	read_data
	ret










	;tell the drive to spin up
spinup:
	mov	r2, #ide_cmd_spinup
spup2:	mov	a, #ide_command
	acall	ide_wr_8
	acall	ide_wait_not_busy
	ret


	;tell the drive to spin down
spindown:
	acall	ide_wait_not_busy
	mov	r2, #ide_cmd_spindown
	sjmp	spup2



	;initialize the ide drive
ide_init:
	mov	a, #ide_head
	mov	r3, #0
	mov	r2, #10100000b
	acall	ide_wr_8		;select the master device
	mov	a, #ide_status
	acall	ide_rd_8
	 ; uncomment these if the code hangs, waiting forever for
	 ; the drive to respond.  This will at least let you see
	 ; where it's waiting, and the value of the status register
	 ;mov	a, #'*'
	 ;lcall	cout
	 ;mov	a, r2
	 ;lcall	phex
	mov	a, r2
	;should probably check for a timeout here
	jnb	acc.6, ide_init		;wait for RDY bit to be set
	jb	acc.7, ide_init		;wait for BSY bit to be clear

	; uncomment this section if you have a very old hard drive
	; (probably win3.1 or early win95 era) that does not even
	; allow LBA accesses until these CHS parameters are set up
	;mov	a, #ide_head
	;mov	r2, #10101111b
	;acall	ide_wr_8		;what should this config parm be?
	;mov	a, #ide_sec_cnt
	;mov	r2, #64
	;acall	ide_wr_8		;what should this config parm be?
	;mov	a, #ide_command
	;mov	r2, #ide_cmd_init
	;acall	ide_wr_8		;do init parameters command
	;acall	ide_wait_not_busy
	;mov	a, #ide_command
	ret



; IDE Status Register:
;  bit 7: Busy	1=busy, 0=not busy
;  bit 6: Ready 1=ready for command, 0=not ready yet
;  bit 5: DF	1=fault occured inside drive
;  bit 4: DSC	1=seek complete
;  bit 3: DRQ	1=data request ready, 0=not ready to xfer yet
;  bit 2: CORR	1=correctable error occured
;  bit 1: IDX	vendor specific
;  bit 0: ERR	1=error occured


;------------------------------------------------------------------
; Not quite as low, low level I/O.  These routines talk to the drive,
; using the low level I/O.  Normally a main program should not call
; directly to these.

	;Read a block of 512 bytes (one sector) from the drive
	;and store it in memory @ DPTR
read_data:
	mov	r5, #0
rdblk2: push	dph
	push	dpl
	mov	a, #ide_data
	acall	ide_rd_16
	pop	dpl
	pop	dph
	mov	a, r2
	movx	@dptr, a
	inc	dptr
	mov	a, r3
	movx	@dptr, a
	inc	dptr
	djnz	r5, rdblk2
	ret


	;Write a block of 512 bytes (at DPTR) to the drive
write_data:
	mov	r5, #0
wrblk2: 
	movx	a, @dptr
	mov	r2, a
	inc	dptr
	movx	a, @dptr
	mov	r3, a
	inc	dptr
	push	dph
	push	dpl
	mov	a, #ide_data
	acall	ide_wr_16
	pop	dpl
	pop	dph
	djnz	r5, wrblk2
	ret


	;write the logical block address to the drive's registers
wr_lba:
	mov	a, lba+3
	anl	a, #0x0F
	orl	a, #0xE0
	mov	r2, a
	mov	a, #ide_head
	acall	ide_wr_8
	mov	a, #ide_cyl_msb
	mov	r2, lba+2
	acall	ide_wr_8
	mov	a, #ide_cyl_lsb
	mov	r2, lba+1
	acall	ide_wr_8
	mov	a, #ide_sector
	mov	r2, lba+0
	acall	ide_wr_8
	mov	a, #ide_sec_cnt
	mov	r2, #1
	acall	ide_wr_8
	ret



ide_wait_not_busy:
	mov	a, #ide_status		;wait for RDY bit to be set
	acall	ide_rd_8
	 ; uncomment these if the code hangs, waiting forever for
	 ; the drive to respond.  This will at least let you see
	 ; where it's waiting, and the value of the status register
	 ;mov	a, #'.'
	 ;lcall	cout
	 ;mov	a, r2
	 ;lcall	phex
	mov	a, r2
	;should probably check for a timeout here
	jb	acc.7, ide_wait_not_busy
	ret


ide_wait_ready:
	mov	a, #ide_status		;wait for RDY bit to be set
	acall	ide_rd_8
	 ; uncomment these if the code hangs, waiting forever for
	 ; the drive to respond.  This will at least let you see
	 ; where it's waiting, and the value of the status register
	 ;mov	a, #','
	 ;lcall	cout
	 ;mov	a, r2
	 ;lcall	phex
	mov	a, r2
	;should probably check for a timeout here
	jnb	acc.6, ide_wait_ready
	jb	acc.7, ide_wait_ready
	ret




	;Wait for the drive to be ready to transfer data.
	;Returns the drive's status in Acc
ide_wait_drq:
	mov	a, #ide_status		;wait for DRQ bit to be set
	acall	ide_rd_8
	 ; uncomment these if the code hangs, waiting forever for
	 ; the drive to respond.  This will at least let you see
	 ; where it's waiting, and the value of the status register
	 ;mov	a, #'_'
	 ;lcall	cout
	 ;mov	a, r2
	 ;lcall	phex
	mov	a, r2
	;should probably check for a timeout here
	jb	acc.7, ide_wait_drq	;wait for BSY to be clear
	jnb	acc.3, ide_wait_drq	;wait for DRQ to be set
	ret


;------------------------------------------------------------------
; Low Level I/O to the drive.  These are the routines that talk
; directly to the drive, via the 8255 chip.  Normally a main
; program would not call to these.

	;Do a read bus cycle to the drive, using the 8255.
	;input acc = ide regsiter address
	;output r2 = lower byte read from ide drive
	;output r3 = upper byte read from ide drive
	;dptr is changed
ide_rd_16:
	mov	dptr, #ide_8255_ctl
	movx	@dptr, a		;drive address onto control lines
	orl	a, #ide_rd_line	
	movx	@dptr, a		;assert read pin
	mov	dptr, #ide_8255_msb
	movx	a, @dptr		;read the upper byte
	mov	r3, a
	mov	dptr, #ide_8255_lsb
	movx	a, @dptr		;read the lower byte
	mov	r2, a
	mov	dptr, #ide_8255_ctl
	clr	a
	movx	@dptr, a		;deassert all control pins
	ret

ide_rd_8:
	mov	dptr, #ide_8255_ctl
	movx	@dptr, a		;drive address onto control lines
	orl	a, #ide_rd_line	
	movx	@dptr, a		;assert read pin
	mov	dptr, #ide_8255_lsb
	movx	a, @dptr		;read the lower byte
	mov	r2, a
	mov	dptr, #ide_8255_ctl
	clr	a
	movx	@dptr, a		;deassert all control pins
	ret



	;Do a write bus cycle to the drive, via the 8255
	;input acc = ide register address
	;input r2 = lsb to write
	;input r3 = msb to write
	;dptr is changed
ide_wr_16:
	mov	r4, a			;address in r4
	mov	dptr, #cfg_8255
	mov	a, #wr_ide_8255
	movx	@dptr, a		;config 8255 chip, write mode
	mov	dptr, #ide_8255_lsb
	mov	a, r2
	movx	@dptr, a		;drive lower lines with lsb (r2)
	mov	dptr, #ide_8255_msb
	mov	a, r3
	movx	@dptr, a		;drive upper lines with msb (r3)
	mov	dptr, #ide_8255_ctl
	mov	a, r4
	movx	@dptr, a		;drive address onto control lines
	orl	a, #ide_wr_line	
	movx	@dptr, a		;assert write pin
	nop
	mov	a, r4
	movx	@dptr, a		;deassert write pin
	mov	dptr, #cfg_8255
	mov	a, #rd_ide_8255
	movx	@dptr, a		;config 8255 chip, read mode
	ret

ide_wr_8:
	mov	r4, a			;address in r4
	mov	dptr, #cfg_8255
	mov	a, #wr_ide_8255
	movx	@dptr, a		;config 8255 chip, write mode
	mov	dptr, #ide_8255_lsb
	mov	a, r2
	movx	@dptr, a		;drive lower lines with lsb (r2)
	mov	dptr, #ide_8255_ctl
	mov	a, r4
	movx	@dptr, a		;drive address onto control lines
	orl	a, #ide_wr_line	
	movx	@dptr, a		;assert write pin
	nop
	mov	a, r4
	movx	@dptr, a		;deassert write pin
	mov	dptr, #cfg_8255
	mov	a, #rd_ide_8255
	movx	@dptr, a		;config 8255 chip, read mode
	ret




	;do a hard reset on the drive, by pulsing its reset pin.
	;this should usually be followed with a call to "ide_init".
ide_hard_reset:
	mov	dptr, #cfg_8255
	mov	a, #rd_ide_8255
	movx	@dptr, a		;config 8255 chip, read mode
	mov	dptr, #ide_8255_ctl
	mov	a, #ide_rst_line
	movx	@dptr, a		;hard reset the disk drive
	mov	r2, #40
	mov	r3, #0
rst_dly:djnz	r3, rst_dly
	djnz	r2, rst_dly		;delay (reset pulse width)
	clr	a
	movx	@dptr, a		;no ide control lines asserted
	ret




;------------------------------------------------------------------
; Some additional serial I/O routines not available in PAULMON


	;print a 16 bit number, located at DPTR
print_parm:
	movx	a, @dptr
	push	acc
	inc	dptr
	movx	a, @dptr
	mov	dph, a
	pop	dpl
	ljmp	pint16u


	;print a string, no more than R0 words long
	;the IDE string are byte swapped.  Fetch each
	;word and swap so the names print correctly
print_name:
	movx	a, @dptr
	mov	r2, a
	inc	dptr
	movx	a, @dptr
	inc	dptr
	jz	pn_end
	lcall	cout
	mov	a, r2
	jz	pn_end
	lcall	cout
	djnz	r0, print_name
pn_end:	ret



	;get a 32 bit input, in hex
ghex32_lba:
	mov	r2, #8
	mov	r3, #0
	mov	r4, #0
	mov	r5, #0
	mov	r6, #0
gh32c:	lcall	cin_filter
	lcall	upper
	cjne	a, #27, gh32d
	setb	c
	ret
gh32d:	cjne	a, #8, gh32f
	sjmp	gh32k
gh32f:	cjne	a, #127, gh32g
gh32k:	cjne	r2, #8, gh32e
	sjmp	gh32c
gh32e:	lcall	cout
	mov	r0, #4
gh32yy:	clr	c
	mov	a, r6
	rrc	a
	mov	r6, a
	mov	a, r5
	rrc	a
	mov	r5, a
	mov	a, r4
	rrc	a
	mov	r4, a
	mov	a, r3
	rrc	a
	mov	r3, a
	djnz	r0, gh32yy
	inc	r2
	sjmp	gh32c
gh32g:	cjne	a, #13, gh32i
	clr	c
	ret
gh32i: 	mov	r7, a
	acall	asc2hex
	jc	gh32c
	xch	a, r7
	lcall	cout
	mov	a, r7
	swap	a
	mov	r7, a
	mov	r0, #4
gh32j:	mov	a, r7
	rlc	a
	mov	r7, a
	mov	a, r3
	rlc	a
	mov	r3, a
	mov	a, r4
	rlc	a
	mov	r4, a
	mov	a, r5
	rlc	a
	mov	r5, a
	mov	a, r6
	rlc	a
	mov	r6, a
	djnz	r0, gh32j
	djnz	r2, gh32c
	clr	c
	ret



        ;carry set if invalid input
asc2hex:
        clr     c
        add     a, #208
        jnc     hex_not
        add     a, #246
        jc      hex_maybe
        add     a, #10
        clr     c
        ret
hex_maybe:
        add     a, #249
        jnc     hex_not
        add     a, #250
        jc      hex_not
        add     a, #16
        clr     c
        ret
hex_not:setb    c
        ret


	;print a hexdump of the data in the 512 byte buffer
hexdump:
	lcall	newline
	mov	r2, #32		;print 32 lines
	mov	dptr, #buffer
hd1:	mov	a, dph
	mov	r5, a
	clr	c
	subb	a, #buffer >> 8
	lcall	phex		;print address, starting at zero
	mov	a, dpl
	mov	r4, a
	lcall	phex
	mov	a, #':'
	lcall	cout
	acall	space
	mov	r3, #16		;print 16 hex bytes per line
hd2:	movx	a, @dptr
	inc	dptr
	lcall	phex		;print each byte in hex
	acall	space
	djnz	r3, hd2
	acall	space
	acall	space
	acall	space
	mov	dpl, r4
	mov	dph, r5
	mov	r3, #16		;print 16 ascii bytes per line
hd3:	movx	a, @dptr
	inc	dptr
	anl	a, #01111111b	;only 7 bits for ascii
	cjne	a, #127, hd3b
	clr	a		;avoid 127/255 (delete/rubout) char
hd3b:	add	a, #224
	jc	hd3c
	clr	a		;avoid control characters
hd3c:	add	a, #32
	lcall	cout
	djnz	r3, hd3
	lcall	newline
	djnz	r2, hd1
	lcall	newline
	ret

space:	mov	a, #' '
	ljmp	cout







