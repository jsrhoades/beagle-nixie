#!/bin/sh

if [ ! -e "./setPWMReg.py" ]; then
   echo "e"
   exit 1;
fi

./setPWMReg.py

echo 6 > /sys/kernel/debug/omap_mux/gpmc_a2

echo 0 > /sys/class/pwm/ehrpwm.1:0/duty_percent
echo 32000 > /sys/class/pwm/ehrpwm.1:0/period_freq

echo 10 > /sys/class/pwm/ehrpwm.1:0/duty_percent
echo 1 > /sys/class/pwm/ehrpwm.1:0/run
