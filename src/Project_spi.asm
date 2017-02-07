$MODLP52
org 0000H
   ljmp MainProgram

DSEG at 30H
Result: ds 2
Final_result: ds 2
x:   ds 4
y:   ds 4
bcd: ds 5
Thertemp: ds 2
LMtemp: ds 2

BSEG
mf: dbit 1
LM_TH: dbit 1

; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P1.2
LCD_RW equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5
CLK  EQU 22118400
BAUD equ 115200
T1LOAD equ (0x100-(CLK/(16*BAUD)))
CE_ADC EQU P2.0
MY_MOSI EQU P2.1
MY_MISO EQU P2.2
MY_SCLK EQU P2.3

$NOLIST
$include(math32.inc)
$LIST

$NOLIST
$include(LCD_4bit.inc)
$LIST

VLED EQU 207 ; Measured (with multimeter) LED voltage x 100
DSEG ; Tell assembler we are about to define variables
Vcc: ds 2 ; 16-bits are enough to store VCC x 100 (max is 525)
CSEG ; Tell assembler we are about to input code
; Measure the LED voltage. Used as reference to find VCC.

Initial_Message:  db 'NOW temperature ', 0

Send_BCD mac
    push ar0
    mov r0, %0
    lcall ?Send_BCD
    pop ar0
endmac

?Send_BCD:
    push acc
    ; Write most significant digit
    mov a, r0
    swap a
    anl a, #0fh
    orl a, #30h
    lcall putchar
    ; write least significant digit
    mov a, r0
    anl a, #0fh
    orl a, #30h
    lcall putchar
    pop acc
    ret

; Configure the serial port and baud rate using timer 1
InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, or risk displaying gibberish!
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can safely proceed with the configuration
	clr	TR1
	anl	TMOD, #0x0f
	orl	TMOD, #0x20
	orl	PCON,#0x80
	mov	TH1,#T1LOAD
	mov	TL1,#T1LOAD
	setb TR1
	mov	SCON,#0x52
    ret

; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret

Hello_World:
    DB  'Hello, World!', '\r', '\n', 0
;----------------------------------------------------------------------
; These �EQU� must match the wiring between the microcontroller and ADC
;----------------------------------------------------------------------

INIT_SPI:
 	setb MY_MISO ; Make MISO an input pin
 	clr MY_SCLK ; For mode (0,0) SCLK is zero
 	ret

DO_SPI_G:
 	push acc
 	mov R1, #0 ; Received byte stored in R1
 	mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP:
 	mov a, R0 ; Byte to write is in R0
 	rlc a ; Carry flag has bit to write
 	mov R0, a
 	mov MY_MOSI, c
 	setb MY_SCLK ; Transmit
 	mov c, MY_MISO ; Read received bit
 	mov a, R1 ; Save received bit in R1
 	rlc a
    mov R1, a
 	clr MY_SCLK
 	djnz R2, DO_SPI_G_LOOP
 	pop acc
 	ret

;--------------------------------------------------
;send voltage to the serial port
;--------------------------------------------------
SendVoltage:

    lcall INIT_SPI
    Forever:
	clr CE_ADC
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B ; Single ended, read channel 0
	lcall DO_SPI_G
	mov a, R1 ; R1 contains bits 8 and 9
	anl a, #00000011B ; We need only the two least significant bits
	mov Result+1, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1 ; R1 contains bits 0 to 7. Save result low.
	setb CE_ADC
	lcall Delay
	;lcall calculation
	lcall data_transformation
	sjmp Forever
    sjmp $ ; This is equivalent to 'forever: sjmp forever'

    ;POP AR0
    ;POP acc
    ret
    jnb LM_TH, Th
LM: mov b, #0;
    lcall _Read_ADC_Channel
    lcall LM_converter
    clr LM_TH
    ljmp Send_Done

Th: mov b, #1 ; connect thermocouple to chanel1
    lcall _Read_ADC_Channel ; Read from the SPI
    lcall Th_converter ; convert ADC TO actual value
    setb LM_TH

Send_Done:

    ; add it up

LM_converter:

    mov x+3, #0 ; Load 32-bit �y� with value from ADC
    mov x+2, #0
    mov x+1, R7
    mov x+0, R6
    load_y(491)
    lcall mul32
    load_y(1023)
    lcall div32
    load_y(273)
    lcLll sub32
    lcall hex2bcd
;-------------------------------------------------
;calculation
;-------------------------------------------------
; Measure the LED voltage. Used as reference to find VCC.
calculation:
		PUSH AR6
		PUSH AR7

    mov b, #7 ; VLED connected to input �7� of MCP3008 ADC
    ;lcall Read_ADC_Channel ; Read voltage, returns 10-bits in [R6-R7]
    lcall _Read_ADC_Channel
    mov y+3, #0 ; Load 32-bit �y� with value from ADC
    mov y+2, #0
    mov y+1, R7
    mov y+0, R6
    load_x(VLED*1023) ; Macro to load �x� with constant
    lcall div32 ; Divide �x� by �y�, the result is VCC in �x�
    mov Vcc+1, x+1 ; Save calculated VCC high byte
    mov Vcc+0, x+0 ; Save calculated VCC low byte

    POP AR7
    POP AR6

    ret

;-----------------------------------
; chanel 6 mac
;-----------------------------------
Read_ADC_Channel MAC
mov b, %0
lcall _Read_ADC_Channel
ENDMAC

_Read_ADC_Channel:
	clr CE_ADC
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov a, b
	swap a
	anl a, #0F0H
	setb acc.7 ; Single mode (bit 7).
	mov R0, a
	lcall DO_SPI_G
	mov a, R1 ; R1 contains bits 8 and 9
	anl a, #00000011B ; We need only the two least significant bits
	mov R7, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov a, R1
	mov R6, a ; R1 contains bits 0 to 7. Save result low.
	setb CE_ADC
	ret



;-----------------------------------------------------
;data_transofrmation
;-----------------------------------------------------
data_transformation:
	PUSH acc
	;Load_x(Result) ; put result into X
	;mov y+3, #0
	;mov y+2, #0
	;mov y+1, Vcc+1
	;mov y+0, Vcc+0

	;mov x+3, #0
	;mov x+2, #0
	;mov x+1, Result+1
	;mov x, Result
	;lcall mul32; result is stroed in X

	;calculate the Voutput voltage
    ;mov y+0, #low(1023)
	;mov y+1, #high(1023)
	;mov y+2, #0
	;mov y+3, #0
	;lcall div32
	;result store in X

	;mov x+1,Vcc
	;mov x,Vcc

	;Final_result 0
	;Final_result 1
	mov x+3, #0
	mov x+2, #0
	mov x+1, Result+1
	mov x, Result

	mov y+3, #0
	mov y+2, #0
	mov y+1, #high(5000)
	mov y+0, #low(5000)

	lcall mul32



    mov y+3, #0
	mov y+2, #0
	mov y+1, #high(1023)
	mov y+0, #low(1023)
	lcall div32

	lcall hex2bcd
	; bcd has the value of ADC voltage
	;lcall calculation


	Send_BCD(bcd+1)
	Send_BCD(bcd)

    lcall bcd2hex
    mov y+3, #0
	mov y+2, #0
	mov y+1, #high(2730)
	mov y+0, #low(2730)
	lcall sub32
	mov y+3, #0
	mov y+2, #0
	mov y+1, #high(10)
	mov y+0, #low(10)
	lcall div32

	lcall hex2bcd


	lcall display

	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	POP acc
	ret

;---------------------------------;
; Wait for halfs
;---------------------------------;
Delay:
		PUSH AR0
		PUSH AR1
		PUSH AR2

		MOV R2, #200
	L3_1s: MOV R1, #160
	L2_1s: MOV R0, #200
	L1_1s: djnz R0, L1_1s ; 3*45.21123ns*400

		djnz R1, L2_1s ;
		djnz R2, L3_1s ;

		POP AR2
		POP AR1
		POP AR0
		ret
;-------------------------------
;display temperature
;------------------------------
display:
   Set_Cursor(2, 7)
    ;Display_BCD(bcd+4)
    ;Display_BCD(bcd+3)
    ;Display_BCD(bcd+2)
    ;Display_BCD(bcd+1)
    Display_BCD(bcd+0)
    ret




MainProgram:
    lcall LCD_4BIT
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    mov PMOD, #0 ; Configure all ports in bidirectional mode
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)

    lcall InitSerialPort
    ;mov DPTR, #Hello_World
    ;lcall SendString
    clr LM_TH ; set the flag to low initially
    lcall SendVoltage
    ;lcall display

END
