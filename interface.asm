;LIT SOLDER OVEN CONTROLLER
; AUTHOR:   SCOTT BEAULIEU (no contributions yet)
;			GEOFF GOODWIN
;			MUCHEN HE
;			LARRY LIU
;			LUFEI LIU
;			WENOA TEVES
; VERSION:	0
; LAST REVISION:	2017-02-05
; http:;i.imgur.com/7wOfG4U.gif


org 0x0000
    ljmp    setup
; org 0x000B
;     ljmp    T0_ISR
org 0x002B
    ljmp    T2_ISR

; standard library
$NOLIST
$MODLP52
$LIST
$include(macros.inc)
$include(LCD_4bit.inc)

; Preprocessor constants
CLK             equ     22118400
T0_RATE         equ     4096
T0_RELOAD       equ     ((65536-(CLK/4096)))
T2_RATE         equ     1000
T2_RELOAD       equ     (65536-(CLK/T2_RATE))
DEBOUNCE        equ     50
TIME_RATE       equ     1000

LCD_RS          equ     P1.2
LCD_RW          equ     P1.3
LCD_E           equ     P1.4
LCD_D4          equ     P3.2
LCD_D5          equ     P3.3
LCD_D6          equ     P3.4
LCD_D7          equ     P3.5


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
    soakTemp:       ds  1
    soakTime:       ds  1
    reflowTemp:     ds  1
    reflowTime:     ds  1
    seconds:        ds  1
    minutes:        ds  1
    countms:        ds  2
    state:          ds  1 ; current state of the controller
    crtTemp:	    ds	1			; temperature of oven

bseg
    seconds_f: 	dbit 1
    ongoing_f:	dbit 1			;only check for buttons when the process has not started (JK just realized we might not need this..)

cseg
; LCD SCREEN
;                     	1234567890123456
msg_main_top:  		db 'STATE:-  T=--- C', 0  ;State: 1-5
msg_main_btm: 		db '   TIME --:--   ', 0  ;elapsed time
msg_soakTemp:       db 'SOAK TEMP:     <', 0
msg_soakTime:       db 'SOAK TIME:     <', 0
msg_reflowTemp:	    db 'REFLOW TEMP:   <', 0
msg_reflowTime:	    db 'REFLOW TIME:   <', 0
msg_temp:	        db '      --- C    >', 0
msg_time:	        db '     --:--     >', 0
msg_state1:         db '   RampToSoak   ', 0
msg_fsm:            db '  --- C  --:--  ', 0

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
    cjne    a,  #low(TIME_RATE),    T2_ISR_return
    mov     a,  countms+1
    cjne    a,  #high(TIME_RATE),   T2_ISR_return
    setb 	seconds_f
    ; reset 16 bit ms counter
    clr 	a
    mov 	countms+0,     a
    mov 	countms+1,     a
    ; Increment seconds
    mov     a,   seconds
    add     a,   #0x01
    ; BCD Conversion and writeback
    da 	    a
    mov     seconds,    a
    ; increment minutes when seconds -> 60
    clr     c
    subb    a,          #0x60
    jz 	    T2_ISR_minutes
    sjmp 	T2_ISR_return
T2_ISR_minutes:
    mov     a,          minutes
    add     a,          #0x01
    da 	    a
    mov     minutes,    a
    mov     seconds,    #0x00
    ; reset minute to 0 when minutes -> 60
    clr     c
    subb    a,          #0x60
    jnz     T2_ISR_return
    mov     minutes,    #0x00
T2_ISR_return:
    pop 	AR1
    pop 	psw
    pop 	acc
    reti

;-----------------------------;
; Initialize SPI		      ;
;-----------------------------;
; SPI_init:
;     ; debounce reset button
;     mov     R1,     #222
;     mov     R0,     #166
;     djnz    R0,     $
;     djnz    R1,     $-4
;     ; set timer
;     clr     TR1
;     anl     TMOD,   #0x0f
;     orl	    TMOD,   #0x20
;     orl	    PCON,   #0x80
;     mov	    TH1,    #T1LOAD
;     mov	    TL1,    #T1LOAD
;     setb    TR1
;     mov	    SCON,   #0x52
;     ret
;-----------------------------;
; Initialize comm to ADC      ;
;-----------------------------;
; ADC_init:
;     setb    ADC_MISO
;     clr     ADC_SCLK
;     ret
;-----------------------------;
; Communicate with ADC        ;
;-----------------------------;
; send byte in R0, receive byte in R1
; ADC_comm:
;     push    ACC
;     mov     R1,     #0
;     mov     R2,     #8
; ADC_comm_loop:
;     mov     a,      R0
;     rlc     a
;     mov     R0,     a
;     mov     ADC_MOSI,   c
;     setb    ADC_SCLK
;     mov     c,      ADC_MISO
;     mov     a,      R1
;     rlc     a
;     mov     R1,     a
;     clr     ADC_SCLK
;     djnz    R2,     SPIcomm_loop
;     pop     ACC
;     ret

;-----------------------------;
;	MAIN PROGRAM		      ;
;-----------------------------;
setup:
    mov     SP,     #0x7F
    mov     PMOD,   #0
    lcall   T2_init
    setb    EA
    lcall   LCD_config

    clr	    ongoing_f
    setb    seconds_f						; may not need this..
    mov     seconds,    #0x00   			; initialize variables
    mov     minutes,    #0x00
    mov		soakTemp, 	#0x00
    mov		soakTime, 	#0x00
	mov		reflowTemp, #0x00
    mov		reflowTime, #0x00
   	mov 	crtTemp,	#0x00	            ; temporary for testing purposes
main:
    ; MAIN MENU LOOP
    ; CHECK: [START], [STATE]
    ; [START] - start the reflow program
    LCD_cursor(1, 1)
    LCD_print(#msg_main_top)
    LCD_cursor(2, 1)
    LCD_print(#msg_main_btm)
    LCD_cursor(1, 15)
    LCD_printChar(#0xDF)    ; deg symbol
main_button_start:
    jb 		BTN_START, main_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_START, main_button_state
    jnb 	BTN_START, $
    setb	ongoing_f

    ; **PUT WHAT HAPPENS IF YOU PRESS START HERE LMAO HELP ME LORD (whatever goes here has to connect to main_update and check for stop button)

main_button_state:
	jb		ongoing_f, main_update	; skip checking for state if process has started
    ; [STATE] - configure reflow program
    jb 		BTN_STATE, main_update
    sleep(#DEBOUNCE)
    jb 		BTN_STATE, main_update
    jnb 	BTN_STATE, $
    ljmp    conf_soakTemp
main_update:
	; update time and ** temperature display here
    LCD_cursor(2, 9)
    LCD_printBCD(minutes)
    LCD_cursor(2, 12)
    LCD_printBCD(seconds)
    LCD_cursor(1, 12)
    LCD_printBCD(crtTemp) ; TODO FIXME
    ljmp 	main_button_start

;-------------------------------------;
; CONFIGURE: Soak Temperature 		  ;
;-------------------------------------;
conf_soakTemp:
    ; change LCD screen to soak temperature interface
    LCD_cursor(1, 1)
    LCD_print(#msg_soakTemp)
	LCD_cursor(2, 1)
    LCD_print(#msg_temp)
conf_soakTemp_update:
    LCD_cursor(2, 7)
	LCD_printTemp(soakTemp)	; display soak temperature on LCD

conf_soakTemp_button_up:
    jb 		BTN_UP, conf_soakTemp_button_down
    sleep(#DEBOUNCE)
    jb 		BTN_UP, conf_soakTemp_button_down
    jnb 	BTN_UP, $
	increment_BCD(soakTemp, #1)

conf_soakTemp_button_down:
    jb 		BTN_DOWN, conf_soakTemp_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_DOWN, conf_soakTemp_button_state
    jnb 	BTN_DOWN, $
    decrement_BCD(soakTemp, #1)

conf_soakTemp_button_state:
    jb 		BTN_STATE, conf_soakTemp_j
    sleep(#DEBOUNCE)
    jb 		BTN_STATE, conf_soakTemp_j
    jnb 	BTN_STATE, $
    ljmp 	conf_soakTime
conf_soakTemp_j:
	ljmp    conf_soakTemp_update

;-------------------------------------;
; CONFIGURE: Soak Time       		  ;
;-------------------------------------;
conf_soakTime:
	; **Update LCD Screen
    LCD_cursor(1, 1)
    LCD_print(#msg_soakTime)
	LCD_cursor(2, 1)
    LCD_print(#msg_time)
conf_soakTime_update:
    LCD_printTime(soakTime) ; soakTime is a variable for seconds, convert into minutes and seconds here

conf_soakTime_button_up:
    jb 		BTN_UP, conf_soakTime_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_soakTime_button_down
	jnb 	BTN_UP, $
    lcall 	inc_soak_time

conf_soakTime_button_down:
    jb 		BTN_DOWN, conf_soakTime_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_soakTime_button_state
	jnb 	BTN_DOWN, $
    lcall 	dec_soak_time

conf_soakTime_button_state:
    jb 		BTN_STATE, conf_soakTime_j
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_soakTime_j
	jnb 	BTN_STATE, $
    ljmp 	conf_reflowTemp

conf_soakTime_j:
	ljmp    conf_soakTime_update

;-------------------------------------;
; CONFIGURE: Reflow Temperature		  ;
;-------------------------------------;
conf_reflowTemp:
    ; **Update LCD Screen
    LCD_cursor(1, 1)
    LCD_print(#msg_reflowTemp)
	LCD_cursor(2, 1)
    LCD_print(#msg_temp)
conf_reflowTemp_update:
    LCD_cursor(2, 7)
	LCD_printTemp(reflowTemp)

conf_reflowTemp_button_up:
    jb 		BTN_UP, conf_reflowTemp_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_reflowTemp_button_down
	jnb 	BTN_UP, $
	increment_BCD(reflowTemp, #1)

conf_reflowTemp_button_down:
    jb 		BTN_DOWN, conf_reflowTemp_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_reflowTemp_button_state
	jnb 	BTN_DOWN, $
	decrement_BCD(reflowTemp, #1)

conf_reflowTemp_button_state:
    jb 		BTN_STATE, conf_reflowTemp_j
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_reflowTemp_j
	jnb 	BTN_STATE, $
    ljmp 	conf_reflowTime

conf_reflowTemp_j:
	ljmp	conf_reflowTemp_update


;-------------------------------------;
; CONFIGURE: Reflow Time  			  ;
;-------------------------------------;
conf_reflowTime:
    ; **Update LCD Screen
    LCD_cursor(1, 1)
    LCD_print(#msg_reflowTime)
	LCD_cursor(2, 1)
    LCD_print(#msg_time)
conf_reflowTime_update:
    LCD_printTime(reflowTime)

conf_reflowTime_button_up:
    jb 		BTN_UP, conf_reflowTime_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_reflowTime_button_down
	jnb 	BTN_UP, $
    lcall 	inc_reflow_time

conf_reflowTime_button_down:
    jb 		BTN_DOWN, conf_reflowTime_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_reflowTime_button_state
	jnb 	BTN_DOWN, $
    lcall 	dec_reflow_time

conf_reflowTime_button_state:
    jb 		BTN_STATE, conf_reflowTime_j
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_reflowTime_j
	jnb 	BTN_STATE, $
    ljmp 	main

conf_reflowTime_j:
	ljmp    conf_reflowTime_update

;------------------------------;
; 		FUNCTION CALLS		   ; ABCDEF
;------------------------------;
; increment soak time by 5 seconds
inc_soak_time:
	mov 	a, soakTime
    add		a, #0x05
    mov		soakTime, a
	ret

; decrement soak time by 5 seconds
dec_soak_time:
	mov		a, soakTime
    add		a, #0xFB
    mov		soakTime, a
	ret

inc_reflow_time:
    mov 	a, reflowTime
    add		a, #0x05
    mov		reflowTime, a
	ret

dec_reflow_time:
	mov 	a, reflowTime
    add		a, #0xFB
    mov		reflowTime, a
	ret

; === END OF PROGRAM ===
END
