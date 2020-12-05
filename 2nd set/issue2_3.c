#include <avr/io.h>
#include <avr/interrupt.h>

char tmp,b,a;
//PD2 για ΙΝΤ0 interrupt
ISR (INT0_vect)				//External interrupt_zero ISR
{	
	tmp = 0;
	b = PINB;
	a = PINA;
	int i;
	if((a & 0x04) != 0x04 ){	//Αν είναι off το Α2
		for( i=0; i<8;i++){		//8 επαναλήψεις για 8 bit
			if(b & 1){			//Αν bit0 του pinB = 1
				if(tmp == 0)	//Την πρώτη φορά
					tmp = 1;	
				else{			//τις υπόλοιπες
					tmp = tmp << 1;	//αριστερή ολίσθηση
					tmp += 1;	//και πρόσθεση του bit0
				}
			}
			b = b >> 1;			//Έλεγξε επόμενο bit του PINB
			PORTC = tmp;		//Απεικόνισε στην έξοδο C
		}
	}else{						//Αν Α2 ON
		for (i=0; i<8; i++){
			if(b & 1){			//Αν bit0 του pinB = 1
				tmp += 1;	
			}
			b = b >> 1;			//Επόμενο bit
			PORTC = tmp;		//Απεικόνισε στην έξοδο C
		}
	}
}
int main(void)
{
	DDRC = 0xff;	//Στο portC η έξοδος
	DDRB = 0x00;	//B είναι είσοδος
	DDRA = 0x00;	
	GICR=0x40;		//Enable external interrupt INT0
	MCUCR = 0x03;	//διακοπή στην ανερχόμενη ακμή
	sei();
    while (1) 
    {
		b = PINB;
		a = PINA;
		PORTC = tmp;
		
	}
}
