; -------------------------------------------------------------------------------------
; INTERRUPT VECTORS

.segment "VECTORS"

    .word NonMaskableInterrupt
    .word Start
    .word $fff0  ; unused
