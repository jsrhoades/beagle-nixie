CROSS_COMPILE ?= arm-angstrom-linux-gnueabi-

CC = $(CROSS_COMPILE)gcc
CFLAGS = -I/usr/local/include -DDEBUG
LDFLAGS = -L/usr/local/lib -lprussdrv -lpthread
PASM = pasm

DATA_PRU = pru0_data.bin
LDR = clock

all: $(LDR) $(LATCH_PRU) $(DATA_PRU)

$(LDR): $(basename $(LDR)).c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(DATA_PRU): $(basename $(DATA_PRU)).p
	$(PASM) -b $^

.PHONY: clean

clean:
	rm -f *~ *.o $(LDR) $(DATA_PRU)
