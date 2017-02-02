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

; States
RAMP2SOAK		equ 1
PREHEAT_SOAK	equ 2
RAMP2PEAK		equ 3
REFLOW			equ 4
COOLING			equ 5

; BUTTONS PINs
BTN_START   	equ 	P2.4
BTN_STATE	    equ 	P2.5
BTN_UP	        equ 	P2.6
BTN_DOWN	  	equ 	P2.7

; Parameters
dseg at 0x30
  soakTemp:		ds 1 ; soak temperature
  soakTime:		ds 1 ; soak time
  reflowTemp:	ds 1 ; reflow temperature
  reflowTime:	ds 1 ; reflow time
  Count1ms:		ds 2 ; counting seconds
  seconds:		ds 1 ; seconds counter
  minutes:		ds 1 ; minutes counter

bseg
  seconds_flag: 	dbit 1
  ongoing_flag:		dbit 1			;only check for buttons when the process has not started

;LCD SCREEN
;                     		1234567890123456
MainScreen_Top:  		db 'STATE:X  T=xxx C', 0  ;State: 1-5
MainScreen_Bottom: 		db '   TIME XX:XX   ', 0  ;elapsed time
Soak_Temp1:				db 'SOAK TEMP:     <', 0
Soak_Temp2: 			db '	  XXX C    >', 0

Reflow_Temp1:			db 'REFLOW TEMP:    ', 0

Soak_Time1:				db 'SOAK TIME:     <', 0
Soak_Time2:				db '     XX:XX     >', 0

Reflow_Time1:			db 'REFLOW TIME:   <', 0
Reflow_Time2: 			db '     XX:XX     >', 0


; ---------------------------------;
; Initialize Timer 2 Interrupt		;
; ---------------------------------;
Timer2_Init:
	mov 	T2CON, 	#0
	mov 	RCAP2H, #high(TIMER2_RELOAD)
	mov 	RCAP2L, #low(TIMER2_RELOAD)
	clr 	a
	mov 	Count1ms+0, a
	mov 	Count1ms+1, a
    setb 	ET2  ; Enable timer 2 interrupt
    setb 	TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr 	TF2 		; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	cpl 	P3.6 		; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.

	; The two registers used in the ISR must be saved in the stack
	push 	acc
	push 	psw
	push 	AR1

	; Increment the 16-bit one mili second counter
	inc 	Count1ms+0    		; Increment the low 8-bits first
	mov 	a, Count1ms+0 		; If the low 8-bits overflow, then increment high 8-bits
	jnz 	Inc_Done
	inc 	Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov 	a, Count1ms+0
	cjne 	a, #low(1000), Timer2_ISR_done
	mov 	a, Count1ms+1
	cjne 	a, #high(1000), Timer2_ISR_done

	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb 	seconds_flag 			; Let the main program know half second had passed
    cpl 	TR0 					; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr 	TR0
	clr 	a
	mov 	Count1ms+0, a
	mov 	Count1ms+1, a
	; Increment the BCD counter
	mov 	a, seconds
	add 	a, #0x01
    ; BCD Conversion
	da 		a
	mov 	seconds, a
	clr 	c
	subb 	a, #0x60
	jz 		minute					; Increment minute after 60 Seconds
	sjmp 	Timer2_ISR_done
minute:
	mov 	a, minutes
	add 	a, #0x01
	da 		a
	mov 	minutes, a
	mov 	seconds, #0x00
	sjmp Timer2_ISR_done
Timer2_ISR_done:
	pop 	AR1
	pop 	psw
	pop 	acc
	reti


;-----------------------------;
;	MAIN PROGRAM		       ;
;-----------------------------;
main:
    mov 	SP, #0x7F
    mov 	PMOD, #0
    lcall 	Timer2_Init
    setb 	EA
    lcall 	LCD_4BIT
	Set_Cursor(1, 1)
    Send_Constant_String(#MainScreen_Top)
    Set_Cursor(2, 1)
  	Send_Constant_String(#MainScreen_Bottom)
    clr		ongoing_flag
    setb 	seconds_flag
	mov 	seconds, #0x00   			; initial seconds
	mov 	minutes, #0x00 				; initial minutes

main_loop:
    jb 		BTN_START, check_state_0  				; if the button is not pressed skip
	Wait_Milli_Seconds(#50)						; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb 		BTN_START, check_state_0  				; if the button is not pressed skip
	jnb 	BTN_START, $						; Wait for button release.




;-------------------------------------;
;			SOAK TEMPERATURE		   ;
;-------------------------------------;
Soak_Temp_Interface:
    ljmp 	set_Soak_Temp_Interface

check_state_1:
    jb 		BTN_STATE, Soak_Temp_Interface  	; if the button is not pressed skip
	Wait_Milli_Seconds(#50)						; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb 		BTN_STATE, Soak_Temp_Interface   	; if the button is not pressed skip
	jnb 	BTN_STATE, $						; Wait for button release.
    ljmp

set_Soak_Temp_Interface:
	; Update LCD Screen
    jb 		BTN_UP, check_temp_down  				; if the button is not pressed skip
	Wait_Milli_Seconds(#50)							; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb 		BTN_UP, check_temp_down  				; if the button is not pressed skip
	jnb 	BTN_UP, $								; Wait for button release.
    lcall 	inc_soak_temp

    jb 		BTN_DOWN, check_state_1  				; if the button is not pressed skip
	Wait_Milli_Seconds(#50)							; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb 		BTN_DOWN, check_state_1  				; if the button is not pressed skip
	jnb 	BTN_DOWN, $								; Wait for button release.
    lcall 	dec_soak_temp

ljmp Check_State
	setb 	ongoing_flag



inc_soak_temp:
	mov 	a, soakTemp
    add		a, #0x01
    da		a
    mov		soakTemp, a
