#include "app/app_main.h"
#include "xil_printf.h"

int count = 0;

int main()
{
    xil_printf("FND Counter Test08\r\n");
    ap_init();
    while (1)
    {
        ap_excute();
    }

    return 0;
}
