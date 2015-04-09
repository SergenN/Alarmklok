

tobin:
CPI r16, 0
BREQ num0
CPI r16, 1
BREQ num1
CPI r16, 2
BREQ num2
CPI r16, 3
BREQ num3
CPI r16, 4
BREQ num4
CPI r16, 5
BREQ num5
CPI r16, 6
BREQ num6
CPI r16, 7
BREQ num7
CPI r16, 8
BREQ num8
CPI r16, 9
BREQ num9
RET

num0:
LDI r17, $77
RET
num1:
LDI r17, $12
RET
num2:
LDI r17, $5D
RET
num3:
LDI r17, $6D
RET
num4:
LDI r17, $2E
RET
num5:
LDI r17, $6B
RET
num6
LDI r17, $7B
RET
num7:
LDI r17, $25
RET
num8:
LDI r17, $7F
RET
num9:
LDI r17, $6F
RET