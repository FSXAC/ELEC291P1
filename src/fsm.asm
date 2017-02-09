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
    soakTime_sec    ds  1
    soakTime_min    ds  1
bseg
    seconds_f: 	dbit 1
    ongoing_f:	dbit 1
    reset_timer_f: dbit 1		;only check for buttons when the process has not started (JK just realized we might not need this..)
    ;for every state to begin, the timer get reset
cseg
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
msg_state1:         db ' S: RampToSoak  ', 0
msg_state2:         db ' S: PreheatSoak ', 0
msg_state3:			db ' S: RampToPeak  ', 0
msg_state4:         db ' S: Reflow      ', 0
msg_state5:         db ' S: Cooling     ', 0
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
    jnb reset_timer_f timer_start
    mov soakTime_sec, #0x00
    mov soakTime_min, #0x00
    ; reset our timer
timer_start:
    mov     a,   soakTime_sec
    add     a,   #0x01
    ; BCD Conversion and writeback
    da 	    a
    mov     soakTime_sec,    a
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
    mov     soakTime_sec,    #0x00
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
; compare temperature and time to change STATE
; state 1, 100% power; reach to 150 C in 120 seconds (aprox.)
fsm_state1:
    cjne    a,  RAMP2SOAK,  fsm_state2

    ; display on LCD
    LCD_cursor(1, 1)
    LCD_print(#msg_state1)
    LCD_cursor(2, 1)
    LCD_print(#msg_fsm)
    LCD_cursor(2, 3)
    LCD_print(soakTemp)         ; need to convert our ADC voltage into decimal

    ; FIXME divide soak time by 60 for minutes
    ; LCD_cursor(2, 10)
    ; LCD_print(soakTime_min)
    LCD_curosr(2, 13)
    LCD_print(soakTime_sec)
    LCD_curosr(2,10)
    LCD_print(soakTime_min)

    mov     power,        #10 ; (Geoff pls change this line of code to fit)
    ;mov     soakTime_sec, #0
    ;mov     soakTime_min, #0
    mov     a,          #150
    clr     c
    subb    a,          soakTemp ; here our soaktime has to be in binary or Decimal not ADC
    jnc     fsm_state1_done
    mov     state, #2
    setb    reset_timer_f; reset the timer before jummp to state2
    ; ***here set the beeper ()
fsm_state1_done:
    ljmp    forever ; here should it be state1? FIXME

fsm_state2:
    cjne    a,  PREHEAT_SOAK, fsm_state3

    LCD_cursor(1, 1)
    LCD_print(#msg_state2)
    ; display the current state, all other display will keep the same
    mov power,        #2
    mov a, soaktime  ; our soaktime has to be
    clr c
    subb a, soakTime_sec
    jnc fsm_state2_done
    mov state, #3
    setb reset_timer_f
    ;***set the beeper
fsm_state2_done:
    ljmp forever
    ; this portion will change depends on the whether we gonna use min or not


fsm_state3:
   cjne    a,  RAMP2PEAK,  fsm_state4
   LCD_cursor(1, 1)
   LCD_print(#msg_state3)
   ; display the current state, all other display will keep the same

   mov     power,        #10  ; (Geoff pls change this line of code to fit)
   ;mov     soakTime_sec, #0
   ;mov     soakTime_min, #0
   mov     a,          #220
   clr     c
   subb    a,          soakTemp ; here our soaktime has to be in binary or Decimal not ADC
   jnc     fsm_state3_done
   mov     state, #4
   setb    reset_timer_f; reset the timer before jummp to state2
   ; ***here set the beeper ()
fsm_state3_done:
   ljmp    forever ; here should it be state1? FIXME


fsm_state4:
   cjne    a,  REFLOW, fsm_state5
   LCD_cursor(1, 1)
   LCD_print(#msg_state4)
   ; display the current state, all other display will keep the same
   mov power,        #2
   mov a, soaktime  ; our soaktime has to be
   clr c
   subb a, soakTime_sec
   jnc fsm_state4_done
   mov state, #5
   setb reset_timer_f
   ; ***set the beeper
fsm_state4_done:
   ljmp forever

fsm_state5:
    cjne    a,  RAMP2SOAK,  main_button_start

    LCD_cursor(1, 1)
    LCD_print(#msg_state5)

    mov     power,        #0 ; (Geoff pls change this line of code to fit)
    ;mov     soakTime_sec, #0
    ;mov     soakTime_min, #0
Three_beeper:
    mov     a,          #60
    clr     c
    subb    a,          soakTemp ; here our soaktime has to be in binary or Decimal not ADC
    jnc     fsm_state5_done
    mov     state, #0
    setb    reset_timer_f; reset the timer before jummp to state2
     ;*** here set *six*  beepers  ()
fsm_state5_done:
    ljmp forever
