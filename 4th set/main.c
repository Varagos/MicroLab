/*
 * zitima5_2.c
 *
 * Created: 7/12/2020 5:03:42 μμ
 * Author : user
 */ 
#define F_CPU 8000000UL	//8MHz
#define _NOP() do { __asm__ __volatile__ ("nop"); } while (0)
// used for a very short delay
#define PPM35 0x0071			//Immediate to compare with
#define PPM70 0x00CD			//conversion of ADC
#define PPM105 0x012A
#define PPM140 0x0186
#define PPM175 0x01E2
#define PPM210 0x023F

#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>



uint8_t swapNibbles(uint8_t x);
uint8_t scan_row_sim(uint8_t r24);
uint16_t scan_keypad_sim();
uint16_t scan_keypad_rising_edge_sim(uint16_t *tmp_p);
uint8_t keypad_to_ascii_sim(uint16_t r25r24);
void adc_init();
uint8_t find_gas_level(uint16_t temp_gas);
void lcd_init_sim();
void lcd_command_sim(uint8_t r24);
void lcd_data_sim(uint8_t r24);
void write_2_nibbles(uint8_t r24);
void LCD_String (char *str);




	volatile uint8_t gas_level;
	volatile uint8_t conversion_complete = 0;	//flag				
int main(void)
{	
	DDRB = 0xFF;								//PortB as output
	DDRC = 0xF0;								//PortC used by keypad
	DDRD = 0xFF;								//PortD for lcd display
	lcd_init_sim();
	TIMSK |= (1<<TOIE1);						// enable overflow interrupt
	TCCR1B |= (0<<CS12)|(1<<CS11)|(1<<CS10);	//011 for CK/64 =>125KHz	
	adc_init();
	uint16_t tmp = 0;							//initial temp state
	uint16_t *tmp_p = &tmp;						//memory address of state
	gas_level = 0;
	uint8_t asci_val[2];
	int i = 0;
    while (1) 
    {
		cli();
		TCNT1 = 0xCF2C;							//Initialize counter
		sei();
		conversion_complete = 0;
		if(gas_level > 0x02) {
			PORTB = 0x00;						//blink
			_delay_ms(35);						
			PORTB = gas_level;
		}
		
		while(!conversion_complete){
			*tmp_p =0;							//
			uint16_t ret_value = 0;
			ret_value = scan_keypad_rising_edge_sim(tmp_p);
			if (ret_value) {
				scan_keypad_rising_edge_sim(tmp_p);		//called for simulation X2go
				asci_val[i] = keypad_to_ascii_sim(ret_value);
				if(i==1) {						//if we read 2nd number
					i = 0;						//reinitialize counter
					if (asci_val[0] == 0x30 && asci_val[1] == 0x33) {//right code
						cli();				//disable interrupts for 4 seconds
						lcd_command_sim(0x01);		//clear display
						_delay_us(1530);
						LCD_String("WELCOME");
						if(gas_level <= 0x02) {
							PORTB = gas_level | 0x80;
						}else {
							PORTB = 0x80;
						}
						for(int p=0;p<4;p++){
							_delay_ms(1000);
						}
						//clear screen and PB7
						if(gas_level <=0x02){
							PORTB = gas_level;
						}else{
							PORTB = 0;
						}
						lcd_command_sim(0x01);		//clear display
						_delay_us(1530);
						gas_level = 0;		//initialize so we can detect it afterwards
						sei();
						break;				//break loop and restart counter
					}else { //wrong code entered	
						cli();
						//uint8_t blink_helper;
						for(int p=0;p<40;p++){
							cli();
							TCNT1 = 0xCF2C;							//Initialize counter
							sei();
							conversion_complete = 0;					
							while(!conversion_complete);
							uint16_t temp_gas = ADC;
							uint8_t gas_val = find_gas_level(temp_gas);
							PORTB = gas_val;
							uint8_t  previous_gas_level = gas_level;
							gas_level = gas_val;
							if(previous_gas_level < 0x04 && gas_level > 0x02){
								lcd_command_sim(0x01);		//clear display
								_delay_us(1530);
								LCD_String("GAS DETECTED");
								}else if(previous_gas_level > 0x02 && gas_level < 0x04){
								lcd_command_sim(0x01);		//clear display
								_delay_us(1530);
								LCD_String("CLEAR");
							}
							//if (ADC < PPM70)
							if (gas_val > 0x02) {
								gas_val = p % 2 ? gas_val : 0;	//ON every even integral of 100ms
							}
							if(p<5 || (p>= 10 && p<15) || (p>=20 && p<25) || (p>=30 && p<35)){
								PORTB = gas_val | 0x80;		//PB7 ON
							}else {
								PORTB = gas_val;
							}
						}
						sei();
						break;
					}
				}else {							//we read 1st number
					i++;
				}
			}
		}
		//conversion complete here
		uint16_t temp_gas = ADC;
		uint8_t gas_val = find_gas_level(temp_gas);
		PORTB = gas_val;
		uint8_t  previous_gas_level = gas_level;
		gas_level = gas_val;
		if(previous_gas_level < 0x04 && gas_level > 0x02){
			lcd_command_sim(0x01);		//clear display
			_delay_us(1530);
			LCD_String("GAS DETECTED");
		}else if(previous_gas_level > 0x02 && gas_level < 0x04){
			lcd_command_sim(0x01);		//clear display
			_delay_us(1530);
			LCD_String("CLEAR");
		}
		
	}
}

ISR(TIMER1_OVF_vect)
{	
	ADCSRA |= (1<<ADSC);						//start adc conversion
	while(ADCSRA & (1<<ADSC));					//wait for conversion to complete
	//uint16_t temp_gas = ADC;
	conversion_complete = 1;
	
}

void adc_init()
{	//Vref=Vcc
	ADMUX |= (1<<REFS0);		
	/*ADC enable and set prescaler 128	
	8Mhz/128 = 62.5 KHz	*/		
	ADCSRA |= (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0);		
}


uint8_t find_gas_level(uint16_t temp_gas)
{
	uint8_t val;
	if(temp_gas < PPM35) {
		val = 0x01;
		}else if(temp_gas < PPM70) {
		val = 0x02;
		}else if(temp_gas < PPM105) {
		val = 0x04;
		}else if(temp_gas < PPM140) {
		val = 0x08;
		}else if(temp_gas < PPM175) {
		val = 0x10;
		}else if(temp_gas < PPM210) {
		val = 0x20;
		}else {
		val = 0x40;
	}
	return val;
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
		return value;
	}else if (r25r24 &0x0002)
	{
		value = 0x30;		//0
		return value;
	}else if (r25r24 &0x0004)
	{
		value = 0x23;		//#
		return value;
	}else if (r25r24 &0x0008)
	{
		value = 0x44;		//D
		return value;
	}else if (r25r24 &0x0010)
	{
		value = 0x37;		//7
		return value;
	}else if (r25r24 &0x0020)
	{
		value = 0x38;		//8
		return value;
	}else if (r25r24 &0x0040)
	{
		value = 0x39;		//9
		return value;
	}else if (r25r24 &0x0080)
	{
		value = 0x43;		//C
		return value;
	}else if (r25r24 &0x0100)
	{
		value = 0x34;		//4
		return value;
	}else if (r25r24 &0x0200)
	{
		value = 0x35;		//5
		return value;
	}else if (r25r24 &0x0400)
	{
		value = 0x36;		//6
		return value;
	}else if (r25r24 &0x0800)
	{
		value = 0x42;		//B
		return value;
	}else if (r25r24 &0x1000)
	{
		value = 0x31;		//1
		return value;
	}else if (r25r24 &0x2000)
	{
		value = 0x32;		//2
		return value;
	}else if (r25r24 &0x4000)
	{
		value = 0x33;		//3
		return value;
	}else if (r25r24 &0x8000)
	{
		value = 0x41;		//A
		return value;
	}else 
	{
		value =0x00;		//if nothing is pressed
		return value;
	}
	
	
}
// 
// void LCD_Init (void)	/* LCD Initialize function */
// {
// 	LCD_Command_Dir = 0xFF;	/* Make LCD command port direction as o/p */
// 	LCD_Data_Dir = 0xFF;	/* Make LCD data port direction as o/p */
// 
// 	_delay_ms(20);		/* LCD Power ON delay always >15ms */
// 	LCD_Command (0x38);	/* Initialization of 16X2 LCD in 8bit mode */
// 	LCD_Command (0x0C);	/* Display ON Cursor OFF */
// 	LCD_Command (0x06);	/* Auto Increment cursor */
// 	LCD_Command (0x01);	/* clear display */
// 	LCD_Command (0x80);	/* cursor at home position */
// }
// 
// void LCD_Command(unsigned char cmnd)
// {
// 	LCD_Data_Port= cmnd;
// 	LCD_Command_Port &= ~(1<<RS);	/* RS=0 command reg. */
// 	LCD_Command_Port &= ~(1<<RW);	/* RW=0 Write operation */
// 	LCD_Command_Port |= (1<<EN);	/* Enable pulse */
// 	_delay_us(1);
// 	LCD_Command_Port &= ~(1<<EN);
// 	_delay_ms(3);
// }
// 
// void LCD_Char (unsigned char char_data)	/* LCD data write function */
// {
// 	LCD_Data_Port = char_data;
// 	LCD_Command_Port |= (1<<RS);	/* RS=1 Data reg. */
// 	LCD_Command_Port &= ~(1<<RW);	/* RW=0 write operation */
// 	LCD_Command_Port |= (1<<EN);	/* Enable Pulse */
// 	_delay_us(1);
// 	LCD_Command_Port &= ~(1<<EN);
// 	_delay_ms(1);
// }
// 
void LCD_String (char *str)
{
	int i;
	for(i=0;str[i]!=0;i++)  /* send each char of string till the NULL */
	{
		lcd_data_sim (str[i]);  /* call LCD data write */
	}
}

void write_2_nibbles(uint8_t r24)
{
	_delay_us(6000);
	uint8_t r25;
	uint8_t r24copy = r24;
	r25 = PIND & 0x0F;		//read previous state to resend it
	r24 &= 0xF0;			//we send 4 msb first
	r24 += r25 ;
	PORTD = r24 ;
	PORTD |= 0x08;			//send Enable signal on PD3
	PORTD &= 0xF7;			// equals to sbi and cbi PD3
	
	_delay_us(6000);
	r24 = (r24copy << 4) & 0xF0 ;	//we send 4 lsb now
	r25 = PIND & 0x0F;
	r24 += r25;
	PORTD = r24;
	PORTD |= 0x08;			//new enable signal
	PORTD &= 0xF7;			
	return ;
}

void lcd_data_sim(uint8_t r24)	//we send 1 byte
{
	PORTD |= 0x04;			//PD=1 for data
	write_2_nibbles(r24);	//send byte
	_delay_us(43);
	return;
}

void lcd_command_sim(uint8_t r24)	//we send 1 byte
{
	PORTD &= 0xFB;			//PD=0 for command
	write_2_nibbles(r24);	//send byte
	_delay_us(39);
	return;
}	

void lcd_init_sim()
{
	_delay_ms(40);
	PORTD = 0x30;			//command for 8 bit mode
	PORTD |= 0x08;			//send Enable signal on PD3
	PORTD &= 0xF7;			
	_delay_us(39);
	_delay_us(1000);		//because of simulation
	
	PORTD = 0x30;			//we send the command twice because we cant be sure
	PORTD |= 0x08;			//about initial mode
	PORTD &= 0xF7;
	_delay_us(39);
	_delay_us(1000);
	
	PORTD = 0x20;			//change to 4bit mode
	PORTD |= 0x08;			//send Enable signal on PD3
	PORTD &= 0xF7;
	_delay_us(39);
	_delay_us(1000);	
	
	lcd_command_sim(0x28);	//5*8 dots and 2 lines
	lcd_command_sim(0x0c);	//enable screen, hide cursor
	lcd_command_sim(0x01);  //clear display
	
	_delay_us(1530);
	
	lcd_command_sim(0x06);
	//enable automatic address increment
	//and disable total display shifting	
	return;
}