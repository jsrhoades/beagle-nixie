#!/usr/bin/env python

REV = "00A0"
MANUFACTURER = "Ranostay Industries"
BOARD_DESC = "Nixie Cape"
PART_NUMBER = "BB-BONE-NIXIE"

f = open("eeprom.bin", "wb")
f.write(chr(0xaa) + chr(0x55) + chr(0x33) + chr(0xee))
f.write("A1")
f.write(BOARD_DESC.ljust(32)[:32])
f.write(REV.ljust(4)[:4])
f.write(MANUFACTURER.ljust(16)[:16])
f.write(PART_NUMBER.ljust(16)[:16])
f.close()
