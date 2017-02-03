$NOLIST
$MODLP52
$LIST

CLK equ 22118400
TIMER0_RATE equ 4096
TIMER0_RELOAD equ ((65536-(CLK/4096)))
TIMER2_RATE equ 1000
TIMER2_RELOAD equ (65536-(CLK/TIMER2_RATE))
DEBOUNCE_DELAY equ 50
TIMER_RATE equ 1000

SOUND_OUT equ P3.7

org 0x0000
    ljmp    setup
org 0x000B
    ljmp    T0_ISR
org 0x002B
    ljmp    T2_ISR

dseg at 0x30
    countms:    ds 2
    state:      ds 1

t0_init:
    mov     a,  TMOD
    anl     a,  #0xf0
    orl     a,      #0x01 ; Configure timer 0 as 16-timer
    mov     TMOD,   a
    mov     TH0,    #high(TIMER0_RELOAD)
    mov     TL0,    #low(TIMER0_RELOAD)
    setb    ET0
    setb    TR0
    ret
t0_isr:
    ; clr     TR0
    cpl     SOUND_OUT
    ; setb    TR0
    reti
t2_init:
    mov     T2CON,  #0
    mov     RCAP2H, #high(TIMER2_RELOAD)
    mov     RCAP2L, #low(TIMER2_RELOAD)
    clr     a
    mov     countms+0, a
    mov     countms+1, a
    setb    ET2
    setb    TR2
    ret
t2_isr:
    clr     TF2
    push    acc
    push    psw
    inc     countms+0
    mov     a,  countms+0
    jnz     t2_isr_done
    inc     countms+1
t2_isr_done:
    mov     a, countms+0
