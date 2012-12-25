CROSS_COMPILE ?= arm-angstrom-linux-gnueabi-

CC = $(CROSS_COMPILE)gcc
#CFLAGS = -I/usr/local/include -DDEBUG
CFLAGS = -I/usr/local/include
LDFLAGS = -L/usr/local/lib -lprussdrv -lpthread
PASM = pasm

DATA_PRU = pru0_clock.bin
CLOCK_PRU = pru1_clock.bin
LDR = clock

all: $(LDR) $(CLOCK_PRU) $(DATA_PRU)

$(LDR): $(basename $(LDR)).c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(CLOCK_PRU): $(basename $(CLOCK_PRU)).p
	$(PASM) -b $^

$(DATA_PRU): $(basename $(DATA_PRU)).p
	$(PASM) -b $^

.PHONY: clean

clean:
	rm -f *~ *.o $(LDR) $(DATA_PRU) $(CLOCK_PRU)
