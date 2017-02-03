# NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft

Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3 (May-June 1983) to Vol 3, Issue 3 (May-June 1984).

Adapted for the freeware Zilog Macro Assembler 2.10 to produce the original ROM code (checksum A934H). PA

http://www.nascomhomepage.com/

==================================================================================

The updates to the original BASIC within this file are copyright Grant Searle.

You have permission to use this for NON COMMERCIAL USE ONLY
If you wish to use it elsewhere, please include an acknowledgement to myself.

http://searle.hostei.com/grant/index.html

If the above don't work, please perform an Internet search to see if I have updated the web page hosting service.

==================================================================================

ACIA 6850 interrupt driven serial I/O to run modified NASCOM Basic 4.7.

Full input and output buffering with incoming data hardware handshaking.
Handshake shows full before the buffer is totally filled to allow run-on from the sender.
Transmit and receive are interrupt driven.

Receive buffer is 239 bytes, to allow efficient pasting of Basic into the editor.
Transmit buffer is 15 bytes, because the rc2014 is too slow to fill the buffer.
Receive and Transmit buffer overflows are silently discarded.

==================================================================================

# YAZ180

ASCI0 interrupt driven serial I/O to run modified NASCOM Basic 4.7.

Two versions of NASCOM Basic are provided.

## 56k Basic

The 56k version utilises the full 56k RAM memory space of the YAZ180, starting at 0x2000.

Full input and output ASCI0 buffering. Transmit and receive are interrupt driven.

Receive buffer is 239 bytes, to allow efficient pasting of Basic into the editor.
Transmit buffer is 15 bytes, for commonality with rc2014.
Receive and Transmit buffer overflows are silently discarded.


## 32k Basic (Monitor)

The 32k version uses only the CA0 space for buffers and the CA1 space for Basic.
This leaves the Bank space in 0x4000 to 0x7FFF for assembly or other usage.

The rationale is to allow in-circuit programming, and exit to another system.
An exit jump to RAM at 0x3000 is provided for this purpose.

Setting the Memory Top to 0xDFFF (for example) leaves 8kB RAM to store a
hex loader, which can use the Bank space to write RAM or Flash as desired.

```bash
YAZ180 - feilipu

Cold or warm start, or eXit (C|W|X) ?C

Memory top?  57343 [$DFFF]
Z80 BASIC Ver 4.7b
Copyright (C) 1978 by Microsoft
24257 Bytes free
Ok
```

Full input and output ASCI0 buffering. Transmit and receive are interrupt driven.

Receive buffer is 255 bytes, to allow efficient pasting of Basic into the editor.
Receive buffer overflows are silently discarded.

Transmit buffer is 255 bytes, because the YAZ180 is 36MHz CPU.
Transmit function busy waits when buffer is full. No Tx characters lost.

https://feilipu.me/
