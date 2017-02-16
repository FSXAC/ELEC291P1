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
