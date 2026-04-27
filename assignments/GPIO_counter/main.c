#include <stdint.h>
#include "xparameters.h"
#include "sleep.h"
#include "xil_printf.h"
#include "xil_io.h"

#define GPIOA_BASE_ADDR XPAR_GPIO_COUNTER_0_BASEADDR
#define GPIOB_BASE_ADDR XPAR_GPIO_COUNTER_1_BASEADDR

#define GPIO_CR_OFFSET  0x00
#define GPIO_IDR_OFFSET 0x04
#define GPIO_ODR_OFFSET 0x08

#define GPIOA_CR  (GPIOA_BASE_ADDR + GPIO_CR_OFFSET)
#define GPIOA_IDR (GPIOA_BASE_ADDR + GPIO_IDR_OFFSET)
#define GPIOA_ODR (GPIOA_BASE_ADDR + GPIO_ODR_OFFSET)

#define GPIOB_CR  (GPIOB_BASE_ADDR + GPIO_CR_OFFSET)
#define GPIOB_ODR (GPIOB_BASE_ADDR + GPIO_ODR_OFFSET)

static const uint8_t seg_lut[10] = {
    0xC0, // 0
    0xF9, // 1
    0xA4, // 2
    0xB0, // 3
    0x99, // 4
    0x92, // 5
    0x82, // 6
    0xF8, // 7
    0x80, // 8
    0x90  // 9
};

static const uint8_t an_lut[4] = {
    0x0E, // AN0
    0x0D, // AN1
    0x0B, // AN2
    0x07  // AN3
};

enum {
    BTN_RUN   = 1 << 0, // GPIOA[4]
    BTN_STOP  = 1 << 1, // GPIOA[5]
    BTN_CLEAR = 1 << 2  // GPIOA[6]
};

static uint8_t read_buttons(void)
{
    return (uint8_t)((Xil_In32(GPIOA_IDR) >> 4) & 0x0F);
}

static uint8_t debounce_buttons(void)
{
    static uint8_t stable = 0;
    static uint8_t last_sample = 0;
    static uint8_t same_count = 0;

    uint8_t sample = read_buttons();

    if (sample == last_sample) {
        if (same_count < 5) {
            same_count++;
        } else {
            stable = sample;
        }
    } else {
        last_sample = sample;
        same_count = 0;
    }

    return stable;
}

static void fnd_display(uint32_t value, uint8_t dot_on)
{
    uint8_t digits[4];

    digits[0] = value % 10;
    digits[1] = (value / 10) % 10;
    digits[2] = (value / 100) % 10;
    digits[3] = (value / 1000) % 10;

    for (int i = 0; i < 4; i++) {
        uint8_t segment = seg_lut[digits[i]];

        if (dot_on && i == 2) {
            segment &= 0x7F; // decimal point on: SS.cc
        }

        Xil_Out32(GPIOA_ODR, 0x0F);
        Xil_Out32(GPIOB_ODR, segment);
        Xil_Out32(GPIOA_ODR, an_lut[i]);
        usleep(1000);
    }
}

int main()
{
    uint32_t count_cs = 0;
    uint32_t elapsed_us = 0;
    uint32_t blink_us = 0;
    uint8_t running = 0;
    uint8_t dot_on = 1;
    uint8_t prev_buttons = 0;

    Xil_Out32(GPIOA_CR, 0x0F);
    Xil_Out32(GPIOB_CR, 0xFF);
    Xil_Out32(GPIOA_ODR, 0x0F);
    Xil_Out32(GPIOB_ODR, 0xFF);

    xil_printf("Stopwatch start\r\n");
    xil_printf("GPIOA[4]=RUN GPIOA[5]=STOP GPIOA[6]=CLEAR\r\n");

    while (1) {
        uint8_t buttons = debounce_buttons();
        uint8_t edges = buttons & (uint8_t)(~prev_buttons);
        uint8_t was_running = running;

        prev_buttons = buttons;

        if (edges & BTN_RUN) {
            running = 1;
            dot_on = 1;
            blink_us = 0;
            xil_printf("RUN\r\n");
        }

        if (edges & BTN_STOP) {
            running = 0;
            dot_on = 1;
            blink_us = 0;
            xil_printf("STOP\r\n");
        }

        if ((edges & BTN_CLEAR) && !was_running && !(edges & BTN_RUN)) {
            count_cs = 0;
            elapsed_us = 0;
            dot_on = 1;
            blink_us = 0;
            xil_printf("CLEAR\r\n");
        }

        if (running) {
            elapsed_us += 4000;
            blink_us += 4000;

            if (blink_us >= 500000) {
                blink_us -= 500000;
                dot_on = !dot_on;
            }

            while (elapsed_us >= 10000) {
                elapsed_us -= 10000;
                count_cs++;

                if (count_cs > 9999) {
                    count_cs = 0;
                }
            }
        } else {
            dot_on = 1;
            blink_us = 0;
        }

        fnd_display(count_cs, dot_on);
    }

    return 0;
}
