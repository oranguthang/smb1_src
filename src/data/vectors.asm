; -------------------------------------------------------------------------------------
; INTERRUPT VECTORS

.segment "VECTORS"

unused_irq_vector_target = $fff0

    .word vec_nmi_handler
    .word vec_reset_handler
    .word unused_irq_vector_target
