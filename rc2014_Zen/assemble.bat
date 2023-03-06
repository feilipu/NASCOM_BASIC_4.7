
zcc +z80 --no-crt -v -m --list -Ca-f0x00 zen_src.asm -o zen
z88dk-appmake +glue -b zen --ihex --pad --filler 0xFF --clean
