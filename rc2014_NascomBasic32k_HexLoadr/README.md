# HexLoadr

__NOTE__ The Intel HEX program loader `HLOAD` has been integrated inside MS Basic.

The goal of this extension to standard MS Basic is to load an arbitrary program in Intel HEX format into an arbitrary location in the Z80 address space, and allow you to start and use your program from Nascom Basic. Your program can be created in assembler, or in C, provided the code is available in Intel HEX format.

There are are several stages to this process.

1. At the Basic interpreter type `HLOAD`, then the command will initiate and look for your program's Intel HEX formatted information on the serial interface.
2. Once the final line of the HEX code is read into memory, `HLOAD` will return to Nascom Basic with `ok`.
3. Start the new arbitrary program from Basic by entering the`USR(x)` command.

The `HLOAD` program can be exited without uploading a valid file by typing `:` followed by `CR CR CR CR CR CR`.

# Important Addresses

There are a number of important Z80 addresses or origins that need to be managed within your assembly program.

## RST locations

For convenience, because we can't easily change the ROM code interrupt routines this ROM provides for the RC2014, the ACIA serial Tx and Rx routines are reachable from your assembly program by calling the `RST` instructions from your program.

* Tx: `RST 08H` expects a byte to transmit in the `a` register.
* Rx: `RST 10H` returns a received byte in the `a` register, and will block (loop) until it has a byte to return.
* Rx Check: `RST 18H` will immediately return the number of bytes in the Rx buffer (0 if buffer empty) in the `a` register.

## USR Jump Address & Parameter Access

For the RC2014 with 32k Basic the `USR(x)` jump address is located at `0x8224`.

Your assembly program can receive a 16 bit parameter passed in from the function by calling `DEINT` at `0x0AD9`. The parameter is stored in register pair `DE`.

When your assembly program is finished it can return a 16 bit parameter stored in `A` (MSB) and `B` (LSB) by jumping to `ABPASS` which is located at `0x124F`.

``` asm
                                ; from Nascom Basic Symbol Tables
DEINT           .EQU    $0AD9   ; Function DEINT to get USR(x) into DE registers
ABPASS          .EQU    $124F   ; Function ABPASS to put output into AB register for return


                .ORG    9000H   ; your code origin, for example
                CALL    DEINT   ; get the USR(x) argument in DE
                 
                                ; your code here
                                
                JP      ABPASS  ; return the 16 bit value to USR(x). Note JP not CALL
```


# Program Usage

1. Select the preferred origin `.ORG` for your arbitrary program, and assemble a HEX file using your preferred assembler, or compile a C program using z88dk.

2. Give the `HLOAD` command within Basic.

3. Using a serial terminal, upload the HEX file for your arbitrary program that you prepared in Step 1, using the Linux `cat` utility or similar. If desired the python `slowprint.py` program can also be used for this purpose. `python slowprint.py > /dev/ttyUSB0 < myprogram.hex` or `cat > /dev/ttyUSB0 < myprogram.hex`. The RC2014 interface can absorb full rate uploads, so using `slowprint.py` is an unnecessary precaution.

4. Start your program by typing `PRINT USR(0)`, or `? USR(0)`, or other variant if you have a parameter to pass to your program.

5. Profit.

## Notes

Note that your program and the `USR(x)` jump address setting will remain in place through a RC2014 Cold or Warm RESET, provided you prevent Basic from initialising the RAM locations you have used. Also, you can reload your assembly program to the same RAM location through multiple Warm and HexLoadr RESETs, without reprogramming the `USR(x)` jump.

Any Basic programs loaded will also remain in place during a Warm RESET.

# Credits

Derived from the work of @fbergama and @foxweb at RC2014.

https://github.com/RC2014Z80/RC2014/blob/master/ROMs/hexload/hexload.asm
