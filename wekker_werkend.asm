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

	ldi temp, high(21600) ;1 sec = (256 / 11059200) * 43200
	out OCR1AH, temp
	ldi temp, low(21600)
	out OCR1AL, temp

	clr temp
	out DDRA, temp

	;init UART
	clr temp;
	out UBRRH, temp
	ldi temp, 35 ;19200 baud
	out UBRRL, temp
	;set frame format : asynchronous, parity disabled, 8 data bits, 1 stop bit
	ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
	out UCSRC, temp
	;enable receiver & transmitter
	ldi temp, (1 << RXEN) | (1 << TXEN)
	out UCSRB, temp

	;prescaler 256 en CTC mode
	ldi temp, (1 << CS12) | (1 << WGM12)
	out TCCR1B, temp

	;enable interrupt
	ldi temp, (1 << OCIE1A)
	out TIMSK, temp
	;clear values
	clr hour
	clr minute
	clr second
	clr alarmHour
	clr alarmMinute
	clr timeSwitch
	clr temp
	clr status

	;alarm-indicator off, colon 1 and 2 on
	ldi byteSeven, 0b00000110
	;set global interrupt flag
	sei

;initial loop, all numbers flicker
begin_loop:
	in temp, PINA
	com temp
	cpi temp, 2
	breq set_hour
	rcall flicker
	rjmp begin_loop

;only hours flicker, set hour with SW01
set_hour:
	inc status
	rcall wait_full_second
	rcall wait_full_second
	rcall increment_button

;only minutes flicker, set minute with SW01
set_minute:
	inc status
	rcall wait_full_second
	rcall wait_full_second
	rcall increment_button

;only seconds flicker, set second with SW01
set_second:
	inc status
	rcall wait_full_second
	rcall wait_full_second
	rcall increment_button

set_alarm_hour:
	inc status
	rcall wait_full_second
	rcall wait_full_second
	ldi byteSeven, 0b000000101
	rcall increment_button

set_alarm_minute:
	inc status
	rcall wait_full_second
	rcall wait_full_second
	rcall increment_button

set_alarm_on_off:
	inc status
	rcall wait_full_second
	rcall wait_full_second
	set_alarm_on_off_loop:
		in temp, PINA
		com temp
		cpi temp, 2
		breq clear_status
		cpi temp, 1
		breq button_sw01_alarm
		rcall flicker
		rjmp set_alarm_on_off_loop
		button_sw01_alarm:
			in temp, PINA
			com temp
			cpi temp, 1
			breq switch_alarm
			rjmp set_alarm_on_off_loop
			switch_alarm:
				rcall wait_half_second
				cpi byteSeven, 0b00000101
				breq alarm_is_on
				ldi byteSeven, 0b00000101
				rcall send_time
			rjmp button_sw01_alarm
				alarm_is_on:
				ldi byteSeven, 0b00000100
				rcall send_time
			rjmp button_sw01_alarm

clear_status:
	sbr byteSeven, 2
	clr status



;main program, clock is running
main:
	rcall compare_alarm
	rcall time_running
	rjmp main



;output temp values to UART
output:
	SBIS	UCSRA,	UDRE
	RJMP	output

	out UDR, temp
	ret

time_running:
	rcall wait_full_second
	rcall send_time
	rcall increment_time
ret

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
		in temp, PINA
		com temp
		cpi temp, 1
		breq set_time_increment
		rjmp increment_button
		set_time_increment:
		rcall set_time_status_check
		rcall send_time
		rjmp button_sw0
	button_sw1:
	ret

wait_full_second:
	ser waitfull
	waiting_full_second:
		tst waitfull
		brne waiting_full_second
	ret

wait_half_second:
	ser waithalf
	waiting_half_second:
		tst waithalf
		brne waiting_half_second
	ret

tobin:
	CPI temp, 0
	BREQ num0
	CPI temp, 1
	BREQ num1
	CPI temp, 2
	BREQ num2
	CPI temp, 3
	BREQ num3
	CPI temp, 4
	BREQ num4
	CPI temp, 5
	BREQ num5
	CPI temp, 6
	BREQ num6
	CPI temp, 7
	BREQ num7
	CPI temp, 8
	BREQ num8
	CPI temp, 9
	BREQ num9
	tobin_continue:
RET

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

;increment the overall time
increment_time:
	inc second
	cpi second, 60
	brlt minute_continue
	clr second
	inc minute
	minute_continue:

	cpi minute, 60
	brlt hour_continue
	clr minute
	inc hour
	cpi hour, 24
	brlt hour_continue
	clr hour
	hour_continue:
ret

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
	rcall wait_half_second
	inc hour
	cpi hour, 24
	brlt inc_hour_continue
	clr hour
	inc_hour_continue:
ret

;increment minute
increment_minute:
	rcall wait_half_second
	inc minute
	cpi minute, 60
	brlt inc_minute_continue
	clr minute
	inc_minute_continue:
ret

;increment second
increment_second:
	rcall wait_half_second
	inc second
	cpi second, 60
	brlt inc_second_continue
	clr second
	inc_second_continue:
ret

increment_alarm_hour:
	rcall wait_half_second
	inc alarmHour
	cpi alarmHour, 24
	brlt inc_alarm_hour_continue
	clr alarmHour
	inc_alarm_hour_continue:
ret

increment_alarm_minute:
	rcall wait_half_second
	inc alarmMinute
	cpi alarmMinute, 60
	brlt inc_alarm_minute_continue
	clr alarmMinute
	inc_alarm_minute_continue:
ret

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
	ldi byteSeven, 0b00001101
	alarm_ringing_loop:
		in temp, PINA
		com temp
		cpi temp, 1
		breq cancel_alarm
		rcall flicker
		rjmp alarm_ringing_loop

cancel_alarm:
	ldi byteSeven, 0b00000111
	clr status
	ret

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

flicker:
	tst waithalf
	brne flicker_continue
	tst timeSwitch
	breq no_flicker
	rcall send_time
	ser waithalf
	rjmp flicker_continue
	no_flicker:
	rcall send_nothing
	cpi status, 4
	brlt flicker_notime_increment
	rcall increment_time
	flicker_notime_increment:
	ser waithalf
	flicker_continue:
ret

ONE_SECOND_TIMER:
	in saveSR, SREG
	tst timeSwitch
	breq timeSwitch_else
	clr timeSwitch
	clr waithalf
	clr waitfull
	rjmp timeSwitch_continue
	timeSwitch_else:
	inc timeSwitch
	clr waithalf
	timeSwitch_continue:
	out SREG, saveSR
reti
