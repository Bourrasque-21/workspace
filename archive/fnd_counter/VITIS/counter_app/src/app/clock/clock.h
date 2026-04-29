/*
 * clock.h
 *
 *  Created on: 2026. 4. 28.
 *      Author: kccistc
 */

#ifndef SRC_APP_CLOCK_CLOCK_H_
#define SRC_APP_CLOCK_CLOCK_H_

#include <stdint.h>
#include "../../driver/FND/FND.h"
#include "../../driver/Button/Button.h"
#include "../../common/common.h"

typedef enum
{
    CLOCK_DISP_HHMM,
    CLOCK_DISP_SSCC
} clock_display_mode_t;

void Clock_Init();
void Clock_Execute();
void Clock_DispLoop();
void Clock_UpdateTime();
void Clock_UpdateDisplay();

#endif /* SRC_APP_CLOCK_CLOCK_H_ */
