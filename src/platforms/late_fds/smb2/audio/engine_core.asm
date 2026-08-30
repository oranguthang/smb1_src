sub_smb2_main_sound_engine:
    LDA OperMode  ; are we in attract mode?
    BNE bra_smb2_main_enable_sound_engine
    STA SND_MASTERCTRL_REG  ; if so, disable sound and leave
    RTS
bra_smb2_main_enable_sound_engine:
    LDA #$ff
    STA JOYPAD_PORT2  ; disable irqs from apu and set frame counter mode
    LDA #$0f
    STA SND_MASTERCTRL_REG  ; enable first four channels
    LDA PauseModeFlag  ; is sound already in pause mode?
    BNE bra_smb2_main_handle_pause_sound
    LDA PauseSoundQueue  ; if not, check pause sfx queue
    CMP #$01
    BNE bra_smb2_main_run_sound_channels  ; if queue is empty, skip pause mode routine
bra_smb2_main_handle_pause_sound:
    LDA PauseSoundBuffer  ; check pause sfx buffer
    BNE bra_smb2_main_continue_pause_sound
    LDA PauseSoundQueue  ; check pause queue
    BEQ bra_smb2_main_clear_sound_queues
    STA PauseSoundBuffer  ; if queue full, store in buffer and activate
    STA PauseModeFlag  ; pause mode to interrupt game sounds
    LDA #$00  ; disable sound and clear sfx buffers
    STA SND_MASTERCTRL_REG
    STA Square1SoundBuffer
    STA Square2SoundBuffer
    STA NoiseSoundBuffer
    LDA #$0f
    STA SND_MASTERCTRL_REG  ; enable sound again
    LDA #$2a  ; store length of sound in pause counter
    STA Squ1_SfxLenCounter
bra_smb2_main_play_pause_first_tone:
    LDA #$44  ; play first tone
    BNE bra_smb2_main_store_pause_tone_registers  ; unconditional branch
bra_smb2_main_continue_pause_sound:
    LDA Squ1_SfxLenCounter  ; check pause length left
    CMP #$24  ; time to play second?
    BEQ bra_smb2_main_play_pause_second_tone
    CMP #$1e  ; time to play first again?
    BEQ bra_smb2_main_play_pause_first_tone
    CMP #$18  ; time to play second again?
    BNE bra_smb2_main_decrement_pause_sound_counter  ; only load regs during times, otherwise skip
bra_smb2_main_play_pause_second_tone:
    LDA #$64  ; store reg contents and play the pause sfx
bra_smb2_main_store_pause_tone_registers:
    LDX #$84
    LDY #$7f
    JSR sub_smb2_main_play_square_1_sound_effect
bra_smb2_main_decrement_pause_sound_counter:
    DEC Squ1_SfxLenCounter  ; decrement pause sfx counter
    BNE bra_smb2_main_clear_sound_queues
    LDA #$00  ; disable sound if in pause mode and
    STA SND_MASTERCTRL_REG  ; not currently playing the pause sfx
    LDA PauseSoundBuffer  ; if no longer playing pause sfx, check to see
    CMP #$02  ; if we need to be playing sound again
    BNE bra_smb2_main_finish_pause_sound
    LDA #$00  ; clear pause mode to allow game sounds again
    STA PauseModeFlag
bra_smb2_main_finish_pause_sound:
    LDA #$00  ; clear pause sfx buffer
    STA PauseSoundBuffer
    BEQ bra_smb2_main_clear_sound_queues

bra_smb2_main_run_sound_channels:
    JSR sub_smb2_main_handle_square_1_sound_effect  ; play sfx on square channel 1
    JSR sub_smb2_main_handle_square_2_sound_effect  ; ''  ''  '' square channel 2
    JSR sub_smb2_main_handle_noise_sound_effect  ; ''  ''  '' noise channel
    JSR sub_smb2_main_music_handler  ; play music on all channels
    LDA #$00  ; clear the music queues
    STA AreaMusicQueue
    STA EventMusicQueue

bra_smb2_main_clear_sound_queues:
    LDA #$00  ; clear the sound effects queues
    STA Square1SoundQueue
    STA Square2SoundQueue
    STA NoiseSoundQueue
    STA PauseSoundQueue
    LDY DAC_Counter  ; load some sort of counter
    LDA AreaMusicBuffer
    AND #%00000011  ; check for specific music
    BEQ bra_smb2_main_decay_dmc_load_counter
    INC DAC_Counter  ; increment and check counter
    CPY #$30
    BCC bra_smb2_main_store_dmc_load_counter  ; if not there yet, just store it
bra_smb2_main_decay_dmc_load_counter:
    TYA
    BEQ bra_smb2_main_store_dmc_load_counter  ; if we are at zero, do not decrement
    DEC DAC_Counter  ; decrement counter
bra_smb2_main_store_dmc_load_counter:
    STY SND_DELTA_REG+1  ; store into DMC load register (??)
    RTS  ; we are done here

; --------------------------------

sub_smb2_main_store_square_1_registers:
    STY SND_SQUARE1_REG+1  ; dump the contents of X and Y into square 1's control regs
    STX SND_SQUARE1_REG
    RTS

sub_smb2_main_play_square_1_sound_effect:
    JSR sub_smb2_main_store_square_1_registers  ; do sub to set ctrl regs for square 1, then set frequency regs

sub_smb2_main_set_square_1_frequency:
    LDX #$00  ; set frequency reg offset for square 1 sound channel

bra_smb2_main_store_frequency_registers:
    TAY
    LDA tbl_smb2_main_music_note_periods+1,y  ; use previous contents of A for sound reg offset
    BEQ bra_smb2_main_exit_frequency_update  ; if zero, then do not load
    STA SND_REGISTER+2,x  ; first byte goes into LSB of frequency divider
    LDA tbl_smb2_main_music_note_periods,y  ; second byte goes into 3 MSB plus extra bit for
    ORA #%00001000  ; length counter
    STA SND_REGISTER+3,x
bra_smb2_main_exit_frequency_update:
    RTS

sub_smb2_main_store_square_2_registers:
    STX SND_SQUARE2_REG  ; dump the contents of X and Y into square 2's control regs
    STY SND_SQUARE2_REG+1
    RTS

sub_smb2_main_play_square_2_sound_effect:
    JSR sub_smb2_main_store_square_2_registers  ; do sub to set ctrl regs for square 2, then set frequency regs

sub_smb2_main_set_square_2_frequency:
    LDX #$04  ; set frequency reg offset for square 2 sound channel
    BNE bra_smb2_main_store_frequency_registers  ; unconditional branch

sub_smb2_main_set_triangle_frequency:
    LDX #$08  ; set frequency reg offset for triangle sound channel
    BNE bra_smb2_main_store_frequency_registers  ; unconditional branch

; --------------------------------

off_smb2_main_swim_stomp_volume_envelope:
    .byte $9f, $9b, $98, $96, $95, $94, $92, $90
    .byte $90, $9a, $97, $95, $93, $92

bra_smb2_main_start_flagpole_slide_sound:
    LDA #$40  ; store length of flagpole sound
    STA Squ1_SfxLenCounter
    LDA #$62  ; load part of reg contents for flagpole sound
    JSR sub_smb2_main_set_square_1_frequency
    LDX #$99  ; now load the rest
    BNE bra_smb2_main_load_flagpole_or_jump_sweep_register

bra_smb2_main_start_small_jump_sound:
    LDA #$26  ; branch here for small mario jumping sound
    BNE bra_smb2_main_store_jump_sound_registers

bra_smb2_main_start_big_jump_sound:
    LDA #$18  ; branch here for big mario jumping sound

bra_smb2_main_store_jump_sound_registers:
    LDX #$82  ; note that small and big jump borrow each others' reg contents
    LDY #$a7  ; anyway, this loads the first part of mario's jumping sound
    JSR sub_smb2_main_play_square_1_sound_effect
    LDA #$28  ; store length of sfx for both jumping sounds
    STA Squ1_SfxLenCounter  ; then continue on here

bra_smb2_main_continue_jump_sound:
    LDA Squ1_SfxLenCounter  ; jumping sounds seem to be composed of three parts
    CMP #$25  ; check for time to play second part yet
    BNE bra_smb2_main_check_jump_sound_third_part
    LDX #$5f  ; load second part
    LDY #$f6
    BNE bra_smb2_main_store_flagpole_or_jump_registers  ; unconditional branch
bra_smb2_main_check_jump_sound_third_part:
    CMP #$20  ; check for third part
    BNE bra_smb2_main_decrement_jump_flagpole_or_bump_sound
    LDX #$48  ; load third part
bra_smb2_main_load_flagpole_or_jump_sweep_register:
    LDY #$bc  ; the flagpole slide sound shares part of third part
bra_smb2_main_store_flagpole_or_jump_registers:
    JSR sub_smb2_main_store_square_1_registers
    BNE bra_smb2_main_decrement_jump_flagpole_or_bump_sound  ; unconditional branch outta here

bra_smb2_main_start_fireball_throw_sound:
    LDA #$05
    LDY #$99  ; load reg contents for fireball throw sound
    BNE bra_smb2_main_store_bump_or_fireball_sound_registers  ; unconditional branch

bra_smb2_main_start_bump_sound:
    LDA #$0a  ; load length of sfx and reg contents for bump sound
    LDY #$93
bra_smb2_main_store_bump_or_fireball_sound_registers:
    LDX #$9e  ; the fireball sound shares reg contents with the bump sound
    STA Squ1_SfxLenCounter
    LDA #$0c  ; load offset for bump sound
    JSR sub_smb2_main_play_square_1_sound_effect

bra_smb2_main_continue_bump_or_fireball_sound:
    LDA Squ1_SfxLenCounter  ; check for second part of bump sound
    CMP #$06
    BNE bra_smb2_main_decrement_jump_flagpole_or_bump_sound
    LDA #$bb  ; load second part directly
    STA SND_SQUARE1_REG+1
bra_smb2_main_decrement_jump_flagpole_or_bump_sound:
    BNE bra_smb2_main_decrement_square_1_sound  ; unconditional branch

sub_smb2_main_handle_square_1_sound_effect:
    LDY Square1SoundQueue  ; check for sfx in queue
    BEQ bra_smb2_main_continue_square_1_sound
    STY Square1SoundBuffer  ; if found, put in buffer
    BMI bra_smb2_main_start_small_jump_sound  ; small jump
    LSR Square1SoundQueue
    BCS bra_smb2_main_start_big_jump_sound  ; big jump
    LSR Square1SoundQueue
    BCS bra_smb2_main_start_bump_sound  ; bump
    LSR Square1SoundQueue
    BCS bra_smb2_main_start_swim_stomp_sound  ; swim/stomp
    LSR Square1SoundQueue
    BCS bra_smb2_main_start_smack_enemy_sound  ; smack enemy
    LSR Square1SoundQueue
    BCS bra_smb2_main_start_pipe_or_injury_sound  ; pipedown/injury
    LSR Square1SoundQueue
    BCS bra_smb2_main_start_fireball_throw_sound  ; fireball throw
    LSR Square1SoundQueue
    BCS bra_smb2_main_start_flagpole_slide_sound  ; slide flagpole

bra_smb2_main_continue_square_1_sound:
    LDA Square1SoundBuffer  ; check for sfx in buffer
    BEQ bra_smb2_main_exit_square_1_sound_handler  ; if not found, exit sub
    BMI bra_smb2_main_continue_jump_sound  ; small mario jump
    LSR
    BCS bra_smb2_main_continue_jump_sound  ; big mario jump
    LSR
    BCS bra_smb2_main_continue_bump_or_fireball_sound  ; bump
    LSR
    BCS bra_smb2_main_continue_swim_stomp_sound  ; swim/stomp
    LSR
    BCS bra_smb2_main_continue_smack_enemy_sound  ; smack enemy
    LSR
    BCS bra_smb2_main_continue_pipe_or_injury_sound  ; pipedown/injury
    LSR
    BCS bra_smb2_main_continue_bump_or_fireball_sound  ; fireball throw
    LSR
    BCS bra_smb2_main_decrement_square_1_sound_length  ; slide flagpole
bra_smb2_main_exit_square_1_sound_handler:
    RTS

bra_smb2_main_start_swim_stomp_sound:
    LDA #$0e  ; store length of swim/stomp sound
    STA Squ1_SfxLenCounter
    LDY #$9c  ; store reg contents for swim/stomp sound
    LDX #$9e
    LDA #$26
    JSR sub_smb2_main_play_square_1_sound_effect

bra_smb2_main_continue_swim_stomp_sound:
    LDY Squ1_SfxLenCounter  ; look up reg contents in data section based on
    LDA off_smb2_main_swim_stomp_volume_envelope-1,y  ; length of sound left, used to control sound's
    STA SND_SQUARE1_REG  ; envelope
    CPY #$06
    BNE bra_smb2_main_decrement_square_1_sound
    LDA #$9e  ; when the length counts down to a certain point, put this
    STA SND_SQUARE1_REG+2  ; directly into the LSB of square 1's frequency divider

bra_smb2_main_decrement_square_1_sound:
    BNE bra_smb2_main_decrement_square_1_sound_length  ; unconditional branch (regardless of how we got here)

bra_smb2_main_start_smack_enemy_sound:
    LDA #$0e  ; store length of smack enemy sound
    LDY #$cb
    LDX #$9f
    STA Squ1_SfxLenCounter
    LDA #$28  ; store reg contents for smack enemy sound
    JSR sub_smb2_main_play_square_1_sound_effect
    BNE bra_smb2_main_decrement_square_1_sound_length  ; unconditional branch

bra_smb2_main_continue_smack_enemy_sound:
    LDY Squ1_SfxLenCounter  ; check about halfway through
    CPY #$08
    BNE bra_smb2_main_insert_smack_enemy_silence
    LDA #$a0  ; if we're at the about-halfway point, make the second tone
    STA SND_SQUARE1_REG+2  ; in the smack enemy sound
    LDA #$9f
    BNE bra_smb2_main_store_smack_enemy_envelope
bra_smb2_main_insert_smack_enemy_silence:
    LDA #$90  ; this creates spaces in the sound, giving it its distinct noise
bra_smb2_main_store_smack_enemy_envelope:
    STA SND_SQUARE1_REG

bra_smb2_main_decrement_square_1_sound_length:
    DEC Squ1_SfxLenCounter  ; decrement length of sfx
    BNE bra_smb2_main_exit_square_1_sound

sub_smb2_main_stop_square_1_sound_effect:
    LDX #$00  ; if end of sfx reached, clear buffer
    STX $f1  ; and stop making the sfx
    LDX #$0e
    STX SND_MASTERCTRL_REG
    LDX #$0f
    STX SND_MASTERCTRL_REG
bra_smb2_main_exit_square_1_sound:
    RTS

bra_smb2_main_start_pipe_or_injury_sound:
    LDA #$2f  ; load length of pipedown sound
    STA Squ1_SfxLenCounter

bra_smb2_main_continue_pipe_or_injury_sound:
    LDA Squ1_SfxLenCounter  ; some bitwise logic, forces the regs
    LSR  ; to be written to only during six specific times
    BCS bra_smb2_main_skip_pipe_or_injury_register_update  ; during which d3 must be set and d1-0 must be clear
    LSR
    BCS bra_smb2_main_skip_pipe_or_injury_register_update
    AND #%00000010
    BEQ bra_smb2_main_skip_pipe_or_injury_register_update
    LDY #$91  ; and this is where it actually gets written in
    LDX #$9a
    LDA #$44
    JSR sub_smb2_main_play_square_1_sound_effect
bra_smb2_main_skip_pipe_or_injury_register_update:
    JMP bra_smb2_main_decrement_square_1_sound_length

; --------------------------------

off_smb2_main_extra_life_frequency_sequence:
    .byte $58, $02, $54, $56, $4e, $44

off_smb2_main_power_up_grab_frequency_sequence:
    .byte $4c, $52, $4c, $48, $3e, $36, $3e, $36, $30
    .byte $28, $4a, $50, $4a, $64, $3c, $32, $3c, $32
    .byte $2c, $24, $3a, $64, $3a, $34, $2c, $22, $2c

; residual frequency data
    .byte $22, $1c, $14

off_smb2_main_power_up_reveal_and_vine_frequency_sequence:
    .byte $14, $04, $22, $24, $16, $04, $24, $26  ; used by both
    .byte $18, $04, $26, $28, $1a, $04, $28, $2a
    .byte $1c, $04, $2a, $2c, $1e, $04, $2c, $2e  ; used by vinegrow
    .byte $20, $04, $2e, $30, $22, $04, $30, $32

bra_smb2_main_start_coin_grab_sound:
    LDA #$35  ; load length of coin grab sound
    LDX #$8d  ; and part of reg contents
    BNE bra_smb2_main_store_coin_or_timer_sound_registers

bra_smb2_main_start_timer_tick_sound:
    LDA #$06  ; load length of timer tick sound
    LDX #$98  ; and part of reg contents

bra_smb2_main_store_coin_or_timer_sound_registers:
    STA Squ2_SfxLenCounter
    LDY #$7f  ; load the rest of reg contents
    LDA #$42  ; of coin grab and timer tick sound
    JSR sub_smb2_main_play_square_2_sound_effect

loc_smb2_main_continue_coin_or_timer_sound:
    LDA Squ2_SfxLenCounter  ; check for time to play second tone yet
    CMP #$30  ; timer tick sound also executes this, not sure why
    BNE bra_smb2_main_decrement_coin_or_timer_sound
    LDA #$54  ; if so, load the tone directly into the reg
    STA SND_SQUARE2_REG+2
bra_smb2_main_decrement_coin_or_timer_sound:
    BNE bra_smb2_main_decrement_square_2_sound_length

bra_smb2_main_start_blast_sound:
    LDA #$20  ; load length of fireworks/gunfire sound
    STA Squ2_SfxLenCounter
    LDY #$94  ; load reg contents of fireworks/gunfire sound
    LDA #$5e
    BNE bra_smb2_main_store_blast_sound_registers

bra_smb2_main_continue_blast_sound:
    LDA Squ2_SfxLenCounter  ; check for time to play second part
    CMP #$18
    BNE bra_smb2_main_decrement_square_2_sound_length
    LDY #$93  ; load second part reg contents then
    LDA #$18
bra_smb2_main_store_blast_sound_registers:
    BNE bra_smb2_main_store_blast_or_bowser_fall_registers  ; unconditional branch to load rest of reg contents

bra_smb2_main_start_power_up_grab_sound:
    LDA #$36  ; load length of power-up grab sound
    STA Squ2_SfxLenCounter

bra_smb2_main_continue_power_up_grab_sound:
    LDA Squ2_SfxLenCounter  ; load frequency reg based on length left over
    LSR  ; divide by 2
    BCS bra_smb2_main_decrement_square_2_sound_length  ; alter frequency every other frame
    TAY
    LDA off_smb2_main_power_up_grab_frequency_sequence-1,y  ; use length left over / 2 for frequency offset
    LDX #$5d  ; store reg contents of power-up grab sound
    LDY #$7f

bra_smb2_main_store_square_2_sound_registers:
    JSR sub_smb2_main_play_square_2_sound_effect

bra_smb2_main_decrement_square_2_sound_length:
    DEC Squ2_SfxLenCounter  ; decrement length of sfx
    BNE bra_smb2_main_exit_square_2_sound

loc_smb2_main_clear_square_2_sound_buffer:
    LDX #$00  ; initialize square 2's sound effects buffer
    STX Square2SoundBuffer

sub_smb2_main_stop_square_2_sound_effect:
    LDX #$0d  ; stop playing the sfx
    STX SND_MASTERCTRL_REG
    LDX #$0f
    STX SND_MASTERCTRL_REG
bra_smb2_main_exit_square_2_sound:
    RTS

sub_smb2_main_handle_square_2_sound_effect:
    LDA Square2SoundBuffer  ; special handling for the 1-up sound to keep it
    AND #Sfx_ExtraLife  ; from being interrupted by other sounds on square 2
    BNE bra_smb2_main_continue_extra_life_sound
    LDY Square2SoundQueue  ; check for sfx in queue
    BEQ bra_smb2_main_continue_square_2_sound
    STY Square2SoundBuffer  ; if found, put in buffer and check for the following
    BMI bra_smb2_main_start_bowser_fall_sound  ; bowser fall
    LSR Square2SoundQueue
    BCS bra_smb2_main_start_coin_grab_sound  ; coin grab
    LSR Square2SoundQueue
    BCS bra_smb2_main_start_power_up_reveal_sound  ; power-up reveal
    LSR Square2SoundQueue
    BCS bra_smb2_main_start_vine_grow_sound  ; vine grow
    LSR Square2SoundQueue
    BCS bra_smb2_main_start_blast_sound  ; fireworks/gunfire
    LSR Square2SoundQueue
    BCS bra_smb2_main_start_timer_tick_sound  ; timer tick
    LSR Square2SoundQueue
    BCS bra_smb2_main_start_power_up_grab_sound  ; power-up grab
    LSR Square2SoundQueue
    BCS bra_smb2_main_start_extra_life_sound  ; 1-up

bra_smb2_main_continue_square_2_sound:
    LDA Square2SoundBuffer  ; check for sfx in buffer
    BEQ bra_smb2_main_exit_square_2_sound_handler  ; if not found, exit sub
    BMI bra_smb2_main_continue_bowser_fall_sound  ; bowser fall
    LSR
    BCS bra_smb2_main_continue_coin_or_timer_sound  ; coin grab
    LSR
    BCS bra_smb2_main_continue_growing_item_sound  ; power-up reveal
    LSR
    BCS bra_smb2_main_continue_growing_item_sound  ; vine grow
    LSR
    BCS bra_smb2_main_continue_blast_sound  ; fireworks/gunfire
    LSR
    BCS bra_smb2_main_continue_coin_or_timer_sound  ; timer tick
    LSR
    BCS bra_smb2_main_continue_power_up_grab_sound  ; power-up grab
    LSR
    BCS bra_smb2_main_continue_extra_life_sound  ; 1-up
bra_smb2_main_exit_square_2_sound_handler:
    RTS

bra_smb2_main_continue_coin_or_timer_sound:
    JMP loc_smb2_main_continue_coin_or_timer_sound

bra_smb2_main_decrement_square_2_sound:
    JMP bra_smb2_main_decrement_square_2_sound_length

bra_smb2_main_start_bowser_fall_sound:
    LDA #$38  ; load length of bowser defeat sound
    STA Squ2_SfxLenCounter
    LDY #$c4  ; load contents of reg for bowser defeat sound
    LDA #$18
bra_smb2_main_store_blast_or_bowser_fall_registers:
    BNE bra_smb2_main_store_bowser_fall_registers

bra_smb2_main_continue_bowser_fall_sound:
    LDA Squ2_SfxLenCounter  ; check for almost near the end
    CMP #$08
    BNE bra_smb2_main_decrement_square_2_sound_length
    LDY #$a4  ; if so, load the rest of reg contents for bowser defeat sound
    LDA #$5a
bra_smb2_main_store_bowser_fall_registers:
    LDX #$9f  ; the fireworks/gunfire sound shares part of reg contents here
bra_smb2_main_load_square_2_sound_registers:
    BNE bra_smb2_main_store_square_2_sound_registers  ; this is an unconditional branch outta here

bra_smb2_main_start_extra_life_sound:
    LDA #$30  ; load length of 1-up sound
    STA Squ2_SfxLenCounter

bra_smb2_main_continue_extra_life_sound:
    LDA Squ2_SfxLenCounter
    LDX #$03  ; load new tones only every eight frames
bra_smb2_main_check_extra_life_note_interval:
    LSR
    BCS bra_smb2_main_decrement_square_2_sound  ; if any bits set here, branch to dec the length
    DEX
    BNE bra_smb2_main_check_extra_life_note_interval  ; do this until all bits checked, if none set, continue
    TAY
    LDA off_smb2_main_extra_life_frequency_sequence-1,y  ; load our reg contents
    LDX #$82
    LDY #$7f
    BNE bra_smb2_main_load_square_2_sound_registers  ; unconditional branch

bra_smb2_main_start_power_up_reveal_sound:
    LDA #$10  ; load length of power-up reveal sound
    BNE bra_smb2_main_initialize_growing_item_sound

bra_smb2_main_start_vine_grow_sound:
    LDA #$20  ; load length of vine grow sound

bra_smb2_main_initialize_growing_item_sound:
    STA Squ2_SfxLenCounter
    LDA #$7f  ; load contents of reg for both sounds directly
    STA SND_SQUARE2_REG+1
    LDA #$00  ; start secondary counter for both sounds
    STA Sfx_SecondaryCounter

bra_smb2_main_continue_growing_item_sound:
    INC Sfx_SecondaryCounter  ; increment secondary counter for both sounds
    LDA Sfx_SecondaryCounter  ; this sound doesn't decrement the usual counter
    LSR  ; divide by 2 to get the offset
    TAY
    CPY Squ2_SfxLenCounter  ; have we reached the end yet?
    BEQ bra_smb2_main_stop_growing_item_sound  ; if so, branch to jump, and stop playing sounds
    LDA #$9d  ; load contents of other reg directly
    STA SND_SQUARE2_REG
    LDA off_smb2_main_power_up_reveal_and_vine_frequency_sequence,y  ; use secondary counter / 2 as offset for frequency regs
    JSR sub_smb2_main_set_square_2_frequency
    RTS

bra_smb2_main_stop_growing_item_sound:
    JMP loc_smb2_main_clear_square_2_sound_buffer  ; branch to stop playing sounds

off_smb2_main_wind_freq_env_data:
    .byte $37, $46, $55, $64, $74, $83, $93, $a2
    .byte $b1, $c0, $d0, $e0, $f1, $f1, $f2, $e2
    .byte $e2, $c3, $a3, $84, $64, $44, $35, $25

off_smb2_main_brick_shatter_noise_frequencies:
    .byte $01, $0e, $0e, $0d, $0b, $06, $0c, $0f
    .byte $0a, $09, $03, $0d, $08, $0d, $06, $0c

off_smb2_main_skid_sfx_freq_data:
    .byte $47, $49, $42, $4a, $43, $4b

bra_smb2_main_play_skid_sfx:
    STY NoiseSoundBuffer
    LDA #$06
    STA Noise_SfxLenCounter

bra_smb2_main_continue_skid_sfx:
    LDA Noise_SfxLenCounter
    TAY
    LDA off_smb2_main_skid_sfx_freq_data-1,y
    STA SND_TRIANGLE_REG+2
    LDA #$18
    STA SND_TRIANGLE_REG
    STA SND_TRIANGLE_REG+3
    BNE bra_smb2_main_decrement_noise_sound_length

bra_smb2_main_start_brick_shatter_sound:
    STY NoiseSoundBuffer
    LDA #$20  ; load length of brick shatter sound
    STA Noise_SfxLenCounter

bra_smb2_main_continue_brick_shatter_sound:
    LDA Noise_SfxLenCounter
    LSR  ; divide by 2 and check for bit set to use offset
    BCC bra_smb2_main_decrement_noise_sound_length
    TAY
    LDX off_smb2_main_brick_shatter_noise_frequencies,y  ; load reg contents of brick shatter sound
    LDA off_smb2_main_brick_shatter_volume_envelope,y

bra_smb2_main_store_noise_sound_registers:
    STA SND_NOISE_REG  ; play the sfx
    STX SND_NOISE_REG+2
    LDA #$18
    STA SND_NOISE_REG+3

bra_smb2_main_decrement_noise_sound_length:
    DEC Noise_SfxLenCounter  ; decrement length of sfx
    BNE bra_smb2_main_exit_noise_sound
    LDA #$f0  ; if done, stop playing the sfx
    STA SND_NOISE_REG
    LDA #$00
    STA SND_TRIANGLE_REG
    LDA #$00
    STA NoiseSoundBuffer
bra_smb2_main_exit_noise_sound:
    RTS

sub_smb2_main_handle_noise_sound_effect:
    LDA NoiseSoundBuffer
    BMI bra_smb2_main_continue_skid_sfx
    LDY NoiseSoundQueue
    BMI bra_smb2_main_play_skid_sfx
    LSR NoiseSoundQueue
    BCS bra_smb2_main_start_brick_shatter_sound
    LSR
    BCS bra_smb2_main_continue_brick_shatter_sound
    LSR NoiseSoundQueue
    BCS bra_smb2_main_start_bowser_flame_sound
    LSR
    BCS bra_smb2_main_continue_bowser_flame_sound
    LSR
    BCS bra_smb2_main_continue_wind_sfx
    LSR NoiseSoundQueue
    BCS bra_smb2_main_play_wind_sfx
    RTS

bra_smb2_main_start_bowser_flame_sound:
    STY NoiseSoundBuffer
    LDA #$40  ; load length of bowser flame sound
    STA Noise_SfxLenCounter

bra_smb2_main_continue_bowser_flame_sound:
    LDA Noise_SfxLenCounter
    LSR
    TAY
    LDX #$0f  ; load reg contents of bowser flame sound
    LDA off_smb2_main_bowser_flame_volume_envelope-1,y
bra_smb2_main_wind_branch:
    BNE bra_smb2_main_store_noise_sound_registers  ; unconditional branch here

bra_smb2_main_play_wind_sfx:
    STY NoiseSoundBuffer
    LDA #$c0
    STA Noise_SfxLenCounter
bra_smb2_main_continue_wind_sfx:
    LSR NoiseSoundQueue  ; get bit for the wind sfx, note that it must
    BCC bra_smb2_main_exit_noise_sound  ; be continuously set in order for it to play
    LDA Noise_SfxLenCounter
    LSR
    LSR  ; divide length counter by 8
    LSR
    TAY
    LDA off_smb2_main_wind_freq_env_data,y
    AND #$0f  ; use lower nybble as frequency data
    ORA #$10
    TAX
    LDA off_smb2_main_wind_freq_env_data,y  ; use upper nybble as envelope data
    LSR
    LSR
    LSR
    LSR
    ORA #$10
    BNE bra_smb2_main_wind_branch  ; unconditional branch

; --------------------------------
