#include "app_main.h"
#include "../driver/FND/FND.h"
#include "../driver/Button/Button.h"
#include "../common/common.h"
#include "upcounter/upcounter.h"
#include "clock/clock.h"

typedef enum
{
    APP_UPCOUNTER,
    APP_CLOCK
} app_mode_t;

hBtn_t hBtnAppMode;

void ap_init()
{
    Button_Init(&hBtnAppMode, GPIOA, GPIO_PIN_5);
    UpCounter_Init();
    Clock_Init();
}

void ap_excute()
{
    static app_mode_t appMode = APP_UPCOUNTER;

    if (Button_GetState(&hBtnAppMode) == ACT_PUSHED)
    {
        appMode = (appMode == APP_UPCOUNTER) ? APP_CLOCK : APP_UPCOUNTER;
    }

    switch (appMode)
    {
    case APP_UPCOUNTER:
        UpCounter_Excute();
        break;
    case APP_CLOCK:
        Clock_Execute();
        break;
    }

    millis_inc();
    delay_ms(1);
}
