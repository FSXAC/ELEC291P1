; LIT SOLDER OVEN CONTROLLER
; AUTHOR:
;			GEOFF GOODWIN
;			MUCHEN HE
;			LARRY LIU
;			LUFEI LIU
;			WENOA TEVES
; VERSION:	0
; REVISION DATE:	2017-02-02
; http:;i.imgur.com/7wOfG4U.gif

$MODLP52

; VECTORS
org 0x0000
    ljmp	init
org 0x000B
    ljmp	T0_ISR

; IMPORTS
$include(LCD_4bit.inc)
$include(math32.inc)

; CONSTANTS
CLK					equ		22118400
BAUD				equ 	115200
TIMER0_RELOAD		equ		((65536-(CLK/4096))
TIMER1_RELOAD		equ		(0x100-CLK/(16*BAUD))
TIMER2_RATE   		equ 	1000     ; Timer 2 for elapsed time
TIMER2_RELOAD 		equ 	((65536-(CLK/TIMER2_RATE)))

; ADC PINs
CSEG
ADC_CE				equ		P2.0
ADC_MOSI			equ 	P2.1
ADC_MISO			equ		P2.2
ADC_SCLK			equ		p2.3

; BUTTONS PINs
BTN_START   		equ 	P2.4
BTN_STATE	     	equ 	P2.5
BTN_UP	        	equ 	P2.6
BTN_DOWN	  		equ 	P2.7

; OVEN CONTORL
SSR_OUT				equ 	P0.0

; SOUND
SOUND_OUT			equ		P3.7

; LCD SCREEN
;                   		1234567890123456
MainScreen_Top:  		db 'STATE:X  T=xxx C', 0  ;State: 1-5
MainScreen_Bottom: 		db '   TIME XX:XX   ', 0  ;elapsed time
Soak_Temp1:				db 'SOAK TEMP:     <', 0
Soak_Temp2: 			db '	  XXX C    >', 0

Reflow_Temp1:			db 'REFLOW TEMP:    ', 0

Soak_Time1:				db 'SOAK TIME:     <', 0
Soak_Time2:				db '     XX:XX     >', 0

Reflow_Time1:			db 'REFLOW TIME:   <', 0
Reflow_Time2: 			db '     XX:XX     >', 0


; Variables
DSEG
Count1ms: ds 2

BSEG
Second_Flag: db 1


CSEG


; ===[MAIN PROGRAM]===
init:
    mov 	SP,		#0x7H
    mov 	PMOD,	#0

    ; initalize MCP3008
    setb	ADC_CE
loop:
    ljmp	loop

; END OF PROGRAM
END
