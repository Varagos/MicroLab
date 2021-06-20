// From memory-map
#define GPIO_SWs    0x80001400
#define GPIO_LEDs   0x80001404
#define GPIO_INOUT  0x80001408

//define basic read-write macros
#define READ_GPIO(addr) (*(volatile unsigned*)addr)
#define WRITE_GPIO(addr, value) { (*(volatile unsigned *)addr) = (value);}

int main(void) 
{
    volatile unsigned ddr_value=0xFFFF, msb_val, lsb_val, sum;

    WRITE_GPIO(GPIO_INOUT, ddr_value);
    while (1) {
        msb_val = READ_GPIO(GPIO_SWs);
        msb_val = msb_val >> 28;
        lsb_val = READ_GPIO(GPIO_SWs);
        lsb_val = lsb_val >> 16;
        sum = (msb_val & 0xF) + (lsb_val & 0xF);
        if (sum < 16) {
           WRITE_GPIO(GPIO_LEDs, sum);
        } else {
            WRITE_GPIO(GPIO_LEDs, 0x10);
        }

    }
    return 0;
}