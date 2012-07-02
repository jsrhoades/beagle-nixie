#!/usr/bin/env python
"""
Copyright 2012, Matt Ranostay. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice, this list of
      conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice, this list
      of conditions and the following disclaimer in the documentation and/or other materials
      provided with the distribution.

THIS SOFTWARE IS PROVIDED BY MATT RANOSTAY ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL MATT RANOSTAY OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those of the
authors and should not be interpreted as representing official policies, either expressed
or implied, of Matt Ranostay.
"""

import datetime
import atexit

import sys
from time import sleep, strftime

try:
    from bbio import *
except ImportError, e:
    print >>sys.stderr, "No pybbio module found. Aborting."
    sys.exit(1)

### Delay -> 10 microseconds ###
MSEC = 10

### GPIO Lines ###

LINES = {
    "BLANK": GPIO1_31,
    "CLK": GPIO1_1,
    "DIN": GPIO1_29,
    "LOAD": GPIO1_5,
}

SEGMENTS = {
    "SEG_A": 1 << 10,
    "SEG_B": 1 << 19,
    "SEG_C": 1 << 13,
    "SEG_D": 1 << 12,
    "SEG_E": 1 << 14,
    "SEG_F": 1 << 20,
    "SEG_G": 1 << 18,
    "SEG_H": 1 << 11,
}

def BUILD_SEGMENT(segments):
    value = 0
    for i in segments:
        value |= SEGMENTS["SEG_" + i]
    return value

SEGMENT_VALUES = { 
    "1":    BUILD_SEGMENT("BC"),
    "2":    BUILD_SEGMENT("ABDEG"),
    "3":    BUILD_SEGMENT("ABGCD"),
    "4":    BUILD_SEGMENT("BCFG"),
    "5":    BUILD_SEGMENT("ACDFG"),
    "6":    BUILD_SEGMENT("ACDEFG"),
    "7":    BUILD_SEGMENT("ABC"),
    "8":    BUILD_SEGMENT("ABCDEFG"),
    "9":    BUILD_SEGMENT("ABCDFG"),
    "0":    BUILD_SEGMENT("ABCDEF"),
    "X":    BUILD_SEGMENT(""),
    ".":    BUILD_SEGMENT("H"),
}


DIGITS = {
    "1": 1 << 8,
    "2": 1 << 1,
    "3": 1 << 7,
    "4": 1 << 2,
    "5": 1 << 6, 
    "6": 1 << 3,
    "7": 1 << 4, 
    "8": 1 << 5,
    "9": 1 << 8,
}

### GPIO Functions ###

def blank():
    digitalWrite(LINES["BLANK"], 1)
    digitalWrite(LINES["BLANK"], 0)


def write_bit(value):
    digitalWrite(LINES["CLK"], 1)
    digitalWrite(LINES["DIN"], int(value))
    digitalWrite(LINES["CLK"], 0)


def write_byte(byte, digit):
    value = DIGITS[str(digit + 1)]
    value |= SEGMENT_VALUES[byte]

    if digit % 2:
        value |= SEGMENTS["SEG_H"]

    value = bin(value)[2:]
    value = value.rjust(20, '0')

    for i in value:
        write_bit(i)

    digitalWrite(LINES["LOAD"], 1)
    digitalWrite(LINES["LOAD"], 0)

def write_string(data):
    idx = 0
    for byte in data:
        if not byte.isspace():
            write_byte(byte, idx)
        idx += 1

def setup_gpios():
    for key, value in LINES.items():
        pinMode(value, OUTPUT)
        digitalWrite(value, 0)

def main():
    setup_gpios()
    last_display = ""

    try:
        while (1):
            str = strftime(" %H%M%S ".ljust(8))
            str = str[::-1]

            if not last_display == str:
                last_display = str
                print str
            write_string(str)

    except KeyboardInterrupt, e:
            str = "".rjust(9)
            str = str.replace(" ", "X")
            write_string(str)


if __name__ == '__main__':
    main()
