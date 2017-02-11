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
    mov     a,      %0
    add     a,      #0x01
    mov     %0,     a
endmac
; -------------------------;
; Decrement Macro		   ;
; -------------------------;
decrement mac
    mov     a,      %0
    add	    a,      #0xFF
    mov     %0,     a
endmac
