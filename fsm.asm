
; compare temperature and time to change STATE
; state 1, 100% power; reach to 150 C in 120 seconds (aprox.)
state1:
    cjne    a,  RAMP2SOAK,  state2

    ; display on LCD
    LCD_cursor(1,1)
    LCD_print(#msg_state1)
    LCD_cursor(2,1)
    LCD_print(#msg_soakTemp)
    LCD_print(soakTemp) ; need to convert our ADC voltage into decimal
    LCD_cursor(2,8)
    LCD_print(#msg_soakTime)
    LCD_print(soakTime)

    mov     pwm,        #100 ; (Geoff pls change this line of code to fit)
    mov     soakTime,   #0
    mov     a,          #150
    clr     c
    subb    a,          soakTemp ; here our soaktime has to be in binary or Decimal not ADC
    jnc     state1_done
    mov     state, #2
fsm_state1_done:
    ljmp    forever ; here should it be state1?

fsm_state2:
    cjne    a,  #2,     state3
fsm_state3:
