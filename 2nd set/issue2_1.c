#include <avr/io.h>

char a,b,c,d,f1,f0;

int main(void)
{	
	DDRB = 0x03;		//Αρχικοποίηση 2lsb PORTB ως output
	DDRC = 0x00;		//Αρχικοποίηση PORTC ως input 
    /* Replace with your application code */
    while (1) 
    {
		a = PINC & 0x01;
		b = PINC & 0x02;
		b = b >> 1;		// Μεταφορά ψηφίου στην θέση 0
		
		c = PINC & 0x04;
		c = c >> 2;		// Μεταφορά ψηφίου στην θέση 0
		
		d = PINC & 0x08;
		d = d >> 3;		// Μεταφορά ψηφίου στην θέση 0
		
		f0 = ((((a ^ 0x01) & b ) | ((b ^ 0x01) & c & d)) ^ 0x01) ;
		f1 = (a & c) & (b | d) ;
		PORTB = f0 | (f1 << 1) ;
    }
}
