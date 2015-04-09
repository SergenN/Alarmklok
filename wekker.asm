.include "m32def.inc"

.def hour = r16
.def minute = r17
.def second = r18
.def saveSR = r19
.def temp = r20
.def segment = r21
.def counter = r22
.def number = r23

.org 0x0000
rjmp init

.org OC1Aaddr
rjmp ONE_SECOND_TIMER

init:
	ldi r16, high(RAMEND) ; init stack pointer
	out SPH, r16
	ldi r16, low(RAMEND)
	out SPL, r16

	ldi temp, high(43200) ; 1 sec = (256 / 11059200) * 43200
	out OCR1AH, temp
	ldi temp, low(43200)
	out OCR1AL, temp

	// Init UART
	clr temp;
	out UBRRH, temp
	ldi temp, 35 ; 19200 baud
	out UBRRL, temp
	; set frame format : asynchronous, parity disabled, 8 data bits, 1 stop bit
	ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
	out UCSRC, temp
	; enable receiver & transmitter
	ldi temp, (1 << RXEN) | (1 << TXEN)
	out UCSRB, temp

	//prescaler 256 en CTC mode
	ldi temp, (1 << CS12) | (1 << WGM12)
	out TCCR1B, temp

	//enable interrupt
	ldi temp, (1 << OCIE1A)
	out TIMSK, temp

	clr hour
	clr minute
	clr second

	clr temp
	sei

loop:
	rjmp loop

output:
	SBIS	UCSRA,	UDRE
	RJMP	output

	out UDR, temp
	ret

vul_segment:
	mov temp, hour
	rcall convert

	mov temp, minute
	rcall convert

	mov temp, second
	rcall convert

	ldi temp, 0b00000111
	rcall output

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

ONE_SECOND_TIMER:
	in saveSR, SREG
	rcall vul_segment
	rcall increment_time
	out SREG, saveSR
	reti
