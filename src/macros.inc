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
beep mac
	push	ACC
	; param: mode of beeping
	; [1] - Short single beep
	; [2] - Long single beep
	; [else] - 6 Intermediate beeps
	mov 	a,		#%0
	lcall	?beep
	pop		ACC
endmac
?beep:
	clr 	c
	dec		a
	jnz 	?beep_not1
	sjmp	?beep_short
?beep_not1:
	dec 	a
	jnz		?beep_not2
	sjmp	?beep_long
?beep_not2:
	sjmp	?beep_pulse

?beep_short:
; 	; beep for 500ms
; 	mov
; 	setb	TR0

?beep_long:
?beep_pulse:

?beep_end:
