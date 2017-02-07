;LIT SOLDER OVEN CONTROLLER
; AUTHOR:   SCOTT BEAULIEU
;			GEOFF GOODWIN
;			MUCHEN HE
;			LARRY LIU
;			LUFEI LIU
;			WENOA TEVES
; VERSION:	0
; LAST REVISION:	2017-02-03 MANSUR HE
; http:;i.imgur.com/7wOfG4U.gif


org 0x0000
    ljmp    setup
;org 0x000B
;    ljmp    T0_ISR
org 0x002B
    ljmp    T2_ISR

; standard library
$NOLIST
$MODLP52
$LIST

$include(macros.inc)
$include(LCD_4bit.inc)
$include(math32.inc)


; Preprocessor constants
CLK             equ     22118400
BAUD            equ     115200
T0_RATE         equ     4096
T0_RELOAD       equ     ((65536-(CLK/4096)))
T1_RELOAD       equ     (0x100-CLK/(16*BAUD))
T2_RATE         equ     1000
T2_RELOAD       equ     (65536-(CLK/T2_RATE))
DEBOUNCE        equ     50
TIME_RATE       equ     1000

; LCD PINS
LCD_RS          equ     P1.2
LCD_RW          equ     P1.3
LCD_E           equ     P1.4
LCD_D4          equ     P3.2
LCD_D5          equ     P3.3
LCD_D6          equ     P3.4
LCD_D7          equ     P3.5

; BUTTONS PINs
BTN_START   	equ 	P2.4
BTN_STATE	    equ 	P2.5
BTN_UP	        equ 	P2.6
BTN_DOWN	  	equ 	P2.7

; ADC SPI PINS
ADC_CE      equ     P2.0
ADC_MOSI    equ     P2.1
ADC_MISO    equ     P2.2
ADC_SCLK    equ     P2.3

; SSR / oven control pin
SSR         equ     P3.7

; States
RAMP2SOAK		equ     1
PREHEAT_SOAK	equ     2
RAMP2PEAK		equ     3
REFLOW			equ     4
COOLING			equ     5

; Parameters
dseg at 0x30
    soakTemp:   ds  1
    soakTime:   ds  1
    reflowTemp: ds  1
    reflowTime: ds  1
    seconds:    ds  1
    minutes:    ds  1
    countms:    ds  2
    state:      ds  1
    crtTemp:	ds	1			; temperature of oven
    perCntr:	ds  1 ; counter to count period in PWM
	ovenPower:	ds  1 ; currnet power of the oven, number between 0 and 10

    ; for math32
    result:         ds  2
    bcd:            ds  5
    x:              ds  4
    y:              ds  4

bseg
    seconds_flag: 	dbit 1
    ongoing_flag:	dbit 1			;only check for buttons when the process has not started (JK just realized we might not need this..)
    oven_enabled:	dbit 1

    ; for math32
    mf:             dbit 1

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


; -------------------------;
; Increment Macro		   ;
; -------------------------;
Increment_variable mac
    mov     a,      %0
    add     a,      #0x01
    mov     %0,     a
endmac
; -------------------------;
; Decrement Macro		   ;
; -------------------------;
Decrement_variable mac
    mov     a,      %0
    add	    a,      #0xFF
    mov     %0,     a
endmac

; -------------------------;
; Print Time Macro		   ;		; does this even work like this? QQ
; -------------------------;
Print_Time mac
    push    ACC
    push    AR2
    push    AR3
	mov 	a, %0
    mov 	b, #60
    div		ab				; minutes are in a, seconds are in b

	mov		R2, b

    mov 	b, #10
    div		ab				; result is in a, remainder is in b
    LCD_cursor(2, 6)
    add		a, #0x30
    mov		R3, a
    Display_Char(R3)

    LCD_cursor(2, 7)
    mov		a, b
    add		a, #0x30
    mov		b, a
    Display_Char(b)

    mov		b, #10
    mov		a, R2
    div		ab
    LCD_cursor(2, 9)
    add		a, #0x30
    mov		R3, a
    Display_Char(R3)

    LCD_cursor(2, 10)
    mov		a, b
    add		a, #0x30
    mov		b, a
    Display_Char(b)
    pop     AR2
    pop     AR3
    pop     ACC
endmac

; -------------------------;
; Print Temp Macro		   ;
; -------------------------;
Print_Temp mac
    push    ACC
    push    AR1
	mov 	a, %0
    mov 	b, #100
    div		ab				; result is in a, remainder is in b
    LCD_cursor(2, 7)
    add		a, #0x30
    mov		R1, a
    Display_Char(R1)
    mov		a, b
    mov		b, #10
    div		ab
    add		a, #0x30
    mov		R1, a
    LCD_cursor(2, 8)
    Display_Char(R1)
    LCD_cursor(2, 9)
    mov		a, b
    add		a, #0x30
    mov		b, a
    Display_Char(b)
    pop     AR1
    pop     ACC
endmac

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

    ; PWM
    lcall   PWM_oven

T2_ISR_incDone:
	; Check if half second has passed
    mov     a,  countms+0
    cjne    a,  #low(TIME_RATE),    T2_ISR_return
    mov     a,  countms+1
    cjne    a,  #high(TIME_RATE),   T2_ISR_return
    ; Let the main program know half second had passed
    setb 	seconds_flag
    ; reset 16 bit ms counter
    clr 	a
    mov 	countms+0,     a
    mov 	countms+1,     a
    ; Increment seconds
    mov     a,   seconds
    add     a,   #0x01
    ; BCD Conversion and write back
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

    ; CHANGED
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

;---------------------------------;
; Pulse Width Modulation		  ;
; Power: [#0-#10]				  ;
; Period: #10					  ;
; Occurs roughly every half sec.  ;
;---------------------------------;
PWM_oven:
    push    ACC
    mov     a,              perCntr
    jnb     oven_enabled,   PWM_oven_on
    ; toaster is now off, check to see if toaster should be turned on
    cjne    a,  ovenPower,  PWM_cont
    ; if power 10, then never turn off (corner case)
    mov     a,  ovenPower
    cjne    a,  #10,    PWM_corner1false
    ljmp    PWM_corner1true
PWM_corner1false:
    setb    SSR
PWM_corner1true:
    setb    oven_enabled
    ljmp    PWM_cont
PWM_oven_on:
    ; toaster is now on, check to see if toaster should be turned off
    cjne    a,  #10,    PWM_cont
    ; if power 0, then never turn on (corner case)
    mov     a,  ovenPower
    cjne    a,  #0,     PWM_corner2false
    ljmp    PWM_corner2true
PWM_corner2false:
    clr     SSR
PWM_corner2true:
    clr     oven_enabled
    clr     a
    mov     perCntr,    a
    sjmp    PWM_return
PWM_cont:
    inc     perCntr
    sjmp    PWM_return
PWM_return:
    pop     ACC
    ret

;-----------------------------;
; Initialize SPI		      ;
;-----------------------------;
SPI_init:
    ; debounce reset button
    mov     R1,     #222
    mov     R0,     #166
    djnz    R0,     $
    djnz    R1,     $-4
    ; set timer
    clr     TR1
    anl     TMOD,   #0x0f
    orl	    TMOD,   #0x20
    orl	    PCON,   #0x80
    mov	    TH1,    #T1_RELOAD
    mov	    TL1,    #T1_RELOAD
    setb    TR1
    mov	    SCON,   #0x52
    ret

;-----------------------------;
; Initialize comm to ADC      ;
;-----------------------------;
ADC_init:
    setb    ADC_MISO
    clr     ADC_SCLK
    ret
;-----------------------------;
; Communicate with ADC        ;
;-----------------------------;
; send byte in R0, receive byte in R1
ADC_comm:
    push    ACC
    mov     R1,     #0
    mov     R2,     #8
ADC_comm_loop:
    mov     a,      R0
    rlc     a
    mov     R0,     a
    mov     ADC_MOSI,   c
    setb    ADC_SCLK
    mov     c,      ADC_MISO
    mov     a,      R1
    rlc     a
    mov     R1,     a
    clr     ADC_SCLK
    djnz    R2,     ADC_comm_loop
    pop     ACC
    ret

;-----------------------------;
; Get number from ADC         ;
;-----------------------------;
ADC_get:
    push    ACC
    push    AR0
    push    AR1
    clr     ADC_CE

    ; starting bit is set to 1
    mov     R0,     #0x01
    lcall   ADC_comm

    ; read channel 0 and save to result
    ; read lower 2 bits of upper byte: ------XX --------
    mov     R0,         #0x80
    lcall   ADC_comm
    mov     a,          R1
    anl     a,          #0x03
    mov     result+1,   a

    ; read lower byte: -------- XXXXXXXX
    mov     R0,         #0x55   ; random command
    lcall   ADC_comm
    mov     result,     R1
    setb    ADC_CE

    ; delay
    ; sleep(#50)

    ; convert result into BCD using math32
    mov     x,      result
    mov     x+1,    result+1
    mov     x+2,    #0x00
    mov     x+3,    #0x00
    lcall   hex2bcd
    mov     result,     bcd
    mov     result+1,   bcd+1

    ; restore registers
    pop     AR1
    pop     AR0
    pop     ACC
    ret

;-----------------------------;
;	MAIN PROGRAM		      ;
;-----------------------------;
setup:
    mov     SP,     #0x7F
    mov     PMOD,   #0

    ; Timer setup
    lcall   T2_init
    setb    EA

    ; LCD setup
    lcall   LCD_4BIT

    ; PWM setup
    mov     ovenPower,      #0 ;choose initial power here (0-10)
    setb    oven_enabled
    mov     perCntr,        #10

    ; Initialize MCP3008 ADC
    setb    ADC_CE
    lcall   ADC_init
    lcall   SPI_init

    clr	    ongoing_flag
    setb    seconds_flag       				; may not need this..
    mov     seconds,    #0x00   			; initialize variables
    mov     minutes,    #0x00
    mov		soakTemp, 	#0x00
    mov		soakTime, 	#0x00
	mov		reflowTemp, #0x00
    mov		reflowTime, #0x00
   	mov 	crtTemp,	#0x00	;temporary for testing purposes
main:
    ; MAIN MENU LOOP
    ; CHECK: [START], [STATE]
    LCD_cursor(1, 1)
    LCD_print(#msg_main_top)
    LCD_cursor(2, 1)
    LCD_print(#msg_main_btm)
    LCD_cursor(1, 15)
    Display_char(#0xDF)
main_button_start:
    ; [START] - start the reflow program
    jb 		BTN_START, main_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_START, main_button_state
    jnb 	BTN_START, $
    setb	ongoing_flag

    ; **PUT WHAT HAPPENS IF YOU PRESS START HERE LMAO HELP ME LORD (whatever goes here has to connect to main_update and check for stop button)

main_button_state:
    ; [STATE] - configure reflow program
	jb		ongoing_flag, main_update	; skip checking for state if process has started
    jb 		BTN_STATE, main_update
    sleep(#DEBOUNCE)
    jb 		BTN_STATE, main_update
    jnb 	BTN_STATE, $
    ljmp    conf_soakTemp
main_update:
	; update time and ** temperature display here
    LCD_cursor(2, 9)
    Display_BCD(minutes)
    LCD_cursor(2, 12)
    Display_BCD(seconds)
    LCD_cursor(1, 12)
    Print_Temp(crtTemp)							; where is the temperature coming from ??
    ljmp 	main_button_start

;-------------------------------------;
; CONFIGURE: Soak Temperature 		  ;
;-------------------------------------;
conf_soakTemp:
    ; CHECK: [STATE], [UP], [DOWN]
    ; soak temperature interface
    LCD_cursor(1, 1)
    LCD_print(#msg_soakTemp)
	LCD_cursor(2, 1)
    LCD_print(#msg_temp)
conf_soakTemp_update:
    LCD_cursor(2, 7)
	Print_Temp(soakTemp)					; display soak temperature on LCD

conf_soakTemp_button_up:
    ; [UP] increment soak temperature by 1
    jb 		BTN_UP, conf_soakTemp_button_down
    sleep(#DEBOUNCE)
    jb 		BTN_UP, conf_soakTemp_button_down
    jnb 	BTN_UP, $
	Increment_variable(soakTemp)

conf_soakTemp_button_down:
    ; [DOWN] decrement soak temperature by 1
    jb 		BTN_DOWN, conf_soakTemp_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_DOWN, conf_soakTemp_button_state
    jnb 	BTN_DOWN, $
    Decrement_variable(soakTemp)

conf_soakTemp_button_state:
    ; [STATE] save this setting and move on
    jb 		BTN_STATE, conf_soakTemp_j
    sleep(#DEBOUNCE)
    jb 		BTN_STATE, conf_soakTemp_j
    jnb 	BTN_STATE, $
    ljmp 	conf_soakTime
conf_soakTemp_j:
	ljmp conf_soakTemp_update

;-------------------------------------;
; CONFIGURE: Soak Time       		  ;
;-------------------------------------;
conf_soakTime:
    ; CHECK: [STATE], [UP], [DOWN]
    ; soak time interface
    LCD_cursor(1, 1)
    LCD_print(#msg_soakTime)
	LCD_cursor(2, 1)
    LCD_print(#msg_time)
conf_soakTime_update:
    Print_Time(soakTime)							; soakTime is a variable for seconds, convert into minutes and seconds here

conf_soakTime_button_up:
    ; [UP] increment soak time by 5
    jb 		BTN_UP, conf_soakTime_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_soakTime_button_down
	jnb 	BTN_UP, $
    lcall 	inc_soak_time

conf_soakTime_button_down:
    ; [DOWN] decrement soak time by 5
    jb 		BTN_DOWN, conf_soakTime_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_soakTime_button_state
	jnb 	BTN_DOWN, $
    lcall 	dec_soak_time

conf_soakTime_button_state:
    ; [STATE] save soak time and move on
    jb 		BTN_STATE, conf_soakTime_j
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_soakTime_j
	jnb 	BTN_STATE, $
    ljmp 	conf_reflowTemp

conf_soakTime_j:
	ljmp conf_soakTime_update

;-------------------------------------;
; CONFIGURE: Reflow Temperature		  ;
;-------------------------------------;
conf_reflowTemp:
    ; CHECK: [STATE], [UP], [DOWN]
    ; reflow temperature setting interface
    LCD_cursor(1, 1)
    LCD_print(#msg_reflowTemp)
	LCD_cursor(2, 1)
    LCD_print(#msg_temp)
conf_reflowTemp_update:
    LCD_cursor(2, 7)
	Print_Temp(reflowTemp)

conf_reflowTemp_button_up:
    ; [UP]  increment reflow tempreature by 1
    jb 		BTN_UP, conf_reflowTemp_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_reflowTemp_button_down
	jnb 	BTN_UP, $
	Increment_variable(reflowTemp)

conf_reflowTemp_button_down:
    ; [DOWN] decrement reflow tempreature by 1
    jb 		BTN_DOWN, conf_reflowTemp_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_reflowTemp_button_state
	jnb 	BTN_DOWN, $
	Decrement_variable(reflowTemp)

conf_reflowTemp_button_state:
    ; [STATE] save reflow temperature and move on
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
    ; CHECK: [STATE], [UP], [DOWN]
    ; reflow time setting interface
    LCD_cursor(1, 1)
    LCD_print(#msg_reflowTime)
	LCD_cursor(2, 1)
    LCD_print(#msg_time)
conf_reflowTime_update:
    Print_Time(reflowTime)

conf_reflowTime_button_up:
    ; [UP]  increase reflow time by 5 seconds
    jb 		BTN_UP, conf_reflowTime_button_down
	sleep(#DEBOUNCE)
	jb 		BTN_UP, conf_reflowTime_button_down
	jnb 	BTN_UP, $
    lcall 	inc_reflow_time

conf_reflowTime_button_down:
    ; [DOWN]  decrease reflow time by 5 seconds
    jb 		BTN_DOWN, conf_reflowTime_button_state
	sleep(#DEBOUNCE)
	jb 		BTN_DOWN, conf_reflowTime_button_state
	jnb 	BTN_DOWN, $
    lcall 	dec_reflow_time

conf_reflowTime_button_state:
    ; [STATE] save reflow time and move on
    jb 		BTN_STATE, conf_reflowTime_j
	sleep(#DEBOUNCE)
	jb 		BTN_STATE, conf_reflowTime_j
	jnb 	BTN_STATE, $
    ljmp 	main

conf_reflowTime_j:
	ljmp conf_reflowTime_update

;------------------------------;
; 		FUNCTION CALLS			;
;------------------------------;
inc_soak_temp:
	mov 	a, soakTemp
    add		a, #0x01
    da		a
    mov		soakTemp, a
    ; ** other stuffs
	ret

dec_soak_temp:
	; ** insert function hereeee
	ret

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

END
