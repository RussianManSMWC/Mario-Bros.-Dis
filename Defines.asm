;This file holds defines for Mario Bros. Disassembly. Both RAM adresses and values.
;Also WIP

;RAM Adresses

InterruptedFlag = $23		    ;Used to determine if game got interrupted with Non-maskable interrupt. one routine specifically waits for NMI and will end waiting after it happens

FrameCounter = $2F          ;Self-explanatory, increments every frame.

Show2ndPlayerScore = $39	  ;flag for player 2 score to display

GameAorBFlag = $3A          ;self explanatory, set if player chose game B

PaletteFlag = $3F           ;If 1, use palette for normal gameplay, otherwise use title screen palette.

GameplayMode = $40          ;used for pointers to handle various gameplay aspects, such as (un)pausing, proceeding to next phase, coin counting after "Test Your Skill!" and other.

DisplayLevelNum = $41		    ;

FreezeFlag = $42            ;POSSIBLY freeze flag, though it doesn't affects player gravity (only collision) and green fireballs. only applied in normal gameplay or demo.

Player1Lives = $48

MarioGameOverFlag = $49

GameOverFlag = $4A

Player2Lives = $4C

LuigiGameOverFlag = $4D

Player2DisplayFlag = $4E

PowHitsLeft = $70

ScreenShakeTimer = $71

HighScore = $91				      ;3 bytes

Player1Score = $95			    ;3 bytes

Player1Score = $99			    ;3 bytes

Player2ScoreDisplay = $9E	  ;seems to be another flag for score display for player 2, except this doesn't handles "II" tile on screen.

BonusTimeSecs = $04B1

BonusTimeMilliSecs = $04B2

Player1BonusCoins = $04B5

Player2BonusCoins = $04B6

SoundPitch = $0500          ;or whatever, related with Freezie's explosion sound (when it makes platform icy), fireball sounds and somehow with red fireball's movement.


