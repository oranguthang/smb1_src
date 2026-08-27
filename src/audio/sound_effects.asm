; -------------------------------------------------------------------------------------

; Arbitrate sound requests and advance SFX and music channels for one frame

; Inputs:
; Sound/music request queues, active channel buffers, and pause state

; Outputs:
; APU registers and channel sequencing state are updated

; Clobbers:
; A, X, Y
.if con_revision_profile = con_revision_profile_vs
    .byte $ff  ; retained arcade alignment byte
.endif
sub_sound_engine:
    LDA ram_oper_mode  ; are we in title screen mode?
    BNE bra_enable_sound_engine
    STA SND_MASTERCTRL_REG  ; if so, disable sound and leave
.if con_revision_profile = con_revision_profile_vs
    STA ram_square1_sound_buffer
    STA ram_square2_sound_buffer
    STA ram_noise_sound_buffer
    STA ram_event_music_buffer
    STA ram_area_music_buffer
    BEQ :+
.else
    RTS
.endif
bra_enable_sound_engine:
    LDA #$ff
    STA JOYPAD_PORT2  ; disable irqs and set frame counter mode???
    LDA #$0f
    STA SND_MASTERCTRL_REG  ; enable first four channels
.if con_revision_profile <> con_revision_profile_vs
    LDA ram_pause_mode_flag  ; is sound already in pause mode?
    BNE bra_handle_pause_sound
    LDA ram_pause_sound_queue  ; if not, check pause sfx queue
    CMP #$01
    BNE bra_run_sound_channels  ; if queue is empty, skip pause mode routine
bra_handle_pause_sound:
    LDA ram_pause_sound_buffer  ; check pause sfx buffer
    BNE bra_continue_pause_sound
    LDA ram_pause_sound_queue  ; check pause queue
    BEQ bra_clear_sound_queues
    STA ram_pause_sound_buffer  ; if queue full, store in buffer and activate
    STA ram_pause_mode_flag  ; pause mode to interrupt game sounds
    LDA #$00  ; disable sound and clear sfx buffers
    STA SND_MASTERCTRL_REG
    STA ram_square1_sound_buffer
    STA ram_square2_sound_buffer
    STA ram_noise_sound_buffer
    LDA #$0f
    STA SND_MASTERCTRL_REG  ; enable sound again
    LDA #$2a  ; store length of sound in pause counter
    STA ram_squ1_sfx_len_counter
bra_play_pause_first_tone:
    LDA #$44  ; play first tone
    BNE bra_store_pause_tone_registers  ; unconditional branch
bra_continue_pause_sound:
    LDA ram_squ1_sfx_len_counter  ; check pause length left
    CMP #$24  ; time to play second?
    BEQ bra_play_pause_second_tone
    CMP #$1e  ; time to play first again?
    BEQ bra_play_pause_first_tone
    CMP #$18  ; time to play second again?
    BNE bra_decrement_pause_sound_counter  ; only load regs during times, otherwise skip
bra_play_pause_second_tone:
    LDA #$64  ; store reg contents and play the pause sfx
bra_store_pause_tone_registers:
    LDX #$84
    LDY #$7f
    JSR sub_play_square_1_sound_effect
bra_decrement_pause_sound_counter:
    DEC ram_squ1_sfx_len_counter  ; decrement pause sfx counter
    BNE bra_clear_sound_queues
    LDA #$00  ; disable sound if in pause mode and
    STA SND_MASTERCTRL_REG  ; not currently playing the pause sfx
    LDA ram_pause_sound_buffer  ; if no longer playing pause sfx, check to see
    CMP #$02  ; if we need to be playing sound again
    BNE bra_finish_pause_sound
    LDA #$00  ; clear pause mode to allow game sounds again
    STA ram_pause_mode_flag
bra_finish_pause_sound:
    LDA #$00  ; clear pause sfx buffer
    STA ram_pause_sound_buffer
    BEQ bra_clear_sound_queues
.endif

bra_run_sound_channels:
    JSR sub_handle_square_1_sound_effect  ; play sfx on square channel 1
    JSR sub_handle_square_2_sound_effect  ; ''  ''  '' square channel 2
    JSR sub_handle_noise_sound_effect  ; ''  ''  '' noise channel
    JSR sub_music_handler  ; play music on all channels
.if con_revision_profile = con_revision_profile_vs
    :
.endif
    LDA #$00  ; clear the music queues
    STA ram_area_music_queue
    STA ram_event_music_queue

bra_clear_sound_queues:
    LDA #$00  ; clear the sound effects queues
    STA ram_square1_sound_queue
    STA ram_square2_sound_queue
    STA ram_noise_sound_queue
.if con_revision_profile <> con_revision_profile_vs
    STA ram_pause_sound_queue
.endif
    LDY ram_dac_counter  ; load some sort of counter
    LDA ram_area_music_buffer
    AND #%00000011  ; check for specific music
    BEQ bra_decay_dmc_load_counter
    INC ram_dac_counter  ; increment and check counter
    CPY #$30
    BCC bra_store_dmc_load_counter  ; if not there yet, just store it
bra_decay_dmc_load_counter:
    TYA
    BEQ bra_store_dmc_load_counter  ; if we are at zero, do not decrement
    DEC ram_dac_counter  ; decrement counter
bra_store_dmc_load_counter:
    STY SND_DELTA_REG+1  ; store into DMC load register (??)
    RTS  ; we are done here

; --------------------------------

sub_store_square_1_registers:
    STY SND_SQUARE1_REG+1  ; dump the contents of X and Y into square 1's control regs
    STX SND_SQUARE1_REG
    RTS

sub_play_square_1_sound_effect:
    JSR sub_store_square_1_registers  ; do sub to set ctrl regs for square 1, then set frequency regs

sub_set_square_1_frequency:
    LDX #$00  ; set frequency reg offset for square 1 sound channel

bra_store_frequency_registers:
    TAY
    LDA tbl_music_note_periods+1,y  ; use previous contents of A for sound reg offset
    BEQ bra_exit_frequency_update  ; if zero, then do not load
    STA SND_REGISTER+2,x  ; first byte goes into LSB of frequency divider
    LDA tbl_music_note_periods,y  ; second byte goes into 3 MSB plus extra bit for
    ORA #%00001000  ; length counter
    STA SND_REGISTER+3,x
bra_exit_frequency_update:
    RTS

sub_store_square_2_registers:
    STX SND_SQUARE2_REG  ; dump the contents of X and Y into square 2's control regs
    STY SND_SQUARE2_REG+1
    RTS

sub_play_square_2_sound_effect:
    JSR sub_store_square_2_registers  ; do sub to set ctrl regs for square 2, then set frequency regs

sub_set_square_2_frequency:
    LDX #$04  ; set frequency reg offset for square 2 sound channel
    BNE bra_store_frequency_registers  ; unconditional branch

sub_set_triangle_frequency:
    LDX #$08  ; set frequency reg offset for triangle sound channel
    BNE bra_store_frequency_registers  ; unconditional branch

; --------------------------------

tbl_swim_stomp_volume_envelope:
    .byte $9f, $9b, $98, $96, $95, $94, $92, $90
    .byte $90, $9a, $97, $95, $93, $92

bra_start_flagpole_slide_sound:
    LDA #$40  ; store length of flagpole sound
    STA ram_squ1_sfx_len_counter
    LDA #$62  ; load part of reg contents for flagpole sound
    JSR sub_set_square_1_frequency
    LDX #$99  ; now load the rest
    BNE bra_load_flagpole_or_jump_sweep_register

bra_start_small_jump_sound:
    LDA #$26  ; branch here for small mario jumping sound
    BNE bra_store_jump_sound_registers

bra_start_big_jump_sound:
    LDA #$18  ; branch here for big mario jumping sound

bra_store_jump_sound_registers:
    LDX #$82  ; note that small and big jump borrow each others' reg contents
    LDY #$a7  ; anyway, this loads the first part of mario's jumping sound
    JSR sub_play_square_1_sound_effect
    LDA #$28  ; store length of sfx for both jumping sounds
    STA ram_squ1_sfx_len_counter  ; then continue on here

bra_continue_jump_sound:
    LDA ram_squ1_sfx_len_counter  ; jumping sounds seem to be composed of three parts
    CMP #$25  ; check for time to play second part yet
    BNE bra_check_jump_sound_third_part
    LDX #$5f  ; load second part
    LDY #$f6
    BNE bra_store_flagpole_or_jump_registers  ; unconditional branch
bra_check_jump_sound_third_part:
    CMP #$20  ; check for third part
    BNE bra_decrement_jump_flagpole_or_bump_sound
    LDX #$48  ; load third part
bra_load_flagpole_or_jump_sweep_register:
    LDY #$bc  ; the flagpole slide sound shares part of third part
bra_store_flagpole_or_jump_registers:
    JSR sub_store_square_1_registers
    BNE bra_decrement_jump_flagpole_or_bump_sound  ; unconditional branch outta here

bra_start_fireball_throw_sound:
    LDA #$05
    LDY #$99  ; load reg contents for fireball throw sound
    BNE bra_store_bump_or_fireball_sound_registers  ; unconditional branch

bra_start_bump_sound:
    LDA #$0a  ; load length of sfx and reg contents for bump sound
    LDY #$93
bra_store_bump_or_fireball_sound_registers:
    LDX #$9e  ; the fireball sound shares reg contents with the bump sound
    STA ram_squ1_sfx_len_counter
    LDA #$0c  ; load offset for bump sound
    JSR sub_play_square_1_sound_effect

bra_continue_bump_or_fireball_sound:
    LDA ram_squ1_sfx_len_counter  ; check for second part of bump sound
    CMP #$06
    BNE bra_decrement_jump_flagpole_or_bump_sound
    LDA #$bb  ; load second part directly
    STA SND_SQUARE1_REG+1
bra_decrement_jump_flagpole_or_bump_sound:
    BNE bra_decrement_square_1_sound  ; unconditional branch

sub_handle_square_1_sound_effect:
    LDY ram_square1_sound_queue  ; check for sfx in queue
    BEQ bra_continue_square_1_sound
    STY ram_square1_sound_buffer  ; if found, put in buffer
    BMI bra_start_small_jump_sound  ; small jump
    LSR ram_square1_sound_queue
    BCS bra_start_big_jump_sound  ; big jump
    LSR ram_square1_sound_queue
    BCS bra_start_bump_sound  ; bump
    LSR ram_square1_sound_queue
    BCS bra_start_swim_stomp_sound  ; swim/stomp
    LSR ram_square1_sound_queue
    BCS bra_start_smack_enemy_sound  ; smack enemy
    LSR ram_square1_sound_queue
    BCS bra_start_pipe_or_injury_sound  ; pipedown/injury
    LSR ram_square1_sound_queue
    BCS bra_start_fireball_throw_sound  ; fireball throw
    LSR ram_square1_sound_queue
    BCS bra_start_flagpole_slide_sound  ; slide flagpole

bra_continue_square_1_sound:
    LDA ram_square1_sound_buffer  ; check for sfx in buffer
    BEQ bra_exit_square_1_sound_handler  ; if not found, exit sub
    BMI bra_continue_jump_sound  ; small mario jump
    LSR
    BCS bra_continue_jump_sound  ; big mario jump
    LSR
    BCS bra_continue_bump_or_fireball_sound  ; bump
    LSR
    BCS bra_continue_swim_stomp_sound  ; swim/stomp
    LSR
    BCS bra_continue_smack_enemy_sound  ; smack enemy
    LSR
    BCS bra_continue_pipe_or_injury_sound  ; pipedown/injury
    LSR
    BCS bra_continue_bump_or_fireball_sound  ; fireball throw
    LSR
    BCS loc_decrement_square_1_sound_length  ; slide flagpole
bra_exit_square_1_sound_handler:
    RTS

bra_start_swim_stomp_sound:
    LDA #$0e  ; store length of swim/stomp sound
    STA ram_squ1_sfx_len_counter
    LDY #$9c  ; store reg contents for swim/stomp sound
    LDX #$9e
    LDA #$26
    JSR sub_play_square_1_sound_effect

bra_continue_swim_stomp_sound:
    LDY ram_squ1_sfx_len_counter  ; look up reg contents in data section based on
    LDA tbl_swim_stomp_volume_envelope-1,y  ; length of sound left, used to control sound's
    STA SND_SQUARE1_REG  ; envelope
    CPY #$06
    BNE bra_decrement_square_1_sound
    LDA #$9e  ; when the length counts down to a certain point, put this
    STA SND_SQUARE1_REG+2  ; directly into the LSB of square 1's frequency divider

bra_decrement_square_1_sound:
    BNE loc_decrement_square_1_sound_length  ; unconditional branch (regardless of how we got here)

bra_start_smack_enemy_sound:
    LDA #$0e  ; store length of smack enemy sound
    LDY #$cb
    LDX #$9f
    STA ram_squ1_sfx_len_counter
    LDA #$28  ; store reg contents for smack enemy sound
    JSR sub_play_square_1_sound_effect
    BNE loc_decrement_square_1_sound_length  ; unconditional branch

bra_continue_smack_enemy_sound:
    LDY ram_squ1_sfx_len_counter  ; check about halfway through
    CPY #$08
    BNE bra_insert_smack_enemy_silence
    LDA #$a0  ; if we're at the about-halfway point, make the second tone
    STA SND_SQUARE1_REG+2  ; in the smack enemy sound
    LDA #$9f
    BNE bra_store_smack_enemy_envelope
bra_insert_smack_enemy_silence:
    LDA #$90  ; this creates spaces in the sound, giving it its distinct noise
bra_store_smack_enemy_envelope:
    STA SND_SQUARE1_REG

loc_decrement_square_1_sound_length:
    DEC ram_squ1_sfx_len_counter  ; decrement length of sfx
    BNE bra_exit_square_1_sound

sub_stop_square_1_sound_effect:
    LDX #$00  ; if end of sfx reached, clear buffer
    STX $f1  ; and stop making the sfx
    LDX #$0e
    STX SND_MASTERCTRL_REG
    LDX #$0f
    STX SND_MASTERCTRL_REG
bra_exit_square_1_sound:
    RTS

bra_start_pipe_or_injury_sound:
    LDA #$2f  ; load length of pipedown sound
    STA ram_squ1_sfx_len_counter

bra_continue_pipe_or_injury_sound:
    LDA ram_squ1_sfx_len_counter  ; some bitwise logic, forces the regs
    LSR  ; to be written to only during six specific times
    BCS bra_skip_pipe_or_injury_register_update  ; during which d3 must be set and d1-0 must be clear
    LSR
    BCS bra_skip_pipe_or_injury_register_update
    AND #%00000010
    BEQ bra_skip_pipe_or_injury_register_update
    LDY #$91  ; and this is where it actually gets written in
    LDX #$9a
    LDA #$44
    JSR sub_play_square_1_sound_effect
bra_skip_pipe_or_injury_register_update:
    JMP loc_decrement_square_1_sound_length

; --------------------------------

tbl_extra_life_frequency_sequence:
    .byte $58, $02, $54, $56, $4e, $44

tbl_power_up_grab_frequency_sequence:
    .byte $4c, $52, $4c, $48, $3e, $36, $3e, $36, $30
    .byte $28, $4a, $50, $4a, $64, $3c, $32, $3c, $32
    .byte $2c, $24, $3a, $64, $3a, $34, $2c, $22, $2c

; residual frequency data
    .byte $22, $1c, $14

tbl_power_up_reveal_and_vine_frequency_sequence:
    .byte $14, $04, $22, $24, $16, $04, $24, $26  ; used by both
    .byte $18, $04, $26, $28, $1a, $04, $28, $2a
    .byte $1c, $04, $2a, $2c, $1e, $04, $2c, $2e  ; used by vinegrow
    .byte $20, $04, $2e, $30, $22, $04, $30, $32

bra_start_coin_grab_sound:
    LDA #$35  ; load length of coin grab sound
    LDX #$8d  ; and part of reg contents
    BNE bra_store_coin_or_timer_sound_registers

bra_start_timer_tick_sound:
    LDA #$06  ; load length of timer tick sound
    LDX #$98  ; and part of reg contents

bra_store_coin_or_timer_sound_registers:
    STA ram_squ2_sfx_len_counter
    LDY #$7f  ; load the rest of reg contents
    LDA #$42  ; of coin grab and timer tick sound
    JSR sub_play_square_2_sound_effect

loc_continue_coin_or_timer_sound:
    LDA ram_squ2_sfx_len_counter  ; check for time to play second tone yet
    CMP #$30  ; !(WHY?) SND-001 - timer tick shares this path
    BNE bra_decrement_coin_or_timer_sound
.if con_revision_profile = con_revision_profile_pal
    LDA #$4e
.else
    LDA #$54  ; if so, load the tone directly into the reg
.endif
    STA SND_SQUARE2_REG+2
bra_decrement_coin_or_timer_sound:
    BNE loc_decrement_square_2_sound_length

bra_start_blast_sound:
    LDA #$20  ; load length of fireworks/gunfire sound
    STA ram_squ2_sfx_len_counter
    LDY #$94  ; load reg contents of fireworks/gunfire sound
    LDA #$5e
    BNE bra_store_blast_sound_registers

bra_continue_blast_sound:
    LDA ram_squ2_sfx_len_counter  ; check for time to play second part
    CMP #$18
    BNE loc_decrement_square_2_sound_length
    LDY #$93  ; load second part reg contents then
    LDA #$18
bra_store_blast_sound_registers:
    BNE bra_store_blast_or_bowser_fall_registers  ; unconditional branch to load rest of reg contents

bra_start_power_up_grab_sound:
    LDA #$36  ; load length of power-up grab sound
    STA ram_squ2_sfx_len_counter

bra_continue_power_up_grab_sound:
    LDA ram_squ2_sfx_len_counter  ; load frequency reg based on length left over
    LSR  ; divide by 2
    BCS loc_decrement_square_2_sound_length  ; alter frequency every other frame
    TAY
    LDA tbl_power_up_grab_frequency_sequence-1,y  ; use length left over / 2 for frequency offset
    LDX #$5d  ; store reg contents of power-up grab sound
    LDY #$7f

bra_store_square_2_sound_registers:
    JSR sub_play_square_2_sound_effect

loc_decrement_square_2_sound_length:
    DEC ram_squ2_sfx_len_counter  ; decrement length of sfx
    BNE bra_exit_square_2_sound

loc_clear_square_2_sound_buffer:
    LDX #$00  ; initialize square 2's sound effects buffer
    STX ram_square2_sound_buffer

sub_stop_square_2_sound_effect:
    LDX #$0d  ; stop playing the sfx
    STX SND_MASTERCTRL_REG
    LDX #$0f
    STX SND_MASTERCTRL_REG
bra_exit_square_2_sound:
    RTS

sub_handle_square_2_sound_effect:
    LDA ram_square2_sound_buffer  ; special handling for the 1-up sound to keep it
    AND #con_sfx_extra_life  ; from being interrupted by other sounds on square 2
    BNE bra_continue_extra_life_sound
    LDY ram_square2_sound_queue  ; check for sfx in queue
    BEQ bra_continue_square_2_sound
    STY ram_square2_sound_buffer  ; if found, put in buffer and check for the following
    BMI bra_start_bowser_fall_sound  ; bowser fall
    LSR ram_square2_sound_queue
    BCS bra_start_coin_grab_sound  ; coin grab
    LSR ram_square2_sound_queue
    BCS bra_start_power_up_reveal_sound  ; power-up reveal
    LSR ram_square2_sound_queue
    BCS bra_start_vine_grow_sound  ; vine grow
    LSR ram_square2_sound_queue
    BCS bra_start_blast_sound  ; fireworks/gunfire
    LSR ram_square2_sound_queue
    BCS bra_start_timer_tick_sound  ; timer tick
    LSR ram_square2_sound_queue
    BCS bra_start_power_up_grab_sound  ; power-up grab
    LSR ram_square2_sound_queue
    BCS bra_start_extra_life_sound  ; 1-up

bra_continue_square_2_sound:
    LDA ram_square2_sound_buffer  ; check for sfx in buffer
    BEQ bra_exit_square_2_sound_handler  ; if not found, exit sub
    BMI bra_continue_bowser_fall_sound  ; bowser fall
    LSR
    BCS bra_continue_coin_or_timer_sound  ; coin grab
    LSR
    BCS bra_continue_growing_item_sound  ; power-up reveal
    LSR
    BCS bra_continue_growing_item_sound  ; vine grow
    LSR
    BCS bra_continue_blast_sound  ; fireworks/gunfire
    LSR
    BCS bra_continue_coin_or_timer_sound  ; timer tick
    LSR
    BCS bra_continue_power_up_grab_sound  ; power-up grab
    LSR
    BCS bra_continue_extra_life_sound  ; 1-up
bra_exit_square_2_sound_handler:
    RTS

bra_continue_coin_or_timer_sound:
    JMP loc_continue_coin_or_timer_sound

bra_decrement_square_2_sound:
    JMP loc_decrement_square_2_sound_length

bra_start_bowser_fall_sound:
    LDA #$38  ; load length of bowser defeat sound
    STA ram_squ2_sfx_len_counter
    LDY #$c4  ; load contents of reg for bowser defeat sound
    LDA #$18
bra_store_blast_or_bowser_fall_registers:
    BNE bra_store_bowser_fall_registers

bra_continue_bowser_fall_sound:
    LDA ram_squ2_sfx_len_counter  ; check for almost near the end
    CMP #$08
    BNE loc_decrement_square_2_sound_length
    LDY #$a4  ; if so, load the rest of reg contents for bowser defeat sound
    LDA #$5a
bra_store_bowser_fall_registers:
    LDX #$9f  ; the fireworks/gunfire sound shares part of reg contents here
bra_load_square_2_sound_registers:
    BNE bra_store_square_2_sound_registers  ; this is an unconditional branch outta here

bra_start_extra_life_sound:
    LDA #$30  ; load length of 1-up sound
    STA ram_squ2_sfx_len_counter

bra_continue_extra_life_sound:
    LDA ram_squ2_sfx_len_counter
    LDX #$03  ; load new tones only every eight frames
bra_check_extra_life_note_interval:
    LSR
    BCS bra_decrement_square_2_sound  ; if any bits set here, branch to dec the length
    DEX
    BNE bra_check_extra_life_note_interval  ; do this until all bits checked, if none set, continue
    TAY
    LDA tbl_extra_life_frequency_sequence-1,y  ; load our reg contents
    LDX #$82
    LDY #$7f
    BNE bra_load_square_2_sound_registers  ; unconditional branch

bra_start_power_up_reveal_sound:
    LDA #$10  ; load length of power-up reveal sound
    BNE bra_initialize_growing_item_sound

bra_start_vine_grow_sound:
    LDA #$20  ; load length of vine grow sound

bra_initialize_growing_item_sound:
    STA ram_squ2_sfx_len_counter
    LDA #$7f  ; load contents of reg for both sounds directly
    STA SND_SQUARE2_REG+1
    LDA #$00  ; start secondary counter for both sounds
    STA ram_sfx_secondary_counter

bra_continue_growing_item_sound:
    INC ram_sfx_secondary_counter  ; increment secondary counter for both sounds
    LDA ram_sfx_secondary_counter  ; this sound doesn't decrement the usual counter
    LSR  ; divide by 2 to get the offset
    TAY
    CPY ram_squ2_sfx_len_counter  ; have we reached the end yet?
    BEQ bra_stop_growing_item_sound  ; if so, branch to jump, and stop playing sounds
    LDA #$9d  ; load contents of other reg directly
    STA SND_SQUARE2_REG
    LDA tbl_power_up_reveal_and_vine_frequency_sequence,y  ; use secondary counter / 2 as offset for frequency regs
    JSR sub_set_square_2_frequency
    RTS

bra_stop_growing_item_sound:
    JMP loc_clear_square_2_sound_buffer  ; branch to stop playing sounds

; --------------------------------

tbl_brick_shatter_noise_frequencies:
    .byte $01, $0e, $0e, $0d, $0b, $06, $0c, $0f
    .byte $0a, $09, $03, $0d, $08, $0d, $06, $0c

bra_start_brick_shatter_sound:
    LDA #$20  ; load length of brick shatter sound
    STA ram_noise_sfx_len_counter

bra_continue_brick_shatter_sound:
    LDA ram_noise_sfx_len_counter
    LSR  ; divide by 2 and check for bit set to use offset
    BCC bra_decrement_noise_sound_length
    TAY
    LDX tbl_brick_shatter_noise_frequencies,y  ; load reg contents of brick shatter sound
    LDA tbl_brick_shatter_volume_envelope,y

bra_store_noise_sound_registers:
    STA SND_NOISE_REG  ; play the sfx
    STX SND_NOISE_REG+2
    LDA #$18
    STA SND_NOISE_REG+3

bra_decrement_noise_sound_length:
    DEC ram_noise_sfx_len_counter  ; decrement length of sfx
    BNE bra_exit_noise_sound
    LDA #$f0  ; if done, stop playing the sfx
    STA SND_NOISE_REG
    LDA #$00
    STA ram_noise_sound_buffer
bra_exit_noise_sound:
    RTS

sub_handle_noise_sound_effect:
    LDY ram_noise_sound_queue  ; check for sfx in queue
    BEQ bra_continue_noise_sound
    STY ram_noise_sound_buffer  ; if found, put in buffer
    LSR ram_noise_sound_queue
    BCS bra_start_brick_shatter_sound  ; brick shatter
    LSR ram_noise_sound_queue
    BCS bra_start_bowser_flame_sound  ; bowser flame

bra_continue_noise_sound:
    LDA ram_noise_sound_buffer  ; check for sfx in buffer
    BEQ bra_exit_noise_sound_handler  ; if not found, exit sub
    LSR
    BCS bra_continue_brick_shatter_sound  ; brick shatter
    LSR
    BCS bra_continue_bowser_flame_sound  ; bowser flame
bra_exit_noise_sound_handler:
    RTS

bra_start_bowser_flame_sound:
    LDA #$40  ; load length of bowser flame sound
    STA ram_noise_sfx_len_counter

bra_continue_bowser_flame_sound:
    LDA ram_noise_sfx_len_counter
    LSR
    TAY
    LDX #$0f  ; load reg contents of bowser flame sound
    LDA tbl_bowser_flame_volume_envelope-1,y
    BNE bra_store_noise_sound_registers  ; unconditional branch here
