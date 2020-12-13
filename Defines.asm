;This file holds defines for Mario Bros. Disassembly. Both RAM adresses and (values, but there's non currently).
;Also WIP

;RAM Adresses

Reg2000BitStorage = $09			;contains bits to be enabled/disabled for register $2000
Reg2001BitStorage = $0A			;contains bits to be enabled/disabled for register $2001

CameraPosY = $0B			;current camera position
CameraPosX = $0C			;

EntityDataPointer = $14			;2 bytes, used by entities for indirect addressing

;Controller addresses. Format: ABetUDLR, A = A button, B = B button, e = select, t = start, U = Up, D = Down, L = Left, R = Right.
;Do note that InputPress only resets A and B bits after press.

ControllerInputHolding = $18		;base adress for both controllers (indexed)
ControllerInputPress = $19		;same as above but for presses

Controller1InputHolding = $18		;controller input bits for player 1, holding.
Controller1InputPress = $19		;controller input bits for player 1, press.

Controller2InputHolding = $1A		;controller input bits for player 2, holding.
Controller2InputPress = $1B		;controller input bits for player 2, press.

InterruptedFlag = $23			;Used to determine if game got interrupted with Non-maskable interrupt. one routine specifically waits for NMI and will end waiting after it happens

NMI_FunctionsDisableFlag = $22		;flag used to prevent NMI routines from running in case it occures during lag

Pause_HeldPressed = $26			;this address reacts to pause being pressed/held. used to prevent pause switching every frame when pause is held.

TitleScreen_SelectHeldFlag = $28	;
Cursor_Option = $29			;selected option

TimingTimer = $2A			;timer used to decrease other timers.
GeneralTimer2B = $2B			;used as timer for various things, for example as timer for bonus end, for each coin display, multiplication display and perfect/no bonus message and for unpause
ShakeTimer = $2C			;timer used for screen shaking when POW block is hit
TransitionTimer = $2D			;used mostly for transitions, specifically, how long it takes before starting new phase after last enemy falls offscreen, timer before transitioning to bonus end and from it and for transition to demo mode.
PipeDelayTimer = $2E			;used for sprites coming out of pipes. when timer's zero, sprite comes out of pipe fully.

FrameCounter = $2F			;Self-explanatory, increments every frame.

DemoFlag = $30				;flag set when demo plays

TwoPlayerModeFlag = $39			;this flag is used to check wether player's in 2P mode for score display

GameAorBFlag = $3A			;self explanatory, set if player chose game B
GameplayModeNext = $3B			;game mode that goes next after execution

PaletteFlag = $3F			;Wether or not game should update palette, and which palette to use. $00 - Don't update, keep current palette, $01 - Gameplay Palette, anything else - Title Screen Palette.

GameplayMode = $40			;used for pointers to handle various gameplay aspects, such as (un)pausing, proceeding to next phase, coin counting after "Test Your Skill" and other.

DisplayLevelNum = $41			;rename to CurrentPhase? i mean it IS used for display but also checked, so maybe it's global

UpdateEntitiesFlag = $42		;0 - update, 1 - don't update. used to prevent lag? (set after normal game mode, reset after NMI) (or is it?)

LastEnemyFlag = $46			;if set, we have the last enemy to defeat to proceed to the next phase

;TO-DO: rename zero lives flags (amd LuigiGameOverFlag) because they're not really that (slightly different function)
PlayerLives = $48			;base address for lives (indexed)
PlayerZeroLivesFlag = $48		;also base address (also indexed)

Player1Lives = $48
Player1TriggerGameOverFlag = $49 	;set to 1 if dying with 0 lives, triggering game over (if set, dying/winning triggers game over)
Player1GameOverFlag = $4A		;

Player2Lives = $4C
Player2TriggerGameOverFlag = $4D
Player2GameOverFlag = $4E

NonGameplayMode = $50			;this is used for modes without player's gameplay (title screen, demo)

Demo_InputIndex = $55
Demo_InputTimer = $56

PowHitsLeft = $70
POWPowerTimer = $71			;timer set when POW is hit, to run hit interaction with everything on-screen. 

;$90 is probably used but idk what its for, same for 94 and 98
;but for what?
ScoreAddress = $90			;base address that gets offsetted to get other score addresses
HighScore = $91				;3 bytes. All score addresses have following format: First byte is tens and hundred thousands, secon is thousands and hundreds, and third byte is tens and ones.
PlayerScoreAddress = $94		;the same as ScoreAddress but for players only
Player1Score = $95			;3 bytes
Player2Score = $99			;3 bytes
Player2ScoreDisplay = $9E		;seems to be another flag for score display for player 2, except this doesn't handle "II" tile on screen.

Player1_Got1UPFlag = $AD		;a flag for wether the player has gotten a 1-up by obtaining a certain amoutnt of score
Player2_Got1UPFlag = $AE		;same but for player 2

CurrentEntity_ActiveFlag = $B0		;flag for current entity wether it exists or not
CurrentEntity_Bits = $B1		;bits used for various entities for various purposes. some enemies use bits 0 and 1 for movement direction (bit 0 - move right, bit 1 - move left)
CurrentEntity_DrawMode = $B5		;how to draw i entity?
CurrentEntity_DrawTile = $B6		;first sprite tile it's drawing
CurrentEntity_YPos = $B8
CurrentEntity_XPos = $B9
CurrentEntity_CurrentPlatform = $BE
CurrentEntity_Timer = $C2		;some kinda of timer, i think
;CurrentEntity_XSpeed = $C4
CurrentEntity_XSpeed = $C5
CurrentEntity_State = $C6
CurrentEntity_HitBoxYPos = $CE
CurrentEntity_HitBoxXPos = $CF

;Sound addresses
;those are bitwise, each sound is it's own bit.
Sound_Loop = $FC			;some looping sounds
Sound_Jingle = $FD			;various jingles
Sound_Effect = $FE			;sound effects
Sound_Effect2 = $FF			;more sound effects

Entity_Address = $0300			;from $0300 to $0460 are used for enities, each using $20 bytes.

BonusTimeSecs = $04B1
BonusTimeMilliSecs = $04B2

TESTYOURSKILL_CoinCountPointer = $04B4	;coin count state after time runs out/all coins are collected
Player1BonusCoins = $04B5
Player2BonusCoins = $04B6

BonusCoins_TotalCollected = $04BB

GameOverStringTimer = $04F0
PhaseStringTimer = $04F1		;for how long PHASE X string will be shown on string

RandomNumberStorage = $0500

BumpTileBuffer = $0540			;contains tiles for bump tiles to be transferred into actual buffer, basically BufferOffset and BufferAddr for bumped tiles (7 bytes max)

BufferDrawFlag = $21			;flag used to tell the game if we're supposed to draw tiles stored in buffer
BufferOffset = $0590			;used to offset buffer position
BufferAddr = $0591			;buffer for tile drawing of unknown size.

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Constants

;VRAM Write routine values, used as commands

VRAMWriteCommand_Repeat = $40		;bit 6 will make repeat writes of one value
VRAMWriteCommand_DrawVert = $80		;bit 7 - change drawing from horizontal line to vertical
VRAMWriteCommand_Stop = $00		;command to stop VRAM write and return from routine.

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
Sound_Loop_Timer = $04
Sound_Loop_Fireball = $08

;$FD
Sound_Jingle_GameStart = $01		;plays when starting the game from phase 1
Sound_Jingle_PhaseStart = $02		;plays when proceeding to the next phase
Sound_Jingle_PERFECT = $04		;plays after "Test Your Skill" if got "perfect!!"
Sound_Jingle_Pause = $08		;plays when pausing the game (and when gaining an extra life, apparently)
Sound_Jingle_PlayerReappear = $10	;plays after lost life and appearing on a platform at the top of the screen
Sound_Jungle_CoinCount = $20		;plays when counting coins after "Test Your Skill"
Sound_Jingle_GameOver = $40		;silent?
Sound_Jungle_TitleScreen = $80		;title screen theme

;$FE
Sound_Effect_DestroyedFreezie = $01
Sound_Effect_CollectedCoin = $02
Sound_Effect_FreezieExplode = $04	;when about to make icy surface
Sound_Effect_CoinPipeExit = $08		;
Sound_Effect_ShellCreeperPipeExit = $10
Sound_Effect_SidestepperPipeExit = $20
Sound_Effect_FighterFlyPipeExit = $40
Sound_Effect_Splash = $80		;when something reaches the botto of the screen and spawns splash effect.

;$FF
Sound_Effect2_PlayerDead = $01
Sound_Effect2_POWBump = $02
Sound_Effect2_LastEnemyDead = $04	;after kicking last enemy
Sound_Effect2_EnemyKicked = $08
Sound_Effect2_EnemyHit = $10		;when hitting platform from below
Sound_Effect2_Jump = $20
Sound_Effect2_Turning = $40
Sound_Effect2_Step = $80		;when player moves around, sound changes slightly every frame

;used by demo screen
Demo_EndCommand = $AA

;Entity addresses' values ($B5)
CurrentEntity_Draw_16x24 = 0		;used by mario and luigi
CurrentEntity_Draw_16x16 = 1		;used by coin effect (kinda popping effect that looks 16x16)
CurrentEntity_Draw_8x16_AnimFlicker = 2	;this is used by by sidestepper, top tile flickers
CurrentEntity_Draw_8x16_Flicker = 3	;used by sidesteppers and fighterflies, they change top tile position every frame.
CurrentEntity_Draw_8x16 = 5		;8x16. used by coins, freezies and other effects
CurrentEntity_Draw_8x16_Shift = 6	;8x16 but the top tile is slightly shifter horizontally. used by Shellcreepers
CurrentEntity_Draw_8x8 = 7		;should be obvious, used for fireballs and various effects

;States for entities

Player_State_AppearAfterDeath = $02

;Entity graphics (first tile for each, after which +1 is added for others)
GFX_Player_Standing = $12		;still
GFX_Player_Hurt = $32


;various OAM slots
Cursor_OAM_Slot = 0			;

;VRAM positions for various things, such as strings (to be added)