#ifndef SRC_DEIVER_FND_FND_H_
#define SRC_DEIVER_FND_FND_H_

#include "../../HAL/GPIO/GPIO.h"

#define FND_FONT_PORT GPIOB
#define FND_COM_PORT GPIOA

#define FND_COM_DIG_1 GPIO_PIN_0
#define FND_COM_DIG_2 GPIO_PIN_1
#define FND_COM_DIG_3 GPIO_PIN_2
#define FND_COM_DIG_4 GPIO_PIN_3

#define SEG_PIN_A GPIO_PIN_0
#define SEG_PIN_B GPIO_PIN_1
#define SEG_PIN_C GPIO_PIN_2
#define SEG_PIN_D GPIO_PIN_3
#define SEG_PIN_E GPIO_PIN_4
#define SEG_PIN_F GPIO_PIN_5
#define SEG_PIN_G GPIO_PIN_6
#define SEG_PIN_DP GPIO_PIN_7

#define FND_DOT_DIG_1 (1 << 0)
#define FND_DOT_DIG_10 (1 << 1)
#define FND_DOT_DIG_100 (1 << 2)
#define FND_DOT_DIG_1000 (1 << 3)

#define ON 0
#define OFF 1

void FND_Init();
void FND_SetComPort(GPIO_Typedef_t *FND_Port, uint32_t Seg_Pin, int OnOFF);
void FND_DispDigit();
void FND_DispDigit_1();
void FND_DispDigit_10();
void FND_DispDigit_100();
void FND_DispDigit_1000();
void FND_SetNum(uint16_t num);
void FND_SetDotData(uint8_t dotData);
void FND_DispALLOn();
void FND_DispALLOff();


#endif /* SRC_DEIVER_FND_FND_H_ */
