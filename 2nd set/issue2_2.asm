
.include "m16def.inc"
		.org 0x0					;Εδω ξεκινάει το πρόγραμμα
		rjmp reset
		.org 0x4					;Διεύθυνση της INT1 
		rjmp ISR1
ISR1:
		push r26 			; Σώσε το περιεχόμενο των r26
		in r26,SREG 		; και SREG
		push r26
		in r26,PINA			;Έλεγχος 2 msb PortA
		andi r26,0xC0		;mask A7 και Α6
		cpi r26,0xC0
		brne no_inc			;Αν δεν είναι λογικό '1' κάνε skip
		inc r27 			; αλλιώς αύξησε τον μετρητή των διακοπών
no_inc:
		pop r26
		out SREG,r26 ; καταχωρητών r24 και SREG
		pop r26
		reti ; Επιστροφή από διακοπή στο κύριο πρόγραμμα	
reset:	
		ldi r24, (1 << ISC11 )|(1 << ISC10)	 ;ορίζεται η διακοπή INT1 να
		out MCUCR , r24						; προκαλείται με σήμα θετικής ακμής
		ldi r24,(1 << INT1)		;Ενεργοποίησε τη διακοπή INT0
		out GICR, r24
		sei						;Ενεργοποίηση συνολικών διακοπών
		ldi r24,low(RAMEND)		;Αρχικοποίηση διεύθυνσης στοίβας
		out SPL,r24
		ldi r24,high(RAMEND)
		out SPH,r24

		ser r26					; αρχικοποίηση της PORTC
		out DDRC,r26			; για έξοδο
		out DDRB,r26			;PORTB το πλήθος των διακοπών
		clr r26					; αρχικοποίηση του μετρητή
		clr r27					;Μετρητής διακοπών
		out DDRA,r26			;A7-A6 input switches για ελεγχο αύξησης
loop:	out PORTC,r26			; Δείξε την τιμή του μετρητή στη θύρα εξόδου των LED
		out PORTB,r27
		inc r26					; Αύξησε τον μετρητή
		rjmp loop				; Επανέλαβε
	
ISR1:
