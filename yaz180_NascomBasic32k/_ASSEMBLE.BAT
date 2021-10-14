
zcc +z180 --no-crt -v -m --list -Ca-f0xFF @nascom32k.lst -o yaz180_32k
appmake +glue -b yaz180_32k --ihex --pad --filler 0xFF --recsize 24 --clean
