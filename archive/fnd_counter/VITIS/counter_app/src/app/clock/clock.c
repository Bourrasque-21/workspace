#include "clock.h"

#define CLOCK_INIT_HOUR 23
#define CLOCK_INIT_MIN 59
#define CLOCK_INIT_SEC 50
#define CLOCK_INIT_CSEC 0

hBtn_t hBtnDisplayMode;

uint8_t clockHour = CLOCK_INIT_HOUR;
uint8_t clockMin = CLOCK_INIT_MIN;
uint8_t clockSec = CLOCK_INIT_SEC;
uint8_t clockCsec = CLOCK_INIT_CSEC;

void Clock_Init()
{
    FND_Init();
    Button_Init(&hBtnDisplayMode, GPIOA, GPIO_PIN_6);
    FND_SetDotData(0);
    Clock_UpdateDisplay();
}

void Clock_Execute()
{
    static clock_display_mode_t displayMode = CLOCK_DISP_HHMM;
    static uint32_t prevTimeDot = 0;
    static uint8_t dotState = 0;

    Clock_DispLoop();
    Clock_UpdateTime();

    if (Button_GetState(&hBtnDisplayMode) == ACT_PUSHED)
    {
        displayMode = (displayMode == CLOCK_DISP_HHMM) ? CLOCK_DISP_SSCC : CLOCK_DISP_HHMM;
    }

    if (millis() - prevTimeDot >= 500)
    {
        prevTimeDot = millis();
        dotState ^= 1;
    }

    FND_SetDotData(dotState ? FND_DOT_DIG_100 : 0);

    switch (displayMode)
    {
    case CLOCK_DISP_HHMM:
        FND_SetNum(clockHour * 100 + clockMin);
        break;
    case CLOCK_DISP_SSCC:
        FND_SetNum(clockSec * 100 + clockCsec);
        break;
    }
}

void Clock_DispLoop()
{
    FND_DispDigit();
}

void Clock_UpdateTime()
{
    static uint32_t prevTimeClock = 0;

    if (millis() - prevTimeClock < 10)
    {
        return;
    }

    prevTimeClock = millis();

    clockCsec++;
    if (clockCsec >= 100)
    {
        clockCsec = 0;
        clockSec++;
    }

    if (clockSec >= 60)
    {
        clockSec = 0;
        clockMin++;
    }

    if (clockMin >= 60)
    {
        clockMin = 0;
        clockHour++;
    }

    if (clockHour >= 24)
    {
        clockHour = 0;
    }
}

void Clock_UpdateDisplay()
{
    FND_SetNum(clockHour * 100 + clockMin);
}
