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
.def waitfull = r23 ; wait a full second
.def useTimer = r24
.def status = r25

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

	// Init UART
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
	clr timeSwitch
	clr temp
	clr status

	ser useTimer
	;set global interrupt flag
	sei

begin_loop:
	in temp, PINA
	com temp
	cpi temp, 2
	breq set_hour
	rcall flicker
	rjmp begin_loop

set_hour:
	inc status
	set_hour_loop:
	rcall flicker
	rjmp set_hour_loop

main:
	rcall time_running
	rjmp main

output:
	SBIS	UCSRA,	UDRE
	RJMP	output

	out UDR, temp
	ret

time_running:
	tst timeSwitch
	brne time_running_continue
	tst waitfull
	brne time_running_continue
	rcall send_time
	rcall increment_time
	ser waitfull
	time_running_continue:
	ret

send_time:
	mov temp, hour
	rcall convert

	mov temp, minute
	rcall convert

	mov temp, second
	rcall convert

	ldi temp, 0b00000111
	rcall output
ret

send_nothing:
	ldi temp, 0x80
	rcall output
	cpi status, 0
	breq status0
	cpi status, 1
	breq status1
	status0:
		ldi temp, 0
		nothing_loop:
		rcall output
		inc counter
		cpi counter, 6
		brlt nothing_loop
		ldi temp, 0b00000110
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
		ldi temp, 0b00000110
		rcall output
		rjmp send_nothing_continue
	send_nothing_continue:
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

convert:
	clr counter
	mov number, temp
	CPI number, 10
	BRGE delen
	convert_continue:
	mov temp, counter
	rcall tobin
	rcall output
	MOV temp, number
	rcall tobin
	rcall output
ret

delen:
	SUBI number, 10
	INC counter
	CPI number, 10
	BRGE delen
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
	ser waithalf
	flicker_continue:
ret

hour_flicker:
	

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
