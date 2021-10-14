
zcc +z80 --no-crt -v -m --list -Ca-f0xFF @nascom32k.lst -o rc2014_32k_am9511
z88dk-appmake +glue -b rc2014_32k_am9511 --ihex --pad --filler 0xFF --recsize 24 --clean
