;===SLEEP===
sleep mac
	push AR2
	mov R2, %0
	lcall ?sleep
	pop AR2
endmac
?sleep:
	push AR0
	push AR1
L3: mov R1, #45
L2: mov R0, #166
L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L2 ; 22.51519us*45=1.013ms
    djnz R2, L3 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret

;===SEND BCD VIA SPI===
putBCD mac
    push    AR0
    mov     R0,     %0
    lcall   ?putBCD
    pop     AR0
endmac
?putBCD:
    push    ACC
    ; Write most significant digit
    mov     a,  R0
    swap    a
    anl     a,  #0fh
    orl     a,  #30h
    lcall   putchar
    ; write least significant digit
    mov     a,  R0
    anl     a,  #0fh
    orl     a,  #30h
    lcall   putchar
    pop     acc
    ret

;===DISPLAY TO LED BAR===
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


; -------------------------;
; Increment Macro		   ;
; -------------------------;
Increment_variable MAC
  	mov 	a, %0
    add		a, #0x01
    mov 	%0, a
ENDMAC
; -------------------------;
; Decrement Macro		   ;
; -------------------------;
Decrement_variable MAC
  	mov 	a, %0
	add		a, #0xFF
    mov 	%0, a
ENDMAC

; -------------------------;
; Print Time Macro		   ;		; does this even work like this? QQ
; -------------------------;
Print_Time MAC
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
ENDMAC

; -------------------------;
; Print Temp Macro		   ;
; -------------------------;
Print_Temp MAC
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
ENDMAC
