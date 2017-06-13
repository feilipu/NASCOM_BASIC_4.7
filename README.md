# NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft

Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3 (May-June 1983) to Vol 3, Issue 3 (May-June 1984).

Adapted for the freeware Zilog Macro Assembler 2.10 to produce the original ROM code (checksum A934H). PA

http://www.nascomhomepage.com/

==============================================================================

The updates to the original BASIC within this file are copyright Grant Searle.

You have permission to use this for NON COMMERCIAL USE ONLY
If you wish to use it elsewhere, please include an acknowledgement to myself.

http://searle.hostei.com/grant/index.html

If the above don't work, please perform an Internet search to see if I have updated the web page hosting service.

==============================================================================

# RC2014

ACIA 6850 interrupt driven serial I/O to run modified NASCOM Basic 4.7.

Full input and output buffering with incoming data hardware handshaking.
Handshake shows full before the buffer is totally filled to allow run-on from the sender.
Transmit and receive are interrupt driven, and are fast.

Receive buffer is 255 bytes, to allow efficient pasting of Basic into the editor.
Transmit buffer is 15 bytes, because the RC2014 is too slow to fill the buffer.
Receive buffer overflows are silently discarded.

Two versions of initialisation routines for NASCOM Basic are provided.

# 56k Basic

Provides the maximum Basic program space, and requires a 64k/56k RAM module.
The 56k version utilises the full 56k RAM memory space of the RC2014, starting at `0x2000`.

No non-Basic programming features are provided, however a `RST`, `INT0`,
and `NMI` JumP Table is provided.

```bash
SBC - Grant Searle
ACIA - feilipu

Cold or Warm start (C|W) ? C

Memory top? 
Z80 BASIC Ver 4.7b
Copyright (C) 1978 by Microsoft
56483 Bytes free

Ok
```


# 32k Basic with integrated HexLoadr

This ROM works with the most basic default version of the RC2014, with 32k of RAM.
This is the ROM to choose if you want fast I/O from a standard RC2014.

```bash
SBC - Grant Searle
ACIA - feilipu

Cold or Warm start, or HexLoadr (C|W|H) ? C

Memory top?  [eg $DFFF]
Z80 BASIC Ver 4.7b
Copyright (C) 1978 by Microsoft
31907 Bytes free

Ok
```

It can be used to simply provide accelerated I/O over the standard ROM, and it provides Basic programming space from `0x8000` RAM address.

Also, this ROM provides both Intel HexLoadr functions and a `RST`, `INT0`, and `NMI` JumP Table.
This allows you to upload Assembly or compiled C programs, and then run them as described below. 

==============================================================================

# YAZ180

ASCI0 interrupt driven serial I/O to run modified NASCOM Basic 4.7.

Two versions of initialisation routines NASCOM Basic are provided.

# 56k Basic with integrated HexLoadr

The 56k version utilises the full 56k RAM memory space of the YAZ180, starting at `0x2000`.

Full input and output ASCI0 buffering. Transmit and receive are interrupt driven.

Receive buffer is 255 bytes, to allow efficient pasting of Basic into the editor.
Receive buffer overflows are silently discarded.

Transmit buffer is 255 bytes, because the YAZ180 is 36.864MHz CPU.
Transmit function busy waits when buffer is full. No Tx characters lost.

# 32k Basic with integrated HexLoadr

The 32k version uses the CA0 space for buffers and the CA1 space for Basic.
This leaves the Bank RAM / Flash space in `0x4000` to `0x7FFF` available for other usage.

The rationale is to allow in-circuit programming, and an exit to another system.
An integrated HexLoadr program is provided for this purpose.


```bash
YAZ180 - feilipu

Cold or Warm start, or Hexloadr (C|W|H) ? C

Memory top? 
Z80 BASIC Ver 4.7b
Copyright (C) 1978 by Microsoft
32451 Bytes free
Ok
```

Full input and output ASCI0 buffering. Transmit and receive are interrupt driven.

Receive buffer is 255 bytes, to allow efficient pasting of Basic into the editor.
Receive buffer overflows are silently discarded.

Transmit buffer is 255 bytes, because the YAZ180 is 36.864MHz CPU.
Transmit function busy waits when buffer is full. No Tx characters lost.

https://feilipu.me/2016/05/23/another-z80-project/

# HexLoadr extension

The goal of this extension to the standard RC2014 and YAZ180 boot sequence is to load an arbitrary program in Intel HEX format into an arbitrary location in the Z180 address space, and allow you to start the program from Nascom Basic.

There are are several stages to this process.

1. Reset the YAZ180, and select the HexLoadr `H` from the `(C|W|H)` options.
2. Then the HexLoadr program will initiate and look for your program's Intel HEX formatted information on the serial interface.
3. Once the final line of the HEX code is read, the HexLoadr will return to Nascom Basic.
4. The newly loaded program starting address must be loaded into the `USR(x)` jump location.
5. Start the new arbitrary program by entering `USR(x)`.
    
# Important Addresses

There are a number of important Z180 addresses or origins that need to be managed within your assembly program.

## Arbitrary Program Origin

Your program (the one that you're doing all this for) needs to start in RAM located somewhere.

If you're using the RC2014 or YAZ180 with 32kB Nascom Basic, then all of the RAM between `0x3000` and `0x7FFF` is available for your assembly programs, without limitation. In the YAZ180 the area between `0x2000` and `0x2FFF` is reserved for system calls, buffers, and stack space. For the RC2014 the area from `0x8000` is reserved for these uses.

In the YAZ180, the area from `0x4000` to `0x7FFF` is the Banked memory area, and this RAM can be managed by the HexLoadr program to write to all of the physical RAM space using ESA Records.

HexLoadr supports the Extended Segment Address Record Type, and will store the MSB of the ESA in the Z180 BBR Register. The LSB of the ESA is silently abandoned. When HexLoadr terminates the BBR is returned to the original value.

## RST locations

For convenience, because we can't easily change the ROM code interrupt routines already present in the YAZ180, the ASCI serial Tx and Rx routines are reachable by calling `RST` instructions from your program.

* Tx: `RST 08H` expects a byte to transmit in the `a` register.
* Rx: `RST 10H` returns a received byte in the `a` register, and will block (loop) until it has a byte to return.
* Rx Check: `RST 18H` will immediately return the number of bytes in the Rx buffer (0 if buffer empty) in the `a` register.

By writing the address of your function into the `RST` jump table locations provided in the`RC2014_LABELS.TXT` and `YAZ180_LABELS.TXT` files you can modify the behaviour of any of the `RST` jumps, and set the address of the location for the `INT0` and `NMI` interrupts.

Note the vector locations provided require only an address to be inserted. The `JP` instruction is already provided. For example, you can attach an `INT0` interrupt service routine by assigning its origin address `INT_INT0    .EQU     NULL_INT` or `INT_INT0    .EQU    serialInt`. Follow the example specifications provided in [`rc2014.asm`](https://github.com/feilipu/NASCOM_BASIC_4.7/blob/master/includes/rc2014.h#L57) or [`yaz180.h`](https://github.com/feilipu/NASCOM_BASIC_4.7/blob/master/includes/yaz180.h#L60) for further details.

## USR Jump Address & Parameter Access 

For the RC2014 with 32k Basic the location for `USR(x)` is `0x8224`. For the YAZ180 with 32k Basic the `USR(x)` jump address is located at `0x8004`. For the YAZ180 with 56k Basic the `USR(x)` jump address is located at `0x2704`. For example, if your arbitrary program is located at `0x3000` then the 32k Basic command to set the `USR(x)` jump address is `DOKE &h8224, &h3000`.

Your assembly program can receive a 16 bit parameter passed in from the function by calling `DEINT` at `0x0C47`. The parameter is stored in register pair `DE`.

When your assembly program is finished it can return a 16 bit parameter stored in `A` (MSB) and `B` (LSB) by jumping to `ABPASS` which is located at `0x13BD`.

``` asm
                                ; from Nascom Basic Symbol Tables
DEINT           .EQU    $0C47   ; Function DEINT to get USR(x) into DE registers
ABPASS          .EQU    $13BD   ; Function ABPASS to put output into AB register for return

                .ORG    3000H   ; your code origin, for example
                CALL DEINT      ; get the USR(x) argument in DE
                 
                                ; your code here
                                
                JP ABPASS       ; return the 16 bit value to USR(x). Note JP not CALL
```
The `YAZ180_LABELS.TXT` file is provided to advise of all the relevant RAM and ROM locations.

# Program Usage

1. Select the preferred origin `.ORG` for your arbitrary program, and assemble a HEX file using your preferred assembler.

2. Reset the YAZ180 and type `H` when offered the `(C|W|H)` option when booting. `HexLoadr:` will wait for Intel HEX formatted data on the ASCI serial interface.

3. Using a serial terminal, upload the HEX file for your arbitrary program that you prepared in Step 1. If desired the python `slowprint.py` program, or the Linux `cat` utility, can also be used for this purpose. `python slowprint.py > /dev/ttyUSB0 < myprogram.hex` or `cat > /dev/ttyUSB0 < myprogram.hex`.

4. When HexLoadr has finished, and you are back at the Basic `ok` prompt, use the `DOKE` command relocate the address for the Basic `USR(x)` command to point to `.ORG` of your arbitrary program. For the YAZ180 the `USR(x)` jump address is located at `0x8224` (RC2014 32k), `0x8004` (YAZ180 32k), or `0x2704` (YAZ180 56k). If your arbitrary program is located at `0x3000` then the Basic command is `DOKE &h8224, &h3000`, for example.

5. Start your arbitrary program by typing `PRINT USR(0)`, or other variant if you have a parameter to pass to your program.

6. Profit.

## Workflow Notes

Note that your arbitrary program and the `USR(x)` jump address setting will remain in place through a YAZ180 Cold or Warm RESET, provided you avoid using RAM that Basic initialises. Also, you can reload your assembly program to the same location through multiple Warm and HexLoadr RESETs, without reprogramming the `USR(x)` jump.

Any Basic programs loaded will also remain in place during a Warm or HexLoadr RESET.

This makes loading a new version of your assembly program as easy as 1. `RESET`, 2. `H`, then 3. `cat`.
