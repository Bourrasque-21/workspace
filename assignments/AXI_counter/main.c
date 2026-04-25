#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xuartlite_l.h"

#define COUNTER_BASEADDR XPAR_COUNTER_0_BASEADDR
#define UART_BASEADDR    XPAR_AXI_UARTLITE_0_BASEADDR

#define COUNTER_CONTROL_OFFSET 0x00U
#define COUNTER_VALUE_OFFSET   0x04U

#define COUNTER_CTRL_RUN       0x00000001U
#define COUNTER_CTRL_CLEAR     0x00000002U

int main()
{
    u8 ch;
    u32 count;

    xil_printf("UART Counter Control\r\n");
    xil_printf("r: run, s: stop, c: clear\r\n");

    Xil_Out32(COUNTER_BASEADDR + COUNTER_CONTROL_OFFSET, COUNTER_CTRL_CLEAR);

    while (1) {
        if (!XUartLite_IsReceiveEmpty(UART_BASEADDR)) {
            ch = XUartLite_RecvByte(UART_BASEADDR);

            if (ch == 'r') {
                Xil_Out32(COUNTER_BASEADDR + COUNTER_CONTROL_OFFSET, COUNTER_CTRL_RUN);
                xil_printf("RUN\r\n");
            } else if (ch == 's') {
                Xil_Out32(COUNTER_BASEADDR + COUNTER_CONTROL_OFFSET, 0);
                xil_printf("STOP\r\n");
            } else if (ch == 'c') {
                Xil_Out32(COUNTER_BASEADDR + COUNTER_CONTROL_OFFSET, COUNTER_CTRL_CLEAR);
                xil_printf("CLEAR\r\n");
            }

            count = Xil_In32(COUNTER_BASEADDR + COUNTER_VALUE_OFFSET);
            xil_printf("count = %d\r\n", count);
        }
    }

    return 0;
}
