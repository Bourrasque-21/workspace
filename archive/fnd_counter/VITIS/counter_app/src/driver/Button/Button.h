/*
 * Button.h
 *
 *  Created on: 2026. 4. 28.
 *      Author: kccistc
 */

#ifndef SRC_DRIVER_BUTTON_BUTTON_H_
#define SRC_DRIVER_BUTTON_BUTTON_H_

#include <stdint.h>
#include "../../HAL/GPIO/GPIO.h"
#include "../../common/common.h"



typedef enum
{
    RELEASED = 0,
    PUSHED,
    ACT_RELEASED,
    ACT_PUSHED,
    NO_ACT
} button_state_t;

typedef struct
{
    GPIO_Typedef_t *GPIOx;
    uint32_t GPIO_Pin;
    button_state_t prevState;
} hBtn_t;

void Button_Init(hBtn_t *hbtn, GPIO_Typedef_t *GPIOx, uint32_t GPIO_Pin);
button_state_t Button_GetState(hBtn_t *hbtn);


#endif /* SRC_DRIVER_BUTTON_BUTTON_H_ */
