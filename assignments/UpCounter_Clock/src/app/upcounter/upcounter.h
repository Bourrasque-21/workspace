/*
 * upcounter.h
 *
 *  Created on: 2026. 4. 28.
 *      Author: kccistc
 */

#ifndef SRC_APP_UPCOUNTER_UPCOUNTER_H_
#define SRC_APP_UPCOUNTER_UPCOUNTER_H_
#include <stdint.h>
#include "../../driver/FND/FND.h"
#include "../../driver/Button/Button.h"
#include "../../common/common.h"


typedef enum
{
    STOP,
    RUN,
    CLEAR
} upcounter_state_t;

void UpCounter_Init();
void UpCounter_Excute();
void upcounter_disploop();
void upcounter_run();
void upcounter_stop();
void upcounter_clear();

#endif /* SRC_APP_UPCOUNTER_UPCOUNTER_H_ */
