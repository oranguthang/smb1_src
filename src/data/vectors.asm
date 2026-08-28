; -------------------------------------------------------------------------------------
; INTERRUPT VECTORS

.segment "VECTORS"

    .word vec_nmi_handler
    .word vec_reset_handler
.if con_revision_profile = con_revision_profile_ann
    .word vec_ann_irq_handler
.elseif con_revision_profile = con_revision_profile_vs
    .word vec_irq_handler
.else
unused_irq_vector_target = $fff0
    .word unused_irq_vector_target
.endif
