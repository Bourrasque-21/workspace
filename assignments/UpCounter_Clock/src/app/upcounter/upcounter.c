#include "upcounter.h"

hBtn_t hBtnRunStop, hBtnClear;
uint16_t counter = 0;

void UpCounter_Init()
{
    FND_Init();
    Button_Init(&hBtnRunStop, GPIOA, GPIO_PIN_4);
    Button_Init(&hBtnClear, GPIOA, GPIO_PIN_7);

    counter = 0;
    FND_SetNum(counter);
}

void UpCounter_Excute()
{
    FND_SetDotData(0);
    upcounter_disploop();
    static upcounter_state_t upCounterState = STOP;

    switch (upCounterState)
    {
    case STOP:
        upcounter_stop();
        if (Button_GetState(&hBtnRunStop) == ACT_PUSHED)
        {
            upCounterState = RUN;
        }
        else if (Button_GetState(&hBtnClear) == ACT_PUSHED)
        {
            upCounterState = CLEAR;
        }
        break;
    case RUN:
        upcounter_run();
        if (Button_GetState(&hBtnRunStop) == ACT_PUSHED)
        {
            upCounterState = STOP;
        }
        break;
    case CLEAR:
        upcounter_clear();
        upCounterState = STOP;
        break;
    }
}

void upcounter_disploop()
{
    FND_DispDigit();
}

void upcounter_run()
{
    static uint32_t prevTimeCount = 0;
    if (millis() - prevTimeCount < 100 - 1)
    {
        return;
    }
    prevTimeCount = millis();
    FND_SetNum(counter++);
}

void upcounter_stop()
{
    FND_SetNum(counter);
}

void upcounter_clear()
{
    counter = 0;
    FND_SetNum(counter);
}
