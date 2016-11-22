# NASCOM_BASIC_4.7

# NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft

Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3 (May-June 1983) to Vol 3, Issue 3 (May-June 1984)
Adapted for the freeware Zilog Macro Assembler 2.10 to produce the original ROM code (checksum A934H). PA

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

https://feilipu.me/
