# Microsoft (NASCOM) Basic for RC2014

This repository provides a number of alternative Microsoft (NASCOM) Basic implementations specifically for variants of the RC2014 Mini, Micro, and Classic retro-computers.

Support is provided for the following hardware options.

 - RC2014 __Mini__, __Micro__, and __Classic__ versions, with 32k of RAM.
 - RC2014 Classic and Plus using 56kB of RAM (with the __64kB RAM Module__).
 - RC2014 Mini, Micro, and Classic using the __Am9511A APU Module__.
 - RC2014 Classic and Plus using the __8085 CPU Module__.
 - RC2014 Classic and Plus using the __8085 CPU Module__ and the __Am9511A APU Module__.

 - RC2014 Classic and Plus using the __Single UART Module__ or the __Dual UART Module__.

The code is originally derived from the NASCOM implementation of Microsoft Basic 4.7, and was adapted for the [Simple Z80](http://searle.x10host.com/z80/SimpleZ80.html) by Grant Searle. Further adaptions here have focused on bug fixes, and functional and performance improvements.

The key differences over previous implementations include.

 - The serial interface is configured for 115200 baud with 8n2 setting and __`/RTS`__ hardware handshake.
 - A serial and memory sanity self check is undertaken on startup, to ensure that I/O and RAM are available and are working.
 - ACIA 68B50 interrupt driven serial I/O supporting the hardware double buffer, together with a large receive buffer of 255 bytes, to allow efficient pasting of Basic into the editor. The receive __`/RTS`__ handshake shows full before the buffer is totally filled to allow run-on from the sender.
 - ACIA 68B50 interrupt driven serial transmission, with a 63 byte buffer, to ensure the CPU is not held waiting during transmission.
 - UART 16C550 interrupt driven serial I/O. Full input and output buffering with receive __`/RTS`__ and transmit __`/CTS`__ hardware handshaking. The handshake shows full 16 bytes before the buffer is totally filled, to allow run-on from the sender. The receive software buffer is 255 bytes and the transmit hardware buffer is 16 bytes.
 - A `RST`, `INT0`, and `NMI` RAM redirection jump table, starting in RAM at `0x8000`, enables the important RST instructions and interrupt vectors to be reconfigured by the user.
 - These ROMs provides both an Intel HEX `HLOAD` statement and software `RESET` statement. This allows you to easily upload Z80 (or 8085) assembly or compiled C programs, and then run them as described. The `HLOAD` statement automatically adjusts the upper RAM limit for Basic and enters the program origin into the `USRLOC` location.
 - Added `MEEK` and `MOKE` statements allow bulk memory to be examined in 16 byte blocks, and support continuous editing (assembly language entry) of memory. Addresses and values can be entered as signed decimal integers, or as hexadecimal numbers using the `&` keyword.
 - The standard `WIDTH` command has been extended to support setting the comma column screen width using `WIDTH I,J` where `I` is the screen width and `J` is the comma column screen width.
 - CPU optimised instruction and code flow tuning result in faster execution.
 - Support for the Am9511A APU Module provides a 3x to 5x faster execution of uploaded assembly or C floating point programs, together with faster execution of BASIC programs.

### RC2014 Mini, Micro, Classic: 32kB MS Basic

This ROM works with the Mini, Micro, and Classic versions of the RC2014, with 32k of RAM.

This is the ROM to choose if you want fast I/O from a standard RC2014, together with the capability to upload and run C or assembly programs from within MS Basic. This ROM provides both the `HLOAD`, `RESET`, `MEEK`, `MOKE` statements, and a `RST`, `INT0`, and `NMI` RAM Jump Table, starting at `0x8000`. This allows you to upload Assembly or compiled C programs, and then run them as described. Please enable __`/RTS`__ flow control to avoid received character loss.

### RC2014 Plus: 56kB MS Basic using __64kB RAM Module__

This version works with the Classic or Plus version of the RC2014 running with a [64k/56k RAM Module](https://rc2014.co.uk/modules/64k-ram/). The 56k version utilises the full 56k memory space of the RC2014, with RAM starting at `0x2000`.

### RC2014 Mini, Micro, Classic: 32kB MS Basic using __Am9511A APU Module__

This ROM works with the Mini, Micro, and Classic versions of the RC2014, with 32k of RAM, if you have installed an [Am9511A APU Module](https://www.tindie.com/products/feilipu/am9511a-apu-module-pcb/).

### RC2014 Classic: 32kB MS Basic using __8085 CPU Module__

This ROM works with the Classic or Plus version of the RC2014, with 32k of RAM,  running with an 8085 CPU Module. This is the ROM to choose if you have installed an [8085 CPU Module](https://www.tindie.com/products/feilipu/8085-cpu-module-pcb/).

### RC2014 Classic: 32kB MS Basic using __8085 CPU Module__ and __Am9511A APU Module__

This version works with the Classic or Plus version of the RC2014, with 32k of RAM, running with an 8085 CPU Module and an Am9511A APU Module. This is the ROM to choose if you have installed both an [8085 CPU Module](https://www.tindie.com/products/feilipu/8085-cpu-module-pcb/) and an [Am9511A APU Module](https://www.tindie.com/products/feilipu/am9511a-apu-module-pcb/).

### RC2014 Classic: 32kB MS Basic using __Single UART Module__ or __Dual UART Module__

This version works with the Classic or Plus version of the RC2014, with 32k of RAM, running with a Single or Dual UART Module for the serial interface. Please enable __`/RTS`__ flow control to avoid received character loss. If equipped with a Dual UART Module, the B channel can be used to upload both BASIC and Intel HEX programs, or to even to connect an additional keyboard. Characters will be output on the A channel as normal.

---

# Assembly (or compiled C) Program Usage

Please refer to [Appendix D of the NASCOM 2 Basic Manual](https://github.com/feilipu/NASCOM_BASIC_4.7/blob/master/NASCOM_Basic_Manual.pdf) for information on loading and running Assembly Language programs.

## Using `MEEK` and `MOKE` for assembly entry

The `MEEK I,J` and `MOKE I` statements can be used to hand edit assembly programs, where `I` is the address of interest as a signed integer, and `J` is the number of 16 byte blocks to display. `MOKE` byte entry can be skipped with carriage return, and is exited with `CTRL C`.

Address entry can also be converted from HEX to signed integer using the `&` HEX prefix, i.e. in `MOKE &9000` `0x9000` is converted to `−28672` which is simpler than calculating this signed 16 bit integer by hand, and `MEEK &9000,&10` will tabulate and print 16 blocks of 16 bytes of memory from memory address `0x9000`.

Once the assembly program is entered using `MOKE`, the origin address of the user assembly program needs to be manually entered into the `USRLOC` address `0x8204` using the `DOKE`. Then the program can be run using the BASIC `PRINT USR(0)` or `? USR(0)` commands.

### Usage Example

<a href="https://raw.githubusercontent.com/feilipu/NASCOM_BASIC_4.7/master/HexLoadr-v1.0.png" target="_blank"><img src="https://raw.githubusercontent.com/feilipu/NASCOM_BASIC_4.7/master/HexLoadr-v1.0.png"/></a>

## Using Zen assembler for entering assembly programs

There are several [Intel HEX versions of the Zen assembler](https://github.com/feilipu/NASCOM_BASIC_4.7/tree/master/rc2014_Zen) with different origins prepared to use from within RC2014 MS BASIC. Use the `HLOAD` keyword to load your choice of HEX file based on how much RAM you wish to leave available for BASIC, and launch Zen with `? USR(0)`. Exit back to MS BASIC with `Q`.

Use the Zen `ORG` and `LOAD` keywords to place assembled programs above the Zen End of File Pointer `EOFP`. Use Zen `H` command to determine where `EOFP` is located. The Zen `ORG` keyword should indicate where program will eventually be located, usually at the default of `0x9000`. On return to BASIC, assembled programs can be launched using the `? USR(0)` command either from immediate mode, or from within a BASIC program as a subroutine, after setting the correct `USRLOC` location for the assembly program's `ORG` using `DOKE`, if the program is being run with Zen in situ. Or use the Zen `X` command to save (write) the assembled program to the serial port in Intel HEX format, and then reload it with the MS Basic `HLOAD` and run normally using the `? USR(0)` command.

## Using `HLOAD` for uploading compiled and assembled programs.

1. Select the preferred origin `.ORG` for your arbitrary program, and assemble a HEX file using your preferred assembler, or compile a C program [using z88dk](https://github.com/RC2014Z80/RC2014/wiki/Using-Z88DK). For RC2014 32kB systems suitable origins commence from `0x8400`, and the default origin for z88dk RC2014 is `0x9000`.

2. At the BASIC interpreter type `HLOAD`, then the command will initiate and look for your program's Intel HEX formatted information on the serial interface.

3. Using a serial terminal, upload the HEX file for your arbitrary program that you prepared in Step 1, using the Linux `cat` utility or similar. If desired the python `slowprint.py` program can also be used for this purpose. `python slowprint.py > /dev/ttyUSB0 < myprogram.hex` or `cat > /dev/ttyUSB0 < myprogram.hex`. The RC2014 interface can absorb full rate uploads, and flow control is enabled, so using `slowprint.py` is an unnecessary precaution.

4. Once the final line of the HEX code is read into memory, `HLOAD` will return to NASCOM Basic with `ok`.

5. Start your program by typing `PRINT USR(0)`, or `? USR(0)`, or other variant if you have an input parameter to pass to your program.

The `HLOAD` program can be exited without uploading a valid file by typing `:` followed by `CR CR CR CR CR CR`, or any other character.

The top of BASIC memory can be readjusted by using the `RESET` statement, when required. `RESET` is functionally equivalent to a cold start.

# Important Addresses

There are a number of important Z80 addresses or origins that can be adjusted and managed if you are writing an assembly  or C program.

## RST locations

For convenience, because we can't easily change the ROM code interrupt routines already present in the RC2014, the ACIA serial Tx and Rx routines are reachable by calling `RST` instructions from your program.

* Tx: `RST 08H` expects a byte to transmit in the `a` register.
* Rx: `RST 10H` returns a received byte in the `a` register, and will block (loop) until it has a byte to return.
* Rx Check: `RST 18H` will immediately return the number of bytes in the Rx buffer (0 if buffer empty) in the `a` register.
* ACIA Interrupt: `RST 38H` is used by the ACIA 68B50 Serial Device (8085 CPU Module systems use IRQ 6.5).

All `RST xxH` targets can be rewritten in a `JP` table originating at `0x8000` in RAM. This allows the use of debugging tools and reorganising the efficient `RST` call instructions as needed.

## USR Jump Address & Parameter Access

The NASCOM Basic Manual Appendix D describes the use of the `USR(x)` function to call assembly (or compiled C) programs directly from the Basic command line or from within a Basic program. Please refer to the Manual Appendix D for further information on mixing Basic and Assembly code.

For the RC2014 with 32k Basic the location for the `USRLOC` user program address is `0x8204`, and with 56k Basic the location for `USRLOC` is `0x2204`.

## Workflow Notes

Note that your program and the `USRLOC` jump address setting will remain in place through a RC2014 Warm Reset, provided you prevent Basic from initialising the RAM locations you have used. Also, you can reload your assembly program to the same RAM location through multiple Warm Resets, without issuing a `RESET` statement.

Any Basic programs loaded will also remain in place during a Warm Reset.

Issuing the `RESET` statement will clear the RC2014 RAM, and return the original memory contents equivalent to a cold start.

The standard `WIDTH` statement has been extended to support setting the comma column screen width using `WIDTH I,J` where `I` is the screen width, and `J` is the comma column screen width.

# Modifications to MS Basic

MS Basic uses 4 byte values extensively as floating point numbers in [Microsoft Binary Format](https://en.wikipedia.org/wiki/Microsoft_Binary_Format), and as pointers to strings. Many of the improvements are in handling these values as they are shifted around in memory, and to `BCDE` registers and the stack.

- 4 `LDI` instructions are used to move values from one location (the Floating Point Register `FPREG`) to another location in memory, and these are in-lined to also save the call-return cycles.
- The `LD (x),DE` `LD(x+2),BC` instruction pair is used to grab values into registers and save from registers, avoiding the need to preserve `HL` and often saving push-pop cycles and of course the call-return cycles.
- There is a 16_16x16 multiply `MLDEBC` used to calculate table offsets, which was optimised to use shift instructions available to the Z80. I experimented with different zero multiplier checks, and with removing the checks, but Microsoft had already done the right optimisation there, so it was left as it was.
- The extensions that Grant Searle had inserted into the operand evaluation chain to check for Hex and Binary numbers were moved to the end of the operand checks, so as not to slow down the normal operand or function evaluation. Code flow for Hex support was simplified and more fully integrated.

Doing these changes achieved about 6% improvement in the benchmarks.

The next step was to use the [`z88dk-ticks`](https://github.com/z88dk/z88dk/wiki/Tool---ticks) tool to evaluate hotspots and try to remediate them. Using the debug mode it is possible to capture exactly how many iterations (visits) and how many cycles are consumed by each instruction.

The testing revealed that the comparison function `CPDEHL` was very heavily used. As it is quite small, and through removing the call-return overhead, it adds only a few bytes per instance to in-line it. There is plenty of space in the 8kB ROM to allow this change so it was made.

Then, the paths taken by the `JR` and `JP` conditional instructions were examined, by checking which path was taken most frequently across the benchmarks. This resulted in changing a few `JR` instructions for `JP` instructions, when the conditional path was mostly true, and one replacement of a `JP` instruction where the conditional was most often false.

Looking further at `z88dk-ticks` hotspot results, the next most used function is `GETCHR` used to collect input from code strings. `GETCHR` is a larger function and is used about 50 times throughout the code base, so there is little point to in-line it. However I do note the new `JR` conditional is used in checking for spaces in token strings, which does save a few cycles. Microsoft warns in the Nascom Basic Manual to optimise performance by removing spaces in code. Now it is even more true than before.

As the Z80 and 8085 have better shift instructions than the 8080, these instructions have been used where possible. Specifically for the 8085 the `rl de` and the `sra hl` undocumented instructions have been used where appropriate.

So with these changes we are now at 12% improvement over the original Microsoft code.

__EDIT__ the `CPDEHL` inline optimisation was reverted to provide space to add the `MEEK` and `MOKE` statements, so we're back to 9% improvement.

So at this point I'll call it done. It seems that without rewriting the code substantially that's about all that I can squeeze out. The result is that with no change in function, MS Basic for Z80 is now simply 9% faster.

---

# YAZ180 (deprecated, see [yabios](https://github.com/feilipu/yaz180/tree/master/yabios))

ASCI0 interrupt driven serial I/O to run modified NASCOM Basic 4.7.

If you're using the YAZ180 with 32kB Nascom Basic, then all of the RAM between `0x3000` and `0x7FFF` is available for your assembly programs, without limitation. In the YAZ180 the area between `0x2000` and `0x2FFF` is reserved for system calls, buffers, and stack space. For the RC2014 the area from `0x8000` is reserved for these uses.

In the YAZ180 32kB Basic, the area from `0x4000` to `0x7FFF` is the Banked memory area, and this RAM can be managed by the HexLoadr program to write to all of the physical RAM space using ESA Records.

HexLoadr supports the Extended Segment Address Record Type, and will store the MSB of the ESA in the Z180 BBR Register. The LSB of the ESA is silently abandoned. When HexLoadr terminates the BBR is returned to the original value.

Two versions of initialisation routines NASCOM Basic are provided.

## 56k Basic with integrated HexLoadr

The 56k version utilises the full 56k RAM memory space of the YAZ180, starting at `0x2000`.

Full input and output ASCI0 buffering. Transmit and receive are interrupt driven.

Receive buffer is 255 bytes, to allow efficient pasting of Basic into the editor.
Receive buffer overflows are silently discarded.

Transmit buffer is 255 bytes, because the YAZ180 is 36.864MHz CPU.
Transmit function busy waits when buffer is full. No Tx characters lost.

## 32k Basic with integrated HexLoadr

The 32k version uses the CA0 space for buffers and the CA1 space for Basic.
This leaves the Bank RAM / Flash space in `0x4000` to `0x7FFF` available for other usage.

The rationale is to allow in-circuit programming, and an exit to another system.
An integrated HexLoadr program is provided for this purpose.

Full input and output ASCI0 buffering. Transmit and receive are interrupt driven.

Receive buffer is 255 bytes, to allow efficient pasting of Basic into the editor.
Receive buffer overflows are silently discarded.

Transmit buffer is 255 bytes, because the YAZ180 is 36.864MHz CPU.
Transmit function busy waits when buffer is full. No Tx characters lost.

https://feilipu.me/2016/05/23/another-z80-project/

---

# Credits

Derived from the work of @fbergama and @foxweb at RC2014.

https://github.com/RC2014Z80/RC2014/blob/master/ROMs/hexload/hexload.asm

# Copyright

NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft

Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3 (May-June 1983) to Vol 3, Issue 3 (May-June 1984).

Adapted for the freeware Zilog Macro Assembler 2.10 to produce the original ROM code (checksum A934H). PA

http://www.nascomhomepage.com/

---

The HEX number handling updates to the original BASIC within this file are copyright (C) Grant Searle

You have permission to use this for NON COMMERCIAL USE ONLY.
If you wish to use it elsewhere, please include an acknowledgement to myself.

http://searle.wales/

---

The UART and ACIA drivers and rework to support MS Basic MEEK, MOKE, HLOAD, RESET, and the 8085 and Z80 instruction tuning are copyright (C) 2020-25 Phillip Stevens.

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.

@feilipu, March 2025

