
zcc +z180 --no-crt -v -m --list -Ca-f0xFF @nascom56k.lst -o yaz180_56k
appmake +glue -b yaz180_56k --ihex --pad --filler 0xFF --recsize 24 --clean
