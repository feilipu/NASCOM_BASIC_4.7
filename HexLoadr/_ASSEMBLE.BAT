tasm -80 -a7 -fff -c -l -g3 d:hexloadr.asm d:hexloadr.bin

python bin2bas.py HEXLOADR.BIN > hexloadr.bas

pause
