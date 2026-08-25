; -------------------------------------------------------------------------------------

; Arbitrate sound requests and advance SFX and music channels for one frame

; Inputs:
; Sound/music request queues, active channel buffers, and pause state

; Outputs:
; APU registers and channel sequencing state are updated

; Clobbers:
; A, X, Y
sub_sound_engine:
    LDA ram_oper_mode  ; are we in title screen mode?
    BNE SndOn
    STA SND_MASTERCTRL_REG  ; if so, disable sound and leave
    RTS
SndOn:
    LDA #$ff
    STA JOYPAD_PORT2  ; disable irqs and set frame counter mode???
    LDA #$0f
    STA SND_MASTERCTRL_REG  ; enable first four channels
    LDA ram_pause_mode_flag  ; is sound already in pause mode?
    BNE InPause
    LDA ram_pause_sound_queue  ; if not, check pause sfx queue
    CMP #$01
    BNE RunSoundSubroutines  ; if queue is empty, skip pause mode routine
InPause:
    LDA ram_pause_sound_buffer  ; check pause sfx buffer
    BNE ContPau
    LDA ram_pause_sound_queue  ; check pause queue
    BEQ SkipSoundSubroutines
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
PTone1F:
    LDA #$44  ; play first tone
    BNE PTRegC  ; unconditional branch
ContPau:
    LDA ram_squ1_sfx_len_counter  ; check pause length left
    CMP #$24  ; time to play second?
    BEQ PTone2F
    CMP #$1e  ; time to play first again?
    BEQ PTone1F
    CMP #$18  ; time to play second again?
    BNE DecPauC  ; only load regs during times, otherwise skip
PTone2F:
    LDA #$64  ; store reg contents and play the pause sfx
PTRegC:
    LDX #$84
    LDY #$7f
    JSR sub_play_squ1_sfx
DecPauC:
    DEC ram_squ1_sfx_len_counter  ; decrement pause sfx counter
    BNE SkipSoundSubroutines
    LDA #$00  ; disable sound if in pause mode and
    STA SND_MASTERCTRL_REG  ; not currently playing the pause sfx
    LDA ram_pause_sound_buffer  ; if no longer playing pause sfx, check to see
    CMP #$02  ; if we need to be playing sound again
    BNE SkipPIn
    LDA #$00  ; clear pause mode to allow game sounds again
    STA ram_pause_mode_flag
SkipPIn:
    LDA #$00  ; clear pause sfx buffer
    STA ram_pause_sound_buffer
    BEQ SkipSoundSubroutines

RunSoundSubroutines:
    JSR sub_square1_sfx_handler  ; play sfx on square channel 1
    JSR sub_square2_sfx_handler  ; ''  ''  '' square channel 2
    JSR sub_noise_sfx_handler  ; ''  ''  '' noise channel
    JSR sub_music_handler  ; play music on all channels
    LDA #$00  ; clear the music queues
    STA ram_area_music_queue
    STA ram_event_music_queue

SkipSoundSubroutines:
    LDA #$00  ; clear the sound effects queues
    STA ram_square1_sound_queue
    STA ram_square2_sound_queue
    STA ram_noise_sound_queue
    STA ram_pause_sound_queue
    LDY ram_dac_counter  ; load some sort of counter
    LDA ram_area_music_buffer
    AND #%00000011  ; check for specific music
    BEQ NoIncDAC
    INC ram_dac_counter  ; increment and check counter
    CPY #$30
    BCC StrWave  ; if not there yet, just store it
NoIncDAC:
    TYA
    BEQ StrWave  ; if we are at zero, do not decrement
    DEC ram_dac_counter  ; decrement counter
StrWave:
    STY SND_DELTA_REG+1  ; store into DMC load register (??)
    RTS  ; we are done here

; --------------------------------

sub_dump_squ1_regs:
    STY SND_SQUARE1_REG+1  ; dump the contents of X and Y into square 1's control regs
    STX SND_SQUARE1_REG
    RTS

sub_play_squ1_sfx:
    JSR sub_dump_squ1_regs  ; do sub to set ctrl regs for square 1, then set frequency regs

sub_set_freq_squ1:
    LDX #$00  ; set frequency reg offset for square 1 sound channel

Dump_Freq_Regs:
    TAY
    LDA FreqRegLookupTbl+1,y  ; use previous contents of A for sound reg offset
    BEQ NoTone  ; if zero, then do not load
    STA SND_REGISTER+2,x  ; first byte goes into LSB of frequency divider
    LDA FreqRegLookupTbl,y  ; second byte goes into 3 MSB plus extra bit for
    ORA #%00001000  ; length counter
    STA SND_REGISTER+3,x
NoTone:
    RTS

sub_dump_sq2_regs:
    STX SND_SQUARE2_REG  ; dump the contents of X and Y into square 2's control regs
    STY SND_SQUARE2_REG+1
    RTS

sub_play_squ2_sfx:
    JSR sub_dump_sq2_regs  ; do sub to set ctrl regs for square 2, then set frequency regs

sub_set_freq_squ2:
    LDX #$04  ; set frequency reg offset for square 2 sound channel
    BNE Dump_Freq_Regs  ; unconditional branch

sub_set_freq_tri:
    LDX #$08  ; set frequency reg offset for triangle sound channel
    BNE Dump_Freq_Regs  ; unconditional branch

; --------------------------------

SwimStompEnvelopeData:
    .byte $9f, $9b, $98, $96, $95, $94, $92, $90
    .byte $90, $9a, $97, $95, $93, $92

PlayFlagpoleSlide:
    LDA #$40  ; store length of flagpole sound
    STA ram_squ1_sfx_len_counter
    LDA #$62  ; load part of reg contents for flagpole sound
    JSR sub_set_freq_squ1
    LDX #$99  ; now load the rest
    BNE FPS2nd

PlaySmallJump:
    LDA #$26  ; branch here for small mario jumping sound
    BNE JumpRegContents

PlayBigJump:
    LDA #$18  ; branch here for big mario jumping sound

JumpRegContents:
    LDX #$82  ; note that small and big jump borrow each others' reg contents
    LDY #$a7  ; anyway, this loads the first part of mario's jumping sound
    JSR sub_play_squ1_sfx
    LDA #$28  ; store length of sfx for both jumping sounds
    STA ram_squ1_sfx_len_counter  ; then continue on here

ContinueSndJump:
    LDA ram_squ1_sfx_len_counter  ; jumping sounds seem to be composed of three parts
    CMP #$25  ; check for time to play second part yet
    BNE N2Prt
    LDX #$5f  ; load second part
    LDY #$f6
    BNE DmpJpFPS  ; unconditional branch
N2Prt:
    CMP #$20  ; check for third part
    BNE DecJpFPS
    LDX #$48  ; load third part
FPS2nd:
    LDY #$bc  ; the flagpole slide sound shares part of third part
DmpJpFPS:
    JSR sub_dump_squ1_regs
    BNE DecJpFPS  ; unconditional branch outta here

PlayFireballThrow:
    LDA #$05
    LDY #$99  ; load reg contents for fireball throw sound
    BNE Fthrow  ; unconditional branch

PlayBump:
    LDA #$0a  ; load length of sfx and reg contents for bump sound
    LDY #$93
Fthrow:
    LDX #$9e  ; the fireball sound shares reg contents with the bump sound
    STA ram_squ1_sfx_len_counter
    LDA #$0c  ; load offset for bump sound
    JSR sub_play_squ1_sfx

ContinueBumpThrow:
    LDA ram_squ1_sfx_len_counter  ; check for second part of bump sound
    CMP #$06
    BNE DecJpFPS
    LDA #$bb  ; load second part directly
    STA SND_SQUARE1_REG+1
DecJpFPS:
    BNE BranchToDecLength1  ; unconditional branch

sub_square1_sfx_handler:
    LDY ram_square1_sound_queue  ; check for sfx in queue
    BEQ CheckSfx1Buffer
    STY ram_square1_sound_buffer  ; if found, put in buffer
    BMI PlaySmallJump  ; small jump
    LSR ram_square1_sound_queue
    BCS PlayBigJump  ; big jump
    LSR ram_square1_sound_queue
    BCS PlayBump  ; bump
    LSR ram_square1_sound_queue
    BCS PlaySwimStomp  ; swim/stomp
    LSR ram_square1_sound_queue
    BCS PlaySmackEnemy  ; smack enemy
    LSR ram_square1_sound_queue
    BCS PlayPipeDownInj  ; pipedown/injury
    LSR ram_square1_sound_queue
    BCS PlayFireballThrow  ; fireball throw
    LSR ram_square1_sound_queue
    BCS PlayFlagpoleSlide  ; slide flagpole

CheckSfx1Buffer:
    LDA ram_square1_sound_buffer  ; check for sfx in buffer
    BEQ ExS1H  ; if not found, exit sub
    BMI ContinueSndJump  ; small mario jump
    LSR
    BCS ContinueSndJump  ; big mario jump
    LSR
    BCS ContinueBumpThrow  ; bump
    LSR
    BCS ContinueSwimStomp  ; swim/stomp
    LSR
    BCS ContinueSmackEnemy  ; smack enemy
    LSR
    BCS ContinuePipeDownInj  ; pipedown/injury
    LSR
    BCS ContinueBumpThrow  ; fireball throw
    LSR
    BCS DecrementSfx1Length  ; slide flagpole
ExS1H:
    RTS

PlaySwimStomp:
    LDA #$0e  ; store length of swim/stomp sound
    STA ram_squ1_sfx_len_counter
    LDY #$9c  ; store reg contents for swim/stomp sound
    LDX #$9e
    LDA #$26
    JSR sub_play_squ1_sfx

ContinueSwimStomp:
    LDY ram_squ1_sfx_len_counter  ; look up reg contents in data section based on
    LDA SwimStompEnvelopeData-1,y  ; length of sound left, used to control sound's
    STA SND_SQUARE1_REG  ; envelope
    CPY #$06
    BNE BranchToDecLength1
    LDA #$9e  ; when the length counts down to a certain point, put this
    STA SND_SQUARE1_REG+2  ; directly into the LSB of square 1's frequency divider

BranchToDecLength1:
    BNE DecrementSfx1Length  ; unconditional branch (regardless of how we got here)

PlaySmackEnemy:
    LDA #$0e  ; store length of smack enemy sound
    LDY #$cb
    LDX #$9f
    STA ram_squ1_sfx_len_counter
    LDA #$28  ; store reg contents for smack enemy sound
    JSR sub_play_squ1_sfx
    BNE DecrementSfx1Length  ; unconditional branch

ContinueSmackEnemy:
    LDY ram_squ1_sfx_len_counter  ; check about halfway through
    CPY #$08
    BNE SmSpc
    LDA #$a0  ; if we're at the about-halfway point, make the second tone
    STA SND_SQUARE1_REG+2  ; in the smack enemy sound
    LDA #$9f
    BNE SmTick
SmSpc:
    LDA #$90  ; this creates spaces in the sound, giving it its distinct noise
SmTick:
    STA SND_SQUARE1_REG

DecrementSfx1Length:
    DEC ram_squ1_sfx_len_counter  ; decrement length of sfx
    BNE ExSfx1

sub_stop_square1_sfx:
    LDX #$00  ; if end of sfx reached, clear buffer
    STX $f1  ; and stop making the sfx
    LDX #$0e
    STX SND_MASTERCTRL_REG
    LDX #$0f
    STX SND_MASTERCTRL_REG
ExSfx1:
    RTS

PlayPipeDownInj:
    LDA #$2f  ; load length of pipedown sound
    STA ram_squ1_sfx_len_counter

ContinuePipeDownInj:
    LDA ram_squ1_sfx_len_counter  ; some bitwise logic, forces the regs
    LSR  ; to be written to only during six specific times
    BCS NoPDwnL  ; during which d3 must be set and d1-0 must be clear
    LSR
    BCS NoPDwnL
    AND #%00000010
    BEQ NoPDwnL
    LDY #$91  ; and this is where it actually gets written in
    LDX #$9a
    LDA #$44
    JSR sub_play_squ1_sfx
NoPDwnL:
    JMP DecrementSfx1Length

; --------------------------------

ExtraLifeFreqData:
    .byte $58, $02, $54, $56, $4e, $44

PowerUpGrabFreqData:
    .byte $4c, $52, $4c, $48, $3e, $36, $3e, $36, $30
    .byte $28, $4a, $50, $4a, $64, $3c, $32, $3c, $32
    .byte $2c, $24, $3a, $64, $3a, $34, $2c, $22, $2c

; residual frequency data
    .byte $22, $1c, $14

PUp_VGrow_FreqData:
    .byte $14, $04, $22, $24, $16, $04, $24, $26  ; used by both
    .byte $18, $04, $26, $28, $1a, $04, $28, $2a
    .byte $1c, $04, $2a, $2c, $1e, $04, $2c, $2e  ; used by vinegrow
    .byte $20, $04, $2e, $30, $22, $04, $30, $32

PlayCoinGrab:
    LDA #$35  ; load length of coin grab sound
    LDX #$8d  ; and part of reg contents
    BNE CGrab_TTickRegL

PlayTimerTick:
    LDA #$06  ; load length of timer tick sound
    LDX #$98  ; and part of reg contents

CGrab_TTickRegL:
    STA ram_squ2_sfx_len_counter
    LDY #$7f  ; load the rest of reg contents
    LDA #$42  ; of coin grab and timer tick sound
    JSR sub_play_squ2_sfx

ContinueCGrabTTick:
    LDA ram_squ2_sfx_len_counter  ; check for time to play second tone yet
    CMP #$30  ; !(WHY?) SND-001 - timer tick shares this path
    BNE N2Tone
    LDA #$54  ; if so, load the tone directly into the reg
    STA SND_SQUARE2_REG+2
N2Tone:
    BNE DecrementSfx2Length

PlayBlast:
    LDA #$20  ; load length of fireworks/gunfire sound
    STA ram_squ2_sfx_len_counter
    LDY #$94  ; load reg contents of fireworks/gunfire sound
    LDA #$5e
    BNE SBlasJ

ContinueBlast:
    LDA ram_squ2_sfx_len_counter  ; check for time to play second part
    CMP #$18
    BNE DecrementSfx2Length
    LDY #$93  ; load second part reg contents then
    LDA #$18
SBlasJ:
    BNE BlstSJp  ; unconditional branch to load rest of reg contents

PlayPowerUpGrab:
    LDA #$36  ; load length of power-up grab sound
    STA ram_squ2_sfx_len_counter

ContinuePowerUpGrab:
    LDA ram_squ2_sfx_len_counter  ; load frequency reg based on length left over
    LSR  ; divide by 2
    BCS DecrementSfx2Length  ; alter frequency every other frame
    TAY
    LDA PowerUpGrabFreqData-1,y  ; use length left over / 2 for frequency offset
    LDX #$5d  ; store reg contents of power-up grab sound
    LDY #$7f

LoadSqu2Regs:
    JSR sub_play_squ2_sfx

DecrementSfx2Length:
    DEC ram_squ2_sfx_len_counter  ; decrement length of sfx
    BNE ExSfx2

EmptySfx2Buffer:
    LDX #$00  ; initialize square 2's sound effects buffer
    STX ram_square2_sound_buffer

sub_stop_square2_sfx:
    LDX #$0d  ; stop playing the sfx
    STX SND_MASTERCTRL_REG
    LDX #$0f
    STX SND_MASTERCTRL_REG
ExSfx2:
    RTS

sub_square2_sfx_handler:
    LDA ram_square2_sound_buffer  ; special handling for the 1-up sound to keep it
    AND #con_sfx_extra_life  ; from being interrupted by other sounds on square 2
    BNE ContinueExtraLife
    LDY ram_square2_sound_queue  ; check for sfx in queue
    BEQ CheckSfx2Buffer
    STY ram_square2_sound_buffer  ; if found, put in buffer and check for the following
    BMI PlayBowserFall  ; bowser fall
    LSR ram_square2_sound_queue
    BCS PlayCoinGrab  ; coin grab
    LSR ram_square2_sound_queue
    BCS PlayGrowPowerUp  ; power-up reveal
    LSR ram_square2_sound_queue
    BCS PlayGrowVine  ; vine grow
    LSR ram_square2_sound_queue
    BCS PlayBlast  ; fireworks/gunfire
    LSR ram_square2_sound_queue
    BCS PlayTimerTick  ; timer tick
    LSR ram_square2_sound_queue
    BCS PlayPowerUpGrab  ; power-up grab
    LSR ram_square2_sound_queue
    BCS PlayExtraLife  ; 1-up

CheckSfx2Buffer:
    LDA ram_square2_sound_buffer  ; check for sfx in buffer
    BEQ ExS2H  ; if not found, exit sub
    BMI ContinueBowserFall  ; bowser fall
    LSR
    BCS Cont_CGrab_TTick  ; coin grab
    LSR
    BCS ContinueGrowItems  ; power-up reveal
    LSR
    BCS ContinueGrowItems  ; vine grow
    LSR
    BCS ContinueBlast  ; fireworks/gunfire
    LSR
    BCS Cont_CGrab_TTick  ; timer tick
    LSR
    BCS ContinuePowerUpGrab  ; power-up grab
    LSR
    BCS ContinueExtraLife  ; 1-up
ExS2H:
    RTS

Cont_CGrab_TTick:
    JMP ContinueCGrabTTick

JumpToDecLength2:
    JMP DecrementSfx2Length

PlayBowserFall:
    LDA #$38  ; load length of bowser defeat sound
    STA ram_squ2_sfx_len_counter
    LDY #$c4  ; load contents of reg for bowser defeat sound
    LDA #$18
BlstSJp:
    BNE PBFRegs

ContinueBowserFall:
    LDA ram_squ2_sfx_len_counter  ; check for almost near the end
    CMP #$08
    BNE DecrementSfx2Length
    LDY #$a4  ; if so, load the rest of reg contents for bowser defeat sound
    LDA #$5a
PBFRegs:
    LDX #$9f  ; the fireworks/gunfire sound shares part of reg contents here
EL_LRegs:
    BNE LoadSqu2Regs  ; this is an unconditional branch outta here

PlayExtraLife:
    LDA #$30  ; load length of 1-up sound
    STA ram_squ2_sfx_len_counter

ContinueExtraLife:
    LDA ram_squ2_sfx_len_counter
    LDX #$03  ; load new tones only every eight frames
DivLLoop:
    LSR
    BCS JumpToDecLength2  ; if any bits set here, branch to dec the length
    DEX
    BNE DivLLoop  ; do this until all bits checked, if none set, continue
    TAY
    LDA ExtraLifeFreqData-1,y  ; load our reg contents
    LDX #$82
    LDY #$7f
    BNE EL_LRegs  ; unconditional branch

PlayGrowPowerUp:
    LDA #$10  ; load length of power-up reveal sound
    BNE GrowItemRegs

PlayGrowVine:
    LDA #$20  ; load length of vine grow sound

GrowItemRegs:
    STA ram_squ2_sfx_len_counter
    LDA #$7f  ; load contents of reg for both sounds directly
    STA SND_SQUARE2_REG+1
    LDA #$00  ; start secondary counter for both sounds
    STA ram_sfx_secondary_counter

ContinueGrowItems:
    INC ram_sfx_secondary_counter  ; increment secondary counter for both sounds
    LDA ram_sfx_secondary_counter  ; this sound doesn't decrement the usual counter
    LSR  ; divide by 2 to get the offset
    TAY
    CPY ram_squ2_sfx_len_counter  ; have we reached the end yet?
    BEQ StopGrowItems  ; if so, branch to jump, and stop playing sounds
    LDA #$9d  ; load contents of other reg directly
    STA SND_SQUARE2_REG
    LDA PUp_VGrow_FreqData,y  ; use secondary counter / 2 as offset for frequency regs
    JSR sub_set_freq_squ2
    RTS

StopGrowItems:
    JMP EmptySfx2Buffer  ; branch to stop playing sounds

; --------------------------------

BrickShatterFreqData:
    .byte $01, $0e, $0e, $0d, $0b, $06, $0c, $0f
    .byte $0a, $09, $03, $0d, $08, $0d, $06, $0c

PlayBrickShatter:
    LDA #$20  ; load length of brick shatter sound
    STA ram_noise_sfx_len_counter

ContinueBrickShatter:
    LDA ram_noise_sfx_len_counter
    LSR  ; divide by 2 and check for bit set to use offset
    BCC DecrementSfx3Length
    TAY
    LDX BrickShatterFreqData,y  ; load reg contents of brick shatter sound
    LDA BrickShatterEnvData,y

PlayNoiseSfx:
    STA SND_NOISE_REG  ; play the sfx
    STX SND_NOISE_REG+2
    LDA #$18
    STA SND_NOISE_REG+3

DecrementSfx3Length:
    DEC ram_noise_sfx_len_counter  ; decrement length of sfx
    BNE ExSfx3
    LDA #$f0  ; if done, stop playing the sfx
    STA SND_NOISE_REG
    LDA #$00
    STA ram_noise_sound_buffer
ExSfx3:
    RTS

sub_noise_sfx_handler:
    LDY ram_noise_sound_queue  ; check for sfx in queue
    BEQ CheckNoiseBuffer
    STY ram_noise_sound_buffer  ; if found, put in buffer
    LSR ram_noise_sound_queue
    BCS PlayBrickShatter  ; brick shatter
    LSR ram_noise_sound_queue
    BCS PlayBowserFlame  ; bowser flame

CheckNoiseBuffer:
    LDA ram_noise_sound_buffer  ; check for sfx in buffer
    BEQ ExNH  ; if not found, exit sub
    LSR
    BCS ContinueBrickShatter  ; brick shatter
    LSR
    BCS ContinueBowserFlame  ; bowser flame
ExNH:
    RTS

PlayBowserFlame:
    LDA #$40  ; load length of bowser flame sound
    STA ram_noise_sfx_len_counter

ContinueBowserFlame:
    LDA ram_noise_sfx_len_counter
    LSR
    TAY
    LDX #$0f  ; load reg contents of bowser flame sound
    LDA BowserFlameEnvData-1,y
    BNE PlayNoiseSfx  ; unconditional branch here
