;This file holds defines for Mario Bros. Disassembly. Both RAM adresses and (values, but there's non currently).
;Also WIP

;RAM Adresses

Reg2000BitStorage = $09				;contains bits to be enabled/disabled for register $2000
Reg2001BitStorage = $0A				;contains bits to be enabled/disabled for register $2001

CameraPosY = $0B				;current camera position
CameraPosX = $0C				;

EntityDataPointer = $14				;2 bytes, used by entities for indirect addressing. used for other indirect thingies also

;$16-$17 - unused

;Controller addresses. Format: ABetUDLR, A = A button, B = B button, e = select, t = start, U = Up, D = Down, L = Left, R = Right.
;Do note that InputPress only resets A and B bits after press.

ControllerInputHolding = $18			;base adress for both controllers (indexed)
ControllerInputPress = $19			;same as above but for presses

Controller1InputHolding = $18			;controller input bits for player 1, holding.
Controller1InputPress = $19			;controller input bits for player 1, press.

Controller2InputHolding = $1A			;controller input bits for player 2, holding.
Controller2InputPress = $1B			;controller input bits for player 2, press.

;1C-1F - used for misc. stuff, often for pointers

FrameFlag = $20					;indicates that a frame has passed

BufferDrawFlag = $21				;flag used to tell the game if we're supposed to draw tiles stored in buffer

NMI_FunctionsEnableFlag = $22			;flag used to prevent NMI routines from running in case it occures during lag. True - run NMI functions, False - don't run NMI functions

InterruptedFlag = $23				;Used to determine if game got interrupted with Non-maskable interrupt. one routine specifically waits for NMI and will end waiting after it happens

;$24 and $25 - unused

Pause_HeldPressed = $26				;this address reacts to pause being pressed/held. used to prevent pause switching every frame when pause is held.
FireballSpawnTiming_Timer = $27			;when this timer reaches a certain amount, timers for fireball spawns will decrease
TitleScreen_SelectHeldFlag = $28		;
Cursor_Option = $29				;selected option

TimerBase = $2A					;base address
TimingTimer = $2A				;timer used to decrease other timers.

TimerBase2 = $2B				;this one doesn't include $2A
GeneralTimer2B = $2B				;used as timer for various things, for example as timer for bonus end, for each coin display, multiplication display and perfect/no bonus message and for unpause
ShakeTimer = $2C				;timer used for screen shaking when POW block is hit
TransitionTimer = $2D				;used mostly for transitions, specifically, how long it takes before starting new phase after last enemy falls offscreen, timer before transitioning to bonus end and from it and for transition to demo mode.
PipeDelayTimer = $2E				;used for sprites coming out of pipes. when timer's zero, sprite comes out of pipe fully.

FrameCounter = $2F				;Self-explanatory, increments every frame.

DemoFlag = $30					;flag set when demo plays

PhaseLoad_PropIndex = $31			;used to get initial properties, such as PlatformTileOffset and enemy level.
PlatformTileOffset = $32			;this is used for platform tile offset, to get platform tile from VRAMTile_PlatformBase (depending on phase)
EnemyLevel = $34				;enemy level, used to load enemies depending on current phase. for more details see DATA_F3BA

TwoPlayerModeFlag = $39				;this flag is used to check wether player's in 2P mode for score display

GameAorBFlag = $3A				;self explanatory, set if player chose game B
GameplayModeNext = $3B				;game mode that goes next after execution

PaletteFlag = $3F				;Wether or not game should update palette, and which palette to use. $00 - Don't update, keep current palette, $01 - Gameplay Palette, anything else - Title Screen Palette.

GameplayMode = $40				;used for pointers to handle various gameplay aspects, such as (un)pausing, proceeding to next phase, coin counting after "Test Your Skill" and other.

DisplayLevelNum = $41				;rename to CurrentPhase? i mean it IS used for display but also checked, so maybe it's global
CurrentPhase = $41

LastEnemyFlag = $46				;if set, we have the last enemy to defeat to proceed to the next phase

PlayerLives = $48				;base address for lives (indexed)
PlayerZeroLivesFlag = $48			;also base address (also indexed)

Player1Lives = $48
Player1TriggerGameOverFlag = $49 		;set to 1 if dying with 0 lives, triggering game over (if set, dying/winning triggers game over)
Player1GameOverFlag = $4A

Player2Lives = $4C
Player2TriggerGameOverFlag = $4D
Player2GameOverFlag = $4E

NonGameplayMode = $50				;this is used for modes without player's gameplay (title screen, demo)

DisableControlFlag = $51			;used to disable control for both players (and freeze in place)

TitleScreen_DemoCount = $52			;how many times the demo must play for music to start playing again on the title screen

Player_Got1UPFlag_SoundFlag = $54		;this is used to play a sound effect for 1-up in case we're transitioning to delay it, isn't player specific

Demo_InputIndex_P1 = $55			;\player 1
Demo_InputTimer_P1 = $56			;/
Demo_InputIndex_P2 = $57			;\player 2
Demo_InputTimer_P2 = $58			;/

TimerBackup = $5A				;stores backups of timers $2A-$2E, 5 bytes

POWHitsLeft = $70
POWPowerTimer = $71				;timer set when POW is hit, to run hit interaction with everything on-screen. 
POWWhoHit = $72					;contains entity ID of which player hit the block (to count score for each enemy affected by POW)

;$74-$7D are bump block variables. the VRAM position and other values are stored here when the platform is bumped.
;5 bytes per player, with first 5 being for Mario.
;$74 and $79 seem to be unused, they're always set to 0 and aren't checked. 
;$75 and $7A are bump tile graphic offset, used to determine wether the bump has occured and which graphic to use
;$76 and $7B are used as bump animation 
;$77-78 and $7C-7D are bump tiles VRAM position, top-left tile of either 2x2 or 3x2 bump area
BumpBlockVars = $74

;$7E-$83 - unused

;$84-$8B are used for bumping platforms for entity interaction.
;$84 and $89 are flags to indicate that we've bumped a platform
;$85 and $8A store which platform we've bumped
;$86 and $8B store where the impact have occured.
BumpEntityVars = $84

;$87 and $88 are unused

;$90 is probably used but idk what its for, same for 94 and 98
;but for what?
ScoreAddress = $90				;base address that gets offsetted to get other score addresses
HighScore = $91					;3 bytes. All score addresses have following format: First byte is tens and hundred thousands, secon is thousands and hundreds, and third byte is tens and ones.
PlayerScoreAddress = $94			;the same as ScoreAddress but for players only
Player1Score = $95				;3 bytes
Player2Score = $99				;3 bytes

PlayerScoreUpdate = $9D				;base address
Player1ScoreUpdate = PlayerScoreUpdate
Player2ScoreUpdate = PlayerScoreUpdate+1	;seems to be another flag for score display for player 2, except this doesn't handle "II" tile on screen.
PlayerPOWScoreUpdate = $9F			;used to enable score update flag for the player who hit the POW (contains index for above 2 addresses). sometimes used as a scratch ram also.

Player1_Got1UPFlag = $AD			;a flag for wether the player has gotten a 1-up by obtaining a certain amoutnt of score
Player2_Got1UPFlag = $AE			;same but for player 2

CurrentEntity_ActiveFlag = $B0			;flag for current entity wether it exists or not
;CurrentEntity_MovementBits = $B1		;used to idicate various movement states
CurrentEntity_Bits = $B1			;bits used for various entities for various purposes. some enemies use bits 0 and 1 for movement direction (bit 0 - move right, bit 1 - move left)
CurrentEntity_Timer = $B3			;general entity timer used for various things
CurrentEntity_AnimationPointer = $B4		;used to animate by pointing to a CurrentEntity_DrawTile in a table (when FF, it loops to the first value of the animation)
CurrentEntity_DrawMode = $B5			;how to draw entity
CurrentEntity_DrawTile = $B6			;first sprite tile it's drawing (rename to GFX frame?)
CurrentEntity_TileProps = $B7			;I think it's about right
CurrentEntity_YPos = $B8
CurrentEntity_XPos = $B9
CurrentEntity_OAMOffset = $BA
;BB is most definitely a timer for things (animation)
;$BC-$BD - some kinda pointer...
CurrentEntity_CurrentPlatform = $BE
CurrentEntity_ID = $BF
;C0 - some kinda bits, one of those bits indicate wether the enemy can be kicked
;$C1 - misc entity ram?
;CurrentEntity_MovementTimer = $C2		;some kinda of timer, i think (maybe misc ram, not necessarily a timer)
;C3
;CurrentEntity_Misc = $C4			;used for various purposes depending on current entity. for player character, this is used as a counter for skidding when moving horizontally, increments up to 2. 0 - start slow, 1 - move but no skid when turning, 02 - skid when turning
CurrentEntity_XSpeed = $C5
CurrentEntity_State = $C6
;C9 - Used by player entities to calculate current 8x8 VRAM position their top-right sprite tile is at (also below)
;CA - high byte for above
CurrentEntity_HitBoxYPos = $CE
CurrentEntity_HitBoxXPos = $CF

;$D0-$EF - Unused

;Sound addresses
Sound_MusicDataPointer = $F7			;2 bytes, indirect addressing

;those are bitwise, each sound/sound is it's own bit.
Sound_Base = Sound_Loop				;used as a base address for sound addresses 
Sound_Loop = $FC				;some looping sounds
Sound_Jingle = $FD				;various jingles
Sound_Effect = $FE				;sound effects
Sound_Effect2 = $FF				;more sound effects

Entity_Address = $0300				;from $0300 to $460 are used for enities, each using $20 bytes.

;Luigi is entity ID 2 (ID 0 doesn't mean anything)
Entity_Luigi_AnimationPointer = $0324
Entity_Luigi_DrawMode = $0325
Entity_Luigi_DrawTile = $0326
;...
Entity_Luigi_XPos = $0329
Entity_Luigi_OAMOffset = $032A


TESTYOURSKILL_Flag = $04B0			;this flag is used to tell wether the phase we're loading is a TEST YOUR SKILL one
BonusTimeSecs = $04B1
BonusTimeMilliSecs = $04B2

BonusTimeMilliSecs_Timing = $04B3		;how many frames does it take to decrease number of milliseconds

TESTYOURSKILL_CoinCountPointer = $04B4		;coin count state after time runs out/all coins are collected
Player1BonusCoins = $04B5
Player2BonusCoins = $04B6

TESTYOURSKILL_CoinCountSubPointer = $04BA	;a subpointer for some TESTYOURSKILL_CoinCountPointer pointers
BonusCoins_TotalCollected = $04BB

ReflectingFireball_MainCodeFlag = $04BF		;if 0, the fireball is initialized

FreezieCanAppearFlag = $04C0			;if set, freezies start to show up

FreezePlatformFlag = $04C5			;if on, the platform becomes frozen
FreezePlatformPointer_Offset = $04C6		;current offset for "platform freeze pointer" pointer
FreezePlatform_UpdateFlag = $04C7		;used to update platform tiles and attributes so the platforms look like they're frozen
FreezePlatformPointer = $04C8			;2 bytes, contains pointer for platform freezing, where to spawn tiles and stuff
FreezePlatformTimer = $04CA			;how long does it take to freeze a part of the platform?

Combo_Timer = $04D0				;combo variables for when kicking enemies, for mario and luigi each has a pair
Combo_Value = $04D1
;Combo_Timer+2 and Combo_Value+2 are for luigi

Score_Slot = $04D5				;contains OAM slot for score sprite (either 0 or 8)
Score_Timer = $04D6				;2 bytes

GameOverStringTimer = $04F0
TESTYOURSKILLStringTimer = $04F0		;uses the same adress as above, which, to be fair, isn't needed in TEST YOUR SKILL phases (you can't get game over there)
PhaseStringTimer = $04F1			;for how long PHASE X string will be shown on string

WaveFireball_SpawnTimer = $04F3

ReflectingFireball_SpawnTimer = $04FC

ReflectingFireball_Timer = $04FF		;how long the fireball should stay on screen
RandomNumberStorage = $0500

;secondary buffer for tiles, that transfers values into a main buffer. used for bump tiles animation and some strings.
BufferOffset2 = $0540				;now that I think of it this isn't used as offset the same way as common buffer. in fact, it can have just draw size and stuff (e.g. draw a 3x2 image)
BufferAddr2 = $0541				;

BufferOffset = $0590				;used to offset buffer position
BufferAddr = $0591				;buffer for tile drawing of unknown size.

;$05FF - some sort of "disable control flag" that's set when players collide with each other?

Sound_JinglePlayingFlag = $06A2			;indicates if there's a jingle playing at the moment
Sound_CurrentJingleID = $06F2			;indicates ID of the current jingle that's playing (detoned by bit number)

;OAM base ram addresses
OAM_Y = $0200
OAM_Tile = $0201
OAM_Prop = $0202
OAM_X = $0203

;OAM addresses for various objects
Cursor_OAM_Y = OAM_Y+(4*Cursor_OAM_Slot)
Cursor_OAM_Tile = OAM_Tile+(4*Cursor_OAM_Slot)
Cursor_OAM_Prop = OAM_Prop+(4*Cursor_OAM_Slot)
Cursor_OAM_X = OAM_X+(4*Cursor_OAM_Slot)

Freezie_Explosion_OAM_Y = OAM_Y+(4*Freezie_Explosion_OAM_Slot)
Freezie_Explosion_OAM_Tile = OAM_Tile+(4*Freezie_Explosion_OAM_Slot)
Freezie_Explosion_OAM_Prop = OAM_Prop+(4*Freezie_Explosion_OAM_Slot)
Freezie_Explosion_OAM_X = OAM_X+(4*Freezie_Explosion_OAM_Slot)

FreezeEffect_OAM_Y = OAM_Y+(4*FreezeEffect_OAM_Slot)
FreezeEffect_OAM_Tile = OAM_Tile+(4*FreezeEffect_OAM_Slot)
FreezeEffect_OAM_Prop = OAM_Prop+(4*FreezeEffect_OAM_Slot)
FreezeEffect_OAM_X = OAM_X+(4*FreezeEffect_OAM_Slot)

Lives_OAM_Y = OAM_Y+(4*Lives_OAM_Slot)
Lives_OAM_Tile = OAM_Tile+(4*Lives_OAM_Slot)
Lives_OAM_Prop = OAM_Prop+(4*Lives_OAM_Slot)
Lives_OAM_X = OAM_X+(4*Lives_OAM_Slot)

Score_OAM_Y = OAM_Y+(4*Score_OAM_Slot)
Score_OAM_Tile = OAM_Tile+(4*Score_OAM_Slot)
Score_OAM_Prop = OAM_Prop+(4*Score_OAM_Slot)
Score_OAM_X = OAM_X+(4*Score_OAM_Slot)

RespawnPlatform_OAM_Y = OAM_Y+(4*RespawnPlatform_OAM_Slot)
RespawnPlatform_OAM_Tile = OAM_Tile+(4*RespawnPlatform_OAM_Slot)
RespawnPlatform_OAM_Prop = OAM_Prop+(4*RespawnPlatform_OAM_Slot)
RespawnPlatform_OAM_X = OAM_X+(4*RespawnPlatform_OAM_Slot)

BonusCoinCount_OAM_Y = OAM_Y+(4*BonusCoinCount_OAM_Slot)
BonusCoinCount_OAM_Tile = OAM_Tile+(4*BonusCoinCount_OAM_Slot)
BonusCoinCount_OAM_Prop = OAM_Prop+(4*BonusCoinCount_OAM_Slot)
BonusCoinCount_OAM_X = OAM_X+(4*BonusCoinCount_OAM_Slot)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;NES Hardware Registers

ControlBits = $2000
RenderBits = $2001
HardwareStatus = $2002
OAMAddress = $2003

VRAMRenderAreaReg = $2005			;write twice to point to to where the screen should point at (used to show things on screen and screen scrolling)
VRAMPointerReg = $2006				;write twice to point to address in VRAM to update
VRAMUpdateRegister = $2007			;write value to update VRAM address with

;sound regs are to be added...

OAMDMA = $4014

APU_SoundChannels = $4015
ControllerReg = $4016
APU_FrameCounter = $4017

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Constants

;VRAM Write routine values, used as commands
VRAMWriteCommand_Repeat = $40			;bit 6 will make repeat writes of one value
VRAMWriteCommand_DrawVert = $80			;bit 7 - change drawing from horizontal line to vertical
VRAMWriteCommand_Stop = $00			;command to stop VRAM write and return from routine.

;controller input constants
Input_A = $80
Input_Select = $20
Input_Start = $10
Input_Up = $08
Input_Down = $04
Input_Left = $02
Input_Right = $01

;Sound values
;$FC
Sound_Loop_Timer = $04				;from TEST YOUR SKILL
Sound_Loop_Fireball = $08

;$FD
Sound_Jingle_GameStart = $01			;plays when starting the game from phase 1
Sound_Jingle_PhaseStart = $02			;plays when proceeding to the next phase
Sound_Jingle_PERFECT = $04			;plays after "Test Your Skill" if got "perfect!!"
Sound_Jingle_Pause = $08			;plays when pausing the game (and when gaining an extra life, apparently)
Sound_Jingle_PlayerReappear = $10		;plays after lost life and appearing on a platform at the top of the screen
Sound_Jingle_CoinCount = $20			;plays when counting coins after "Test Your Skill"
Sound_Jingle_GameOver = $40			;silent?
Sound_Jingle_TitleScreen = $80			;title screen theme

;$FE
Sound_Effect_DestroyedFreezie = $01
Sound_Effect_CollectedCoin = $02
Sound_Effect_FreezieExplode = $04		;when about to make icy surface
Sound_Effect_CoinPipeExit = $08			;
Sound_Effect_ShellCreeperPipeExit = $10
Sound_Effect_SidestepperPipeExit = $20
Sound_Effect_FighterFlyPipeExit = $40
Sound_Effect_Splash = $80			;when something reaches the bottom of the screen and spawns splash effect.

;$FF
Sound_Effect2_PlayerDead = $01
Sound_Effect2_POWBump = $02
Sound_Effect2_LastEnemyDead = $04		;after kicking last enemy
Sound_Effect2_EnemyKicked = $08
Sound_Effect2_EnemyHit = $10			;when hitting platform from below
Sound_Effect2_Jump = $20
Sound_Effect2_Turning = $40
Sound_Effect2_Step = $80			;when player moves around, sound changes slightly every frame

;used by demo screen
Demo_EndCommand = $AA

;Entity addresses' values
;those are most likely shared like moving for players and other entities are the same.
;$B1
Entity_MovementBits_MovingRight = $01
Entity_MovementBits_MovingLeft = $02
Entity_MovementBits_Skidding = $04		;probably exclusive to players
Entity_MovementBits_CantMove = $08		;used by players when they're squished
Entity_MovementBits_Fall = $40
Entity_MovementBits_Jump = $80			;used by mario and fighterflies

;$B4
GFX_AnimationCycle_PlayerWalking = $00
GFX_AnimationCycle_SidestepperAngry = $1A

;$B5
Entity_Draw_16x24 = 0				;used by mario and luigi
Entity_Draw_16x16 = 1				;used by coin effect (kinda popping effect that looks 16x16) and players when squished
Entity_Draw_8x16_AnimFlicker = 2		;this is used by by sidestepper, top tile flickers
Entity_Draw_8x16_FlickerTop = 3			;used by sidesteppers and fighterflies, they change top tile position every frame. (TO-DO: RENAME, not exactly accurate, at least in that it's not used by fighter flies)
Entity_Draw_8x16_FlickerBottom = 4		;used by sidesteppers when flipped over, same as above, but it's the bottom tile that flickers
Entity_Draw_8x16 = 5				;8x16. used by coins, freezies and other effects
Entity_Draw_8x16_Shift = 6			;8x16 but the top tile is slightly shifter horizontally. used by Shellcreepers
Entity_Draw_8x8 = 7				;should be obvious, used for fireballs and various effects

;Entity graphics (first tile for each, after which +1 is added for others)
;$B6
GFX_Player_Walk1 = $06
GFX_Player_Walk2 = $0C
GFX_Player_Walk3 = $00
GFX_Player_Standing = $12			;still
GFX_Player_Jumping = $18

GFX_Player_Squish1 = $1E			;one player's too heavy for another
GFX_Player_Squish2 = $22

GFX_Player_Skid1 = $26
GFX_Player_Skid2 = $2C
GFX_Player_Hurt = $32

GFX_Shellcreeper_Walk1 = $52
GFX_Shellcreeper_Walk2 = $54
GFX_Shellcreeper_Walk3 = $56

GFX_Shellcreeper_Flipped1 = $58

GFX_Sidestepper_Move1 = $6C
GFX_Sidestepper_Move2 = $6F
GFX_Sidestepper_Move3 = $72

GFX_Sidestepper_AngryMove1 = $D0
GFX_Sidestepper_AngryMove2 = $D3
GFX_Sidestepper_AngryMove3 = $D6

GFX_Sidestepper_Flipped1 = $D9

GFX_Fighterfly_Move1 = $7D
GFX_Fighterfly_Move2 = $80
GFX_Fighterfly_Move3 = $83

GFX_Fighterfly_Flipped1 = $E0

GFX_Coin_Frame1 = $A1
GFX_Coin_Frame2 = $A3
GFX_Coin_Frame3 = $A5
GFX_Coin_Frame4 = $A7
GFX_Coin_Frame5 = $A9

GFX_Freezie_Move1 = $8C
GFX_Freezie_Move2 = $8E
GFX_Freezie_Move3 = $90

GFX_Splash_Frame1 = $B4
GFX_Splash_Frame2 = $B8
GFX_Splash_Frame3 = $BC

GFX_Fireball_Move1 = $92
GFX_Fireball_Move2 = $93
GFX_Fireball_Move3 = $94
GFX_Fireball_Move4 = $95

GFX_Freezie_Destroyed1 = $E8

GFX_CoinCollected = $46

;$BF
Entity_ID_Mario = $01			;i suspect luigi is #$02
Entity_ID_Shellcreeper = $10
Entity_ID_Sidestepper = $20
Entity_ID_Fighterfly = $30
Entity_ID_Coin = $40
Entity_ID_Freezie = $80

;States for entities
;$C6
Player_State_AppearAfterDeath = $02

Entity_Address_Size = $0020			;how many bytes does each entity use?

;various OAM slots
Cursor_OAM_Slot = 0				;
Cursor_Tile = $EE
Cursor_XPos = $38

Freezie_Explosion_OAM_Slot = 44			;uses 2 slots = 2 tiles
Freezie_Explosion_Property = $03		;OAM prop
Freezie_Explosion_Frame1 = $68
Freezie_Explosion_Frame2 = $6A

FreezeEffect_OAM_Slot = 44			;those use 4 slots (2 tiles for 2 directions)

Lives_OAM_Slot = 52				;all lives
Lives_Mario_OAM_Slot = 52			;Mario's, 3 slots
Lives_Luigi_OAM_Slot = 55			;Luigi's, 3 slots too
Lives_Tile = $DF

Score_OAM_Slot = 58				;4 slots, 2 pairs
Score_Zeros_Tile = $45
Score_8_Tile = $40
Score_16_Tile = $42
Score_24_Tile = $43
Score_32_Tile = $44
Score_2_Tile = $3E
Score_5_Tile = $3F

RespawnPlatform_OAM_Slot = 48			;4 slots, 2 pairs for each player
RespawnPlatform_Tile1 = $CD
RespawnPlatform_Tile2 = $CE
RespawnPlatform_Tile3 = $CF

BonusCoinCount_OAM_Slot = 12			;this is for coins that show up on bonus coin count screen after a bonus phase
Coin_TopTile = $A5
Coin_BottomTile = $A6

;various VRAM tile defines
VRAMTile_Empty = $24				;empty tile of transparency
VRAMTile_Bricks = $92				;those bricks at the very bottom of the level
VRAMTile_PlatformBase = $93			;used as a base value for platforms, they have different look depending on how far you're in the game

;VRAM positions for various things, such as strings
VRAMLoc_Player1Score = $2064			;position of the leftmost digit of player 1's score
VRAMLoc_TOPScore = $206E			;
VRAMLoc_Player2Score = $2077			;

VRAMLoc_TopPipeLeft = $2080			;position for top-right 8x8 row in 6x4 (8x8 tile) object
VRAMLoc_TopPipeRight = $209A

;the bottom pipes are 4x3 tiles
VRAMLoc_BottomPipeLeft = $22E0
VRAMLoc_BottomPipeRight = $22FC

VRAMLoc_BonusTimer = $20AE			;location for TEST YOUR SKILL timer

;Other misc values
TensHundredsThousandsScoreFor1Up = $02		;used to check if having enough score to reward a 1-up. checking for thousands and hundreds requires changing address (e.g. Player2Score+1). checking for both requires additional code.

;easy OAM props, don't change these
OAMProp_YFlip = %10000000
OAMProp_XFlip = %01000000
OAMProp_BGPriority = %00100000
OAMProp_Palette0 = %00000000
OAMProp_Palette1 = %00000001
OAMProp_Palette2 = %00000010
OAMProp_Palette3 = %00000011