handler_smb2_data4_upside_down_pipe_high:
    LDA #$01  ; start at second row
    PHA
    BNE bra_smb2_data4_render_upside_down_pipe_body
handler_smb2_data4_upside_down_pipe_low:
    LDA #$04  ; start at fifth row
    PHA
bra_smb2_data4_render_upside_down_pipe_body:
    JSR sub_smb2_main_get_pipe_height  ; get pipe height from object byte
    PLA
    STA $07  ; save buffer offset temporarily
    TYA
    PHA  ; save pipe height temporarily
    LDY AreaObjectLength,x  ; if on second column of pipe, skip this
    BEQ bra_smb2_data4_finish_upside_down_pipe
    JSR sub_smb2_main_find_empty_enemy_slot  ; otherwise try to insert upside-down
    BCS bra_smb2_data4_finish_upside_down_pipe  ; piranha plant, if no empty slots, skip this
    LDA #$04
    JSR sub_smb2_main_setup_piranha_plant  ; set up upside-down piranha plant
    LDA $06
    ASL
    ASL  ; multiply height of pipe by 16
    ASL  ; and add enemy Y position previously set up
    ASL  ; then subtract 10 pixels, save as new Y position
    CLC
    ADC Enemy_Y_Position,x
    SEC
    SBC #$0a
    STA Enemy_Y_Position,x
    STA PiranhaPlantDownYPos,x  ; set as "down" position, which in this case is up
    CLC  ; add 24 pixels, save as "up" position
    ADC #$18  ; note up and down here are reversed
    STA PiranhaPlantUpYPos,x
    INC PiranhaPlant_MoveFlag,x  ; set movement flag
bra_smb2_data4_finish_upside_down_pipe:
    PLA
    TAY  ; return tile offset
    PHA
    LDX $07
    LDA off_smb2_main_vertical_pipe_metatiles+2,y
    LDY $06  ; render the pipe shaft
    DEY
    JSR sub_smb2_main_render_under_part
    PLA
    TAY
    LDA off_smb2_main_vertical_pipe_metatiles,y  ; and render the pipe end
    STA MetatileBuffer,x
    RTS

    RTS  ; unused, nothing jumps here

handler_smb2_data4_move_upside_down_piranha_plant:
    LDA Enemy_State,x  ; check enemy state
    BNE bra_smb2_data4_exit_upside_down_piranha_movement  ; if set at all, branch to leave
    LDA EnemyFrameTimer,x  ; check enemy's timer here
    BNE bra_smb2_data4_exit_upside_down_piranha_movement  ; branch to end if not yet expired
    LDA PiranhaPlant_MoveFlag,x  ; check movement flag
    BNE bra_smb2_data4_select_piranha_plant_limit  ; if moving, skip to part ahead
    LDA PiranhaPlant_Y_Speed,x  ; get vertical speed
    EOR #$ff
    CLC  ; change to two's compliment
    ADC #$01
    STA PiranhaPlant_Y_Speed,x  ; save as new vertical speed
    INC PiranhaPlant_MoveFlag,x  ; increment to set movement flag

bra_smb2_data4_select_piranha_plant_limit:
    LDA PiranhaPlantUpYPos,x  ; get original vertical coordinate (lowest point)
    LDY PiranhaPlant_Y_Speed,x  ; get vertical speed
    BPL bra_smb2_data4_move_piranha_plant  ; branch if moving downwards
    LDA PiranhaPlantDownYPos,x  ; otherwise get other vertical coordinate (highest point)

bra_smb2_data4_move_piranha_plant:
    STA $00  ; save vertical coordinate here
    LDA TimerControl  ; get master timer control
    BNE bra_smb2_data4_exit_upside_down_piranha_movement  ; branch to leave if set (likely not necessary)
    LDA Enemy_Y_Position,x  ; get current vertical coordinate
    CLC
    ADC PiranhaPlant_Y_Speed,x  ; add vertical speed to move up or down
    STA Enemy_Y_Position,x  ; save as new vertical coordinate
    CMP $00  ; compare against low or high coordinate
    BNE bra_smb2_data4_exit_upside_down_piranha_movement  ; branch to leave if not yet reached
    LDA #$00
    STA PiranhaPlant_MoveFlag,x  ; otherwise clear movement flag
    LDA #$20
    STA EnemyFrameTimer,x  ; set timer to delay piranha plant movement
bra_smb2_data4_exit_upside_down_piranha_movement:
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_data4_blow_player_around:
    LDA WindFlag  ; if wind is turned off, just exit
    BEQ bra_smb2_data4_exit_wind_player_push
    LDA AreaType  ; don't blow the player around unless
    CMP #$01  ; the area is ground type
    BNE bra_smb2_data4_exit_wind_player_push
    LDY #$01
    LDA FrameCounter
    ASL
    BCS bra_smb2_data4_gate_wind_push_by_frame
    LDY #$03
bra_smb2_data4_gate_wind_push_by_frame:
    STY $00
    LDA FrameCounter
    AND $00
    BNE bra_smb2_data4_exit_wind_player_push
    LDA Player_X_Position  ; move player slightly to the right
    CLC  ; to simulate the wind moving the player
    ADC #$01
    STA Player_X_Position
    LDA Player_PageLoc
    ADC #$00
    STA Player_PageLoc
    INC Player_X_Scroll  ; add one to movement speed for scroll
bra_smb2_data4_exit_wind_player_push:
    RTS

; note the position data values are overwritten in RAM
tbl_smb2_data4_leaves_y_pos:
    .byte $30, $70, $b8, $50, $98, $30
    .byte $70, $b8, $50, $98, $30, $70

tbl_smb2_data4_leaves_x_pos:
    .byte $30, $30, $30, $60, $60, $a0
    .byte $a0, $a0, $d0, $d0, $d0, $60

tbl_smb2_data4_leaves_tile:
    .byte $7b, $7b, $7b, $7b, $7a, $7a
    .byte $7b, $7b, $7b, $7a, $7b, $7a

sub_smb2_data4_simulate_wind:
    LDA WindFlag  ; if no wind, branch to leave
    BEQ bra_smb2_data4_exit_wind_simulation
    LDA #$04  ; play wind sfx
    STA NoiseSoundQueue
    JSR sub_smb2_data4_modify_leaves_pos  ; modify X and Y position data of leaves
    LDX #$00
    LDY Alt_SprDataOffset-1  ; use first sprite data offset for first six leaves
bra_smb2_data4_draw_wind_leaf:
    LDA tbl_smb2_data4_leaves_y_pos,x
    STA Sprite_Y_Position,y  ; set up sprite data in OAM memory
    LDA tbl_smb2_data4_leaves_tile,x
    STA Sprite_Tilenumber,y
    LDA #$41
    STA Sprite_Attributes,y
    LDA tbl_smb2_data4_leaves_x_pos,x
    STA Sprite_X_Position,y
    INY
    INY
    INY
    INY
    INX
    CPX #$06  ; if still on first six leaves, continue
    BNE bra_smb2_data4_draw_wind_leaves_loop  ; using the first sprite data offset
    LDY Alt_SprDataOffset  ; otherwise use the second one instead
bra_smb2_data4_draw_wind_leaves_loop:
    CPX #$0c  ; continue until done putting twelve leaves on the screen
    BNE bra_smb2_data4_draw_wind_leaf
bra_smb2_data4_exit_wind_simulation:
    RTS

tbl_smb2_data4_leaves_pos_adder:
    .byte $57, $57, $56, $56, $58, $58, $56, $56, $57, $58, $57, $58
    .byte $59, $59, $58, $58, $5a, $5a, $58, $58, $59, $5a, $59, $5a

sub_smb2_data4_modify_leaves_pos:
    LDX #$0b
bra_smb2_data4_update_wind_leaf_positions_loop:
    LDA tbl_smb2_data4_leaves_x_pos,x  ; add each adder to each X position twice
    CLC  ; and to each Y position once
    ADC tbl_smb2_data4_leaves_pos_adder,x
    ADC tbl_smb2_data4_leaves_pos_adder,x
    STA tbl_smb2_data4_leaves_x_pos,x
    LDA tbl_smb2_data4_leaves_y_pos,x
    CLC
    ADC tbl_smb2_data4_leaves_pos_adder,x
    STA tbl_smb2_data4_leaves_y_pos,x
    DEX
    BPL bra_smb2_data4_update_wind_leaf_positions_loop
    RTS

handler_smb2_data4_wind_on:
    LDA #$01  ; branch to turn the wind on
    BNE bra_smb2_data4_store_wind_state
handler_smb2_data4_wind_off:
    LDA #$00  ; turn the wind off
bra_smb2_data4_store_wind_state:
    STA WindFlag
    RTS

; some unused bytes
    .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff

; --------------------------------------------------

; level A-4
