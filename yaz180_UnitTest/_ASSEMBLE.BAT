tasm -80 -x3 -a7 -fff -c -l d:test.asm d:test.hex

zcc +yaz180 -subtype=basic_dcio -SO3 -m --list z180ide.asm -o _ide -lm -create-app
cat > /dev/ttyUSB0 < _ide.ihx 

