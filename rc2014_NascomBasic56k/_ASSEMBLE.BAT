
zcc +z80 --no-crt -v -m --list -Ca-f0xFF @nascom56k.lst -o int56k
z88dk-appmake +glue -b int56k --ihex --pad --filler 0xFF --recsize 24 --clean

# AND

tasm -80 -a7 -fff -c -l d:bas56k.asm d:bas56k.hex

# CONCATENATE THE TWO HEX FILES
