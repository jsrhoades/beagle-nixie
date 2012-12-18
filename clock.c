/*
 * Nixie Cape PRU Clock Application
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
#include <string.h>
#include <signal.h>
#include <time.h>

#include <prussdrv.h>
#include <pruss_intc_mapping.h>

/*
 * Segments
 */

enum vfd_segments {
	SEG_A = 1<<0,
	SEG_B = 1<<1,
	SEG_C = 1<<2,
	SEG_D = 1<<3,
	SEG_E = 1<<4,
	SEG_F = 1<<5,
	SEG_G = 1<<6,
	SEG_H = 1<<7,
};

static const uint16_t nixie_segment_values[] = {
	SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F,		/* 0 */
	SEG_B | SEG_C,						/* 1 */
	SEG_A | SEG_B | SEG_D | SEG_E | SEG_G,			/* 2 */
	SEG_A | SEG_B | SEG_C | SEG_D | SEG_G,			/* 3 */
	SEG_B | SEG_C | SEG_F | SEG_G,				/* 4 */
	SEG_A | SEG_C | SEG_D | SEG_F | SEG_G,			/* 5 */
	SEG_A | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G,		/* 6 */
	SEG_A | SEG_B | SEG_C,					/* 7 */
	SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G,	/* 8 */
	SEG_A | SEG_B | SEG_C | SEG_D | SEG_F | SEG_G,		/* 9 */
	SEG_G,							/* (hypen) */
	SEG_H,							/* (period) */
	0,							/* (space) */
};

/*
 * Valid Characters
 */
static const char nixie_value_array[] = "0123456789-. ";

#define SEGMENT_COUNT	8
#define	NUM_DIGITS	9
#define RUN_FLAG_IDX	NUM_DIGITS 

struct pru_data {
	/* data section - copy to PRU */
	uint32_t *prumem;
};

uint32_t running = 1; /* start running */

/* Hardcoded settings for MAX6921 + IV-18 Tube
 *
 */

uint32_t digits_cache[NUM_DIGITS] =
	{ 0x0c, 0x13, 0x0d, 0x12, 0x0e, 0x11, 0x10, 0x0f, 0x0b };

uint32_t digits_mask[NUM_DIGITS] =
	{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,0xc0 };

uint32_t segments_cache[SEGMENT_COUNT] =
	{ 0x0a, 0x01, 0x07, 0x08, 0x06, 0x00, 0x02, 0x09 };

static uint32_t char_to_segment(int digit, int idx, int period)
{
	int i;
	uint32_t retval = 0;
	uint32_t val = nixie_segment_values[idx];

	if (period) {
		val |= SEG_H;
	}
	val = val & digits_mask[digit];

	for (i = 0; i < SEGMENT_COUNT; i++) {
		if (val & (1 << i)) {
			retval |= 1<< segments_cache[i];
		}
	}

	retval |= 1<< digits_cache[digit];

	return retval;
}

static inline int is_valid_value(char val)
{
	int i;

	for (i = 0; i < sizeof(nixie_value_array) - 1; i++) {
		if (nixie_value_array[i] == val)
			return i;
	}

	return -EINVAL;
}

#ifdef DEBUG
static inline void print_buffer(struct pru_data *pru)
{
	uint32_t *buf = (uint32_t *) pru->prumem;
	printf( "Buffer Dump: \n"
		"\tDigit 0: %x\n"
		"\tDigit 1: %x\n"
		"\tDigit 2: %x\n"
		"\tDigit 3: %x\n"
		"\tDigit 4: %x\n"
		"\tDigit 5: %x\n"
		"\tDigit 6: %x\n"
		"\tDigit 7: %x\n"
		"\tDigit 8: %x\n",
		buf[8], buf[7], buf[6],
		buf[5], buf[4], buf[3],
		buf[2], buf[1], buf[0]);

}
#endif

static int update_buffer(const char *buf, struct pru_data *pru)
{
	uint32_t *prumem = (uint32_t *) pru->prumem;
	int digit = 0;
	int period = 0;
	int val;
	int i;

	/*
	 * Cycle right to left from input string
	 */
	for (i = strlen(buf); i >= 0; i--) {
		char chr = buf[i];

		/*
		 * DP are part of digits
		 */
		if (chr == '.') {
			period = 1;
			continue;
		}

		val = is_valid_value(chr);
		if (val < 0)
			continue;

		val = char_to_segment(digit, val, period);
		if (val < 0)
			continue;

		prumem[digit] = val;
		period = 0;
		digit++;
	}

	if (period) {
		val = is_valid_value('.');
		if (val < 0)
			goto leave;
		val = char_to_segment(digit, val, 0);
		prumem[digit] = val;
	}
	memset((uint32_t *) prumem + digit, 0, sizeof(uint32_t) * (NUM_DIGITS - digit));

leave:
#ifdef DEBUG
	print_buffer(pru);
#endif
	return 0;
}

static void update_time(char *buf, int len) {
	time_t lt;
	struct tm *ptr;

	lt = time(NULL);
	ptr = localtime(&lt);

	strftime(buf, len, " %H.%M.%S ", ptr);
#ifdef DEBUG
	printf("Time is NOW: %s\n", buf);
#endif
}

static void trigger_update(struct pru_data *pru)
{
	prussdrv_pru_send_event(ARM_PRU0_INTERRUPT);
}

static void blank_vfd(struct pru_data *pru)
{
	/* blank VFD */
	memset(pru->prumem, 0, NUM_DIGITS * sizeof(uint32_t));
	trigger_update(pru);
}

static void shutdown_clock(int signo)
{
	running = 0;
}


int main(void) {
	char buf[32];
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
	pru.prumem[RUN_FLAG_IDX] = 1; /* startup */
	prussdrv_exec_program(0, "./pru0_clock.bin");

	blank_vfd(&pru);
	signal(SIGINT, shutdown_clock);

	int i = 0;
	while (running) {
		update_time((char *) &buf, sizeof(buf));
		update_buffer((const char *) &buf, &pru);
		trigger_update(&pru);
		sleep(1);
	}

	pru.prumem[RUN_FLAG_IDX] = 0;
	trigger_update(&pru);
#ifdef DEBUG
	fprintf(stdout, "Waiting for PRU core to shutdown..\n");
#endif
	prussdrv_pru_wait_event(PRU_EVTOUT_0);
	prussdrv_pru_clear_event(PRU0_ARM_INTERRUPT);

	prussdrv_pru_disable(0);
	prussdrv_exit();
	return 0;
}
