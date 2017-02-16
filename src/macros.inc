;-----------------------------
;send bcd to putty
;-----------------------------
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
;===SLEEP===
sleep mac
    push   AR2
    mov    R2,     %0
    lcall  ?sleep
    pop    AR2
endmac
?sleep:
    push    AR0
    push    AR1
L3: mov     R1,     #45
L2: mov     R0,     #166
L1: djnz    R0,     L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz    R1,     L2 ; 22.51519us*45=1.013ms
    djnz    R2,     L3 ; number of millisecons to wait passed in R2
    pop     AR1
    pop     AR0
    ret

; -------------------------;
; Increment Macro		   ;
; -------------------------;
increment mac
	push 	ACC
    mov     a,      %0
    add     a,      #0x01
    mov     %0,     a
	pop		ACC
endmac
; -------------------------;
; Decrement Macro		   ;
; -------------------------;
decrement mac
	push	ACC
    mov     a,      %0
    add	    a,      #0xFF
    mov     %0,     a
	pop		ACC
endmac

;=== BEEPING MACRO===
; Current objective: just make a simple beep that might have delay on overall program
beepButton mac
    setb    TR0
    sleep(#50)
    clr     TR0
endmac
beepShort mac
    ; beep for 0.5s = 2 * 250ms
    ;mov     soundms+0, #low(500)
	;mov 	soundms+1, #high(500)
	;mov 	soundX, #5
	setb	TR0
	sleep(#250)
	sleep(#150)
	clr 	TR0
endmac
beepLong mac
    ; beep for 1s = 4 * 250ms
    ;mov     soundms+0, #low(1000)
	;mov 	soundms+1, #high(1000)
	;mov 	soundX, #0
	setb	TR0
	sleep(#250)
	sleep(#250)
	sleep(#250)
	sleep(#250)
	clr 	TR0
endmac
beepPulse mac
	push 	AR0
    ; set special routine for 6 pulses of beeps
	mov 	R0,	#6
	lcall 	?beepPulse
	pop		AR0
endmac
?beepPulse:
	setb	TR0
	sleep(#250)
	sleep(#250)
	clr 	TR0
	sleep(#250)
	djnz	R0,	?beepPulse
	ret

;--------------------------------;
; Pause (longer than sleep)
;--------------------------------;
waitSeconds mac
	push	acc
	mov		soakTime_sec, #0x00
	mov		sleep_time, %0
	lcall	?msg_sleep
	pop		acc
endmac
?msg_sleep:
	mov		a, sleep_time
	clr		c
	subb	a, soakTime_sec
	jnz		?msg_sleep
	ret

; SHIFT REGISTER
LEDseg mac
	mov r0, a
	mov dptr, #SEG_array
	lcall ?LEDseg
endmac
?LEDseg:
	push ar0
	jz ?LEDseg_zero
?LEDseg_incPointer:
	inc dptr
	dec r0
	cjne r0, #0, ?LEDseg_incPointer
?LEDseg_zero:
	clr a
	movc a, @a+dptr
	lcall LEDByte
	pop ar0
	ret

; assume r0 contains lower BCD, r1 contains upper BCD
; A B C D E F G H
; 1 2 3 4 x x x x
sendSeg mac
  	push ar1
  	push ar2
  	push acc
    mov dptr, #SEG_array
  	mov R1, segBCD+1
  	mov R2, segBCD+0
  	lcall ?sendSeg
  	pop acc
  	pop ar2
  	pop ar1
endmac
?sendSeg:
    clr c
    mov a, digit
    jz ?sendSeg_1
    dec a
    jz ?sendSeg_2
    dec a
    jz ?sendSeg_3
    dec a
    jz ?sendSeg_4
    mov digit, #0x00
    sjmp ?sendSeg
?sendSeg_1:
    ; 970312 !!!!
    ; display the first digit (upper 4 bits of upper BCD)
    ; shfit in positional bits (0000 0001)
    mov a, #0x80 ; 1000 0000
    lcall LEDbyte
    mov a, R1 ;0x12
    anl a, #0xF0 ; 0001 0000
    ;lcall LEDbyte
    rr a
    rr a
    rr a
    rr a ; 0000_0001
    LEDseg()
    clr LED_CLR
    setb LED_CLR
    ljmp ?sendSeg_end

?sendSeg_2:
    ; display the second digit (lower 4 bits of upper BCD)
    ; shift bits into second SR (0000 0010)
    mov a, #0x40
    lcall LEDbyte
    mov a, R1
    anl a, #0x0F
    LEDseg()
    clr LED_CLR
    setb LED_CLR
    sleep(#10)
    ljmp ?sendSeg_end

?sendSeg_3:
    ; display the third digit (upper 4 bits of lower BCD)
    mov a,#0x20
    lcall LEDbyte
    mov a, R2 ;0x12
    anl a, #0xF0 ;0x00010000
    ;lcall LEDbyte
    rr a
    rr a
    rr a
    rr a ; 0000_0001
    LEDseg()
    clr LED_CLR
    setb LED_CLR
    ljmp ?sendSeg_end

?sendSeg_4:
    ; display the fourth digit (lower 4 bits of lower BCD)
    mov a, R2
    mov a, #0x10
    lcall LEDbyte
    mov a, R2
    anl a, #0x0F
    LEDseg()
    clr LED_CLR
    setb LED_CLR
    sleep(#10)
    ljmp ?sendSeg_end
?sendSeg_end:
    ret

barLED mac
    push    ACC
    push    AR0
    mov     R0,     %0
    mov     a,      #8
    subb    a,      R0
    lcall   ?barLED
    pop     AR0
    pop     ACC
endmac
?barLED:
    clr     LED_CLR
    clr     LED_CLK
    clr     LED_LATCH
    setb    LED_DATA
    setb    LED_CLR
barLED_1:
    cpl     LED_CLK
    cpl     LED_CLK
    djnz    R0, barLED_1
    mov     R0, a
    ; inc     R0
    clr     LED_DATA
    jz      barLED_end
barLED_2:
    cpl     LED_CLK
    cpl     LED_CLK
    djnz    R0, barLED_2
barLED_end:
    setb    LED_LATCH
    ret
