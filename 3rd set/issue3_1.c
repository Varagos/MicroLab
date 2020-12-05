#define F_CPU 8000000UL  // 8 MHz
#define _NOP() do { __asm__ __volatile__ ("nop"); } while (0)
// used for a very short delay

#include <util/delay.h>
#include <avr/io.h>

uint8_t swapNibbles(uint8_t x);
uint8_t scan_row_sim(uint8_t r24);
uint16_t scan_keypad_sim();
uint16_t scan_keypad_rising_edge_sim(uint16_t *tmp_p);
uint8_t keypad_to_ascii_sim(uint16_t r25r24);


int main(void)
{
	DDRB = 0xFF;	//Port B as output
	DDRC = 0xF0;	//4 msb as outputs and 4 lsb as inputs
	int i;			//for counter
	uint16_t tmp = 0;			//initial temp state
	uint16_t *tmp_p = &tmp;		//memory adress for states
	while (1)
	{	
		uint8_t asci_val[2];	
		for(i=0; i<2; i++)		//we read 2 numbers
		{
			*tmp_p = 0;			
			uint16_t ret_value = 0x0000;
			while(ret_value == 0x0000)	
			{
				//function will return != 0 on new keypad press
				ret_value = scan_keypad_rising_edge_sim(tmp_p);
			}
			asci_val[i] = keypad_to_ascii_sim(ret_value);	//convert to ascii
		}

		scan_keypad_rising_edge_sim(tmp_p);			//extra call for X2go system
		
		if (asci_val[0] == 0x30 && asci_val[1] == 0x33)
		{
			PORTB = 0xFF;			//LEDS ON
			for(i=0; i<4; i++)		// 4 sec delay
			{
				_delay_ms(1000);
			}
			PORTB = 0x00;			//LEDS OFF
		}else
		{	//otherwise alternating leds
			for(i=0; i<4; i++)
			{
				PORTB = 0xFF;
				_delay_ms(500);
				PORTB = 0x00;
				_delay_ms(500);
			}	
		}		
	}
}
uint8_t swapNibbles(uint8_t x)
{
	return ((x & 0x0F) << 4 | (x & 0xF0) >> 4);
}

uint8_t scan_row_sim(uint8_t r24)	// checks 1 keyboard line & returns state
{
	PORTC = r24 & 0xF0;			// ! r25 in asm 
	_delay_us(500);	
	_NOP();
	_NOP();
	r24 = PINC & 0x0F;
	return r24;
}

uint16_t scan_keypad_sim()
{
	uint16_t r2524 ;			//1 bit for each keyboard button
	uint8_t r25 = 0x10;			// scan first line (1-2-3-A)
	uint8_t r24 ;
	uint8_t r27;
	uint8_t r26;
	r24 = scan_row_sim(r25);
	r24 = swapNibbles(r24);		//move 4 lsb to msb
	r27 = r24;					//save to r27
	r25 = 0x20;					//scan 2nd line (4-5-6-B)
	r24 = scan_row_sim(r25);
	r27 |= r24;					//same as += here 
	r25 = 0x40;					//scan 3rd line (7-8-9-C)
	r24 = scan_row_sim(r25);
	r24 = swapNibbles(r24);	
	r26 = r24;					//save to r26
	r25	= 0x80;					//scan 4th line
	r24 = scan_row_sim(r25);
	r26 |= r24;
	
	r24 = r26;
	r25 = r27;
	r2524 = ((uint16_t)r25 << 8 ) | r24; //combine 2 8bit to 1 16bit
	
	r26 = 0x00;					//added for distance access
	PORTC = r26;
	return r2524;
}

uint16_t scan_keypad_rising_edge_sim(uint16_t *tmp_p)		//address of tmp
{
	uint16_t s1 = scan_keypad_sim();
	_delay_ms(15);				//typical values are 10-20msec-(spinthirismos)
	uint16_t s2 = scan_keypad_sim();
	s2 &= s1;					// AND 2 results => current state 
	//we must save new state of buttons
	//equivalent of store
	s1 = *tmp_p;				// load previous state from memory
	(*tmp_p) = s2;				//save current state of buttons to memory
	
	s1 = ~s1;			//1's COM of previous state
	s2 &= s1;			//and with current state
	return s2;
}

uint8_t keypad_to_ascii_sim(uint16_t r25r24)
{
	uint8_t value;
	if (r25r24 &0x0001)
	{	
		value = 0x2A;		//*
	}else if (r25r24 &0x0002)
	{
		value = 0x30;		//0
	}else if (r25r24 &0x0004)
	{
		value = 0x23;		//#
	}else if (r25r24 &0x0008)
	{
		value = 0x44;		//D
	}else if (r25r24 &0x0010)
	{
		value = 0x37;		//7
	}else if (r25r24 &0x0020)
	{
		value = 0x38;		//8
	}else if (r25r24 &0x0040)
	{
		value = 0x39;		//9
	}else if (r25r24 &0x0080)
	{
		value = 0x43;		//C
	}else if (r25r24 &0x0100)
	{
		value = 0x34;		//4
	}else if (r25r24 &0x0200)
	{
		value = 0x35;		//5
	}else if (r25r24 &0x0400)
	{
		value = 0x36;		//6
	}else if (r25r24 &0x0800)
	{
		value = 0x42;		//B
	}else if (r25r24 &0x1000)
	{
		value = 0x31;		//1
	}else if (r25r24 &0x2000)
	{
		value = 0x32;		//2
	}else if (r25r24 &0x4000)
	{
		value = 0x33;		//3
	}else if (r25r24 &0x8000)
	{
		value = 0x41;		//A
	}else 
	{
		value =0x00;		//if nothing is pressed
	}
  return value;
	
}
