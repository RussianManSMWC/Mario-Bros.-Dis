;This file holds defines for Mario Bros. Disassembly. Both RAM adresses and (values, but there's non currently).
;Also WIP

;RAM Adresses

Reg2000BitStorage = $09			;contains bits to be enabled/disabled for register $2000
Reg2001BitStorage = $0A			;contains bits to be enabled/disabled for register $2001

CameraPosY = $0B            ;current camera position
CameraPosX = $0C            ;

;Controller addresses. Format: ABetUDLR, A = A button, B = B button, e = select, t = start, U = Up, D = Down, L = Left, R = Right.
;Do note that InputPress only resets A and B bits after press.

Controller1InputHolding = $18		;controller input bits for player 1, holding.
Controller1InputPress = $19		;controller input bits for player 1, press.

Controller2InputHolding = $1A		;controller input bits for player 2, holding.
Controller2InputPress = $1B		;controller input bits for player 2, press.

InterruptedFlag = $23			;Used to determine if game got interrupted with Non-maskable interrupt. one routine specifically waits for NMI and will end waiting after it happens

TimingTimer = $2A			;timer used to decrease other timers.

GeneralTimer2B = $2B			;used as timer for various things, for example as timer for bonus end, for each coin display, multiplication display and perfect/no bonus message and for unpause
ShakeTimer = $2C					;timer used for screen shaking when POW block is hit
TransitionTimer = $2D			;used mostly for transitions, specifically, how long it takes before starting new phase after last enemy falls offscreen, timer before transitioning to bonus end and from it.
PipeDelayTimer = $2E			;used for sprites coming out of pipes. when timer's zero, sprite comes out of pipe.

FrameCounter = $2F			;Self-explanatory, increments every frame.

DemoFlag = $30				;flag set when demo plays

Show2ndPlayerScore = $39		;flag for player 2 score to display

GameAorBFlag = $3A			;self explanatory, set if player chose game B

PaletteFlag = $3F			;Wether or not game should update palette, and which palette to use. $00 - Don't update, keep current palette, $01 - Gameplay Palette, anything else - Title Screen Palette.

GameplayMode = $40			;used for pointers to handle various gameplay aspects, such as (un)pausing, proceeding to next phase, coin counting after "Test Your Skill!" and other.

DisplayLevelNum = $41			;

FreezeFlag = $42			;POSSIBLY freeze flag, though it doesn't affects player gravity (only collision) and green fireballs. only applied in normal gameplay or demo.

Player1Lives = $48

MarioGameOverFlag = $49

GameOverFlag = $4A			;non-player specific game over flag.

Player2Lives = $4C

LuigiGameOverFlag = $4D

Player2DisplayFlag = $4E

PowHitsLeft = $70

POWPowerTimer = $71			;timer set when POW is hit, to run hit interaction with everything on-screen. 

HighScore = $91				;3 bytes

Player1Score = $95			;3 bytes

Player2Score = $99			;3 bytes

Player2ScoreDisplay = $9E		;seems to be another flag for score display for player 2, except this doesn't handles "II" tile on screen.

CurrentEntity_ActiveFlag = $B0    ;flag for current entity wether it exists or not
CurrentEntity_Bits = $B1		      ;some kind of bits that represent current entity's state
CurrentEntity_ID = $B5

BonusTimeSecs = $04B1
BonusTimeMilliSecs = $04B2

Player1BonusCoins = $04B5
Player2BonusCoins = $04B6

RandomNumberStorage = $0500

;VRAM Write routine values, used as commands

VRAMWriteCommand_Repeat = $40     ;bit 6 will make repeat writes of one value

VRAMWriteCommand_Stop = $00       ;command to stop VRAM write and return from routine.
