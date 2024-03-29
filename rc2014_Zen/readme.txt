Notes for use with Microsoft Basic.

There are several Intel HEX versions of the Zen assembler with different RAM origins prepared to use from within RC2014 NASCOM Basic. Use the "HLOAD" Basic keyword to load your choice of HEX file based on how much RAM you wish to leave available for Basic, and launch Zen with "?USR(0)". Exit back to MS Basic with "Q".

Use the Zen "ORG" and "LOAD" keywords to place assembled programs above the Zen End of File Pointer "EOFP". Use Zen "H" command to determine where "EOFP" is located. The Zen "ORG" keyword should indicate where program will eventually be located, usually at the default of 0x9000. On return to Basic, assembled programs can be launched using the "?USR(0)" command either from immediate mode, or from within a Basic program as a subroutine, after setting the correct "USR" location for the assembly program's "ORG", if the program is being run with Zen insitu. Or use the "X" command to save the assembled program to the serial port in Intel HEX format, and then reload it with the Basic "HLOAD" and run normally using the "?USR(0)" command.

Check the NASCOM Basic Manual Appendix D for further information on mixing Basic and Assembly code.

A MS BASIC monitor for the RC2014 is available, which can be used together with Zen to manage large assembly programs.
https://github.com/RC2014Z80/RC2014/tree/master/BASIC-Programs/Monitor

Derived from the original source by Neal Crook, and including adaption to RC2014 and improvements by Phil Green.
https://github.com/nealcrook/nascom/tree/master/ZEN_assembler

feilipu - March 2023

========================================================================



Zen Editor/Assembler for the Grant Searle "Simple Z80" and similar board
------------------------------------------------------------------------

Grant Searle's "Simple Z80" is a brilliant retro computing design, which has spawned a host of Z80 projects, notably the RC2014 series, the "RC2014 Mini", "Micro" and "Classic II" being essentially identical to Grants design. As published these are BASIC-only machines, but the Nascom BASIC interpreter doesnt quite fill the 8k ROM so I wrote a small Z80 machine-code monitor that just fits in the unused space. This simple monitor is only about 600 bytes yet is adequate for entering, examining and running small programs, loading Intel Hex files, and calling M/C from BASIC, but for anything more elaborate you really need an assembler.

The problem is that almost all assemblers use disks or external storage, which the "Simple Z80" or "RC2014 mini/micro" doesnt have. They also need an external source editor which again would normally be disk based.

"Zen" is different - its a truly-retro memory-resident Editor-Assembler which needs no external storage - the assembler itself, your source code, the resulting object code and the symbol table are all stored in RAM, which is a perfect solution to the lack of disks.  Its capable without being feature-laden and is dead easy to use. Zen was popular back in the late 70s to mid 80s then faded away, to be resurrected by retro computer enthusiasts four decades later on a variety of retro Z80 projects. At under 4k in size it can readily run on the 32k boards.

With Zen, the Grant Searle "Simple Z80", the RC2014 'Mini' and 'Micro' become useful development machines fully capable of serious Z80 assembler coding.   It works really well and allows the full development cycle on the Z80 itself, very much like the ZEAP editor/assembler I had on my Nascom-1 back in 1978. Of course I've CP/M systems here that can do the whole cycle with ease and my favourite PC cross-assemblers but this is particularly interesting as it runs on such a basic machine and is totally self-contained.

With sincere thanks to Neal Crook who has kindly made public the extensive work he's done on the Nascom version of Zen, on which this is based, heres my port for the "Simple Z80" or "RC2014 mini/micro" computer in either 32k or 56k format.  An amended manual specific to this port is included, its short, easy to follow and has only a few commands to remember. 

There are some changes to the documented commands, to better suit the GS/RC2014 hardware:
 - The cassette tape storage commands are redundant so I've disabled 'R' for read tape
 - The "W" write command is changed to output source in a re-loadable format, in exactly the same way that a BASIC listing is saved and loaded within Teraterm, either using the log function or simple copy & paste from the Teraterm buffer. 
 - The "E" command loads source, either manually from the keyboard or from Teraterm 'file-send' just as we do when loading BASIC programs, a character delay of 1ms and a line delay of say 300ms ensures nothing is missed.  
 - Three options are available for the 'A' assembler command ouput, 'V' sends a proper listing to the screen, or 'C' does a tabulated object code dump. A null option (just press return) assembles only to memory which is much faster. 
 - The "X" command is new, following a successful assembly X can be used to generate an Intel Hex file of the object code. This correctly handles phase differences between ORG and LOAD.
 - The "Q" quit command returns to the monitor in the 8k rom image, so please use the updated rom from http://philg.uk

The editor is as minimal as it could be - you can enter a line, during which you may use backspace, you can delete a line with "Z" (zap) and enter a new line with "N". "T" takes you to the top of the source, "B" to the bottom, theres "U" for up, "D" for down, and "Pnn" prints nn lines to the screen. "Gnn" goes to line nn. Remember that "E" enters text BEFORE the current line, as it always has.

The manual lists the Editor & Assembler commands and options, please read it  :-)

To minimise the source-code memory used, it helps to keep comments brief and use minimal annotation - perhaps keep two copies of every source file, one commented for human use, and one as brief as possible to be loaded into the assembler.

With its own minimised source code "Zen" will happily assemble itself and can locate the object code somewhere other than where it is ORG'd using the LOAD operator. The "X" command takes account of this, and correctly generates loadable Intel HEX code.

Over the decades "Zen" has morphed in many ways but was originally written by John Hawthorne and distributed by Tim Moore of Newbear and by Laurie Shields of Avalon Sofware, with the Nascom port completed by Neal Crook, and all credit goes to these good people  :-)

Phil_G 2/3/2023, updated 10/3/2023, 18/3/2023
philg@talk21.com
https://www.youtube.com/@PHILG2864/videos
