
zcc +z80 --no-crt -v -m --list -Ca-f0xFF @nascom56k.lst -o rc2014_56k
z88dk-appmake +glue -b rc2014_56k --ihex --pad --filler 0xFF --recsize 24 --clean
