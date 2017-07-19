tasm -80 -x3 -a7 -fff -c -l d:bas56k.asm d:bas56k.hex

zcc +z180 --no-crt -v -m --list -Ca--filler=0xFF @nascom32k.lst -o int32k
appmake +glue -b int32k --ihex --pad --filler 0xFF --recsize 24 --clean
