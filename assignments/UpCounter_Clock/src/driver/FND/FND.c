#include "FND.h"

uint16_t fndNumData = 0;
uint8_t fndDotData = 0;

uint8_t FND_AddDot(uint8_t fontData, uint8_t dotMask)
{
    if (fndDotData & dotMask)
    {
        return fontData & ~SEG_PIN_DP;
    }

    return fontData | SEG_PIN_DP;
}

void FND_Init()
{
    // GPIO 설정, GPIOA 0, 1, 2, 3 COM 연결
    GPIO_SetMode(FND_COM_PORT, FND_COM_DIG_1 | FND_COM_DIG_2 | FND_COM_DIG_3 | FND_COM_DIG_4, OUTPUT);
    // GPIOB Seg, abcdefg, dp
    GPIO_SetMode(FND_FONT_PORT, SEG_PIN_A | SEG_PIN_B | SEG_PIN_C | SEG_PIN_D | SEG_PIN_E | SEG_PIN_F | SEG_PIN_G | SEG_PIN_DP, OUTPUT);
}

void FND_SetComPort(GPIO_Typedef_t *FND_Port, uint32_t Seg_Pin, int OnOFF)
{
    GPIO_WritePin(FND_Port, Seg_Pin, OnOFF);
}

void FND_DispDigit()
{
    static uint8_t fndDigState = 0;
    fndDigState = (fndDigState + 1) % 4;
    switch (fndDigState)
    {
    case 0:
        FND_DispDigit_1();
        break;
    case 1:
        FND_DispDigit_10();
        break;
    case 2:
        FND_DispDigit_100();
        break;
    case 3:
        FND_DispDigit_1000();
        break;
    default:
        FND_DispDigit_1();
        break;
    }
}

void FND_DispDigit_1()
{
    uint8_t fndFont[16] = {0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E};

    uint8_t digitData1 = fndNumData % 10;
    FND_DispALLOff();
    GPIO_WritePort(FND_FONT_PORT, FND_AddDot(fndFont[digitData1], FND_DOT_DIG_1));
    FND_SetComPort(FND_COM_PORT, FND_COM_DIG_1, ON);
}

void FND_DispDigit_10()
{
    uint8_t fndFont[16] = {0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E};

    uint8_t digitData10 = fndNumData / 10 % 10;
    FND_DispALLOff();
    GPIO_WritePort(FND_FONT_PORT, FND_AddDot(fndFont[digitData10], FND_DOT_DIG_10));
    FND_SetComPort(FND_COM_PORT, FND_COM_DIG_2, ON);
}

void FND_DispDigit_100()
{
    uint8_t fndFont[16] = {0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E};

    uint8_t digitData100 = fndNumData / 100 % 10;
    FND_DispALLOff();
    GPIO_WritePort(FND_FONT_PORT, FND_AddDot(fndFont[digitData100], FND_DOT_DIG_100));
    FND_SetComPort(FND_COM_PORT, FND_COM_DIG_3, ON);
}

void FND_DispDigit_1000()
{
    uint8_t fndFont[16] = {0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E};

    uint8_t digitData1000 = fndNumData / 1000 % 10;
    FND_DispALLOff();
    GPIO_WritePort(FND_FONT_PORT, FND_AddDot(fndFont[digitData1000], FND_DOT_DIG_1000));
    FND_SetComPort(FND_COM_PORT, FND_COM_DIG_4, ON);
}

void FND_SetNum(uint16_t num)
{
    fndNumData = num;
}

void FND_SetDotData(uint8_t dotData)
{
    fndDotData = dotData;
}

void FND_DispALLOn()
{
    FND_SetComPort(FND_COM_PORT, FND_COM_DIG_1 | FND_COM_DIG_2 | FND_COM_DIG_3 | FND_COM_DIG_4, ON);
}

void FND_DispALLOff()
{
    FND_SetComPort(FND_COM_PORT, FND_COM_DIG_1 | FND_COM_DIG_2 | FND_COM_DIG_3 | FND_COM_DIG_4, OFF);
}
