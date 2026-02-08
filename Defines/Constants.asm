;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Constants

;initial register values
ControlInitBits = %10010000
RenderInitBits = %00000110

;VRAM Write routine values, used as commands
VRAMWriteCommand_Repeat = $40                               ;bit 6 will make repeat writes of one value
VRAMWriteCommand_DrawVert = $80                             ;bit 7 - change drawing from horizontal line to vertical
VRAMWriteCommand_Stop = $00                                 ;command to stop VRAM write and return from routine.

;controller input constants
Input_A = %10000000
Input_B = %01000000
Input_Select = %00100000
Input_Start = %00010000
Input_Up = %00001000
Input_Down = %00000100
Input_Left = %00000010
Input_Right = %00000001

BonusTimerMilliSecondTiming = $06                           ;how long does it take to decrease bonus phase's timer by 1 millisecond (PAL version makes this value lower by 1)

;Sound values
;$FC
Sound_Loop_Timer = %00000100                                ;from TEST YOUR SKILL
Sound_Loop_Fireball = %00001000                             ;not necessarily a loop but the way wavy fireball produces it, it may as well be (though the diagonal one only makes it each time it hits the surface so its not a loop)

;$FD
Sound_Jingle_GameStart = %00000001                          ;plays when starting the game from phase 1
Sound_Jingle_PhaseStart = %00000010                         ;plays when proceeding to the next phase
Sound_Jingle_PERFECT = %00000100                            ;plays after "Test Your Skill" if got "perfect!!"
Sound_Jingle_Pause = %00001000                              ;plays when pausing the game (and when gaining an extra life, apparently)
Sound_Jingle_PlayerReappear = %00010000                     ;plays after lost life and appearing on a platform at the top of the screen
Sound_Jingle_CoinCount = %00100000                          ;plays when counting coins after "Test Your Skill"
Sound_Jingle_GameOver = %01000000                           ;
Sound_Jingle_TitleScreen = %10000000                        ;title screen theme

;$FE
Sound_Effect_DestroyedFreezie = %00000001
Sound_Effect_CollectedCoin = %00000010
Sound_Effect_FreezieExplode = %00000100                     ;when about to make icy surface
Sound_Effect_CoinPipeExit = %00001000
Sound_Effect_ShellCreeperPipeExit = %00010000
Sound_Effect_SidestepperPipeExit = %00100000
Sound_Effect_FighterFlyPipeExit = %01000000
Sound_Effect_Splash = %10000000                             ;when something reaches the bottom of the screen and spawns splash effect.

;$FF
Sound_Effect2_PlayerDead = %00000001
Sound_Effect2_POWBump = %00000010
Sound_Effect2_LastEnemyDead = %00000100                     ;after kicking last enemy
Sound_Effect2_EnemyKicked = %00001000
Sound_Effect2_EnemyBumped = %00010000                       ;when hitting platform from below
Sound_Effect2_Jump = %00100000
Sound_Effect2_Skidding = %01000000                          ;player skid sound
Sound_Effect2_Step = %10000000                              ;when player moves around, sound changes slightly every frame

;some sound values that can change the way sound effects, well, sound
Sound_Timer_BasePitch = $34
Sound_Fireball_BasePitch = $FE

;used by demo screen
Demo_EndCommand = $AA

;Entity addresses' values
;CurrentEntity_MovementBits
Entity_MovementBits_MovingRight = %00000001
Entity_MovementBits_MovingLeft = %00000010
Entity_MovementBits_MovingHorz = Entity_MovementBits_MovingRight|Entity_MovementBits_MovingLeft
Entity_MovementBits_Skidding = %00000100                    ;exclusive to players
Entity_MovementBits_CantMove = %00001000                    ;used by players when they're squished or have respawned on a platform
Entity_MovementBits_Fall = %01000000
Entity_MovementBits_JumpBounce = %10000000                  ;entity jumped if bounced upward
Entity_MovementBits_AirMovement = Entity_MovementBits_Fall|Entity_MovementBits_JumpBounce

;CurrentEntity_AnimationPointer
;all point to the start of the animation cycle within the allocated animation table
PlayerRunningAnimCycle_Start = PlayerRunningAnimCycle-EntityMovementAnimations_F4B2
PlayerSkiddingAnimCycle_Start = PlayerSkiddingAnimCycle-EntityMovementAnimations_F4B2
ShellcreeperWalkAnimCycle_Start = ShellcreeperWalkAnimCycle-EntityMovementAnimations_F4B2
SidestepperWalkAnimCycle_Start = SidestepperWalkAnimCycle-EntityMovementAnimations_F4B2
SidestepperAngryWalkAnimCycle_Start = SidestepperAngryWalkAnimCycle-EntityMovementAnimations_F4B2
FighterflyMovementAnimCycle_Start = FighterflyMovementAnimCycle-EntityMovementAnimations_F4B2
CoinSpinningAnimCycle_Start = CoinSpinningAnimCycle-EntityMovementAnimations_F4B2
FreezieMovementAnimCycle_Start = FreezieMovementAnimCycle-EntityMovementAnimations_F4B2
SplashAnimCycle_Start = SplashAnimCycle-EntityMovementAnimations_F4B2
FireballMovementAnimCycle_Start = FireballMovementAnimCycle-EntityMovementAnimations_F4B2

;Entity graphics (first tile for each, after which +1 is added for others)
;$B6
GFX_Player_Walk1 = $06
GFX_Player_Walk2 = $0C
GFX_Player_Walk3 = $00
GFX_Player_Standing = $12                                   ;still
GFX_Player_Jumping = $18

GFX_Player_Squish1 = $1E                                    ;one player's too heavy for another
GFX_Player_Squish2 = $22

GFX_Player_Skid1 = $26
GFX_Player_Skid2 = $2C
GFX_Player_Hurt = $32
GFX_Player_FallDown = $38

GFX_Shellcreeper_Walk1 = $52
GFX_Shellcreeper_Walk2 = $54
GFX_Shellcreeper_Walk3 = $56

GFX_Shellcreeper_Flipped1 = $58
GFX_Shellcreeper_Flipped2 = $5A
GFX_Shellcreeper_Turning = $E6

GFX_Sidestepper_Move1 = $6C
GFX_Sidestepper_Move2 = $6F
GFX_Sidestepper_Move3 = $72

GFX_Sidestepper_AngryMove1 = $D0
GFX_Sidestepper_AngryMove2 = $D3
GFX_Sidestepper_AngryMove3 = $D6

GFX_Sidestepper_Flipped1 = $D9
GFX_Sidestepper_Flipped2 = $DC
GFX_Sidestepper_Turning = $75

GFX_Fighterfly_Move1 = $7D
GFX_Fighterfly_Move2 = $80
GFX_Fighterfly_Move3 = $83

GFX_Fighterfly_Flipped1 = $E0
GFX_Fighterfly_Flipped2 = $E3

GFX_Coin_Frame1 = $A1
GFX_Coin_Frame2 = $A3
GFX_Coin_Frame3 = $A5
GFX_Coin_Frame4 = $A7
GFX_Coin_Frame5 = $A9

GFX_CollectedCoin_Frame1 = $46
GFX_CollectedCoin_Frame2 = $47
GFX_CollectedCoin_Frame3 = $48
GFX_CollectedCoin_Frame4 = $49
GFX_CollectedCoin_Frame5 = $4D                              ;8x16 dollar

GFX_CollectedBonusCoin = $9E                                ;same tile as one of the fireball appear frames

GFX_Freezie_Move1 = $8C
GFX_Freezie_Move2 = $8E
GFX_Freezie_Move3 = $90

GFX_Freezie_Destroyed1 = $E8
GFX_Freezie_Destroyed2 = $EB
GFX_Freezie_Destroyed3 = $F0

GFX_Fireball_Move1 = $92
GFX_Fireball_Move2 = $93
GFX_Fireball_Move3 = $94
GFX_Fireball_Move4 = $95

GFX_Fireball_Pop1 = $9B                                     ;pop IN or OUT
GFX_Fireball_Pop2 = $9C
GFX_Fireball_Pop3 = $9D
GFX_Fireball_Pop4 = $9E
GFX_Fireball_Pop5 = $9F

GFX_Splash_Frame1 = $B4
GFX_Splash_Frame2 = $B8
GFX_Splash_Frame3 = $BC

;CurrentEntity_PaletteOffset
ShellcreeperPalettes_Start = ShellcreeperPalettes-EnemyPalettes_F638
SidestepperPalettes_Start = SidestepperPalettes-EnemyPalettes_F638
FighterflyPalettes_Start = FighterflyPalettes-EnemyPalettes_F638

;CurrentEntity_ID
Entity_ID_Mario = $01
Entity_ID_Luigi = $02
Entity_ID_Shellcreeper = $10
Entity_ID_Sidestepper = $20
Entity_ID_Fighterfly = $30
Entity_ID_Coin = $40                                        ;moving coin after the enemy has been defeated
Entity_ID_Freezie = $80
Entity_ID_WavyFireball = $A0
Entity_ID_ReflectingFireball = $B0
Entity_ID_FloatingCoin = $F0                                ;TEST YOUR SKILL coin

;$C0
Entity_State_GotFlipped = $01
Entity_State_FlippedFalling = $02                           ;was just flipped by the player, currently in air
Entity_State_FlippedLanded = $03
Entity_State_SidestepperAngry = $04
Entity_State_Disappears = $06                               ;freezie and coin only
Entity_State_FlippedBack = $0F                              ;the enemy just got up from being flipped
Entity_BumpBits_BumpedCenter = $30
Entity_BumpBits_BumpedToTheRight = $10
Entity_BumpBits_BumpedToTheLeft = $20

;CurrentEntity_XSpeedTableOffset
PlayerXMovementData_Start = PlayerXMovementData-EntityXMovementData_F393
ShellcreeperXMovementData_Start = ShellcreeperXMovementData-EntityXMovementData_F393
SidestepperXMovementData_Start = SidestepperXMovementData-EntityXMovementData_F393
FreezieXMovementData_Start = ShellcreeperXMovementData_Start;shared with turtles
CoinXMovementData_Start = ShellcreeperXMovementData_Start   ;same as above

;States for entities
;$C6
Player_State_Dead = $01                                     ;game over or init respawn platform
Player_State_AppearAfterDeath = $02                         ;moves down on respawn platform
Player_State_P1OnRespawnPlatform = $04                      ;currently on respawn platform and hasn't moved yet (player 1)
Player_State_P2OnRespawnPlatform = $08                      ;player 2
Players_State_OnRespawnPlatform = Player_State_P1OnRespawnPlatform|Player_State_P2OnRespawnPlatform
Player_State_Hurt = $10
Player_State_Splash = $20                                   ;player turned into a splash after falling down

;Fireball states
Fireball_State_Appears = $01
Fireball_State_Disappears = $02
Fireball_State_Normal = $10

;CurrentEntity_DefeatedState
CurrentEntity_DefeatedState_Kicked = $10
CurrentEntity_DefeatedState_Splash = $20

Entity_Address_Size = $0020                                 ;how many bytes does each entity use? (to-do: calculate automatically)

;various OAM slots
Cursor_OAM_Slot = 0                                         ;
Cursor_Tile = $EE
Cursor_XPos = $38

Mario_OAM_Slot = 4
Luigi_OAM_Slot = 10

;players will take these slots during TEST YOUR SKILL bonus phases
MarioInTestYourSkill_OAM_Slot = 0                           ;respective player starting OAM slots
LuigiInTestYourSkill_OAM_Slot = 6

Freezie_Explosion_OAM_Slot = 44                             ;uses 2 slots = 2 tiles
Freezie_Explosion_Property = OAMProp_Palette3               ;OAM prop
Freezie_Explosion_Frame1 = $68
Freezie_Explosion_Frame2 = $6A

FreezeEffect_OAM_Slot = 44                                  ;those use 4 slots (2 tiles for 2 directions)
FreezeEffect_Tile1 = $8A
FreezeEffect_Tile2 = $8B
FreezeEffect_Property = OAMProp_Palette3

WavyFireball_OAM_Slot = 0
WavyFireball_Property = OAMProp_Palette1
WavyFireball_SpawnXPosLeft = $18                            ;x-positions for fireball's spawn, for both sides of the screen
WavyFireball_SpawnXPosRight = $E8

ReflectingFireball_OAM_Slot = 1
ReflectingFireball_Property = OAMProp_Palette2

Lives_OAM_Slot = 52                                         ;all lives
Lives_Mario_OAM_Slot = 52                                   ;Mario's, 3 slots
Lives_Luigi_OAM_Slot = 55                                   ;Luigi's, 3 slots too
Lives_Tile = $DF

Score_OAM_Slot = 58                                         ;4 slots, 2 pairs
Score_Zeros_Tile = $45
Score_8_Tile = $40
Score_16_Tile = $42
Score_24_Tile = $43
Score_32_Tile = $44
Score_2_Tile = $3E
Score_5_Tile = $3F

Score_ForMarioPalette = OAMProp_Palette3
Score_ForLuigiPalette = OAMProp_Palette2

RespawnPlatform_OAM_Slot = 48                               ;4 slots, 2 pairs for each player
RespawnPlatform_Tile1 = $CD
RespawnPlatform_Tile2 = $CE
RespawnPlatform_Tile3 = $CF

BonusCoinCount_OAM_Slot = 12                                ;this is for coins that show up on bonus coin count screen after a bonus phase
Coin_TopTile = $A5
Coin_BottomTile = $A6
Coin_DollarProp = OAMProp_Palette2

Splash_OAMProp = OAMProp_Palette3

;various VRAM tile defines
VRAMTile_Empty = $24                                        ;empty tile of transparency
VRAMTile_Bricks = $92                                       ;those bricks at the very bottom of the level
VRAMTile_PlatformBase = $93                                 ;used as a base value for platforms, they have different look depending on how far you're in the game
VRAMTile_IcePlatform = $97                                  ;to check for slippery slippydo

;VRAM positions for various things, such as strings
VRAMLoc_Player1Score = $2064                                ;position of the leftmost digit of player 1's score
VRAMLoc_TOPScore = $206E                                    ;
VRAMLoc_Player2Score = $2077                                ;

VRAMLoc_TopPipeLeft = $2080                                 ;position for top-right 8x8 row in 6x4 (8x8 tile) object
VRAMLoc_TopPipeRight = $209A

;the bottom pipes are 4x3 tiles
VRAMLoc_BottomPipeLeft = $22E0
VRAMLoc_BottomPipeRight = $22FC

VRAMLoc_POW = $22AF

VRAMLoc_BonusTimer = $20AE                                  ;location for TEST YOUR SKILL timer

;Other misc values
TensHundredsThousandsScoreFor1Up = $02                      ;used to check if having enough score to reward a 1-up. checking for thousands and hundreds requires changing address (e.g. Player2Score+1). checking for both requires additional code.

;easy OAM props, don't change these
OAMProp_YFlip = %10000000
OAMProp_XFlip = %01000000
OAMProp_BGPriority = %00100000
OAMProp_Palette0 = %00000000
OAMProp_Palette1 = %00000001
OAMProp_Palette2 = %00000010
OAMProp_Palette3 = %00000011