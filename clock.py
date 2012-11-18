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
from time import strftime

try:
    from spi import spi_transfer, SPIDev
    SPI_DEVICE = "/dev/spidev2.0"
except ImportError, e:
    print >>sys.stderr, "No spi module found. Aborting."
    sys.exit(1)


try:
    from bbio import *
    from bbio.bbio import _setReg, _pinMux
except ImportError, e:
    print >>sys.stderr, "No pybbio module found. Aborting."
    sys.exit(1)

### GPIO Lines ###

LINES = {
    "BLANK": GPIO2_7,
}

SEGMENTS = {
    "SEG_A": 1 << 9,
    "SEG_B": 1 << 18,
    "SEG_C": 1 << 12,
    "SEG_D": 1 << 11,
    "SEG_E": 1 << 13,
    "SEG_F": 1 << 19,
    "SEG_G": 1 << 17,
    "SEG_H": 1 << 10,
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
    ".":    BUILD_SEGMENT("H"),
}


DIGITS = {
    "1": 1 << 7,
    "2": 1 << 0,
    "3": 1 << 6,
    "4": 1 << 1,
    "5": 1 << 5, 
    "6": 1 << 2,
    "7": 1 << 3, 
    "8": 1 << 4,
    "9": 1 << 8,
}

BLANKING_PWM = "/sys/class/pwm/ehrpwm.1:1/"

def set_brightness(value):
    value = 100 - value

    _pinMux("gpmc_a3", 6) # Blanking PWM Channel #

    with open(BLANKING_PWM + "duty_percent", "w") as f:
        f.write(str(value))

    try:
        with open(BLANKING_PWM + "run", "w") as f:
            f.write("1")
    except IOError, e:
        pass

def blank_screen():
    set_brightness(0)

    write_byte(".", 0) # Discharge boost converter here #

    with open(BLANKING_PWM + "run", "w") as f:
        f.write("0")

def write_byte(byte, digit):
    value = DIGITS[str(digit + 1)]
    value |= SEGMENT_VALUES[byte]

    if digit % 2:
        value |= SEGMENTS["SEG_H"]

    data = []
    data.append(chr((value >> 16) & 0xff))
    data.append(chr((value >> 8) & 0xff))
    data.append(chr(value & 0xff))

    transaction = []
    transfer, tx_buf, rx_buf = spi_transfer("".join(data), readlen=0)
    transaction.append(transfer)

    dev = SPIDev(SPI_DEVICE) 
    dev.do_transfers(transaction)

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

### No feedback loop. So know what you are doing... ###
SYSFS_PWM = "/sys/class/pwm/ehrpwm.1:0/"

def setup_pwm():
    _setReg(CM_PER_EPWMSS1_CLKCTRL, 0x2)
    _pinMux("gpmc_a2", 6) # Boost PWM Channel #

    with open(SYSFS_PWM + "duty_percent", "w") as f:
        f.write("0")

    try:
        with open(SYSFS_PWM + "run", "w") as f:
            f.write("0")
    except IOError, e:
        pass

    ### 9.250 Khz ###
    with open(SYSFS_PWM + "period_freq", "w") as f:
        f.write("9250")

    with open(SYSFS_PWM + "duty_percent", "w") as f:
        f.write("35")

    with open(SYSFS_PWM + "run", "w") as f:
        f.write("1")


def shutdown_pwm():
    with open(SYSFS_PWM + "run", "w") as f:
        f.write("0")

def main():
    setup_gpios()
    setup_pwm()

    if len(sys.argv) == 2:
        brightness = sys.argv[1]
        if brightness.isdigit():
            brightness = int(brightness)

            if not brightness in range(1, 100 + 1):
                print "Defaulting brightness to 50"
                brightness = 50
        else:
            print "Defaulting brightness to 50"
            brightness = 50
    else:
        print "Defaulting brightness to 50"
        brightness = 50

    set_brightness(brightness)

    atexit.register(shutdown_pwm)
    atexit.register(blank_screen)

    last_display = ""
    try:
        x = 0
        while (1):
            str = strftime(" %H%M%S ".ljust(8))
            if not last_display == str:
                last_display = str
                print str, x
                x = 0

            str = str[::-1]
            write_string(str)

            x += 1
    except KeyboardInterrupt: pass

if __name__ == '__main__':
    main()
