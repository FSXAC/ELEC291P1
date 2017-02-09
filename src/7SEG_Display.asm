;LIT SOLDER OVEN CONTROLLER -- BONUS: 7SEG LED DISPLAY
; AUTHOR:	GEOFF GOODWIN
;			MUCHEN HE
;			WENOA TEVES
; VERSION:	0
; LAST REVISION:	2017-02-05
; http: i.imgur.com/7wOfG4U.gif

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
