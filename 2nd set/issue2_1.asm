
.include "m16def.inc"

reset:	ldi r24,low(RAMEND)	;αρχικοποίηση στοίβας
		out SPL,r24
		ldi r24,high(RAMEND)
		out SPH,r24

		ldi r24,0x00
		out DDRC,r24		; PORTC είσοδος
		ldi r24,0x03
		out DDRB,r24		;2LSB της PORTB η έξοδος

		in r24,PINC			;στον r24 κρατάμε την είσοδο
		andi r24,0x0F		;Κάνουμε mask 4 LSB
		mov r25,r24
		andi r25,0x01		;r25=A
		mov r26,r24
		andi r26,0x02		;mask το 2ο lsb
		lsr r26				;r26 = B
		mov r27,r24			
		andi r27,0x04		;mask το 3ο lsb
		lsr r27				;2 shifts right
		lsr r27				;r27 = C
		mov r28,r24
		andi r28,0x08		;mask το 4ο lsb
		lsr r28				;3 shifts right
		lsr r28
		lsr r28				;r28 = D

		ldi r29,1			;constant for xor - για συμπλήρωμα του bit0
		mov r30,r25
		eor r30,r29			;συμπλήρωμα bit0 only
		and r30,r26			;R30 = A'B
		mov r31,r26
		eor r31,r29
		and r31,r27			;B'C
		and r31,r28			;B'CD
		or r30,r31
		eor r30,r29			;(A'B + B'CD)'

		and r25,r27			;AC
		or r26,r28			;B+D
		and r25,r26			;F1 = (AC)(B+D)
		lsl r25				;στο bit1 από bit0 για απεικόνιση του F1
		or r30,r25	
		out PORTB,r30
		
