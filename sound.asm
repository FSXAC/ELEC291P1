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
    count1ms:   ds 2
    state:      ds 1

bseg
    
