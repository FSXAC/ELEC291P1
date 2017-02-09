cseg

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns

;---------------------------------;
; Wait 40 microseconds            ;
;---------------------------------;
sleep40us:
	push AR0
	mov R0, #177
L0:
	nop
	nop
	djnz R0, L0 ; 1+1+3 cycles->5*45.21123ns*177=40us
	pop AR0
    ret

;---------------------------------;
; Toggles the 'E' pin in the LCD  ;
;---------------------------------;
LCD_pulse:
	setb LCD_E
	lcall 5
	clr LCD_E
    ret

;---------------------------------;
; Writes acc to LCD in 4-bit mode ;
;---------------------------------;
LCD_byte:
	; Write high 4 bits first
	mov c, ACC.7
	mov LCD_D7, c
	mov c, ACC.6
	mov LCD_D6, c
	mov c, ACC.5
	mov LCD_D5, c
	mov c, ACC.4
	mov LCD_D4, c
    lcall LCD_pulse
    lcall sleep40us
	; Write low 4 bits next
	mov c, ACC.3
	mov LCD_D7, c
	mov c, ACC.2
	mov LCD_D6, c
	mov c, ACC.1
	mov LCD_D5, c
	mov c, ACC.0
	mov LCD_D4, c
    lcall LCD_pulse
	ret

;---------------------------------;
; Write data to LCD               ;
;---------------------------------;
LCD_write mac
	mov a, %0
	lcall ?LCD_write
endmac
?LCD_write:
	setb LCD_RS
	ljmp LCD_byte

;---------------------------------;
; Write command to LCD            ;
;---------------------------------;
LCD_cmd mac
	mov a, %0
	lcall ?LCD_cmd
endmac
?LCD_cmd:
	clr LCD_RS
	ljmp LCD_byte

;---------------------------------;
; Configure LCD in 4-bit mode     ;
;---------------------------------;
LCD_init:
	clr LCD_E   ; Resting state of LCD's enable pin is zero
	clr LCD_RW  ; We are only writing to the LCD in this program

	; After power on, let the LCD start up before initializing
	; NOTE: the preprogrammed power-on delay of 16 ms on the AT89LP52
	; seems to be enough.  That is why this line is commented out.
	; Wait_Milli_Seconds(#40)

	; First make sure the LCD is in 8-bit mode and then change to 4-bit mode
	LCD_cmd(#0x33)
	LCD_cmd(#0x33)
	LCD_cmd(#0x32) ; change to 4-bit mode

	; Configure the LCD
	LCD_cmd(#0x28)
	LCD_cmd(#0x0c)
	LCD_cmd(#0x01) ;  Clear screen command (takes some time)

    ;Wait for the clear screen command to finish.
	sleep(#2)
    ret

;---------------------------------;
; Send a constant string to LCD   ;
;---------------------------------;
LCD_print mac
	push dph
	push dpl
	push acc
	mov dptr, %0
	lcall ?Send_Constant_String
	pop acc
	pop dpl
	pop dph
endmac
?Send_Constant_String:
    clr a
    movc a, @a+dptr
    jz ?Send_Constant_String_Done
    lcall ?LCD_write
    inc dptr
    sjmp ?Send_Constant_String
?Send_Constant_String_Done:
    ret

;---------------------------------;
; Scroll display constant string  ;
;---------------------------------;
Scroll_display mac
	push dph
	push dpl
	push acc
	push AR1
	mov R1, %0
?scroll:
	mov a, R1
	clr c
	subb a, %1
	jz ?next
	LCD_cmd(#0x14)
	Send_Constant_String(%2)
	Wait_Milli_Seconds(#50)
;	LCD_cmd(#0x01)
;	Wait_Milli_Seconds(#2)
	inc R1
	sjmp ?scroll
?next:
	pop AR1
	pop acc
	pop dpl
	pop dph
	endmac

;---------------------------------;
; Set LCD cursor at row, column   ;
;---------------------------------;
LCD_cursor mac
	push acc
	mov a, #%1
	dec a
	lcall ?Set_Cursor_%0 ; Select column and row
	pop acc
endmac
?Set_Cursor_2:
	orl a, #01000000B
?Set_Cursor_1:
	orl a, #10000000B
	ljmp ?LCD_cmd ; Select column and row

;---------------------------------;
; Display a BCD number in the LCD ;
;---------------------------------;
LCD_printBCD mac
	push ar0
	mov r0, %0
	lcall ?LCD_printBCD
	pop ar0
endmac
?LCD_printBCD:
	push acc
	; Write most significant digit
	mov a, r0
	swap a
	anl a, #0fh
	orl a, #30h
	lcall ?LCD_write
	; write least significant digit
	mov a, r0
	anl a, #0fh
	orl a, #30h
	lcall ?LCD_write
	pop acc
	ret

;------------------------------------;
; Display a char in the LCD          ;
;------------------------------------;
LCD_printChar mac
	push acc
	mov a, %0
	lcall ?LCD_write
	pop acc
endmac

; -------------------------;
; Print Time Macro		   ;		; does this even work like this? QQ
; -------------------------;
LCD_printTime mac
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
    pop     AR2
    pop     AR3
    pop     ACC
endmac

; -------------------------;
; Print Temp Macro		   ;
; -------------------------;
LCD_printTemp mac
    push    ACC
    push    AR1
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
    pop     AR1
    pop     ACC
endmac
