tasm -80 -x3 -a7 -c -l -g3 d:hexloadr.asm d:hexloadr.bin

python bin2bas.py HEXLOADR.BIN > hexloadr.bas

python slowprint.py < hexloadr.bas > /dev/ttyUSB0

pause
