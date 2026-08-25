; -------------------------------------------------------------------------------------
; $00-$01 - used to hold many values, essentially temp variables
; $04 - holds lower nybble of vertical coordinate from block buffer routine
; $eb - used to hold block buffer adder

PlayerBGUpperExtent:
    .byte $20, $10

PlayerBGCollision:
    LDA DisableCollisionDet  ; if collision detection disabled flag set,
    BNE ExPBGCol  ; branch to leave
    LDA GameEngineSubroutine
    CMP #$0b  ; if running routine #11 or $0b
    BEQ ExPBGCol  ; branch to leave
    CMP #$04
    BCC ExPBGCol  ; if running routines $00-$03 branch to leave
    LDA #$01  ; load default player state for swimming
    LDY SwimmingFlag  ; if swimming flag set,
    BNE SetPSte  ; branch ahead to set default state
    LDA Player_State  ; if player in normal state,
    BEQ SetFallS  ; branch to set default state for falling
    CMP #$03
    BNE ChkOnScr  ; if in any other state besides climbing, skip to next part
SetFallS:
    LDA #$02  ; load default player state for falling
SetPSte:
    STA Player_State  ; set whatever player state is appropriate
ChkOnScr:
    LDA Player_Y_HighPos
    CMP #$01  ; check player's vertical high byte for still on the screen
    BNE ExPBGCol  ; branch to leave if not
    LDA #$ff
    STA Player_CollisionBits  ; initialize player's collision flag
    LDA Player_Y_Position
    CMP #$cf  ; check player's vertical coordinate
    BCC ChkCollSize  ; if not too close to the bottom of screen, continue
ExPBGCol:
    RTS  ; otherwise leave

ChkCollSize:
    LDY #$02  ; load default offset
    LDA CrouchingFlag
    BNE GBBAdr  ; if player crouching, skip ahead
    LDA PlayerSize
    BNE GBBAdr  ; if player small, skip ahead
    DEY  ; otherwise decrement offset for big player not crouching
    LDA SwimmingFlag
    BNE GBBAdr  ; if swimming flag set, skip ahead
    DEY  ; otherwise decrement offset
GBBAdr:
    LDA BlockBufferAdderData,y  ; get value using offset
    STA $eb  ; store value here
    TAY  ; put value into Y, as offset for block buffer routine
    LDX PlayerSize  ; get player's size as offset
    LDA CrouchingFlag
    BEQ HeadChk  ; if player not crouching, branch ahead
    INX  ; otherwise increment size as offset
HeadChk:
    LDA Player_Y_Position  ; get player's vertical coordinate
    CMP PlayerBGUpperExtent,x  ; compare with upper extent value based on offset
    BCC DoFootCheck  ; if player is too high, skip this part
    JSR BlockBufferColli_Head  ; do player-to-bg collision detection on top of
    BEQ DoFootCheck  ; player, and branch if nothing above player's head
    JSR CheckForCoinMTiles  ; check to see if player touched coin with their head
    BCS AwardTouchedCoin  ; if so, branch to some other part of code
    LDY Player_Y_Speed  ; check player's vertical speed
    BPL DoFootCheck  ; if player not moving upwards, branch elsewhere
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #$04  ; from collision detection routine
    BCC DoFootCheck  ; if low nybble < 4, branch
    JSR CheckForSolidMTiles  ; check to see what player's head bumped on
    BCS SolidOrClimb  ; if player collided with solid metatile, branch
    LDY AreaType  ; otherwise check area type
    BEQ NYSpd  ; if water level, branch ahead
    LDY BlockBounceTimer  ; if block bounce timer not expired,
    BNE NYSpd  ; branch ahead, do not process collision
    JSR PlayerHeadCollision  ; otherwise do a sub to process collision
    JMP DoFootCheck  ; jump ahead to skip these other parts here

SolidOrClimb:
    CMP #$26  ; if climbing metatile,
    BEQ NYSpd  ; branch ahead and do not play sound
    LDA #Sfx_Bump
    STA Square1SoundQueue  ; otherwise load bump sound
NYSpd:
    LDA #$01  ; set player's vertical speed to nullify
    STA Player_Y_Speed  ; jump or swim

DoFootCheck:
    LDY $eb  ; get block buffer adder offset
    LDA Player_Y_Position
    CMP #$cf  ; check to see how low player is
    BCS DoPlayerSideCheck  ; if player is too far down on screen, skip all of this
    JSR BlockBufferColli_Feet  ; do player-to-bg collision detection on bottom left of player
    JSR CheckForCoinMTiles  ; check to see if player touched coin with their left foot
    BCS AwardTouchedCoin  ; if so, branch to some other part of code
    PHA  ; save bottom left metatile to stack
    JSR BlockBufferColli_Feet  ; do player-to-bg collision detection on bottom right of player
    STA $00  ; save bottom right metatile here
    PLA
    STA $01  ; pull bottom left metatile and save here
    BNE ChkFootMTile  ; if anything here, skip this part
    LDA $00  ; otherwise check for anything in bottom right metatile
    BEQ DoPlayerSideCheck  ; and skip ahead if not
    JSR CheckForCoinMTiles  ; check to see if player touched coin with their right foot
    BCC ChkFootMTile  ; if not, skip unconditional jump and continue code

AwardTouchedCoin:
    JMP HandleCoinMetatile  ; follow the code to erase coin and award to player 1 coin

ChkFootMTile:
    JSR CheckForClimbMTiles  ; check to see if player landed on climbable metatiles
    BCS DoPlayerSideCheck  ; if so, branch
    LDY Player_Y_Speed  ; check player's vertical speed
    BMI DoPlayerSideCheck  ; if player moving upwards, branch
    CMP #$c5
    BNE ContChk  ; if player did not touch axe, skip ahead
    JMP HandleAxeMetatile  ; otherwise jump to set modes of operation
ContChk:
    JSR ChkInvisibleMTiles  ; do sub to check for hidden coin or 1-up blocks
    BEQ DoPlayerSideCheck  ; if either found, branch
    LDY JumpspringAnimCtrl  ; if jumpspring animating right now,
    BNE InitSteP  ; branch ahead
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #$05  ; from collision detection routine
    BCC LandPlyr  ; if lower nybble < 5, branch
    LDA Player_MovingDir
    STA $00  ; use player's moving direction as temp variable
    JMP ImpedePlayerMove  ; jump to impede player's movement in that direction
LandPlyr:
    JSR ChkForLandJumpSpring  ; do sub to check for jumpspring metatiles and deal with it
    LDA #$f0
    AND Player_Y_Position  ; mask out lower nybble of player's vertical position
    STA Player_Y_Position  ; and store as new vertical position to land player properly
    JSR HandlePipeEntry  ; do sub to process potential pipe entry
    LDA #$00
    STA Player_Y_Speed  ; initialize vertical speed and fractional
    STA Player_Y_MoveForce  ; movement force to stop player's vertical movement
    STA StompChainCounter  ; initialize enemy stomp counter
InitSteP:
    LDA #$00
    STA Player_State  ; set player's state to normal

DoPlayerSideCheck:
    LDY $eb  ; get block buffer adder offset
    INY
    INY  ; increment offset 2 bytes to use adders for side collisions
    LDA #$02  ; set value here to be used as counter
    STA $00

SideCheckLoop:
    INY  ; move onto the next one
    STY $eb  ; store it
    LDA Player_Y_Position
    CMP #$20  ; check player's vertical position
    BCC BHalf  ; if player is in status bar area, branch ahead to skip this part
    CMP #$e4
    BCS ExSCH  ; branch to leave if player is too far down
    JSR BlockBufferColli_Side  ; do player-to-bg collision detection on one half of player
    BEQ BHalf  ; branch ahead if nothing found
    CMP #$1c  ; otherwise check for pipe metatiles
    BEQ BHalf  ; if collided with sideways pipe (top), branch ahead
    CMP #$6b
    BEQ BHalf  ; if collided with water pipe (top), branch ahead
    JSR CheckForClimbMTiles  ; do sub to see if player bumped into anything climbable
    BCC CheckSideMTiles  ; if not, branch to alternate section of code
BHalf:
    LDY $eb  ; load block adder offset
    INY  ; increment it
    LDA Player_Y_Position  ; get player's vertical position
    CMP #$08
    BCC ExSCH  ; if too high, branch to leave
    CMP #$d0
    BCS ExSCH  ; if too low, branch to leave
    JSR BlockBufferColli_Side  ; do player-to-bg collision detection on other half of player
    BNE CheckSideMTiles  ; if something found, branch
    DEC $00  ; otherwise decrement counter
    BNE SideCheckLoop  ; run code until both sides of player are checked
ExSCH:
    RTS  ; leave

CheckSideMTiles:
    JSR ChkInvisibleMTiles  ; check for hidden or coin 1-up blocks
    BEQ ExCSM  ; branch to leave if either found
    JSR CheckForClimbMTiles  ; check for climbable metatiles
    BCC ContSChk  ; if not found, skip and continue with code
    JMP HandleClimbing  ; otherwise jump to handle climbing
ContSChk:
    JSR CheckForCoinMTiles  ; check to see if player touched coin
    BCS HandleCoinMetatile  ; if so, execute code to erase coin and award to player 1 coin
    JSR ChkJumpspringMetatiles  ; check for jumpspring metatiles
    BCC ChkPBtm  ; if not found, branch ahead to continue cude
    LDA JumpspringAnimCtrl  ; otherwise check jumpspring animation control
    BNE ExCSM  ; branch to leave if set
    JMP StopPlayerMove  ; otherwise jump to impede player's movement
ChkPBtm:
    LDY Player_State  ; get player's state
    CPY #$00  ; check for player's state set to normal
    BNE StopPlayerMove  ; if not, branch to impede player's movement
    LDY PlayerFacingDir  ; get player's facing direction
    DEY
    BNE StopPlayerMove  ; if facing left, branch to impede movement
    CMP #$6c  ; otherwise check for pipe metatiles
    BEQ PipeDwnS  ; if collided with sideways pipe (bottom), branch
    CMP #$1f  ; if collided with water pipe (bottom), continue
    BNE StopPlayerMove  ; otherwise branch to impede player's movement
PipeDwnS:
    LDA Player_SprAttrib  ; check player's attributes
    BNE PlyrPipe  ; if already set, branch, do not play sound again
    LDY #Sfx_PipeDown_Injury
    STY Square1SoundQueue  ; otherwise load pipedown/injury sound
PlyrPipe:
    ORA #%00100000
    STA Player_SprAttrib  ; set background priority bit in player attributes
    LDA Player_X_Position
    AND #%00001111  ; get lower nybble of player's horizontal coordinate
    BEQ ChkGERtn  ; if at zero, branch ahead to skip this part
    LDY #$00  ; set default offset for timer setting data
    LDA ScreenLeft_PageLoc  ; load page location for left side of screen
    BEQ SetCATmr  ; if at page zero, use default offset
    INY  ; otherwise increment offset
SetCATmr:
    LDA AreaChangeTimerData,y  ; set timer for change of area as appropriate
    STA ChangeAreaTimer
ChkGERtn:
    LDA GameEngineSubroutine  ; get number of game engine routine running
    CMP #$07
    BEQ ExCSM  ; if running player entrance routine or
    CMP #$08  ; player control routine, go ahead and branch to leave
    BNE ExCSM
    LDA #$02
    STA GameEngineSubroutine  ; otherwise set sideways pipe entry routine to run
    RTS  ; and leave

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

StopPlayerMove:
    JSR ImpedePlayerMove  ; stop player's movement
ExCSM:
    RTS  ; leave

AreaChangeTimerData:
    .byte $a0, $34

HandleCoinMetatile:
    JSR ErACM  ; do sub to erase coin metatile from block buffer
    INC CoinTallyFor1Ups  ; increment coin tally used for 1-up blocks
    JMP GiveOneCoin  ; update coin amount and tally on the screen

HandleAxeMetatile:
    LDA #$00
    STA OperMode_Task  ; reset secondary mode
    LDA #$02
    STA OperMode  ; set primary mode to autoctrl mode
    LDA #$18
    STA Player_X_Speed  ; set horizontal speed and continue to erase axe metatile
ErACM:
    LDY $02  ; load vertical high nybble offset for block buffer
    LDA #$00  ; load blank metatile
    STA ($06),y  ; store to remove old contents from block buffer
    JMP RemoveCoin_Axe  ; update the screen accordingly

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

ClimbXPosAdder:
    .byte $f9, $07

ClimbPLocAdder:
    .byte $ff, $00

FlagpoleYPosData:
    .byte $18, $22, $50, $68, $90

HandleClimbing:
    LDY $04  ; check low nybble of horizontal coordinate returned from
    CPY #$06  ; collision detection routine against certain values, this
    BCC ExHC  ; makes actual physical part of vine or flagpole thinner
    CPY #$0a  ; than 16 pixels
    BCC ChkForFlagpole
ExHC:
    RTS  ; leave if too far left or too far right

ChkForFlagpole:
    CMP #$24  ; check climbing metatiles
    BEQ FlagpoleCollision  ; branch if flagpole ball found
    CMP #$25
    BNE VineCollision  ; branch to alternate code if flagpole shaft not found

FlagpoleCollision:
    LDA GameEngineSubroutine
    CMP #$05  ; check for end-of-level routine running
    BEQ PutPlayerOnVine  ; if running, branch to end of climbing code
    LDA #$01
    STA PlayerFacingDir  ; set player's facing direction to right
    INC ScrollLock  ; set scroll lock flag
    LDA GameEngineSubroutine
    CMP #$04  ; check for flagpole slide routine running
    BEQ RunFR  ; if running, branch to end of flagpole code here
    LDA #BulletBill_CannonVar  ; load identifier for bullet bills (cannon variant)
    JSR KillEnemies  ; get rid of them
    LDA #Silence
    STA EventMusicQueue  ; silence music
    LSR
    STA FlagpoleSoundQueue  ; load flagpole sound into flagpole sound queue
    LDX #$04  ; start at end of vertical coordinate data
    LDA Player_Y_Position
    STA FlagpoleCollisionYPos  ; store player's vertical coordinate here to be used later

ChkFlagpoleYPosLoop:
    CMP FlagpoleYPosData,x  ; compare with current vertical coordinate data
    BCS MtchF  ; if player's => current, branch to use current offset
    DEX  ; otherwise decrement offset to use
    BNE ChkFlagpoleYPosLoop  ; do this until all data is checked (use last one if all checked)
MtchF:
    STX FlagpoleScore  ; store offset here to be used later
RunFR:
    LDA #$04
    STA GameEngineSubroutine  ; set value to run flagpole slide routine
    JMP PutPlayerOnVine  ; jump to end of climbing code

VineCollision:
    CMP #$26  ; check for climbing metatile used on vines
    BNE PutPlayerOnVine
    LDA Player_Y_Position  ; check player's vertical coordinate
    CMP #$20  ; for being in status bar area
    BCS PutPlayerOnVine  ; branch if not that far up
    LDA #$01
    STA GameEngineSubroutine  ; otherwise set to run autoclimb routine next frame

PutPlayerOnVine:
    LDA #$03  ; set player state to climbing
    STA Player_State
    LDA #$00  ; nullify player's horizontal speed
    STA Player_X_Speed  ; and fractional horizontal movement force
    STA Player_X_MoveForce
    LDA Player_X_Position  ; get player's horizontal coordinate
    SEC
    SBC ScreenLeft_X_Pos  ; subtract from left side horizontal coordinate
    CMP #$10
    BCS SetVXPl  ; if 16 or more pixels difference, do not alter facing direction
    LDA #$02
    STA PlayerFacingDir  ; otherwise force player to face left
SetVXPl:
    LDY PlayerFacingDir  ; get current facing direction, use as offset
    LDA $06  ; get low byte of block buffer address
    ASL
    ASL  ; move low nybble to high
    ASL
    ASL
    CLC
    ADC ClimbXPosAdder-1,y  ; add pixels depending on facing direction
    STA Player_X_Position  ; store as player's horizontal coordinate
    LDA $06  ; get low byte of block buffer address again
    BNE ExPVne  ; if not zero, branch
    LDA ScreenRight_PageLoc  ; load page location of right side of screen
    CLC
    ADC ClimbPLocAdder-1,y  ; add depending on facing location
    STA Player_PageLoc  ; store as player's page location
ExPVne:
    RTS  ; finally, we're done!

; --------------------------------

ChkInvisibleMTiles:
    CMP #$5f  ; check for hidden coin block
    BEQ ExCInvT  ; branch to leave if found
    CMP #$60  ; check for hidden 1-up block
ExCInvT:
    RTS  ; leave with zero flag set if either found

; --------------------------------
; $00-$01 - used to hold bottom right and bottom left metatiles (in that order)
; $00 - used as flag by ImpedePlayerMove to restrict specific movement

ChkForLandJumpSpring:
    JSR ChkJumpspringMetatiles  ; do sub to check if player landed on jumpspring
    BCC ExCJSp  ; if carry not set, jumpspring not found, therefore leave
    LDA #$70
    STA VerticalForce  ; otherwise set vertical movement force for player
    LDA #$f9
    STA JumpspringForce  ; set default jumpspring force
    LDA #$03
    STA JumpspringTimer  ; set jumpspring timer to be used later
    LSR
    STA JumpspringAnimCtrl  ; set jumpspring animation control to start animating
ExCJSp:
    RTS  ; and leave

ChkJumpspringMetatiles:
    CMP #$67  ; check for top jumpspring metatile
    BEQ JSFnd  ; branch to set carry if found
    CMP #$68  ; check for bottom jumpspring metatile
    CLC  ; clear carry flag
    BNE NoJSFnd  ; branch to use cleared carry if not found
JSFnd:
    SEC  ; set carry if found
NoJSFnd:
    RTS  ; leave

HandlePipeEntry:
    LDA Up_Down_Buttons  ; check saved controller bits from earlier
    AND #%00000100  ; for pressing down
    BEQ ExPipeE  ; if not pressing down, branch to leave
    LDA $00
    CMP #$11  ; check right foot metatile for warp pipe right metatile
    BNE ExPipeE  ; branch to leave if not found
    LDA $01
    CMP #$10  ; check left foot metatile for warp pipe left metatile
    BNE ExPipeE  ; branch to leave if not found
    LDA #$30
    STA ChangeAreaTimer  ; set timer for change of area
    LDA #$03
    STA GameEngineSubroutine  ; set to run vertical pipe entry routine on next frame
    LDA #Sfx_PipeDown_Injury
    STA Square1SoundQueue  ; load pipedown/injury sound
    LDA #%00100000
    STA Player_SprAttrib  ; set background priority bit in player's attributes
    LDA WarpZoneControl  ; check warp zone control
    BEQ ExPipeE  ; branch to leave if none found
    AND #%00000011  ; mask out all but 2 LSB
    ASL
    ASL  ; multiply by four
    TAX  ; save as offset to warp zone numbers (starts at left pipe)
    LDA Player_X_Position  ; get player's horizontal position
    CMP #$60
    BCC GetWNum  ; if player at left, not near middle, use offset and skip ahead
    INX  ; otherwise increment for middle pipe
    CMP #$a0
    BCC GetWNum  ; if player at middle, but not too far right, use offset and skip
    INX  ; otherwise increment for last pipe
GetWNum:
    LDY WarpZoneNumbers,x  ; get warp zone numbers
    DEY  ; decrement for use as world number
    STY WorldNumber  ; store as world number and offset
    LDX WorldAddrOffsets,y  ; get offset to where this world's area offsets are
    LDA AreaAddrOffsets,x  ; get area offset based on world offset
    STA AreaPointer  ; store area offset here to be used to change areas
    LDA #Silence
    STA EventMusicQueue  ; silence music
    LDA #$00
    STA EntrancePage  ; initialize starting page number
    STA AreaNumber  ; initialize area number used for area address offset
    STA LevelNumber  ; initialize level number used for world display
    STA AltEntranceControl  ; initialize mode of entry
    INC Hidden1UpFlag  ; set flag for hidden 1-up blocks
    INC FetchNewGameTimerFlag  ; set flag to load new game timer
ExPipeE:
    RTS  ; leave!!!

ImpedePlayerMove:
    LDA #$00  ; initialize value here
    LDY Player_X_Speed  ; get player's horizontal speed
    LDX $00  ; check value set earlier for
    DEX  ; left side collision
    BNE RImpd  ; if right side collision, skip this part
    INX  ; return value to X
    CPY #$00  ; if player moving to the left,
    BMI ExIPM  ; branch to invert bit and leave
    LDA #$ff  ; otherwise load A with value to be used later
    JMP NXSpd  ; and jump to affect movement
RImpd:
    LDX #$02  ; return $02 to X
    CPY #$01  ; if player moving to the right,
    BPL ExIPM  ; branch to invert bit and leave
    LDA #$01  ; otherwise load A with value to be used here
NXSpd:
    LDY #$10
    STY SideCollisionTimer  ; set timer of some sort
    LDY #$00
    STY Player_X_Speed  ; nullify player's horizontal speed
    CMP #$00  ; if value set in A not set to $ff,
    BPL PlatF  ; branch ahead, do not decrement Y
    DEY  ; otherwise decrement Y now
PlatF:
    STY $00  ; store Y as high bits of horizontal adder
    CLC
    ADC Player_X_Position  ; add contents of A to player's horizontal
    STA Player_X_Position  ; position to move player left or right
    LDA Player_PageLoc
    ADC $00  ; add high bits and carry to
    STA Player_PageLoc  ; page location if necessary
ExIPM:
    TXA  ; invert contents of X
    EOR #$ff
    AND Player_CollisionBits  ; mask out bit that was set here
    STA Player_CollisionBits  ; store to clear bit
    RTS

; --------------------------------

SolidMTileUpperExt:
    .byte $10, $61, $88, $c4

CheckForSolidMTiles:
    JSR GetMTileAttrib  ; find appropriate offset based on metatile's 2 MSB
    CMP SolidMTileUpperExt,x  ; compare current metatile with solid metatiles
    RTS

ClimbMTileUpperExt:
    .byte $24, $6d, $8a, $c6

CheckForClimbMTiles:
    JSR GetMTileAttrib  ; find appropriate offset based on metatile's 2 MSB
    CMP ClimbMTileUpperExt,x  ; compare current metatile with climbable metatiles
    RTS

CheckForCoinMTiles:
    CMP #$c2  ; check for regular coin
    BEQ CoinSd  ; branch if found
    CMP #$c3  ; check for underwater coin
    BEQ CoinSd  ; branch if found
    CLC  ; otherwise clear carry and leave
    RTS
CoinSd:
    LDA #Sfx_CoinGrab
    STA Square2SoundQueue  ; load coin grab sound and leave
    RTS

GetMTileAttrib:
    TAY  ; save metatile value into Y
    AND #%11000000  ; mask out all but 2 MSB
    ASL
    ROL  ; shift and rotate d7-d6 to d1-d0
    ROL
    TAX  ; use as offset for metatile data
    TYA  ; get original metatile value back
ExEBG:
    RTS  ; leave
