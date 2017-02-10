mem = 0xF800 # location of the hexload program
usr = 0x80AB # location of the USR(x) jump address from Basic

# fill the USR(x) jump with the address
print "poke "+str(usr-65536+1) + "," + str(0x00) + "\r"
print "poke "+str(usr-65536+2) + "," + str(0xF8) + "\r"

# now fill the RAM with the program bytes
with open("HEXLOAD.BIN", "rb") as f:
    byte = f.read(1)
    while byte != "":
        print "poke "+str( mem-65536 )+","+str( ord(byte) ) + "\r"
        mem = mem+1
        byte = f.read(1)

