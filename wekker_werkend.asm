/*
Status:
	0 = Hours, minutes and seconds flicker
	1 = Set hour
	2 = Set minute
	3 = Set second
	4 = Set alarm hour
	5 = Set alarm minute
	6 = Turn alarm on/off
	7 = alarm ringing
*/

.include "m32def.inc"

.def saveSR = r3
.def timeSwitch = r4 ;switch to determine one second, and if flick is on or off
.def hour = r16
.def minute = r17
.def second = r18
.def temp = r19
.def counter = r20
.def number = r21
.def waithalf = r22 ;wait half a second
.def waitfull = r23 ;wait a full second
.def status = r25
.def byteSeven = r26
.def alarmHour = r27
.def alarmMinute = r28

.org 0x0000
rjmp init

.org OC1Aaddr
rjmp ONE_SECOND_TIMER

init:
	ldi r16, high(RAMEND) ;init stack pointer
	out SPH, r16
	ldi r16, low(RAMEND)
	out SPL, r16

	ldi temp, high(21600) ;load with 1/2 second, 1 sec = (256 / 11059200) * 43200
	out OCR1AH, temp
	ldi temp, low(21600)
	out OCR1AL, temp

	clr temp			;set buttons as input
	out DDRA, temp
	ser temp			;set leds as output
	out DDRB, temp

	clr temp			;init UART
	out UBRRH, temp
	ldi temp, 35		;19200 baud
	out UBRRL, temp
	;set frame format; asynchronous, parity disabled, 8 data bits, 1 stop bit
	ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
	out UCSRC, temp
	;enable receiver and transmitter
	ldi temp, (1 << RXEN) | (1 << TXEN)
	out UCSRB, temp

	;prescaler on 256 and set CTC mode
	ldi temp, (1 << CS12) | (1 << WGM12)
	out TCCR1B, temp

	;enable interrupt
	ldi temp, (1 << OCIE1A)
	out TIMSK, temp
	;clear all values
	clr hour
	clr minute
	clr second
	clr alarmHour
	clr alarmMinute
	clr timeSwitch
	clr temp
	clr status
	;enable led 0 and 1
	ldi temp, 2
	com temp
	out PORTB, temp
	;alarm-indicator off, colon 1 and 2 on
	ldi byteSeven, 0b00000110
	;set global interrupt flag
	sei

;initial loop, all numbers flicker
begin_loop:
	in temp, PINA
	com temp
	cpi temp, 2
	breq led_01
	rcall flicker
	rjmp begin_loop

;set led 0 and 1
led_01:
	ldi temp, 3
	com temp
	out PORTB, temp

;only hours flicker, set hour with SW1, increment with SW0
set_time:
	cpi status, 3
	brge set_alarm_time
	inc status
	rcall wait_full_second
	rcall wait_full_second
	rcall increment_button
	rjmp set_time

;only hours flicker, set alarm hour with SW1
set_alarm_time:
	cpi status, 6
	brge clear_status
	inc status
	rcall wait_full_second
	rcall increment_time
	rcall wait_full_second
	rcall increment_time
	ldi byteSeven, 0b000000101
	rcall increment_button
	rjmp set_alarm_time

;set status to 0, set bit 2 in byteSeven
clear_status:
	ser temp
	out PORTB, temp
	sbr byteSeven, 2
	clr status
	rcall wait_full_second
	rcall increment_time



;main program, time is running
main:
	in temp, PINA
	com temp
	cpi temp, 2
	breq reset_alarm
	rcall compare_alarm
	rcall time_running
	rjmp main
	;hold SW1 to reset alarm
	reset_alarm:
		ldi status, 3
		rjmp led_01



;output temp values to UART
output:
	SBIS	UCSRA,	UDRE
	RJMP	output

	out UDR, temp
	ret

;wait one second, increment time
time_running:
	rcall wait_full_second
	rcall increment_time
	rcall send_time
	ret

;display current time
send_time:
	cpi status, 4
	brge alarm_not_set

	mov temp, hour
	rcall convert

	mov temp, minute
	rcall convert

	mov temp, second
	rcall convert

	mov temp, byteSeven
	rcall output
	ret

	alarm_not_set:
	rcall send_alarm_time
	ret

;display current alarm time
send_alarm_time:
	mov temp, alarmHour
	rcall convert

	mov temp, alarmMinute
	rcall convert

	ldi temp, 0
	rcall output
	ldi temp, 0
	rcall output

	mov temp, byteSeven
	rcall output
	ret

;depending on current status, display these values
send_nothing:
	ldi temp, 0x80
	rcall output
	cpi status, 0
	breq status0
	cpi status, 1
	breq status1
	cpi status, 2
	breq status2
	cpi status, 3
	breq status3
	cpi status, 4
	breq status4
	cpi status, 5
	breq status5
	cpi status, 6
	brge jump_to_status6
	jump_to_status6:
	rjmp status6
	status0:
		ldi temp, 0
		nothing_loop:
		rcall output
		inc counter
		cpi counter, 6
		brlt nothing_loop
		ldi byteSeven, 0b00000110
		mov temp, byteSeven
		rcall output
		rjmp send_nothing_continue
	status1:
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		mov temp, minute
		rcall convert
		mov temp, second
		rcall convert
		mov temp, byteSeven
		rcall output
		rjmp send_nothing_continue
	status2:
		mov temp, hour
		rcall convert
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		mov temp, second
		rcall convert
		mov temp, byteSeven
		rcall output
		rjmp send_nothing_continue
	status3:
		mov temp, hour
		rcall convert
		mov temp, minute
		rcall convert
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		mov temp, byteSeven
		rcall output
		rjmp send_nothing_continue
	status4:
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		mov temp, alarmMinute
		rcall convert
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		ldi temp, 0b00000100
		rcall output
		rjmp send_nothing_continue
	status5:
		mov temp, alarmHour
		rcall convert
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		ldi temp, 0
		rcall output
		ldi temp, 0b00000100
		rcall output
		rjmp send_nothing_continue
	status6:
		ldi temp, 0
		nothing_loop6:
		rcall output
		inc counter
		cpi counter, 6
		brlt nothing_loop6
		mov temp, byteSeven
		rcall output
		rjmp send_nothing_continue
	send_nothing_continue:
	ret

;increment value with SW0, or alarm-indicator depending on status
increment_button:
	in temp, PINA
	com temp
	cpi temp, 2
	breq button_sw1
	cpi temp, 1
	breq button_sw0
	rcall flicker
	rjmp increment_button
	button_sw0:
		cpi status, 6
		breq button_sw0_alarm
		rcall set_time_status_check
		rcall send_time
		rcall wait_half_second
		button_sw0_loop:
			rcall wait_half_second
			in temp, PINA
			com temp
			cpi temp, 1
			breq set_time_increment
			rjmp increment_button
			set_time_increment:
				rcall set_time_status_check
				rcall send_time
			rjmp button_sw0_loop
	button_sw1:
	ret
	button_sw0_alarm:
		rcall switch_alarm
		button_sw0_alarm_loop:
			rcall wait_half_second
			in temp, PINA
			com temp
			cpi temp, 1
			brne increment_button
			rjmp button_sw0_alarm_loop

;set alarm-indicator on or off
switch_alarm:
	cpi byteSeven, 0b00000101
	breq alarm_is_on
	ldi byteSeven, 0b00000101
	rcall send_time
	ret
	alarm_is_on:
		ldi byteSeven, 0b00000100
		rcall send_time
	ret
	
;while waitfull is set, stay in loop. waitfull is cleared in ISR after 1 second
wait_full_second:
	ser waitfull
	waiting_full_second:
		tst waitfull
		brne waiting_full_second
	ret

;same as wait_full_second, but with waithalf
wait_half_second:
	ser waithalf
	waiting_half_second:
		tst waithalf
		brne waiting_half_second
	ret

;convert decimal to binary display
tobin:
	cpi temp, 0
	breq num0
	cpi temp, 1
	breq num1
	cpi temp, 2
	breq num2
	cpi temp, 3
	breq num3
	cpi temp, 4
	breq num4
	cpi temp, 5
	breq num5
	cpi temp, 6
	breq num6
	cpi temp, 7
	breq num7
	cpi temp, 8
	breq num8
	cpi temp, 9
	breq num9
	tobin_continue:
	ret

	num0:
		LDI temp, $77
		rjmp tobin_continue
	num1:
		LDI temp, $24
		rjmp tobin_continue
	num2:
		LDI temp, $5D
		rjmp tobin_continue
	num3:
		LDI temp, $6D
		rjmp tobin_continue
	num4:
		LDI temp, $2E
		rjmp tobin_continue
	num5:
		LDI temp, $6B
		rjmp tobin_continue
	num6:
		LDI temp, $7B
		rjmp tobin_continue
	num7:
		LDI temp, $25
		rjmp tobin_continue
	num8:
		LDI temp, $7F
		rjmp tobin_continue
	num9:
		LDI temp, $6F
		rjmp tobin_continue

;if number is over 10, divide and decode seperate numbers
convert:
	clr counter
	mov number, temp
	CPI number, 10
	BRGE divide
	convert_continue:
	mov temp, counter
	rcall tobin
	rcall output
	MOV temp, number
	rcall tobin
	rcall output
	ret

divide:
	SUBI number, 10
	INC counter
	CPI number, 10
	BRGE divide
	rjmp convert_continue

;increment the overall time
increment_time:
	inc second
	cpi second, 60
	brlt minute_continue	;if 60, clear seconds and increment minute
	clr second
	inc minute
	minute_continue:

	cpi minute, 60			;if 60, clear minutes and increment hour
	brlt hour_continue
	clr minute
	inc hour
	cpi hour, 24
	brlt hour_continue		;if 24, clear hours, brand new day!
	clr hour
	hour_continue:
	ret

;depending on status, increment hour, minute or second
set_time_status_check:
	cpi status, 1
	breq time_status1
	cpi status, 2
	breq time_status2
	cpi status, 3
	breq time_status3
	cpi status, 4
	breq time_status4
	cpi status, 5
	breq time_status5

	time_status1:
		rcall increment_hour
		ret
	time_status2:
		rcall increment_minute
		ret
	time_status3:
		rcall increment_second
		ret
	time_status4:
		rcall increment_alarm_hour
		ret
	time_status5:
		rcall increment_alarm_minute
		ret

increment_hour:
	inc hour
	cpi hour, 24
	brlt inc_hour_continue
	clr hour
	inc_hour_continue:
	ret

increment_minute:
	inc minute
	cpi minute, 60
	brlt inc_minute_continue
	clr minute
	inc_minute_continue:
	ret

increment_second:
	inc second
	cpi second, 60
	brlt inc_second_continue
	clr second
	inc_second_continue:
	ret

increment_alarm_hour:
	inc alarmHour
	cpi alarmHour, 24
	brlt inc_alarm_hour_continue
	clr alarmHour
	inc_alarm_hour_continue:
	ret

increment_alarm_minute:
	inc alarmMinute
	cpi alarmMinute, 60
	brlt inc_alarm_minute_continue
	clr alarmMinute
	inc_alarm_minute_continue:
	ret

;if alarm time equals current time, let alarm ring
compare_alarm:
	cpi byteSeven, 0b00000111
	breq alarm_bit_set
	ret
	alarm_bit_set:
		cp hour, alarmHour
		brne no_alarm
		cp minute, alarmMinute
		brne no_alarm
		cpi second, 0
		brne no_alarm
		rcall alarm_ringing
		ret
		no_alarm:
	ret

alarm_ringing:
	ldi status, 7
	ldi byteSeven, 0b00001101	;load byteSeven with alarm-bit, so alarm will ring
	ldi temp, 3					;set led 0 and 1
	com temp
	out PORTB, temp
	alarm_ringing_loop:
		in temp, PINA
		com temp
		cpi temp, 1				;if SW0, turn off alarm
		breq cancel_alarm
		cpi temp, 2				;if SW1, turn off alarm and snooze
		breq snooze
		rcall flicker
		rjmp alarm_ringing_loop

cancel_alarm:
	ldi byteSeven, 0b00000111	;turn off alarm-bit
	clr status
	clr temp					;turn off led 0 and 1
	com temp
	out PORTB, temp
	rcall time_running
	ret

;set alarm again, plus 5 minutes
snooze:
	clr counter
	snooze_loop:
		cpi counter, 5
		breq cancel_alarm
		inc counter
		rcall increment_alarm_minute
		cpi alarmMinute, 0
		brne snooze_loop
		rcall increment_alarm_hour
		rjmp snooze_loop

;flickering of display, half a second current time, half a second nothing
flicker:
	tst waithalf
	brne flicker_continue ;if waithalf is set, ret from subroutine
	tst timeSwitch
	breq no_flicker ;if timeswitch set, send current time, else send flicker
	rcall send_time
	ser waithalf
	rjmp flicker_continue
	no_flicker:
	rcall send_nothing
	cpi status, 4 ;if status is 4 or higher, increment time as well
	brlt flicker_notime_increment
	rcall increment_time
	flicker_notime_increment:
	ser waithalf
	flicker_continue:
	ret

;ISR, every half a second
ONE_SECOND_TIMER:
	in saveSR, SREG
	tst timeSwitch				;if timeswitch is 0, set timeswitch on 1
	breq timeSwitch_else
	clr timeSwitch				;this part of ISR will happen twice every 1/2 second
	clr waithalf				;clear waithalf, to indicate 1/2 second has passed
	clr waitfull				;clear waitfull, to indicate a full second as passed as well
	rjmp timeSwitch_continue
	timeSwitch_else:			;this part will happen every 1/2 second
	inc timeSwitch				;set timeswitch on 1
	clr waithalf				;clear waithalf, to indicate 1/2 second has passed
	timeSwitch_continue:
	out SREG, saveSR
	reti
