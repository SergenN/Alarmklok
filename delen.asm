convert:
	CPI number, 10 
	BRGE delen
	convert_continue:
	MOV numout, number
	rcall tobin
	rcall output
ret

delen:
	SUBI number, 10
	INC counter
	CPI number, 10
	BRGE delen
	MOV numout, counter
	rcall tobin
	rcall output
rjmp convert_continue