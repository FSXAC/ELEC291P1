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

;===WAIT []ms===
; sleep mac
; 	push AR2
; 	mov R2, %0
; 	lcall ?sleep
; 	pop AR2
; endmac
; ?sleep:
; 	push AR0
; 	push AR1
; L3: mov R1, #45
; L2: mov R0, #166
; L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
;     djnz R1, L2 ; 22.51519us*45=1.013ms
;     djnz R2, L3 ; number of millisecons to wait passed in R2
;     pop AR1
;     pop AR0
;     ret

;---------------------------------;
; Toggles the 'E' pin in the LCD  ;
;---------------------------------;
LCD_pulse:
	setb LCD_E
	lcall Wait40uSec
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
    lcall Wait40uSec
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
LCD_config:
	clr LCD_E   ; Resting state of LCD's enable pin is zero
	clr LCD_RW  ; We are only writing to the LCD in this program
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
	push   dph
	push   dpl
	push   acc
	mov    dptr, %0
	lcall  ?LCD_print
	pop    acc
	pop    dpl
	pop    dph
endmac
?LCD_print:
    clr     a
    movc    a,  @a+dptr
    jz      ?LCD_print_return
    lcall   ?LCD_write
    inc     dptr
    sjmp    ?LCD_print
?LCD_print_return:
    ret

;---------------------------------;
; Set LCD cursor at row, column   ;
;---------------------------------;
LCD_cursor mac
	push   acc
	mov    a,  #%1
	dec    a
	lcall  ?LCD_cursor_%0 ; Select column and row
	pop    acc
endmac
?LCD_cursor_2:
	orl    a,  #01000000B
?LCD_cursor_1:
	orl    a,  #10000000B
	ljmp   ?LCD_cmd ; Select column and row

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
