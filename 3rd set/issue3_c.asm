.include "m16def.inc"


.DSEG
_tmp_: .byte 2

.CSEG

reset:
	ldi r24,low(RAMEND)		;initialize stack
	out SPL,r24
	ldi r24,high(RAMEND)
	out SPH,r24

	ser r24
	out DDRD,r24			;initialize PORTD as output for display
	clr r24
	rcall lcd_init_sim		;routine for display initialization

	ser r24
	out DDRB,r24			;PORTB is output
	ldi r24,0xF0
	out DDRC,r24			;4 msb as output,rest as input
start:
	ldi r24,0x01 			;clear display after
	rcall lcd_command_sim	;each message timeout
	ldi r24, low(1530)		;minimal delay for command
	ldi r25, high(1530)
	rcall wait_usec 
		
	ldi r20,2				;numbers counter
for_loop:
	clr r25
	clr r24
while_loop:
	rcall scan_keypad_rising_edge_sim	;keypad state in r25-r24
	cpi r25,0x00			;compare with zero
	brne valid				;to catch first keypad press
	cpi r24,0x00
	breq while_loop			;else continue reading
valid:
	rcall keypad_to_ascii_sim
	push r24		;save ascii to stack
	dec r20			;decrease counter
	sbrc r20,0
	rjmp for_loop
	pop r23			;2nd number in r23		
	pop r22			;1st number

	rcall keypad_to_ascii_sim	;needed for simulation
	cpi r22,'0'		;compare with team nb - 03
	brne wrong_code
	cpi r23,'3'
	brne wrong_code
	;welcome 03
	ldi r24,0x01 	; clear display screen
	rcall lcd_command_sim
	ldi r24, low(1530)
	ldi r25, high(1530)
	rcall wait_usec 
	
	ldi r24,'W'		;print letters to screen
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
	ldi r24,' '
	rcall lcd_data_sim
	ldi r24,'0'
	rcall lcd_data_sim
	ldi r24,'3'
	rcall lcd_data_sim
	ldi r26,0			;4 seconds delay
	
label1:
	ser r24
	out PORTB,r24		;leds on
	ldi r24,low(1000)	;1 second delay
	ldi r25,high(1000)
	rcall wait_msec
	inc r26
	cpi r26,4
	brne label1			;until r20 = 4
	clr r24
	out PORTB,r24		;switch off lights
	rjmp start			;continuous program

wrong_code:
	ldi r24,0x01 		; clear display screen
	rcall lcd_command_sim
	ldi r24, low(1530)	;delay until controller ready
	ldi r25, high(1530)
	rcall wait_usec 
	ldi r24,'A'
	rcall lcd_data_sim
	ldi r24,'L'
	rcall lcd_data_sim
	ldi r24,'A'
	rcall lcd_data_sim
	ldi r24,'R'
	rcall lcd_data_sim
	ldi r24,'M'
	rcall lcd_data_sim
	ldi r24,' '
	rcall lcd_data_sim
	ldi r24,'O'
	rcall lcd_data_sim
	ldi r24,'N'
	rcall lcd_data_sim
	ldi r26,0			;delay counter
four_sec_blink:
	ser r24
	out PORTB,r24		;leds on
	ldi r24,low(500)	;0.5 second delay
	ldi r25,high(500)
	rcall wait_msec
	clr r24
	out PORTB,r24		;leds off
	ldi r24,low(500)	;0.5 second delay
	ldi r25,high(500)
	rcall wait_msec
	inc r26
	cpi r26,4			;loop until counter=4
	brne four_sec_blink
	rjmp start			;continuous program


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
