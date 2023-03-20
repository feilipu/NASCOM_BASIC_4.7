
zcc +z80 --no-crt -v -m --list -Ca-f0x00 zen_src.asm -o zen_basic
z88dk-appmake +glue -b zen_basic --ihex --pad --filler 0xFF --clean
