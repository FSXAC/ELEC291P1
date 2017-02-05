
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
