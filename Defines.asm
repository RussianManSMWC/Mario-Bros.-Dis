;This file holds defines for Mario Bros. Disassembly. Both RAM adresses and (values, but there's non currently).
;maybe split constants and RAM addresses some day...
;Also WIP

;RAM Adresses

Reg2000BitStorage = $09				;contains bits to be enabled/disabled for register $2000
Reg2001BitStorage = $0A				;contains bits to be enabled/disabled for register $2001

CameraPosX = $0B				;current camera position
CameraPosY = $0C				;
BaseCameraPosY = $0D				;always remains 0, used for for camera displacement during POW shake, so the camera would return to default position

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
;$33 - Misc?
EnemyLevel = $34				;enemy level, used to load enemies depending on current phase. for more details see DATA_F3BA

EntitySpawnIndex = $35				;acts as an index for the pointer for enemies that come out of pipe. Also holds special command value, AA - no more enemies should spawn (except for freezies), BB - don't spawn entities at all (for TEST YOUR SKILL phases)
EntitySpawnPointer = $36			;2 bytes

;$38 - unused

TwoPlayerModeFlag = $39				;this flag is used to check wether player's in 2P mode for score display

GameAorBFlag = $3A				;self explanatory, set if player chose game B
GameplayModeNext = $3B				;game mode that goes next after execution

;$3C-$3E - unused

PaletteFlag = $3F				;Wether or not game should update palette, and which palette to use. $00 - Don't update, keep current palette, $01 - Gameplay Palette, anything else - Title Screen Palette.

GameplayMode = $40				;used for pointers to handle various gameplay aspects, such as (un)pausing, proceeding to next phase, coin counting after "Test Your Skill" and other.

CurrentPhase = $41				;0 - didn't start playing the game

UpdateEntitiesFlag = $42			;set for NMI to update entity variables, such as update timer (so the entities won't update during lag)

;$43-$45 - enemies on screen?
;$43-$45 - entities on-screen.
;$43 is the main count, $44 is the amount of entitites without coins and freezies, $45 is the amount of entities without just freezies (?)
EnemiesOnScreen = $43
;EnemiesOnScreen = $45				;counts enemies required to kill on screen, to limit the number of them
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

PhaseCompleteFlag = $51				;victory

TitleScreen_DemoCount = $52			;how many times the demo must play for music to start playing again on the title screen

;$53 - unused

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
PlayerScore = $95				;for current player, contains both player1 and player 2 (offset by X)

PlayerScoreUpdateFlag = $9D			;base address
Player1ScoreUpdateFlag = PlayerScoreUpdateFlag
Player2ScoreUpdateFlag = PlayerScoreUpdateFlag+1;seems to be another flag for score display for player 2, except this doesn't handle "II" tile on screen.
PlayerScoreUpdateIndex = $9F			;used to enable score update flag for the player who hit the POW/enemy from below (contains index for above 2 addresses). sometimes used as a scratch ram also.

;$A0-$A1 - current entity table pointer, kinda like $14 (2 bytes)

Player1_Got1UPFlag = $AD			;a flag for wether the player has gotten a 1-up by obtaining a certain amoutnt of score
Player2_Got1UPFlag = $AE			;same but for player 2

CurrentEntity_Address = $B0			;a base address for current processed entity's values

;flag for the current entity wether it exists or not
CurrentEntity_ActiveFlag = CurrentEntity_Address

;contains various bits related to movement (moving left or right or jumping and so on)
CurrentEntity_MovementBits = CurrentEntity_Address+1

;used to refresh CurrentEntity_UpdateTimer for animations and such
CurrentEntity_TimerStorage = CurrentEntity_Address+2

;general entity timer, when its zero, the entity updates things like movement and animation
CurrentEntity_UpdateTimer = CurrentEntity_Address+3

;used to animate by pointing to a CurrentEntity_DrawTile in a table (when FF, it loops to the first value of the animation)
CurrentEntity_AnimationPointer = CurrentEntity_Address+4

;how the entity is drawn with OAM tiles
CurrentEntity_DrawMode = CurrentEntity_Address+5

;first OAM tile it's drawing
CurrentEntity_DrawTile = CurrentEntity_Address+6
CurrentEntity_TileProps = CurrentEntity_Address+7

;fairly obvious coordinate addresses
CurrentEntity_YPos = CurrentEntity_Address+8
CurrentEntity_XPos = CurrentEntity_Address+9

;where it's OAM is allocated
CurrentEntity_OAMOffset = CurrentEntity_Address+$0A

;For player, used as a timer for squishing animation (player bounced off another player)
;For other entities (particularly, shellcreepers, sidesteppers and fighterflies), this is used to change their palette to indicate speed boost
CurrentEntity_PaletteOffset = CurrentEntity_Address+$0B
CurrentEntity_Player_SquishingTimer = CurrentEntity_Address+$0B

;a pointer for update data of various varieties, like vertical speed, horizontal speed, graphics display and stuff.
CurrentEntity_UpdateDataPointer = CurrentEntity_Address+$0C

CurrentEntity_CurrentPlatform = CurrentEntity_Address+$0E
CurrentEntity_ID = CurrentEntity_Address+$0F

;Used to indicate if a non-player entity has been bumped from below/by POW and represents a particular state of disturbance (also used for coins when simply picked up, either by bump or touched by the player
;bits 4 and 5 represent the way it's been bumped (bit 4 - bumped to the right, bit 5 - bumped to the left, both bits enabled - dead center)
;For player entities, holds controller inputs
CurrentEntity_BumpedStateAndBits = CurrentEntity_Address+$10
CurrentEntity_Player_ControllerInputs = CurrentEntity_Address+$10

;has various uses:
;for player entities, its used to contain bump bits similar to above address (bits 4 and 5).
;for sidestepper, it contains horizontal movement direction for after being bumped once.
;for freezies, it's used as a timer for the freeze procedure.
;for coins its a flag indicating if its been collected
CurrentEntity_MiscRAM = CurrentEntity_Address+$11

;here are specific uses for each entity
CurrentEntity_Player_BumpedBits = CurrentEntity_Address+$11
CurrentEntity_Freezie_FreezeTimer = CurrentEntity_Address+$11

;for player entities, this acts as a timer for animations (primarily movement?).
;for other entities, this is a pipe coming in/out direction (Entity_MovementBits_MovingHorz bits), bit 7 is set when its coming out of the pipe specifically.
CurrentEntity_PipeDir = CurrentEntity_Address+$12
CurrentEntity_Player_MovementTimer = CurrentEntity_Address+$12

;used to offset the x-speed movement table to get different values for different entities
CurrentEntity_XSpeedTableOffset = CurrentEntity_Address+$13

;Used to give an entity some speed, can be modified to speed up/slow down an entity (grabs various values from the table)
CurrentEntity_XSpeedTableEntry = CurrentEntity_Address+$14

;how fast it's moving
CurrentEntity_XSpeed = CurrentEntity_Address+$15

;for players this is a state address, such as hurt, respawning, etc., for others its a timer?
;for other entities, this is a timer that ticks down when it's moving, when it's 0, it's "held back" in it's movement, for example, it's used for sidesteppers to make them move at a reasonable speed (stops them every few frames instead of moving too fast)
;for moving coins and freezies, it also acts as an animation timer. when it's zero, it stops and updates it's graphic appearance
;does not affect shellcreepers, as their hold-back speed is zero (always moves)
CurrentEntity_XSpeedAlterTimer = CurrentEntity_Address+$16
CurrentEntity_Player_State = CurrentEntity_Address+$16

;used to slow down entity when it's moving... sometimes. sometimes it equals 0 and has no effect. and in one case, it's used to increase speed instead.
CurrentEntity_XSpeedModifier = CurrentEntity_Address+$17

;flag/animation counter for turning, shellcreepers and sidesteppers animate while turning
CurrentEntity_TurningCounter = CurrentEntity_Address+$18

;These three bytes are used by player entities - first two are "VRAM" position, and the third byte is the tile value that is located at said position (used for bumping platforms)
CurrentEntity_Player_VRAMPosLo = CurrentEntity_Address+$19
CurrentEntity_Player_VRAMPosHi = CurrentEntity_Address+$1A
CurrentEntity_Player_TileAtTopVRAMPos = CurrentEntity_Address+$1B

;Other entities use these differently
;basically indicates an abnormal status - defeated/splash state (or collected, in case of coins)
CurrentEntity_DefeatedState = CurrentEntity_Address+$19

;CurrentEntity_Address+$1A and CurrentEntity_Address+$1B are unused for non-player entities (especially CurrentEntity_Address+$1B, none of the entities need to detect what's above them)

;only used by coins? only set when POW is activated
CurrentEntity_WhichPlayerInteracted = CurrentEntity_Address+$1C

;on the contrary, this is used by all entities (to detect ground and bump tiles)
CurrentEntity_TileAtBottomVRAMPos = CurrentEntity_Address+$1D

CurrentEntity_HitBoxHeight = CurrentEntity_Address+$1E
CurrentEntity_HitBoxWidth = CurrentEntity_Address+$1F

;$D0-$EF - Unused

;Sound addresses
Sound_Effect2_Current = $F0			;sound effect2 that is currently playing
Sound_Loop_Timer_Length = $F5			;how long the timer tick (TEST YOUR SKILL) sound is held for before replaying it
Sound_Loop_Fireball_Pitch = $F6			;only used for fireball sound to produce variable sound
Sound_MusicDataPointer = $F7			;2 bytes, indirect addressing

;those are bitwise, each sound/sound is it's own bit.
Sound_Base = Sound_Loop				;used as a base address for sound addresses 
Sound_Loop = $FC				;some looping sounds/held note sound
Sound_Jingle = $FD				;various jingles
Sound_Effect = $FE				;sound effects
Sound_Effect2 = $FF				;more sound effects

;TO-DO: do the same calculation as with current entity values
;e.g. Entity_ReflectingFireball_ActiveFlag = Entity_Address+(ReflectingFireballEntityID*$20)
;will need to define specific slots/IDs or whatever (unrelated to CurrentEntity_ID)
;will make it easier to relocate/resize these addresses I think
Entity_Address = $0300				;from $0300 to $460 are used for enities, each using $20 bytes.
Entity_YPos = Entity_Address+8
Entity_XPos = Entity_Address+9

;First chunk of entity RAM is occupied by Mario
Entity_Mario_ActiveFlag = $0300
Entity_Mario_XPos = $0309

Entity_Mario_OAMOffset = $030A
Entity_Mario_CurrentPlatform = $030E

Entity_Mario_ControllerInputs = $0310

Entity_Mario_State = $0316

;Second chunk - Green Mario
Entity_Luigi_ActiveFlag = $0320
Entity_Luigi_MovementBits = $0321
Entity_Luigi_UpdateTimer = $0323
Entity_Luigi_AnimationPointer = $0324
Entity_Luigi_DrawMode = $0325
Entity_Luigi_DrawTile = $0326

Entity_Luigi_YPos = $0328
Entity_Luigi_XPos = $0329
Entity_Luigi_OAMOffset = $032A
Entity_Luigi_SquishingTimer = $032B
Entity_Luigi_UpdateDataPointer = $032C
Entity_Luigi_CurrentPlatform = $032E

Entity_Luigi_ControllerInputs = $0330
Entity_Luigi_BumpedBits = $0331
Entity_Luigi_MovementTimer = $0332

Entity_Luigi_XSpeedTableEntry = $0334
Entity_Luigi_XSpeed = $0335
Entity_Luigi_State = $0336

Entity_Luigi_TileAtBottomVRAMPos = $033D

;Chunk 3 - reflecting fireball
Entity_ReflectingFireball_ActiveFlag = $0340
Entity_ReflectingFireball_HorzDirection = $0341
Entity_ReflectingFireball_TimerStorage = $0342	;also acts like a timer for appearing in
Entity_ReflectingFireball_UpdateTimer = $0343
Entity_ReflectingFireball_AnimationPointer = $0344
Entity_ReflectingFireball_DrawTile = $0346
Entity_ReflectingFireball_TileProps = $0347
Entity_ReflectingFireball_YPos = $0348
Entity_ReflectingFireball_XPos = $0349
Entity_ReflectingFireball_OAMOffset = $034A
Entity_ReflectingFireball_ObjCollisionDisableTimer = $034B ;some timer?? disables interaction with platform bumping??
Entity_ReflectingFireball_UpdateDataPointer = $034C

Entity_ReflectingFireball_State = $0350
Entity_ReflectingFireball_VertDirection = $0351
Entity_ReflectingFireball_YSpeed = $0355	;unlike most other entities, this is Y speed, not X speed!

Entity_ReflectingFireball_VRAMPosLo = $0357
Entity_ReflectingFireball_VRAMPosHi = $0358

Entity_ReflectingFireball_TileAtBottomVRAMPos = $035B

;chunks 4-9 are occupied by common entities (enemies, freezies and coins)

;Chunk 10 belongs to us. To us, wavy fireballs!
Entity_WavyFireball_ActiveFlag = $0420
Entity_WavyFireball_HorzDirection = $0421
Entity_WavyFireball_AnimationPointer = $0424
Entity_WavyFireball_DrawTile = $0426
Entity_WavyFireball_TileProps = $0427
Entity_WavyFireball_YPos = $0428
Entity_WavyFireball_XPos = $0429
Entity_WavyFireball_OAMOffset = $042A

Entity_WavyFireball_UpdateDataPointer = $042C
Entity_WavyFireball_CurrentPlatform = $042E
Entity_WavyFireball_State = $0430
Entity_WavyFireball_AppearTimer = $0431

EntitiesPerPlatform = $04AC			;4 bytes for each platform. calculates how many things are on the same platform. A player entity adds 2 to this value.
EntitiesPerPlatformTransfer = $04A8		;actual value is transferred here, while the other address is zeroed out for the next calculation

TESTYOURSKILL_Flag = $04B0			;this flag is used to tell wether the phase we're loading is a TEST YOUR SKILL one
BonusTimeSecs = $04B1
BonusTimeMilliSecs = $04B2
BonusTimeMilliSecs_Timing = $04B3		;how many frames does it take to decrease number of milliseconds

TESTYOURSKILL_CoinCountPointer = $04B4		;coin count state after time runs out/all coins are collected
Player1BonusCoins = $04B5
Player2BonusCoins = $04B6

TESTYOURSKILL_CoinCountSubPointer = $04BA	;a subpointer for some TESTYOURSKILL_CoinCountPointer pointers
BonusCoins_TotalCollected = $04BB
BonusCoins_Total = $04BC			;how many coins remain in current TEST YOUR SKILL phase

WaveFireball_MainCodeFlag = $04BE		;\
ReflectingFireball_MainCodeFlag = $04BF		;/if 0, the fireball is being initialized

FreezieCanAppearFlag = $04C0			;if set, freezies start to show up
FreezieAliveFlag = $04C1
FreezieAppearTimer = $04C2
;...
FreezePlatformFlag = $04C5			;if on, the platform becomes frozen
FreezePlatformPointer_Offset = $04C6		;current offset for "platform freeze pointer" pointer
FreezePlatform_UpdateFlag = $04C7		;used to update platform tiles and attributes so the platforms look like they're frozen
FreezePlatformPointer = $04C8			;2 bytes, contains pointer for platform freezing, where to spawn tiles and stuff
FreezePlatformTimer = $04CA			;how long does it take to freeze a part of the platform?
;$04CB - ?
FreezePlatform_WhatPlatform = $04CC		;0 - center, 1 - bottom-left, 2 - bottom-right

PlatformFrozenFlag = $04CD			;3 bytes corresponding each platform: center, bottom-left and bottom-right

Combo_Timer = $04D0				;combo variables for when kicking enemies, for mario and luigi each has a pair
Combo_Value = $04D1
;Combo_Timer+2 and Combo_Value+2 are for luigi

Score_Slot = $04D5				;contains OAM slot for score sprite (either 0 or 8)
Score_Timer = $04D6				;2 bytes

GameOverStringTimer = $04F0
TESTYOURSKILLStringTimer = $04F0		;uses the same adress as above, which, to be fair, isn't needed in TEST YOUR SKILL phases (you can't get game over there)
PhaseStringTimer = $04F1			;for how long PHASE X string will be shown on string

WaveFireball_EnableSpawnTimer = $04F3

;yes, it's the same address, it's set during phase load, then repurposed into an actual timer
WaveFireball_SpawnTimerIndex = WaveFireball_EnableSpawnTimer

;InitEnemyFacing = $04F5
WavyFireball_AppearForPlayerPlatform = $04F6 	;track player's platform level, reset timer if differs
WavyFireball_AppearForPlayerTimer = $04F7
WavyFireball_AppearForPlayerFlag = $04F8

;$04F6 - WavyFireball_AppearForMarioPlatform
WavyFireball_AppearForMarioTimer = $04F7
WavyFireball_AppearForMarioFlag = $04F8

;$04F9 - WavyFireball_AppearForLuigiPlatform
WavyFireball_AppearForLuigiTimer = $04FA
WavyFireball_AppearForLuigiFlag = $04FB

ReflectingFireball_SpawnTimer = $04FC		;2 bytes, there can be up to two reflecting fireballs (??? I'm pretty sure there can be only 1)
ReflectingFireball_SpawnTimerIndex = $04FD
ReflectingFireball_SpawnTimerIndexModifier = $04FE ;IN THEORY, this is supposed to change how long it takes reflecting fireball to respawn after it disappears in the same phase. in practice, it has no effect.
ReflectingFireball_Timer = $04FF		;how long the fireball should stay on screen

RandomNumberStorage = $0500			;4 bytes

;Mario, Luigi and reflecting fireballs reserve two pairs of bytes, first pair is for VRAM position of the tile that the head is in, while second pair is a tile below the entity (like the platform they stand on)
;the second byte of each pair also gets overwritten with tile value at the same VRAM position, then stored to CurrentEntity addresses
;other entities only reserve one pair, since they don't have a ceiling collision, only the bottom tile they're intersecting is checked
Entity_VRAMPosition = $0520
Entity_VRAMTile = Entity_VRAMPosition			;the tile is stored in the same address as the position, it'll get refreshed on the next frama
;Entity_VRAMTileTop = Entity_VRAMPosition+1
;Entity_VRAMTileBottom = Entity_VRAMPosition+3

;secondary buffer for tiles, that transfers values into a main buffer. used for bump tiles animation and some strings.
BufferOffset2 = $0540				;now that I think of it this isn't used as offset the same way as common buffer. in fact, it can have just draw size and stuff (e.g. draw a 3x2 image)
BufferAddr2 = $0541				;

BufferOffset = $0590				;used to offset buffer position
BufferAddr = $0591				;buffer for tile drawing of unknown size.

Entity_InteractionSide = $05F7			;direction bits from which the interaction between two entities has occured (between player and another entity or two players). Format: UD----RL, U - up, D - down, L - left, R - right.
Entity_SavedMovementDir = $05F8			;used by sidestepper after being bumped once so it continues moving in the same direction it previously did
Entity_QuakeYPosOffset = $05F9			;when the POW is hit, the screen shakes, this is used to offset Y-position alongside the screen
;Entity_VRAMPositionIndex = $05FA
Entity_ComingOutOfLeftPipeFlag = $05FB		;is set when an entity is coming out of the left pipe
Entity_ComingOutofRightPipeFlag = $05FC		;is set when an entity is coming out of the right pipe

;$05FD - ??
;$05FE - ??
;$05FF - some sort of "disable control flag" that's set when players collide with each other?

Sound_JinglePlayingFlag = $06A2			;indicates if there's a jingle playing at the moment
Sound_Loop_Fireball_Length = $06C0		;how long the fireball sound is held for
Sound_Effect2_Step_Counter = $06F0		;counts up each time #Sound_Effect2_Step starts playing, to give each step a different tone
Sound_CurrentJingleID = $06F2			;indicates ID of the current jingle that's playing (detoned by bit number)

;$0700-$07FF - unused (these aren't even reset in a RAM clear loop)

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

;initial register values
Reg2000InitBits = %10010000
Reg2001InitBits = %00000110

;VRAM Write routine values, used as commands
VRAMWriteCommand_Repeat = $40			;bit 6 will make repeat writes of one value
VRAMWriteCommand_DrawVert = $80			;bit 7 - change drawing from horizontal line to vertical
VRAMWriteCommand_Stop = $00			;command to stop VRAM write and return from routine.

;controller input constants
Input_A = $80
Input_B = $40
Input_Select = $20
Input_Start = $10
Input_Up = $08
Input_Down = $04
Input_Left = $02
Input_Right = $01

;Sound values
;$FC
Sound_Loop_Timer = $04				;from TEST YOUR SKILL
Sound_Loop_Fireball = $08			;not necessarily a loop but the way wavy fireball produces it, it may as well be (though the diagonal one only makes it each time it hits the surface so its not a loop)

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

;some sound values that can change the way sound effects, well, sound
Sound_Timer_BasePitch = $34
Sound_Fireball_BasePitch = $FE

;used by demo screen
Demo_EndCommand = $AA

;Entity addresses' values
;CurrentEntity_MovementBits
Entity_MovementBits_MovingRight = $01
Entity_MovementBits_MovingLeft = $02
Entity_MovementBits_MovingHorz = Entity_MovementBits_MovingRight|Entity_MovementBits_MovingLeft
Entity_MovementBits_Skidding = $04		;exclusive to players
Entity_MovementBits_CantMove = $08		;used by players when they're squished or have respawned on a platform
Entity_MovementBits_Fall = $40
Entity_MovementBits_JumpBounce = $80		;entity jumped if bounced upward
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

;$B5
Entity_Draw_16x24 = 0				;used by mario and luigi
Entity_Draw_16x16 = 1				;used by coin effect (kinda popping effect that looks 16x16) and players when squished
Entity_Draw_8x16_AnimFlicker = 2		;this is used by by sidestepper, top tile flickers (what is this used by now that I think about it...)
Entity_Draw_8x16_FlickerTop = 3			;used by sidesteppers and fighterflies, they change top tile position every frame. (TO-DO: RENAME, not exactly accurate, at least in that it's not used by fighter flies) (ACTUALLY IT IS???!!!)
Entity_Draw_8x16_FlickerBottom = 4		;used by sidesteppers when flipped over, same as above, but it's the bottom tile that flickers
Entity_Draw_8x16 = 5				;8x16. used by coins, freezies and other effects
Entity_Draw_8x16_Shift = 6			;8x16 but the top tile is slightly shifted horizontally. used by Shellcreepers
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
GFX_CollectedCoin_Frame5 = $4D				;8x16 dollar

GFX_CollectedBonusCoin = $9E				;same tile as one of the fireball appear frames

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

GFX_Fireball_Pop1 = $9B				;pop IN or OUT
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
Entity_ID_Coin = $40				;moving coin after the enemy has been defeated
Entity_ID_Freezie = $80
Entity_ID_WavyFireball = $A0
Entity_ID_ReflectingFireball = $B0
Entity_ID_FloatingCoin = $F0			;TEST YOUR SKILL coin

;$C0
Entity_State_GotFlipped = $01
Entity_State_FlippedFalling = $02		;was just flipped by the player, currently in air
Entity_State_FlippedLanded = $03
Entity_State_SidestepperAngry = $04
Entity_State_Disappears = $06			;freezie and coin only
Entity_State_FlippedBack = $0F			;the enemy just got up from being flipped
Entity_BumpBits_BumpedCenter = $30
Entity_BumpBits_BumpedToTheRight = $10
Entity_BumpBits_BumpedToTheLeft = $20

;CurrentEntity_XSpeedTableOffset
PlayerXMovementData_Start = PlayerXMovementData-EntityXMovementData_F393
ShellcreeperXMovementData_Start = ShellcreeperXMovementData-EntityXMovementData_F393
SidestepperXMovementData_Start = SidestepperXMovementData-EntityXMovementData_F393
FreezieXMovementData_Start = ShellcreeperXMovementData_Start	;shared with turtles
CoinXMovementData_Start = ShellcreeperXMovementData_Start	;same as above

;States for entities
;$C6
Player_State_Dead = $01				;game over or init respawn platform
Player_State_AppearAfterDeath = $02
Player_State_Hurt = $10
Player_State_Splash = $20			;player turned into a splash after falling down

;Fireball states
Fireball_State_Appears = $01
Fireball_State_Disappears = $02
Fireball_State_Normal = $10

;CurrentEntity_DefeatedState
CurrentEntity_DefeatedState_Kicked = $10
CurrentEntity_DefeatedState_Splash = $20

Entity_Address_Size = $0020			;how many bytes does each entity use?

;various OAM slots
Cursor_OAM_Slot = 0				;
Cursor_Tile = $EE
Cursor_XPos = $38

Mario_OAM_Slot = 4
Luigi_OAM_Slot = 10

;players will take these slots during TEST YOUR SKILL bonus phases
MarioInTestYourSkill_OAM_Slot = 0		;respective player starting OAM slots
LuigiInTestYourSkill_OAM_Slot = 6

Freezie_Explosion_OAM_Slot = 44			;uses 2 slots = 2 tiles
Freezie_Explosion_Property = OAMProp_Palette3	;OAM prop
Freezie_Explosion_Frame1 = $68
Freezie_Explosion_Frame2 = $6A

FreezeEffect_OAM_Slot = 44			;those use 4 slots (2 tiles for 2 directions)
FreezeEffect_Tile1 = $8A
FreezeEffect_Tile2 = $8B
FreezeEffect_Property = OAMProp_Palette3

WavyFireball_OAM_Slot = 0
WavyFireball_Property = OAMProp_Palette1
WavyFireball_SpawnXPosLeft = $18		;x-positions for fireball's spawn, for both sides of the screen
WavyFireball_SpawnXPosRight = $E8

ReflectingFireball_OAM_Slot = 1
ReflectingFireball_Property = OAMProp_Palette2

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

Score_ForMarioPalette = OAMProp_Palette3
Score_ForLuigiPalette = OAMProp_Palette2

Score_ID_800 = $00
Score_ID_1600 = $01
Score_ID_2400 = $02
Score_ID_3200 = $03
Score_ID_200 = $04				;unused
Score_ID_500 = $05

RespawnPlatform_OAM_Slot = 48			;4 slots, 2 pairs for each player
RespawnPlatform_Tile1 = $CD
RespawnPlatform_Tile2 = $CE
RespawnPlatform_Tile3 = $CF

BonusCoinCount_OAM_Slot = 12			;this is for coins that show up on bonus coin count screen after a bonus phase
Coin_TopTile = $A5
Coin_BottomTile = $A6
Coin_DollarProp = OAMProp_Palette2

Splash_OAMProp = OAMProp_Palette3

;various VRAM tile defines
VRAMTile_Empty = $24				;empty tile of transparency
VRAMTile_Bricks = $92				;those bricks at the very bottom of the level
VRAMTile_PlatformBase = $93			;used as a base value for platforms, they have different look depending on how far you're in the game
VRAMTile_IcePlatform = $97			;to check for slippery slippydo

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