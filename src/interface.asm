; LIT SOLDER OVEN CONTROLLER
; AUTHORS:  SCOTT BEAULIEU
;           GEOFF GOODWIN
;           MUCHEN HE
;           LARRY LIU
;           LUFEI LIU
;           WENOA TEVES
; VERSION:	1
; LAST REVISION:	2017-02-11
; http:;i.imgur.com/7wOfG4U.gif

org 0x0000
    ljmp    setup
org 0x000B
    ljmp    T0_ISR
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
CLK         equ     22118400
BAUD        equ     115200
T0_RELOAD   equ     ((65536-(CLK/4096)))
T1_RELOAD   equ     (0x100-CLK/(16*BAUD))
T2_RELOAD   equ     (65536-(CLK/1000))
DEBOUNCE    equ     50
TIME_RATE   equ     1000

; LCD PINS
LCD_RS      equ     P1.2
LCD_RW      equ     P1.3
LCD_E       equ     P1.4
LCD_D4      equ     P3.2
LCD_D5      equ     P3.3
LCD_D6      equ     P3.4
LCD_D7      equ     P3.5

; ADC SPI PINS
ADC_CE      equ     P2.0
ADC_MOSI    equ     P2.1
ADC_MISO    equ     P2.2
ADC_SCLK    equ     P2.3

; BUTTONS PINs
BTN_START   equ     P2.4
BTN_STATE   equ     P2.5
BTN_UP      equ     P2.6
BTN_DOWN    equ     P2.7

; SSR / oven control pin
SSR         equ     P3.7

; SOUND
SOUND       equ     P0.0

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
    soakTime_sec:	ds 1
    power:		ds  1
    Thertemp:   ds  4
    LMtemp:     ds  4
    Oven_temp:  ds  4

    ; for math32
    result:     ds  2
    bcd:        ds  5
    x:          ds  4
    y:          ds  4

bseg
    seconds_flag: 	dbit 1
    oven_enabled:	dbit 1
    reset_timer_f:	dbit 1

    ; for math32
    mf:             dbit 1
    ; for reading temperature
    LM_TH: dbit 1
cseg
; LCD SCREEN
;                     	1234567890123456
msg_main_top:  		db 'STATE:-  T:--- C', 0  ;State: 1-5
msg_main_btm: 		db '   TIME --:--   ', 0  ;elapsed time
msg_soakTemp:       db 'SOAK TEMP:     <', 0
msg_soakTime:       db 'SOAK TIME:     <', 0
msg_reflowTemp:	    db 'REFLOW TEMP:   <', 0
msg_reflowTime:	    db 'REFLOW TIME:   <', 0
msg_temp:	        db '      --- C    >', 0
msg_time:	        db '     --:--     >', 0
msg_state1:         db 'S: RampToSoak   ', 0
msg_state2:         db 'S: PreheatSoak  ', 0
msg_state3:			db 'S: RampToPeak   ', 0
msg_state4:         db 'S: Reflow       ', 0
msg_state5:         db 'S: Cooling      ', 0
msg_fsm:            db 'T: --- C --:--  ', 0

; -------------------------;
; Initialize Timer 0	   ;
; -------------------------;
T0_init:
    mov     a,      TMOD
    anl     a,      #0xF0
    orl     a,      #0x01
    mov     TMOD,   a
    mov     TH0,    #high(T0_RELOAD)
    mov     TL0,    #low(T0_RELOAD)
    ; Enable the timer and interrupts
    setb    ET0
    ; Timer 0 do not start by default
    ; setb    TR0
    ret

;-----------------------------;
; ISR for timer 0             ;
;-----------------------------;
T0_ISR:
    clr     TR0
    mov     TH0,    #high(T0_RELOAD)
    mov     TL0,    #low(T0_RELOAD)
    setb    TR0
    cpl     P0.0
    reti

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

    ; Increment soaktime timer
    increment(soakTime_sec)

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
    lcall SendVoltage; send voltage for each Timer2 interrupt
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
; Get number from ADC, store it in R6 and R7 ;
;-----------------------------;
ADC_get:
    push    ACC
    push    AR0
    push    AR1
    clr     ADC_CE
    mov     R0,     #0x01 ; Start bit:1
    lcall   ADC_comm

    mov     a,      b
    swap    a
    anl     a,      #0F0H
    setb    acc.7          ; Single mode (bit 7).
    mov     R0,     a
    lcall   ADC_comm
    mov     a,      R1 ; R1 contains bits 8 and 9
    anl     a,      #0x03 ; We need only the two least significant bits
    mov     R7,     a ; Save result high.
    mov     R0,     #0x55 ; It doesn't matter what we transmit...
    lcall   ADC_comm
    mov     a,      R1
    mov     R6,     a ; R1 contains bits 0 to 7. Save result low.
    setb    ADC_CE
    sleep(50)
    pop     AR1
    pop     AR0
    ret

;-----------------------------;
;	MAIN PROGRAM		      ;
;-----------------------------;
setup:
    mov     SP,     #0x7F
    mov     PMOD,   #0

    ; Timer setup
    lcall   T0_init
    lcall   T2_init
    setb    EA

    ; LCD setup
    lcall   LCD_init

    ; PWM setup
    mov     ovenPower,      #0 ;choose initial power here (0-10)
    setb    oven_enabled
    mov     perCntr,        #10

    ; Initialize MCP3008 ADC
    setb    ADC_CE
    lcall   ADC_init
    lcall   SPI_init

    ; initialize variables
    setb    seconds_flag
    mov     seconds,    #0x00
    mov     minutes,    #0x00
    mov		soakTemp, 	#0x00
    mov		soakTime, 	#0x00
    mov		reflowTemp, #0x00
    mov		reflowTime, #0x00
   	mov 	crtTemp,	#0x00	;temporary for testing purposes
    clr     LM_TH  ; set the flag to low initially

main:
    ; MAIN MENU LOOP
    ; CHECK: [START], [STATE]
    LCD_cursor(1, 1)
    LCD_print(#msg_main_top)
    LCD_cursor(2, 1)
    LCD_print(#msg_main_btm)
    LCD_cursor(1, 15)
    LCD_printChar(#0xDF)
main_button_start:
    ; [START] - start the reflow program
    jb 	    BTN_START,      main_button_state
    sleep(#DEBOUNCE)
    jb 	    BTN_START,      main_button_state
    jnb     BTN_START,      $

    ; clear the reset flag so timer can start counting up
    clr		reset_timer_f

    ; reset the soaktime timer to be 0
    mov		soakTime_sec, #0x00

    ; set as FSM State 1
    mov		state, #RAMP2SOAK

    ; set LCD screen and go to FSM fsm loop
    LCD_cursor(1, 1)
    LCD_print(#msg_state1)
    LCD_cursor(2, 1)
    LCD_print(#msg_fsm)
    ljmp 	fsm

main_button_state:
    ; [STATE] - configure reflow program
    jb 		BTN_STATE, main_update
    sleep(#DEBOUNCE)
    jb 		BTN_STATE, main_update
    jnb 	BTN_STATE, $
    ljmp    conf_soakTemp

main_update:
    ; update main screen values
    LCD_cursor(2, 9)
    LCD_printBCD(minutes)
    LCD_cursor(2, 12)
    LCD_printBCD(seconds)
    LCD_printTemp(crtTemp, 1, 12)	; where is the temperature coming from ??
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
    LCD_printTemp(soakTemp, 2, 7)					; display soak temperature on LCD

conf_soakTemp_button_up:
    ; [UP] increment soak temperature by 1
    jb 		BTN_UP, conf_soakTemp_button_down
    sleep(#DEBOUNCE)
    jb 		BTN_UP, conf_soakTemp_button_down
    jnb 	BTN_UP, $
    increment(soakTemp)

conf_soakTemp_button_down:
    ; [DOWN] decrement soak temperature by 1
    jb 		BTN_DOWN, conf_soakTemp_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_DOWN, conf_soakTemp_button_state
    jnb 	BTN_DOWN, $
    decrement(soakTemp)

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
    LCD_printTime(soakTime, 2, 6) ; soakTime is a variable for seconds, convert into minutes and seconds here

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
    LCD_printTemp(reflowTemp, 2, 7)

conf_reflowTemp_button_up:
    ; [UP]  increment reflow tempreature by 1
    jb 		BTN_UP, conf_reflowTemp_button_down
    sleep(#DEBOUNCE)
    jb 		BTN_UP, conf_reflowTemp_button_down
    jnb 	BTN_UP, $
    increment(reflowTemp)

conf_reflowTemp_button_down:
    ; [DOWN] decrement reflow tempreature by 1
    jb 		BTN_DOWN, conf_reflowTemp_button_state
    sleep(#DEBOUNCE)
    jb 		BTN_DOWN, conf_reflowTemp_button_state
    jnb 	BTN_DOWN, $
    decrement(reflowTemp)

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
    LCD_printTime(reflowTime, 2, 6)

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
    ljmp   conf_reflowTime_update

;------------------------------;
; 		FUNCTION CALLS		   ;
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


;-------------------------------------;
; END OF INTERFACE // BEGIN FSM       ;
;-------------------------------------;
fsm:
    ; update LCD
    LCD_printTemp(crtTemp, 2, 3)
    LCD_printTime(soakTime_sec, 2, 9)

    ; find which state we are currently on
    mov     a,  state
    cjne    a,  #RAMP2SOAK,     fsm_notState1
    ljmp    fsm_state1
fsm_notState1:
    cjne    a,  #PREHEAT_SOAK,  fsm_notState2
    ljmp    fsm_state2
fsm_notState2:
    cjne    a,  #RAMP2PEAK,     fsm_notState3
    ljmp    fsm_state3
fsm_notState3:
    cjne    a,  #REFLOW,        fsm_notState4
    ljmp    fsm_state4
fsm_notState4:
    cjne    a,  #COOLING,       fsm_invalid
    ljmp    fsm_state5
fsm_invalid:
    ; have some code for this exception (eg. reset and return to main)
    ljmp    setup

fsm_state1:
    mov     power,        #10 ; (Geoff pls change this line of code to fit)
    ; !! WE SHOULD USE MATH32 LIBRARY TO MAKE COMPARISONS HERE
    ;soakTemp is the saved parameter from interface
    mov     a,          soakTemp
    clr     c
    ;crtTemp is the temperature taken from oven (i think...)
    subb    a,          crtTemp ; here our soaktime has to be in binary or Decimal not ADC
    jc      fsm_state1_done
    ljmp    fsm

    mov x+1, soakTemp+1

    mov y+1, soakTemp+1 ; load soaktemp to y
    mov y+0, soakTemp+0




fsm_state1_done:
    ; temperature reached
    mov     state,          #PREHEAT_SOAK
    mov	    soakTime_sec,   #0x00   ; reset the timer before jummp to state2

    ; produces beeping noise
    beepshort()

    ; update state 2 LCD screen
    LCD_cursor(1, 1)
    LCD_print(#msg_state2)

fsm_state2:
    mov     power,          #2
    mov     a,              soaktime
    clr     c
    subb    a,              soakTime_sec
    jc      fsm_state2_done
    ljmp    fsm

fsm_state2_done:
    ; finished state 2
    mov     state,          #3
    ; TODO reset counter !!! TODO
    beepShort()
    LCD_cursor(1, 1)
    LCD_print(#msg_state3)

fsm_state3:
    mov     power,      #10
    mov     a,          #220 ; make this a constant
    clr     c
    subb    a,          soakTemp ; here our soaktime has to be in binary or Decimal not ADC
    jc      fsm_state3_done
    ljmp    fsm

fsm_state3_done:
    ; finished state 3
    mov     state,      #4
    ; TODO reset counter !!! TODO
    beepShort()
    LCD_cursor(1, 1)
    LCD_print(#msg_state4)

fsm_state4:
    mov     power,        #2
    mov     a,      soaktime  ; our soaktime has to be
    clr     c
    subb    a,      soakTime_sec
    jc      fsm_state4_done
    ljmp    fsm
fsm_state4_done:
    mov     state,  #5
    ; TODO reset counter !!! TODO
    beepLong()
    LCD_cursor(1, 1)
    LCD_print(#msg_state5)

fsm_state5:
    mov     power,      #0
    mov     a,          #60
    clr     c
    subb    a,          soakTemp ; here our soaktime has to be in binary or Decimal not ADC
    jc      fsm_state5_done
    ljmp    fsm

fsm_state5_done:
    mov		state,		#0
    ; TODO reset counter !!! TODO
    beepPulse()
    ljmp    fsm

END

;-------------------------------------
;send voltage to the serial port
;--------------------------------------------------
SendVoltage:
    jnb LM_TH, Th ; jump to Th initially
LM: mov b, #0;
    lcall ADC_get
    lcall LM_converter
    clr LM_TH
 	LCD_cursor(2, 7)
    ;LCD_printBCD(bcd+1); display on the LCD
 	;LCD_printBCD(bcd+0); display on the LCD
 	Send_BCD(bcd+1) ;
    Send_BCD(bcd+0) ;
	;lcall add_two_temp ; two temp
	lcall Switchline


	lcall add_two_temp ; two temp
    Send_bcd(bcd+1)             ;display the total temperature
	Send_bcd(bcd+0)

	lcall Switchline
  ret ; jump back to our interrupt
    ;ljmp SendVoltage ; for our testing code, constanly track the temperature


Th: mov b, #1 ; connect thermocouple to chanel1
    lcall ADC_get ; Read from the SPI
    lcall Th_converter ; convert ADC TO actual value
    setb LM_TH
    ;;lcall hex2bcd
    ;mov Thertemp+1,  bcd+1
    ;mov Thertemp+0,  bcd+0

 	Send_BCD(bcd+1) ;
    Send_BCD(bcd+0) ;

	lcall Switchline
    ljmp SendVoltage

;------------------------
;Conver ADC LM_temp to BCD
;------------------------
LM_converter:

    mov x+3, #0 ; Load 32-bit "y" with value from ADC
    mov x+2, #0
    mov x+1, R7
    mov x+0, R6
    load_y(503)
    lcall mul32
    load_y(1023)
    lcall div32
    load_y(273)
    lcall sub32
    ;lcall hex2bcd

    mov LMtemp+3,  x+3
    mov LMtemp+2,  x+2
    mov LMtemp+1,  x+1
    mov LMtemp+0,  x+0
    lcall hex2bcd
    ret
;----------------------------
; Conver ADC Ther_temp to BCD
;----------------------------
Th_converter:
    mov x+3, #0 ; Load 32-bit �y� with value from ADC
    mov x+2, #0
    mov x+1, R7
    mov x+0, R6
    load_y(2)
    lcall div32
    ;lcall hex2bcd
    mov Thertemp+3,  x+3
    mov Thertemp+2,  x+2
    mov Thertemp+1,  x+1
    mov Thertemp+0,  x+0
    lcall hex2bcd
    ret
    ;lcall hex2bcd
    ;Send_BCD(bcd)

    ;mov DPTR, #New_Line
    ;lcall SendString

;keep in hex
;--------------------
; ADD two temperature together for FSM
;--------------------------------
add_two_temp:
   ;load_x(LMtemp)
   ;load_y(Thertemp)

   mov x+3,LMtemp+3
   mov x+2,LMtemp+2
   mov x+1,LMtemp+1
   mov x+0,LMtemp+0

   ;-----------------
   mov y+3, Thertemp+3
   mov y+2, Thertemp+2
   mov y+1, Thertemp+1
   mov y+0, Thertemp+0 ;

   ;-----------------
   lcall add32
   load_y(5) ; offest can be reset
   lcall add32
   mov Oven_temp+3,  x+3
   mov Oven_temp+2,  x+2
   mov Oven_temp+1,  x+1
   mov Oven_temp+0,  x+0
   lcall hex2bcd
   ret

;---------
;Swithline
;---------
Switchline:
	mov a, #'\r'
    lcall putchar
    mov a, #'\n'
    lcall putchar; display our value - final temperature
	ret
