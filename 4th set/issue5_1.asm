;
; zitima5_1.asm
;
; Created: 6/12/2020 3:18:42 μμ
; Author : user
;
.include "m16def.inc"


.DSEG
_tmp_: .byte 2
gas_level: .byte 1
.equ ppm35 = 0x0071			;Immediate to compare with
.equ ppm70 = 0x00CD			;conversion of ADC
.equ ppm105 = 0x012A
.equ ppm140 = 0x0186
.equ ppm175 = 0x01E2
.equ ppm210 = 0x023F
.def c_tmp=r18 


.CSEG
.org 0x00
	rjmp reset				;program starts here
.org 0x10
	rjmp ISR_TIMER1_OVF		;counter1 interrupt routine
.org 0x1C					
	rjmp new_metric			;when ADC converts


reset:
	ldi r24,low(RAMEND)		;initialize stack
	out SPL,r24
	ldi r24,high(RAMEND)
	out SPH,r24

	ser r24
	out DDRD,r24			;PORTD connected to display,intialized as output
	clr r24
	rcall lcd_init_sim		;routine for display initialization

	ser r24
	out DDRB,r24			;PORTB is output
	ldi r24,0xF0
	out DDRC,r24			;4 msb as output,rest as input for keypad usage
	
	ldi r24,(1<<TOIE1)		;Enable counter1 overflow interrupt
	out TIMSK,r24			
	ldi r24,(0<<CS12)|(1 << CS11)|(1 << CS10)	;CK/64=125000Hz
	out TCCR1B,r24			;control register of counter1
	rcall ADC_init			;initialize ADC-enable ADC interrupt
	clr r16
	ldi r30 ,low(gas_level)	;connect Z register with gas_level
	ldi r31 ,high(gas_level);address
	st Z, r16				;iniatilize gas_level
	ldi r20,2				;counter for 2 numbers
repeat_loop:
	cli						;global interrupt disable
	ldi r24,0xCF			;interrupt after 100ms
	out TCNT1H,r24			;read with interrupts disabled
	ldi r24,0x2C
	out TCNT1L,r24
	sei						;Enable interrupts(I<-1)
	
	ld r16,Z				;check if previous level > 70ppm
	cpi r16,0x04			;if true then blink
	brlo skip_blink
	ldi r24 ,35				;30 ms
	ldi r25 ,0 
	out PORTB,r25
	rcall wait_msec	
	out PORTB,r16

skip_blink:
	ser r21
	clr r25
	clr r24					
wait_loop:					;loop while r21 set
	rcall scan_keypad_rising_edge_sim	;keypad state in r25-r24
	cpi r25,0x00			;compare with zero
	brne valid				;to catch first keypad press
	cpi r24,0x00
	brne valid				;if key pressed then jump
	rjmp no_press			;else continue reading

valid:
	rcall keypad_to_ascii_sim
	push r24				;save pressed number into stack
	dec r20					;decrease number counter
	sbrc r20,0				;skip next comm if we have 2 numbers
	rjmp wait_loop
	ldi r20,2				;set counter to 2 again
	pop r23					;pop 2nd number
	pop r22					;1st number
	rcall scan_keypad_rising_edge_sim	;needed for simulation
	cpi r22,'0'				;compare with team nb - 03
	brne wrong_code
	cpi r23,'3'
	brne wrong_code
	;welcome 03
	cli						;disable interrupts for 4 sec
	ldi r24,0x01			; clear display screen
	rcall lcd_command_sim
	ldi r24, low(1530)		
	ldi r25, high(1530)
	rcall wait_usec 
	
	ldi r24,'W'				;print WELCOME message
	rcall lcd_data_sim
	ldi r24,'E'
	rcall lcd_data_sim
	ldi r24,'L'
	rcall lcd_data_sim
	ldi r24,'C'
	rcall lcd_data_sim
	ldi r24,'O'
	rcall lcd_data_sim
	ldi r24,'M'
	rcall lcd_data_sim
	ldi r24,'E'
	rcall lcd_data_sim

	ldi r26,0				;counter for a 4 seconds delay
	ldi r30 ,low(gas_level)
	ldi r31 ,high(gas_level)
	ld r16, Z				;iniatilize gas_level
	cpi r16,0x4
	brlo label1				;jump if there was no alarm
	ldi r16,0				;disable alarm 
	st Z,r16				;save new state
label1:
	ori r16,0x80			;PB7 ON
	out PORTB,r16			;leds on
	ldi r24,low(1000)		;1 second delay
	ldi r25,high(1000)
	rcall wait_msec
	inc r26
	cpi r26,4
	brne label1				;until r26 = 4
	ldi r24,0x01			; clear display screen
	rcall lcd_command_sim	;when 4 sec are up
	ldi r24, low(1530)
	ldi r25, high(1530)
	rcall wait_usec 
	clr r24
	out PORTB,r24			;switch off lights
	rjmp repeat_loop		;continuous program

wrong_code:
	ldi r20,2				;reset number counter to 2
	;4 sec 
	ldi r26,0				;counter for 40 intervals of 100ms
inside_loop:
	cli						;global interrupt disable
	ldi r24,0xCF			;interrupt after 100ms
	out TCNT1H,r24			;read with interrupts disabled
	ldi r24,0x2C
	out TCNT1L,r24
	sei						;Enable interrupts(I<-1)
	ser r21
wait_adc:
	sbrc r21,0				;while number not converted, loop	
	rjmp wait_adc
	ld r16,Z				;load number of gas_level
	cpi r16,0x04
	brlo skip_blink2		;if less than 70ppm no need for on-off
	sbrs r26,0				;blink gas level based on odd-even interval of 100ms
	rjmp skip_blink2
	ldi r16,0				;off on odd intervals

skip_blink2:				;first 0.5sec PB7 is on
	cpi r26,0x05
	brhs min0_5
	ori r16,0x80
	out PORTB,r16
	inc r26					;increase interval counter
	rjmp inside_loop
min0_5:
	cpi r26,0x0A
	brhs min1_0
	andi r16,0x7F			;make PB=0
	out PORTB,r16
	inc r26
	rjmp inside_loop
min1_0:
	cpi r26,0x0F			;15
	brhs min1_5
	ori r16,0x80			;make PB=1
	out PORTB,r16
	inc r26					;increase interval counter
	rjmp inside_loop
min1_5:
	cpi r26,0x14			;20
	brhs min2_0
	andi r16,0x7F			;make PB=0
	out PORTB,r16
	inc r26
	rjmp inside_loop
min2_0:
	cpi r26,0x19			;25
	brhs min2_5
	ori r16,0x80			;make PB=1
	out PORTB,r16
	inc r26					;increase interval counter
	rjmp inside_loop
min2_5:
	cpi r26,0x1E			;30
	brhs min3_0
	andi r16,0x7F			;make PB=0
	out PORTB,r16
	inc r26
	rjmp inside_loop
min3_0:
	cpi r26,0x23			;35
	brhs min3_5
	ori r16,0x80			;make PB=1
	out PORTB,r16
	inc r26					;increase interval counter
	rjmp inside_loop
min3_5:
	andi r16,0x7F			;make PB=0
	out PORTB,r16
	inc r26
	cpi r26,0x28			;40
	brlo inside_loop
	clr r21
no_press:	
	
	sbrc r21,0				;jump out when ADC converts
	rjmp wait_loop
	;we return from conversion

	
	rjmp repeat_loop

		


ISR_TIMER1_OVF:
	in r24,ADCSRA
	ori r24,(1<<ADSC)	;Start conversion
	out ADCSRA,r24
	ser r21				;dont break main loop
	reti				;return from interrupt

ADC_init:
	ldi r24,(1<<REFS0)	;Vref = Vcc
	out ADMUX,r24		;MUX4:0 = 00000 for A0
	;ADEN enables ADC
	;ADIE = adc interrupt enable-requires I set
	;Prescaler ADPS2:0 = 128
	;62.5Khz(>50KHz and <200Khz)
	ldi r24,(1<<ADEN)|(1<<ADIE)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
	out ADCSRA,r24
	ret
					
new_metric:
	push r24
	push r25
	push r26
	push r27
	in r26,ADCL				;read converted bits
	in r27,ADCH

	ldi r30 ,low(gas_level)
	ldi r31 ,high(gas_level)
	ld r16, Z				;restore gas_level from memory
	mov r29,r16				;keep a copy of previous state
	 
	cpi r26, low(ppm35)		;Compare low byte
	ldi c_tmp, high(ppm35)
	cpc r27, c_tmp			;Compare high byte
	brsh level_1			;jump if >= 35 ppm
	cpi r16, 0x04			
	brcs was_low1			;if carry=1,r16 < 0x04
	rcall clear_dis
was_low1:
	ldi r16,0x01			;r16 reserved for gas_level
	out PORTB,r16			;bit0 ON
	st Z,r16				;save gas_level into memory
	rjmp label_over

level_1:
	cpi r26,low(ppm70)		;Compare low byte
	ldi c_tmp,high(ppm70)
	cpc r27,c_tmp			;Compare high byte
	brsh level_2			;jump if >= 70 ppm
	cpi r16,0x04
	brcs was_low2
	rcall clear_dis
was_low2:
	ldi r16,0x02
	out PORTB,r16			;bit1 ON
	st Z,r16				;save gas_level into memory
	rjmp label_over

level_2:
	cpi r26,low(ppm105)		;Compare low byte
	ldi c_tmp,high(ppm105)
	cpc r27,c_tmp			;Compare high byte
	brsh level_3			;branch if >= 105 ppm
	ldi r16,0x04
	out PORTB,r16			;bit2 ON
	st Z,r16				;save gas_level into memory
	rjmp gas_detected

level_3:	
	cpi r26,low(ppm140)		;Compare low byte
	ldi c_tmp,high(ppm140)
	cpc r27,c_tmp			;Compare high byte
	brsh level_4			;branch if >= 140 ppm
	ldi r16,0x08
	out PORTB,r16			;bit3 ON
	st Z,r16				;save gas_level into memory
	rjmp gas_detected

level_4:
	cpi r26,low(ppm175)		;Compare low byte
	ldi c_tmp,high(ppm175)
	cpc r27,c_tmp			;Compare high byte
	brsh level_5			;branch if >= 175 ppm
	ldi r16,0x10
	out PORTB,r16			;bit4 ON
	st Z,r16				;save gas_level in memory
	rjmp gas_detected

level_5:
	cpi r26,low(ppm210)		;Compare low byte
	ldi c_tmp,high(ppm210)
	cpc r27,c_tmp			;Compare high byte
	brsh level_6			;branch if >= 210 ppm
	ldi r16,0x20
	out PORTB,r16			;bit5 ON
	st Z,r16				;save gas_level in memory
	rjmp gas_detected

level_6:
	ldi r16,0x40
	out PORTB,r16			;bit6 ON
	st Z,r16				;save gas_level in memory

gas_detected:
	cpi r29,0x04		;check if already gas detected
	brsh label_over
	;clr c_tmp
	;out PORTB,c_tmp			;blink led on gas detection
	

	ldi r24,0x01 			;clear display after
	rcall lcd_command_sim	;in order to print GAS DET
	ldi r24, low(1530)		;minimal delay for command
	ldi r25, high(1530)
	rcall wait_usec 
	
	ldi r24,'G'		;print GAS DETECTED
	rcall lcd_data_sim
	ldi r24,'A'
	rcall lcd_data_sim
	ldi r24,'S'
	rcall lcd_data_sim
	ldi r24,' '
	rcall lcd_data_sim
	ldi r24,'D'
	rcall lcd_data_sim
	ldi r24,'E'
	rcall lcd_data_sim
	ldi r24,'T'
	rcall lcd_data_sim
	ldi r24,'E'
	rcall lcd_data_sim
	ldi r24,'C'
	rcall lcd_data_sim
	ldi r24,'T'
	rcall lcd_data_sim
	ldi r24,'E'
	rcall lcd_data_sim
	ldi r24,'D'
	rcall lcd_data_sim

label_over:
	clr r21				;break main loop
	pop r27
	pop r26
	pop r25
	pop r24
	reti				;return from interrupt

clear_dis:
	push r24
	push r25
	ldi r24,0x01 			;clear display after gas
	rcall lcd_command_sim	;in order to print CLEAR
	ldi r24, low(1530)		;minimal delay for command
	ldi r25, high(1530)
	rcall wait_usec 
	
	ldi r24,'C'		;print GAS DETECTED
	rcall lcd_data_sim
	ldi r24,'L'
	rcall lcd_data_sim
	ldi r24,'E'
	rcall lcd_data_sim
	ldi r24,'A'
	rcall lcd_data_sim
	ldi r24,'R'
	rcall lcd_data_sim
	pop r25
	pop r24
	ret

scan_row_sim:
	out PORTC, r25		;r25 contains desired row 
	push r24 			;save r24-r25 values to stack
	push r25 
	ldi r24,low(500) 
	ldi r25,high(500)
	rcall wait_usec
	pop r25				;restore r24-r25 values
	pop r24
	nop
	nop 
	in r24, PINC		;pinc4 4lsb return row state
	andi r24 ,0x0f		;mask 4lsb 
	ret


scan_keypad_sim:
	push r26 			;save r26-r27 values to stack
	push r27 
	ldi r25 , 0x10 		;first row
	rcall scan_row_sim	
	swap r24 			;swap nibbles
	mov r27, r24 		;save to 4 msb of r27
	ldi r25 ,0x20 		;second row
	rcall scan_row_sim
	add r27, r24 		;save to 4lsb of r27
	ldi r25 , 0x40 		;third row
	rcall scan_row_sim
	swap r24 			;swap nibbles
	mov r26, r24 
	ldi r25 ,0x80 		;fourth row
	rcall scan_row_sim
	add r26, r24 
	movw r24, r26 		;r24-r25 = r26-r27
	clr r26 			;these 2 lines are added
	out PORTC,r26		;for remote system 
	pop r27 
	pop r26
	ret 

scan_keypad_rising_edge_sim:
	push r22 		;save affected registers in stack
	push r23 
	push r26
	push r27
	rcall scan_keypad_sim 
	push r24 
	push r25
	ldi r24 ,15 
	ldi r25 ,0 
	rcall wait_msec	;typical delay is 10-20 ms
	rcall scan_keypad_sim 
	pop r23 
	pop r22
	and r24 ,r22	;and 2 reads of current state
	and r25 ,r23
	ldi r26 ,low(_tmp_)
	ldi r27 ,high(_tmp_) 
	ld r23 ,X+		;load temp value to r23-r22
	ld r22 ,X
	st X ,r24 		;store current state in temp
	st -X ,r25 
	com r23			;1s com previous state
	com r22 
	and r24 ,r22	;and current state with previous
	and r25 ,r23
	pop r27 
	pop r26 
	pop r23
	pop r22
	ret 


keypad_to_ascii_sim:	
	push r26
	push r27 
	movw r26 ,r24 		;move r24-r25 to r26-r27
	ldi r24 ,'*' 		;and scann until first positive bit
	sbrc r26 ,0			;then return its ascii value
	rjmp return_ascii
	ldi r24 ,'0'
	sbrc r26 ,1
	rjmp return_ascii
	ldi r24 ,'#'
	sbrc r26 ,2
	rjmp return_ascii
	ldi r24 ,'D'
	sbrc r26 ,3 ; 
	rjmp return_ascii
	ldi r24 ,'7'
	sbrc r26 ,4
	rjmp return_ascii
	ldi r24 ,'8'
	sbrc r26 ,5
	rjmp return_ascii
	ldi r24 ,'9'
	sbrc r26 ,6
	rjmp return_ascii ;
	ldi r24 ,'C'
	sbrc r26 ,7
	rjmp return_ascii
	ldi r24 ,'4' 
	sbrc r27 ,0 
	rjmp return_ascii
	ldi r24 ,'5' 
	sbrc r27 ,1
	rjmp return_ascii
	ldi r24 ,'6'
	sbrc r27 ,2
	rjmp return_ascii
	ldi r24 ,'B'
	sbrc r27 ,3
	rjmp return_ascii
	ldi r24 ,'1'
	sbrc r27 ,4
	rjmp return_ascii 
	ldi r24 ,'2'
	sbrc r27 ,5
	rjmp return_ascii
	ldi r24 ,'3' 
	sbrc r27 ,6
	rjmp return_ascii
	ldi r24 ,'A'
	sbrc r27 ,7
	rjmp return_ascii
	clr r24
	rjmp return_ascii
return_ascii:
	pop r27 		; restore registers r27:r26
	pop r26
	ret

wait_msec:
	push r24
	push r25 
	ldi r24 , low(998) 
	ldi r25 , high(998) 
	rcall wait_usec 
	pop r25 
	pop r24 
	sbiw r24 , 1
	brne wait_msec 
	ret 


wait_usec:
	sbiw r24 ,1 
	nop 
	nop 
	nop 
	nop 
	brne wait_usec 
	 ret 

write_2_nibbles_sim:
	push r24 ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25 ; λειτουργία του προγραμματος απομακρυσμένης
	ldi r24 ,low(6000) ; πρόσβασης
	ldi r25 ,high(6000)
	rcall wait_usec
	pop r25
	pop r24 ; τέλος τμήμα κώδικα
	push r24 ; στέλνει τα 4 MSB
	in r25, PIND ; διαβάζονται τα 4 LSB και τα ξαναστέλνουμε
	andi r25, 0x0f ; για να μην χαλάσουμε την όποια προηγούμενη κατάσταση
	andi r24, 0xf0 ; απομονώνονται τα 4 MSB και
	add r24, r25 ; συνδυάζονται με τα προϋπάρχοντα 4 LSB
	out PORTD, r24 ; και δίνονται στην έξοδο
	sbi PORTD, PD3 ; δημιουργείται παλμός Enable στον ακροδέκτη PD3
	cbi PORTD, PD3 ; PD3=1 και μετά PD3=0
	push r24 ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25 ; λειτουργία του προγραμματος απομακρυσμένης
	ldi r24 ,low(6000) ; πρόσβασης
	ldi r25 ,high(6000)
	rcall wait_usec
	pop r25
	pop r24 ; τέλος τμήμα κώδικα
	pop r24 ; στέλνει τα 4 LSB. Ανακτάται το byte.
	swap r24 ; εναλλάσσονται τα 4 MSB με τα 4 LSB
	andi r24 ,0xf0 ; που με την σειρά τους αποστέλλονται
	add r24, r25
	out PORTD, r24
	sbi PORTD, PD3 ; Νέος παλμός Enable
	cbi PORTD, PD3
	ret

lcd_data_sim:
	push r24 ; αποθήκευσε τους καταχωρητές r25:r24 γιατί τους
	push r25 ; αλλάζουμε μέσα στη ρουτίνα
	sbi PORTD, PD2 ; επιλογή του καταχωρητή δεδομένων (PD2=1)
	rcall write_2_nibbles_sim ; αποστολή του byte
	ldi r24 ,43 ; αναμονή 43μsec μέχρι να ολοκληρωθεί η λήψη
	ldi r25 ,0 ; των δεδομένων από τον ελεγκτή της lcd
	rcall wait_usec
	pop r25 ;επανάφερε τους καταχωρητές r25:r24
	pop r24
	ret 

lcd_command_sim:
	push r24 ; αποθήκευσε τους καταχωρητές r25:r24 γιατί τους
	push r25 ; αλλάζουμε μέσα στη ρουτίνα
	cbi PORTD, PD2 ; επιλογή του καταχωρητή εντολών (PD2=0)
	rcall write_2_nibbles_sim ; αποστολή της εντολής και αναμονή 39μsec
	ldi r24, 39 ; για την ολοκλήρωση της εκτέλεσης της από τον ελεγκτή της lcd.
	ldi r25, 0 ; ΣΗΜ.: υπάρχουν δύο εντολές, οι clear display και return home,
	rcall wait_usec ; που απαιτούν σημαντικά μεγαλύτερο χρονικό διάστημα.
	pop r25 ; επανάφερε τους καταχωρητές r25:r24
	pop r24
	ret 

lcd_init_sim:
	push r24 ; αποθήκευσε τους καταχωρητές r25:r24 γιατί τους
	push r25 ; αλλάζουμε μέσα στη ρουτίνα
	ldi r24, 40 ; Όταν ο ελεγκτής της lcd τροφοδοτείται με
	ldi r25, 0 ; ρεύμα εκτελεί την δική του αρχικοποίηση.
	rcall wait_msec ; Αναμονή 40 msec μέχρι αυτή να ολοκληρωθεί.
	ldi r24, 0x30 ; εντολή μετάβασης σε 8 bit mode
	out PORTD, r24 ; επειδή δεν μπορούμε να είμαστε βέβαιοι
	sbi PORTD, PD3 ; για τη διαμόρφωση εισόδου του ελεγκτή
	cbi PORTD, PD3 ; της οθόνης, η εντολή αποστέλλεται δύο φορές
	ldi r24, 39
	ldi r25, 0 ; εάν ο ελεγκτής της οθόνης βρίσκεται σε 8-bit mode
	rcall wait_usec ; δεν θα συμβεί τίποτα, αλλά αν ο ελεγκτής έχει διαμόρφωση
 ; εισόδου 4 bit θα μεταβεί σε διαμόρφωση 8 bit
	push r24 ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25 ; λειτουργία του προγραμματος απομακρυσμένης
	ldi r24,low(1000) ; πρόσβασης
	ldi r25,high(1000)
	rcall wait_usec
	pop r25
	pop r24 ; τέλος τμήμα κώδικα
	ldi r24, 0x30
	out PORTD, r24
	sbi PORTD, PD3
	cbi PORTD, PD3
	ldi r24,39
	ldi r25,0
	rcall wait_usec 
	push r24 ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25 ; λειτουργία του προγραμματος απομακρυσμένης
	ldi r24 ,low(1000) ; πρόσβασης
	ldi r25 ,high(1000)
	rcall wait_usec
	pop r25
	pop r24 ; τέλος τμήμα κώδικα
	ldi r24,0x20 ; αλλαγή σε 4-bit mode
	out PORTD, r24
	sbi PORTD, PD3
	cbi PORTD, PD3
	ldi r24,39
	ldi r25,0
	rcall wait_usec
	push r24 ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25 ; λειτουργία του προγραμματος απομακρυσμένης
	ldi r24 ,low(1000) ; πρόσβασης
	ldi r25 ,high(1000)
	rcall wait_usec
	pop r25
	pop r24 ; τέλος τμήμα κώδικα
	ldi r24,0x28 ; επιλογή χαρακτήρων μεγέθους 5x8 κουκίδων
	rcall lcd_command_sim ; και εμφάνιση δύο γραμμών στην οθόνη
	ldi r24,0x0c ; ενεργοποίηση της οθόνης, απόκρυψη του κέρσορα
	rcall lcd_command_sim
	ldi r24,0x01 ; καθαρισμός της οθόνης
	rcall lcd_command_sim
	ldi r24, low(1530)
	ldi r25, high(1530)
	rcall wait_usec
	ldi r24 ,0x06 ; ενεργοποίηση αυτόματης αύξησης κατά 1 της διεύθυνσης
	rcall lcd_command_sim ; που είναι αποθηκευμένη στον μετρητή διευθύνσεων και
 ; απενεργοποίηση της ολίσθησης ολόκληρης της οθόνης
	pop r25 ; επανάφερε τους καταχωρητές r25:r24
	pop r24
	ret
