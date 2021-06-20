// From memory-map
#define GPIO_SWs    0x80001400
#define GPIO_LEDs   0x80001404
#define GPIO_INOUT  0x80001408

#define DELAY   0x200000

//define basic read-write macros
#define READ_GPIO(addr) (*(volatile unsigned*)addr)
#define WRITE_GPIO(addr, value) { (*(volatile unsigned *)addr) = (value);}

int main(void) 
{
    volatile unsigned ddr_value=0xFFFF, switches_val, temp, ones_sum = 0, previous_msb = 0;
    volatile int i, timer;
    WRITE_GPIO(GPIO_INOUT, ddr_value);

    previous_msb = READ_GPIO(GPIO_SWs); 
    //read msbit
    previous_msb &= 0x80000000;
    while (1) {
        do {
        switches_val = READ_GPIO(GPIO_SWs);
        ;
        } while ((switches_val & 0x80000000) == previous_msb);
        //Update msbit 
        previous_msb = switches_val & 0x80000000;
        switches_val = switches_val >> 16;
        switches_val &= 0xFFFF;
        switches_val ^= 0xFFFF; 
        temp = switches_val;

        ones_sum = 0;
        for (i=0; i<16; i++) {
            if (temp & 0x1) {
                ones_sum ++;
            }
            temp =  temp >> 1;
        }

        for (i=1; i<=ones_sum; i++) {
            timer = 0;
            WRITE_GPIO(GPIO_LEDs, switches_val);
            while(timer < DELAY) {
                timer++;
            }
            timer = 0;
            WRITE_GPIO(GPIO_LEDs, 0);
            while(timer < DELAY) {
                timer++;
            }
        }
    }
    return 0;
}