
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
;---------------------------------;
; Toggles the 'E' pin in the LCD  ;
;---------------------------------;
LCD_pulse:
	setb LCD_E
	lcall sleep40us
	clr LCD_E
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
    LCD_printChar(R3)

    LCD_cursor(2, 7)
    mov		a, b
    add		a, #0x30
    mov		b, a
    LCD_printChar(b)

    mov		b, #10
    mov		a, R2
    div		ab
    LCD_cursor(2, 9)
    add		a, #0x30
    mov		R3, a
    LCD_printChar(R3)

    LCD_cursor(2, 10)
    mov		a, b
    add		a, #0x30
    mov		b, a
    LCD_printChar(b)
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
    LCD_printChar(R1)
    mov		a, b
    mov		b, #10
    div		ab
    add		a, #0x30
    mov		R1, a
    LCD_cursor(2, 8)
    LCD_printChar(R1)
    LCD_cursor(2, 9)
    mov		a, b
    add		a, #0x30
    mov		b, a
    LCD_printChar(b)
ENDMAC
