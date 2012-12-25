/*
 * Nixie Cape PRU Standalone Clock Application
 *
 * Copyright 2012, Matt Ranostay. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are
 * permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice, this list of
 *     conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright notice, this list
 *     of conditions and the following disclaimer in the documentation and/or other materials
 *     provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY MATT RANOSTAY ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL MATT RANOSTAY OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation are those of the
 * authors and should not be interpreted as representing official policies, either expressed
 *or implied, of Matt Ranostay.
 */



#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>

#include <prussdrv.h>
#include <pruss_intc_mapping.h>
#include <sys/fcntl.h>
#include <sys/stat.h>
#include <time.h>

struct pru_data {
	/* data section - copy to PRU */
	uint8_t *prumem;
};

enum pru_data_idx {
	HOUR_FIRST_DIGIT	= 0,
	HOUR_SECOND_DIGIT 	= 1,

	MINUTE_FIRST_DIGIT	= 2,
	MINUTE_SECOND_DIGIT	= 3,

	SECOND_FIRST_DIGIT	= 4,
	SECOND_SECOND_DIGIT	= 5,
};

#define NUM_DIGITS	6 

static int init_time(struct pru_data *pru) {
	uint8_t buf[NUM_DIGITS + 1];
        uint8_t *mem = pru->prumem;
	time_t ts;
	struct tm *timeinfo;
	int i;

	time(&ts);
	timeinfo = localtime(&ts);

	strftime(buf, sizeof(buf), "%H%M%S", timeinfo);

	for (i = 0; i < NUM_DIGITS; i++) {
		mem[i] = buf[i] - '0';
	}
#ifdef DEBUG
        fprintf(stdout, "Hour Digit 1:\t\t%x\n"
                        "Hour Digit 2:\t\t%x\n"
                        "Minute Digit 1:\t\t%x\n"
                        "Minute Digit 2:\t\t%x\n"
                        "Second Digit 1:\t\t%x\n"
                        "Second Digit 2:\t\t%x\n",
                        mem[0], mem[1], mem[2],
                        mem[3], mem[4], mem[5]);
#endif
};


int main(int argc, char **argv) {
	char *bin_path, *ptr;
	struct pru_data	pru;

	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
	prussdrv_init();
	if (prussdrv_open(PRU_EVTOUT_0)) {
		fprintf(stderr, "Cannot setup PRU_EVTOUT_0.\n");
		return -EINVAL;
	}
	prussdrv_pruintc_init(&pruss_intc_initdata);

	prussdrv_map_prumem(PRUSS0_PRU0_DATARAM, (void *) &pru.prumem);
	if (pru.prumem == NULL) {
		fprintf(stderr, "Cannot map PRU0 memory buffer.\n");
		return -ENOMEM;
	}
	init_time(&pru);

	bin_path = strdup(argv[0]);

	ptr = strrchr(bin_path, '/');
	*ptr = '\0';

	chdir(bin_path);
	/*
	 * Display PRU
	 */
	prussdrv_exec_program(0, "pru0_clock.bin");

	/*
	 * Clock PRU
	 */
	prussdrv_exec_program(1, "pru1_clock.bin");
	prussdrv_exit();

	return 0;
}
