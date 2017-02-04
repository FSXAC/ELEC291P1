; LIT SOLDER OVEN CONTROLLER
; AUTHOR:   SCOTT BEAULIEU (no contributions yet)
;			GEOFF GOODWIN
;			MUCHEN HE
;			LARRY LIU
;			LUFEI LIU
;			WENOA TEVES
; VERSION:	0
; REVISION DATE:	2017-02-03
; http:;i.imgur.com/7wOfG4U.gif

; standard library
$NOLIST
$MODLP52
$LIST

; Preprocessor constants
CLK             equ     22118400
T0_RATE         equ     4096
T0_RELOAD       equ     ((65536-(CLK/4096)))
T2_RATE         equ     1000
T2_RELOAD       equ     (65536-(CLK/T2_RATE))
DEBOUNCE        equ     50
TIME_RATE       equ     1000

org 0x0000
    ljmp    setup
org 0x000B
    ljmp    T0_ISR
org 0x002B
    ljmp    T2_ISR

; States
RAMP2SOAK		equ     1
PREHEAT_SOAK	equ     2
RAMP2PEAK		equ     3
REFLOW			equ     4
COOLING			equ     5

; BUTTONS PINs
BTN_START   	equ 	P2.4
BTN_STATE	    equ 	P2.5
BTN_UP	        equ 	P2.6
BTN_DOWN	  	equ 	P2.7

; Parameters
dseg at 0x30
    soakTemp:   ds  1
    soakTime:   ds  1
    reflowTemp: ds  1
    reflowTime: ds  1
    seconds:    ds  1
    minutes:    ds  1
    countms:    ds  2
    state:      ds  1 ; current state of the controller
bseg
    seconds_f: 	dbit 1
    ongoing_f:	dbit 1			;only check for buttons when the process has not started

; LCD SCREEN
;                     	1234567890ABCDEF
msg_main_top:  		db 'STATE:-  T=--- C', 0  ;State: 1-5
msg_main_btm: 		db '   TIME --:--   ', 0  ;elapsed time
msg_soakTemp:       db 'SOAK TEMP:     <', 0
msg_soakTime:       db 'SOAK TIME:     <', 0
msg_reflowTemp:	    db 'REFLOW TEMP:   <', 0
msg_reflowTime:	    db 'REFLOW TIME:   <', 0
msg_temp:	        db '      --- C    >', 0
msg_time:	        db '     --:--     >', 0
msg_ramptosoak    db '   RampToSoak', 0

; -------------------------;
; Initialize Timer 2	   ;
; -------------------------;
T2_init:
    mov 	T2CON, 	#0
    mov 	RCAP2H, #high(T2_RELOAD)
    mov 	RCAP2L, #low(T2_RELOAD)
    clr 	a
    mov 	countms+0, a
    mov 	countms+1, a
    setb 	ET2  ; Enable timer 2 interrupt
    setb 	TR2  ; Enable timer 2
    ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
T2_ISR:
    clr 	TF2
    push 	acc
    push 	psw
    push 	AR1
    inc 	countms+0
    mov 	a,     countms+0
    jnz 	T2_ISR_incDone
    inc 	countms+1
T2_ISR_incDone:
	; Check if half second has passed
    mov     a,  countms+0
    cjne    a,  #low(TIME_RATE),    Timer2_ISR_done
    mov     a,  countms+1
    cjne    a,  #high(TIME_RATE),   Timer2_ISR_done
    ; Let the main program know half second had passed
    setb 	seconds_f
    ; reset 16 bit ms counter
    clr 	a
    mov 	countms+0,     a
    mov 	countms+1,     a
    ; Increment seconds
    mov     a,   seconds
    add     a,   #0x01
    ; BCD Conversion
    da 	    a
    mov     seconds,    a
    clr     c
    ; increment minutes when seconds -> 60
    subb    a,          #0x60
    jz 	    T2_ISR_minutes
    sjmp 	T2_ISR_return
T2_ISR_minutes:
    mov     a,          minutes
    add     a,          #0x01
    da 	    a
    mov     minutes,    a
    mov     seconds,    #0x00
    sjmp    T2_ISR_return
T2_ISR_return:
    pop 	AR1
    pop 	psw
    pop 	acc
    reti

;-----------------------------;
;	MAIN PROGRAM		      ;
;-----------------------------;
setup:
    mov     SP,     #0x7F
    mov     PMOD,   #0
    lcall   T2_init
    setb    EA
    lcall   LCD_4BIT
    LCD_cursor(1, 1)
    LCD_print(#msg_main_top)
    LCD_cursor(2, 1)
    LCD_print(#msg_main_btm)
    clr	    ongoing_f
    setb    seconds_f
    mov     seconds,    #0x00   			; initial seconds
    mov     minutes,    #0x00 				; initial minutes
main:
    ; MAIN MENU LOOP
    ; CHECK: [START], [STATE]
    ; [START] - start the reflow program


    mov state, #0  ; reset our state to 0

main_button_start:
    jb 		BTN_START, main_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_START, main_button_state
    jnb 	BTN_START, $
    ; **PUT WHAT HAPPENS IF YOU PRESS START HERE LMAO HELP ME LORD
main_button_state:
    ; [STATE] - configure reflow program
    jb 		BTN_STATE, main_update
    sleep(#DEBOUNCE)
    jb 		BTN_STATE, main_update
    jnb 	BTN_STATE, $
    ljmp    conf_soakTemp
main_update:
  ; **update time and temperature display here
; compare temperature and time to change STATE
; state 1, 100% power; reach to 150 C in 120 seconds (aprox.)
state1:
    cjne a, RAMP2SOAK, state2
    ; display on LCD
    LCD_cursor(1,1)
    LCD_print(#msg_ramptosoak)
    LCD_cursor(2,1)
    LCD_print(#msg_soakTemp)
    LCD_print(soakTemp) ; need to convert our ADC voltage into decimal
    LCD_cursor(2,8)
    LCD_print(#msg_soakTime)
    LCD_print(soakTime)

    mov pwm, #100 ; (Geoff pls change this line of code to fit)
    mov soakTime, #0
    mov a, #150
    clr c
    subb a, soakTemp ; here our soaktime has to be in binary or Decimal not ADC
    jnc state1_done
    mov state, #2
state1_done:
    ljmp forever ; here should it be state1?

state2:
    cjne a, #2, state3



state3:




state2:


  ; **update time and temperature display here
    ljmp 	main

;-------------------------------------;
; CONFIGURE: Soak Temperature 		  ;
;-------------------------------------;
conf_soakTemp:
    ; change LCD screen to soak temperature interface
    LCD_cursor(1, 1)
    LCD_print(#msg_soakTemp)
    LCD_cursor(2, 1)
    LCD_print(#msg_temp)

conf_soakTemp_button_up:
    jb 		BTN_UP, conf_soakTemp_button_down
    sleep(#DEBOUNCE)
    jb 		BTN_UP, conf_soakTemp_button_down
    jnb 	BTN_UP, $

    ; increment soak temperature
    mov 	a,     soakTemp
    add		a,     #0x01
    da		a
    mov		soakTemp, a

conf_soakTemp_button_down:
    jb 		BTN_DOWN, conf_soakTemp_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_DOWN, conf_soakTemp_button_state
    jnb 	BTN_DOWN, $
    ; decrement soak temp (((FIXME)))

conf_soakTemp_button_state:
    jb 		BTN_STATE, conf_soakTemp
    sleep(#DEBOUNCE)
    jb 		BTN_STATE, conf_soakTemp
    jnb 	BTN_STATE, $
    ljmp 	conf_soakTime
	setb 	ongoing_flag

;-------------------------------------;
; CONFIGURE: Soak Time       		  ;
;-------------------------------------;
conf_soakTime:
	; **Update LCD Screen
    LCD_cursor(1, 1)
    LCD_print(#msg_soakTime)
    LCD_cursor(2, 1)
    LCD_print(#msg_time)

conf_soakTime_button_up:
    jb 		BTN_UP, conf_soakTime_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_soakTime_button_down
	jnb 	BTN_UP, $
    ; lcall 	inc_soak_time

conf_soakTime_button_down:
    jb 		BTN_DOWN, conf_soakTime_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_soakTime_button_state
	jnb 	BTN_DOWN, $
    ; lcall 	dec_soak_time

conf_soakTime_button_state:
    jb 		BTN_STATE, conf_soakTime
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_soakTime
	jnb 	BTN_STATE, $
    ljmp 	Reflow_Temp_Interface

;-------------------------------------;
; CONFIGURE: Reflow Temperature		  ;
;-------------------------------------;
conf_reflowTemp:
    ; **Update LCD Screen
    LCD_cursor(1, 1)
    LCD_print(#msg_reflowTemp)
    LCD_cursor(2, 1)
    LCD_print(#msg_temp)

conf_reflowTemp_button_up:
    jb 		BTN_UP, conf_reflowTemp_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_reflowTemp_down
	jnb 	BTN_UP, $
    ; lcall 	inc_reflow_temp

conf_reflowTemp_button_down:
    jb 		BTN_DOWN, conf_reflowTemp_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_reflowTemp_button_state
	jnb 	BTN_DOWN, $
    ; lcall 	dec_reflow_temp

conf_reflowTemp_button_state:
    jb 		BTN_STATE, conf_reflowTemp
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_reflowTemp
	jnb 	BTN_STATE, $
    ljmp 	conf_reflowTime

;-------------------------------------;
; CONFIGURE: Reflow Time  			  ;
;-------------------------------------;
conf_reflowTime:
    ; **Update LCD Screen
    LCD_cursor(1, 1)
    LCD_print(#msg_reflowTime)
    LCD_cursor(2, 1)
    LCD_print(#msg_time)

conf_reflowTime_button_up:
    jb 		BTN_UP, conf_reflowTime_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_reflowTime_button_down
	jnb 	BTN_UP, $
    ; lcall 	inc_reflow_time

conf_reflowTime_button_down:
    jb 		BTN_DOWN, conf_reflowTime_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_reflowTime_button_state
	jnb 	BTN_DOWN, $
    ; lcall 	dec_reflow_time

conf_reflowTime_button_state:
    jb 		BTN_STATE, conf_reflowTime
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_reflowTime
	jnb 	BTN_STATE, $
    ljmp 	main
END
