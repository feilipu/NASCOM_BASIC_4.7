# HexLoadr
The goal of this program is to load an arbitrary program in Intel HEX format into an arbitrary location in the Z80 address space, and allow you to start the program from Nascom Basic.

There are are several stages to this process.

1. The `hexloadr.asm` loader program must be compiled into a binary format, `HEXLOADR.BIN`
2. `HEXLOADR.BIN` must then be converted to a series of poke statements using the `bin2bas.py` python program.
3. These poke statements are then loaded through the serial interface into Nascom Basic to get the hexloadr program placed correctly into the RAM of the RC2014 or YAZ180 machine.
4. The starting adddress of the hexloadr program must be inserted into the correct location for the `USR(x)` jump out of Nascom Basic.
5. Then the hexloadr program will initiate and look for your program's Intel HEX formatted information on the serial interface.
6. Once the final line of the HEX code is read, the hexloadr will return to Nascom Basic.
7. The newly loaded program starting address is automatically loaded into the `USR(x)` jump location.
8. Start the new program by entering `USR(x)`.
    
# Important Addresses

There are a number of important Z80 addresses or origins that need to be modified (managed) within the assembly and python programs.

### Arbitrary Program Origin

Your program (the one that you're doing all this for) needs to start in RAM located somewhere. Some recommendations can be given.

For the RC2014 with 32kB of RAM, when Nascom Basic initiates it requests the "Memory Top?" figure. Setting this to 57343 (`0xDFFF`), or lower, will give you space from `0xE000` to `0xFFFF` for your program and for the hexloader program.

The eXit option on my initiation routine for Nascom Basic is set to jump to `0xE000`, Under the assumption that if you are jumping off at restart you are interested to have a large space for your arbitrary program.

For the YAZ180 with 56kB of RAM, the arbitrary program location is set to `0x3000`, to allow this to be in the Common 0 Space for the MMU.


### HexLoadr Program Origin

For convenience, the hexloadr program is configured to load itself from `0xFF00`. This means your arbitrary program can use the space from `0xE000` to `0xFEFF` without compromise. Further, if you want to use a separate stack or heap space (preserving Nascom Basic) the hexloadr program space can be overwritten, by setting the stack pointer to `0x0000` (which decrements on use to `0xFFFF`).

This can be changed if substantial code is added to the hexloadr program

### RST locations

For convenience, because we can't easily change ROM code already present in the RC2014, the serial Tx and Rx routines are reachable by calling RST jumps (calls).

* Tx: `RST 08H` expects a byte in the a register.
* Rx: `RST 10H` returns a byte in the a register, and will loop until it has a byte to return.
* Rx Check: `RST 18H` will return the number of bytes in the Rx buffer (0 if buffer empty).

# Program Usage

1. Select the preferred origin `.ORG` for your arbitrary program, and assemble a HEX file using your preferred assembler.

2. Confirm your preferred origin of the hexloadr program, and adjust it to match in the `hexloadr.asm` and `bin2bas.py` programs.

3. Assemble hexloadr.asm using TASM to produce a HEXLOADR.BIN file using this command line. `tasm -80 -a7 -fff -c -l -g3 d:hexloadr.asm d:hexloadr.bin`

4. Produce the "poke" file called `hexloadr.bas` by using the python command. `python bin2bas HEXLOADR.BIN > hexloadr.bas`

5. Start your RC2014 with the `Memory top?` set to 57343 (`0xDFFF`) or lower. This leaves space for your program and for the hexloadr program.

6. Using a serial terminal either copy and paste all of the "poke" commands into the RC2014, or upload them using a slow (or timed) serial loading program. If desired the python `slowprint.py` program can be used for this purpose. `python slowprint.py < hexloadr.bas > /dev/ttyUSB0`

7. From the `ok` prompt in Basic, start the hexloadr program with `print usr(0)`

8. Using a serial terminal, upload the HEX file for your arbitrary program that you prepared in step 1. If desired the python `slowprint.py` program can also be used for this purpose. `python slowprint.py < myarbitraryprogram.hex > /dev/ttyUSB0`

9. When hexloadr has finished, and you are back at the Basic `ok` prompt start your arbitrary program using '`print usr(0)`, or other variant if you have parameters to pass to your program.

10. Profit.

# Credits

Derived from the work of @fbergama and @foxweb at RC2014.

https://github.com/RC2014Z80/RC2014/blob/master/ROMs/hexload/hexload.asm



