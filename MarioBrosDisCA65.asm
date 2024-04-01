;Mario Bros. (NES) Disassembly.
;not very well documented yet.
;But it's pretty much an accurate byte-to-byte MB. disassembly.
;
;(Almost) All ROM labels are going to be renamed from generic CODE_XXXX (or DATA_XXXX) to something more informative.
;Same goes for RAM addresses, to make it easy to understand on what specific address does in code.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "Defines.asm"				;load all defines for RAM addresses

;Set version with this define. Use one of the following arguments
;NTSC
;PAL
;Gamecube
;or you can use number 0-2 for respective version.

Version = NTSC

.segment "HEADER"
.include "iNES_Header.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "TILES"
.incbin "MarioBrosGFX.bin"			;graphics

.if Version = Gamecube
.segment "GCPADDING"
;there will be padding here...

;padding ends here
.segment "GCCODE"

Gamecube_CODE_BFD0:
   LDX NonGameplayMode				;check if loading the title screen
   BNE Gamecube_CODE_BFD7			;
   JMP CODE_C58E				;obviously, can't select options yet

Gamecube_CODE_BFD7:
   LDY Cursor_Option				;
   INY						;
   CMP #Input_Select				;if pressed select, cursor goes down (like in vanilla)
   BEQ Gamecube_CODE_BFEB			;
   CMP #Input_Down				;if pressed down on d-pad, cursor goes down (like in not vanilla but pretty much any game you can think of)
   BEQ Gamecube_CODE_BFEB			;
   DEY						;cursor will go up if...
   DEY						;
   CMP #Input_Up				;...if pressed up
   BEQ Gamecube_CODE_BFEB			;
   JMP CODE_C568				;

Gamecube_CODE_BFEB:
   CPX #$01					;
   BEQ Gamecube_CODE_BFF2			;are we on the title screen?
   JMP CODE_C561				;do return to the title screen

Gamecube_CODE_BFF2:
   LDA TitleScreen_SelectHeldFlag		;
   BEQ Gamecube_CODE_BFF9			;
   JMP CODE_C574				;

Gamecube_CODE_BFF9:
   TYA						;change selected option
   AND #$03					;
   TAY						;
   JMP CODE_C55C				;
.endif

.segment "CODE"
.include "CharacterSet.asm"			;this game's character set and special characters used in strings
.feature force_range				;allows -$xx expressions (for negative values)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Reset routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Obviously runs at reset, clearing adresses, disabling/enabling NES registers, and etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RESET_C000:
   CLD						;Disable Decimal Mode
   SEI						;set as interrupt

vblankloop_C002:
   LDA HardwareStatus				;V-blank loop 1 to waste some cycles
   BPL vblankloop_C002				;required to enable other PPU registers

   LDX #$00					;
   STX ControlBits				;disable non-masked interrupt
   STX RenderBits				;disable rendering
   DEX						;\
   TXS						;/initialize stack

   LDX POWHitsLeft				;load POW-block state for RNG setup (which could be any value after a different game)

   LDY #$06					;set up RAM clearing loop
   STY $01					;

   LDY #$00					;
   STY $00					;clear $6FF bytes (because of DEY and equal zero check)

   LDA #$00					;reset all those bytes

RAMResetLoop_C01D:
   STA ($00),y					;
   DEY						;
   BNE RAMResetLoop_C01D			;

   DEC $01					;
   BPL RAMResetLoop_C01D			;we set reset loop by setting high and low bytes for inderect adressing, and decrease high byte

   TXA						;if POW block is non-existant (hit three time)
   BNE CODE_C02B				;

   LDX #$5F					;start "RNG" loop at $5F

CODE_C02B:
   STX RandomNumberStorage			;otherwise it starts at 1, 2 or 3 depending on POW block state before reset

   JSR ClearScreenAndAttributesInit_CA1B	;clear screen(s) and attributes
   JSR RemoveSpriteTiles_CA2B			;no more sprite tiles

   LDY #$00					;load 00 into Y register....
   STA VRAMRenderAreaReg			;\initial camera position/no scroll
   STA VRAMRenderAreaReg			;/

   INY						;\increase Y register... but I'm sure LDY #$01 could've worked just fine.
   STY DemoFlag					;/initially demo flag is set

   LDA #$0F					;\enable all sound channels (except for DMC)
   STA APU_SoundChannels			;/

   LDA #Reg2000InitBits				;enable VBlank (NMI) and background
   STA ControlBits				;
   STA Reg2000BitStorage			;backup enabled bits

   LDA #Reg2001InitBits				;Bits 1 and 2 to be enabled for 2001
   STA Reg2001BitStorage			;which are "background left column enable" and "sprite left column enable"

CODE_C04F:
   LDA #$00					;reset frame window flag
   STA FrameFlag				;

   LDA DemoFlag					;if in actual gameplay (not title screen or demo recording)
   BEQ CODE_C05D				;always play sound effects

   LDA NonGameplayMode				;if not in title screen mode (demo recording, titlescreen/gameplay inits), don't play sounds
   CMP #$01					;
   BNE CODE_C060				;

CODE_C05D:
   JSR SoundEngine_F8A7				;sound engine

CODE_C060:
   JSR HandleGlobalTimers_CD88			;handle various timers
   JSR CODE_C4B8				;handle gamemodes

   LDA #$01					;
   STA NMI_FunctionsEnableFlag			;can run interrupt code safely

CODE_C06A:
   LDA FrameFlag				;if in frame hasn't passed
   BEQ CODE_C077				;do other things

   INC FrameCounter				;increase frame counter, well, every frame (duh)

   LDA #$00					;
   STA NMI_FunctionsEnableFlag			;Disable NMI functions
   JMP CODE_C04F				;run some routines that update things every frame, like sounds and stuff

CODE_C077:
   JSR RNG_D328					;randomize numbers in the mean time
   JMP CODE_C06A				;loop

NMI_C07D:
   PHA						;\usual stuff - save all registers
   TXA						;|
   PHA						;|
   TYA						;|
   PHA						;/because interrupt can, well, interrupt any process anytime, so we want to make sure we don't mess any registers we had

   LDA #$00					;\OAM DMA
   STA OAMAddress				;|
   LDA #$02					;|
   STA OAMDMA					;/

   LDA NMI_FunctionsEnableFlag			;don't screw anything up and skip everything in case it occured during lag (that could lead to bugs mostly due to changes in scratch RAM)
   BEQ CODE_C0AC				;

   JSR CODE_CB58				;get tiles the entities are overlapping (for potential bump check)
   JSR CODE_EE6A				;handles freezie's platform freezing
   JSR CODE_CCFF            			;handles buffered tile drawing
   JSR CODE_CA66            			;handle palette
   JSR CODE_CE09            			;keep camera still
   JSR CODE_CCC5            			;handle controllers
   JSR CODE_CAF7    				;handle entity timers and store tile values from their VRAM positions

   LDY #$01					;"Frame has passed" flag.
   STY FrameFlag				;

   DEY						;
   STY UpdateEntitiesFlag			;can't update entities unless we run through gameplay code

CODE_C0AC:
   LDA #$01					;"Was interrupted" flag, required to exit loop waiting for interrupt to happen
   STA InterruptedFlag				;

   PLA						;\restore all registers
   TAY						;|
   PLA						;|
   TAX						;|
   PLA						;/
   RTI						;exit interrupt

;interaction between bros
;$10 - movement bits for player 2
CODE_C0B6:
   LDA CurrentEntity_ActiveFlag			;if current entity (presumably Mario) isn't active, return 
   BEQ CODE_C0BF				;

   LDA Entity_Luigi_ActiveFlag			;if luigi is active, check collision between brothers?
   BNE CODE_C0C2				;

CODE_C0BF:
   JMP CODE_C149				;

CODE_C0C2:
   LDA #$20					;set up indirect addressing ($0320)
   STA $14					;

   LDA #$03					;
   STA $15					;

   LDA #$01					;check only one hitbox. it's mario/luigi
   STA $11					;

   LDY #$0B					;
   LDX #$08					;
   JSR CODE_C44A				;check interaction between players?
   STA Entity_InteractionSide			;store bits of side from which interaction occured
   ORA #$00					;ok?
   BEQ CODE_C149				;no interaction if zero

   LDA CurrentEntity_Player_State		;if both bros are in normal state, continue checking
   ORA Entity_Luigi_State			;
   BEQ CODE_C0F3				;
   TAX						;
   AND #$F0					;check if on of any high nibble bits enabled (indicates bro without interaction enabled aka dying)
   BNE CODE_C149				;
   TXA						;
   AND #$0F					;different states check
   CMP #$04					;if it's on small platform after death
   BEQ CODE_C0F3				;can interact
   CMP #$08					;if it's after being jumped on
   BNE CODE_C149				;if not, don't interact

CODE_C0F3:
   LDA #$00					;some flag?
   STA $05FE					;

   LDA Entity_Luigi_MovementBits		;
   STA $10					;save movement bits here
   AND #Entity_MovementBits_AirMovement		;check if player 2 is airborn
   BNE CODE_C152				;meaning the player is performing a jump (probably)

   LDA CurrentEntity_MovementBits		;check if the player 1 is airborn
   AND #Entity_MovementBits_AirMovement		;
   BNE CODE_C14F				;kinda cancel that jump

   LDA CurrentEntity_MovementBits		;then check direction
   AND #Entity_MovementBits_MovingHorz		;
   BEQ CODE_C15E				;if player 1 isn't moving, k

   LDA $10					;check if player 2's also moving
   AND #Entity_MovementBits_MovingHorz		;
   BEQ CODE_C161				;no, they aren't

   JSR CODE_C3A0				;currently unknown

   LDA $10					;if both players have pressed left or right
   AND #Entity_MovementBits_MovingHorz		;(i think this is bumping into each other when moving)
   EOR CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_MovingHorz		;
   BEQ CODE_C13E				;if not, player don't bump into each other, do pushing

   LDA $05F7					;
   AND #$0F					;
   CMP #$02					;check if collided from the right...
   BEQ CODE_C12E				;

   LDA CurrentEntity_MovementBits		;otherwise mario's on the left
   JMP CODE_C130				;check player 1 direction first

CODE_C12E:
   LDA $10					;check player 2 direction first

CODE_C130:
   LSR A					;check if direction pressed is right
   BCC CODE_C149				;if not, return

   LDA CurrentEntity_XSpeedTableEntry		;probably speed, maybe
   CMP Entity_Luigi_XSpeedTableEntry		;bumped into each other with the same speed
   BEQ CODE_C15B				;
   BCS CODE_C158				;if mario's speed was higher, different kind of bump
   BCC CODE_C155				;

CODE_C13E:
   LDA Entity_Luigi_XSpeedTableEntry		;check if same speed stuffs for both players
   CMP CurrentEntity_XSpeedTableEntry		;
   BEQ CODE_C164				;
   BCS CODE_C155				;
   BCC CODE_C158				;

CODE_C149:
   LDA #$00
   STA $05FF
   RTS

CODE_C14F:
   JMP CODE_C196

CODE_C152:
   JMP CODE_C1C3

CODE_C155:
   JMP CODE_C22D

CODE_C158:
   JMP CODE_C2AD

CODE_C15B:
   JMP CODE_C334

CODE_C15E:
   JMP CODE_C35B

CODE_C161:
   JMP CODE_C37D

CODE_C164:
   LDA CurrentEntity_MovementBits		;check if both players are skidding
   ORA Entity_Luigi_MovementBits		;
   AND #Entity_MovementBits_Skidding		;
   BNE CODE_C193				;i think this checks if both are grounded?

   LDX #$01					;speed
   LDY #$03					;movement frequency

   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_MovingHorz		;
   STA $1D					;

   LDA $05F7
   AND #$03
   CMP $1D
   BNE CODE_C189
   STX CurrentEntity_XSpeed
   STY CurrentEntity_UpdateTimer
   DEX
   STX CurrentEntity_XSpeedTableEntry
   BEQ CODE_C193

CODE_C189:
   STX Entity_Luigi_XSpeed			;x-speed
   STY Entity_Luigi_UpdateTimer			;
   DEX						;
   STX Entity_Luigi_XSpeedTableEntry		;
   
CODE_C193:
   JMP CODE_C149

CODE_C196:
   JSR CODE_C3A0

   LDA $10
   AND #Entity_MovementBits_AirMovement
   BEQ CODE_C158

;if player 2 while jumping hits player 1 who falls down
CODE_C19F:
   LDA $05F7
   ASL A
   BCS CODE_C1CE

   LDA Entity_Luigi_YPos			;check by how much Luigi is lower than Mario
   SEC						;
   SBC CurrentEntity_YPos			;
   CMP #$0B					;not much lower
   BCC CODE_C221				;

   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_MovingHorz		;
   BNE CODE_C212				;is Mario moving horizontally

   LDA $10					;
   AND #Entity_MovementBits_MovingHorz		;
   BNE CODE_C221				;

   LDA #Entity_MovementBits_MovingRight		;mario will move to the right (because neither player is moving horizontally and we don't want a softlock)
   ORA CurrentEntity_MovementBits		;
   STA CurrentEntity_MovementBits		;
   BNE CODE_C212				;

CODE_C1C3:
   JSR CODE_C3A0

   LDA CurrentEntity_MovementBits		;Mario airborn?
   AND #Entity_MovementBits_AirMovement		;
   BEQ CODE_C155				;
   BNE CODE_C19F				;

;if player 1 while jumping hits player 2 who falls down
CODE_C1CE:
   LDA CurrentEntity_YPos			;check by how much Mario is lower than Luigi
   SEC						;
   SBC Entity_Luigi_YPos			;
   CMP #$0B					;
   BCC CODE_C221				;

   LDA $10					;check if Luigi is moving horizontally
   AND #Entity_MovementBits_MovingHorz		;
   BNE CODE_C212				;

   LDA CurrentEntity_MovementBits		;check if Mario is moving horizontally
   AND #Entity_MovementBits_MovingHorz		;
   BNE CODE_C221				;

   LDA #Entity_MovementBits_MovingRight		;same shenanigan as before, Luigi will move out of the way
   ORA $10					;
   STA $10					;
   BNE CODE_C212				;

CODE_C1EC:
   LDA CurrentEntity_MovementBits		;
   AND #$FF^Entity_MovementBits_MovingHorz	;
   ORA $1F					;
   STA Entity_Luigi_MovementBits		;

   LDA $10					;
   AND #$FF^Entity_MovementBits_MovingHorz	;
   ORA $1E					;
   STA CurrentEntity_MovementBits		;

;swap speed pointers for both players
;e.g. if luigi bounced mario while luigi were moving up and mario down, mario will get Luigi's upward boost, and luigi will get mario's downward speed
CODE_C1FD:
   LDX CurrentEntity_UpdateDataPointer		;Mario's speed pointer
   LDY CurrentEntity_UpdateDataPointer+1	;

   LDA Entity_Luigi_UpdateDataPointer		;luigi's (speed) pointer is now mario's
   STA CurrentEntity_UpdateDataPointer		;

   LDA Entity_Luigi_UpdateDataPointer+1		;
   STA CurrentEntity_UpdateDataPointer+1	;

   STX Entity_Luigi_UpdateDataPointer		;mario's is luigi's
   STY Entity_Luigi_UpdateDataPointer+1		;
   RTS						;

CODE_C212:
   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_MovingHorz		;
   STA $1E					;

   LDA $10					;
   AND #Entity_MovementBits_MovingHorz		;
   STA $1F					;

   JMP CODE_C1EC				;

CODE_C221:
   LDA CurrentEntity_MovementBits		;sharing is caring as they say.
   STA Entity_Luigi_MovementBits		;mario gives luigi their movement bits

   LDA $10					;mario receives new movement bits
   STA CurrentEntity_MovementBits		;
   JMP CODE_C1FD				;

CODE_C22D:
   JSR CODE_C41F
   DEY
   BEQ CODE_C282
   DEY
   BEQ CODE_C23C

CODE_C236:
   LDX #Entity_MovementBits_Skidding|Entity_MovementBits_MovingLeft
   LDY #Entity_MovementBits_Fall|Entity_MovementBits_MovingRight
   BNE CODE_C286				;

CODE_C23C:
   LDA CurrentEntity_YPos			;check if mario is above or below luigi
   CMP Entity_Luigi_YPos			;
   BCS CODE_C24B				;

   LDA Entity_InteractionSide
   LSR A
   BCS CODE_C236
   BCC CODE_C282

;Play player squishing animation (Mario)
CODE_C24B:
   LDA #Entity_Draw_16x16			;draw 16x16
   STA CurrentEntity_DrawMode			;

   LDA CurrentEntity_OAMOffset			;Mario's OAM offset
   JSR CODE_C3F5				;remove top 2 tiles, since squishing animation is 16x16

   LDA #GFX_Player_Squish1			;
   STA CurrentEntity_DrawTile			;

   LDA CurrentEntity_MovementBits		;cant move!
   ORA #Entity_MovementBits_CantMove		;
   STA CurrentEntity_MovementBits		;

   LDA #$2F					;
   STA CurrentEntity_Player_SquishingTimer	;timer for squishing animation

   LDA $10					;will make luigi bounce up
   AND #Entity_MovementBits_Fall|Entity_MovementBits_MovingHorz
   CMP #Entity_MovementBits_Fall		;check if luigi is NOT moving in any horizontal direction while bouncing off mario
   BNE CODE_C26E

   LDA #Entity_MovementBits_MovingRight		;force them to bounce to the right
   STA $10					;

CODE_C26E:
   LDA $10					;
   AND #Entity_MovementBits_MovingHorz		;
   ORA #Entity_MovementBits_JumpBounce		;bounce up
   STA Entity_Luigi_MovementBits		;

   LDA #<DATA_F350				;Upward momentum for Luigi
   LDY #>DATA_F350				;

CODE_C27B:
   STA Entity_Luigi_UpdateDataPointer		;haha, luigi go boing
   STY Entity_Luigi_UpdateDataPointer+1		;
   RTS						;

;luigi touches mario from side while airborn
CODE_C282:
   LDX #Entity_MovementBits_Skidding|Entity_MovementBits_MovingRight
   LDY #Entity_MovementBits_Fall|Entity_MovementBits_MovingLeft

CODE_C286:
   STY Entity_Luigi_MovementBits		;

   LDA CurrentEntity_MovementBits		;check if mario can move in any way
   AND #Entity_MovementBits_CantMove		;
   BNE CODE_C2A7				;don't push him
   STX CurrentEntity_MovementBits		;push a little to the right
   JSR CODE_C3E3				;

   LDA CurrentEntity_XSpeedTableEntry		;
   STA $00					;

   LDA CurrentEntity_TileAtBottomVRAMPos	;
   STA $01					;

   JSR CODE_C3C2				;
   STA CurrentEntity_Player_MovementTimer	;

   LDA $00					;
   BEQ CODE_C2A7				;
   STA CurrentEntity_AnimationPointer		;

CODE_C2A7:
   LDA #<DATA_F33A				;$3A
   LDY #>DATA_F33A				;$F3

CODE_C2AB:
   BNE CODE_C27B

CODE_C2AD:
   JSR CODE_C429
   DEY
   BEQ CODE_C304
   DEY
   BEQ CODE_C2BC

CODE_C2B6:
   LDX #Entity_MovementBits_Skidding|Entity_MovementBits_MovingLeft
   LDY #Entity_MovementBits_Fall|Entity_MovementBits_MovingRight
   BNE CODE_C308

CODE_C2BC:
   LDA Entity_Luigi_YPos			;check if Luigi is lower than Mario
   CMP CurrentEntity_YPos			;
   BCS CODE_C2CB				;

   LDA $05F7					;
   LSR A					;
   BCS CODE_C304 
   BCC CODE_C2B6

;play squishing animation (Luigi)
CODE_C2CB:
   LDA #Entity_Draw_16x16			;
   STA Entity_Luigi_DrawMode			;

   LDA Entity_Luigi_OAMOffset			;remove top 2 tiles
   JSR CODE_C3F5				;

   LDA #GFX_Player_Squish1			;
   STA Entity_Luigi_DrawTile			;

   LDA $10					;
   ORA #Entity_MovementBits_CantMove		;luigi is being squished, no time for movement
   STA Entity_Luigi_MovementBits		;

   LDA #$2F					;squish animation time
   STA Entity_Luigi_SquishingTimer		;

   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_MovingHorz|Entity_MovementBits_Fall
   CMP #Entity_MovementBits_Fall		;checks if mario is falling without actually moving anywhere
   BNE CODE_C2F3				;if they do, continue on their was

   LDA #Entity_MovementBits_MovingRight		;move it! so the players aren't stuck bouncing in place and getting squished repeatidly
   STA CurrentEntity_MovementBits		;

;player bounced off luigi
CODE_C2F3:
   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_MovingHorz		;
   ORA #Entity_MovementBits_JumpBounce		;mario bounced up
   STA CurrentEntity_MovementBits		;

   LDA #<DATA_F350				;upward momentum for Mario
   LDY #>DATA_F350				;

CODE_C2FF:
   STA CurrentEntity_UpdateDataPointer		;haha, mario go boing
   STY CurrentEntity_UpdateDataPointer+1	;
   RTS						;

CODE_C304:
   LDX #Entity_MovementBits_Skidding|Entity_MovementBits_MovingRight
   LDY #Entity_MovementBits_Fall|Entity_MovementBits_MovingLeft

CODE_C308:
   STY CurrentEntity_MovementBits		;mario's movement

   LDA Entity_Luigi_MovementBits
   AND #Entity_MovementBits_CantMove		;check if luigi is immovable
   BNE CODE_C32E
   STX Entity_Luigi_MovementBits		;luigi's

   JSR CODE_C3E3				;

   LDA Entity_Luigi_XSpeedTableEntry		;
   STA $00					;

   LDA Entity_Luigi_TileAtBottomVRAMPos		;
   STA $01					;

   JSR CODE_C3C2				;make Luigi skid (maybe)
   STA Entity_Luigi_MovementTimer		;

   LDA $00					;
   BEQ CODE_C32E				;
   STA Entity_Luigi_AnimationPointer		;luigi will skid

CODE_C32E:
   LDA #<DATA_F33A				;
   LDY #>DATA_F33A				;
   BNE CODE_C2FF				;

CODE_C334:
   LDA CurrentEntity_MovementBits		;both playes will skid & move away from each other
   ORA #Entity_MovementBits_Skidding		;
   STA Entity_Luigi_MovementBits		;this is for luigi

   LDA $10					;same for mario
   ORA #Entity_MovementBits_Skidding		;
   STA CurrentEntity_MovementBits		;

   LDA CurrentEntity_XSpeedTableEntry		;save mario's X-speed table entry
   STA $00					;

   LDA CurrentEntity_TileAtBottomVRAMPos	;i don't know what this is
   STA $01					;

   JSR CODE_C3C2				;
   STA CurrentEntity_Player_MovementTimer	;
   STA Entity_Luigi_MovementTimer		;

   LDA $00					;
   BEQ CODE_C35A				;
   STA CurrentEntity_AnimationPointer		;
   STA Entity_Luigi_AnimationPointer		;both players will skid

CODE_C35A:
   RTS						;

CODE_C35B:
   JSR CODE_C41F				;

   LDA $10					;
   AND #Entity_MovementBits_MovingHorz		;
   DEY						;
   BEQ CODE_C376				;
   CMP #Entity_MovementBits_MovingLeft		;
   BNE CODE_C37A				;

CODE_C369:
   LDA #PlayerSkiddingAnimCycle_Start		;Mario gets bumped by Luigi
   STA CurrentEntity_AnimationPointer		;

   LDX #$10					;
   LDY #$0D					;
   LDA $10					;
   JMP CODE_C402				;

CODE_C376:
   CMP #Entity_MovementBits_MovingRight		;
   BEQ CODE_C369				;

CODE_C37A:
   JMP CODE_C3A8				;

CODE_C37D:
   JSR CODE_C429				;check which side we're pushing from, i think

   LDA CurrentEntity_MovementBits		;horizontal direction
   AND #Entity_MovementBits_MovingHorz		;
   DEY						;
   BEQ CODE_C399				;
   CMP #Entity_MovementBits_MovingLeft		;
   BNE CODE_C39D				;

CODE_C38B:
   LDA #$06					;
   STA Entity_Luigi_AnimationPointer		;show luigi as skidding

   LDX #$0D					;movement timers
   LDY #$10					;luigi's longer
   LDA CurrentEntity_MovementBits		;
   JMP CODE_C402				;

CODE_C399:
   CMP #Entity_MovementBits_MovingRight		;
   BEQ CODE_C38B				;

CODE_C39D:
   JMP CODE_C3A8				;

CODE_C3A0:
   LDA $05FF					;check some interaction flag
   BEQ CODE_C3A8				;
   PLA						;stop any further interaction
   PLA						;
   RTS						;

CODE_C3A8:
   LDY #$00					;
   STY CurrentEntity_Player_BumpedBits		;not bumped, thats for sure
   STY Entity_Luigi_BumpedBits			;also for luigi
   INY						;
   STY $05FF					;enable this...

   LDY CurrentEntity_Player_SquishingTimer	;being squishy?
   BNE CODE_C3B9				;not sure if this check is necessary. if it's zero, we store zero? (because of LDA before required to be zero)
   STA CurrentEntity_Player_SquishingTimer	;

CODE_C3B9:
   LDY Entity_Luigi_SquishingTimer		;same for luigi
   BNE CODE_C3C1				;
   STA Entity_Luigi_SquishingTimer		;

CODE_C3C1:
   RTS						;

;set player's animation cycle and timing when stopping the movement
;input:
;$00 - x-speed table entry
;$01 - tile below the entity (CurrentEntity_TileAtBottomVRAMPos)
;output:
;A - timer before stopping the movement
;$00 - animation pointer (either for skidding cycle or walking
CODE_C3C2:
   LDA $01					;check if the player is standing on a frozen tile
   CMP #VRAMTile_IcePlatform			;
   BEQ CODE_C3DC				;what a slip-up!

   LDA $00					;check if was fast enough
   CMP #$02					;
   BNE CODE_C3D5				;

   LDA #PlayerSkiddingAnimCycle_Start		;WILL skid!
   STA $00					;

   LDA #$08					;skid for a little bit
   RTS						;

CODE_C3D5:
   LDA #PlayerRunningAnimCycle_Start		;not fast enough/not on ice, no skidding
   STA $00					;

   LDA #$05					;standstill after this amount of frames
   RTS						;

CODE_C3DC:
   LDA #PlayerSkiddingAnimCycle_Start		;will skid on ice, naturally
   STA $00					;

   LDA #$1C					;skid for a while
   RTS						;

CODE_C3E3:
   LDA CurrentEntity_XSpeedTableEntry		;\swap speed modifiers
   PHA						;|
   LDA Entity_Luigi_XSpeedTableEntry		;|luigi with mario and mario with luigi
   STA CurrentEntity_XSpeedTableEntry		;|
   PLA						;|
   STA Entity_Luigi_XSpeedTableEntry		;/

   LDA #$01					;\slow down luigi (I GUESS??)
   STA $05FD					;|
   RTS						;/

;remove two OAM sprite tiles, input A for OAM offset, with $10 to be added
CODE_C3F5:
   CLC						;
   ADC #$10					;
   TAY						;
   LDA #$F4					;hide
   STA OAM_Y,y					;
   STA OAM_Y+4,y				;
   RTS						;

;input:
;X - Mario's movement timer
;Y - Luigi's movement timer
;A - Entity Bits (player movements)
CODE_C402:
   AND #Entity_MovementBits_MovingHorz		;
   ORA #Entity_MovementBits_Skidding		;
   STA CurrentEntity_MovementBits		;so the players can't change move themselves for a little bit
   STA Entity_Luigi_MovementBits		;both Mario and Luigi
   STX CurrentEntity_Player_MovementTimer	;movement timer
   STY Entity_Luigi_MovementTimer		;

   LDY #$00					;
   STY CurrentEntity_XSpeedTableEntry		;no skidding turning
   STY Entity_Luigi_XSpeedTableEntry		;
   STY $05FE					;unknown flag that seems to be unused...
   INY						;
   STY $05FD					;no more interaction, a'ight?
   RTS						;

;get horizonal difference between mario and luigi or luigi and mario in that order
CODE_C41F:
   LDA Entity_Luigi_XPos			;horizontal difference (difference between luigi and mario
   STA $1F					;

   LDA CurrentEntity_XPos			;
   JMP CODE_C430				;

CODE_C429:
   LDA CurrentEntity_XPos			;get horizontal difference (mario vs. luigi)
   STA $1F					;
   LDA Entity_Luigi_XPos			;

CODE_C430:
   SEC						;
   SBC $1F					;
   BPL CODE_C43C				;check if on the left
   CMP #$FB					;if it's on the right, check how much of a difference
   BCS CODE_C440				;

   LDY #$03					;
   RTS						;

CODE_C43C:
   CMP #$05					;
   BCS CODE_C443				;

CODE_C440:
   LDY #$02					;
   RTS						;

CODE_C443:
   LDY #$01					;
   RTS						;

;Collision routine. Entity A refers to currently loaded entity in CurrentEntity_Address range, and entity B is in indirect addressing.
;output A: if zero, no interaction, otherwise the output is the direction from which the contact had occured
CODE_C446:
   LDY #$00					;
   LDX #$00					;

CODE_C44A:
   STY $1C					;
   STX $1D					;

   LDA #<Entity_Address_Size			;size for each entity
   STA $12					;

   LDA #>Entity_Address_Size			;
   STA $13					;

CODE_C456:
   LDY #$00					;CurrentEntity_ActiveFlag-CurrentEntity_Address
   LDA ($14),y					;if entity isn't active, can't collide
   BEQ CODE_C4AE				;

   LDX #$40					;set bottom bit by default (D)
   LDY #$08					;CurrentEntity_YPos-CurrentEntity_Address (should be CurrentEntity_YPos... but obviously for not current entity)
   LDA ($14),y					;check vertical difference between entities
   SEC						;
   SBC CurrentEntity_YPos			;
   BPL CODE_C46E				;
   EOR #$FF					;entity A is higher than B
   CLC						;
   ADC #$01					;invert value
   LDX #$80					;and set as collided from the top (U)

CODE_C46E:
   STX $1F					;

   PHA						;preserve calculated distance between both entities
   LDY #$1E					;CurrentEntity_HitBoxHeight-CurrentEntity_Address
   LDA ($14),y					;entity B's hit box y-displacement.
   CLC						;
   ADC CurrentEntity_HitBoxHeight		;entity A's hit box y-displacement.
   ADC $1D					;additional height, input into this routine
   STA $1E					;summed entity A and B's heights.
   PLA						;

   SEC						;
   SBC $1E					;
   BPL CODE_C4AE				;didn't even intercect vertically? NEXT!!

   LDX #$01					;Left (L)
   LDY #$09					;now X-pos
   LDA ($14),y					;
   SEC						;
   SBC CurrentEntity_XPos			;check horizontal difference
   BPL CODE_C494				;entity A's to the left of entity B.
   EOR #$FF					;
   CLC						;
   ADC #$01					;
   LDX #$02					;right (R)

CODE_C494:
   PHA						;

   TXA						;
   ORA $1F					;store direction bits
   STA $1F					;

   LDY #$1F					;CurrentEntity_HitBoxWidth-CurrentEntity_Address
   LDA ($14),y					;W I D E
   CLC						;
   ADC CurrentEntity_HitBoxWidth		;
   ADC $1C					;additional width, if applicable
   STA $1E					;entity A's hitbox width + entity B's hitbox width
   PLA						;

   SEC						;
   SBC $1E					;
   BPL CODE_C4AE				;did not collide horizontally?

   LDA $1F					;if both Y and x positions match, collision test is successfull.
   RTS						;

CODE_C4AE:
   JSR CODE_CDB4				;next entity B

   DEC $11					;
   BNE CODE_C456				;loop untill all is checked

   LDA #$00					;no collision occured
   RTS						;

CODE_C4B8:
   LDA DemoFlag					;\if it's title screen and demo time
   BNE CODE_C528				;/don't run gameplay (or do, but from different pointers)

   LDA Controller1InputHolding			;\if start button is pressed, start game
   AND #Input_Start				;|
   BEQ CODE_C507				;/

   LDY Pause_HeldPressed			;\prevent start from pausing/unpausing when it's held (only when pressed)
   BNE CODE_C50B				;/

   INY						;\no INC Pause_HeldPressed? Sad day
   STY Pause_HeldPressed			;/

   LDY GameplayMode				;if game was paused
   CPY #$05					;
   BEQ CODE_C4F9				;unpause
   CPY #$04					;
   BEQ CODE_C4D7				;if just paused, do things
   CPY #$06					;
   BNE CODE_C50B				;otherwise run like normal

CODE_C4D7:
   LDX #$05					;setup loop for some timers

CODE_C4D9:
   LDA TimerBase,X				;\
   STA TimerBackup,X				;/back-up timers
   DEX						;
   BPL CODE_C4D9				;loop

   LDA Reg2001BitStorage			;\
   AND #$0E					;|don't show sprites (this also filters color emphasis and greyscale mode, as they're normally unused)
   STA RenderBits				;|
   STA Reg2001BitStorage			;/

   STY GameplayModeNext				;back-up gamemode

   LDA #$05					;\gamemode = paused
   STA GameplayMode				;/

   LDA #$00					;\disable some sound effects
   STA Sound_Effect2				;|
   STA Sound_Effect				;|
   STA Sound_Loop				;/
   BEQ CODE_C501				;play pause sound effect

CODE_C4F9:
   LDA #$14					;\unpause timer
   STA TimerBase2				;/

   LDA #$0A					;\unpause game
   STA GameplayMode				;/

CODE_C501:
   LDA #Sound_Jingle_Pause			;\play pause sound effect
   STA Sound_Jingle				;/
   BNE CODE_C50B				;run gamemode

CODE_C507:
   LDA #$00					;player can press start
   STA Pause_HeldPressed			;

CODE_C50B:
   LDA GameplayMode				;another gamemode pointer? this time for actual gameplay
   JSR ExecutePointers_CD9E			;

DATA_C510:
   .word CODE_D34A				;gameplay init
   .word CODE_E14A				;determine Phase number and if it's a "Test Your Skill!" Area
   .word CODE_D3F9				;more init - sets Game A or B flag and enables gameplay palette flag
   .word CODE_D3A8				;even more init, with some flags being cleared

   .word CODE_C5A3				;actual gameplay!
   .word CODE_D5E5				;paused (return)
   .word CODE_E453				;coin counting after "Test Your Skill!" phase
   .word CODE_D5E5				;return

   .word CODE_D451				;game start
   .word CODE_E129				;wait for next phase to begin/to take coin count for TEST YOUR SKILL
   .word CODE_D45C				;unpause
   .word CODE_E28B				;game over

CODE_C528:
   LDA Controller1InputHolding			;
.if Version = Gamecube				;count ups and downs in the gamecube version (modernize selecting options on the title screen)
   AND #Input_Select|Input_Start|Input_Up|Input_Down
.else
   AND #Input_Select|Input_Start		;
.endif
   CMP #Input_Start				;if player pressed start, start the game
   BNE CODE_C543				;

   LDA #$00					;\
   STA DemoFlag					;|reset demo flag
   STA GameplayMode				;/initialize gameplay

   JSR MuteSounds_D4FE				;
   JSR DisableRender_E132			;

   LDA #$02					;
   STA TimingTimer				;quit demo
   STA TransitionTimer				;
   RTS						;

CODE_C543:
.if Version = Gamecube
   JMP Gamecube_CODE_BFD0			;a hijack
   NOP						;
.else
   LDX NonGameplayMode				;\if it's title screen init
   BEQ CODE_C58E				;/don't check things
.endif
   CMP #Input_Select                 		;\check if pressed select
   BNE CODE_C568                		;/
   CPX #$01                 			;\if select was pressed, but it's not a title screen
   BNE CODE_C561				;/return to title screen

   LDA TitleScreen_SelectHeldFlag 		;don't repeatidly move cursor (if holding select)
   BNE CODE_C574				;

   LDY Cursor_Option				;move cursor 
   INY						;
   CPY #$04                 			;
   BNE CODE_C55C				;

   LDY #$00					;if cursor was on last entry, wrap around

CODE_C55C:
   STY Cursor_Option				;cursor's position
   JMP CODE_C570				;

CODE_C561:
   JSR MuteSounds_D4FE				;mute sounds (not that they play during demo anyways...)

   STA NonGameplayMode				;initialize title screen
   BEQ CODE_C58E				;

CODE_C568:
   CMP #$00					;if we pressed select
   BNE CODE_C570				;move only once per press

   STA TitleScreen_SelectHeldFlag 		;if not holding/pressing select anymore, can move again
   BEQ CODE_C57E				;

CODE_C570:
   LDA #$01					;can't move cursor
   STA TitleScreen_SelectHeldFlag 		;

CODE_C574:
   LDA TransitionTimer				;keep timer if moving cursor
   CMP #$25					;(when song plays out)
   BCS CODE_C57E				;

   LDA #$25					;keep the timer
   STA TransitionTimer				;

CODE_C57E:
   CPX #$01					;\don't handle cursor if it's not title screen
   BNE CODE_C58E				;/

   LDA Cursor_Option				;\handle cursor's position
   ASL A					;|
   ASL A					;|
   ASL A					;|
   ASL A					;|
   CLC						;|
   ADC #$80					;|
   STA Cursor_OAM_Y				;/

CODE_C58E:
   LDA NonGameplayMode  			;\execute some              
   JSR ExecutePointers_CD9E			;/

;Title screen and demo pointers
;those run until we press start to start the game
DATA_C593:
   .word CODE_D40B				;loading title screen
   .word CODE_D47D				;title screen
   .word CODE_D491				;initialize demo
   .word CODE_D496				;more init
   .word CODE_D49B				;build phase (and more initialization)
   .word CODE_D4A0				;enable screen display
   .word CODE_D4AF				;playing title screen demo recording (or actual gameplay?)
   .word CODE_D448				;reset pointer

CODE_C5A3:
.if Version = PAL
   JSR PAL_CODE_C5DE				;alter speed of fireballs and players
.endif
   JSR CODE_D56E				;spawn enemy entities if needed
   JSR CODE_D202				;handle bumping tiles
   JSR CODE_D301				;apply POW's screen shake if needed
   JSR HandlePlayerEntities_C5DB		;run players coding
   JSR CODE_C66A				;process entities (other than player)
   JSR CODE_E783				;transfer entities per-platform counters
   JSR CODE_EA31				;handle reflecting fireball
   JSR CODE_E795				;handle wavy fireball
   JSR CODE_EDEB				;run platform freezing effect
   JSR CODE_E2AB				;TEST YOUR SKILL related?
   JSR CODE_E21A				;handle 1-up score reward and TOP score update
   JSR CODE_E1F7				;store score to buffer
   JSR CODE_DFF8				;handle drawing/removing GAME OVER string and removing PHASE string
   JSR CODE_E1CE				;handle phase transition (after all enemies have been defeated)
   JSR CODE_E26D				;handle game overs
   JSR CODE_E709				;handle combo and fireball timers
   JSR CODE_EF32				;run score sprites' timers

   LDA #$01					;
   STA UpdateEntitiesFlag			;can update entity variables (for NMI)
   RTS						;

.if Version = PAL
PAL_CODE_C5DE:
   DEC PAL_SpeedAlterationTimer			;tick this special speed-altering timer
   BPL PAL_CODE_C5E6				;

   LDA #$03					;
   STA PAL_SpeedAlterationTimer			;refresh this mysterious variable

PAL_CODE_C5E6:
   RTS						;
.endif

HandlePlayerEntities_C5DB:
   LDA #<Entity_Address				;
   STA $A0					;

   LDA #>Entity_Address				;
   STA $A1					;

   LDA #$02					;2 players to process
   STA $33					;

   LDA #$00					;
   STA $A2					;
   STA Entity_VRAMPositionIndex			;

   LDA Controller1InputPress			;mario's control inpits
   STA Entity_Mario_ControllerInputs		;

   LDA Controller2InputPress			;luigi's control inputs
   STA Entity_Luigi_ControllerInputs		;

CODE_C5F8:
   JSR CODE_CB9B				;copy to current entity addresses (Entity_Address->CurrentEntity_Address)

   LDA CurrentEntity_ActiveFlag			;is the player active?
   BNE CODE_C605				;if so, do the normal player stuff

   JSR SkipPlayerVRAMPosition_DFBA		;move onto next player's VRAM alignment stuff
   JMP CODE_C65D				;next player

CODE_C605:
   JSR CODE_D019				;get the platform level for the player

   LDX CurrentEntity_CurrentPlatform		;
   INC EntitiesPerPlatform,X			;player is like 2 entities in one I suppose
   INC EntitiesPerPlatform,X			;

   LDA CurrentEntity_Player_State		;
   BEQ CODE_C636				;
   AND #$F0					;10 to F0 - got hurt
   BNE CODE_C629				;

;CurrentEntity_Player_State = 01 through 0F
   LDA PhaseCompleteFlag			;did we win???
   BNE CODE_C62C				;if so, skip stuff

   JSR CODE_DEEC				;respawn procedures

   LDA CurrentEntity_Player_State		;check if escaped the respawn platform or something
   BEQ CODE_C636				;
   AND #Players_State_OnRespawnPlatform		;on reaspawn platform (the platform slowly disappears)
   BNE CODE_C636				;if any is enabled, some other stuff
   BEQ CODE_C62C				;

CODE_C629:
   JSR CODE_DDE0				;run hurt player (freeze, fall down, splash)

CODE_C62C:
   JSR SkipPlayerVRAMPosition_DFBA		;won't process tiles, prepare next player/entity's index for VRAM alignment
   JMP CODE_C657				;skip over all tile-related matters

   LDA PhaseCompleteFlag			;
   BNE CODE_C62C				;these can't be executed. probably a copy-paste mistake... or actually a branch mistake, but maybe it was intentional? there's one more winning state check further

CODE_C636:
   LDA $33					;check if we're processing Mario
   CMP #$02					;
   BNE CODE_C63F				;only mario is allowed to collide with luigi

   JSR CODE_C0B6				;only run player<->player collision once and only for Mario 

CODE_C63F:
   LDA $05FD					;probably indicates that the players collided...
   BEQ CODE_C647

   JSR CODE_CAB9				;player physics?

CODE_C647:   
   LDA PhaseCompleteFlag			;are ya winning, son?
   BNE CODE_C62C				;if so, some kinda timer thing again. man they really want to check you winning

   JSR CODE_D6BA				;handle various states
   JSR CODE_C785				;movement related
   JSR Player_CalculateVRAMPosForBump_CC3F	;calculate player's VRAM position for bumpy action
   JSR CODE_DC75				;handle interaction with other entities (like enemies)

CODE_C657:
   JSR CODE_CBC4				;player graphics
   JSR CODE_CBB6				;store current entity address values back into entity's actual addresses (CurrentEntity_Address->Entity_Address)

CODE_C65D:
   JSR CODE_CBAE				;next entity addresses (Luigi)

   DEC $33					;player loop
   BNE CODE_C5F8				;run 2nd player

   LDA #$00					;set this to 0...
   STA $05FD					;
   RTS						;

CODE_C66A:
   LDA EnemiesOnScreen				;can update if this flag is set (are there any entities to speak of?
   BNE CODE_C66F				;
   RTS						;

CODE_C66F:
   STA $45					;backups...
   STA $44					;
   STA $33					;

   LDA #<Entity_Address+$60			;
   STA $A0					;

   LDA #>Entity_Address				;
   STA $A1					;

   LDA #$00					;
   STA $A2					;

   LDA #$0D					;
   STA Entity_VRAMPositionIndex			;skip over players and reflecting fireball for VRAM checks

EntityProcessingLoop_C686:
   JSR CODE_CB9B				;copy to current entity addresses (CurrentEntity_Address)

   LDA CurrentEntity_ActiveFlag			;entity active?
   BNE CODE_C697				;take care of it

   DEC $45					;-1 entity, period
   DEC $44					;
   JSR SkipEntityVRAMPosition_DFBD		;ignore this non-existent entity's VRAM position
   JMP CODE_C75D				;next entity then

CODE_C697:
   JSR CODE_D019				;
   LDX CurrentEntity_CurrentPlatform		;depending on which platform it's at
   INC EntitiesPerPlatform,X			;this entity adds to the count of things on the same platform

   LDA PhaseCompleteFlag			;win flag?
   BEQ CODE_C6BC				;

   LDA CurrentEntity_BumpedStateAndBits		;check if the entity has been disturbed already
   BNE CODE_C6BC				;move along

   LDA CurrentEntity_ID				;
   CMP #Entity_ID_Coin				;check if coin
   BEQ CODE_C6C9				;it'll disappear in a glittery fashion
   CMP #Entity_ID_Freezie			;check if freezie
   BNE CODE_C6BC				;if not freezie, it won't disappear in a self-destructing fashion (like freezies do)

   LDA #$00					;
   STA FreezieCanAppearFlag			;freezie can't appear if there's one already

   LDA #<DATA_F59E				;freezie's destruction animation
   LDY #>DATA_F59E				;
   BNE CODE_C6CD				;

CODE_C6BC:  
   JMP CODE_ECEC				;

CODE_C6BF:
   LDA CurrentEntity_DefeatedState		;
   BEQ CODE_C6E9				;hasn't been killed/collected?

   LDA CurrentEntity_ID				;is it a coin?
   CMP #Entity_ID_Coin				;
   BNE CODE_C6E0				;if not, it's a regular enemy death

;coin/freezie is being removed from the scene (phase clear)
CODE_C6C9:
   LDA #<DATA_F5A4				;$A4                 
   LDY #>DATA_F5A4				;$F5

CODE_C6CD:
   STA $06					;
   STY $07					;

   LDA #$30					;(Entity_MiscBits_BumpBits)
   STA $00					;pretend as if its bumped

   JSR CODE_D789				;remove its sprite tiles...?

   LDA #$00					;
   STA CurrentEntity_DefeatedState		;is no longer "defeated"
   STA CurrentEntity_PipeDir			;
   BEQ CODE_C744				;the rest of it

;entity is kicked off
CODE_C6E0:
   JSR CODE_DEAF				;handle getting kicked & splashing
   JSR SkipEntityVRAMPosition_DFBD		;will check for the next entity's VRAM tile that is below them
   JMP CODE_C747				;draw and everything

;entity is normal
CODE_C6E9:
   JSR CODE_D6BA				;state stuff
   JSR CODE_DB53				;
   JSR CODE_DBFF				;interact with other entitites

   LDA CurrentEntity_BumpedStateAndBits		;not bumped by anything?
   BNE CODE_C6FC				;ignore...

   JSR CODE_D9FE				;check if can go in the pipe
   JMP CODE_C708				;

CODE_C6FC:
   LDA CurrentEntity_BumpedStateAndBits		;check if the entity in specific states...
   AND #$0F					;
   CMP #Entity_State_FlippedLanded		;check if flipped yet grounded
   BEQ CODE_C744				;
   CMP #$06					;check if it disappears like a coin/freezie...?
   BEQ CODE_C744				;

CODE_C708:
   JSR TickXSpeedAlterTimer_DB2D		;can move like normal = can be modified like normal

   LDA CurrentEntity_BumpedStateAndBits		;check if in an abnormal state
   ORA CurrentEntity_PipeDir			;or coming out of the pipe
   BNE CODE_C73B				;won't speed up yet

   LDA LastEnemyFlag				;is the last enemy?
   BEQ CODE_C73B				;if not, carry on

   LDA CurrentEntity_ID				;
   LDY #$05					;speed offset
   LDX #$06					;palette offset
   CMP #Entity_ID_Sidestepper			;
   BEQ CODE_C727				;

   LDY #$02					;speed offset
   LDX #$02					;palette offset
   CMP #Entity_ID_Shellcreeper			;
   BNE CODE_C73B				;if it's not shellcreeper... DONT CARE!!

CODE_C727:
   STY CurrentEntity_XSpeedTableEntry		;speed modifier...
   STX CurrentEntity_PaletteOffset		;palette

   JSR CODE_CAB9				;speed, please
   JSR CODE_D9B6				;palette

   LDA CurrentEntity_ID				;check if shellcreeper
   CMP #Entity_ID_Shellcreeper			;
   BNE CODE_C73B				;if not, already moving at max capacity

   LDA #$00					;
   STA CurrentEntity_XSpeedModifier		;no holding back for this turtles!

CODE_C73B:
   LDA CurrentEntity_UpdateTimer		;updates vertical movement every few frames?
   CMP #$05					;
   BCS CODE_C744				;

   JSR CODE_C785				;handle movement

CODE_C744:
   JSR CODE_CC73				;get VRAM position below this entity

CODE_C747:
   JSR CODE_CBC4				;entity drawing

   LDA CurrentEntity_ActiveFlag			;entity active?
   BEQ CODE_C758				;

   LDA CurrentEntity_DefeatedState		;defeated in any way (or """""""""""defeated""""""""""" if it's a coin)
   BNE CODE_C758				;technically doesn't count

   LDA CurrentEntity_ID				;
   CMP #Entity_ID_Coin				;coin and above don't count as required entities for progression
   BCC CODE_C75A				;

CODE_C758:
   DEC $44					;-1 entity on-screen

CODE_C75A:  
   JSR CODE_CBB6				;store entity values from temporary addresses

CODE_C75D:
   JSR CODE_CBAE				;next entity
   
   DEC $33					;loop until all are processed
   BNE CODE_C782
   
   LDA EntitySpawnIndex				;if we didn't spawn all required enemies
   CMP #$AA					;
   BNE CODE_C781				;don't check for victory yet

   LDA $45					;new entity count
   BNE CODE_C775				;
   STA $43					;

CODE_C770:
   LDA #$01					;phase complete
   STA PhaseCompleteFlag			;
   RTS						;

CODE_C775:
   LDA $44					;
   BEQ CODE_C770				;if all enemies are defeated, mark phase as complete
   CMP #$01					;if not last enemy alive
   BNE CODE_C781				;return

   LDA #$01					;mark last enemy (make them faster)
   STA LastEnemyFlag				;

CODE_C781:
   RTS						;

CODE_C782:
   JMP EntityProcessingLoop_C686		;jump all the way back and run the next entity

;handle horizontal and vertical movement
;MoveEntity_C785:
CODE_C785:
   LDA CurrentEntity_ID				;
   CMP #Entity_ID_Fighterfly			;check if fighterfly
   BNE CODE_C7B7				;

   LDA CurrentEntity_BumpedStateAndBits		;bumped?
   BNE CODE_C792				;skip movement animation (plays animation if needed somewhere else)

   JSR UpdateEntityGFXFrame_WhenMoving_CE9C	;animate (animate while jumping and falling)

CODE_C792:
   LDA CurrentEntity_UpdateTimer		;timer for fighterfly to jump?
   BEQ CODE_C797				;
   RTS						;

CODE_C797:
   LDA CurrentEntity_BumpedStateAndBits		;check for bump AGAIN???
   BNE CODE_C7B7				;don't, like, move... at least, don't overwrite speeds

   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_AirMovement		;check if already doing in-air movement
   BNE CODE_C7B7				;

   LDA CurrentEntity_MovementBits		;
   ORA #Entity_MovementBits_JumpBounce		;fighter fly just jumped
   STA CurrentEntity_MovementBits		;

   LDX #<DATA_F36D				;fighter fly's general jumping y-speeds
   LDY #>DATA_F36D				;
   LDA CurrentEntity_CurrentPlatform		;if on brick level, different jumps
   BNE CODE_C7B3				;

   LDX #<DATA_F370				;subdue jumps (doesn't jump as high, so that means it jumps more often)
   LDY #>DATA_F370				;

CODE_C7B3:
   STX CurrentEntity_UpdateDataPointer		;
   STY CurrentEntity_UpdateDataPointer+1	;

CODE_C7B7:
   LDA CurrentEntity_MovementBits		;back this up
   STA $11					;

   JSR CODE_CCA0				;load vertical speed

   BIT $11					;check if it's falling (moving down) or jumping/bounces (up)
   BMI CODE_C7C7				;
   BVS CODE_C7CA				;

   JMP CODE_C7CD				;no vertical speed, not moving on y-axis

CODE_C7C7:
   JMP CODE_C93A				;moving up

CODE_C7CA:
   JMP CODE_C9A1				;moving down

CODE_C7CD:
   LDA CurrentEntity_ID				;check if it's a player entity
   AND #$F0					;
   BEQ CODE_C7DA				;if so...

   LDA CurrentEntity_PipeDir			;inside a pipe?
   BEQ CODE_C7DE				;

   JMP CODE_C8D1				;move horizontally (in pipe)

CODE_C7DA:
   LDA CurrentEntity_Player_State		;check if player is totally NOT normal
   BNE CODE_C7F3

CODE_C7DE:
   LDA CurrentEntity_TileAtBottomVRAMPos	;
   JSR GetTileActsLike_CAA4			;check if touched anything solid (or solid-like)
   AND #$0F					;
   BNE CODE_C7EA				;

   JMP CODE_C97D				;go handle gravity?

CODE_C7EA:
   LDA CurrentEntity_ID				;perform player animations?
   AND #$0F					;
   BNE CODE_C7F3				;

   JMP CODE_C8D1				;horizontal speed, here we come

CODE_C7F3:
   LDA CurrentEntity_Player_MovementTimer	;if the movement timer is set, it'll tick down
   BEQ CODE_C7F9				;

   DEC CurrentEntity_Player_MovementTimer	;frame passed

CODE_C7F9:
   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_CantMove		;squished bit?
   BNE CODE_C86F				;if set, continue squishing

   LDA CurrentEntity_Player_ControllerInputs	;check if player pressed B button (jump)
   BPL CODE_C824				;other control shenanigans then

;performing jump, wah, wahoo, yupee!
   LDA Sound_Effect2				;play sound
   ORA #Sound_Effect2_Jump			;
   STA Sound_Effect2				;

   LDA CurrentEntity_MovementBits		;
   AND #$33					;direction and maybe other bits
   ORA #Entity_MovementBits_JumpBounce		;propel thyself up
   STA CurrentEntity_MovementBits		;

   LDA #<DATA_F350				;$50                 
   STA CurrentEntity_UpdateDataPointer

   LDA #>DATA_F350				;$F3                 
   STA CurrentEntity_UpdateDataPointer+1

   LDA #GFX_Player_Jumping			;show jumping frame
   STA CurrentEntity_DrawTile			;

   LDA #PlayerRunningAnimCycle_Start		;zero out animation pointer index (walk once landing, not skidding)
   STA CurrentEntity_AnimationPointer		;

   JMP CODE_C9E6				;

CODE_C824:
   AND #Input_Right|Input_Left			;
   STA $1E					;actual inputs

   LDA CurrentEntity_MovementBits		;
   STA $1F					;current movement
   AND #Entity_MovementBits_Skidding		;is player skidding?
   BNE CODE_C8AD				;

   LDA CurrentEntity_MovementBits		;
   AND #Entity_MovementBits_MovingHorz		;
   STA $1F					;
   BEQ CODE_C891				;check if even moving

   LDY $05FF					;got pushed by another player?
   BNE CODE_C8B5				;
   AND $1E					;check if changed direction?
   BEQ CODE_C853				;

   LDA CurrentEntity_Player_MovementTimer	;is player currently on the move?
   BNE CODE_C8B5				;
   STA CurrentEntity_Player_SquishingTimer	;no squishy or smth

   INC CurrentEntity_XSpeedTableEntry		;player moved
   JSR CODE_CAB9				;

   LDA #$08					;
   STA CurrentEntity_Player_MovementTimer	;
   JMP CODE_C8B5				;

CODE_C853:
   LDA $1F					;
   ORA #Entity_MovementBits_Skidding		;player is skiddy skiddy skidding
   STA $1F					;

   LDA CurrentEntity_XSpeedTableEntry		;
   STA $00					;

   LDA CurrentEntity_TileAtBottomVRAMPos	;
   STA $01					;
   
   JSR CODE_C3C2				;
   STA CurrentEntity_Player_MovementTimer	;

   LDA $00					;check if skidding
   BEQ CODE_C86C				;if not, no point 
   STA CurrentEntity_AnimationPointer		;I'm guessing modifies image based on if the player is moving

CODE_C86C:
   JMP CODE_C8B5				;

CODE_C86F:
   DEC CurrentEntity_Player_SquishingTimer	;decrement timer
   BEQ CODE_C884				;if zero, become normal

   LDY #GFX_Player_Squish2			;

   LDA CurrentEntity_Player_SquishingTimer	;show different frame depending on when
   CMP #$20					;
   BEQ CODE_C881				;

   LDY #GFX_Player_Squish1			;
   CMP #$10					;
   BNE CODE_C883				;

CODE_C881:
   STY CurrentEntity_DrawTile			;

CODE_C883:
   RTS						;

CODE_C884:
   LDA #Entity_Draw_16x24			;the player becomes 16x24 again
   STA CurrentEntity_DrawMode			;

   LDA CurrentEntity_MovementBits		;restore control to the player
   AND #$FF^Entity_MovementBits_CantMove	;
   STA CurrentEntity_MovementBits		;

   JMP CODE_CEBA				;restore gfx

CODE_C891:
   LDA $1E					;
   BNE CODE_C8A4				;

CODE_C895:
   LDA #$00					;
   STA CurrentEntity_XSpeedTableEntry		;default speed
   STA CurrentEntity_Player_SquishingTimer	;animation stuff

   JSR CODE_CAB9				;player movement update (stop em)
   JSR CODE_CEBA				;player stand still
   JMP CODE_C8B5				;

CODE_C8A4:
   LDA #$05					;movement time (at least 5 frames from the initial direction press)
   STA CurrentEntity_Player_MovementTimer	;

   LDA $1E					;
   JMP CODE_C8B7				;

CODE_C8AD:
   LDA CurrentEntity_Player_MovementTimer	;movement timer ran out?
   BNE CODE_C8B5				;
   STA $1F					;not moving anymore
   BEQ CODE_C895				;

CODE_C8B5:
   LDA $1F					;

CODE_C8B7:
   STA CurrentEntity_MovementBits		;
   STA $11					;

   LDA CurrentEntity_DrawTile			;only play step sound when this frame displays
   CMP #GFX_Player_Walk2			;
   BNE CODE_C8C7				;

   LDA Sound_Effect2				;
   ORA #Sound_Effect2_Step			;
   BNE CODE_C8CF				;

CODE_C8C7:
   CMP #GFX_Player_Skid1			;play turning sound when this frame shows up
   BNE CODE_C8D1				;

   LDA Sound_Effect2				;
   ORA #Sound_Effect2_Turning			;

CODE_C8CF:
   STA Sound_Effect2				;

CODE_C8D1:
   LDA CurrentEntity_ID				;if entity isn't a coin or a freezie
   CMP #Entity_ID_Coin				;something skip
   BCC CODE_C8E4				;

CODE_C8D7:
   LDA CurrentEntity_XSpeedAlterTimer		;both stops AND animates!
   BNE CODE_C8DE				;if timer is ticking though, nothing happens

   JSR UpdateEntityGFXFrame_CEA3		;update their appearance. hey, nice hairstyle!

CODE_C8DE:
   JSR CODE_CAEB				;don't process further if timer hasn't expired
   JMP CODE_C8F4				;move

CODE_C8E4:
   JSR CODE_CAEB				;timer check, should it move?

   LDA CurrentEntity_ID				;check if not a player
   AND #$F0					;
   BEQ CODE_C8F1				;will check for something

   LDA CurrentEntity_TurningCounter		;if currently turning, not animating
   BNE CODE_C916				;

CODE_C8F1:
   JSR UpdateEntityGFXFrame_WhenGrounded_CE95	;common movement animation routine (when not in air and when moving)

CODE_C8F4:
   LDY #$00					;

   LDA CurrentEntity_ID				;check for player
   AND #$0F					;
.if Version <> PAL
   BNE CODE_C90A				;just update x
.else
   BEQ PAL_CODE_C919

   LDA PAL_SpeedAlterationTimer			;player will be slightly slower to match PAL's lower refresh rate
   BNE PAL_CODE_C927				;

   LDA CurrentEntity_XSpeedTableEntry		;if player is moving only slightly
   BEQ PAL_CODE_C927				;
   DEY						;
   CMP #$01					;if running...
   BEQ PAL_CODE_C927				;will slow down

   LDY #$01					;skidding, on the other hand, is FASTER. Every 4th frame that is.
   BNE PAL_CODE_C927				;

PAL_CODE_C919:
.endif

   LDA CurrentEntity_TurningCounter		;is it turning?
   BNE CODE_C916				;doesnt move

   LDA CurrentEntity_XSpeedAlterTimer		;don't move too fast pal (or don't speed up for one x-speed modifier entry)
   BNE CODE_C90A				;but while it's not zero, you may move

   LDA #$03					;
   STA CurrentEntity_XSpeedAlterTimer		;reset the timer

   LDY CurrentEntity_XSpeedModifier		;slow down, or in rare cases, speed up (or don't do jack, depends on modifier's value)

PAL_CODE_C927:
CODE_C90A:
   TYA						;
   CLC						;
   ADC CurrentEntity_XSpeed			;

;movement
   LSR $11					;moving right
   BCS CODE_C91C				;

   LSR $11					;moving left
   BCS CODE_C917				;

CODE_C916:
   RTS						;not moving at all (e.g. middle bump)

CODE_C917:
   EOR #$FF					;moving left
   SEC						;
   BCS CODE_C91D				;

CODE_C91C:
   CLC						;moving right

CODE_C91D:
   ADC CurrentEntity_XPos			;update x-pos
   STA CurrentEntity_XPos			;

   LDA CurrentEntity_ID				;check for player entity
   AND #$0F					;
   BEQ CODE_C936				;non-players face based on speed

   LDA CurrentEntity_Player_BumpedBits		;chceck if the player got bumped
   BEQ CODE_C92C				;not bumped
   RTS						;

CODE_C92C:
   LDA CurrentEntity_Player_SquishingTimer	;being squished?
   BNE CODE_C939				;ignore

   LDA CurrentEntity_MovementBits		;check if skidding
   AND #Entity_MovementBits_Skidding		;
   BNE CODE_C939				;can't change direction

CODE_C936:
   JSR CODE_D9EA				;flip horizontally if necessary

CODE_C939:
   RTS						;

CODE_C93A:
   CMP #$AA					;stop command?
   BEQ CODE_C97D				;no way!
   CMP #$99					;some other command...
   BNE CODE_C959				;no way!

   LDA CurrentEntity_ID 			;check if player or no
   AND #$0F					;
   BNE CODE_C97D				;if player, do something else

   LDA CurrentEntity_BumpedStateAndBits		;
   AND #$0F					;
   CMP #Entity_State_FlippedBack		;check if the entity got flipped again by the player
   BNE CODE_C954				;

   LDA #$FF					;reset its state bits (with the INC right after)
   STA CurrentEntity_BumpedStateAndBits		;

CODE_C954:
   INC CurrentEntity_BumpedStateAndBits		;next state. either it becomes normal or Entity_State_FlippedFalling (or something else)
   JMP CODE_C97D				;

CODE_C959:
   TAY						;temporarily save y-speed
   LDA CurrentEntity_YPos			;check if lower than this
   CMP #$20					;
   BCC CODE_C96F				;

   LDA CurrentEntity_ID				;Mario/Luigi check
   AND #$0F					;
   BEQ CODE_C96F				;not a player

   LDA CurrentEntity_Player_TileAtTopVRAMPos	;check if player has bumped into something
   JSR GetTileActsLike_CAA4			;
   ORA #$00					;?
   BNE CODE_C973				;bump and also nullify vertical speed

CODE_C96F:
   TYA						;restore y-spd
   JMP CODE_C9DD				;

CODE_C973:
   JSR CODE_CF67				;

   LDA #<DATA_F32C				;
   LDY #>DATA_F32C				;
   JMP CODE_C992				;

CODE_C97D:
   LDA CurrentEntity_ID				;lower gravity for fighterfly
   CMP #Entity_ID_Fighterfly			;
   BNE CODE_C98E				;

   LDA CurrentEntity_PipeDir			;unless its performing a pipe entrance/exit
   BNE CODE_C99E				;

   LDA #<DATA_F37B				;$7B
   LDY #>DATA_F37B				;$F3
   JMP CODE_C992				;

CODE_C98E:
   LDA #<DATA_F33A				;$3A
   LDY #>DATA_F33A				;$F3

CODE_C992:
   STA CurrentEntity_UpdateDataPointer		;
   STY CurrentEntity_UpdateDataPointer+1	;

   LDA CurrentEntity_MovementBits		;
   AND #$FF^Entity_MovementBits_AirMovement	;
   ORA #Entity_MovementBits_Fall		;is falling
   STA CurrentEntity_MovementBits		;

CODE_C99E:
   JMP CODE_C9E6				;

CODE_C9A1:
   TAY						;save y-spd i think

   LDA CurrentEntity_TileAtBottomVRAMPos	;check if landed
   JSR GetTileActsLike_CAA4			;
   AND #$0F					;not standing on anything solid?
   BEQ CODE_C9D2				;update speed vertically

   LDA CurrentEntity_MovementBits		;clear jumping and falling bits
   AND #$FF^Entity_MovementBits_AirMovement	;
   STA CurrentEntity_MovementBits		;

   LDA CurrentEntity_ID				;
   CMP #Entity_ID_Fighterfly			;check if fighterfly
   BNE CODE_C9BD				;

   LDA #$08					;
   STA CurrentEntity_UpdateTimer		;timer before next jump
   BNE CODE_C9CB				;

CODE_C9BD:
   LDA CurrentEntity_ID				;player check
   AND #$0F					;
   BEQ CODE_C9CB				;only fix position

   LDA #$00					;
   STA CurrentEntity_Player_BumpedBits		;clear bumped bits

   LDA #PlayerRunningAnimCycle_Start		;
   STA CurrentEntity_AnimationPointer		;players are walking when grounded, obviously

CODE_C9CB:
   LDA CurrentEntity_YPos			;snap to solid ground
   AND #$F8					;
   STA CurrentEntity_YPos			;

CODE_C9D1:
   RTS						;

CODE_C9D2:
   TYA						;
   CMP #$CC					;restore timer and max gravity
   BEQ CODE_C9F1				;
   CMP #$AA					;default (max) gravity
   BNE CODE_C9DD				;

CODE_C9DB:
   LDA #$04					;

CODE_C9DD:
   CLC						;move this many pixels
   ADC CurrentEntity_YPos			;
   CMP #$08					;ensure that you can't go offscreen at the top
   BCC CODE_C9E6				;
   STA CurrentEntity_YPos			;

CODE_C9E6:
   LDA CurrentEntity_ID				;check for non-playable character
   AND #$F0					;
   BNE CODE_C9F8				;

   LDA CurrentEntity_Player_BumpedBits		;checks for bumped bits in this address (players)
   JMP CODE_C9FE				;

CODE_C9F1:
   LDA CurrentEntity_TimerStorage		;
   STA CurrentEntity_UpdateTimer		;
   JMP CODE_C9DB				;

CODE_C9F8:
   CMP #Entity_ID_Fighterfly			;is it fighterfly?
   BEQ CODE_CA0C				;

   LDA CurrentEntity_BumpedStateAndBits		;bump bits for other entities...

CODE_C9FE:
   BEQ CODE_CA0C				;did not get bumped or whatever
   AND #$F0					;
   CMP #Entity_BumpBits_BumpedCenter		;check if got bumped (middle)
   BEQ CODE_C9D1				;just bounces in place (does not move horizontally)

   LDA FrameCounter				;only every fourth frame
   AND #$03					;
   BEQ CODE_CA15				;

CODE_CA0C:
   LDA CurrentEntity_ID				;coin and higher ID
   CMP #Entity_ID_Coin				;
   BCS CODE_CA18				;

   JSR CODE_CAEB				;check if can update

CODE_CA15:
   JMP CODE_C8F4				;just move I guess

CODE_CA18:
   JMP CODE_C8D7				;animate and move

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Clear Screen Init
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Sets up values that'll be used in screen filler routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ClearScreenAndAttributesInit_CA1B:
   LDA #$03					;
   JSR CODE_CA22				;

ClearScreenInit_CA20:
   LDA #$01					;

CODE_CA22:
   STA $01					;this is "VRAM" offset, needed to set-up proper tile update location

   LDA #VRAMTile_Empty				;set blank tile to be displayed on screen
   STA $00					;
   JMP ClearScreen_CD43				;go and clear the screen

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Clear Sprites loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Remove sprite tiles (OAM tiles, sprites, whatever term you prefer) by putting it offscreen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RemoveSpriteTiles_CA2B:
   LDY #>OAM_Y					;OAM starting point, high byte
   STY $01					;

   LDY #<OAM_Y					;\OAM starting point, low byte
   STY $00					;/

   LDA #$F4					;

;InitializeData_CA35:
CODE_CA35:
   STA ($00),y					;\this piece of code is also called by other routine
   DEY						;|
   BNE CODE_CA35				;|
   RTS						;/

CODE_CA3B:
   LDA #<DATA_F23F				;
   LDX #>DATA_F23F				; 
   JSR CODE_CA5E				;set attributes for each phase (HUD, brick floor)

   LDA #<DATA_F266				;
   LDX #>DATA_F266				;

   LDY PlatformTileOffset			;load attributes based on ledge value
   BEQ CODE_CA5E				;tile 93
   CPY #$04					;ice (test your skill bonus)
   BEQ CODE_CA5E				;

   LDA #<DATA_F276				;
   LDX #>DATA_F276				;
   CPY #$01					;tile 94
   BEQ CODE_CA5E				;
   CPY #$03					;tile 96
   BEQ CODE_CA5E				;

   LDA #<DATA_F286				;(for tile 95)
   LDX #>DATA_F286				;

CODE_CA5E:
   STA $00					;
   STX $01					;
   JSR CODE_CE00				;stuff into buffer

CODE_CA65:
   RTS						;

CODE_CA66:
   LDY PaletteFlag				;check if it should update palette
   BEQ CODE_CA65				;return if not
   DEY						;check if supposed to load gameplay palette
   BEQ CODE_CA73				;do so if set, otherwise set palette for title screen

   LDA #<DATA_F227				;Setup address to read data from (DATA_F227)
   LDX #>DATA_F227				;
   BNE CODE_CA77				;

CODE_CA73:
   LDA #<DATA_F203				;setup different data address to read from (DATA_F203)
   LDX #>DATA_F203				;

CODE_CA77:
   LDY #$00					;
   STY PaletteFlag				;update once, don't waste time
   BEQ CODE_CA5E				;lets go call routine and store palettes to VRAM

;calculates VRAM tile position (PPU addr)
;input $00 - x-pos, $01 - y-pos
;output $00 - PPU position high byte, $01 - PPU positiom low byte
;CalculatePPUAddrAtPos_CA7D:
CODE_CA7D:
   LDA $00					;get tile x-pos (VRAM low)
   LSR A					;
   LSR A					;
   LSR A					;
   STA $12					;

   LDA #$20					;base VRAM high
   STA $13					;

   LDA #$00					;base VRAM high low nibble
   STA $15					;

   LDA $01					;
   AND #$F8					;align to 8x8
   ASL A					;
   ROL $15					;
   ASL A					;
   ROL $15					;carry to add to high byte
   STA $14					;adds to low byte 
   JSR CODE_CDB4				;sum these values together

   LDA $15					;result
   STA $00					;

   LDA $14					;
   STA $01					;
   RTS						;

;get the tile type (acts as) the entity is overlapping
;input A: tile value
;output A:
;0 - Tile is considered non-solid
;1 - Tile is considered solid
;2 - Tile is considered as part of a platform bump area
GetTileActsLike_CAA4:
   CMP #$92					;non-solid are tiles 0-91
   BCC CODE_CAB6				;
   CMP #$A0					;platform tiles are 92-9F
   BCC CODE_CAB3				;
   CMP #$FA					;FA-FF (POW tiles) are also considered solid
   BCS CODE_CAB3				;

   LDA #$02					;bumped platform
   RTS						;

CODE_CAB3:
   LDA #$01					;solid
   RTS						;

CODE_CAB6:
   LDA #$00					;not solid
   RTS						;

CODE_CAB9:
   LDA #<EntityXMovementData_F393		;base x-speed tables pointer
   STA $14					;

   LDA #>EntityXMovementData_F393		;
   STA $15					;

   LDA CurrentEntity_XSpeedTableOffset		;offset stored in entity's ram!
   STA $12

   LDA #$00					;
   STA $13					;high byte is 0

   JSR CODE_CDB4				;calculate proper offset

;acceleration for various entities (player, side-stepper, etc)
CODE_CACC:
   LDA CurrentEntity_XSpeedTableEntry		;  
   ASL A					;
   CLC						;
   ADC CurrentEntity_XSpeedTableEntry		;times 3
   TAY						;
   LDA ($14),Y					;check if encountered a loop command
   CMP #$AA					;
   BNE CODE_CADE				;

   DEC CurrentEntity_XSpeedTableEntry		;don't overflow, use the latest entry
   JMP CODE_CACC				;

CODE_CADE:
   STA CurrentEntity_XSpeed			;set entity's speed
   INY						;
   LDA ($14),Y					;
   STA CurrentEntity_TimerStorage		;timing for movement I guess
   INY						;
   LDA ($14),Y					;
   STA CurrentEntity_XSpeedModifier		;
   RTS						;in-air boost or whatever

;called to check for entity's timer. If timer hasn't ran out, terminate further processing, otherwise restore timer and continue
;CheckTimerForUpdate_CAEB:
CODE_CAEB:
   LDA CurrentEntity_UpdateTimer		;if timer ran out
   BEQ CODE_CAF2				;restore and continue running

   PLA						;terminate further processing
   PLA						;
   RTS						;

CODE_CAF2:
   LDA CurrentEntity_TimerStorage		;restore timer
   STA CurrentEntity_UpdateTimer		;
   RTS						;

;update entities' timer and tiles at their VRAM positions for potential collision
CODE_CAF7:
   LDA UpdateEntitiesFlag			;can we even update entities' variables?
   BEQ CODE_CB4F				;

   LDA #$0D					;count all entities
   STA $33					;

   LDX #$01					;
   LDA FrameCounter				;alternate between player entities + reflecting fireball and other entities' tiles
   LSR A					;
   BCC CODE_CB08				;

   LDX #$0E					;

CODE_CB08:
   LDA #<Entity_Address				;entity address
   STA $14					;

   LDA #>Entity_Address				;
   STA $15					;

   LDA #<Entity_Address_Size			;table size
   STA $12					;

   LDA #>Entity_Address_Size			;
   STA $13					;

CODE_CB18:
   LDY #CurrentEntity_ActiveFlag-CurrentEntity_Address
   LDA ($14),y					;check if the entity is active
   BEQ CODE_CB29				;don't decrease timer

   LDY #CurrentEntity_UpdateTimer-CurrentEntity_Address
   LDA ($14),y					;decrease timer address for current entity (CurrentEntity_Timer)
   BEQ CODE_CB29				;
   SEC						;
   SBC #$01					;
   STA ($14),y					;

CODE_CB29:
   LDA $33					;check if we're going through player entities and reflecting fireball
   CMP #$0B					;
   BCC CODE_CB40				;

   CPX #$0E					;but if we aren't storing their tile values this frame
   BCS CODE_CB48				;skip them

   LDY #CurrentEntity_Player_TileAtTopVRAMPos-CurrentEntity_Address
   JSR CODE_CB50				;store to Entity_TileAtTopVRAMPosition (only really useful for the player)

CODE_CB38:
   LDY #CurrentEntity_TileAtBottomVRAMPos-CurrentEntity_Address
   JSR CODE_CB50				;store to Entity_TileAtBottomVRAMPosition

   JMP CODE_CB48				;continue loop

CODE_CB40:
   CMP #$05					;for last few entities
   BCC CODE_CB48				;don't store tile values at all (only decrement their timer)

   CPX #$0E					;check if we're updating these entities this frame
   BCS CODE_CB38				;if so, they only care about what's below them

CODE_CB48:
   JSR CODE_CDB4				;next entity

   DEC $33					;count down
   BNE CODE_CB18				;

CODE_CB4F:
   RTS						;

CODE_CB50:
   LDA Entity_VRAMTile,x			;top or bottom tile goes there
   STA ($14),y					;
   INX						;retrieve bottom tile next time (or not if we just did that)
   INX						;
   RTS						;

;get top/bottom tiles for each entity (via their VRAM position)
;GetTileAtEntity_CB58:
CODE_CB58:
   LDA UpdateEntitiesFlag			;not updating entities this frame = return
   BEQ CODE_CB84				;

   LDX #$00					;
   LDA FrameCounter				;every frame alternate between first 3 entities and last 3 entities VRAM tile positions
   LSR A					;
   BCC CODE_CB65				;

   LDX #$0D					;

CODE_CB65:
   LDY #$06					;3 entities' VRAM locations (two VRAM positions for each: top, bottom)
   LDA HardwareStatus				;can use NES registers

CODE_CB6A:
   LDA Entity_VRAMPosition,x			;point to the tile
   STA VRAMPointerReg				;
   INX						;
   LDA Entity_VRAMPosition,x			;
   STA VRAMPointerReg				;

   LDA VRAMUpdateRegister			;ready VRAM read/write
   LDA VRAMUpdateRegister			;in this case, it's read to get the tile
   STA Entity_VRAMTile,x			;store tile (same address as Entity_VRAMPosition by default)

   INX						;next VRAM location
   DEY						;
   BNE CODE_CB6A				;

CODE_CB84:
   RTS						;

CODE_CB85:
   LDA $A0					;base address
   STA $14					;

   LDA $A1					;
   STA $15					;high byte

   LDA $A2					;offset 
   STA $12					;

   LDA #$00					;offset high
   STA $13					;

   JSR CODE_CDB4				;calculate

   TAY						;
   TAX						;
   RTS						;

CODE_CB9B:
   JSR CODE_CB85				;

CODE_CB9E:
   LDA ($14),Y					;store into temprorary "current entity" addresses that save space significantly
   STA CurrentEntity_Address,X			;

   INY						;
   INX						;
   CPX #<Entity_Address_Size			;keep on loading
   BNE CODE_CB9E				;

   LDA #$00					;
   TAY						;
   STA ($14),Y					;temporarily disables active flag in actual table?
   RTS						;

;next entity addresses
;LoadNextEntityVariables_CBAE:
CODE_CBAE:
   LDA $A2					;
   CLC						;
   ADC #<Entity_Address_Size			;
   STA $A2					;
   RTS						;

CODE_CBB6:
   JSR CODE_CB85				;remember what entity's tables are we storing to

CODE_CBB9:
   LDA CurrentEntity_Address,X			;store entity values where they belong (before moving onto next entity)
   STA ($14),Y					;
   INY						;
   INX						;
   CPX #<Entity_Address_Size			;
   BNE CODE_CBB9				;

CODE_CBC3:
   RTS						;

;seems to be a general sprite GFX drawing routine
CODE_CBC4:
   LDA CurrentEntity_ActiveFlag			;if current entity is non-existent
   BEQ CODE_CBC3				;don't draw

   LDA #>DATA_F296				;load pointer table for graphics for current entity
   STA $15

   LDA #<DATA_F296				;
   STA $14					;

   LDA CurrentEntity_DrawMode			;get pointers to graphics depending on its draw mode
   JSR CODE_CC29				;

   LDA CurrentEntity_DrawTile			;first sprite tile to draw from (as in first tile is 12, then 13, then 14, etc.)
   STA $11					;

   LDY #$00					;
   LDX CurrentEntity_OAMOffset			;OAM offset

CODE_CBDD:
   LDA ($12),Y					;
   BEQ CODE_CBE9				;check if it should animate with frame counter?
   BPL CODE_CBE4				;if bit 7 is set, it'll animate slower (or faster, idk)
   ASL A					;

CODE_CBE4:
   EOR FrameCounter				;
   LSR A					;
   BCS CODE_CC1D				;load different tiles

CODE_CBE9:
   INY						;
   LDA ($12),Y					;Y-position offset

   INY						;
   CLC						;
   ADC CurrentEntity_YPos			;add to current entity's Y-position
   ADC #$FF					;
   STA OAM_Y,X					;sprite's Y-pos

   INX						;
   LDA $11					;sprite tile
   STA OAM_Y,X					;

   INC $11					;next tile value

   INX						;current entity's GFX properties
   LDA CurrentEntity_TileProps			;
   STA OAM_Y,X					;

   INX						;
   LDA ($12),Y					;load X-position offset

   BIT CurrentEntity_TileProps			;if flipped horizontally, invert offset
   BVS CODE_CC0D				;
   CLC						;
   BCC CODE_CC13				;

CODE_CC0D:
   EOR #$FF					;
   SEC						;
   SBC #$08					;
   SEC						;

CODE_CC13:
   ADC CurrentEntity_XPos			;current entity's X-position
   INY						;
   STA OAM_Y,X					;
   INX						;
   JMP CODE_CC22				;check end command

CODE_CC1D:
   INY						;
   INY						;
   INY						;
   INC $11					;

CODE_CC22:
   LDA ($12),Y					;if hit end command (AA), end drawing
   CMP #$AA					;
   BNE CODE_CBDD				;otherwise loop
   RTS						;

CODE_CC29:
   ASL A					;get correct pointer, multiply by 2
   STA $12					;

   LDA #$00					;reset A and Y (not sure why ROL is here)
   TAY						;
   ROL A					;
   STA $13					;

   JSR CODE_CDB4				;add to offset

   LDA ($14),Y					;get graphic data pointer
   STA $12					;
   INY						;
   LDA ($14),Y					;
   STA $13					;
   RTS						;

;Calculate player's VRAM tile positions (for bumping and stuff)
Player_CalculateVRAMPosForBump_CC3F:
;CODE_CC3F:
   LDA CurrentEntity_YPos			;player's location
   SEC						;
   SBC #$0F					;
   CMP #$20					;
   BCC CODE_CC4C				;
   CMP #$E0					;
   BCC CODE_CC54				;

CODE_CC4C:
   LDA #$00					;if the player is too high or too low, VRAM pos doesn't really matter (can't bump blocks)
   STA $01					;

   LDA #$20					;default VRAM tile pos, since can't interact with anything
   BNE CODE_CC5F				;

CODE_CC54:
   STA $01					;

   LDA CurrentEntity_XPos			;
   STA $00					;

   JSR CODE_CA7D				;get first VRAM position (below player)

   LDA $00					;

CODE_CC5F:
   LDX Entity_VRAMPositionIndex			;
   STA CurrentEntity_Player_VRAMPosHi		;high byte
   STA Entity_VRAMPosition,X			;player's VRAM tile position

   INX						;
   LDA $01					;
   STA CurrentEntity_Player_VRAMPosLo		;low byte
   STA Entity_VRAMPosition,X			;

   INX						;
   STX Entity_VRAMPositionIndex			;

;shared with normal entities
CODE_CC73:
   LDA CurrentEntity_YPos			;
   CLC						;
   ADC #$08					;
   CMP #$E4					;check if current entity is low enough
   BCC CODE_CC84				;if not, well

   LDA #$00					;
   STA $01					;default VRAM tile position = $2000 (top-left)

   LDA #$20					;
   BNE CODE_CC8F				;

CODE_CC84:
   STA $01					;

   LDA CurrentEntity_XPos			;
   STA $00					;

   JSR CODE_CA7D				;second VRAM position, below current entity

   LDA $00					;

CODE_CC8F:
   LDX Entity_VRAMPositionIndex			;
   STA Entity_VRAMPosition,X			;
   INX						;

   LDA $01					;
   STA Entity_VRAMPosition,X			;

   INX						;
   STX Entity_VRAMPositionIndex			;index for all the other entities (maybe a second player even)
   RTS						;

;update entity's pointer
;GetEntityData_CCA0:				;generic name... but then again, the data itself can be different things (y-speed, animation frames and stuff)
CODE_CCA0:
   STY $1E					;saves y just in case

   LDA CurrentEntity_UpdateDataPointer		;in this case, holds Y-speed pointer
   STA $14					;

   LDA CurrentEntity_UpdateDataPointer+1	;
   STA $15					;

   LDY #$00					;
   LDA ($14),Y					;
   CMP #$AA					;hit command?
   BEQ CODE_CCC2 				;don't update pointer, full stop
   STY $13					;

   INY						;
   STY $12					;next byte
   JSR CODE_CDB4				;

   LDY $14					;
   STY CurrentEntity_UpdateDataPointer		;

   LDY $15					;
   STY CurrentEntity_UpdateDataPointer+1	;

CODE_CCC2:
   LDY $1E					;
   RTS						;

;Should be self-explanatory
;ReadControllers_CCC5:
CODE_CCC5:
   LDX #$01					;\prepare controller 2 for reading
   STX ControllerReg				;/
   DEX						;\
   TXA						;|prepare controller 1 for reading
   STA ControllerReg				;/
   JSR CODE_CCD3				;read input bits for controller 1
   INX						;then controller 2

CODE_CCD3:
   LDY #$08					;8 bits, of course

CODE_CCD5:
   PHA						;
   LDA ControllerReg,x				;load whatever bit

   STA $00					;store here
   LSR A					;\
   ORA $00					;|get rid of all bits but bit zero (that happens)
   LSR A					;/
   PLA						;
   ROL A					;"sum" active bits
   DEY						;\
   BNE CODE_CCD5				;/next button check

   STX $00					;\get index for single frame press
   ASL $00					;|
   LDX $00					;|
   LDY ControllerInputHolding,x			;|
   STY $00					;/store to scratch ram
   STA ControllerInputHolding,x			;\store controller input (holding)
   STA ControllerInputPress,x			;/(press)
   AND #$FF					;\if A and B are pressed
   BPL CODE_CCFE				;/meh

   BIT $00					;if these buttons are pressed again
   BPL CODE_CCFE				;don't reset bits

   AND #$7F					;\reset A and B press bits
   STA ControllerInputPress,x			;/

CODE_CCFE:
   RTS						;

;Draw tiles from Buffer
;BufferedDraw_CCFF:
CODE_CCFF:
   LDA BufferDrawFlag				;flag for tile update
   BEQ CODE_CD42				;obviously don't do that if not set

   LDA #<BufferAddr				;set buffer address as indirect address ($91)
   STA $00					;

   LDA #>BufferAddr				;$05
   STA $01					;

   LDA Reg2000BitStorage			; 
   AND #$FB					;enable any of bits except for bits 0 and 1
   STA ControlBits				;(which are related with nametables)
   STA Reg2000BitStorage			;back them up

   LDX HardwareStatus				;prepare for PPU drawing

   LDY #$00					;initialize Y register
   BEQ CODE_CD34				;jump ahead

CODE_CD1B:
   STA VRAMPointerReg				;set tile drawing position, high byte

   INY						;low byte
   LDA ($00),y					;
   STA VRAMPointerReg				;

   INY						;
   LDA ($00),y					;
   AND #$3F					;
   TAX						;set how many tiles to draw on a single line

CODE_CD2A:
   INY						;
   LDA ($00),y					;now, tiles
   STA VRAMUpdateRegister			;
   DEX						;
   BNE CODE_CD2A				;draw untill the end
   INY						;

CODE_CD34:
   LDA ($00),y					;if it transferred all tile data from buffer addresses by hitting address with 0, return
   BNE CODE_CD1B				;loop if must

   LDA #$00					;
   STA BufferOffset				;
   STA BufferAddr				;
   STA BufferDrawFlag				;end draw, reset flag

CODE_CD42:
   RTS						;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Fill screen routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Clears screen
;(technically it can fill screen with any tile loaded into $00, but only tile 24 is stored here, and this routine is called only once
;(actually twice but in the same init that is called once))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;USED RAM ADRESSES:
;$00 - Tile value, used to fill screen
;$01 - VRAM tile write placement, used to determine starting position for tile drawing
;$02 - used as position for attribute clearing, VRAM's position, high byte
;$09 - uses previous stored PPU bits to enable almost everything, except of first 2 bits
;PPU registers:
;$2000, $2002, $2006, $2007
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;straight up from Donkey Kong Jr.!
ClearScreen_CD43:
   LDA HardwareStatus				;ready to draw

   LDA Reg2000BitStorage			;\
   AND #$FB					;|
   STA ControlBits				;|
   STA Reg2000BitStorage			;/

   LDA #$1C					;
   CLC						;

CODE_CD52:
   ADC #$04					;
   DEC $01					;calculate high byte of tile drawing starting point
   BNE CODE_CD52				;can be either 20 or 28
   STA $02					;
   STA VRAMPointerReg				;

   LDA #$00					;tile drawing's position, low byte
   STA VRAMPointerReg				;so, the final starting position is either 2000 or 2800

   LDX #$04					;to effectively clear full screen, we need to go from 0 to 255 (dec) 4 times! which is 8 horizontal tile lines from the top right to the bottom left tile. that's how many 8x8 tiles to clear
   LDY #$00					;(technically not, as this also affects attributes that start after 2xBF, but they get cleared afterwards anyway)

   LDA $00					;load tile to fill screen with (by default it's only 24. why they didn't load 24 directly is a mystery. They wanted to use this more than once, with different values loaded into $00? world may never know).

CODE_CD68:
   STA VRAMUpdateRegister			;\fill screen(s) with tiles
   DEY						;|
   BNE CODE_CD68				;|
   DEX						;|
   BNE CODE_CD68				;/

   LDA $02					;\calculate position of tile attribute data.
   ADC #$03					;|end result is either 23 or 2B
   STA VRAMPointerReg				;/

   LDA #$C0					;\attributes location, low byte
   STA VRAMPointerReg				;/

   LDY #$40					;64 attribute bytes
   LDA #$00					;zero 'em out

CODE_CD81:
   STA VRAMUpdateRegister			;\this loop clears tile attributes (y'know, 32x32 areas that contain palette data for each individual 16x16 in it tile)
   DEY						;|
   BNE CODE_CD81				;/
   RTS						;

;handle various timers
HandleGlobalTimers_CD88:
   LDX #$01					;
   DEC TimingTimer				;tick tactics
   BPL CODE_CD94				;don't restore timing

   LDA #$0A					;some timers tick every 10 frames
   STA TimingTimer				;

   LDX #$03					;decrease timers from $2E downto $2B (otherwise only $2C and $2B)

CODE_CD94:
   LDA TimerBase2,x				;if timer is already 0, move onto the next timer
   BEQ CODE_CD9A				;

   DEC TimerBase2,x				;

CODE_CD9A:
   DEX						;
   BPL CODE_CD94				;loop
   RTS						;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Pointer routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Used for 2-byte jumps depending on loaded variable and table values after JSR to this routine.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ExecutePointers_CD9E:
   ASL A					;loaded value multiply by 2
   TAY                      			;turn into y
   INY                      			;and add 1 (to jump over jsr's bytes and load table values correctly)
   PLA                      			;pull our previous location that JSR pushed for us
   STA $14                  			;low byte
   PLA                      			;
   STA $15 					;high byte

   LDA ($14),Y              			;load new location from the table, low byte
   TAX                      			;turn it into x
   INY                      			;increase Y for high byte
   LDA ($14),Y              			;get it
   STA $15                  			;and store
   STX $14                  			;low byte stored into x goes here
   JMP ($0014)              			;perform jump to set location

;calculates 16-bit pointer with offset
;$14-$15 - base pointer
;$12-$13 - offset
CODE_CDB4:
   PHA						;
   CLC						;
   LDA $14					;
   ADC $12					;
   STA $14					;

   LDA $15					;
   ADC $13					;
   STA $15					;
   PLA						;
   RTS						;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Layout building routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This routine draws tiles from table, accessed via indirect addressing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;USED RAM ADRESSES:
;$00 - Table location in ROM, low byte
;$01 - Table location in ROM, high byte
;$09 - contains previously enabled bits of $2000
;PPU registers:
;$2000, $2002, $2006, $2007
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CODE_CDC4:
   STA VRAMPointerReg				;load locations for tile to draw
   INY						;

   LDA ($00),y					;low byte
   STA VRAMPointerReg				;
   INY						;

   LDA ($00),y					;
   ASL A					;
   PHA						;
   LDA Reg2000BitStorage			;
   ORA #$04					;enable drawing in a verical line
   BCS CODE_CDDA				;
   AND #$FB					;or disable it (on bit 7)

CODE_CDDA:
   STA ControlBits				;
   STA $09					;
   PLA						;
   ASL A					;shift again
   BCC CODE_CDE6				;if carry was set by shifting bit 6 (which should trigger repeated write)
   ORA #$02					;set bit that'll go into carry when we shift everything back
   INY						;

CODE_CDE6:
   LSR A					;
   LSR A					;restore original value-bit 6 - how many bytes to write
   TAX						;and said write X times into X

CODE_CDE9:
   BCS CODE_CDEC				;
   INY						;

CODE_CDEC:
   LDA ($00),y					;
   STA VRAMUpdateRegister			;
   DEX						;
   BNE CODE_CDE9				;
   SEC						;set carry
   TYA						;shift original read location so we can continue from here
   ADC $00					;
   STA $00					;

   LDA #$00					;high byte ofc.
   ADC $01					;
   STA $01					;

CODE_CE00:
   LDX HardwareStatus				;
   LDY #$00					;
   LDA ($00),y					;if value isn't zero, which acts as stop writing comand
   BNE CODE_CDC4				;do actual writing

;Restore camera position after messing with VRAM
CODE_CE09:
   PHA
   LDA CameraPosX				;restore camera position
   STA VRAMRenderAreaReg			;

   LDA CameraPosY				;
   STA VRAMRenderAreaReg			;
   PLA						;
   RTS						;

CODE_CE16:
   LDA #$00					;set up address we're copying data to      
   STA $03					;

   LDA #$02					;it's OAM data, starting from first slot
   STA $04					;

   LDY $02					;load offset
   DEY						;-1
   LDX $02					;load amount of bytes to copy

;this routine is used to copy data from one area of addresses to another (from ROM to RAM or RAM to RAM)
;there's only a single JSR for this.

CODE_CE23:
   LDA ($00),Y					;
   STA ($03),Y					;
   DEY						;
   DEX						;
   BNE CODE_CE23				;
   RTS						;

;Set up buffered write.
;Used by things such as POW block and score updates.

CODE_CE2C:
   LDA #$01					;enable drawing for various tiles (in NMI via buffer)
   STA BufferDrawFlag				;

   LDY #$00					;
   LDA ($02),Y					;number of bytes to update on a single row
   AND #$0F					;
   STA $05					;

   LDA ($02),Y					;number of rows to update        
   LSR A					;
   LSR A					;
   LSR A					;
   LSR A					;
   STA $04					;

   LDX BufferOffset				;get buffer offset if any

CODE_CE43:   
   LDA $01					;VRAM position, high byte
   STA BufferAddr,X				;

   JSR NextVRAMUpdateIndex_CE84			;

   LDA $00					;VRAM position, low byte
   STA BufferAddr,X				;

   JSR NextVRAMUpdateIndex_CE84			;

   LDA $05					;number of tiles to draw
   STA $06					;set up a loop
   STA BufferAddr,X 				;and save that information in the buffer.

CODE_CE5A:
   JSR NextVRAMUpdateIndex_CE84			;

   INY						;get those tiles in the buffer
   LDA ($02),Y					;
   STA BufferAddr,X				;

   DEC $06					;keep looping untill all bytes are in the buffer  
   BNE CODE_CE5A				;
   JSR NextVRAMUpdateIndex_CE84			;

   STX BufferOffset				;store current buffer offset
   CLC						;
   LDA #$20					;add + $20 to the VRAM position, so it's the next row
   ADC $00					;
   STA $00					;

   LDA #$00					;high byte  
   ADC $01					;
   STA $01					;

   DEC $04					;check number of rows
   BNE CODE_CE43				;if not all, keep loopin'

   LDA #$00					;put an end for buffered write.  
   STA BufferAddr,X				;
   RTS						;

NextVRAMUpdateIndex_CE84:   
   INX						;write next buffer byte
   TXA						;transfer into X for the next check

NextVRAMUpdateIndex_CheckOverflow_CE86:   
   CMP #$2F					;check if there's too much to update
   BCC CODE_CE94				;if not, moving on

   LDX BufferOffset				;get current buffer offset

   LDA #$00					;and cut this particular update out
   STA BufferAddr,X				;maybe for the next time

   PLA						;terminate call             
   PLA						;

CODE_CE94:   
   RTS						;

;used to animate some entities (specifically, their movement)
UpdateEntityGFXFrame_WhenGrounded_CE95:
CODE_CE95:
   LDA CurrentEntity_MovementBits		;if an entity is neither falling or jumping, don't animate
   AND #Entity_MovementBits_AirMovement		;
   BEQ UpdateEntityGFXFrame_WhenMoving_CE9C	;
   RTS						;

UpdateEntityGFXFrame_WhenMoving_CE9C:
CODE_CE9C:
   LDA CurrentEntity_MovementBits		;is entity even moving? no?
   AND #Entity_MovementBits_MovingHorz		;not wew! anymore
   BNE UpdateEntityGFXFrame_CEA3		;yes? dew yeet
   RTS						;

;actual animation here
UpdateEntityGFXFrame_CEA3:
CODE_CEA3:
   LDY CurrentEntity_AnimationPointer		;
   LDA EntityMovementAnimations_F4B2,Y		;
   CMP #$FF					;encountered loop command?
   BEQ CODE_CEB1				;use next byte to go to specified point
   STA CurrentEntity_DrawTile			;otherwise just show the frame

   INC CurrentEntity_AnimationPointer		;
   RTS						;

CODE_CEB1:
   INY						;
   LDA EntityMovementAnimations_F4B2,Y		;reset animation cycle
   STA CurrentEntity_AnimationPointer		;
   JMP UpdateEntityGFXFrame_CEA3		;

CODE_CEBA:
   LDA #GFX_Player_Standing			;player stops, display standing animation
   STA CurrentEntity_DrawTile			;

   LDA #PlayerRunningAnimCycle_Start		;
   STA CurrentEntity_AnimationPointer		;reset animation pointer
   RTS						;

CODE_CEC3:
   LDA #<Entity_Address+$60			;start at $0360 (enemy entities)
   STA $A0					;

   LDA #>Entity_Address				;
   STA $A1					;

   LDA #<Entity_Address_Size			;
   STA $A2					;
   STA $12					;

   LDA #>Entity_Address_Size
   STA $13

   LDA #$06					;max amount of entity slots to go through
   STA $33

CODE_CED9:
   LDY #$00

   LDA ($A0),y					;check if entity is active
   BEQ CODE_CEEF				;if not, spawn

   JSR CODE_CB85

   LDA $14
   STA $A0

   LDA $15
   STA $A1

   DEC $33
   BNE CODE_CED9
   RTS

;initialize enemy!
CODE_CEEF:
   LDY $35
   STY $1F
   INY               
   LDA ($36),Y         
   STA $1E
   STA $1D

   INY
   LDA ($36),Y
   CMP #$AA                 
   BEQ CODE_CF04
   STA PipeDelayTimer
   TYA

CODE_CF04:
   STA $35

   LDA #<SpawnInitValues_Enemies_F452                    
   STA $14

   LDA #>SpawnInitValues_Enemies_F452  
   STA $15

   LDA $1E				;check if we're spawning shellcreeper
   BEQ CODE_CF19			;no need for loop nonsense

CODE_CF12:
   JSR CODE_CDB4			;offset table to get values for the appropriate entity (sidestepper, fighterfly)
   
   DEC $1E				;keep going?
   BNE CODE_CF12			;

CODE_CF19:
   LDA $33                  
   ASL A                 
   ASL A
   ASL A
   ASL A
   CLC                      
   ADC #$40        
   TAX
   
   LDY #$00

CODE_CF25:   
   LDA ($14),Y
   CPY #$0A    
   BNE CODE_CF2C
   
   TXA

CODE_CF2C:   
   STA ($A0),Y

   INY                      
   CPY #$20
   BNE CODE_CF25

   LDA DemoFlag					;are we watching a demo?
   BEQ CODE_CF3B				;no, spawn like normal

   LDA #$01					;all enemies will spawn from the right pipe
   BNE CODE_CF53				;

CODE_CF3B:
   LDA $1F					;
   CMP #$02					;
   BNE CODE_CF48				;

   LDA $04F5					;flip the facing from the previous spawn
   EOR #$03					;
   BNE CODE_CF53				;this branch always triggers

CODE_CF48:
   JSR RNG_D328					;entity's spawn position depends on random number
   AND #$01					;
   CLC						;
   ADC #$01					;
   STA $04F5					;

CODE_CF53:
   LDX #$F0					;spawn x-position
   CMP #$01					;coming from right pipe?
   BEQ CODE_CF5B				;yes

   LDX #$10					;x-position for left pipe

CODE_CF5B:   
   LDY #$12					;
   STA ($A0),Y					;direction, maybe?
   TXA						;

   LDY #$09					;
   STA ($A0),Y					;store x-pos

   INC $43					;+1 to the enemy count
   RTS						;

;player's head hits the platform
CODE_CF67:
   LDA POWPowerTimer				;can't hit platforms if POW is active
   BNE CODE_CF88				;

   LDA CurrentEntity_Player_BumpedBits		;player's bumped
   BNE CODE_CF88				;ignore

   LDA $05FF					;flag...
   BNE CODE_CF88				;

   LDA FreezePlatformFlag			;there's a platform freezing somewhere?
   BNE CODE_CF88				;can't bump

   LDX CurrentEntity_ID				;
   LDY #$01					;set up ram offset for specific player
   CPX #Entity_ID_Mario				;
   BEQ CODE_CF83				;

   LDY #$06					;

CODE_CF83:
   LDA BumpBlockVars,Y				;
   BEQ CODE_CF89				;

CODE_CF88:
   RTS						;

;check which tile the player have bumped
CODE_CF89:
   LDX #$00					;

;first, check hardcoded edges/ends (w/e you wanna call them) of platforms
CODE_CF8B:
   LDA CurrentEntity_Player_VRAMPosLo		;
   CMP DATA_F574,X				;check VRAM location of the player
   BNE CODE_CFA7				;doesn't match

   LDA CurrentEntity_Player_VRAMPosHi		;high byte
   INX						;
   CMP DATA_F574,X				;
   BNE CODE_CFA8				;
   CPX #$08					;if less than 08
   BCC CODE_CFC4				;means right end of the platform

CODE_CF9E:
   LDX #$02					;left end of the platform
   LDA #$E0					;
   STA $12					;(PlayersVRAMPos+FFE0, which means slightly higher than the platform that's being hit)
   JMP CODE_CFCA				;

CODE_CFA7:
   INX						;

CODE_CFA8:
   INX						;
   CPX #$10					;checked all edges?
   BCC CODE_CF8B				;no, loop

   LDA CurrentEntity_Player_TileAtTopVRAMPos	;check if bumped into any of POW tiles (from FA to FF)
   CMP #$FA					;no variable hitbox, so only bopping the top two tiles count
   BCC CODE_CFB6				;

   JMP CODE_D2DF				;Hit POW block.

;check screen ends
CODE_CFB6:
   LDA CurrentEntity_Player_VRAMPosLo		;
   AND #$1F					;
   BEQ CODE_CF9E				;no bits set meaning VRAM low byte is 0, meaning the left side of the screen, show as 2x2 right platform end bump animation
   CMP #$1F					;
   BEQ CODE_CFC4				;exactly 1F? right side of the screen = 2x2 left platform end bump anim

   LDX #$03					;somewhere in the middle (3x2 animation)
   BNE CODE_CFC6				;

CODE_CFC4:
   LDX #$01					;

CODE_CFC6:  
   LDA #$DF					;(PlayersVRAMPos+FFDF, which means higher but also one tile to the left)
   STA $12					;

CODE_CFCA:
   LDA CurrentEntity_Player_TileAtTopVRAMPos	;can't activate platform bump if its already performing an animation (tiles A0 onward)
   CMP #$A0					;
   BCS CODE_CF88				;return

   LDA #$FF					;
   STA $13					;basically adding such a big value will result in substraction instead due to overflow (can be either FFE0 or FFDF)

   LDA CurrentEntity_Player_VRAMPosHi		;store player's "VRAM" position
   STA $15					;

   LDA CurrentEntity_Player_VRAMPosLo		;
   STA $14					;

   LDA #$01					;actually $84 or $89 because of offset
   STA BumpEntityVars-1,Y			;bumped platform flag, but not for animation, but rather for hitting entities above

   LDA CurrentEntity_CurrentPlatform		;get player's platform they were standing on
   CLC						;
   ADC #$01					;and add +1 to get the platform above
   STA BumpEntityVars,Y				;

   LDA CurrentEntity_XPos			;and where the the bump has occured
   STA BumpEntityVars+1,Y			;

   JSR CODE_CDB4				;calculate VRAM location of the top-left bump effect tile

   LDA CurrentEntity_Player_TileAtTopVRAMPos	;use galaxy brain to calculate bump animation with platform tiles in mind
   SEC						;
   SBC #VRAMTile_PlatformBase			;
   STX $00					;
   ASL A					;
   ASL A					;
   ASL A					;
   ASL A					;
   ORA $00					;
   STA BumpBlockVars,Y				;

   DEY						;
   LDA #$00					;
   STA BumpBlockVars,Y				;$74 or $79 set to 0 (which is never checked btw)

   INY						;
   INY						;
   STA BumpBlockVars,Y				;set animation counter to 0

   INY                      
   LDA $14					;store VRAM pos (calculated top-right)
   STA BumpBlockVars,Y				;

   INY						;btw all of the INY shenanigans probably could've been avoided by just using BumpBlockVars+1, BumpBlockVars+2 etc.
   LDA $15					;like how they did with BumpEntityVars earlier
   STA BumpBlockVars,Y				;
   RTS						;

;figure out what platform level the entity's on
;EntityGetPlatform_D019:
CODE_D019:
   LDA CurrentEntity_YPos			;
   LDY #$03					;highest platform level
   CMP #$50					;
   BCC CODE_D02C				;

   DEY						;middle platforms
   CMP #$80					;
   BCC CODE_D02C				;
   DEY						;

   CMP #$B0					;low platforms
   BCC CODE_D02C				;
   DEY						;

CODE_D02C:
   STY CurrentEntity_CurrentPlatform		;
   RTS						;

;update score, or at least write some initial values
CODE_D02F:
   LDA #$01					;no more updates plz
   STA BufferDrawFlag				;

   LDX $00                  
   JSR CODE_D03F
   
   LDA $00                  
   LSR A                    
   LSR A                    
   LSR A                    
   LSR A                    
   TAX                      

;similar routine in DK - CODE_F24E
CODE_D03F:
   INX						;
   TXA						;
   AND #$0F					;
   CMP #$09					;
   BCS CODE_D0B3				;
   ASL A					;*4 to get proper counter index (TOP, player 1 or 2)
   ASL A					;
   TAY						;
   STA $02					;

   LDX BufferOffset				;get VRAM pos high
   LDA ScoreVRAMUpdData_F68D,Y			;
   STA BufferAddr,X				;
   JSR NextVRAMUpdateIndex_CE84			;

   INY						;
   LDA ScoreVRAMUpdData_F68D,Y			;VRAM pos Low
   STA BufferAddr,X				;
   JSR NextVRAMUpdateIndex_CE84			;

   INY						;
   LDA ScoreVRAMUpdData_F68D,Y			;
   AND #$07					;max 8 digits? though the counters are max 6
   STA BufferAddr,X				;
   STA $01					;how many digits to update
   TXA						;
   SEC						;
   ADC $01					;
   JSR NextVRAMUpdateIndex_CheckOverflow_CE86	;
   TAX						;
   STX BufferOffset				;end stuffing buffer with... well, stuff

   LDA #VRAMWriteCommand_Stop			;
   STA BufferAddr,X				;

   INY						;
   LDA ScoreVRAMUpdData_F68D,Y			;
   STA $03					;

CODE_D083:
   DEX						;

   LDA ScoreAddress,Y				;ones/hundreds/ten thousands digit
   AND #$0F					;
   STA BufferAddr,X				;

   DEC $01					;next digit
   BEQ CODE_D0A2				;

   DEX						;

   LDA ScoreAddress,Y				;tens/thousands/hundred thousands digit
   AND #$F0					;
   LSR A					;
   LSR A					;
   LSR A					;
   LSR A					;
   STA BufferAddr,X				;
   DEY						;

   DEC $01					;next digit again
   BNE CODE_D083				;

CODE_D0A2:
   LDA $03					;
   AND #$01					;check for some bit
   BEQ CODE_D0B3				;

;----------------------------------------------
;!UNUSED
;replaces the very last digit (the highest one) with a fixed tile. Purpose unknown.
   LDY $02					;\same as DK and others.
   CLC						;|
   LDA ScoreAddress,Y				;|
   ADC #$37					;|
   STA BufferAddr,X				;/
;----------------------------------------------

CODE_D0B3:
   RTS						;

;score related
;Input:
;$04 - substraction flag, clear - addition, set - substraction (substraction is unused in this game)
;$05 - Hundreds and tens thousands to add
;$06 - Thousands and hundreds to add
;$07 - Tens and ones to add
;A - score address offset, where 0 - mario and 1 - luigi

CODE_D0B4:
   AND #$07					;does that mean that theoratically you can have more than 2 player scores? i don't know what ninty game allows for more than 2 and uses this same routine
   ASL A					;
   ASL A					;x4 to get correct score address
   TAX						;into X

   LDA $04					;0 - addition, non-zero - substraction
   BEQ CODE_D0E4				;

   LDA PlayerScore-1,X				;\invert addition/substraction flag, I think.
   BEQ CODE_D0E8				;/is never set to non-zero, seems kinda worthless actually

CODE_D0C1:
   CLC						;
   LDA PlayerScore+2,X				;store original value before calculation into $03
   STA $03					;

   LDA $07					;
   JSR CounterAddition_D139			;calculate tens and ones
   STA PlayerScore+2,X				;result

   LDA PlayerScore+1,X				;now calculate hundreds and thousands
   STA $03					;

   LDA $06					;
   JSR CounterAddition_D139			;
   STA PlayerScore+1,X				;result

   LDA PlayerScore,X				;and tens and ones
   STA $03					;

   LDA $05					;calculate tens and hundreds of thousands
   JSR CounterAddition_D139			;
   STA PlayerScore,X				;you guessed it, calculated result
   RTS						;

CODE_D0E4:
   LDA PlayerScore-1,X				;if this flag is set, it'll do substraction instead???
   BEQ CODE_D0C1				;i guess this is like an overflow/underflow prevention measure, but it seems weirdly handled (does it even work?).

;SUBSTRACTION...?
CODE_D0E8:
   SEC						;+1 to hundreds 
   LDA PlayerScore+2,X				;tens and ones
   STA $03					;

   LDA $07					;sub ten/hundred thousands
   JSR CounterSubstraction_D15A			;
   STA PlayerScore+2,X				;resulting

   LDA PlayerScore+1,X				;
   STA $03					;

   LDA $06					;
   JSR CounterSubstraction_D15A			;
   STA PlayerScore+1,X				;

   LDA PlayerScore,X				;
   STA $03					;

   LDA $05					;
   JSR CounterSubstraction_D15A			;
   STA PlayerScore,X				;

   LDA PlayerScore,X             		;\could work without LDA?
   BNE CODE_D116         			;/

;these aren't used yet
   LDA PlayerScore+1,X				;
   BNE CODE_D116				;

   LDA PlayerScore+2,X				;
   BEQ CODE_D11C				;

CODE_D116:
   BCS CODE_D138				;

   LDA PlayerScore-1,X				;
   EOR #$FF					;

CODE_D11C:
   STA PlayerScore-1,X

   SEC						;
   LDA #$00					;
   STA $03					;add 0?

   LDA PlayerScore+2,X				;
   JSR CounterSubstraction_D15A			;
   STA PlayerScore+2,X				;

   LDA PlayerScore+1,X				;
   JSR CounterSubstraction_D15A			;
   STA PlayerScore+1,X				;

   LDA PlayerScore,X				;
   JSR CounterSubstraction_D15A			;
   STA PlayerScore,X				;

CODE_D138:
   RTS						;

;Calculate counter value, like score, addition
;Input:
;$03 - original value to add to
;A - value to add
;Output:
;A - result
;Carry - if next calculation in this routine should have a +1 to the low digit
CounterAddition_D139:
   JSR ExtractDigits_D17C			;
   ADC $01					;
   CMP #$0A					;if value less than A
   BCC CODE_D144				;don't round
   ADC #$05					;by adding 6 (incluing carry)

CODE_D144:
   CLC						;
   ADC $02					;
   STA $02					;

   LDA $03					;tens/thousands/ten thousands
   AND #$F0					;only care about left digit that can overflow
   ADC $02					;and additional ten/whatev
   BCC CODE_D155				;overflow?

CODE_D151:
   ADC #$5F					;+$60 because of the carry (need carry set to get there)
   SEC						;and +1 to the next digit calculation (so for example 90+20=110, which results in +1 to the hundreds address)
   RTS						;

CODE_D155:
   CMP #$A0					;hundreds and etc?
   BCS CODE_D151				;if so, round it to 0
   RTS						;otherwise return

;Calculate counter value, like score, substraction
;$03 - original value to substract from
;A - value to substract
;Output:
;A - result
;Carry - if next calculation in this routine should have a -1 to the low digit
CounterSubstraction_D15A:
CODE_D15A:
   JSR ExtractDigits_D17C			;extract digits
   SBC $01					;
   STA $01					;minus itself?
   BCS CODE_D16D
   ADC #$0A                 
   STA $01
   
   LDA $02                  
   ADC #$0F                 
   STA $02

CODE_D16D:
   LDA $03                  
   AND #$F0                 
   SEC                      
   SBC $02                  
   BCS CODE_D179                
   ADC #$A0                 
   CLC

CODE_D179:   
   ORA $01                  
   RTS                      

;extract two digits into two bytes
;Input:
;A - Value to get digits from
;
;Output:
;$01 - right digit (00-0F)
;$02 - left digit (00-F0)

ExtractDigits_D17C:
   PHA					;
   AND #$0F				;
   STA $01				;save low digit
   PLA					;
   AND #$F0				;and high digit
   STA $02				;

   LDA $03				;calculate low digit of value we're about to calculate
   AND #$0F				;
   RTS					;

;high score related!
UpdateTOPScore_D18B:
   LDA #$00				;
   STA $04				;
   CLC					;

   LDA $00				;the amount of high scores?
   ADC #$10				;$F0+$10 = $00, indicating 1 TOP score on screen
   AND #$F0				;
   LSR A				;
   LSR A				;
   TAY					;

   LDA $00				;number of players
   AND #$07				;
   ASL A				;each player 4 bytes
   ASL A				;
   TAX					;

CODE_D1A0:
   LDA HighScore-1,Y			;these unknown flags strike back!!
   BEQ CODE_D1F6			;

   LDA PlayerScore-1,X			;...again!
   BEQ CODE_D1CF			;

CODE_D1A9:
   SEC					;
   LDA HighScore+2,Y			;
   STA $03				;

   LDA PlayerScore+2,X			;top score minus player score to figure out if player's score hasn't TOPped the high score
   JSR CounterSubstraction_D15A		;

   LDA HighScore+1,Y			;
   STA $03				;

   LDA PlayerScore+1,X			;continue subbing
   JSR CounterSubstraction_D15A		;

   LDA HighScore,Y			;
   STA $03				;

   LDA PlayerScore,X			;
   JSR CounterSubstraction_D15A		;
   BCS CODE_D1FA			;

   LDA HighScore-1,Y			;
   BNE CODE_D1FF			;

CODE_D1CF:
   LDA #$FF				;
   STA $04				;
   SEC					;

CODE_D1D4:  
   TYA					;
   BNE CODE_D1F5			;
   BCC CODE_D1E9			;

   LDA PlayerScore-1,X			;these flags that drive me Nutz. like in that game, Mr. Nutz
   STA HighScore-1			;

   LDA PlayerScore,X			;replace high score with player's score
   STA HighScore			;

   LDA PlayerScore+1,X			;
   STA HighScore+1			;now that I think about it, these aren't Y-indexed, which means theoretical support for multiple top scores won't work anyway.

   LDA PlayerScore+2,X			;
   STA HighScore+2			;

CODE_D1E9:
   LDA $00				;check if the game is not singleplayer (the game itself, not the mode you're playing)
   AND #$08				;
   BEQ CODE_D1F5			;if the game is singleplayer-only, there are no more scores to check for

   DEX					;next player's score will be checked (which is............... player 1's)
   DEX					;
   DEX					;
   DEX					;
   BPL CODE_D1A0			;

CODE_D1F5:
   RTS					;

CODE_D1F6:
   LDA PlayerScore-1,X			;
   BEQ CODE_D1A9			;

CODE_D1FA:
   LDA HighScore-1,Y			;
   BNE CODE_D1CF			;

CODE_D1FF:
   CLC					;
   BCC CODE_D1D4			;

CODE_D202:
   LDA POWPowerTimer				;POW active?
   BNE CODE_D217				;return

   LDA FrameCounter				;check one player's bump tiles depending on... frame counter?
   LSR A					;so it's Mario for one frame and luigi for another
   LDY #$00					;
   BCC CODE_D20F				;
   LDY #$05					;

CODE_D20F:
   STY $05					;
   INY						;
   LDA BumpBlockVars,Y				;did we even bump a platform?
   BNE CODE_D218				;yes, buffer things

CODE_D217:
   RTS						;

CODE_D218:
   STA $10                  			;
   AND #$F0					;
   STA $00					;\calculate bump tiles first animation frame
   LSR A					;|
   LSR A					;|
   LSR A					;|
   CLC						;|
   ADC $00					;|
   ADC #$A0					;|general offset for bump tiles
   STA $01					;/

   INY						;
   LDA BumpBlockVars,Y				;
   TAX						;
   CLC						;
   ADC #$01					;
   STA BumpBlockVars,Y				;next animation frame

   LDA DATA_F81C,X				;bump animation frames
   CMP #$AA					;AA means restore tiles
   BEQ CODE_D297				;
   ASL A					;
   STA $00					;
   ASL A					;
   CLC						;
   ADC $00					;offset from first anim frame if necessary
   ADC $01					;
   STA $11					;

   LDA $10					;check for for what part of the platform we've bumped
   AND #$0F					;either somewhere in the middle, right edge or left edge
   CMP #$01					;
   BNE CODE_D251				;

;below are some binary values.
;bit values that are used to skip tiles. if bit is not set, skip. values below mean: %11011000 - top left and bottom left are skipped (right platform's end), %11111100 - show full 3x2 animation, %01101100 - top right and bottom right are skipped.
   LDA #%11011000				;value used by right end of the platform
   BNE CODE_D257				;

CODE_D251:
   CMP #$02					;
   BNE CODE_D25B				;

   LDA #%01101100				;left end of the platform

CODE_D257:
   LDX #$22					;draw 2x2
   BNE CODE_D25F				;

CODE_D25B:
   LDA #%11111100				;all pieces
   LDX #$23					;draw 3x2

CODE_D25F:   
   STX BufferOffset2				;
   STA $10					;

   LDA #$00					;
   STA $07					;initialize tile counter

   LDX #$00					;Nintendo avoiding TAXes?

CODE_D26A:
   ASL $10					;use some bit trickery to skip some tiles if necessary (in case of edges which only display 4 out of 6 tiles)
   BCC CODE_D277				;

   LDA $07					;
   CLC						;
   ADC $11					;
   STA BufferAddr2,X				;calculate tile of animation

   INX						;

CODE_D277:
   INC $07					;

   LDA $07					;all 6 tiles? (some may be skipped)
   CMP #$06					;
   BNE CODE_D26A				;nah, loop some more

CODE_D27F:
   INY						;
   LDA BumpBlockVars,Y				;and of course VRAM address of affected area
   STA $00					;

   INY						;
   LDA BumpBlockVars,Y				;
   STA $01					;

   LDA #<BufferOffset2				;$40
   STA $02					;

   LDA #>BufferOffset2				;$05
   STA $03					;

   JSR CODE_CE2C				;stuff into an actual buffer
   RTS						;

;restore platform tiles after the bump animation has ended

CODE_D297:
   LDA #$00					;
   STA BumpEntityVars,Y				;can't hit entities anymore since the animation is done

   LDA $10					;restore platform tile
   LSR A					;
   LSR A					;
   LSR A					;
   LSR A					;
   CLC						;
   ADC #VRAMTile_PlatformBase			;
   TAX						;

   LDA #VRAMTile_Empty				;empty tiles
   STA BufferAddr2				;
   STA BufferAddr2+1				;
   STA BufferAddr2+2				;

   LDA $10					;check the animation size
   AND #$0F					;
   CMP #$03					;
   BNE CODE_D2C7				;showing 2x2? yeah

   TXA						;platform tiles
   STA BufferAddr2+3				;
   STA BufferAddr2+4				;
   STA BufferAddr2+5				;

   LDA #$23					;3x2
   BNE CODE_D2D0				;

CODE_D2C7:
   TXA						;store platform tiles
   STA BufferAddr2+2				;only upload 4 tiles instead of 2
   STA BufferAddr2+3				;

   LDA #$22					;2x2

CODE_D2D0:
   STA BufferOffset2				;

   LDY $05					;
   INY						;
   LDA #$00					;but yeah, no more bump.
   STA BumpBlockVars,Y				;

   INY						;
   JMP CODE_D27F				;

;hit POW!
CODE_D2DF:
   LDA POWHitsLeft				;if POW can still be hit
   BNE CODE_D2E4				;run interaction
   RTS						;

CODE_D2E4:
   LDA POWPowerTimer				;if POW isn't in effect
   BEQ CODE_D2E9				;hit everything
   RTS						;

CODE_D2E9:
   LDA #$0F					;set POW effect timer 
   STA POWPowerTimer				;

   LDA CurrentEntity_ID				;who bumped the block, Mario or Luigi?
   STA POWWhoHit				;

   LDA #$00					;reset shake time (so the camera shifts every other frame to create
   STA ShakeTimer				;

   DEC POWHitsLeft				;POW's "hitpoints" -1
   JSR CODE_D593

   LDA Sound_Effect2				;sound effect
   ORA #Sound_Effect2_POWBump			;
   STA Sound_Effect2				;
   RTS						;

CODE_D301:
   LDA POWPowerTimer				;if POW's in effect
   BNE CODE_D306				;decrease timers
   RTS						;

CODE_D306:
   LDA ShakeTimer				;
   BEQ CODE_D30B				;
   RTS						;

CODE_D30B:
   LDA #$01					;
   STA ShakeTimer				;

   DEC POWPowerTimer				;decrease POW's effect timer

   LDY #$01					;move down

   LDA POWPowerTimer				;if timer is less than 8, camera moves down (and all the entities as well)
   CMP #$08					;
   BCC CODE_D31F				;

   LDY #$FF					;move up
   ORA #$F0					;
   EOR #$FF					;

CODE_D31F:
   CLC						;
   ADC BaseCameraPosY				;
   STA CameraPosY				;camera Y

   STY Entity_QuakeYPosOffset			;
   RTS						;

RNG_D328:
   LDA RandomNumberStorage			;Random number
   AND #$02					;
   STA $07					;something to make it a little more "random"

   LDA RandomNumberStorage+1			;Random number
   AND #$02					;
   EOR $07					;
   CLC						;
   BEQ CODE_D33A				;if value isn't zero, don't set carry
   SEC						;

CODE_D33A:
   ROR RandomNumberStorage			;
   ROR RandomNumberStorage+1			;
   ROR RandomNumberStorage+2			;
   ROR RandomNumberStorage+3			;

   LDA RandomNumberStorage			;output for some calls
   RTS						;

CODE_D34A:
   LDA TransitionTimer				;wait a little
   BNE CODE_D3A7				;

   LDA #$00					;
   STA PhaseLoad_PropIndex			;load enemies from phase 1
   STA CurrentPhase				;start from phase 1

   LDA #$03					;
   STA POWHitsLeft				;initialize POW's hitpoints

   LDX #$02					;
   LDY #$00					;
   STX Player1Lives				;set first player's lifes
   STY Player1GameOverFlag			;reset 1P game over flag
   STY Player1_Got1UPFlag			;can receive an extra life

   LDA DemoFlag					;check if it's a demo movie (?)
   BEQ CODE_D36D				;if not, welp

   LDA #$55					;
   STA PhaseLoad_PropIndex			;load certain phase properties
   JMP CODE_D37D				;demo always has 2 players

CODE_D36D:
   LDA Cursor_Option				;if game mode is 2 Players mode
   CMP #$02					;
   BCS CODE_D37D				;set lives for second player as well

   STY Player2Lives				;otherwise don't display luigi's lifes
   STY Player2ScoreUpdateFlag			;update his score

   LDY #$FF					;and don't show him at all
   LDA #$00					;
   BEQ CODE_D381				;

CODE_D37D:
   STX Player2Lives				;luigi's lifes

   LDA #$02					;

CODE_D381:
   STY Player2GameOverFlag			;no game over for 
   STY Player2_Got1UPFlag			;can get an extra life
   STA TwoPlayerModeFlag			;set a flag for 2 Player mode

   LDA #$00					;reset gameover flag for both mario and luigi
   STA Player1TriggerGameOverFlag		;
   STA Player2TriggerGameOverFlag		;

   LDX #$07					;

CODE_D38F:
   STA PlayerScoreAddress,x			;this loop clears mario and luigi's scores
   DEX						;
   BPL CODE_D38F				;

   LDY #$00					;\check if it's game A or B
   LDA Cursor_Option				;|check chosen option
   BEQ CODE_D39F				;|0 - Game A was chosen
   CMP #$02					;|
   BEQ CODE_D39F				;|2 - Game A 2 Players was chosen
   INY						;/otherwise it's game B

CODE_D39F:
   STY GameAorBFlag				;

   LDA #$01					;\use gameplay palette
   STA PaletteFlag				;/
   INC GameplayMode				;change game state

CODE_D3A7:
   RTS						;

CODE_D3A8:
   LDA TransitionTimer				;more timer before transitions
   BNE CODE_D3A7				;

   LDA #$00					;reset lotta flags 'n values
   STA Player1TriggerGameOverFlag		;
   STA Player2TriggerGameOverFlag		;luigi's gameover flag (no idea yet)
   STA PhaseCompleteFlag			;phase complete
   STA LastEnemyFlag				;last enemy flag
   STA Entity_ComingOutOfLeftPipeFlag		;clear pipe flags
   STA Entity_ComingOutofRightPipeFlag		;
   STA $43					;
   STA $44					;some entity variables
   STA $45					;
   STA LastEnemyFlag				;wait, wot

   LDX #$03					;reset sound addresses

CODE_D3C6:
   STA Sound_Base,X				;
   DEX						;
   BPL CODE_D3C6				;

   LDA DemoFlag					;is it demo?
   BNE CODE_D3F5				;run it differently

   JSR InitLives_D60F				;initialize lives
   JSR InitLifeDisplay_1P_D5E6			;now load lives that should show up (player 1)
   JSR InitLifeDisplay_2P_D5EC			;now for player 2

   LDA CurrentPhase				;if phase isn't first, we didn't start the game, play different sounds and stuff
   CMP #$01					;
   BNE CODE_D3ED				;

   LDA #$08					;
   STA GameplayMode				;gameplay mode = start phase

   LDA #$18					;wait a bit for music and stuff
   STA TransitionTimer				;

   LDA #Sound_Jingle_GameStart			;start game music
   STA Sound_Jingle				;

CODE_D3EA:
   JMP EnableRender_E13D			;enable display

CODE_D3ED:
   LDA #Sound_Jingle_PhaseStart			;
   STA Sound_Jingle				;

   LDA #$0C					;shorter transition
   STA TransitionTimer				;

CODE_D3F5:
   INC GameplayMode				;next game state (gameplay)
   BNE CODE_D3EA				;and enable display

CODE_D3F9:
   JSR DisableRender_E132			;call NMI and disable rendering    
   JSR ClearScreenInit_CA20			;clear screen
   JSR RemoveSpriteTiles_CA2B			;remove all sprite tiles
   JSR CODE_D508				;draw main props (pipes, platforms and so on)
   JSR CODE_D61D				;show some initial strings

   INC GameplayMode  				;next gameplay state
   RTS               				;

CODE_D40B:
   JSR DisableRender_E132			;turn off rendering
   JSR ClearScreenInit_CA20   			;clear screen
   JSR RemoveSpriteTiles_CA2B			;clear OAM

   LDX #<DATA_F0A5				;draw title screen behind scenes
   LDY #>DATA_F0A5				;
   JSR CODE_D5D5				;

   LDA #$02					;use title screen's palettes    
   STA PaletteFlag				;

   LDA #$01					;makes cursor move when select is pressed (not held)
   STA TitleScreen_SelectHeldFlag		;

   LDA #<DATA_F689				;setup for cursor sprite
   STA $00					;

   LDA #>DATA_F689				;set-up location to get cursor's OAM data
   STA $01					;it's DATA_F689

   LDA #$04					;4 bytes to transfer
   STA $02					;
   JSR CODE_CE16				;

   INC NonGameplayMode				;next pointer (show title screen)

   LDY TitleScreen_DemoCount			;if it shouldn't play title screen song (or again, after demo ends)
   BNE CODE_D440				;wait for next time

   LDY #$02					;don't play music after demo plays a couple of times
   STY TitleScreen_DemoCount			;

   LDA #$4F					;this value sets title screen music and obviously makes title screen stay for longer before demo plays
   BNE CODE_D444				;

CODE_D440:
   DEC TitleScreen_DemoCount			;

   LDA #$25					;shorter time, because no song

CODE_D444:
   STA TransitionTimer				;
   BNE CODE_D3EA				;enable display and return

CODE_D448:
   LDA TransitionTimer				;wait for the timer to run out
   BNE CODE_D450				;

   LDA #$00					;reset pointer, initialize title screen
   STA NonGameplayMode				;

CODE_D450:
   RTS						;

CODE_D451:
   LDA TransitionTimer				;timer to update scores?
   BNE CODE_D459				;

   LDA #$04					;set gameplay mode to #$04 - slight pause?
   BNE CODE_D47A				;

CODE_D459:
   JMP CODE_E1F7				;update score tiles (store to buffer)

;unpause
CODE_D45C:
   LDA GeneralTimer2B				;if timer runs out, restore timers and gameplay mode
   BEQ CODE_D46F				;
   CMP #$0A					;if isn't at a certain point, return
   BNE CODE_D47C				;

   LDA Reg2001BitStorage			;\
   ORA #$10					;|enable sprite display
   STA RenderBits				;|
   STA Reg2001BitStorage			;/
   BNE CODE_D47C				;always branch, though RTS could've fit in here (and it'd save 1 byte of space)

;Restore timer and gameplay mode
CODE_D46F:
   LDX #$05					;

CODE_D471:
   LDA TimerBackup,X				;restore timers
   STA TimerBase,X				;
   DEX						;
   BPL CODE_D471

   LDA GameplayModeNext				;set next game mode

CODE_D47A:
   STA GameplayMode				;

CODE_D47C:
   RTS						;

CODE_D47D:   
   LDY TransitionTimer				;if timer ran out, play demo
   BEQ CODE_D48E				;
   CPY #$4B					;if it should play title screen music (after reset/after demo plays a couple of times), well
   BNE CODE_D48D				;

   LDA #Sound_Jingle_TitleScreen		;queue title screen music
   STA Sound_Jingle				;

   LDY #$48					;and set the timer
   STY TransitionTimer				;

CODE_D48D:
   RTS						;

CODE_D48E:
   INC NonGameplayMode				;start demo (initialization)
   RTS						;

CODE_D491:
   INC NonGameplayMode				;more init
   JMP CODE_D34A				;jump to existing pointer used during phase initialization

CODE_D496:
   INC NonGameplayMode				;play demo after initialization
   JMP CODE_E14A				;more phase initialization

CODE_D49B:
   INC NonGameplayMode				;
   JMP CODE_D3F9				;even more init!

CODE_D4A0:
   INC NonGameplayMode				;finish init, goddammit!

   LDA #$00					;reset demo movement addresses
   STA Demo_InputIndex_P1			;
   STA Demo_InputTimer_P1			;
   STA Demo_InputIndex_P2			;
   STA Demo_InputTimer_P2			;
   JMP CODE_D3A8				;

CODE_D4AF:
   LDY Demo_InputTimer_P1			;if timer's ticking
   BNE CODE_D4CA				;keep on doing so

   LDX Demo_InputIndex_P1			;demo movement offset
   LDA Player1DemoInputs_F823,X			;
   CMP #Demo_EndCommand				;if should end the demo
   BEQ CODE_D4F8				;end the demo (duh)
   STA Controller1InputPress			;store input

   INX						;
   LDA Player1DemoInputs_F823,X			;
   STA Demo_InputTimer_P1			;and how long to hold the input
   INX						;
   STX Demo_InputIndex_P1			;
   JMP CODE_D4D4				;now luigi

CODE_D4CA:
   DEY						;
   STY Demo_InputTimer_P1			;

   LDA Entity_Mario_ControllerInputs		;keep left or right inputs
   AND #Input_Left|Input_Right			;
   STA Controller1InputPress			;

CODE_D4D4:
   LDY Demo_InputTimer_P2			;tick the timer
   BNE CODE_D4EB				;

   LDX Demo_InputIndex_P2			;get luigi's input
   LDA DATA_F854,X				;
   STA Controller2InputPress			;

   INX						;
   LDA DATA_F854,X				;and time for said input
   STA Demo_InputTimer_P2			;
   INX						;
   STX Demo_InputIndex_P2			;
   JMP CODE_D4F5				;

CODE_D4EB:
   DEY						;tick tock clock
   STY Demo_InputTimer_P2			;

   LDA Entity_Luigi_ControllerInputs		;something about luigi's direction?
   AND #Input_Left|Input_Right			;
   STA Controller2InputPress			;

CODE_D4F5:
   JMP CODE_C5A3				;

CODE_D4F8:
   LDA #$05					;
   STA TransitionTimer				;

   INC NonGameplayMode				;

MuteSounds_D4FE:
   LDA #$00					;store zero to all addresses
   LDX #$03					;loop through all sound addresses

CODE_D502:
   STA Sound_Base,x				;loop through sound addresses
   DEX						;
   BPL CODE_D502				;
   RTS						;

CODE_D508:
   JSR CODE_CA3B				;write attributes

   LDA PlatformTileOffset			;load ledge tile value that is used to build ledges (changes in some phases)
   CLC						;apply offset to get correct tiles (93, 94, 95 and 96)
   ADC #VRAMTile_PlatformBase			;
   STA $07					;

   LDX #$00					;
   LDY #$00					;
   STY $1C					;

CODE_D518:
   LDA #$03					;get VRAM location and amount of tiles to write
   STA $02					;

CODE_D51C:
   LDA DATA_F1E7,Y				;
   STA BufferOffset2,X				;into buffer 2
   INY						;
   INX						;
   DEC $02					;
   BNE CODE_D51C				;

   LDA $1C					;see if we drew all ledges
   BEQ CODE_D53A				;if not, continue

   LDA #VRAMTile_Bricks				;draw bricks now
   STA BufferOffset2,X				;
   INX						;

   LDA $1C					;if we drew 2 rows of bricks, can put a stop now
   CMP #$02					;
   BEQ CODE_D54F				;
   BNE CODE_D54A				;

CODE_D53A:
   LDA DATA_F1E7,Y				;used to check for stop command
   STA $00					;

   LDA $07					;ledge tile
   STA BufferOffset2,X				;
   INX						;

   LDA $00					;check if we've hit a stop command
   BNE CODE_D518				;no, continue drawing ledges
   INY						;

CODE_D54A:
   INC $1C					;can draw bricks now!
   JMP CODE_D518				;

CODE_D54F:
   LDA #VRAMWriteCommand_Stop			;can stop
   STA BufferOffset2,X				;

   LDX #<BufferOffset2				;
   LDY #>BufferOffset2				;
   JSR CODE_D5D5				;store into main buffer
   JSR CODE_D58C				;draw pipes
   JSR CODE_D593				;draw POW block
   JSR CODE_D5BE				;HUD init

   LDA #$00					;reset platform bump variables
   LDX #$09					;

CODE_D568:
   STA BumpBlockVars,X				;
   DEX						;
   BPL CODE_D568				;
   RTS						;

;handle entity spawning
CODE_D56E:
   LDA EntitySpawnIndex				;don't spawn entities...
   CMP #$AA					;exhasted all from the list
   BEQ CODE_D58B				;
   CMP #$BB					;...if bonus phase
   BEQ CODE_D58B				;no enemy entities

   LDA PipeDelayTimer				;wait for the enemy to come out
   BNE CODE_D58B				;

   LDA CurrentPhase				;if 2nd phase, skip some check
   CMP #$02					;
   BEQ CODE_D588				;only phase 2 can have more than 4 required enemies at once

   LDA $45					;check the amount of enemies on-screen?
   CMP #$04					;
   BCS CODE_D58B				;can't have more than 4

CODE_D588:
   JSR CODE_CEC3				;init enemy coming from the pipe

CODE_D58B:
   RTS						;

;draw pipes
CODE_D58C:
   LDX #<DATA_F4F5				;pointer for pipe tiles
   LDY #>DATA_F4F5				;
   JMP CODE_D5D5				;store indirect and write to buffer

;This code is used to draw POW (or nothing)
CODE_D593:
   LDA POWHitsLeft				;POW hits
   ASL A					;
   ASL A					;
   CLC						;*5
   ADC POWHitsLeft				;
   STA $12					;store here

   LDA #$00					;
   STA $13					;

   LDA #<DATA_F560				;
   STA $14					;

   LDA #>DATA_F560				;
   STA $15					;some table set-up, i believe
   JSR CODE_CDB4				;do some calculation

   LDA #$AF					;more set-up
   STA $00					;

   LDA #$22					;
   STA $01					;

   LDA $14					;transfer for indirect addressing
   STA $02					;

   LDA $15					;
   STA $03					;
   JMP CODE_CE2C				;draw POW block (or the lack of it)

;This routine draws HUD during phase initialization (not the score values)
CODE_D5BE:
   LDX #<DATA_F660				;
   LDY #>DATA_F660				;
   JSR CODE_D5D5				;draw part of the HUD

   LDA #$01					;
   STA Player1ScoreUpdateFlag			;draw player 1 score

   LDA TwoPlayerModeFlag			;check if in 2 player mode
   BEQ CODE_D5E5				;

   LDA #$01					;
   STA Player2ScoreUpdateFlag			;draw luigi's score

   LDX #<DATA_F66B				;
   LDY #>DATA_F66B				;

;This stores indirect pointer from X and Y and jumps to routine that stores VRAM updates to buffer
;StoreToBufferWPointer_D5D5:
CODE_D5D5:
   STX $00					;
   STY $01					;
   JMP CODE_CE00				;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;NMI Wait
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This block of code specifically waits for NMI to happen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WaitForNMI_D5DC:
   LDA #$00                 			;reset wait flag
   STA InterruptedFlag             		;
   NOP						;and a single NOP for some reason

CODE_D5E1:
   LDA InterruptedFlag              		;wait for NMI to happen
   BEQ CODE_D5E1				;

CODE_D5E5:
   RTS						;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   
CODE_D5E6:
InitLifeDisplay_1P_D5E6:
   LDX Player1Lives				;load number of player 1's lives to display

   LDY #Lives_Mario_OAM_Slot*4			;OAM offset
   BNE CODE_D5F0				;Always branch

InitLifeDisplay_2P_D5EC:
CODE_D5EC:
   LDX Player2Lives				;load number of player 2's lives to display
   LDY #Lives_Luigi_OAM_Slot*4			;

CODE_D5F0:
   LDA DemoFlag					;if it's demo recording, don't show lives
   BNE CODE_D609				;

   LDA #$03					;can only display max 3 lives for each player
   STA $1E					;

   LDA #$20					;Y-position onscreen
   INX						;

CODE_D5FB:
   DEX                      			;if lives shouldn't be shown in case player doesn't have enough
   BEQ CODE_D60A				;don't show up
   
CODE_D5FE:
   STA OAM_Y,Y					;set Y-position of OAM tile with given offset
   INY						;\
   INY						;|
   INY						;|
   INY						;/next tile's Y-position
   DEC $1E					;life limit to be shown
   BNE CODE_D5FB				;if not all, loop

CODE_D609:
   RTS						;

CODE_D60A:  
   LDA #$F4					;"Hide zone" - Y-position were sprite tiles don't render (i'll probably need to move this term somewhere on top)
   INX						;they could've used INX right before CODE_D5FE
   BNE CODE_D5FE				;that'd save 1 byte of space. I know, that's a lot.

;this prepares life display, load values from table, tiles, props and X-positions
;Y-positions point to "Hide zone", but they're overwritten afterwards.
InitLives_D60F:
   LDY #$00					;

CODE_D611:
   LDA InitLivesData_F671,Y			;load in next order: Y-pos, sprite tile, tile prop, X-pos
   STA Lives_OAM_Y,Y				;

   INY						;
   CPY #$18					;loop untill all 6 tiles are initialized ($18/4)
   BNE CODE_D611				;
   RTS						;

;used to display some strigs upon phase load
CODE_D61D:
   LDA DemoFlag					;check for demo mode
   BNE CODE_D67E				;return if yes

   LDA #$24					;high digit is empty tile by default, unless phase number is higher than 9
   STA $01					;

   LDX #$00					;
   LDA CurrentPhase				;
   AND #$F0					;check if current phase value is over 9
   BEQ CODE_D634				;if not, leave high digit as empty tile
   LSR A					;
   LSR A					;
   LSR A					;if so, do get high digit into a tile
   LSR A					;
   STA $00,X					;
   INX						;

CODE_D634:
   LDA CurrentPhase				;get low digit
   AND #$0F					;
   STA $00,X					;

   LDY #$12					;get phase strings

CODE_D63C:
   LDA DATA_F722,Y				;
   STA BufferOffset2,Y				;into a buffer that'll store to another buffer
   DEY						;
   BPL CODE_D63C				;

   LDA $00					;store low digit for both PHASE and P= strings
   STA BufferAddr2+8				;
   STA BufferAddr2+$0F				;

   LDA $01					;and high digit (or empty tile)
   STA BufferAddr2+9				;
   STA BufferAddr2+$10				;

   LDA #$FF					;how long the "PHASE XX" string stays onscreen
   STA PhaseStringTimer				;

   LDX #<BufferOffset2				;toss into a buffer
   LDY #>BufferOffset2				;
   JSR CODE_D5D5				;

   LDA TESTYOURSKILL_Flag			;test your skill flag
   BEQ CODE_D67E				;if not set, return

   LDA #$F0					;
   STA TESTYOURSKILLStringTimer			;show test your skill string for this long

   LDX #<DATA_F735				;actually load strings
   LDY #>DATA_F735				;
   JMP CODE_D5D5				;and store in buffer

;add a +1 to the phase counter, treat it as decimal
CODE_D672:
   LDA #$01					;+1
   STA $03					;
   CLC						;
   LDA CurrentPhase				;
   JSR CounterAddition_D139			;but also make sure there's no hex (e.g. if 1A, change to 20)
   STA CurrentPhase				;

CODE_D67E:
   RTS						;

;supposed to initialize players!
CODE_D67F:
   LDY #$1F					;offset for player 1
   LDX #$1F					;

   LDA Player2GameOverFlag			;is luigi in the game?
   BNE CODE_D68F				;no, only init mario

   LDX #$3F					;can take luigi's props

   LDA Player1GameOverFlag			;is mario in the game?
   BNE CODE_D68F				;if not, luigi only

   LDY #$3F					;init both players

CODE_D68F:
   LDA SpawnInitValues_Players_F2EC,X		;
   STA Entity_Address,X				;first two entities are players
   DEX						;
   DEY						;
   BPL CODE_D68F				;
   RTS						;

;this is used to store initial enemy pipe time upon loading the phase
CODE_D69A:
   LDA #<DATA_F3BA				;
   STA $14					;

   LDA #>DATA_F3BA				;
   STA $15					;

   LDA EnemyLevel				;
   JSR CODE_CC29				;get pointer

   LDA $12					;store pointer
   STA EntitySpawnPointer			;

   LDA $13					;
   STA EntitySpawnPointer+1			;

   LDA #$00					;initialize index for enemy table
   STA EntitySpawnIndex				;btw, this is already set to zero before even entering this routine

   LDY #$00					;
   LDA (EntitySpawnPointer),Y			;load time for enemy to spawn upon phase load
   STA PipeDelayTimer				;
   RTS						;

;set-up data related to being bumped (normal/flipped animation, timing flipped state, etc.)
;HandleEntityBumpedStates_D6BA:
CODE_D6BA:
   LDA CurrentEntity_ID				;low nibble is only used by player entities
   AND #$0F					;
   BNE CODE_D710				;player interact

   LDA CurrentEntity_ID				;setup various pointers/data, for when entity gets bumped or simply for animation
   LDX #<DATA_F584				;
   LDY #>DATA_F584				;
   CMP #Entity_ID_Shellcreeper			;check which non-player entity is it and get their platform bump data
   BEQ CODE_D6E6				;

   LDX #<DATA_F58C				;
   LDY #>DATA_F58C				;
   CMP #Entity_ID_Sidestepper			;
   BEQ CODE_D6E6				;

   LDX #<DATA_F596				;
   LDY #>DATA_F596				;
   CMP #Entity_ID_Fighterfly			;
   BEQ CODE_D6E6				;

   LDX #<DATA_F59E				;
   LDY #>DATA_F59E				;
   CMP #Entity_ID_Freezie			;
   BEQ CODE_D6E6				;

   LDX #<DATA_F5A4				;
   LDY #>DATA_F5A4				;

CODE_D6E6:
   STX $06					;
   STY $07					;

   LDA CurrentEntity_BumpedStateAndBits		;check for abnormal state
   BNE CODE_D6F1				;
   JMP CODE_D73C				;the entity is in normal state

CODE_D6F1:  
   AND #$0F					;
   CMP #Entity_State_FlippedFalling		;
   BNE CODE_D6FA				;
   JMP CODE_D7C2				;currently in-air, should land somewhere

CODE_D6FA:
   CMP #Entity_State_FlippedLanded		;landed after the bump
   BNE CODE_D701				;
   JMP CODE_D80E				;it'll get up after some time

CODE_D701:
   CMP #Entity_State_SidestepperAngry+1		;check if angry & landed
   BNE CODE_D708 				;
   JMP CODE_D855				;

CODE_D708:
   CMP #$06					;coin/freezie collected/destroyed
   BNE CODE_D70F				;acts the same way though.
   JMP CODE_D885				;

CODE_D70F:
   RTS						;nothing.

;player air and bump checks for GFX
CODE_D710:
   LDA CurrentEntity_MovementBits		;check if player is airborn
   AND #Entity_MovementBits_AirMovement		;
   BNE CODE_D70F				;ignore

   JSR CODE_D90D				;
   CMP #$02					;bumped from below?
   BNE CODE_D70F				;nah

   LDA $00					;got bumped bits
   STA CurrentEntity_Player_BumpedBits		;

   LDA CurrentEntity_MovementBits		;
   ORA #Entity_MovementBits_JumpBounce		;bounce up
   STA CurrentEntity_MovementBits		;

   LDA #<DATA_F5AD				;$AD                 
   STA CurrentEntity_UpdateDataPointer		;vertical speed set-up

   LDA #>DATA_F5AD				;$F5
   STA CurrentEntity_UpdateDataPointer+1	;

   LDA CurrentEntity_MovementBits		;check if the entity is squished (player only)
   AND #Entity_MovementBits_CantMove		;
   BEQ CODE_D70F				;

   LDA #$00					;
   STA CurrentEntity_Player_SquishingTimer	;unsquish
   JMP CODE_C884				;

CODE_D73C:
   JSR CODE_D90D				;check if the entity is bumped from below
   CMP #$02					;
   BEQ CODE_D744				;yes
   RTS						;

CODE_D744:
   LDA CurrentEntity_ID				;is current entity...
   CMP #Entity_ID_Sidestepper			;a side stepper?
   BNE CODE_D767				;if not, check if it's a different entity

   LDA CurrentEntity_AnimationPointer		;check if side stepper is mad
   CMP #SidestepperAngryWalkAnimCycle_Start	;
   BCC CODE_D753				;no, make it mad
   JMP CODE_D877				;yes, flip it

CODE_D753:
   LDA #SidestepperAngryWalkAnimCycle_Start	;sidestepper now appears angery
   STA CurrentEntity_AnimationPointer		;

   INC CurrentEntity_XSpeedTableEntry		;speed up!
   JSR CODE_CAB9				;give it new speed

   LDA Entity_SavedMovementDir			;
   AND #Entity_MovementBits_MovingHorz		;
   STA CurrentEntity_MiscRAM			;remember its direction when it lands

   LDA #Entity_State_SidestepperAngry		;roar, bring it!
   BNE CODE_D797				;

;check other entities
CODE_D767:
   CMP #Entity_ID_Coin				;is it a coin then?
   BEQ CODE_D77F				;collect it
   CMP #Entity_ID_Freezie			;freezie?
   BNE CODE_D792				;no? that leaves shellcreeper and sidestepper

;freezie is destroyed!
   LDA Sound_Effect				;
   ORA #Sound_Effect_DestroyedFreezie		;
   STA Sound_Effect				;

   LDA #$F4					;
   STA Freezie_Explosion_OAM_Y			;hide OAM tiles for potential explosion
   STA Freezie_Explosion_OAM_Y+4		;
   BNE CODE_D785				;

;coin collected (by POW or bump)
CODE_D77F:
   LDA Sound_Effect				;collected a coin
   ORA #Sound_Effect_CollectedCoin		;
   STA Sound_Effect				;

CODE_D785:
   LDA PlayerScoreUpdateIndex			;which player just collected the coin/destroyed freezie? they are rewarded
   STA CurrentEntity_WhichPlayerInteracted	;

CODE_D789:
   LDY #$04					;remove coin/freezie sprite tiles (its 4 max)
   JSR RemoveEntitySpriteTiles_DFC4		;

   LDA #Entity_State_Disappears			;coin/freezie isn't kickable (i'm guessing these bits are for non-interactables)
   BNE CODE_D797				;

CODE_D792:
   JSR Award10ScorePoints_EE82			;

   LDA #Entity_State_GotFlipped			;enemy flipped

CODE_D797:
   ORA $00					;plus bump bits, to see which way it moves from the bump
   STA CurrentEntity_BumpedStateAndBits		;

   LDY #$04					;the entity will animate

CODE_D79D:
   JSR CODE_D9E0				;setup the way its drawn

   LDA CurrentEntity_MovementBits		;
   AND #$FF^Entity_MovementBits_AirMovement	;
   ORA #Entity_MovementBits_JumpBounce		;is raising/bouncing up
   STA CurrentEntity_MovementBits		;

   LDY #$00					;

CODE_D7AA:
   LDA ($06),Y					;
   STA CurrentEntity_UpdateDataPointer		;

   INY						;
   LDA ($06),Y					;
   STA CurrentEntity_UpdateDataPointer+1	;

   LDA CurrentEntity_BumpedStateAndBits		;did this entity become kickable?
   AND #$0F					;
   CMP #Entity_State_GotFlipped			;
   BNE CODE_D7C1				;not applicable to angry sidestepper, freezie or coin

   LDA Sound_Effect2				;
   ORA #Sound_Effect2_EnemyHit			;hit enemy sound
   STA Sound_Effect2				;

CODE_D7C1:
   RTS						;

CODE_D7C2:
   JSR CODE_D90D				;check for getting bumped again
   CMP #$01					;
   BEQ CODE_D7CE				;landed on solid ground
   CMP #$02					;
   BEQ CODE_D7E4				;yes, did get bumped again, un-bump itself
   RTS						;nothing special happens in air

CODE_D7CE:
   JSR CODE_C9CB				;ground itself

   LDA #Entity_State_FlippedLanded		;it'll stay there helpless... KICK ME (or don't and I'll get up)
   STA CurrentEntity_BumpedStateAndBits		;

   LDA CurrentEntity_MovementBits		;not falling
   AND #$FF^Entity_MovementBits_Fall		;
   STA CurrentEntity_MovementBits		;

   LDY #$02					;load flipped animation & timings table
   JMP CODE_D7AA				;

CODE_D7E0:
   LDA #$00					;
   STA CurrentEntity_UpdateTimer		;consistify its update timer

CODE_D7E4:
   JSR CODE_D9EA				;horizontal flip

   LDA #$00					;
   STA CurrentEntity_UpdateTimer		;

   LDA CurrentEntity_ID				;sidestepper?
   CMP #Entity_ID_Sidestepper			;
   BNE CODE_D7FE				;nevermind

   LDA #SidestepperWalkAnimCycle_Start		;not angry anymore
   STA CurrentEntity_AnimationPointer		;

   LDA CurrentEntity_XSpeedTableEntry		;
   BEQ CODE_D7FE				;check if at normal speed setting (not angry)

   DEC CurrentEntity_XSpeedTableEntry		;slow down
   JSR CODE_CAB9				;

CODE_D7FE:
   LDY #$06					;init entity's normal walking animation
   JSR CODE_D79D				;

   LDA CurrentEntity_BumpedStateAndBits		;
   ORA #Entity_State_FlippedBack		;got un-flipped by the player
   ORA $00					;+bump bits
   STA CurrentEntity_BumpedStateAndBits		;

   JMP CODE_D851				;will restore its palette back to what it was (in case it was about to unflip itself, changed the palette, the player bumped it, it'll be back to normal)

;the enemy is currently flipped, animate it & make it get up eventually
CODE_D80E:
   JSR CODE_D90D				;check acts like
   CMP #$02					;bump area
   BEQ CODE_D7E0				;un-flip it

   JSR CODE_CAEB				;only animate every few frames (depends on what entity it is)

   JSR CODE_CCA0				;fetch the animation graphic
   CMP #$FF					;reached the end of flipped animation table, get up
   BEQ CODE_D831				;
   CMP #$00					;special command 0 - will change palette/speed-up
   BNE CODE_D829				;

   JSR CODE_D9C5				;the enemy becomes quicker
   JSR CODE_CCA0				;next table byte

CODE_D829:
   STA CurrentEntity_DrawTile			;store graphics

   JSR CODE_CCA0				;and store how long it'll display the frame
   STA CurrentEntity_UpdateTimer		;
   RTS						;

CODE_D831:
   INC CurrentEntity_XSpeedTableEntry		;FASTER SPEED
   JSR CODE_CAB9				;

   LDA #$00					;
   STA CurrentEntity_UpdateTimer		;reset timer to make its movement consistent
   STA CurrentEntity_BumpedStateAndBits		;normal state

   LDY #$06					;initialize walking animation
   JSR CODE_D9E0				;

   LDA CurrentEntity_ID
   CMP #Entity_ID_Fighterfly			;fighterfly does not actually get faster after getting up (only when it's the last enemy that must be defeated)
   BEQ CODE_D851				;
   CMP #Entity_ID_Sidestepper			;
   BNE CODE_D84F				;

   LDA #SidestepperWalkAnimCycle_Start		;sidestepper normal walking frame
   STA CurrentEntity_AnimationPointer		;

CODE_D84F:
   INC CurrentEntity_PaletteOffset		;cycle palette (it'll be faster)

CODE_D851:
   JSR CODE_D9B6				;update palette
   RTS						;

CODE_D855:
   JSR CODE_D90D				;see if got bumped or smth
   CMP #$01					;solid?
   BEQ CODE_D861				;indicate its not bumped anymore (move normally)
   CMP #$02					;bump area?
   BEQ CODE_D871				;sidestepper gets flipped for real
   RTS						;

CODE_D861:
   JSR CODE_C9CB				;its grounded

   LDA CurrentEntity_MovementBits		;
   AND #$FF^Entity_MovementBits_MovingHorz	;
   ORA CurrentEntity_MiscRAM			;sidestepper's facing?
   STA CurrentEntity_MovementBits		;

   LDA #$00					;not bumped anymore
   STA CurrentEntity_BumpedStateAndBits		;
   RTS						;

CODE_D871:
   LDA CurrentEntity_MovementBits		;is falling (is kinda pointless it seems?)
   AND #$FF^Entity_MovementBits_Fall		;
   STA CurrentEntity_MovementBits		;

CODE_D877:
   JSR Award10ScorePoints_EE82			;add score

   LDA #Entity_State_GotFlipped			;just bumped it
   ORA $00					;
   STA CurrentEntity_BumpedStateAndBits		;

   LDY #$08					;sidestepper's flipped state animation init
   JMP CODE_D79D				;

;freezie destroyed/coin collected
CODE_D885:
   JSR CODE_CCA0				;
   CMP #$EE					;
   BEQ CODE_D8C1				;end of animation
   CMP #$DD					;
   BEQ CODE_D8AF				;change graphical appearance
   CMP #$CC					;
   BEQ CODE_D89E				;change draw mode or disappear

   LDY PhaseCompleteFlag			;can't raise up if phase complete
   BNE CODE_D89D				;
   CLC						;
   ADC CurrentEntity_YPos			;collected coin raises up
   STA CurrentEntity_YPos			;

CODE_D89D:
   RTS						;

CODE_D89E:
   JSR CODE_CCA0				;
   STA CurrentEntity_DrawMode			;
   CMP #Entity_Draw_8x16			;check if not this specific draw mode
   BNE CODE_D885				;keep speeding up

   LDY #$04					;disappear
   JSR RemoveEntitySpriteTiles_DFC4		;
   JMP CODE_D885				;

CODE_D8AF:
   JSR CODE_CCA0				;
   STA CurrentEntity_DrawTile			;
   CMP #GFX_CollectedCoin_Frame5		;check if at coin's last frame ($ sign)
   BNE CODE_D8C0				;if not, ok

   LDA PhaseCompleteFlag			;if phase beaten
   BNE CODE_D904				;dollar won't show up even

   LDA #OAMProp_Palette2			;dollar sign's palette
   STA CurrentEntity_TileProps			;

CODE_D8C0:
   RTS						;

CODE_D8C1:
   LDA TESTYOURSKILL_Flag			;are we testing our skill?
   BNE CODE_D904				;simply disappear

   LDA PhaseCompleteFlag			;we won?
   BNE CODE_D904				;all coins/freezies simply disappear

   LDA CurrentEntity_YPos			;Y-position for currently processed entity?
   CLC						;
   ADC #$0B					;
   TAX						;

   LDY CurrentEntity_XPos			;X-position for currently processed entity?

   LDA CurrentEntity_WhichPlayerInteracted	;which player gains score
   STA $11					;

   LDA CurrentEntity_ID				;
   CMP #Entity_ID_Freezie			;
   BEQ CODE_D8E5				;

   LDA #Score_ID_800				;spawn score 800 for collected coin
   JSR SpawnScoreSprite_EEE3			;

   LDY #$08					;add 800 to score counter
   BNE CODE_D8F1				;

CODE_D8E5:
   LDA #Score_ID_500				;spawn score 500 for freezie defeat
   JSR SpawnScoreSprite_EEE3			;

   LDA #$00					;freezie is no longer alive
   STA FreezieAliveFlag				;

   LDY #$05					;add 500 to score counter

CODE_D8F1:
   STY $00					;

   LDX CurrentEntity_WhichPlayerInteracted	;
   LDA #$01					;
   STA PlayerScoreUpdateFlag,X			;award score to whoever collected the coin/destroyed freezie
   TXA						;
   ORA #$08					;
   STA $01					;

   JSR CODE_DE83				;update score counter or smth
   JMP CODE_ECA2				;maybe spawn another freezie

CODE_D904:
   LDA #$00					;not active any longer
   STA CurrentEntity_ActiveFlag

   LDY #$04					;sprite tiles begone
   JMP RemoveEntitySpriteTiles_DFC4		;

;checks if the entity is interacting with a solid surface or bump area
;output A - tile acts-like. 0 - nothing, 1 - solid platform, 2 - bump area
;HandleTileInteraction_D90D:
CODE_D90D:
   LDA CurrentEntity_ID				;player entity check
   AND #$0F					;
   BNE CODE_D91A				;players can't come out of pipes. but imagine...

   LDA CurrentEntity_PipeDir			;coming in/out of the pipe?
   BEQ CODE_D91A				;if not, can check for surfaces

   LDA #$00					;technically not touching anything solid
   RTS						;

CODE_D91A:
   LDA POWPowerTimer				;something to do with POW?
   BNE CODE_D988				;

   LDA CurrentEntity_TileAtBottomVRAMPos	;check what tile type is below the entity
   JSR GetTileActsLike_CAA4			;
   CMP #$02					;bump area?
   BEQ CODE_D928				;alright

CODE_D927:
   RTS						;

;calculate how exactly it got bumped (to the right/left or in the middle)
CODE_D928:
   LDX CurrentEntity_CurrentPlatform		;
   LDY CurrentEntity_XPos			;
   JSR CODE_EC67				;who bumped an entity
   JSR CODE_D990				;which part of the bump the entity is interacting with

CODE_D932:
   LDA $00					;is it middle?
   CMP #$30					;
   BEQ CODE_D968				;

   LSR A					;result into low nibble
   LSR A					;
   LSR A					;
   LSR A					;

CODE_D93C:
   STA $1E					;result is movement, left or right

   LDA CurrentEntity_MovementBits		;
   STA Entity_SavedMovementDir			;only used for sidestepper, save direction it was moving in
   AND #$FF^Entity_MovementBits_MovingHorz	;
   ORA $1E					;move right if bumped on the right side, etc.
   STA CurrentEntity_MovementBits		;

CODE_D949:
   LDA CurrentEntity_ID				;check if not player entity
   AND #$F0					;
   BEQ CODE_D965				;

   LDY CurrentEntity_TurningCounter		;turning check?
   BEQ CODE_D965				;
   CMP #Entity_ID_Fighterfly			;don't change draw mode if fighterfly (since it doesnt have a unique turning animation that changes draw mode)
   BEQ CODE_D961				;
   LDY #Entity_Draw_8x16_FlickerTop		;restore sidestepper's draw mode
   CMP #Entity_ID_Sidestepper			;
   BEQ CODE_D95F				;

   LDY #Entity_Draw_8x16_Shift			;for shellcreeper

CODE_D95F:
   STY CurrentEntity_DrawMode			;

CODE_D961:
   LDA #$00					;
   STA CurrentEntity_TurningCounter		;not turning anymore

CODE_D965:
   LDA #$02					;interacted with a bump area
   RTS						;

CODE_D968:
   LDA CurrentEntity_ID				;check player entity
   AND #$0F					;
   BNE CODE_D949				;couldve just branched to CODE_D965 but w/e

   LDA CurrentEntity_MovementBits		;check if even moving horizontally?
   AND #Entity_MovementBits_MovingHorz		;
   BEQ CODE_D93C				;it doesnt have the bit set, nevermind that
   EOR #Entity_MovementBits_MovingHorz		;clear the bit
   JMP CODE_D93C				;

CODE_D979:
   LDA CurrentEntity_TileAtBottomVRAMPos	;
   JSR GetTileActsLike_CAA4			;get tile that is at the bottom
   CMP #$00					;air?
   BEQ CODE_D927				;POW can't affect you

   LDA #$30					;
   STA $00					;act like the entity has been bumped without moving it left and right (bounce in place)
   BNE CODE_D932				;

CODE_D988:
   LDY POWWhoHit				;get player's entity ID
   DEY						;-1 because Mario's ID is 1 and Luigi's 2
   STY PlayerScoreUpdateIndex			;
   JMP CODE_D979				;

;check which part of the bump the entity is touching, left, middle or right
CODE_D990:
   LDA PlatformTileOffset			;
   ASL A					;
   STA $00					;
   ASL A					;
   ASL A					;
   ASL A					;
   CLC						;
   ADC $00					;
   ADC #$A0					;bump animation tile offset

CODE_D99D:
   LDY #$03					;start from leftmost part

CODE_D99F:
   DEY						;
   CMP CurrentEntity_TileAtBottomVRAMPos	;compare with what tile the entity is toucing
   BEQ CODE_D9AD				;if so, the result
   CLC						;
   ADC #$01					;next part
   CPY #$00					;
   BNE CODE_D99F				;
   BEQ CODE_D99D				;then it must be other platform tile bump animation, redo the check

CODE_D9AD:
   LDA DATA_D9B3,Y				;bump result
   STA $00					;
   RTS						;

;bump result: left, middle, right
DATA_D9B3:
.byte $10,$30,$20

;used to set specific palette value for the entity (within their possible palettes table)
CODE_D9B6:
   PHA						;

CODE_D9B7:
   LDY CurrentEntity_PaletteOffset		;restore the entity's its palette
   LDA EnemyPalettes_F638,Y			;
   CMP #$FF					;
   BNE CODE_D9D4				;

   DEC CurrentEntity_PaletteOffset		;keep it at bay (the last table value will be used)
   JMP CODE_D9B7				;

;used to change the enemy's color palette after it stays in flipped form long enough (will move faster)
CODE_D9C5:
   PHA						;
   LDY CurrentEntity_PaletteOffset		;
   INY						;

CODE_D9C9:
   LDA EnemyPalettes_F638,Y			;encountered the end of the table (last possible coloration/speed configuration)
   CMP #$FF					;
   BNE CODE_D9D4				;
   DEY						;
   JMP CODE_D9C9				;

CODE_D9D4:
   STA $1E					;palette

   LDA CurrentEntity_TileProps			;
   AND #$E0					;
   ORA $1E					;change palette (if possible)
   STA CurrentEntity_TileProps			;

   PLA						;
   RTS						;

CODE_D9E0:
   LDA ($06),Y					;draw from this tile
   STA CurrentEntity_DrawTile			;
   INY						;

   LDA ($06),Y					;draw like this
   STA CurrentEntity_DrawMode			;
   RTS						;

;horizontally flip entity sprite tiles based on facing
CODE_D9EA:
   LDA CurrentEntity_MovementBits		;
   LDY #OAMProp_XFlip				;
   LSR A					;right or left?
   BCS CODE_D9F3				;if right (bit 0), flipped

   LDY #$00					;not flipped

CODE_D9F3:
   STY $1E					;

   LDA CurrentEntity_TileProps			;
   AND #$FF^OAMProp_XFlip			;all but x-flip bit ($BF)
   ORA $1E					;which is stored here
   STA CurrentEntity_TileProps			;result
   RTS						;

;go in da pipe maybe
CODE_D9FE:
   LDY CurrentEntity_XPos			;
   LDA CurrentEntity_PipeDir			;did we set its coming-in-the-pipe direction?
   BNE CODE_DA61				;

   LDA CurrentEntity_CurrentPlatform		;lowest platform check?
   BEQ CODE_DA09				;
   RTS						;can get in the pipe

CODE_DA09:
   LDA CurrentEntity_ID				;check if fighterfly
   CMP #Entity_ID_Fighterfly			;
   BNE CODE_DA32				;

   LDA CurrentEntity_MovementBits		;check if airborn...
   AND #Entity_MovementBits_AirMovement		;
   BNE CODE_DA1E				;return...

   LDA CurrentEntity_MovementBits		;check x-position depending on its movement direction (which pipe is it coming in?)
   LSR A					;
   BCS CODE_DA1F				;

   CPY #$40					;left side x-pos check (fighterfly can go in from slightly further)
   BCC CODE_DA24				;

CODE_DA1E:
   RTS						;

CODE_DA1F:
   CPY #$C0					;right side x-pos check (fighterfly)
   BCS CODE_DA24				;
   RTS						;

CODE_DA24:
   LDA CurrentEntity_MovementBits		;
   ORA #Entity_MovementBits_JumpBounce		;now its out and airborn
   STA CurrentEntity_MovementBits		;

   LDA #<DATA_F64D				;$4D lower gravity I think? for when it comes out after
   LDY #>DATA_F64D				;$F6
   LDX #$03					;
   BNE CODE_DA46				;

CODE_DA32:
   LDA CurrentEntity_MovementBits		;check for entity's facing
   LSR A					;
   BCS CODE_DA3C				;

   CPY #$28					;different x-pos check for other entities
   BCC CODE_DA40				;

CODE_DA3B:
   RTS						;

CODE_DA3C:
   CPY #$D8					;
   BCC CODE_DA3B				;
   
CODE_DA40:
   LDA #<DATA_F643				;$43
   LDY #>DATA_F643				;$F6
   LDX #$02					;

CODE_DA46:
   STA CurrentEntity_UpdateDataPointer		;
   STY CurrentEntity_UpdateDataPointer+1	;

   LDA CurrentEntity_MovementBits		;whichever direction it's going
   AND #$03					;it's coming inside of the appropriate pipe
   STA CurrentEntity_PipeDir			;

   LDA CurrentEntity_TileProps			;
   ORA #OAMProp_BGPriority			;go behind background (goes inside the pipe)
   STA CurrentEntity_TileProps			;
   STX CurrentEntity_TimerStorage		;

   LDA #$01					;coming in the pipe x-speed
   STA CurrentEntity_XSpeed			;1 pixel per frame I think

   LDA #$00 					;does not slow down at all
   STA CurrentEntity_XSpeedModifier		;
   RTS						;

CODE_DA61:
   BPL CODE_DAA5				;

   LSR A					;check which pipe is it exiting
   BCC CODE_DA75				;

   CPY #$38					;fully comes out at this position (left)
   BCS CODE_DA6D				;

CODE_DA6A:
   JMP CODE_DB1E				;hasn't come out yet

CODE_DA6D:
   LDA #$00					;
   STA Entity_ComingOutOfLeftPipeFlag		;an entity can come out of the left pipe
   JMP CODE_DA7E				;

CODE_DA75:
   CPY #$C8					;fully comes out at this position (right)
   BCS CODE_DA6A				;

   LDA #$00					;can come out of the right pipe
   STA Entity_ComingOutofRightPipeFlag		;

;the entity has come out of the pipe fully
CODE_DA7E:
   JSR CODE_DB34				;play appropriate sound for the entity that's exiting the pipe
   JSR CODE_CAB9				;setup coming out speed and stuff

   LDA CurrentEntity_TileProps			;behind BG bit off
   AND #$FF^OAMProp_BGPriority			;                 
   STA CurrentEntity_TileProps			;

   LDA #$00					;
   STA CurrentEntity_PipeDir			;not coming out of pipe anymore

   LDA CurrentEntity_ID				;check if the entity is a fighter fly
   CMP #Entity_ID_Fighterfly			;
   BNE CODE_DAC0				;

   LDA #<DATA_F37B				;$7B
   LDY #>DATA_F37B				;$F3                 
   STA CurrentEntity_UpdateDataPointer		;standard vertical speed stuff
   STY CurrentEntity_UpdateDataPointer+1	;

   LDA CurrentEntity_MovementBits		;
   AND #$FF^Entity_MovementBits_AirMovement	;
   ORA #Entity_MovementBits_Fall		;you fell off! out of the pipe I mean
   STA CurrentEntity_MovementBits		;
   RTS						;

CODE_DAA5:  
   JSR CODE_DB1E				;offset y-position if the screen's shaking because of POW (shake with the pipe)

   JSR CODE_CCA0				;apply y-speed (not really...
   CMP #$AA					;
   BEQ CODE_DAC1				;
   TAY						;
   
   LDA CurrentEntity_ID				;
   CMP #Entity_ID_Fighterfly			;
   BNE CODE_DABA				;
   
   LDA CurrentEntity_UpdateTimer		;don't move vertically if the timer hasn't ran out
   BNE CODE_DAC0				;
  
CODE_DABA:
   TYA						;
   CLC						;
   ADC CurrentEntity_YPos			;
   STA CurrentEntity_YPos			;

CODE_DAC0:
   RTS						;

;entity still enters inside the pipe
CODE_DAC1:
   LDY CurrentEntity_XPos			;
   LDA CurrentEntity_PipeDir			;see if the entity has entered bottom-right pipe
   LSR A					;
   BCS CODE_DAE3				;yes, check if fully inside
   CPY #$18					;see if fully inside of the pipe
   BCS CODE_DAC0				;no, return

   LDA #$10					;
   STA CurrentEntity_XPos			;place entity inside the top-left pipe

   LDA Entity_ComingOutOfLeftPipeFlag		;is something already coming out of left pipe?
   BNE CODE_DB19				;stay in shadow relm (or rather, the overscan area where you can see them for a few frames)

   JSR CODE_DFD3				;freezie instead of coin maybe

   LDA #$01					;now it is coming
   STA Entity_ComingOutOfLeftPipeFlag		;

   LDA #$28					;x-pos
   LDY #Entity_MovementBits_MovingRight		;
   BNE CODE_DAFC				;

CODE_DAE3:
   CPY #$E8					;once again, see if fully in the pipe
   BCC CODE_DAC0				;

   LDA #$F0					;place in the top-right
   STA CurrentEntity_XPos			;

   LDA Entity_ComingOutofRightPipeFlag		;is there something coming out of right pipe?
   BNE CODE_DB19				;

   JSR CODE_DFD3				;yet again, see if a freezie should spawn instead of coin

   LDA #$01					;
   STA Entity_ComingOutofRightPipeFlag		;

   LDA #$D8					;
   LDY #Entity_MovementBits_MovingLeft		;

CODE_DAFC:
   STA CurrentEntity_XPos			;
   STY CurrentEntity_MovementBits		;

   LDA #$2C					;y-pos for pipe exit
   STA CurrentEntity_YPos			;

   TYA						;
   ORA #$80					;bit 7 signifies its coming out of the pipe instead of going in
   STA CurrentEntity_PipeDir			;

   LDA #$03					;
   STA CurrentEntity_TimerStorage		;standard timing

   LDA CurrentEntity_ID				;check what enemy is this...
   CMP #Entity_ID_Fighterfly			;fighterfly?
   BNE CODE_DB18				;if not, return
   TYA						;
   ORA #Entity_MovementBits_JumpBounce		;fighterfly technically bounces out of pipe, i guess
   STA CurrentEntity_MovementBits		;

CODE_DB18:
   RTS						;

CODE_DB19:
   LDA #$F4					;
   STA CurrentEntity_YPos			;remain hidden (as hidden as can be if you can't see overscan)
   RTS						;

;apply POW shake y-pos offset if necessary
CODE_DB1E:
   PHA						;
   LDA POWPowerTimer				;if POW is not hit, return
   BEQ CODE_DB2B

   LDA Entity_QuakeYPosOffset			;get y-position offset along with the camera shake
   CLC						;
   ADC CurrentEntity_YPos			;
   STA CurrentEntity_YPos			;

CODE_DB2B:
   PLA						;
   RTS						;

TickXSpeedAlterTimer_DB2D:
   LDA CurrentEntity_XSpeedAlterTimer		;if at zero
   BEQ CODE_DB33				;already done ticking

   DEC CurrentEntity_XSpeedAlterTimer		;tick
   
CODE_DB33:
   RTS

;Play appropriate sound for entity that's fully come out of the pipe
CODE_DB34:
   LDA CurrentEntity_ID				;
   LDX #Sound_Effect_ShellCreeperPipeExit	;
   CMP #Entity_ID_Shellcreeper			;
   BEQ CODE_DB4A				;

   LDX #Sound_Effect_SidestepperPipeExit	;
   CMP #Entity_ID_Sidestepper			;
   BEQ CODE_DB4A				;

   LDX #Sound_Effect_FighterFlyPipeExit		;
   CMP #Entity_ID_Fighterfly			;
   BEQ CODE_DB4A				;

   LDX #Sound_Effect_CoinPipeExit		;coins and freezies use this sound
  
CODE_DB4A:
;alternative code:
;  TXA
;  ORA Sound_Effect
;  STA Sound_Effect
;  RTS

   STX $1E					;

   LDA Sound_Effect				;
   ORA $1E					;play da sound effect
   STA Sound_Effect				;
   RTS						;

CODE_DB53:
   LDY $33					;
   DEY						;
   BEQ CODE_DB33				;no other entities to interact with?
   STY $11					;

   LDA FrameCounter				;alternate between entities it should interact with to face away from every frame
   AND #$01					;
   BNE CODE_DB6B				;

   CPY #$03                 
   BEQ CODE_DB6A				;
   CPY #$04					;
   BEQ CODE_DB6A				;this line is unecessary btw 
   BNE CODE_DB73				;

CODE_DB6A:
   RTS						;

CODE_DB6B:
   CPY #$03					;
   BEQ CODE_DB73				;
   CPY #$04					;
   BNE CODE_DB6A				;

CODE_DB73:
   LDA $A0					;
   STA $14					;

   LDA $A1					;
   STA $15					;

   LDA $A2					;
   CLC						;
   ADC #<Entity_Address_Size			;
   STA $12					;

   LDA #>Entity_Address_Size			;
   STA $13					;

   JSR CODE_CDB4				;setup indirect addressing for entity B

   LDY #$05					;
   LDX #$07					;
   JSR CODE_C44A				;check collision between entities
   AND #$0F					;
   BEQ CODE_DB6A				;
   STA $1F					;save collision direction for entity B
   EOR #$03					;opposite for entity A
   STA $1E					;

;current entity checks
   LDA CurrentEntity_BumpedStateAndBits		;in a special state (bumped, collected, etc)
   ORA CurrentEntity_PipeDir			;going in/out the pipe?
   ORA CurrentEntity_TurningCounter		;already turning around
   BNE CODE_DBC6				;won't turn around, but maybe the other entity will

   LDA CurrentEntity_ID				;check if freezie
   CMP #Entity_ID_Freezie			;
   BNE CODE_DBAC				;

   LDA CurrentEntity_Freezie_FreezeTimer	;performing freeze effect
   BNE CODE_DBC6				;can't turn around I think?

CODE_DBAC:
   LDY #$19					;
   LDA ($14),Y 					;check for VRAM pos? I guess it checks if it has been bumped by something, in which case it won't face away, or something?
   BNE CODE_DBFE				;no interact

   LDA CurrentEntity_MovementBits		;
   AND #$03					;check if interacted from behind
   CMP $1E					;
   BEQ CODE_DBC6				;don't turn around

   LDA CurrentEntity_MovementBits		;do face away
   AND #$FC					;
   ORA $1E					;
   STA CurrentEntity_MovementBits		;

   LDA #$01					;its turning around
   STA CurrentEntity_TurningCounter		;

;entity its supposedly interacts with, same checks
CODE_DBC6:
   LDY #$10					;bumped?
   LDA ($14),Y					;
   LDY #$12					;in/out pipe check
   ORA ($14),Y					;
   LDY #$18					;already turning?
   ORA ($14),Y					;
   BNE CODE_DBFE				;

   LDY #$0F					;
   LDA ($14),Y					;
   CMP #Entity_ID_Freezie			;check if its also freezie
   BNE CODE_DBE2				;

   LDY #$11					;check if its performing freezing action
   LDA ($14),Y					;
   BNE CODE_DBFE				;

CODE_DBE2:
   LDA CurrentEntity_DefeatedState		;check if the entity is kicked out of commission
   BNE CODE_DBFE				;the other entity won't turn when intercecting it

   LDY #$01					;once again, did it get hit from behind?
   LDA ($14),Y					;
   AND #$03					;
   CMP $1F					;
   BEQ CODE_DBFE				;

   LDA ($14),Y					;face away please!
   AND #$FC					;
   ORA $1F					;
   STA ($14),Y					;

   LDY #$18					;
   LDA #$01					;turning away flag for that entity
   STA ($14),Y					;

CODE_DBFE:
   RTS						;

CODE_DBFF:
   LDA CurrentEntity_UpdateTimer		;if shouldnt update yet
   BNE CODE_DBFE				;return

   LDX CurrentEntity_TurningCounter		;is it even turning around?
   BEQ CODE_DBFE				;

   LDA CurrentEntity_MovementBits		;cant perform turning animaion in air
   AND #Entity_MovementBits_AirMovement		;
   BNE CODE_DBFE				;

   LDA CurrentEntity_ID				;fighterfly?
   CMP #Entity_ID_Fighterfly			;
   BEQ CODE_DC55				;different handling of turning

   LDY #$09					;
   CMP #Entity_ID_Sidestepper			;sidestepper?
   BEQ CODE_DC1F				;

   LDY #$00					;
   CMP #Entity_ID_Shellcreeper			;shell creeper
   BNE CODE_DC50				;other entitites don't animate turning

CODE_DC1F:
   DEX						;
   TXA						;
   STY $1E					;
   CLC						;
   ADC $1E					;
   TAY						;
   LDA DATA_F626,Y				;display frame, or...
   CMP #$01					;
   BEQ CODE_DC3B				;$01 - flip horizontally
   CMP #$FF					;
   BEQ CODE_DC44				;$FF - end turning
   STA CurrentEntity_DrawTile			;

   LDA #Entity_Draw_8x16			;both sidestepper and shellcreeper use proper 8x16 drawing when turning around
   STA CurrentEntity_DrawMode			;

CODE_DC38:
   INC CurrentEntity_TurningCounter		;count up
   RTS						;

CODE_DC3B:
   LDA CurrentEntity_TileProps			;flip x
   EOR #OAMProp_XFlip				;
   STA CurrentEntity_TileProps			;
   JMP CODE_DC38				;

CODE_DC44:
   LDA CurrentEntity_ID				;restore draw mode
   LDY #Entity_Draw_8x16_FlickerTop		;sidestepper's
   CMP #Entity_ID_Sidestepper			;
   BEQ CODE_DC4E				;

   LDY #Entity_Draw_8x16_Shift			;shellcreeper's

CODE_DC4E:
   STY CurrentEntity_DrawMode			;

CODE_DC50:
   LDA #$00					;not turning
   STA CurrentEntity_TurningCounter		;
   RTS						;

CODE_DC55:
   CPX #$01					;
   BNE CODE_DC6E				;

   LDA #<DATA_F37B				;$7B
   STA CurrentEntity_UpdateDataPointer		;

   LDA #>DATA_F37B				;$F3
   STA CurrentEntity_UpdateDataPointer+1	;

   LDA CurrentEntity_MovementBits		;
   AND #$FF^Entity_MovementBits_AirMovement	;
   ORA #Entity_MovementBits_Fall		;falling
   STA CurrentEntity_MovementBits		;

   LDA #$02					;
   STA CurrentEntity_TurningCounter		;init over
   RTS						;

CODE_DC6E:
   LDA CurrentEntity_MovementBits		;wait until it lands
   AND #Entity_MovementBits_AirMovement		;
   BEQ CODE_DC50				;then its not turning
   RTS						;

CODE_DC75:
   LDA #<Entity_Address+$40			;entities after Mario and Luigi
   STA $14					;

   LDA #>Entity_Address				;
   STA $15					;

   LDY #$08					;
   LDA TESTYOURSKILL_Flag			;are we in the TEST YOUR SKILL bonus?
   BEQ CODE_DC86				;if not, can only interact with max 8 entities

   LDY #$0A					;actually 10 entities (all coins)

CODE_DC86:
   STY $11					;number of entities we can interact with

   JSR CODE_C446				;try interaction
   STA $1E					;
   ORA #$00					;alright
   BNE CODE_DC92				;if interaction had occured, some consequence

CODE_DC91:
   RTS						;

CODE_DC92:
   LDA CurrentEntity_Player_State		;if the player is in an abnormal state
   BNE CODE_DC91				;don't run the consequence

   LDY #$12					;CurrentEntity_PipeDir-CurrentEntity_Address
   LDA ($14),Y					;if the entity is currently entering/exiting a pipe
   BNE CODE_DC91				;no consequence

   LDY #$19					;$C9-CurrentEntity_Address
   LDA ($14),Y					;is entity already defeated?
   BNE CODE_DC91				;no consequence

   LDY #$0F					;check ID (CurrentEntity_ID-CurrentEntity_Address)
   LDA ($14),Y					;
   CMP #Entity_ID_FloatingCoin			;
   BEQ CODE_DCB9				;
   CMP #Entity_ID_WavyFireball			;wavy fireball
   BEQ CODE_DCBC				;
   CMP #Entity_ID_ReflectingFireball		;a different kind of fireball
   BEQ CODE_DCBF				;
   CMP #Entity_ID_Coin				;check if this was a coin
   BNE CODE_DCC2				;

   JMP CODE_DDC7				;coin interaction

CODE_DCB9:
   JMP CODE_E29A				;float coin interaction

CODE_DCBC:  
   JMP CODE_E9B8				;

CODE_DCBF:  
   JMP CODE_E9B8              			;wait a sec, 2 indentical JMPs???

CODE_DCC2:
   LDY #$10					;CurrentEntity_BumpedStateAndBits-CurrentEntity_Address
   LDA ($14),Y					;
   AND #$0F					;none of the flip bits set...
   BEQ CODE_DCCE

   CMP #$04					;check if enemy's flipped?
   BCC CODE_DD2C				;kicked the enemy

;Hurt the player
CODE_DCCE:
   LDA #$00
   STA $05FF

   LDY CurrentEntity_ID				;check if current player is...
   LDX #$00					;
   DEY						;1 - mario
   BEQ CODE_DCDC				;go ahead

   LDX #$04					;get offset for lives and stuff

CODE_DCDC:
   LDA PlayerLives,X				;if 0 lives
   BEQ CODE_DCE5				;set zero lives flag

   DEC PlayerLives,X				;-1 life like normal
   JMP CODE_DCEA				;

CODE_DCE5:
   INX						;after lives address comes zero lives flag
   LDA #$01					;
   STA PlayerZeroLivesFlag,X			;

CODE_DCEA:
   LDA #Player_State_Hurt			;player's state
   STA CurrentEntity_Player_State		;got hit!

   LDA #$40					;
   STA CurrentEntity_UpdateTimer		;set the timer before dropping down

   LDA #GFX_Player_Hurt				;
   STA CurrentEntity_DrawTile			;

   LDA #Entity_Draw_16x24			;keep player as 16x24
   STA CurrentEntity_DrawMode			;

   LDA #<PlayerDeathYSpeeds_F6A9		;
   LDY #>PlayerDeathYSpeeds_F6A9		;
   STA CurrentEntity_UpdateDataPointer		;prepare a table pointer for bouncing up in air (death animation)
   STY CurrentEntity_UpdateDataPointer+1	;

   LDA Sound_Effect2				;
   ORA #Sound_Effect2_PlayerDead		;yep, the player's dead
   STA Sound_Effect2				;

   LDA $1E                  
   LDY #$00                 
   LSR A                    
   BCS CODE_DD11                
   LDY #$40

CODE_DD11:   
   STY $1E
   
   LDY #$07                 
   LDA ($14),Y              
   AND #$BF
   ORA $1E                  
   STA ($14),Y

   LDY #$01                 
   LDA ($14),Y					;change enemy's direction (Entity_Address+1)
   EOR #$03					;
   STA ($14),Y

   LDY #$03                 
   LDA #$20					;time before changing direction
   STA ($14),Y              
   RTS 
  
CODE_DD2C:
   LDA LastEnemyFlag				;was it the last enemy?
   BEQ CODE_DD3C				;if not, just kick

   LDA #$00					;\disable all sounds, all enemies defeated!
   STA Sound_Effect				;|
   STA Sound_Jingle				;|
   STA Sound_Loop				;/

   LDA #Sound_Effect2_LastEnemyDead		;last enemy dead sound
   BNE CODE_DD40				;

CODE_DD3C:
   LDA Sound_Effect2				;normal kick
   ORA #Sound_Effect2_EnemyKicked		;

CODE_DD40:
   STA Sound_Effect2				;

   LDA #$10					;KICKED
   LDY #CurrentEntity_DefeatedState-CurrentEntity_Address	;i really need to figure out if I can shorten this, because BOI DOES THIS NOT LOOK PRETTY
   STA ($14),Y					;

   LDA #<KickedEnemyXAndYSpeeds_F7E9		;set enemy's speed table, gets kicked down
   LDY #CurrentEntity_UpdateDataPointer-CurrentEntity_Address
   STA ($14),Y					;

   LDA #>KickedEnemyXAndYSpeeds_F7E9		;
   INY						;
   STA ($14),Y					;get this           outta here

   LDA CurrentEntity_MovementBits		;check whichever way the player moved
   AND #Entity_MovementBits_MovingHorz		;
   BNE CODE_DD5E				;

   LDA Entity_InteractionSide			;if they were stationary, then check what side they touched from
   AND #$0F					;

CODE_DD5E:
   LSR A					;send an enemy flying in the appropriate direction
   BCS CODE_DD65				;

   LDA #$FF					;move right
   BNE CODE_DD67				;

CODE_DD65:
   LDA #$00					;no speed for left???

CODE_DD67:
   LDY #CurrentEntity_XSpeed-CurrentEntity_Address
   STA ($14),Y					;speed

   LDY #CurrentEntity_TimerStorage-CurrentEntity_Address
   LDA #$01					;update with this frequency (every other frame)
   STA ($14),Y					;
   INY						;(CurrentEntity_UpdateTimer-CurrentEntity_Address)
   STA ($14),Y					;set the timer

   LDX #$02					;

   LDY CurrentEntity_ID				;check what player kicked the enemy
   DEY						;
   STY $11					;0 - mario, 1 - luigi
   BNE CODE_DD7F				;

   LDX #$00					;

CODE_DD7F:
   LDA Combo_Timer,X				;combo timer still on?
   BNE CODE_DD89				;

   LDA #$00					;if it ran out, start from all over
   STA Combo_Value,X				;

CODE_DD89:
   LDA #$34					;set combo timer
   STA Combo_Timer,X				;

   LDA Combo_Value,X				;
   STA $1F					;
   CMP #$03					;cap combo
   BEQ CODE_DD9A				;

   INC Combo_Value,X				;increase combo with each hit

CODE_DD9A:
   LDY #CurrentEntity_YPos-CurrentEntity_Address
   LDA ($14),Y					;place score above defeated entity 
   TAX						;
   INY						;(CurrentEntity_XPos-CurrentEntity_Address)
   LDA ($14),Y					;at x-pos
   TAY						;
   LDA $1F					;
   JSR SpawnScoreSprite_EEE3			;spawn score based on kill combo

   LDX $1F					;and actually add score
   LDA ComboScoreValues_DDB0,X			;
   JMP CODE_DDB6				;

ComboScoreValues_DDB0:
.byte $08,$16,$24,$32				;800, 1600, 2400 and 3200 respectively.

   LDA #$08					;unused? would make it so only 800 score is awarded

CODE_DDB6:
   STA $00					;

   LDX CurrentEntity_ID				;set current player's score to update
   DEX						;
   LDA #$01					;
   STA PlayerScoreUpdateFlag,X			;

   TXA						;
   ORA #$08					;
   STA $01					;
   JMP CODE_DE83				;

CODE_DDC7:
   LDY #$10					;
   LDA ($14),Y					;if it's already collected by someone (and plays the animation
   BNE CODE_DE04				;do nothing
   TYA						;
   LDY #$19					;become collected
   STA ($14),Y					;

   LDX CurrentEntity_ID				;current player's entity ID
   DEX						;
   TXA						;

   LDY #$1C					;
   STA ($14),Y					;remember which player collected this coin

   LDA Sound_Effect				;coin sound effect
   ORA #Sound_Effect_CollectedCoin		;
   BNE CODE_DE2C				;

CODE_DDE0:
   LDA CurrentEntity_UpdateTimer		;a timer?
   CMP #$04					;
   BCS CODE_DE04				;

   LDA CurrentEntity_Player_State		;
   AND #$F0					;
   CMP #Player_State_Splash			;check if in water splash state
   BEQ CODE_DE2F				;

   LDA #GFX_Player_FallDown			;show the player as falling down
   STA CurrentEntity_DrawTile

   JSR CODE_CCA0				;
   CMP #$AA					;ended hardcoded vertical speed values?
   BNE CODE_DDFB				;

   LDA #$03					;move 3 pixels every frame from then on

CODE_DDFB:
   CLC						;
   ADC CurrentEntity_YPos			;
   CMP #$E8					;if the entity's low enough
   BCS CODE_DE05				;generate a splash

CODE_DE02:
   STA CurrentEntity_YPos			;

CODE_DE04:
   RTS						;

CODE_DE05:
   LDA #Player_State_Splash			;
   STA CurrentEntity_Player_State		;player's splash state

   LDA CurrentEntity_OAMOffset			;remove player's display
   JSR CODE_C3F5				;

CODE_DE0E:
   LDA #Entity_Draw_16x16			;I guess the first frame will be almost instantenious
   STA CurrentEntity_DrawMode			;
   STA CurrentEntity_UpdateTimer		;

   LDA #SplashAnimCycle_Start			;point to splash GFX
   STA CurrentEntity_AnimationPointer		;

   LDA #$05					;animation timer (animate every 5 frames)
   STA CurrentEntity_TimerStorage		;

   LDA #$E0					;
   STA CurrentEntity_YPos			;fix its Y-position

   LDA #Splash_OAMProp				;
   STA CurrentEntity_TileProps			;

   LDA LastEnemyFlag				;if it was the last enemy
   BNE CODE_DE2E				;don't play the splash sound effect

   LDA Sound_Effect				;
   ORA #Sound_Effect_Splash			;

CODE_DE2C:
   STA Sound_Effect				;

CODE_DE2E:
   RTS						;

;water splash state
CODE_DE2F:
   JSR CODE_CAEB

   LDA CurrentEntity_DrawTile			;is it splash's last graphical frame?
   CMP #GFX_Splash_Frame3			;
   BEQ CODE_DE3B				;
   JMP UpdateEntityGFXFrame_CEA3		;keep animating

CODE_DE3B:
   LDY #$04					;remove splash sprite tiles
   JSR RemoveEntitySpriteTiles_DFC4		;

   LDA CurrentEntity_ID				;if it wansn't a player that splashed
   AND #$0F					;
   BEQ CODE_DE4E				;just remove

   LDA #Player_State_Dead			;player is officially dead
   STA CurrentEntity_Player_State		;

   LDA #$F4					;place the player offscreen for a moment
   BNE CODE_DE02				;

CODE_DE4E:
   LDA PhaseCompleteFlag			;check if in a win situation
   BEQ CODE_DE57				;if not, something else can be spawned in this slot

   LDA #$00					;remove this entity
   STA CurrentEntity_ActiveFlag			;
   RTS						;

CODE_DE57:
   LDX CurrentEntity_OAMOffset			;

   LDA CurrentEntity_XPos			;save x-pos so its not actually overwritten
   PHA						;
   LDY #$00					;

CODE_DE5E:
   LDA DATA_F6C8,Y				;spawn MONEY
   STA CurrentEntity_Address,Y			;

   INY						;
   CPY #<Entity_Address_Size			;
   BNE CODE_DE5E				;loop through all entity variables

   STX CurrentEntity_OAMOffset			;keep its OAM offset

   PLA						;
   LDY #Entity_MovementBits_MovingRight		;
   LDX #$F0					;
   CMP #$80					;check if died on the right side of the screen?
   BCS CODE_DE78				;will spawn from the right pipe

   LDY #Entity_MovementBits_MovingLeft		;
   LDX #$10					;

CODE_DE78:
   STY CurrentEntity_PipeDir			;a pipe come-out direction
   STY CurrentEntity_MovementBits		;move direction is the same
   STX CurrentEntity_XPos			;

   LDY #$04					;
   JMP RemoveEntitySpriteTiles_DFC4		;remove sprite tiles (potentially a second time)

;score calculation routine (prep).
;input:
;$00 - how much score to add/substract.
;$01 - score or counter offset (bits 0-2), valid values are listed below. bit 3 - do calculation with ones and tens, otherwise hundreds and thousands

;prep for score addition
;AddToScoreCounter_DE83:
CODE_DE83:
   LDA DemoFlag					;
   BNE CODE_DEAE				;don't give points during demo mode

   LDX #$00					;
   STX $04					;never takes away score (if it was set to #$FF, would do substraction instead(

   LDX #$00           				;no substraction, might as well have not used LDX #$00 twice 
   STX $05					;tens and hundreds of thousands init
   STX $06					;hundreds and thousands init
   STX $07					;tens and ones init

   LDA $01					;check how much score it should award (tens and ones, or hundreds and thousands?)
   AND #$08					;
   BNE CODE_DE9A				;

   INX						;reward tens and ones

CODE_DE9A:
   LDA $00					;give this much score
   STA $06,X					;

   LDA $01					;
   JMP CODE_D0B4				;actual score updating routine

;init for player entity
CODE_DEA3:
   LDX #<Entity_Address_Size-1			;

CODE_DEA5:
   LDA SpawnInitValues_Players_F2EC,Y		;
   STA CurrentEntity_Address,X			;
   DEY						;
   DEX						;
   BPL CODE_DEA5				;

CODE_DEAE:
   RTS						;

CODE_DEAF:
   LDA CurrentEntity_DefeatedState		;
   AND #$F0					;
   CMP #$20					;
   BNE CODE_DEBA				;haven't dipped itself in water yet

   JMP CODE_DE2F				;handle splash

;entity has been kicked by the player, fall down to their watery doom
CODE_DEBA:
   JSR CODE_CCA0				;you're going down (and to the side)
   CMP #$AA					;
   BNE CODE_DEC3				;check for terminator byte, if haven't encountered it yet, go down slower (mostly)

   LDA #$04					;constant vertical speed, down you go!

CODE_DEC3:
   CLC						;
   ADC CurrentEntity_YPos			;
   CMP #$E8					;check if at the bottom
   BCS CODE_DEE0				;
   STA CurrentEntity_YPos			;update position

   JSR CODE_CCA0				;horizontal movement
   CMP #$AA					;
   BEQ CODE_DEDF				;again, terminator byte, if hit, it'll go straight down only
   EOR CurrentEntity_XSpeed			;basically checks its direction, if it goes right or left
   BPL CODE_DEDA				;will go left
   CLC						;
   ADC #$01					;go right

CODE_DEDA:
   CLC						;
   ADC CurrentEntity_XPos			;
   STA CurrentEntity_XPos			;move it!

CODE_DEDF:
   RTS						;

CODE_DEE0:
   LDA #$20					;create a splash
   STA CurrentEntity_DefeatedState		;

   LDY #$04					;prepare sprite tiles for the splash effect
   JSR RemoveEntitySpriteTiles_DFC4		;
   JMP CODE_DE0E				;init splash

CODE_DEEC:
   LDA CurrentEntity_Player_State		;check the player's state
   LDY CurrentEntity_ID				;
   CMP #Player_State_Dead			;is set to respawn?
   BNE CODE_DF37				;if not, continue checking

   DEY						;is it Mario or Luigi?
   BNE CODE_DF24				;if luigi, luigi begone

   JSR CODE_D5E6				;Mario's lives display

   LDA Player1TriggerGameOverFlag		;if not set to game over
   BEQ CODE_DF07				;continue on

CODE_DEFE:
   LDA #$00					;
   STA CurrentEntity_ActiveFlag			;player is no longer active

   LDY #$06					;remove all of player's tiles from view
   JMP RemoveEntitySpriteTiles_DFC4		;

CODE_DF07:
   LDY #$1F					;re-initialize Mario
   JSR CODE_DEA3				;

   JSR CODE_DF9D				;spawn respawn platform

   LDA #$74					;respawn x-pos for mario

CODE_DF11:
   STA CurrentEntity_XPos

   LDA #$09					;
   STA CurrentEntity_YPos			;

   LDA #Player_State_AppearAfterDeath		;
   STA CurrentEntity_Player_State		;

   LDA Sound_Jingle				;appear at the top of the screen
   ORA #Sound_Jingle_PlayerReappear		;
   STA Sound_Jingle				;
   JMP CODE_CEBA				;

CODE_DF24:  
   JSR CODE_D5EC				;luigi's lives display
   
   LDA Player2TriggerGameOverFlag		;
   BNE CODE_DEFE				;can't respawn

   LDY #$3F					;re-initialize Luigi
   JSR CODE_DEA3				;

   JSR CODE_DFAC				;

   LDA #$8C					;respawn x-pos for luigi
   BNE CODE_DF11				;

CODE_DF37:
   CMP #$02					;is set to come down with the respawn platform?
   BNE CODE_DF60				;

   JSR CODE_CAEB				;

   INC CurrentEntity_YPos			;move the player down with the platform

   JSR GetRespawnPlatOAM_DFB0			;

   INC RespawnPlatform_OAM_Y,X			;
   INC RespawnPlatform_OAM_Y+4,X		;move respawn platform down

   LDA CurrentEntity_YPos			;if the player is at this position, don't move down anymore
   CMP #$28					;
   BEQ CODE_DF50				;
   RTS						;

CODE_DF50:
   LDA #Player_State_P1OnRespawnPlatform	;
   LDY CurrentEntity_ID				;on respawn platform state depending on which player
   DEY						;
   BEQ CODE_DF59				;
   
   LDA #Player_State_P2OnRespawnPlatform	;I don't know what the difference is between these two values other than... being different values.

CODE_DF59:
   STA CurrentEntity_Player_State		;

CODE_DF5B:
   LDA #$FF					;
   STA CurrentEntity_UpdateTimer		;
   RTS						;

CODE_DF60:
   LDA CurrentEntity_MovementBits		;check player's bits
   BEQ CODE_DF87				;no bit set - keep on platform
   BMI CODE_DF6C				;jumped off - remove the platform
   AND #Entity_MovementBits_CantMove		;I guess check if bumped by a player and this got unset?
   BNE CODE_DF87				;
   BEQ CODE_DF72				;otherwise we've pressed a direction button, let the player go

CODE_DF6C:
   LDA #GFX_Player_Jumping			;show player's jumping frame
   STA CurrentEntity_DrawTile			;
   BNE CODE_DF75				;

CODE_DF72:
   JSR UpdateEntityGFXFrame_CEA3		;show a walking frame

CODE_DF75:
   LDA #$00					;
   STA CurrentEntity_Player_State		;let the player go
   STA CurrentEntity_UpdateTimer		;no more platform timer

   JSR GetRespawnPlatOAM_DFB0			;get platform's OAM

   LDA #$F4					;remove platform
   STA RespawnPlatform_OAM_Y,X			;
   STA RespawnPlatform_OAM_Y+4,X		;

CODE_DF86:
   RTS						;

CODE_DF87:
   LDA CurrentEntity_UpdateTimer		;see if the platform should decease
   BNE CODE_DF86				;no, return

   JSR GetRespawnPlatOAM_DFB0			;

   LDA RespawnPlatform_OAM_Tile,X		;see of respawn platform was at it's last "health"
   CMP #RespawnPlatform_Tile3			;aka super thin
   BEQ CODE_DF75				;drop the player and the platform disappears
   
   INC RespawnPlatform_OAM_Tile,X		;change platform's tile
   INC RespawnPlatform_OAM_Tile+4,X		;
   BNE CODE_DF5B				;and restore the timer

;initialize respawn platform
CODE_DF9D:
   LDY #$07					;OAM offset for mario

CODE_DF9F:   
   LDX #$07					;

CODE_DFA1:   
   LDA DATA_F699,Y				;init values
   STA RespawnPlatform_OAM_Y,Y			;
   DEY						;
   DEX						;
   BPL CODE_DFA1				;
   RTS						;

CODE_DFAC:
   LDY #$0F					;OAM offset for luigi
   BNE CODE_DF9F				;

;get respawn platform's OAM offset
;CODE_DFB0:
GetRespawnPlatOAM_DFB0:
   LDX #$08					;platform sprite tiles offset for luigi
   LDY CurrentEntity_ID				;
   DEY						;
   BNE CODE_DFB9

   LDX #$00					;platform sprite tiles offset for mario

CODE_DFB9:
   RTS						;

;won't run player's tile check stuffs, skip over
SkipPlayerVRAMPosition_DFBA:
   JSR SkipEntityVRAMPosition_DFBD		;run twice (because player checks for two positions - top for bumping, and bottom for grounding itself (like pretty much everything else)

;won't run entity's tile check stuffs, skip over
SkipEntityVRAMPosition_DFBD:
   INC Entity_VRAMPositionIndex			;
   INC Entity_VRAMPositionIndex			;
   RTS						;

;this routine is used to remove sprite tiles for current entity
;Input Y - amount of tiles to remove
RemoveEntitySpriteTiles_DFC4:
CODE_DFC4:
   LDA #$F4					;
   LDX CurrentEntity_OAMOffset			;remove current entity's OAM tiles

CODE_DFC8:
   STA OAM_Y,x					;
   INX						;
   INX						;
   INX						;
   INX						;
   DEY						;
   BNE CODE_DFC8				;loop untill all tiles have been removed
   RTS						;

CODE_DFD3:
   LDA CurrentEntity_ID				;check if coin is coming out
   CMP #Entity_ID_Coin				;
   BNE CODE_DFF7				;

   LDY #$00					;
   LDA $C1					;coin collected flag?
   BNE CODE_DFF5				;

;you missed collecting a coin. oops!
   PLA						;further processing will be terminated.
   PLA						;

   LDA FreezieCanAppearFlag			;can freezie appear?
   BEQ CODE_DFEE				;

   LDA FreezieAliveFlag				;is there freeze present?
   BNE CODE_DFEE				;
   JMP CODE_ECAF				;instead, there'll be a freezie!

CODE_DFEE:
   STY CurrentEntity_ActiveFlag			;nothing comes out. bummer

   LDY #$02					;
   JMP RemoveEntitySpriteTiles_DFC4		;erase coin's sprite tiles

CODE_DFF5:
   STY $C1					;the coin can be collected and it comes out

CODE_DFF7:
   RTS						;

;used to draw game over string (if necessary)
CODE_DFF8:
   LDA BufferDrawFlag				;drawing something? anything?
   BNE CODE_DFF7				;return
   
   LDA $04C5					;some flag i don't know about?
   BNE CODE_DFF7				;return

   LDX #<EmptyString_E0A8			;load empty string by default     
   LDY #>EmptyString_E0A8			;

   LDA GameOverStringTimer			;remove game over string timer
   BEQ CODE_E00F				;if 0, nothing to remove, maybe remove phase string

   DEC GameOverStringTimer			;
   BEQ CODE_E049				;fun fact: i missed this branch and had no label for it for a while

CODE_E00F:
   LDA PhaseStringTimer				;timer for "PHASE X" removal
   BEQ CODE_E023				;

   DEC PhaseStringTimer				;
   BNE CODE_E023				;

   LDA #$49					;VRAM pos ($2249)
   STA $00					;

   LDA #$22					;
   STA $01					;
   BNE CODE_E051				;remove PHASE string

CODE_E023:
   LDX #<GameOverString_E088			;GAME OVER string for if both players have game overed (or just Mario in 1P mode)            
   LDY #>GameOverString_E088			;

   LDA Player1TriggerGameOverFlag		;show mario game over string?
   BEQ CODE_E058				;check luigi instead

   LDA Entity_Mario_ActiveFlag			;check if mario's active
   BNE CODE_E058				;yes? check luigi

   LDA TwoPlayerModeFlag			;check for player 2
   BEQ CODE_E03C				;

   LDA Player2GameOverFlag			;did luigi game over, too?
   BNE CODE_E03C				;if so, we're displaying GAME OVER

   LDX #<MarioGameOverString_E078		;MARIO GAME OVER   
   LDY #>MarioGameOverString_E078		;

CODE_E03C:
   LDA #$00					;triggered game over, reset this
   STA Player1TriggerGameOverFlag		;

   LDA #$FF					;set actual game over
   STA Player1GameOverFlag			;

CODE_E044:
   LDA #$FF					;
   STA GameOverStringTimer			;timer for game over string

CODE_E049:
   LDA #$89					;VRAM address for game over string ($2189)
   STA $00					;

   LDA #$21					;
   STA $01					;

CODE_E051:
   STX $02					;
   STY $03					;
   JMP CODE_CE2C				;

CODE_E058:
   LDA Player2TriggerGameOverFlag		;show game over string?
   BEQ CODE_E077				;no, return

   LDA Entity_Luigi_ActiveFlag			;is luigi still on screen?
   BNE CODE_E077				;yes, return

   LDA TwoPlayerModeFlag			;are we in 2 player mode even?
   BEQ CODE_E06D				;no, don't even question

   LDA Player1GameOverFlag			;did player 1 game over as well?
   BNE CODE_E06D				;yes, show GAME OVER for both

   LDX #<LuigiGameOverString_E098		;LUIGI GAME OVER
   LDY #>LuigiGameOverString_E098		;

CODE_E06D:
   LDA #$00					;showing game over string once
   STA Player2TriggerGameOverFlag		;

   LDA #$FF					;luigi game over
   STA Player2GameOverFlag			;
   BNE CODE_E044				;

CODE_E077:
   RTS						;

;Strings, use row format (CODE_CE2C)
;first byte is the length of string(s) in low nibble, and high nibble is number of rows (strings) to draw, by default it's always 1 row

;MARIO GAME OVER
MarioGameOverString_E078:
.byte @StringEnd-@StringStart|$10		;really wish I could use a macro, but alas, the macro labels are global
@StringStart:
	.byte "MARIO GAME OVER"			;but hey, you can now directly edit the text without referencing game's character mapping. pretty cool, huh?
@StringEnd:

;if both players are dead in 2P mode or 1 player in 1P
;   GAME OVER   
GameOverString_E088:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "   GAME OVER   "
@StringEnd:

;LUIGI GAME OVER
LuigiGameOverString_E098:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "LUIGI GAME OVER"
@StringEnd:

;Empty string
EmptyString_E0A8:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "               "
@StringEnd:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This subroutine resets RAM addresses $0300-$0400 (entity-related).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;USED RAM ADRESSES:
;$00 - RAM Pointer (low byte)
;$01 - RAM Pointer (high byte)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CODE_E0B8:
   LDA #$03				;set-up range for ram clean-up
   STA $01				;

   LDA #$00 				;
   STA $00				;
   TAY					;
   JSR CODE_CA35			;first clear $0300-$03FF

   LDA #$04				;then set-up range and clear $0400-$04FF
   STA $01				;

   LDA #$00				;
   STA $00				;
   TAY					;
   JMP CODE_CA35			;

;this table is used to set certain properties on phase load - enemy level, if it's a TEST YOUR SKILL phase and so on
;For what enemies spawn per enemy level, see DATA_F3BA
;First byte - enemy level or if $AA, if it's a TEST YOUR SKILL phase, if FF, set to certain position in table to repeat (don't read past the table)
;Second byte - platform tile offset - which tile to use for the platforms (visual)
;Third byte - wavy (green) fireball frequency (with lower values meaning low frequency)
;Forth byte - diagonal (red) fireball frequency
DATA_E0D0:
.byte $00,$00,$00,$00
.byte $01,$00,$00,$00

;TEST YOUR SKILL start with $AA.
;Second byte - ledge tile offset, $04 - slippery surface (i think)
;3rd byte - Time in seconds.
.byte $AA,$03,$20

.byte $02,$01,$00,$00
.byte $03,$01,$01,$00
.byte $04,$02,$01,$01
.byte $05,$02,$01,$01
.byte $AA,$04,$20

.byte $06,$03,$02,$01
.byte $07,$03,$02,$01
.byte $08,$03,$02,$02
.byte $09,$03,$02,$02
.byte $AA,$04,$15					;from this phase, timer is set to 15 sec (although it shows 20 for a few frames, before snapping to the intended value)

.byte $0A,$03,$03,$02
.byte $07,$03,$03,$02
.byte $09,$03,$03,$03
.byte $09,$03,$03,$04
.byte $AA,$04,$15

.byte $0A,$03,$03,$04
.byte $07,$03,$03,$04
.byte $09,$03,$03,$04
.byte $09,$03,$03,$04
.byte $FF

;Demo phase properties
.byte $0B,$00,$00,$00

;this game mode is simply waiting a bit after which set next phase stored in GameplayModeNext
CODE_E129:
   LDA TransitionTimer				;check for timer
   BNE CODE_E131				;return if ticking

   LDA GameplayModeNext				;\set next gamemode
   STA GameplayMode				;/

CODE_E131:
   RTS						;

DisableRender_E132:
   JSR WaitForNMI_D5DC				;wait for NMI

   LDA Reg2001BitStorage			;\
   AND #$E7					;|turn off sprite and background display
   STA RenderBits				;/
   RTS						;

EnableRender_E13D:
   JSR WaitForNMI_D5DC				;wait for NMI

   LDA Reg2001BitStorage			;\
   ORA #$18					;|enable sprites and background display
   STA RenderBits				;|
   STA Reg2001BitStorage			;/
   RTS						;

CODE_E14A:   
   JSR CODE_E0B8				;reset some RAM adresses

   LDX PhaseLoad_PropIndex			;get phase properties index

CODE_E14F:
   LDA DATA_E0D0,X				;if first property byte is           
   CMP #$AA                 			;$AA, it's "Test Your Skill" time.
   BNE CODE_E188                		;no? well...
   INX						;
   LDA DATA_E0D0,X				;second prop. byte
   STA PlatformTileOffset			;contains 8x8 tile index platforms are made of

   INX						;
   LDA DATA_E0D0,X				;third prop. byte is initial timer, seconds
   STA BonusTimeSecs				;

   INX						;
   STX PhaseLoad_PropIndex			;store index+1 for next property load

   LDA CurrentPhase				;If phase's number is less than 7
   CMP #$07					;
   BCC CODE_E170				;don't restore POW

   LDA #$03					;after bonus, POW is restored
   STA POWHitsLeft				;

CODE_E170:
   LDA #$BB                 			;
   STA EntitySpawnIndex				;don't spawn entities in bonus phase

   JSR CODE_D67F				;put in players

   LDA #MarioInTestYourSkill_OAM_Slot*4		;player 1 takes OAM slots from this point
   STA Entity_Mario_OAMOffset			;

   LDA #LuigiInTestYourSkill_OAM_Slot*4		;player 2 hogs OAM tiles starting here
   STA Entity_Luigi_OAMOffset			;

   LDA #$01					;skip over some code
   STA TESTYOURSKILL_Flag			;
   BNE CODE_E1C4				;

CODE_E188:
   CMP #$FF					;Or $FF, repeat
   BNE CODE_E190				;

   LDX #$41					;I assume this makes load previous properties, ending up in a repeat (so it doesn't end up loading incorrect values and cause "Kill Screen")
   BNE CODE_E14F				;start prop. loading over

CODE_E190:
   LDA DATA_E0D0,X				;store first prop. byte in $34 (not sure why you have to reload it but whatev)
   STA EnemyLevel				;contains "enemy level"

   INX						;second prop.
   LDA DATA_E0D0,X				;contains platform tile index
   STA PlatformTileOffset			;in da $32

   INX						;
   LDY #$01					;
   LDA CurrentPhase				;if phase number is less than 8, don't make freezies appear
   CMP #$08					;
   BCC CODE_E1A7				;
   STY FreezieCanAppearFlag			;
   
CODE_E1A7:
   LDA DATA_E0D0,X				;third prop.
   STA WaveFireball_SpawnTimerIndex		;timer index for wavy fireball frequency
   
   INX						;forth and last phase prop.
   LDA DATA_E0D0,X				;
   STA $04FC					;timer index for diagonal reflecting fireball frequency
   INX						;
   STX PhaseLoad_PropIndex			;store prop. index for next time we enter this routine

   LDA #$00					;reset "enemies to defeat" index (?)
   STA EntitySpawnIndex				;

   JSR CODE_E97A				;initialize fireball spawn timers
   JSR CODE_D67F				;put players in the game!
   JSR CODE_D69A				;

CODE_E1C4:
   JSR CODE_D672				;next phase, add a +1 to the phase number
   JSR CODE_D3F9				;
   
   LDA #$02					;
   BNE CODE_E1F4				;
   
CODE_E1CE:
   LDA EntitySpawnIndex				;are there more enemies to spawn?
   CMP #$AA					;
   BNE CODE_E1F6				;yes, return

   LDA $45					;unknown flag, defeated all enemies flag?
   BNE CODE_E1F6				;

   LDA TransitionTimer				;transitioning?
   BNE CODE_E1F6				;return

   LDY #$FF					;
   LDA Player1TriggerGameOverFlag		;check if player 1 has game overed
   BEQ CODE_E1E4				;
   STY Player1GameOverFlag			;if so, don't show up

CODE_E1E4:
   LDA Player2TriggerGameOverFlag		;check luigi now
   BEQ CODE_E1EA				;
   STY Player2GameOverFlag			;don't show (oddly enough this line doesn't actually trigger. hm...)

CODE_E1EA:
   LDA #$10					;

CODE_E1EC:
   STA TransitionTimer				;

   LDA #$01					;load phase after we set some things
   STA GameplayModeNext				;

   LDA #$09					;

CODE_E1F4:
   STA GameplayMode				;

CODE_E1F6:
   RTS						;

;update score
CODE_E1F7:
   LDA BufferDrawFlag				;updating something else?
   BNE CODE_E219				;return

   LDA FreezePlatformFlag			;freezing platform?
   BNE CODE_E219				;do nothing

   LDY #$00					;
   LDA Player1ScoreUpdateFlag			;see if we should update player 1's score
   BEQ CODE_E20F				;no, check player 2
   STY Player1ScoreUpdateFlag			;update once ofc

   LDA #$F0					;some kinda offset?

CODE_E20A:
   STA $00					;
   JMP CODE_D02F				;

CODE_E20F:
   LDA Player2ScoreUpdateFlag			;
   BEQ CODE_E219				;
   STY Player2ScoreUpdateFlag			;

   LDA #$F1					;
   BNE CODE_E20A				;

CODE_E219:
   RTS						;

CODE_E21A:
   LDA #$F9					;
   STA $00					;
   JSR UpdateTOPScore_D18B			;Top score stuff

   LDA Player1_Got1UPFlag			;did the player 1 get 1-up already?
   BNE CODE_E239				;if yes, return

   LDA Player1GameOverFlag			;
   BNE CODE_E239				;

   LDA Player1Score				;if player's score is less than 20000
   CMP #TensHundredsThousandsScoreFor1Up	;no 1-up
   BCC CODE_E239				;

   INC Player1_Got1UPFlag			;
   INC Player1Lives				;
   JSR CODE_D5E6				;redraw mario's lives
   JMP CODE_E24E				;check if should play the sound effect

CODE_E239:
   LDA Player2_Got1UPFlag			;don't receive a 1-up if already did
   BNE CODE_E25F

   LDA Player2GameOverFlag			;if player 2 has also gameovered
   BNE CODE_E25F				;

   LDA Player2Score				;check for 20000 score
   CMP #TensHundredsThousandsScoreFor1Up	;if less, no extra life
   BCC CODE_E25F				;but check if player 1 has gotten a 1-up and should play a sound effect

   INC Player2_Got1UPFlag			;
   INC Player2Lives				;
   JSR CODE_D5EC				;

CODE_E24E:
   LDA TransitionTimer				;if not transitioning, play sound now	
   BEQ CODE_E258				;

   LDA #$01					;otherwise delay the sound
   STA Player_Got1UPFlag_SoundFlag		;
   BNE CODE_E25E				;(RTS also works, y'know)

CODE_E258:
   LDA Sound_Jingle				;play pause sound (for extra life, not actual pause)
   ORA #Sound_Jingle_Pause			;
   STA Sound_Jingle				;

CODE_E25E:
   RTS						;

CODE_E25F:
   LDA TransitionTimer				;transitioning? return!
   BNE CODE_E25E				;

   LDA Player_Got1UPFlag_SoundFlag		;did any player get a 1-UP?
   BEQ CODE_E25E				;no, return

   LDA #$00					;reset this flag and play the sound
   STA Player_Got1UPFlag_SoundFlag		;
   BEQ CODE_E258				;play the sound effect

;play game over
CODE_E26D:
   LDA Player1GameOverFlag			;check if player 1's out
   BEQ CODE_E25E				;no, return

   LDA Player2GameOverFlag			;player 2?
   BEQ CODE_E25E				;still in the game, return

   LDA #$00					;
   STA TitleScreen_DemoCount			;play title screen song when back at the title screen

   JSR MuteSounds_D4FE				;no sounds

   LDA #Sound_Jingle_GameOver			;game over!
   STA Sound_Jingle				;

   LDA #$20					;
   STA TransitionTimer				;

   LDA #$0B					;game over state
   STA GameplayMode				;

   JMP RemoveSpriteTiles_CA2B			;remove all sprite tiles

;Game Over Mode
CODE_E28B:
   LDA TransitionTimer				;wait for timer
   BNE CODE_E299				;

   LDA #$01					;
   STA DemoFlag					;demo mode at the title screen
   STA TitleScreen_SelectHeldFlag		;can't hold select?

   LDA #$00					;
   STA NonGameplayMode				;init title screen

CODE_E299:
   RTS						;

CODE_E29A:
   LDY #$10					;
   LDA ($14),Y					;see if the coin has actually been collected.
   BNE CODE_E2AA				;

   LDA CurrentEntity_ID				;what player collected this
   STA ($14),Y					;

   LDA Sound_Effect				;play coin collected sound
   ORA #Sound_Effect_CollectedCoin		;
   STA Sound_Effect				;

CODE_E2AA:
   RTS						;

CODE_E2AB:
   LDA TESTYOURSKILL_Flag			;check TEST YOUR SKILL flag
   BNE CODE_E2B1				;
   RTS						;

;spawn floating coins for TEST YOUR SKILL bonus
CODE_E2B1:
   CMP #$01					;if initialized
   BNE CODE_E329				;run TEST YOUR SKILL!
   
   LDA #<Entity_Address+$40			;initialize coins starting from entity $02
   STA EntityDataPointer
   
   LDA #>Entity_Address
   STA EntityDataPointer+1			;the address 
   
   LDA #$20                 
   STA $12
   
   LDA #$00     
   STA $13
   
   LDA #$0A                 
   STA $33
   
   LDX #$00
   LDA #$30                 
   STA $11
   
CODE_E2CF:
   LDY #$00
   
CODE_E2D1:
   LDA SpawnInitValues_FloatingCoin_E6C5,Y	;
   CPY #$0A					;check if we're storing OAM index
   BNE CODE_E2E4				;check something else
   
   LDA $11					;adjust the OAM stuff for each coin
   PHA						;
   CLC						;
   ADC #$10					;
   STA $11					;
   PLA						;
   JMP CODE_E2FD				;

CODE_E2E4:
   CPY #$09					;check if we're storing X pos
   BNE CODE_E2ED				;

   LDA FloatingCoinSpawnCoordinatesAndAnim_E6E5,X              
   BNE CODE_E2FD				;

CODE_E2ED:
   CPY #$08					;check if we're setting y-position
   BNE CODE_E2F6				;

   LDA FloatingCoinSpawnCoordinatesAndAnim_E6E5+1,X
   BNE CODE_E2FD				;

CODE_E2F6:
   CPY #$04					;check if we're setting animation cycle
   BNE CODE_E2FD				;

   LDA FloatingCoinSpawnCoordinatesAndAnim_E6E5+2,X

CODE_E2FD:
   STA (EntityDataPointer),Y			;
   INY						;
   CPY #$20					;
   BNE CODE_E2D1				;

   INX						;next coin's positions and animation cycle
   INX						;
   INX						;
   JSR CODE_CDB4				;

   DEC $33					;loop through all coins to spawn
   BNE CODE_E2CF				;

   LDA #$00					;\reset collected coins from bonus phase    
   STA Player1BonusCoins			;|Mario's
   STA Player2BonusCoins			;/Luigi's

   LDA #$40					;initial timing before the actual timer starts counting down
   STA BonusTimeMilliSecs_Timing		;

   LDA #$01					;trick the game into ticking from 20/18 to the next second and 9 milliseconds
   STA BonusTimeMilliSecs			;

   LDA #$0A					;max coins
   STA BonusCoins_Total				;
   INC TESTYOURSKILL_Flag			;init over, game is on
   RTS						;

CODE_E329:
   LDA BonusTimeMilliSecs			;see if time's up
   BNE CODE_E36C				;if we have millisecs, count them down

   LDA BonusTimeSecs				;if we have seconds, count them down also
   BNE CODE_E34E				;

;otherwise time is up

CODE_E333:
   LDA #$01					;mark phase as completed, players can't move
   STA PhaseCompleteFlag			;

   LDA #$00					;
   STA TESTYOURSKILL_Flag			;next phase we'll load won't be TEST YOUR SKILL one
   STA Sound_Loop				;no timer ticking sound
   STA TESTYOURSKILL_CoinCountPointer		;start counting and stuff

   LDA #$10					;how long to wait before actually counting
   STA TransitionTimer				;

   LDA #$06					;count coins!
   STA GameplayModeNext				;

   LDA #$09					;
   STA GameplayMode				;wait a little bit
   RTS						;

CODE_E34E:
   STA $03					;initialize the sound effect  
   CMP #$18					;if set 20, play sound on 18
   BEQ CODE_E358				;
   CMP #$13					;if set 15, play on 13 (also works for 20)
   BNE CODE_E35C				;

CODE_E358:
   LDA #Sound_Loop_Timer			;tick tock sound
   STA Sound_Loop				;

CODE_E35C:
   LDA #$01					;
   SEC						;
   JSR CounterSubstraction_D15A			;-1 sec (decimal)
   STA BonusTimeSecs				;

   LDA #$09					;
   STA BonusTimeMilliSecs			;9 millisecs for every second
   BNE CODE_E374				;

CODE_E36C:
   DEC BonusTimeMilliSecs_Timing		;decrease millisecs every x frames
   BNE CODE_E3AE				;

   DEC BonusTimeMilliSecs			;-1 millisecond

CODE_E374:
.if Version = PAL
   LDA #BonusTimerMilliSecondTiming-1		;WOW! Milliseconds go by faster in PAL version! Who woulda guessed? Well... maybe not me.
.else
   LDA #BonusTimerMilliSecondTiming		;
.endif
   STA BonusTimeMilliSecs_Timing		;

   LDA #$14					;draw 1 row with 4 tiles
   STA BufferOffset2				;

   LDA BonusTimeSecs				;get seconds, tens
   LSR A					;
   LSR A					;
   LSR A					;
   LSR A					;
   STA BufferAddr2				;

   LDA BonusTimeSecs				;seconds ones
   AND #$0F					;
   STA BufferAddr2+1				;

   LDA #$66					;dot tile
   STA BufferAddr2+2				;

   LDA BonusTimeMilliSecs			;milliseconds
   STA BufferAddr2+3				;

   LDA #<VRAMLoc_BonusTimer			;VRAM location
   STA $00					;

   LDA #>VRAMLoc_BonusTimer			;
   STA $01					;

   LDA #<BufferOffset2				;             
   STA $02					;

   LDA #>BufferOffset2				;        
   STA $03					;
   JSR CODE_CE2C				;store into main buffer

;animate coins in TEST YOUR SKILL bonus
CODE_E3AE:
   LDX #$40					;
   LDY #$03					;

   LDA FrameCounter				;alternate coins that animate based on frame counter
   LSR A					;
   BCC CODE_E3BB				;

   LDX #$E0					;addresses overlap, meaning some coins will always animate!
   LDY #$03					;

CODE_E3BB:
   STX $A0					;
   STY $A1					;

   LDA #$05					;5 coins will animate
   STA $33					;

   LDA #$00					;
   STA $A2					;

CODE_E3C7:
   JSR CODE_CB9B

   LDA CurrentEntity_ActiveFlag			;entity currently active?
   BEQ CODE_E3E3				;can't even animate

   LDA CurrentEntity_BumpedStateAndBits		;got collected by the player? (technically not bump-related at all)
   BNE CODE_E3F3				;

   LDA CurrentEntity_UpdateTimer		;timer
   BNE CODE_E3E0				;

   LDA CurrentEntity_TimerStorage		;restore timer
   STA CurrentEntity_UpdateTimer		;

   JSR UpdateEntityGFXFrame_WhenGrounded_CE95	;animate (I guess the floating coins are considered to be "grounded")

CODE_E3DD:
   JSR CODE_CBC4				;update graphical display

CODE_E3E0:
   JSR CODE_CBB6				;next entity plz

CODE_E3E3:
   JSR CODE_CBAE				;move onto next entity

   DEC $33					;updated all coins?
   BNE CODE_E3C7				;keep doing

   LDA BonusCoins_Total				;checks if all coins have been collected?
   BNE CODE_E3F2				;
   JMP CODE_E333				;move onto counting them

CODE_E3F2:
   RTS						;

CODE_E3F3:
   CMP #$08                 
   BEQ CODE_E41E                
   CMP #$01                 
   BNE CODE_E400

   INC Player1BonusCoins			;increase "bonus coins collected" counter for player 1
   BNE CODE_E403				;always branch

CODE_E400:  
   INC Player2BonusCoins			;increase "bonus coins collected" counter for player 2

CODE_E403:
   LDA #<CoinPickupAnimationData_F6E8		;           
   STA CurrentEntity_UpdateDataPointer		;

   LDA #>CoinPickupAnimationData_F6E8		;       
   STA CurrentEntity_UpdateDataPointer+1	;

   LDA #Entity_Draw_8x8				;initial draw mode for collected coin (bonus test your skill only)
   STA CurrentEntity_DrawMode			;

   LDY #$02					;
   JSR RemoveEntitySpriteTiles_DFC4		;remove coin tiles...

   LDA #$08					;coin collected
   STA CurrentEntity_BumpedStateAndBits		;
 
   LDA #GFX_CollectedBonusCoin
   STA CurrentEntity_DrawTile
   BNE CODE_E3E0

;coin collected animation
CODE_E41E:
   JSR CODE_CCA0                
   CMP #$CC                 
   BEQ CODE_E42F                
   CMP #$DD                 
   BEQ CODE_E440                
   CMP #$EE                 
   BEQ CODE_E448                
   BNE CODE_E3DD

CODE_E42F:  
   JSR CODE_CCA0
   STA CurrentEntity_DrawMode
   CMP #Entity_Draw_8x16
   BNE CODE_E41E
   
   LDY #$04                 
   JSR RemoveEntitySpriteTiles_DFC4
   JMP CODE_E41E
  
CODE_E440:
   JSR CODE_CCA0                
   STA CurrentEntity_DrawTile
   JMP CODE_E3DD

CODE_E448:  
   DEC $04BC

   LDY #$04                 
   JSR RemoveEntitySpriteTiles_DFC4
   JMP CODE_E3E3

CODE_E453:
   JSR CODE_E1F7				;run "update score" routine

   LDA TESTYOURSKILL_CoinCountPointer		;
   JSR ExecutePointers_CD9E			;execute pointers

DATA_E45C:
.word CODE_E464					;bonus end init
.word CODE_E48A					;count mario's coins
.word CODE_E49A					;count luigi's coins
.word CODE_E4AA					;bonus/no bonus

CODE_E464:
   JSR DisableRender_E132			;turn off rendering & wait for NMI to occur
   JSR ClearScreenInit_CA20			;clear screen
   JSR CODE_CA3B				;VRAM attributes and maybe something else  
   JSR RemoveSpriteTiles_CA2B			;clear OAM
   JSR CODE_D5BE				;draw some HUD elements
   JSR InitLives_D60F				;prepare OAM slots for lives
   JSR CODE_D5E6				;set Mario's lives Y-position
   JSR CODE_D5EC				;same for Luigi
   JSR EnableRender_E13D			;wait for NMI and enable rendering

   LDA #$00					;zero out RAM addresses for next state
   STA TESTYOURSKILL_CoinCountSubPointer	;coin count state subpointer
   STA GeneralTimer2B				;timer

   INC TESTYOURSKILL_CoinCountPointer		;to the next state

CODE_E489:
   RTS						;

CODE_E48A:
   LDA GeneralTimer2B				;wait for timer
   BNE CODE_E489				;

   LDA TESTYOURSKILL_CoinCountSubPointer	;execute Mario's pointers
   JSR ExecutePointers_CD9E			;

DATA_E494:
.word CODE_E51A					;show Mario
.word CODE_E5CE					;count his coins
.word CODE_E670

CODE_E49A:
   LDA GeneralTimer2B				;wait for a bit...
   BNE CODE_E489				;

   LDA TESTYOURSKILL_CoinCountSubPointer	;
   JSR ExecutePointers_CD9E			;

DATA_E4A4:
.word CODE_E554					;show Luigi
.word CODE_E646					;count his coins
.word CODE_E6B8

CODE_E4AA:
   LDA Player1BonusCoins			;calculate coins total
   CLC						;
   ADC Player2BonusCoins			;
   LDX #<DATA_E5BF				;\message pointer
   LDY #>DATA_E5BF				;/
   CMP #$0A					;if less than 10, not all coins are collected, NO BONUS
   BNE CODE_E506				;

   LDX #<DATA_E5AD				;5000 pts message
   LDY #>DATA_E5AD				;
   LDA $41					;5000 points for bonus phases after phase 7
   CMP #$07                 
   BCS CODE_E4CB

   LDX #<DATA_E5B6				;otherwise a lowly 3000   
   LDY #>DATA_E5B6				;
   LDA #$30					;yes, give 3000 points
   BNE CODE_E4CD

CODE_E4CB:  
   LDA #$50					;5000 points reward

CODE_E4CD:  
   STA $1E					;temprorary score storage
   STX $02					;
   STY $03					;

   LDA #$D0					;message's VRAM position
   STA $00

   LDA #$22					;
   STA $01					;
   JSR CODE_CE2C				;draw the message

   LDA $1E					;
   STA $00					;

   LDA Player1GameOverFlag			;if player 1 is no longer with us.....................
   BNE CODE_E4ED				;don't award them points

   LDA #$08					;give score in hundreds and thousands and award em to mario
   STA $01					;
   JSR CODE_DE83				;

CODE_E4ED:
   LDA Player2GameOverFlag			;is 2nd player alive and well?
   BNE CODE_E4FC				;if not, just cut to the chase

   LDA $1E					;luigi also deserves score! Team work, yeah!
   STA $00

   LDA #$09					;give score in hundreds and thousands and award em to luigi
   STA $01					;
   JSR CODE_DE83				;

;Load PERFECT!! string 
CODE_E4FC:
   LDX #<PerfectString_E5A4			;             
   LDY #>PerfectString_E5A4			;
   
   LDA Sound_Jingle				;collected all coins!!!
   ORA #Sound_Jingle_PERFECT			;
   STA Sound_Jingle				;

CODE_E506:
   LDA #$C7					;VRAM address low
   STA $00					;

   LDA #$22					;high
   STA $01					;(thats $22C7)
   STX $02					;
   STY $03					;
   
   JSR CODE_CE2C				;stuff that into buffer

   LDA #$10					;time for transition
   JMP CODE_E1EC				;
   
CODE_E51A:
   LDA Player1GameOverFlag			;is player 1 still in the game?
   BEQ CODE_E522				;show Mario if so
 
CODE_E51E:
   INC $04B4					;count coins then
   RTS						;

;Show Mario on coin counting screen
CODE_E522:
   LDA #$17					;Mario's table offset
   STA $1E					;

   LDA #$27					;VRAM offset for the string
   STA $00					;

   LDA #$21					;
   LDX #<MarioString_E568			;MARIO string   
   LDY #>MarioString_E568			;

CODE_E530:
   STA $01					;
   STX $02					;
   STY $03					;
   JSR CODE_CE2C				;buffer

   LDX $1E					;player sprite tile table offset
   LDY #6*4-1					;amount of sprite tiles player sprite tiles (6 tiles, 4 bytes each and 0 counts)

CODE_E53D:
   LDA DATA_E574,X				;
   STA OAM_Y,X					;
   DEX						;
   DEY						;
   BPL CODE_E53D				;

   INC TESTYOURSKILL_CoinCountSubPointer

   LDA #$00					;
   STA BonusCoins_TotalCollected		;init counter, so it'll count up for each coin collected

   LDA #$10					;some timer
   STA $2B					;
   RTS						;

;show Luigi on coin counting screen
CODE_E554:
  LDA Player2GameOverFlag			;is player 2 playing?
  BNE CODE_E51E					;if not, don't show luigi
  
  LDA #$2F					;Luigi's table offset
  STA $1E

  LDA #$07					;VRAM offset
  STA $00					;

  LDA #$22					;
  LDX #<LuigiString_E56E			;LUIGI string
  LDY #>LuigiString_E56E			;
  BNE CODE_E530					;

;various strings for coin counting after TEST YOUR SKILL!
MarioString_E568:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "MARIO"
@StringEnd:

LuigiString_E56E:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "LUIGI"
@StringEnd:

;init mario and luigi sprite tiles, for after TEST YOUR SKILL! screen
DATA_E574:
;mario
.byte $40,GFX_Player_Standing+1,OAMProp_XFlip|OAMProp_Palette0,$20
.byte $40,GFX_Player_Standing,OAMProp_XFlip|OAMProp_Palette0,$28
.byte $48,GFX_Player_Standing+3,OAMProp_XFlip|OAMProp_Palette0,$20
.byte $48,GFX_Player_Standing+2,OAMProp_XFlip|OAMProp_Palette0,$28
.byte $50,GFX_Player_Standing+5,OAMProp_XFlip|OAMProp_Palette0,$20
.byte $50,GFX_Player_Standing+4,OAMProp_XFlip|OAMProp_Palette0,$28

;luigi
.byte $78,GFX_Player_Standing+1,OAMProp_XFlip|OAMProp_Palette1,$20
.byte $78,GFX_Player_Standing,OAMProp_XFlip|OAMProp_Palette1,$28
.byte $80,GFX_Player_Standing+3,OAMProp_XFlip|OAMProp_Palette1,$20
.byte $80,GFX_Player_Standing+2,OAMProp_XFlip|OAMProp_Palette1,$28
.byte $88,GFX_Player_Standing+5,OAMProp_XFlip|OAMProp_Palette1,$20
.byte $88,GFX_Player_Standing+4,OAMProp_XFlip|OAMProp_Palette1,$28

;PERFECT!! (!! is a single character)
PerfectString_E5A4:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "PERFECT",TwoExclamationMarks
@StringEnd:

;5000PTS'
DATA_E5AD:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "5000PTS'"
@StringEnd:

;3000PTS'
DATA_E5B6:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "3000PTS'"
@StringEnd:

;     NO BONUS.
DATA_E5BF:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "     NO BONUS."
@StringEnd:

;count each coin
CODE_E5CE:
   LDA Player1BonusCoins			;did the player 1 collect a coin?
   BEQ CODE_E639				;if not, check player 2 (i think?)
   CMP BonusCoins_TotalCollected		;counted all coins?
   BEQ CODE_E631				;yes

   LDA BonusCoins_TotalCollected		;count each coin
   ASL A					;
   ASL A					;
   ASL A					;
   TAX                      
   LDY #$41					;first row

   LDA Player1BonusCoins			;
   CMP #$06					;
   LDA BonusCoins_TotalCollected		;
   BCC CODE_E5F6				;

   LDY #$38					;second row?
   CMP #$05					;
   BCC CODE_E5F6				;

   LDY #$4A					;something else?

CODE_E5F3:
   SEC						;
   SBC #$05					;

CODE_E5F6:
   STY $1E					;y-pos

   ASL A                   			;
   ASL A                    			;
   STA $1F					;x-pos offset

   ASL A                  			;
   CLC                      			;
   ADC $1F                  			;
   ADC #$70                 			;
   STA BonusCoinCount_OAM_X,X              	;
   STA BonusCoinCount_OAM_X+4,X			;Tile's X position

   LDA #OAMProp_Palette2			;tile property (sprite palette 2)
   STA BonusCoinCount_OAM_Prop,X		;
   STA BonusCoinCount_OAM_Prop+4,X		;

   LDA #Coin_TopTile				;coin's top tile		  
   STA BonusCoinCount_OAM_Tile,X 		;

   LDA #Coin_BottomTile				;          
   STA BonusCoinCount_OAM_Tile+4,X		;bottom tile

   LDA $1E					;      
   STA BonusCoinCount_OAM_Y,X			;Tile's Y position
   CLC						;
   ADC #$08					;bottom tile 8 pixels lower
   STA BonusCoinCount_OAM_Y+4,X			;

   INC BonusCoins_TotalCollected		;count next coin maybe

   LDA #$0A					;count every 10 frames
   STA GeneralTimer2B				;

   LDA #Sound_Jingle_CoinCount			;
   STA Sound_Jingle				;coin + 1 sound
   RTS						;

CODE_E631:
   INC TESTYOURSKILL_CoinCountSubPointer	;next phase, PERFECT or not? (or maybe second player count)

   LDA #$10					;
   STA GeneralTimer2B				;
   RTS						;

CODE_E639:
   LDA #$00					;
   STA TESTYOURSKILL_CoinCountSubPointer	;

   INC TESTYOURSKILL_CoinCountPointer		;

   LDA #$10					;
   STA GeneralTimer2B				;
   RTS						;

;second player coin count
CODE_E646:
   LDA Player2BonusCoins			;doest thee player 2 hast bonus coins?
   BEQ CODE_E639				;nay?
   CMP BonusCoins_TotalCollected		;
   BEQ CODE_E631				;

   LDA BonusCoins_TotalCollected		;
   ASL A					;
   ASL A					;
   ASL A					;
   CLC						;
   ADC #$50					;OAM offset
   TAX						;

   LDY #$79					;
   LDA Player2BonusCoins			;and of course which row
   CMP #$06					;if first 5 coins have been counted,
   LDA BonusCoins_TotalCollected		;
   BCC CODE_E5F6

   LDY #$70					;
   CMP #$05					;
   BCC CODE_E5F6				;

   LDY #$82					;
   BCS CODE_E5F3				;draw pls

CODE_E670:
   LDA #$00					;
   STA $1F					;add to player 1's score

   LDX #$37					;VRAM address for multiplication string 
   LDY #$21					;
   LDA Player1BonusCoins			;score for coins

CODE_E67B:
   STA $1E					;
   STX $00					;
   STY $01					;

   LDA #<DATA_E703				;$03                 
   STA $02

   LDA #>DATA_E703				;$E7                 
   STA $03

   JSR CODE_CE2C

   LDA #$00					;
   STA $04					;
   STA $05					;
   STA $07					;

   LDY #$08					;add +800 score for a coin
   STY $03					;

CODE_E698:
   CLC						;
   JSR CounterAddition_D139			;add score
   BCC CODE_E6A0				;

   INC $05					;this is untriggered, wonder why

CODE_E6A0:
   DEC $1E					;keep adding 800 for each coin collected
   BNE CODE_E698				;
   STA $06					;

   LDA $1F					;
   JSR CODE_D0B4				;

   LDA #$20					;some delay
   STA $2B					;

   LDA #$00					;
   STA TESTYOURSKILL_CoinCountSubPointer	;reset subpointer

   INC TESTYOURSKILL_CoinCountPointer		;next pointer
   RTS						;

CODE_E6B8:
   LDA #$01					;when counting each coin, add to player 2's
   STA $1F					;

   LDX #$17					;
   LDY #$22					;multiplication string pos for player 2

   LDA Player2BonusCoins			;and score for player's coins
   BNE CODE_E67B				;

;floating coin init values
SpawnInitValues_FloatingCoin_E6C5:
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte Entity_MovementBits_MovingRight		;CurrentEntity_MovementBits
.byte $03					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte CoinSpinningAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x16				;CurrentEntity_DrawMode
.byte GFX_Coin_Frame3				;CurrentEntity_DrawTile
.byte OAMProp_Palette2				;CurrentEntity_TileProps
.byte $00					;CurrentEntity_YPos (overwritten afterwards)
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte $00					;CurrentEntity_OAMOffset (overwritten afterwards)
.byte $00					;CurrentEntity_PaletteOffset (does not affect coin)
.word $0000					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_FloatingCoin			;CurrentEntity_ID

.byte $00					;CurrentEntity_BumpedStateAndBits
.byte $00 					;CurrentEntity_MiscRAM
.byte $00					;CurrentEntity_PipeDir
.byte $00					;CurrentEntity_XSpeedTableOffset (floating coin does not move)
.byte $00					;CurrentEntity_XSpeedTableEntry (floating coin does not move)
.byte $00					;CurrentEntity_XSpeed (floating coin does not move)
.byte $00					;CurrentEntity_XSpeedAlterTimer
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.byte $00,$00					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi (has no effect on anything other than players)
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $0F,$0F					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;set each coin's coordinates and starting animation index (so they all look differently)
FloatingCoinSpawnCoordinatesAndAnim_E6E5:
.byte $38,$24,CoinSpinningAnimCycle_Start
.byte $C8,$24,CoinSpinningAnimCycle_Start+2
.byte $18,$5A,CoinSpinningAnimCycle_Start+1
.byte $2C,$5A,CoinSpinningAnimCycle_Start+4
.byte $D4,$5A,CoinSpinningAnimCycle_Start+4
.byte $E8,$5A,CoinSpinningAnimCycle_Start+1
.byte $60,$8A,CoinSpinningAnimCycle_Start+3
.byte $A0,$8A,CoinSpinningAnimCycle_Start+2
.byte $28,$BA,CoinSpinningAnimCycle_Start+1
.byte $D8,$BA,CoinSpinningAnimCycle_Start+4

;X 800 string
DATA_E703:
.byte @StringEnd-@StringStart|$10
@StringStart:
	.byte "X 800"
@StringEnd:

;Combo chain timers and fireball spawn timers handler
CODE_E709:
   LDA Combo_Timer				;\tick down Mario's combo timer
   BEQ CODE_E711				;|
   DEC Combo_Timer				;/

CODE_E711:
   LDA Combo_Timer+2				;\Luigi's combo timer
   BEQ CODE_E719				;|
   DEC Combo_Timer+2				;/

CODE_E719:
   INC FireballSpawnTiming_Timer		;
   LDA FireballSpawnTiming_Timer		;
   CMP #$3E					;when at this value, tick down fireball timers
   BCC CODE_E73D				;

   LDA #$00					;
   STA FireballSpawnTiming_Timer		;

   LDA WaveFireball_EnableSpawnTimer		;
   BEQ CODE_E72D				;
   DEC WaveFireball_EnableSpawnTimer		;

CODE_E72D:
   LDA ReflectingFireball_SpawnTimer		;
   BEQ CODE_E735				;
   DEC ReflectingFireball_SpawnTimer		;

CODE_E735:
   LDA ReflectingFireball_Timer			;time untill the fireball vanishes
   BEQ CODE_E73D				;
   DEC ReflectingFireball_Timer			;

CODE_E73D:
   RTS						;

;prepare spawn for fireball at Mario's level
CODE_E73E:
   LDA Entity_Mario_ActiveFlag			;is mario active?
   BEQ CODE_E768				;

   LDA Entity_Mario_State			;check if he's not in any abnormal state
   BNE CODE_E768				;

   LDX #$00					;
   LDA Entity_Mario_CurrentPlatform		;checks if on the same platform

CODE_E74D:
   CMP WavyFireball_AppearForPlayerPlatform,X	;if not on the same platform
   BNE CODE_E769				;

   INC WavyFireball_AppearForPlayerTimer,X	;increase counter

   LDY #$F0					;
   LDA GameAorBFlag				;
   BEQ CODE_E75D				;

   LDY #$3E					;shorter timer when in game B

CODE_E75D:
   TYA						;
   CMP WavyFireball_AppearForPlayerTimer,X	;
   BCS CODE_E768				;check if time has come for it to appear

   LDA #$01					;fireball is locked in to spawn
   STA WavyFireball_AppearForPlayerFlag,X	;

CODE_E768:
   RTS						;

CODE_E769:
   STA WavyFireball_AppearForPlayerPlatform,X	;remember the platform

   LDA #$00					;timer reset
   STA WavyFireball_AppearForPlayerTimer,X	;
   RTS						;

;prepare spawn for fireball at Luigi's level
CODE_E772:
   LDA Entity_Luigi_ActiveFlag			;is Luigi game?
   BEQ CODE_E768				;no Luigi

   LDA Entity_Luigi_State			;check if luigi is in an abnormal state
   BNE CODE_E768				;

   LDA Entity_Luigi_CurrentPlatform		;get the platform level's on right now
   LDX #$03					;
   BNE CODE_E74D				;

CODE_E783:
   LDX #$03					;
   LDY #$00					;

CODE_E787:
   LDA EntitiesPerPlatform,X			;I don't know why they couldn't use this address then set it to 0 at the end somewhere instead of using extra RAM, but whatever.
   STA EntitiesPerPlatformTransfer,X		;(this would make more sense if, at the very least, these were zero page addresses...)
   TYA						;
   STA EntitiesPerPlatform,X			;0 for the next calculation
   DEX						;
   BPL CODE_E787				;
   RTS						;

CODE_E795:
   LDA TESTYOURSKILL_Flag			;are we in a bonus phase?
   BNE CODE_E7AC				;no fireballs

   LDA WaveFireball_EnableSpawnTimer		;fireball spawned in?
   BEQ CODE_E7AD				;handle it

   LDY LastEnemyFlag				;check if only one enemy is remaining
   BEQ CODE_E7AC				;
   CMP #$04					;if the timer was already shortened (or was already short enough)
   BCC CODE_E7AC				;just wait

   LDA #$04					;shorter timer if the last enemy remains to slightly highten the difficulty
   STA WaveFireball_EnableSpawnTimer		;

CODE_E7AC:
   RTS						;

CODE_E7AD:
   LDA WaveFireball_MainCodeFlag		;did it initialize?
   BNE CODE_E7BD				;

   JSR CODE_EEAD				;see if it can spawn this moment
   JSR CODE_E9A0				;init fireball's values

   LDA #$01					;init over
   STA WaveFireball_MainCodeFlag		;

CODE_E7BD:
   JSR CODE_E73E				;make fireball appear for player 1
   JSR CODE_E772				;make fireball appear for player 2

   LDA Entity_WavyFireball_State		;check if on scene
   BEQ CODE_E7CB				;if not, it'll appearTM
   JMP CODE_E86B				;

CODE_E7CB:
   LDA Entity_WavyFireball_AppearTimer		;
   BEQ CODE_E7D6				;

   DEC Entity_WavyFireball_AppearTimer		;
   JMP CODE_E805				;

CODE_E7D6:
   LDA PhaseCompleteFlag			;phase complete = don't care
   BNE CODE_E805				;

   LDA WavyFireball_AppearForMarioFlag		;fireball about to appear for mario flag
   BNE CODE_E806				;

   LDA WavyFireball_AppearForLuigiFlag		;fireball about to appear for luigi flag
   BNE CODE_E84A				;

;Wavy fireball's GFX
CODE_E7E4:
   LDX Entity_WavyFireball_OAMOffset		;
   LDA Entity_WavyFireball_YPos			;
   CLC						;
   ADC #$FC					;
   STA OAM_Y,X					;

   LDA Entity_WavyFireball_DrawTile		;
   STA OAM_Tile,X				;

   LDA Entity_WavyFireball_TileProps		;
   STA OAM_Prop,X				;

   LDA Entity_WavyFireball_XPos			;
   CLC						;
   ADC #$FC					;
   STA OAM_X,X					;

CODE_E805:
   RTS						;

;prepare fireball spawn at Mario's level (the green, wavy one one)
CODE_E806:
   LDX Entity_Mario_CurrentPlatform		;
   LDA EntitiesPerPlatformTransfer,X		;check if there's TOO much on the same platform
   CMP #$08					;
   BCS CODE_E805				;prevents the dreaded flicker (or the lack thereof, because the game doesn't handle flicker as we know it)

   LDA #$00					;
   STA WavyFireball_AppearForMarioFlag		;appear no more
   STA WavyFireball_AppearForMarioTimer		;timer reset for the next spawn
   STX Entity_WavyFireball_CurrentPlatform	;same platform level as mayo

   LDA WavyFireball_SpawnYPos_F0A1,X		;y-pos based on the platform level
   STA Entity_WavyFireball_YPos

   LDA Entity_Mario_XPos			;

CODE_E824:
   LDY #WavyFireball_SpawnXPosLeft		;
   LDX #Entity_MovementBits_MovingRight		;goes from left to right
   CMP #$80					;check player's x-pos
   BCS CODE_E830				;if on the right side of the screen, show far to the right

   LDY #WavyFireball_SpawnXPosRight		;spawn on the right side of the screen
   LDX #Entity_MovementBits_MovingLeft		;from right to left

CODE_E830:
   STY Entity_WavyFireball_XPos			;
   STX Entity_WavyFireball_HorzDirection	;

   LDA #Fireball_State_Appears			;fireball ON
   STA Entity_WavyFireball_State		;
   JSR EnableFireballSound_E96D			;happy fireball noises

   LDX #<DATA_EFDB				;start appearing in
   LDY #>DATA_EFDB				;

CODE_E842:
   STX Entity_WavyFireball_UpdateDataPointer	;
   STY Entity_WavyFireball_UpdateDataPointer+1	;
   BNE CODE_E805				;could've been an RTS instead

CODE_E84A:
   LDX Entity_Luigi_CurrentPlatform		;
   LDA EntitiesPerPlatformTransfer,X		;
   CMP #$08					;if too much stuff on the same level, won't spawn
   BCS CODE_E805				;
   STX Entity_WavyFireball_CurrentPlatform	;same platform level as Papa Louie from Papa's Pizzeria

   LDA WavyFireball_SpawnYPos_F0A1,X		;
   STA Entity_WavyFireball_YPos			;

   LDA #$00					;
   STA WavyFireball_AppearForLuigiFlag		;
   STA WavyFireball_AppearForLuigiTimer		;

   LDA Entity_Luigi_XPos			;check if Luigi is on the left side of the screen or the right one
   JMP CODE_E824				;

CODE_E86B:
   CMP #Fireball_State_Appears			;check if the fireball currently appears
   BNE CODE_E893				;

   JSR CODE_EA25				;check if phase complete or POW hit
   BCC CODE_E877				;does not disappear if not true

   JMP CODE_E952				;disappear

CODE_E877:
   JSR CODE_E9D3				;
   CMP #$FF					;simply animates
   BNE CODE_E889				;

   LDA #Fireball_State_Normal			;
   STA Entity_WavyFireball_State		;

CODE_E883:
   LDX #<DATA_F01B				;
   LDY #>DATA_F01B				;
   BNE CODE_E842				;

CODE_E889:
   CMP #$00					;don't change tile
   BEQ CODE_E890				;
   STA Entity_WavyFireball_DrawTile		;

CODE_E890:
   JMP CODE_E7E4				;

CODE_E893:
   CMP #Fireball_State_Disappears		;check if disappears
   BNE CODE_E8D3				;

   JSR CODE_E9D3				;animate disappearance
   CMP #$FF					;reached animation end?
   BNE CODE_E889				;

   JSR DisableFireballSound_E973		;no more fireball noise

   LDY #$00					;the fireball is no longer with us... f
   STY Entity_WavyFireball_State		;
   DEY						;

   LDA GameAorBFlag				;see if in game A or B
   BEQ CODE_E8AD				;

   LDY #$80					;

CODE_E8AD:
   STY Entity_WavyFireball_AppearTimer		;timer or smth?

   LDA #$F4					;banish it into offscreen
   STA Entity_WavyFireball_YPos			;

   LDX Entity_WavyFireball_OAMOffset		;
   STA OAM_Y,X					;the associated OAM tile also BEGONE
   JMP CODE_E805				;

CODE_E8BE:
   LDA #$02					;200 points (or 20 if we didn't enable bit 3 with ORA down below, but that'd be a pretty pathetic bonus)
   STA $00					;

   LDX PlayerScoreUpdateIndex			;who hit the POW, gains score

   LDA #$01					;update score for said player
   STA PlayerScoreUpdateFlag,X			;

   TXA						;whichever player
   ORA #$08					;and a number of points that is bigger than tens (we're speaking hundreds and even (gasp) thousands!)
   STA $01					;
   JSR CODE_DE83				;reward them

CODE_E8D0:
   JMP CODE_E952				;

CODE_E8D3:
   JSR CODE_EA25				;check if phase complete or POW hit
   BCS CODE_E8D0				;fireball should disappear if true

   LDX Entity_WavyFireball_CurrentPlatform	;
   LDA EntitiesPerPlatformTransfer,X		;
   CMP #$09					;check if there's too much on the same platform (again)
   BCS CODE_E8D0				;fireball will just cease to exist. it feels like a third wheel. Or a ninth one.

   LDA Entity_WavyFireball_HorzDirection	;check if moving left or right
   LSR A					;
   BCS CODE_E92E				;moves right

   LDA Entity_WavyFireball_XPos			;check if got to the left side of the screen
   CMP #$10					;
   BCS CODE_E8F2				;

   JMP CODE_E952				;disappear

CODE_E8F2:
   JSR CODE_E9D3				;
   CMP #$AA					;check if should reset it's vertical movement (should wave again)
   BEQ CODE_E883				;
   CMP #$BB					;check if at its lowest point, basically
   BNE CODE_E907				;which means it can be bumped

   JSR CODE_E95E				;check if collided with a bump area
   BNE CODE_E905				;

   JMP CODE_E8BE				;score

CODE_E905:
   LDA #$00					;

CODE_E907:
   DEC Entity_WavyFireball_XPos			;

.if Version = PAL
   LDX PAL_SpeedAlterationTimer			;will move an extra pixel every 4th frame
   BNE PAL_CODE_E92E				;

   DEC Entity_WavyFireball_XPos			;move left

PAL_CODE_E92E:
.endif

CODE_E90A:
   CLC						;
   ADC Entity_WavyFireball_YPos			;
   STA Entity_WavyFireball_YPos			;

;animate fireball
CODE_E911:
   LDX Entity_WavyFireball_AnimationPointer	;
   LDA EntityMovementAnimations_F4B2,X		;
   CMP #$FF					;
   BNE CODE_E925				;

   INX						;
   LDA EntityMovementAnimations_F4B2,X		;
   STA Entity_WavyFireball_AnimationPointer	;reset animation
   JMP CODE_E911				;

CODE_E925:
   STA Entity_WavyFireball_DrawTile		;

   INC Entity_WavyFireball_AnimationPointer	;
   JMP CODE_E7E4				;

CODE_E92E:
   LDA Entity_WavyFireball_XPos			;check if reached right side of the screen
   CMP #$F4					;
   BCS CODE_E952				;will disappear

   JSR CODE_E9D3				;
   CMP #$AA					;check if should reset it's vertical movement (should wave again)
   BEQ CODE_E948				;
   CMP #$BB					;check if at its lowest point, basically
   BNE CODE_E94D				;which means it can be bumped

   JSR CODE_E95E				;check if the fireball got bumped
   BNE CODE_E94B				;

   JMP CODE_E8BE				;score

CODE_E948:
   JMP CODE_E883				;

CODE_E94B:
   LDA #$00					;

CODE_E94D:
.if Version = PAL
   INC Entity_WavyFireball_XPos			;

   LDX PAL_SpeedAlterationTimer			;will move an extra pixel every 4th frame
   BNE PAL_CODE_E92E				;
.endif

   INC Entity_WavyFireball_XPos			;
   BNE CODE_E90A				;

CODE_E952:
   LDA #Fireball_State_Disappears		;make it disappear
   STA Entity_WavyFireball_State		;(I think)

   LDX #<DATA_F006				;
   LDY #>DATA_F006				;disappear animation
   JMP CODE_E842				;

CODE_E95E:
   LDA Entity_WavyFireball_YPos			;
   JSR CODE_EEA5				;

   LDY Entity_WavyFireball_XPos			;
   JSR CODE_EC67				;check bump contact
   ORA #$00					;right...
   RTS						;

;enable fireball sound
EnableFireballSound_E96D:
   LDA Sound_Loop				;
   ORA #Sound_Loop_Fireball			;
   BNE CODE_E977				;

;disable fireball sound
DisableFireballSound_E973:
   LDA Sound_Loop				;
   AND #$FF^Sound_Loop_Fireball			;

CODE_E977:
   STA Sound_Loop				;
   RTS						;

CODE_E97A:
   LDA WaveFireball_SpawnTimerIndex		;
   LDY GameAorBFlag				;if in game B, the fireballs will spawn faster.
   BEQ CODE_E984				;
   CLC						;
   ADC #$04					;

CODE_E984:
   TAX						;
   LDA DATA_F081,X				;spawn times for wavy fireball
   STA WaveFireball_EnableSpawnTimer		;

   LDA ReflectingFireball_SpawnTimer		;
   STA ReflectingFireball_SpawnTimerIndex	;

   CPY #$00					;spawn faster in game B for reflecting fireballs as well
   BEQ CODE_E998				;
   CLC						;
   ADC #$04					;

CODE_E998:
   TAX						;
   LDA DATA_F089,X				;spawn times for reflecting fireball
   STA ReflectingFireball_SpawnTimer		;
   RTS						;

;initialize wavy fireball
CODE_E9A0:
   LDX #$1F					;

CODE_E9A2:
   LDA SpawnInitValues_WavyFireball_F061,X	;
   STA Entity_WavyFireball_ActiveFlag,X		;
   DEX						;
   BPL CODE_E9A2				;
   RTS						;

;a wild reflecting fireball appears!
InitializeReflectingFireball_E9AC:
   LDX #$1F					;

CODE_E9AE:
   LDA SpawnInitValues_ReflectingFireball_EFBB,X;
   STA Entity_ReflectingFireball_ActiveFlag,X	;
   DEX						;
   BPL CODE_E9AE				;
   RTS						;

;player interacted with a fireball
CODE_E9B8:
   LDY #$10					;
   LDA ($14),Y					;unless the fireball is already disappearing...?
   CMP #$10					;
   BNE CODE_E9D2				;

   LDA #$02					;fireball disappears or smth...
   STA ($14),Y					;

   LDY #$0C					;
   LDA #<DATA_F006				;
   STA ($14),Y					;

   INY						;
   LDA #>DATA_F006				;
   STA ($14),Y					;

   JMP CODE_DCCE				;

CODE_E9D2:
   RTS						;

CODE_E9D3:
   LDA #$00					;
   LDX Entity_WavyFireball_UpdateDataPointer	;
   LDY Entity_WavyFireball_UpdateDataPointer+1	;
   JSR CODE_E9FA				;
   CMP #$CC					;
   BNE CODE_E9E8				;

   JSR EnableFireballSound_E96D			;
   JMP CODE_E9D3				;

CODE_E9E8:
   CMP #$DD					;
   BNE CODE_E9D2				;

   JSR DisableFireballSound_E973		;disable fireball SFX
   JMP CODE_E9D3				;

CODE_E9F2:
   LDA #$01					;
   LDX Entity_ReflectingFireball_UpdateDataPointer
   LDY Entity_ReflectingFireball_UpdateDataPointer+1

CODE_E9FA:
   STA $1E					;remember if it's reflecting fireball or a wavy fireball
   STX $14					;
   STY $15					;

   LDY #$00					;
   LDA ($14),Y					;
   STY $13					;
   INY						;
   STY $12					;

   JSR CODE_CDB4				;

   PHA						;
   LDX $14					;
   LDY $15					;
   LDA $1E					;
   BNE CODE_EA1D				;
   STX Entity_WavyFireball_UpdateDataPointer	;
   STY Entity_WavyFireball_UpdateDataPointer+1	;
   PLA						;
   RTS						;

CODE_EA1D:
   STX Entity_ReflectingFireball_UpdateDataPointer
   STY Entity_ReflectingFireball_UpdateDataPointer+1
   PLA						;
   RTS						;

CODE_EA25:
   LDA PhaseCompleteFlag			;
   BNE CODE_EA2F				;player(s) won? fireball should disappear

   LDA POWPowerTimer				;POW should make the fireball disappear
   BNE CODE_EA2F				;

   CLC						;fireball is alive
   RTS						;

CODE_EA2F:
   SEC						;fireball is unalive
   RTS						;

CODE_EA31:
   LDA TESTYOURSKILL_Flag			;fireball won't spawn in test your skill levels
   BEQ CODE_EA37				;

CODE_EA36:
   RTS						;

;reflecting fireball
CODE_EA37:
   LDA ReflectingFireball_SpawnTimer		;timer for when fireball should appear
   BNE CODE_EA36				;return

   LDA ReflectingFireball_MainCodeFlag		;run main code for fireball
   BNE CODE_EA4C				;

   JSR CODE_EEAD				;see if it can spawn this moment
   JSR InitializeReflectingFireball_E9AC	;set initial values for reflecting fireball entity

   LDA #$01					;set the flag
   STA ReflectingFireball_MainCodeFlag		;

CODE_EA4C:
   LDA Entity_WavyFireball_State		;checks if wavy fireball is present
   BNE CODE_EA54				;keep fireball noise

   JSR DisableFireballSound_E973		;disable fireball SFX loop (only play once every time it hits a surface)

CODE_EA54:
   LDA Entity_ReflectingFireball_State		;fireball's state
   CMP #Fireball_State_Normal			;in action
   BEQ CODE_EA97				;
   CMP #Fireball_State_Appears			;appears in
   BEQ CODE_EA91				;
   CMP #Fireball_State_Disappears		;disappears
   BEQ CODE_EA94				;

   LDA #$28					;positions
   STA Entity_ReflectingFireball_YPos		;

   LDA #$50					;
   STA Entity_ReflectingFireball_XPos		;

   LDA Entity_ReflectingFireball_TimerStorage	;check if can appear for real
   BNE CODE_EA79				;

   LDA #$02					;
   STA Entity_ReflectingFireball_YSpeed		;y-speed
   BNE CODE_EA7C				;

CODE_EA79:
   DEC Entity_ReflectingFireball_TimerStorage	;timer

CODE_EA7C:
   JSR CODE_EA25				;check if fireball should begone
   BCS CODE_EA90				;don't even play the appearing animation

   LDA #Fireball_State_Appears			;continue appearing
   LDX #<DATA_EF9D				;
   LDY #>DATA_EF9D				;

CODE_EA87:
   STA Entity_ReflectingFireball_State		;
   STX Entity_ReflectingFireball_UpdateDataPointer
   STY Entity_ReflectingFireball_UpdateDataPointer+1

CODE_EA90:
   RTS						;

CODE_EA91:
   JMP CODE_EC14				;animate appearing

CODE_EA94:
   JMP CODE_EC30				;animate disappearing

CODE_EA97:
   JSR CODE_EA25				;check if it should be gone
   BCC CODE_EA9F				;

   JMP CODE_EBE9				;make fireball go poof

CODE_EA9F:
   LDA Entity_ReflectingFireball_YPos		;check if its too low
   CMP #$18					;
   BCS CODE_EABD				;

   LDA ReflectingFireball_Timer			;
   BNE CODE_EAB5				;

   LDA Entity_ReflectingFireball_YPos		;check if it's pretty much at the top of the screen
   CMP #$0C					;
   BCS CODE_EADF				;I', guessing this is to prevent graphics disappearing or something??

   JMP CODE_EBE9				;disappear

CODE_EAB5:
   LDA #$01					;moves down

CODE_EAB7:
   STA Entity_ReflectingFireball_VertDirection	;moves vertically
   JMP CODE_EADF				;

CODE_EABD:
   CMP #$D4					;too low
   BCC CODE_EAC5				;

   LDA #$00					;
   BEQ CODE_EAB7				;

CODE_EAC5:
   LDA Entity_ReflectingFireball_XPos		;
   CMP #$0C					;hit left side of the screen?
   BCS CODE_EAD3				;

   JSR CODE_EEBC				;push it outta there

   LDA #$00					;sure did
   BEQ CODE_EADC				;

CODE_EAD3:
   CMP #$F8					;hit right side of the screen?
   BCC CODE_EAE2				;

   JSR CODE_EECC				;yeah, push it out!

   LDA #$01					;

CODE_EADC:
   STA Entity_ReflectingFireball_HorzDirection	;horizontal move direction

CODE_EADF:
   JSR EnableFireballSound_E96D			;a brief fireball noise for hitting a surface

CODE_EAE2:
;don't interact with objects if this timer is ticking
   LDA Entity_ReflectingFireball_ObjCollisionDisableTimer
   BEQ CODE_EAED

   DEC Entity_ReflectingFireball_ObjCollisionDisableTimer

   JMP CODE_EB6B				;

CODE_EAED:
   LDA Entity_ReflectingFireball_TileAtBottomVRAMPos
   JSR GetTileActsLike_CAA4			;check if hit a platform
   CMP #$00					;nothing
   BEQ CODE_EB6B				;did not hit
   CMP #$02					;bump area
   BNE CODE_EB1C				;if not, it's just a solid tile

   LDA Entity_ReflectingFireball_YPos		;
   JSR CODE_EEA5				;

   LDY Entity_ReflectingFireball_XPos		;check bump contact (or rather, who dunnit, because we already figured it got hit)
   JSR CODE_EC67				;

   LDA #$10					;
   STA $00					;1000 points!!

   LDX PlayerScoreUpdateIndex			;
   LDA #$01					;
   STA PlayerScoreUpdateFlag,X			;
   TXA						;
   ORA #$08					;make sure to reward with hundreds and thousands (in this case, a single 1 thousand)
   STA $01					;

   JSR CODE_DE83				;give score to the player that managed to kill it
   JMP CODE_EBE9

CODE_EB1C:
   JSR EnableFireballSound_E96D			;sound of hitting stuff

   JSR RNG_D328					;roll RNG
   AND #$01					;
   CLC						;
   ADC Entity_ReflectingFireball_UpdateTimer	;delay or do not delay its movement by... 1 frame.
   STA Entity_ReflectingFireball_UpdateTimer	;

   LDA #$08					;disable interaction for a little bit (yep, it won't be bump-able in that time)
   STA Entity_ReflectingFireball_ObjCollisionDisableTimer

   LDX #$00

CODE_EB32:
   LDA DATA_F574,X				;check for platform edges
   CMP Entity_ReflectingFireball_VRAMPosLo	;
   BNE CODE_EB42				;

   LDA DATA_F574+1,X				;
   CMP Entity_ReflectingFireball_VRAMPosHi	;
   BEQ CODE_EB4A				;matches up

CODE_EB42:
   INX						;loop through all edges
   INX						;
   CPX #$10					;
   BNE CODE_EB32				;
   BEQ CODE_EB53				;

CODE_EB4A:
   CPX #$08					;check if touched right or left edges
   BCC CODE_EB5E				;

   LDA Entity_ReflectingFireball_HorzDirection	;right edges
   BEQ CODE_EB63				;if fireball moved right, it'll change its horizontal direction, otherwise it'll change vertical

CODE_EB53:
   LDA Entity_ReflectingFireball_VertDirection	;
   EOR #$01					;
   STA Entity_ReflectingFireball_VertDirection	;
   JMP CODE_EB6B				;

CODE_EB5E:
   LDA Entity_ReflectingFireball_HorzDirection	;left edges
   BEQ CODE_EB53				;if fireball moved left, it'll change its horizontal direction, otherwise it'll change vertical

CODE_EB63:
   LDA Entity_ReflectingFireball_HorzDirection	;change its direction
   EOR #$01					;
   STA Entity_ReflectingFireball_HorzDirection	;

CODE_EB6B:
   LDY #$04					;
   LDA Entity_ReflectingFireball_HorzDirection	;
   BEQ CODE_EB74				;

   LDY #-$04					;

CODE_EB74:
   TYA						;
   CLC						;
   ADC Entity_ReflectingFireball_XPos		;offset so it checks for tiles ahead of itself (to the left/right depending on its movement direction)
   STA $00					;

   LDY #$04					;
   LDA Entity_ReflectingFireball_VertDirection	;
   BNE CODE_EB84				;

   LDY #-$04					;

CODE_EB84:
   TYA						;
   CLC						;
   ADC Entity_ReflectingFireball_YPos		;don't forget to offset vertically as well
   STA $01					;

   JSR CODE_CA7D				;calculate the tile it's touching

   LDA $00					;
   STA Entity_ReflectingFireball_VRAMPosHi	;
   STA Entity_VRAMPosition+8			;hmm...

   LDA $01					;
   STA Entity_ReflectingFireball_VRAMPosLo	;
   STA Entity_VRAMPosition+9			;

   LDA Entity_ReflectingFireball_UpdateTimer	;should move?
   BNE CODE_EC13				;if not, nothing happens

   LDA Entity_ReflectingFireball_TimerStorage	;restore timer
   STA Entity_ReflectingFireball_UpdateTimer	;

   LDA Entity_ReflectingFireball_YPos		;
   LDY Entity_ReflectingFireball_VertDirection	;depending on its vertical direction, it'll move accordingly.
   BNE CODE_EBB8				;
   SEC						;
   SBC Entity_ReflectingFireball_YSpeed		;moving up
   JMP CODE_EBBC				;

CODE_EBB8:
   CLC						;
   ADC Entity_ReflectingFireball_YSpeed		;moving down

CODE_EBBC:
   STA Entity_ReflectingFireball_YPos		;

   LDA Entity_ReflectingFireball_HorzDirection	;check direction with which the fireball is moving (left or right)
   BNE CODE_EBC9				;

.if Version = PAL
   INC Entity_ReflectingFireball_XPos		;

   LDA PAL_SpeedAlterationTimer			;I hope you already got the idea. Yes, extra pixel every fourth frame
   BNE PAL_CODE_EC05				;
.endif

   INC Entity_ReflectingFireball_XPos		;move right
   BNE CODE_EBCC				;

CODE_EBC9:
.if Version = PAL
   DEC Entity_ReflectingFireball_XPos		;

   LDA PAL_SpeedAlterationTimer			;The wonders of PAL conversions. Did you know that the European version of Duck Tales for the NES made Scrooge faster to compensate for slower frame rate?
   BNE PAL_CODE_EC05				;
.endif

   DEC Entity_ReflectingFireball_XPos		;move left

PAL_CODE_EC05:
CODE_EBCC:
   LDX Entity_ReflectingFireball_AnimationPointer
   LDA EntityMovementAnimations_F4B2,X		;fairly standard animation routine
   CMP #$FF					;
   BNE CODE_EBE0				;
   INX						;
   LDA EntityMovementAnimations_F4B2,X		;reset animation
   STA Entity_ReflectingFireball_AnimationPointer
   JMP CODE_EBCC				;

CODE_EBE0:  
   STA Entity_ReflectingFireball_DrawTile	;

   INC Entity_ReflectingFireball_AnimationPointer
   JMP CODE_EBF2				;display the fireball on screen

CODE_EBE9:
   LDA #Fireball_State_Disappears		;the fireball will start disappearing
   LDX #<DATA_F006				;
   LDY #>DATA_F006				;
   JMP CODE_EA87				;

;reflecting fireball's GFX
CODE_EBF2:
   LDX Entity_ReflectingFireball_OAMOffset	;fireball's OAM slot?
   LDA Entity_ReflectingFireball_YPos		;
   CLC						;
   ADC #$FC					;center position
   STA OAM_Y,X					;

   LDA Entity_ReflectingFireball_DrawTile	;
   STA OAM_Tile,X				;

   LDA Entity_ReflectingFireball_TileProps	;
   STA OAM_Prop,X				;

   LDA Entity_ReflectingFireball_XPos		;
   CLC						;
   ADC #$FC					;slightly center the animation
   STA OAM_X,X					;

CODE_EC13:
   RTS						;

CODE_EC14:
   JSR CODE_E9F2				;animation stuff
   CMP #$FF					;
   BEQ CODE_EC25				;ended appearing in

CODE_EC1B:
   CMP #$00					;
   BEQ CODE_EC13				;dont change anything if the value is 0 (reuse same animation frame)
   STA Entity_ReflectingFireball_DrawTile	;new tile, new animation frame
   JMP CODE_EBF2				;

CODE_EC25:
   LDA #Fireball_State_Normal			;normal state (bounce around, hurt people, etc)
   STA Entity_ReflectingFireball_State		;

   LDA #$1E					;bounce around for this long
   STA ReflectingFireball_Timer			;
   RTS						;

CODE_EC30:
   JSR CODE_E9F2				;animation
   CMP #$FF					;
   BNE CODE_EC1B				;

   LDX Entity_ReflectingFireball_OAMOffset	;slot shenanigan
   LDA #$F4					;fireball disappears graphically
   STA OAM_Y,X					;

   LDA #$00					;
   STA Entity_ReflectingFireball_State		;the fireball is gone

   LDA ReflectingFireball_SpawnTimerIndexModifier
   CMP #$02					;can only change the timing so far
   BEQ CODE_EC51				;

   INC ReflectingFireball_SpawnTimerIndexModifier

   LDA ReflectingFireball_SpawnTimerIndexModifier

CODE_EC51:
   LSR A					;umm... with the max value being 2, dividing by 8 basically renders this useless...
   LSR A					;
   LSR A					;(were these supposed to be ASLs? Mario Bros. Classic does not change this)
   LDY GameAorBFlag				;
   BEQ CODE_EC5B				;
   CLC						;
   ADC #$04					;once again, playing game B will make the fireball spawn faster

CODE_EC5B:
   CLC						;
   ADC ReflectingFireball_SpawnTimerIndex	;
   TAX						;

   LDA DATA_F089,X				;
   STA ReflectingFireball_SpawnTimer		;
   RTS						;

;check if the player have hit an entity with platform bump
;input:
;X - platform the entity's on
;Y - entity's x-pos that probably should make a contact with the bump.
;output:
;A - 0 = contact success, non-zero (FF in this case) = contact failure
CODE_EC67:
   LDA #$00					;
   STA PlayerScoreUpdateIndex			;check player 1 first
   STY $1F					;store entity's x-pos

   LDY #$00					;check Mario's impact first

CODE_EC6F:
   LDA BumpEntityVars,Y				;check bump flag
   BEQ CODE_EC91				;

   TXA						;get entity's platform index
   CMP BumpEntityVars+1,Y			;does it match with the platform that's being bumped?
   BNE CODE_EC91				;

   LDA $1F					;check if the entity's in proximity of said bump
   SEC						;
   SBC #$10					;check 16 pixels ahead to the right
   CMP BumpEntityVars+2,Y			;
   BCS CODE_EC91				;too far to the right

   LDA $1F					;more proximity
   CLC						;
   ADC #$10					;check 16 pixels behind to the left
   CMP BumpEntityVars+2,Y			;
   BCC CODE_EC91				;too far to the left

   LDA #$00					;YES!
   RTS						;

CODE_EC91:
   INC PlayerScoreUpdateIndex			;next player

   LDY #$05					;luigi's impact
   LDA PlayerScoreUpdateIndex			;got through both players?
   CMP #$02					;
   BNE CODE_EC6F				;not yet, loop

   LDA #$00					;
   STA PlayerScoreUpdateIndex			;reset

   LDA #$FF					;epic fail, no entity has been affected
   RTS						;

CODE_ECA2:
   LDA FreezieCanAppearFlag			;can freezie even appear?
   BNE CODE_ECAA				;

CODE_ECA7:
   JMP CODE_D904				;freezie can't spawn, keep its OAM and entity active flag at bay

CODE_ECAA:
   LDA FreezieAliveFlag				;is there freezie out there?
   BNE CODE_ECA7				;don't spawn anymore

;init freezie
CODE_ECAF:
   LDA #$FF					;timer for the next time it can appear
   STA FreezieAppearTimer			;

   LDA #$01					;freezie is alive, yes
   STA FreezieAliveFlag				;

   LDY CurrentEntity_OAMOffset			;keep the same OAM offset
   LDX #<Entity_Address_Size-1			;initialize entity addresses for freezie

CODE_ECBD:
   LDA DATA_ECCC,X				;
   STA CurrentEntity_Address,X			;
   DEX						;
   BPL CODE_ECBD				;
   STY CurrentEntity_OAMOffset			;same OAM offset as I said

   LDY #$04					;
   JMP RemoveEntitySpriteTiles_DFC4		;remove sprite tiles for freezie to take

;init entity values for freezie
DATA_ECCC:
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte $00					;CurrentEntity_MovementBits
.byte $02					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte FreezieMovementAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x16				;CurrentEntity_DrawMode
.byte GFX_Freezie_Move1				;CurrentEntity_DrawTile
.byte OAMProp_Palette3|OAMProp_BGPriority	;CurrentEntity_TileProps (since these enemies appear out of the pipe, they go behind the pipe)
.byte $00					;CurrentEntity_YPos (overwritten afterwards)
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte $00					;CurrentEntity_OAMOffset (overwritten afterwards)
.byte $00					;CurrentEntity_PaletteOffset (has no effect on freezie)
.word DATA_F64C					;CurrentEntity_UpdateDataPointer
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_Freezie				;CurrentEntity_ID

.byte $00					;CurrentEntity_BumpedStateAndBits
.byte $00 					;CurrentEntity_MiscRAM
.byte $01					;CurrentEntity_PipeDir
.byte FreezieXMovementData_Start		;CurrentEntity_XSpeedTableOffset
.byte $02					;CurrentEntity_XSpeedTableEntry
.byte $01					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_XSpeedAlterTimer
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.byte $00,$00					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi (has no effect on anything other than players and reflecting fireballs)
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $04,$03					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

CODE_ECEC:
   LDA CurrentEntity_ID				;
   CMP #Entity_ID_Freezie			;
   BEQ CODE_ECFB				;

CODE_ECF2:
   JMP CODE_C6BF				;jump back and continue processing this entity

   JSR SkipEntityVRAMPosition_DFBD		;these lines are never executed. RIP (supposed to move onto a new entity)
   JMP CODE_C75A				;

;Freezie
CODE_ECFB:
   LDA CurrentEntity_BumpedStateAndBits		;is freezie currently being destroyed?
   BNE CODE_ECF2				;wait until its fully destroyed

   LDA FreezieAppearTimer			;is freezie active?
   BEQ CODE_ED20				;

   DEC FreezieAppearTimer			;
   BNE CODE_ECF2				;spawn freezie when this hits 0

   JSR RNG_D328					;reroll the RNG

   LDY #Entity_MovementBits_MovingRight		;
   LDX #$F0					;
   AND #$01					;RNG decides which pipe it'll come out of
   BEQ CODE_ED18				;

   LDY #Entity_MovementBits_MovingLeft		;
   LDX #$10					;

CODE_ED18:
   STY CurrentEntity_PipeDir			;coming out of pipe dir
   STY CurrentEntity_MovementBits		;actual movement dir
   STX CurrentEntity_XPos			;
   BNE CODE_ECF2				;always branch here

CODE_ED20:
   LDA CurrentEntity_Freezie_FreezeTimer	;explosion timer set?
   BNE CODE_ED6C				;freeze the platform

   LDA CurrentEntity_MovementBits		;in air movement?
   AND #Entity_MovementBits_AirMovement		;
   BNE CODE_ECF2				;can't freeze platforms when in air

   LDY CurrentEntity_XPos			;
   LDA CurrentEntity_CurrentPlatform		;check what platform
   CMP #$01					;
   BEQ CODE_ED40				;low platforms
   CMP #$02					;
   BNE CODE_ECF2				;center platform check

   CPY #$80					;at the dead center of the platform?
   BNE CODE_ECF2				;if not, no explosion

   LDA #$00					;center platform is being frozen
   LDX #$00					;
   BEQ CODE_ED50				;

CODE_ED40:
   LDA #$09					;freezing bottom-left platform (bottom-left part if you think they're connected)
   LDX #$01					;

   CPY #$30					;low level left part?
   BEQ CODE_ED50				;
   CPY #$D0					;right part
   BNE CODE_ECF2				;

   LDA #$10					;freezing bottom-right part
   LDX #$02					;

CODE_ED50:
   TAY						;
   LDA PlatformFrozenFlag,X			;check if current platform is already frozen 
   BNE CODE_ECF2				;don't think about it

   LDA #$01					;a debug leftover? it's worthless since what platform accepts X now
   STX FreezePlatform_WhatPlatform		;
   TYA						;
   STA FreezePlatformPointer_Offset		;

   LDA #$00					;
   STA FreezePlatformFlag			;freezit
   STA CurrentEntity_MovementBits		;not going anywhere

   LDA #$80					;how long does it take to freeze a platform
   STA CurrentEntity_Freezie_FreezeTimer	;
   BNE CODE_ECF2				;return

;freezie explosion
CODE_ED6C:
   DEC CurrentEntity_Freezie_FreezeTimer	;if timer hits zero, remove freezie, and change platform tiles to frozen ones
   BEQ CODE_EDAC				;

   LDA CurrentEntity_Freezie_FreezeTimer	;show a particular frame at different times
   LDY #Freezie_Explosion_Frame2		;
   CMP #$20					;
   BEQ CODE_ED9C				;
   CMP #$40					;
   BNE CODE_EDA9				;

;freezie explosion sprite tiles! this is some initialization
   LDA CurrentEntity_YPos			;freezie's y-pos
   CLC						;lace explosion tiles a few pixels below
   ADC #$07					;
   STA Freezie_Explosion_OAM_Y			;
   STA Freezie_Explosion_OAM_Y+4		;

   LDA #$03					;
   STA Freezie_Explosion_OAM_Prop		;properties
   STA Freezie_Explosion_OAM_Prop+4		;

   LDA CurrentEntity_XPos			;
   STA Freezie_Explosion_OAM_X+4		;
   SEC						;
   SBC #$08					;
   STA Freezie_Explosion_OAM_X			;

   LDY #Freezie_Explosion_Frame1		;

CODE_ED9C:
   STY Freezie_Explosion_OAM_Tile		;

   INY						;and the tile right after
   STY Freezie_Explosion_OAM_Tile+4		;

   LDA Sound_Effect				;freezie explode sound effect
   ORA #Sound_Effect_FreezieExplode		;
   STA Sound_Effect				;

CODE_EDA9:
   JMP CODE_C6BF				;do other entity stuff

CODE_EDAC:
   LDA BufferDrawFlag				;can't update?
   BNE CODE_EDE7				;keep them alive then
   
   LDA BumpBlockVars+1				;a platform bump is occuring somewhere
   ORA BumpBlockVars+6				;
   BNE CODE_EDE7				;keep alive until finished
   STA FreezePlatformTimer			;timer zero
   
   LDY #$04					;remove freezie's sprite tiles
   JSR RemoveEntitySpriteTiles_DFC4		;

   JSR CODE_EF50				;init freeze effect
   
   LDA #$01					;
   STA FreezePlatformFlag			;currently freezing a platform!
   LDX FreezePlatform_WhatPlatform		;
   STA PlatformFrozenFlag,X			;that platform becomes frozen
   
   LDA PlatformFrozenFlag			;
   AND PlatformFrozenFlag+1			;check if all platforms that can be frozen are frozen
   AND PlatformFrozenFlag+2			;
   BNE CODE_EDDD				;if so, freezies won't spawn anymore

   JSR CODE_ECAF				;re-initialize freezie when it spawns next
   JMP CODE_EDA9				;i guess it can interact or something?

CODE_EDDD:
   LDA #$00					;
   STA FreezieCanAppearFlag			;don't appear anymore
   STA CurrentEntity_ActiveFlag			;freezie no more

   JMP CODE_C75A				;no freezie, no problems

CODE_EDE7:
   INC CurrentEntity_Freezie_FreezeTimer	;stall freezie's timer until some VRAM shenanigans are done
   BNE CODE_EDA9				;
   
CODE_EDEB:
   LDA FreezePlatformFlag			;should we freeze a platform?
   BNE CODE_EDF1				;yes
   RTS						;no

;move ice sprites that freeze the platform
CODE_EDF1:
   LDA FreezePlatformTimer			;timer for freezing effect
   BEQ CODE_EE1F				;if time's up, either turn the platform frozen or remove sprites

   DEC FreezePlatformTimer			;decrement timer

   LDA FreezeEffect_OAM_X			;check if the ice sprite is at certain X-pos
   BEQ CODE_EE1E				;return
   CMP #$40					;
   BEQ CODE_EE1E				;
   CMP #$A0					;
   BEQ CODE_EE1E				;

   DEC FreezeEffect_OAM_X			;move one part to the left
   DEC FreezeEffect_OAM_X			;

   DEC FreezeEffect_OAM_X+4			;
   DEC FreezeEffect_OAM_X+4			;

   INC FreezeEffect_OAM_X+8			;and the other part right
   INC FreezeEffect_OAM_X+8			;

   INC FreezeEffect_OAM_X+12			;
   INC FreezeEffect_OAM_X+12			;

CODE_EE1E:
   RTS						;

;freeze the platform re-init (when timer runs out)
CODE_EE1F:
   LDX FreezePlatformPointer_Offset		;platform freeze index
   LDA DATA_EE53,X				;
   BEQ CODE_EE40				;stop freezing if encountering a stop command
   STA FreezePlatformPointer+1			;

   INX						;
   LDA DATA_EE53,X				;
   STA FreezePlatformPointer			;

   LDA #$01					;currently freezing da flag!
   STA FreezePlatform_UpdateFlag		;

   INX						;
   STX FreezePlatformPointer_Offset		;next pointer next time

   LDA #$08					;
   STA FreezePlatformTimer			;
   RTS						;

CODE_EE40:
   LDA #$00					;don't process freezing anymore
   STA FreezePlatformFlag			;
   STA FreezePlatform_UpdateFlag		;

   LDA #$F4					;
   LDX #$0F					;

CODE_EE4C:
   STA FreezeEffect_OAM_Y,X			;remove freeze effect
   DEX						;
   BPL CODE_EE4C				;
   RTS						;

;Freezie platform freeze pointers
DATA_EE53:
.byte >DATA_F763,<DATA_F763			;$F7,$63
.byte >DATA_F76D,<DATA_F76D			;$F7,$6D
.byte >DATA_F77B,<DATA_F77B			;$F7,$7B
.byte >DATA_F78B,<DATA_F78B			;$F7,$8B
.byte VRAMWriteCommand_Stop

.byte >DATA_F79B,<DATA_F79B			;$F7,$9B
.byte >DATA_F7A4,<DATA_F7A4			;$F7,$A4
.byte >DATA_F7B3,<DATA_F7B3			;$F7,$B3
.byte VRAMWriteCommand_Stop

.byte >DATA_F7C2,<DATA_F7C2			;$F7,$C2
.byte >DATA_F7CB,<DATA_F7CB			;$F7,$CB
.byte >DATA_F7DA,<DATA_F7DA			;$F7,$DA
.byte VRAMWriteCommand_Stop

;turn tiles into frozen ones (runs from NMI!)
CODE_EE6A:
   LDA FreezePlatform_UpdateFlag		;update platform?
   BEQ CODE_EE81				;no, return

   LDA FreezePlatformPointer			;where to take positions an stuff?
   STA $00					;

   LDA FreezePlatformPointer+1			;
   STA $01					;

   JSR CODE_CE00				;buffer and all

   LDA #$00					;
   STA FreezePlatform_UpdateFlag		;update once

CODE_EE81:
   RTS						;

;Adds a measily 10 to the player's score (for bumping an enemy from below)
Award10ScorePoints_EE82:
   LDA $00                  
   PHA
   LDA $06                  
   PHA
   LDA $07                  
   PHA

   LDA #$10					;give 10 score
   STA $00					;

   LDX PlayerScoreUpdateIndex			;
   LDA #$01					;
   STA PlayerScoreUpdateFlag,X			;
   TXA						;\
   STA $01					;/(minor optimization: STX)

   JSR CODE_DE83				;SCORE!!

   PLA						;
   STA $07					;
   PLA						;
   STA $06					;
   PLA						;
   STA $00					;
   RTS						;

CODE_EEA5:
   STA CurrentEntity_YPos			;get the platform level for the fireball, pretty please
   JSR CODE_D019				;
   LDX CurrentEntity_CurrentPlatform		;get platform (for bumping by the player from below)
   RTS						;

;passing checks for fireball spawn - if it should even spawn
CODE_EEAD:
   LDA EntitySpawnIndex				;check if an enemy is currently being spawned (or if we're in TEST YOUR SKILL phase)
   CMP #$AA					;
   BNE CODE_EEB9				;fireball won't appear at the same time

   LDA $45					;check if there aren't too many enemies on-screen
   CMP #$04					;
   BCC CODE_EEBB				;

CODE_EEB9:  
   PLA						;terminate (return from routine that called this routine)
   PLA						;

CODE_EEBB:  
   RTS						;

;"push" reflecting fireball to the right after hitting the left screen boundary
CODE_EEBC:
   JSR RNG_D328					;call RNG routine
   AND #$07					;move between 0-7 pixels right
   CLC						;
   ADC Entity_ReflectingFireball_XPos		;
   STA Entity_ReflectingFireball_XPos		;

   INC Entity_ReflectingFireball_YPos		;move it down one pixel, because why not
   RTS

;"push" reflecting fireball to the left after hitting the right screen boundary
CODE_EECC:
   JSR RNG_D328					;pray upon RNG gods and get their answer
   AND #$03					;move between 0 to 3 pixels left
   STA $07					;is this necessary??? previous routine did not do this

   LDA Entity_ReflectingFireball_XPos		;displace it
   SEC						;
   SBC $07					;
   STA Entity_ReflectingFireball_XPos		;

   DEC Entity_ReflectingFireball_YPos		;move it up a couple pixels for good measure
   DEC Entity_ReflectingFireball_YPos		;
   RTS						;

;spawn a score sprite
;A - score value/ID
;$11 - which player spawned score (will use appropriate palette)
SpawnScoreSprite_EEE3:
   STA $1E					;save score value index.
   TXA						;Y-position from X
   SEC						;
   LDX Score_Slot				;if sprite isn't in first slot, it'll be spawned higher up (weird but ok)
   BEQ CODE_EEEE				;
   SBC #$08					;8 pixels higher

CODE_EEEE:
   SBC #$18					;24 pixels higher
   STA Score_OAM_Y,X				;score sprite tiles' Y-position
   STA Score_OAM_Y+4,X				;
   TYA						;X-position from Y
   SEC						;
   SBC #$08					;first sprite tile's 8 pixels to the left
   STA Score_OAM_X,X				;
   TYA						;
   STA Score_OAM_X+4,X				;

   LDY $1E					;load score value
   LDA DATA_EF97,Y				;load respective sprite tile
   STA Score_OAM_Tile,X				;

   LDA #Score_Zeros_Tile			;second tile is always "00"
   STA Score_OAM_Tile+4,X			;

   LDY #Score_ForMarioPalette			;
   LDA $11					;check which player triggered score
   BEQ CODE_EF16				;use appropriate color palette for luigi or mario
   LDY #Score_ForLuigiPalette			;

CODE_EF16:
   TYA						;
   STA Score_OAM_Prop,X				;store props
   STA Score_OAM_Prop+4,X			;

   LDX #$00					;
   LDY #$08					;
   LDA Score_Slot				;check if we already ran through first score sprite
   BEQ CODE_EF29				;no, set its timer
   INX						;
   LDY #$00					;

CODE_EF29:
   LDA #$40					;
   STA Score_Timer,X				;timer for score sprite's graphic to stay
   STY Score_Slot				;next score sprite
   RTS						;

;handle score sprite's display on timer.
CODE_EF32:
   LDX #$00					;
   LDY #$00					;

CODE_EF36:
   LDA Score_Timer,X				;if first score sprite's timer is zero
   BEQ CODE_EF48				;check the other

   DEC Score_Timer,X				;decrease it's timer
   BNE CODE_EF48				;untill it's zero

   LDA #$F4					;erase sprite tiles
   STA Score_OAM_Y,y				;
   STA Score_OAM_Y+4,y				;

CODE_EF48:
   LDY #$08					;check next score sprite (OAM offset)
   INX						;
   CPX #$02					;check if ran through both
   BNE CODE_EF36				;
   RTS						;

;spawn freeze effect sprite tiles
CODE_EF50:
   LDA FreezePlatform_WhatPlatform		;set positions and stuff based on where it exploded
   ASL A					;
   ASL A					;
   ASL A					;
   ASL A					;
   TAX						;

   LDY #$00					;

CODE_EF5A:
   LDA DATA_EF67,X				;store properties
   STA FreezeEffect_OAM_Y,Y			;

   INX						;
   INY						;
   CPY #$10					;drew all 4?
   BNE CODE_EF5A				;if not, loop
   RTS						;

;freeze effect tiles' OAM data
DATA_EF67:
.byte $77,FreezeEffect_Tile1,FreezeEffect_Property,$70
.byte $77,FreezeEffect_Tile2,FreezeEffect_Property,$78
.byte $77,FreezeEffect_Tile2,FreezeEffect_Property|OAMProp_XFlip,$80
.byte $77,FreezeEffect_Tile1,FreezeEffect_Property|OAMProp_XFlip,$88

.byte $A7,FreezeEffect_Tile1,FreezeEffect_Property,$20
.byte $A7,FreezeEffect_Tile2,FreezeEffect_Property,$28
.byte $A7,FreezeEffect_Tile2,FreezeEffect_Property|OAMProp_XFlip,$30
.byte $A7,FreezeEffect_Tile1,FreezeEffect_Property|OAMProp_XFlip,$38

.byte $A7,FreezeEffect_Tile1,FreezeEffect_Property,$C0
.byte $A7,FreezeEffect_Tile2,FreezeEffect_Property,$C8
.byte $A7,FreezeEffect_Tile2,FreezeEffect_Property|OAMProp_XFlip,$D0
.byte $A7,FreezeEffect_Tile1,FreezeEffect_Property|OAMProp_XFlip,$D8

;Sprite tile values for each score value.
DATA_EF97:
.byte Score_8_Tile				;8 for 800
.byte Score_16_Tile				;16 for 1600
.byte Score_24_Tile				;24 for 2400
.byte Score_32_Tile				;32 for 3200
.byte Score_2_Tile				;2 for 200 (unused)
.byte Score_5_Tile				;5 for 500

;reflecting fireball appearing effect animation table
;$00 - keep the same frame as before, used to prolong the frame of animation
;$FF - terminator, as you'd expect
;ReflectingFireball_AppearingAnimFrames_EF9D:
DATA_EF9D:
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop5,$00,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop1,$00,$00
.byte GFX_Fireball_Move1,$00,$00
.byte GFX_Fireball_Move2,$00,$00
.byte GFX_Fireball_Move3,$00,$00
.byte GFX_Fireball_Move4,$00
.byte GFX_Fireball_Move1,$00
.byte GFX_Fireball_Move2,$00
.byte GFX_Fireball_Move3,$00
.byte $FF

;initial values for reflecting fireball
SpawnInitValues_ReflectingFireball_EFBB:
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte Entity_MovementBits_MovingRight		;CurrentEntity_MovementBits
.byte $03					;CurrentEntity_TimerStorage
.byte $01					;CurrentEntity_UpdateTimer
.byte FireballMovementAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x8				;CurrentEntity_DrawMode
.byte GFX_Fireball_Move1			;CurrentEntity_DrawTile
.byte ReflectingFireball_Property		;CurrentEntity_TileProps
.byte $F4					;CurrentEntity_YPos (overwritten afterwards)
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte ReflectingFireball_OAM_Slot*4		;CurrentEntity_OAMOffset
.byte $00					;Entity_ReflectingFireball_ObjCollisionDisableTimer
.word $0000					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_ReflectingFireball		;CurrentEntity_ID

.byte $00					;Entity_ReflectingFireball_State
.byte $01 					;Entity_ReflectingFireball_VertDirection
.byte $00					;CurrentEntity_PipeDir (has no effect on fireball)
.byte $00					;CurrentEntity_XSpeedTableOffset (has no effect on fireball)
.byte $00					;CurrentEntity_XSpeedTableEntry (has no effect on fireball)
.byte $01					;Entity_ReflectingFireball_YSpeed
.byte $00					;CurrentEntity_XSpeedAlterTimer (has no effect on fireball)
.word $0000					;Entity_ReflectingFireball_VRAMPosLo/Entity_ReflectingFireball_VRAMPosHi
.byte $00					;CurrentEntity_DefeatedState
.byte $00					;unused
.byte $00					;Entity_ReflectingFireball_TileAtBottomVRAMPos
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $04,$04					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;wavy fireball appearing effect animation table
DATA_EFDB:
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop5,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop5,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop5,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop5,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop5,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop5,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00
.byte GFX_Fireball_Pop1,$00
.byte $FF

;reflecting fireball disappearing effect animation table
DATA_F006:
.byte GFX_Fireball_Pop1,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00

;shared with wavy fireball
DATA_F00C:
.byte $00
.byte GFX_Fireball_Pop4,$00
.byte GFX_Fireball_Pop5,$00
.byte GFX_Fireball_Pop2,$00
.byte GFX_Fireball_Pop3,$00,$00
.byte GFX_Fireball_Pop4,$00
.byte GFX_Fireball_Pop5,$00
.byte $FF

;wavy fireball movement (y-speeds and special commands)
;$AA - reset to the beginning of the table, restart wavy movement
;$BB - indicate it's at it's lowest point, can interact with bump tiles
;$CC - turn fireball sound on
;$DD - turn fireball sound off
DATA_F01B:
.byte $00,$00,$FF,$FF,$DD,$FF,$FE,$FE
.byte $FD,$FE,$FE,$FF,$FF,$00,$FF,$00
.byte $FF,$00,$00,$00,$01,$00,$01,$00
.byte $01,$01,$02,$02,$03,$02,$02,$01
.byte $CC,$01,$01,$00,$00,$BB,$00,$00
.byte $FF,$00,$FF,$FF,$DD,$FF,$FE,$FF
.byte $FF,$FF,$FF,$00,$00,$00,$01,$01
.byte $01,$02,$02,$01,$01,$CC,$01,$00
.byte $01,$00,$00,$BB,$00,$AA

SpawnInitValues_WavyFireball_F061:
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte Entity_MovementBits_MovingRight		;CurrentEntity_MovementBits
.byte $00					;CurrentEntity_TimerStorage
.byte $01					;CurrentEntity_UpdateTimer
.byte FireballMovementAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x8				;CurrentEntity_DrawMode
.byte GFX_Fireball_Move1			;CurrentEntity_DrawTile
.byte WavyFireball_Property			;CurrentEntity_TileProps
.byte $F4					;CurrentEntity_YPos (overwritten afterwards)
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte WavyFireball_OAM_Slot*4			;CurrentEntity_OAMOffset
.byte $00					;CurrentEntity_PaletteOffset (has no effect on fireball)
.word $0000					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_WavyFireball			;CurrentEntity_ID

.byte $00					;Entity_WavyFireball_State
.byte $80 					;Entity_WavyFireball_AppearTimer
.byte $00					;CurrentEntity_PipeDir (has no effect on fireball)
.byte $00					;CurrentEntity_XSpeedTableOffset (has no effect on fireball)
.byte $00					;CurrentEntity_XSpeedTableEntry (has no effect on fireball)
.byte $00					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_XSpeedAlterTimer (has no effect on fireball)
.byte $00					;CurrentEntity_XSpeedModifier (has no effect on fireball)
.byte $00					;CurrentEntity_TurningCounter (has no effect on fireball)
.byte $00					;CurrentEntity_DefeatedState
.word $0000					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi (has no effect)
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $04,$04					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

DATA_F081:
.if Version <> PAL
  .byte $28,$1E,$0A,$05,$0F,$0A,$07,$03		;NTSC
.else
  .byte $21,$19,$08,$04,$0D,$08,$06,$03		;PAL
.endif

;timer values for how long it should take for a reflecting fireball to appear
;progressively less and less time to spawn a fireball
DATA_F089:
.if Version <> PAL
  .byte $32,$32,$28,$26,$1E,$1E,$1C,$12		;NTSC
  .byte $28,$28,$1C,$12,$1C,$1C,$12,$0A
  .byte $1E,$14,$14,$12,$14,$12,$0A,$08
.else
  .byte $28,$28,$21,$1F,$19,$19,$17,$0F		;PAL
  .byte $21,$21,$17,$0F,$17,$17,$0F,$08
  .byte $19,$10,$10,$0F,$10,$0F,$08,$06
.endif

;y-positions for wavy fireball's spawn points, based on which platform level the player was on at the moment of its spawn
WavyFireball_SpawnYPos_F0A1:
.byte $CC,$9C,$6C,$3C

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Title screen tile layout data and attributes
;basically tilemap of title screen - logo and strings
;uses same data structure as other tables that use CODE_CE00
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DATA_F0A5:
.byte $20,$83				;location to write to
.byte $02				;amount of bytes to write in line
.byte $76,$7A				;tiles to write

.byte $20,$A3				;next location
.byte $02				;amount of tiles
.byte $77,$79				;tiles

.byte $20,$9A				;etc.
.byte $02
.byte $7C,$7E

.byte $20,$BA
.byte $02
.byte $7D,$7F

.byte $21,$63
.byte $02
.byte $80,$82

.byte $21,$83
.byte $02
.byte $81,$83

.byte $21,$7A
.byte $02
.byte $84,$86

.byte $21,$9A
.byte $02
.byte $85,$87

.byte $20,$85
.byte VRAMWriteCommand_Repeat|$0A
.byte $7B

.byte $20,$90
.byte VRAMWriteCommand_Repeat|$0A
.byte $7B

.byte $21,$85
.byte VRAMWriteCommand_Repeat|$0A
.byte $89

.byte $21,$90
.byte VRAMWriteCommand_Repeat|$0A
.byte $89

.byte $20,$C3
.byte $19				;this time we write 25 tiles in a row
.byte $78,$24,$24,$68,$69,$69,$6B,$69,$68
.byte $69,$68,$6B,$69,$24,$68,$69,$68
.byte $69,$6B,$69,$6B,$69,$24,$24,$88

.byte $20,$E6
.byte $13				;this time 19 tiles
.byte $68,$6A,$6A,$6E,$6A
.byte $68,$6A,$68,$6E,$6A,$24,$68,$6A
.byte $68,$6A,$6E,$6A,$6E,$71

.byte $21,$06
.byte $13
.byte $68,$6A,$6A,$68,$6C,$68,$6D
.byte $68,$6E,$6A,$24,$68,$6D,$68,$6D
.byte $6E,$6A,$6F,$69

.byte $21,$26
.byte $13
.byte $68,$6A,$6A,$6E,$6A,$68,$6A,$68,$6E
.byte $6A,$24,$68,$6A,$68,$6A,$6E,$6A
.byte $72,$6A

.byte $21,$43
.byte $19
.byte $78,$24,$24,$68,$6A,$6A,$6E,$6A
.byte $68,$6A,$68,$6F,$70,$24,$68,$70
.byte $68,$6A,$6F,$70,$6F,$70,$73,$24,$88

;this is where strings are stored (1 PLAYER GAME A, 2 PLAYER GAME B, etc.)

;1 PLAYER GAME A
OnePlayerGameAString:
.byte $22,$09
.byte @StringEnd-@StringStart
@StringStart:
	.byte "1 PLAYER GAME A"
@StringEnd:

;1 PLAYER GAME B
OnePlayerGameBString:
.byte $22,$49
.byte @StringEnd-@StringStart
@StringStart:
	.byte "1 PLAYER GAME B"
@StringEnd:

TwoPlayerGameAString:
;2 PLAYER GAME A
.byte $22,$89
.byte @StringEnd-@StringStart
@StringStart:
	.byte "2 PLAYER GAME A"
@StringEnd:

TwoPlayerGameBString:
;2 PLAYER GAME B
.byte $22,$C9
.byte @StringEnd-@StringStart
@StringStart:
	.byte "2 PLAYER GAME B"
@StringEnd:

NintendoCOString:
;(c)1983 NINTENDO CO.,LTD.
.byte $23,$05
.byte @StringEnd-@StringStart
@StringStart:
	.byte CopyrightSymbol,"1983 NINTENDO CO",DotAndComma,"LTD."
@StringEnd:

;MADE IN JAPAN
MadeInJapanString:
.byte $23,$4B
.byte @StringEnd-@StringStart
@StringStart:
	.byte "MADE IN JAPAN"
@StringEnd:

;.byte $0D
;.byte $16,$0A,$0D,$0E,$24,$12,$17,$24,$13,$0A,$19,$0A,$17

;finally, attributes to give our tiles some color
.byte $23,$C8
.byte $0F
.byte $AA,$2A,$0A,$0A,$0A,$0A
.byte $8A,$00,$FF,$30,$00,$00,$00,$00
.byte $C0

.byte $23,$D8
.byte VRAMWriteCommand_Repeat|$08		;repeat 8 times same attribute
.byte $FF

.byte $23,$E0
.byte VRAMWriteCommand_Repeat|$10
.byte $55

.byte $23,$F0
.byte VRAMWriteCommand_Repeat|$08
.byte $AA

.byte VRAMWriteCommand_Stop			;end writing (finally)

;initialize platforms. do note that the tiles themselves aren't provided as they are stored from the address in RAM.
DATA_F1E7:
.byte $21,$20
.byte VRAMWriteCommand_Repeat|$0E

.byte $21,$32
.byte VRAMWriteCommand_Repeat|$0E

.byte $21,$E8
.byte VRAMWriteCommand_Repeat|$10

.byte $22,$00
.byte VRAMWriteCommand_Repeat|$04

.byte $22,$1C
.byte VRAMWriteCommand_Repeat|$04

.byte $22,$A0
.byte VRAMWriteCommand_Repeat|$0C

.byte $22,$B4
.byte VRAMWriteCommand_Repeat|$0C

.byte VRAMWriteCommand_Stop

;more data, bottom bricks?
.byte $23,$60
.byte VRAMWriteCommand_Repeat|$20

.byte $23,$80
.byte VRAMWriteCommand_Repeat|$20

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DATA_F203 - Palette Data
;This is where Palette data uploaded to VRAM is located.
;It uses generic PPU write format, as other tables that use CODE_CE00 (to be explained).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DATA_F203:
.byte $3F,$00					;PPU Address to write to
.byte $20					;How many bytes to write (32 in dec)

;Gameplay Palette, used during, well, gameplay, including demo.
.byte $0F,$30,$2C,$12				;>Background 0, used by Phase 1's platforms, frozen platforms, POW and player's roman number tiles
.byte $0F,$30,$29,$09				;>Background 1, used by pipes
.byte $0F,$30,$27,$18				;>Background 2, used by bonus phases' platforms, phase 4 platforms and phase 9 onward's platforms
.byte $0F,$30,$26,$06				;>Background 3, used by phase 6's platforms

.byte $0F,$16,$37,$12				;>Sprite 0, used by Mario and fighter fly
.byte $0F,$30,$27,$19				;>Sprite 1, used by Luigi shellcreepers and fireballs
.byte $0F,$30,$27,$16				;>Sprite 2, used by sidesteppers and fireballs
.byte $0F,$2C,$12,$25				;>Sprite 3, used last enemy and by freezies

.byte VRAMWriteCommand_Stop			;Command used to stop writing.

DATA_F227:
.byte $3F,$00					;PPU Address
.byte $14					;Write 20 bytes to PPU. That means no Sprite Palette 2-4 overwrite.

;Palette used for title screen.
.byte $0F,$16,$16,$16				;>Background 0, used by MARIO BROS. logo
.byte $0F,$27,$27,$27				;>Background 1, used by option strings
.byte $0F,$30,$2C,$12				;>Background 2, used by logo's top border and copyright strings
.byte $0F,$30,$29,$19				;>Background 3, used by logo's bottom border

.byte $0F,$35,$35,$35				;>Sprite 1, used by select sprite

.byte VRAMWriteCommand_Stop			;stop writing

;General attribute setup table
;attributes that ar written for all phases. that being HUD and brick floor. just like before, uses generic PPU write format.

DATA_F23F:
.byte $23,$C0					;PPU address
.byte $10					;16 bytes
.byte $00,$00,$C0,$30,$00,$50,$00,$00
.byte $55,$55,$00,$00,$00,$00,$55,$55

.byte $23,$F0					;another PPU address, being at the bottom of the screen, aka brick flooring
.byte $10					;16 bytes
.byte $F5,$FF,$FF,$FF,$FF,$FF,$FF,$F5
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

.byte VRAMWriteCommand_Stop			;stop write


;attributes used for ledge tiles 93 and 97
DATA_F266:
.byte $23,$D0
.byte VRAMWriteCommand_Repeat|$18		;repeat one byte $18 times
.byte $00					;

.byte $23,$E8
.byte $08					;8 bytes
.byte $50,$00,$00,$00,$00,$00,$00,$50		;

.byte VRAMWriteCommand_Stop			;end

;attributes used for ledge tiles 94 and 96
DATA_F276:
.byte $23,$D0
.byte VRAMWriteCommand_Repeat|$18
.byte $AA

.byte $23,$E8
.byte $08
.byte $5A,$AA,$AA,$00,$00,$AA,$AA,$5A

.byte VRAMWriteCommand_Stop		;stop write

;attributes used for ledge tile 95
DATA_F286:
.byte $23,$D0
.byte VRAMWriteCommand_Repeat|$18
.byte $FF

.byte $23,$E8
.byte $08
.byte $5F,$FF,$FF,$00,$00,$FF,$FF,$5F

.byte VRAMWriteCommand_Stop

;graphic pointers for every entity in game
DATA_F296:
.word DATA_F2A6				;$A6,$F2	;mario
.word DATA_F2B9				;$B9,$F2
.word DATA_F2C6				;$C6,$F2
.word DATA_F2C6				;$C6,$F2
.word DATA_F2D0				;$D0,$F2
.word DATA_F2DA				;$DA,$F2
.word DATA_F2E1				;$E1,$F2
.word DATA_F2E8				;$E8,$F2

DATA_F2A6:
.byte $00,$EF,$F8,$00,$EF,$00,$00,$F7
.byte $F8,$00,$F7,$00,$00,$00,$F8,$00
.byte $00,$00,$AA

DATA_F2B9:
.byte $00,$F7,$F8,$00,$F7,$00,$00,$00
.byte $F8,$00,$00,$00,$AA

DATA_F2C6:
.byte $80,$F7,$F8,$01,$F7,$00,$00,$00
.byte $FC,$AA

DATA_F2D0:
.byte $00,$F7,$FC,$80,$00,$F8,$01,$00
.byte $00,$AA

DATA_F2DA:
.byte $00,$F7,$FC,$00,$00,$FC,$AA

DATA_F2E1:
.byte $00,$F7,$F8,$00,$00,$FC,$AA

DATA_F2E8:
.byte $00,$FC,$FC,$AA

;this table contains various initial props and such for Player entities
SpawnInitValues_Players_F2EC:
;Mario
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte $00					;CurrentEntity_MovementBits
.byte $03					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte $00					;CurrentEntity_AnimationPointer (has no effect on player)
.byte Entity_Draw_16x24				;CurrentEntity_DrawMode
.byte GFX_Player_Standing			;CurrentEntity_DrawTile
.byte OAMProp_Palette0|OAMProp_XFlip		;CurrentEntity_TileProps
.byte $D0					;CurrentEntity_YPos
.byte $44					;CurrentEntity_XPos
.byte Mario_OAM_Slot*4				;CurrentEntity_OAMOffset
.byte $00					;CurrentEntity_PaletteOffset (has no effect on player)
.word $0000					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_Mario				;CurrentEntity_ID

.byte $00					;CurrentEntity_Player_ControllerInputs
.byte $00 					;CurrentEntity_Player_BumpedBits
.byte $00					;CurrentEntity_Player_MovementTimer
.byte $00					;CurrentEntity_XSpeedTableOffset
.byte $00					;CurrentEntity_XSpeedTableEntry
.byte $01					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_Player_State
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.word $0000					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $04,$04					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;Luigi
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte $00					;CurrentEntity_MovementBits
.byte $03					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte $00					;CurrentEntity_AnimationPointer (has no effect on player)
.byte Entity_Draw_16x24				;CurrentEntity_DrawMode
.byte GFX_Player_Standing			;CurrentEntity_DrawTile
.byte OAMProp_Palette1				;CurrentEntity_TileProps
.byte $D0					;CurrentEntity_YPos
.byte $C4					;CurrentEntity_XPos
.byte Luigi_OAM_Slot*4				;CurrentEntity_OAMOffset
.byte $00					;CurrentEntity_PaletteOffset (has no effect on player)
.word $0000					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_Luigi				;CurrentEntity_ID

.byte $00					;CurrentEntity_Player_ControllerInputs
.byte $00 					;CurrentEntity_Player_BumpedBits
.byte $00					;CurrentEntity_Player_MovementTimer
.byte $00					;CurrentEntity_XSpeedTableOffset
.byte $00					;CurrentEntity_XSpeedTableEntry
.byte $01					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_Player_State
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.word $0000					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $04,$04					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;Speed values are altered for PAL version

;gravity y-speeds for fighterflies (stall in air for a bit, then applies general gravity that comes right after)
DATA_F32C:
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00

;gravity y-speeds for entities (differs between PAL and NTSC versions)
DATA_F33A:
.if Version <> PAL
  .byte $01,$00,$01,$00,$01,$01,$00,$01		;NTSC gravity
  .byte $01,$02,$01,$02,$02,$02,$02,$02
  .byte $02,$03,$03,$03,$03
.else
  .byte $01,$00,$01,$01,$01,$02,$01,$02		;PAL gravity (faster)
  .byte $02,$02,$02,$03,$03,$03,$03,$03
  .byte $03
.endif

.byte $AA

;Vertical jump/bounce y-speeds for Mario & Luigi (when jumping or bouncing off another player)
DATA_F350:
.if Version <> PAL
  .byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FD		;NTSC
  .byte $FD,$FE,$FE,$FE,$FE,$FE,$FE,$FF
  .byte $FE,$FF,$FF,$FF,$00,$FF,$FF,$00
  .byte $FF,$00,$00,$00
.else
  .byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC		;PAL
  .byte $FD,$FD,$FE,$FE,$FE,$FE,$FE,$FE
  .byte $FE,$FF,$FF,$FF,$00,$FF,$00
.endif

.byte $AA

;Vertical jump y-speeds for the Fighterfly when not on the bottom platform
DATA_F36D:
.if Version <> PAL
  .byte $FE,$FE,$FE
.else
  .byte $FD,$FE,$FE
.endif

;vertical jump y-speeds for the Fighterfly, general
DATA_F370:
.if Version <> PAL
  .byte $FF,$FF,$FF,$FF,$FF,$00,$FF,$00		;NTSC
  .byte $FF,$00
.else
  .byte $FE,$FE,$FF,$FF,$FF,$00,$FF		;PAL
.endif

.byte $AA

;Sidestepper's something
DATA_F37B:
.if Version <> PAL
  .byte $00,$01,$00,$01,$00,$01,$01,$01		;NTSC
  .byte $02,$01,$01,$02,$03,$03,$04,$04
  .byte $CC,$04,$CC,$CC,$CC,$04,$CC
.else
  .byte $00,$01,$01,$01,$01,$01,$02,$02		;PAL (I don't think I need to tell you that fact from now on, just know that values after .if - NTSC, after .else - PAL)
  .byte $02,$02,$03,$03,$04,$04,$CC,$04
  .byte $CC,$CC,$CC,$04,$CC
.endif

.byte $AA

;x-speed, movement timing (every x frames), speed modifier (typically used to make the entity stop at certain times so it looks like it moves slowly)
EntityXMovementData_F393:
PlayerXMovementData:
.if Version <> PAL
  .byte $01,$03,$00
  .byte $01,$02,$00
  .byte $01,$01,$00
.else
  .byte $01,$02,$00
  .byte $01,$01,$00
  .byte $01,$01,$00
.endif
.byte $AA

ShellcreeperXMovementData:
.if Version <> PAL
  .byte $01,$03,$00
  .byte $01,$02,$00
  .byte $01,$01,$FF
.else
  .byte $01,$02,$00
  .byte $01,$01,$FF
  .byte $01,$01,$00
.endif
.byte $AA

SidestepperXMovementData:
.if Version <> PAL
  .byte $01,$02,$00
  .byte $01,$01,$FF
  .byte $01,$01,$FF
  .byte $01,$01,$00
  .byte $01,$01,$00
  .byte $01,$01,$01			;third byte = actutally speed up instead of slowing down every now and then
.else
  .byte $01,$01,$FF
  .byte $01,$01,$00
  .byte $01,$01,$00
  .byte $01,$01,$01
  .byte $01,$01,$01
  .byte $02,$01,$FF
.endif
.byte $AA

;This set of data is enemy data to spawn from pipes per "Enemy level".
;First, there are pointers to appropriate tables.
DATA_F3BA:
.word DATA_F3D2
.word DATA_F3D9
.word DATA_F3E4
.word DATA_F3ED
.word DATA_F3FA
.word DATA_F403
.word DATA_F40E
.word DATA_F419
.word DATA_F424
.word DATA_F431
.word DATA_F43E
.word DATA_F449

;then there are tables for enemy spawns, each enemy takes a pair of bytes:
;first byte is timer for how long it should take to come out of the pipe
;second byte is the entity ID, where 0 - Shellkreeper, 1 - Sidestepper, 2 - Fighterfly.
;$AA is a terminator, making no more enemies spawn.

;3 shellkreepers
DATA_F3D2:
.if Version <> PAL
  .byte $05,$00
  .byte $12,$00
  .byte $1F,$00
.else
  .byte $04,$00				;yes, spawning times are also different in PAL version
  .byte $0E,$00
  .byte $19,$00
.endif
.byte $AA

;5 shellkreepers
DATA_F3D9:
.if Version <> PAL
  .byte $05,$00
  .byte $12,$00
  .byte $1F,$00
  .byte $19,$00
  .byte $1F,$00
.else
  .byte $04,$00
  .byte $0E,$00
  .byte $19,$00
  .byte $14,$00
  .byte $19,$00
.endif
.byte $AA

;4 sidesteppers
DATA_F3E4:
.if Version <> PAL
  .byte $05,$01
  .byte $0C,$01
  .byte $2B,$01
  .byte $0C,$01
.else
  .byte $04,$01
  .byte $0A,$01
  .byte $24,$01
  .byte $0A,$01
.endif
.byte $AA

;4 sidesteppers and 2 shellkreepers
DATA_F3ED:
.if Version <> PAL
  .byte $03,$01
  .byte $0C,$01
  .byte $31,$00
  .byte $06,$00
  .byte $49,$01
  .byte $07,$01
.else
  .byte $03,$01
  .byte $0A,$01
  .byte $28,$00
  .byte $05,$00
  .byte $3C,$01
  .byte $06,$01
.endif
.byte $AA

;4 fighterflies
DATA_F3FA:
.if Version <> PAL
  .byte $0C,$02
  .byte $0C,$02
  .byte $31,$02
  .byte $0C,$02
.else
  .byte $0A,$02
  .byte $0A,$02
  .byte $28,$02
  .byte $0A,$02
.endif
.byte $AA

;3 fighterflies and 2 sidesteppers
DATA_F403:
.if Version <> PAL
  .byte $0C,$02
  .byte $0C,$02
  .byte $31,$01
  .byte $06,$01
  .byte $31,$02
.else
  .byte $0A,$02
  .byte $0A,$02
  .byte $28,$01
  .byte $05,$01
  .byte $28,$02
.endif
.byte $AA

;4 shellkreepers, 1 fighterfly
DATA_F40E:
.if Version <> PAL
  .byte $03,$00
  .byte $0C,$00
  .byte $31,$02
  .byte $06,$00
  .byte $31,$00
.else
  .byte $03,$00
  .byte $0A,$00
  .byte $28,$02
  .byte $05,$00
  .byte $28,$00
.endif
.byte $AA

;4 sidesteppers, 1 fighterfly
DATA_F419:
.if Version <> PAL
  .byte $03,$01
  .byte $0C,$01
  .byte $31,$02
  .byte $06,$01
  .byte $31,$01
.else
  .byte $03,$01
  .byte $0A,$01
  .byte $28,$02
  .byte $05,$01
  .byte $28,$01
.endif
.byte $AA

;4 sidesteppers, 2 fighterflies
DATA_F424:
.if Version <> PAL
  .byte $0C,$02
  .byte $0C,$01
  .byte $31,$01
  .byte $06,$01
  .byte $31,$02
  .byte $12,$01
.else
  .byte $0A,$02
  .byte $0A,$01
  .byte $28,$01
  .byte $05,$01
  .byte $28,$02
  .byte $0E,$01
.endif
.byte $AA

;4 sidesteppers, 2 fighterflies, different order
DATA_F431:
.if Version <> PAL
  .byte $03,$01
  .byte $0C,$01
  .byte $31,$01
  .byte $06,$02
  .byte $31,$02
  .byte $12,$01
.else
  .byte $03,$01
  .byte $0A,$01
  .byte $28,$01
  .byte $05,$02
  .byte $28,$02
  .byte $0E,$01
.endif
.byte $AA

;4 shellkreepers, 1 sidestepper
DATA_F43E:
.if Version <> PAL
  .byte $03,$00
  .byte $0C,$00
  .byte $31,$01
  .byte $06,$00
  .byte $06,$00
.else
  .byte $03,$00
  .byte $0A,$00
  .byte $28,$01
  .byte $05,$00
  .byte $05,$00
.endif
.byte $AA

;4 shellkreepers, different timings
DATA_F449:
.if Version <> PAL
  .byte $01,$00
  .byte $05,$00
  .byte $40,$00
  .byte $FF,$00
.else
  .byte $01,$00
  .byte $05,$00
  .byte $31,$00
  .byte $FF,$00
.endif
.byte $AA

;initial values for entities when spawned, specifically, shellcreeper, sidestepper and fighterfly
DATA_F452:
SpawnInitValues_Enemies_F452:
;shellcreeper values
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte $00					;CurrentEntity_MovementBits
.byte $03					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte ShellcreeperWalkAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x16_Shift			;CurrentEntity_DrawMode
.byte GFX_Shellcreeper_Walk1			;CurrentEntity_DrawTile
.byte OAMProp_Palette1|OAMProp_BGPriority	;CurrentEntity_TileProps (since these enemies appear out of the pipe, they go behind the pipe)
.byte $28					;CurrentEntity_YPos
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte $00					;CurrentEntity_OAMOffset (overwritten afterwards)
.byte ShellcreeperPalettes_Start		;CurrentEntity_PaletteOffset
.word DATA_F64C					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_Shellcreeper			;CurrentEntity_ID

.byte $00					;CurrentEntity_BumpedStateAndBits
.byte $00 					;CurrentEntity_MiscRAM
.byte $00					;CurrentEntity_PipeDir
.byte ShellcreeperXMovementData_Start		;CurrentEntity_XSpeedTableOffset
.byte $00					;CurrentEntity_XSpeedTableEntry
.byte $01					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_XSpeedAlterTimer
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.byte $00,$00					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi (has no effect on anything other than players and reflecting fireballs)
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $04,$06					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;Sidestepper values
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte $00					;CurrentEntity_MovementBits
.byte $03					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte SidestepperWalkAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x16_FlickerTop		;CurrentEntity_DrawMode
.byte GFX_Sidestepper_Move1			;CurrentEntity_DrawTile
.byte OAMProp_Palette2|OAMProp_BGPriority	;CurrentEntity_TileProps
.byte $28					;CurrentEntity_YPos
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte $00					;CurrentEntity_OAMOffset (overwritten afterwards)
.byte SidestepperPalettes_Start			;CurrentEntity_PaletteOffset
.word DATA_F64C					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_Sidestepper			;CurrentEntity_ID

.byte $00					;CurrentEntity_BumpedStateAndBits
.byte $00 					;CurrentEntity_MiscRAM
.byte $00					;CurrentEntity_PipeDir
.byte SidestepperXMovementData_Start		;CurrentEntity_XSpeedTableOffset
.byte $00					;CurrentEntity_XSpeedTableEntry
.byte $01					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_XSpeedAlterTimer
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.byte $00,$00					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi (has no effect on anything other than players and reflecting fireballs)
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $05,$06					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;fighterfly values
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte $00					;CurrentEntity_MovementBits
.byte $03					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte FighterflyMovementAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x16_FlickerTop		;CurrentEntity_DrawMode
.byte GFX_Fighterfly_Move1			;CurrentEntity_DrawTile
.byte OAMProp_Palette0|OAMProp_BGPriority	;CurrentEntity_TileProps
.byte $28					;CurrentEntity_YPos
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte $00					;CurrentEntity_OAMOffset (overwritten afterwards)
.byte FighterflyPalettes_Start			;CurrentEntity_PaletteOffset
.word DATA_F64C					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_Fighterfly			;CurrentEntity_ID

.byte $00					;CurrentEntity_BumpedStateAndBits
.byte $00 					;CurrentEntity_MiscRAM
.byte $00					;CurrentEntity_PipeDir
.byte $00					;CurrentEntity_XSpeedTableOffset (Fighterfly does not use the same x-movement handling as others, so it has no effect)
.byte $00					;CurrentEntity_XSpeedTableEntry
.byte $01					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_XSpeedAlterTimer
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.byte $00,$00					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi (has no effect on anything other than players)
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $05,$06					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;Holds frames for various animations for various entities (CurrentEntity_DrawTile values)
;FF is used to loop back to specified index (the byte right next to it)

EntityMovementAnimations_F4B2:

PlayerRunningAnimCycle:
;Player Running
.byte GFX_Player_Walk1
.byte GFX_Player_Walk2
.byte GFX_Player_Walk3
.byte GFX_Player_Walk2
.byte $FF
.byte PlayerRunningAnimCycle_Start

;Player Skidding
PlayerSkiddingAnimCycle:
.byte GFX_Player_Skid1
.byte GFX_Player_Skid2
.byte $FF
.byte PlayerSkiddingAnimCycle_Start

;Shellcreeper Movement
ShellcreeperWalkAnimCycle:
.byte GFX_Shellcreeper_Walk1
.byte GFX_Shellcreeper_Walk2
.byte GFX_Shellcreeper_Walk1
.byte GFX_Shellcreeper_Walk3
.byte $FF
.byte ShellcreeperWalkAnimCycle_Start

;Sidestepper Movement
SidestepperWalkAnimCycle:
.byte GFX_Sidestepper_Move1
.byte GFX_Sidestepper_Move1
.byte GFX_Sidestepper_Move2
.byte GFX_Sidestepper_Move2
.byte GFX_Sidestepper_Move1
.byte GFX_Sidestepper_Move1
.byte GFX_Sidestepper_Move3
.byte GFX_Sidestepper_Move3
.byte $FF
.byte SidestepperWalkAnimCycle_Start

;Sidestepper Movement (hit once)
SidestepperAngryWalkAnimCycle:
.byte GFX_Sidestepper_AngryMove1				;GFX_AnimationCycle_SidestepperAngry = $1A
.byte GFX_Sidestepper_AngryMove1
.byte GFX_Sidestepper_AngryMove2
.byte GFX_Sidestepper_AngryMove2
.byte GFX_Sidestepper_AngryMove1
.byte GFX_Sidestepper_AngryMove1
.byte GFX_Sidestepper_AngryMove3
.byte GFX_Sidestepper_AngryMove3
.byte $FF
.byte SidestepperAngryWalkAnimCycle_Start

;Fighterfly Movement
FighterflyMovementAnimCycle:
.byte GFX_Fighterfly_Move1
.byte GFX_Fighterfly_Move1
.byte GFX_Fighterfly_Move2
.byte GFX_Fighterfly_Move2
.byte GFX_Fighterfly_Move3
.byte GFX_Fighterfly_Move3
.byte $FF
.byte FighterflyMovementAnimCycle_Start

;Coin
CoinSpinningAnimCycle:
.byte GFX_Coin_Frame1
.byte GFX_Coin_Frame2
.byte GFX_Coin_Frame3
.byte GFX_Coin_Frame4
.byte GFX_Coin_Frame5
.byte $FF
.byte CoinSpinningAnimCycle_Start

;Freezie
FreezieMovementAnimCycle:
.byte GFX_Freezie_Move1
.byte GFX_Freezie_Move2
.byte GFX_Freezie_Move3
.byte $FF
.byte FreezieMovementAnimCycle_Start

;Splash (doesn't actually "move" but let's say, the H20 matter within does move, so it counts!!)
SplashAnimCycle:
.byte GFX_Splash_Frame1
.byte GFX_Splash_Frame2
.byte GFX_Splash_Frame3
.byte $FF
.byte SplashAnimCycle_Start

;Fireball
FireballMovementAnimCycle:
.byte GFX_Fireball_Move1
.byte GFX_Fireball_Move2
.byte GFX_Fireball_Move3
.byte GFX_Fireball_Move4
.byte $FF
.byte FireballMovementAnimCycle_Start

;pipes tiles and stuff

;top-left pipe
TEMP_Def .set VRAMLoc_TopPipeLeft+2

DATA_F4F5:
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $52,$51,$3C,$50

TEMP_Def .set VRAMLoc_TopPipeLeft+$20
.byte >TEMP_Def,<TEMP_Def
.byte $06
.byte $41,$57,$56,$55,$47,$54

TEMP_Def .set VRAMLoc_TopPipeLeft+$40
.byte >TEMP_Def,<TEMP_Def
.byte $06
.byte $46,$5C,$5B,$5A,$4C,$59

TEMP_Def .set VRAMLoc_TopPipeLeft+$60
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $49,$61,$49,$5F

;top-right pipe
TEMP_Def .set VRAMLoc_TopPipeRight

.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $39,$3C,$3A,$3B

TEMP_Def .set VRAMLoc_TopPipeRight+$20
.byte >TEMP_Def,<TEMP_Def
.byte $06
.byte $3D,$47,$3E,$3F,$40,$41

TEMP_Def .set VRAMLoc_TopPipeRight+$40
.byte >TEMP_Def,<TEMP_Def
.byte $06
.byte $42,$4C,$43,$44,$45,$46

TEMP_Def .set VRAMLoc_TopPipeRight+$62
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $48,$49,$4A,$4B

;bottom-left pipe

TEMP_Def .set VRAMLoc_BottomPipeLeft
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $41,$41,$41,$57

TEMP_Def .set VRAMLoc_BottomPipeLeft+$20
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $46,$46,$46,$5C

TEMP_Def .set VRAMLoc_BottomPipeLeft+$40
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $4B,$4B,$4B,$61

TEMP_Def .set VRAMLoc_BottomPipeRight
;bottom-right pipe
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $40,$41,$41,$41

TEMP_Def .set VRAMLoc_BottomPipeRight+$20
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $45,$46,$46,$46

TEMP_Def .set VRAMLoc_BottomPipeRight+$40
.byte >TEMP_Def,<TEMP_Def
.byte $04
.byte $4A,$4B,$4B,$4B
.byte VRAMWriteCommand_Stop

;POW Block update data
;used for buffered write.
;first byte is a number of rows and tiles in said rows (low nibble - amount of tiles, high nibble - rows)
DATA_F560:
.byte $22
.byte $24,$24
.byte $24,$24					;No POW block

.byte $22
.byte $FE,$FF
.byte $90,$91					;hit twice

.byte $22
.byte $FC,$FD
.byte $8E,$8F					;hit once

.byte $22
.byte $FA,$FB
.byte $8C,$8D					;full POW block

;VRAM locations for platform edges that can be bumped from below (so only 2x2 tiles instead of 3x2 are shown)
DATA_F574:
.word $212D
.word $21F7
.word $2203
.word $22AB

.word $2132
.word $21E8
.word $221C
.word $22B4

;pointers and values for entities' graphical display
;first pointer is for vertical speed when it gets bumped, second pointer is for flipped animation
DATA_F584:
.word DATA_F5AA
.word DATA_F5CA

.byte GFX_Shellcreeper_Flipped1,Entity_Draw_8x16_Shift
.byte GFX_Shellcreeper_Walk1,Entity_Draw_8x16_Shift

DATA_F58C:
.word DATA_F5AA
.word DATA_F5EA

;key frames for sidestepper and drawing mode
.byte GFX_Sidestepper_AngryMove1,Entity_Draw_8x16_FlickerTop
.byte GFX_Sidestepper_Move1,Entity_Draw_8x16_FlickerTop
.byte GFX_Sidestepper_Flipped1,Entity_Draw_8x16_FlickerBottom

DATA_F596:
.word DATA_F5BD
.word DATA_F608

.byte GFX_Fighterfly_Flipped1,Entity_Draw_8x16_FlickerBottom
.byte GFX_Fighterfly_Move1,Entity_Draw_8x16_FlickerTop

DATA_F59E:
.word FreezieDestructionAnimationData_F70F
.word $0000					;unused null pointer (freezie cannot be flipped)

.byte GFX_Freezie_Destroyed1,Entity_Draw_8x16_FlickerBottom

DATA_F5A4:
.word CoinPickupAnimationData_F6E8
.word $0000					;unused null pointer (coin cannot be flipped)

.byte GFX_CollectedCoin_Frame1,Entity_Draw_8x8

;bounce y-speed for shellcreeper and sidestepper (flows into the table right after)
DATA_F5AA:
.if Version <> PAL
  .byte $FD,$FE,$FE
.else
  .byte $FD,$FD,$FE
.endif

;bounce y-speed after getting bumped by the player (continuation for shellcreeper/sidestepper, and beginning for players)
DATA_F5AD:
.if Version <> PAL
  .byte $FE,$FE,$FF,$FF,$FF,$FE,$00,$FF
  .byte $00,$FE,$00,$FF,$00,$00,$00
.else
  .byte $FE,$FE,$FE,$FF,$FF,$00,$FF,$00
  .byte $FF,$00,$00
.endif
.byte $99					;stop

DATA_F5BD:
.if Version <> PAL
  .byte $FE,$FE,$FE,$FF,$FF,$FF,$00,$FF
  .byte $00,$FF,$00,$00
.else
  .byte $FD,$FE,$FE,$FF,$FF,$FF,$00,$FF
  .byte $00
.endif
.byte $99

;flipped animation table for shellcreeper, first byte is graphic frame and the second is how long it lasts
;$00 - cycle palette (to indicate that it's going to move faster)
DATA_F5CA:
.if Version <> PAL
  .byte GFX_Shellcreeper_Flipped1,$40		;un-flipping animation timings are different between regions
  .byte GFX_Shellcreeper_Flipped2,$40
  .byte GFX_Shellcreeper_Flipped1,$40
  .byte GFX_Shellcreeper_Flipped2,$30
  .byte GFX_Shellcreeper_Flipped1,$30
  .byte GFX_Shellcreeper_Flipped2,$20
  .byte GFX_Shellcreeper_Flipped1,$20
  .byte GFX_Shellcreeper_Flipped2,$20
  .byte GFX_Shellcreeper_Flipped1,$20
  .byte GFX_Shellcreeper_Flipped2,$18
  .byte GFX_Shellcreeper_Flipped1,$10
  .byte $00
  .byte GFX_Shellcreeper_Flipped2,$10
  .byte GFX_Shellcreeper_Flipped1,$10
  .byte GFX_Shellcreeper_Flipped2,$08
  .byte GFX_Shellcreeper_Flipped1,$08
.else
  .byte GFX_Shellcreeper_Flipped1,$35
  .byte GFX_Shellcreeper_Flipped2,$35
  .byte GFX_Shellcreeper_Flipped1,$35
  .byte GFX_Shellcreeper_Flipped2,$28
  .byte GFX_Shellcreeper_Flipped1,$28
  .byte GFX_Shellcreeper_Flipped2,$1A
  .byte GFX_Shellcreeper_Flipped1,$1A
  .byte GFX_Shellcreeper_Flipped2,$1A
  .byte GFX_Shellcreeper_Flipped1,$1A
  .byte GFX_Shellcreeper_Flipped2,$14
  .byte GFX_Shellcreeper_Flipped1,$0D
  .byte $00
  .byte GFX_Shellcreeper_Flipped2,$0E
  .byte GFX_Shellcreeper_Flipped1,$0E
  .byte GFX_Shellcreeper_Flipped2,$08
  .byte GFX_Shellcreeper_Flipped1,$08
.endif
.byte $FF


;flipped animation table for sidestepper
DATA_F5EA:
.if Version <> PAL
  .byte GFX_Sidestepper_Flipped1,$40
  .byte GFX_Sidestepper_Flipped2,$40
  .byte GFX_Sidestepper_Flipped1,$40
  .byte GFX_Sidestepper_Flipped2,$30
  .byte GFX_Sidestepper_Flipped1,$30
  .byte GFX_Sidestepper_Flipped2,$20
  .byte GFX_Sidestepper_Flipped1,$20
  .byte GFX_Sidestepper_Flipped2,$20
  .byte GFX_Sidestepper_Flipped1,$18
  .byte GFX_Sidestepper_Flipped2,$10
  .byte $00
  .byte GFX_Sidestepper_Flipped1,$10
  .byte GFX_Sidestepper_Flipped2,$08
  .byte GFX_Sidestepper_Flipped1,$08
  .byte GFX_Sidestepper_Flipped2,$08
.else
  .byte GFX_Sidestepper_Flipped1,$35
  .byte GFX_Sidestepper_Flipped2,$35
  .byte GFX_Sidestepper_Flipped1,$35
  .byte GFX_Sidestepper_Flipped2,$28
  .byte GFX_Sidestepper_Flipped1,$28
  .byte GFX_Sidestepper_Flipped2,$1A
  .byte GFX_Sidestepper_Flipped1,$1A
  .byte GFX_Sidestepper_Flipped2,$1A
  .byte GFX_Sidestepper_Flipped1,$14
  .byte GFX_Sidestepper_Flipped2,$0D
  .byte $00
  .byte GFX_Sidestepper_Flipped1,$0E
  .byte GFX_Sidestepper_Flipped2,$08
  .byte GFX_Sidestepper_Flipped1,$08
  .byte GFX_Sidestepper_Flipped2,$08
.endif
.byte $FF

;flipped animation table for fighterfly
DATA_F608:
.if Version <> PAL
  .byte GFX_Fighterfly_Flipped1,$60
  .byte GFX_Fighterfly_Flipped2,$40
  .byte GFX_Fighterfly_Flipped1,$30
  .byte GFX_Fighterfly_Flipped2,$20
  .byte GFX_Fighterfly_Flipped1,$20
  .byte GFX_Fighterfly_Flipped2,$18
  .byte GFX_Fighterfly_Flipped1,$18
  .byte GFX_Fighterfly_Flipped2,$10
  .byte GFX_Fighterfly_Flipped1,$10
  .byte $00
  .byte GFX_Fighterfly_Flipped2,$08
  .byte GFX_Fighterfly_Flipped1,$08
  .byte GFX_Fighterfly_Flipped2,$08
  .byte GFX_Fighterfly_Flipped1,$08
  .byte GFX_Fighterfly_Flipped2,$04
.else
  .byte GFX_Fighterfly_Flipped1,$50
  .byte GFX_Fighterfly_Flipped2,$35
  .byte GFX_Fighterfly_Flipped1,$28
  .byte GFX_Fighterfly_Flipped2,$1A
  .byte GFX_Fighterfly_Flipped1,$1A
  .byte GFX_Fighterfly_Flipped2,$14
  .byte GFX_Fighterfly_Flipped1,$14
  .byte GFX_Fighterfly_Flipped2,$0E
  .byte GFX_Fighterfly_Flipped1,$0E
  .byte $00
  .byte GFX_Fighterfly_Flipped2,$08
  .byte GFX_Fighterfly_Flipped1,$08
  .byte GFX_Fighterfly_Flipped2,$08
  .byte GFX_Fighterfly_Flipped1,$08
  .byte GFX_Fighterfly_Flipped2,$04
.endif
.byte $FF

;turning animation for shellcreeper. $01 - flip the image, $FF - end turning
DATA_F626:
.byte GFX_Shellcreeper_Turning
.byte GFX_Shellcreeper_Turning
.byte GFX_Shellcreeper_Turning
.byte GFX_Shellcreeper_Turning
.byte $01
.byte GFX_Shellcreeper_Turning
.byte GFX_Shellcreeper_Turning
.byte GFX_Shellcreeper_Turning
.byte $FF

;same for sidesteppers
.byte GFX_Sidestepper_Turning
.byte GFX_Sidestepper_Turning
.byte GFX_Sidestepper_Turning
.byte GFX_Sidestepper_Turning
.byte $01
.byte GFX_Sidestepper_Turning
.byte GFX_Sidestepper_Turning
.byte GFX_Sidestepper_Turning
.byte $FF              

;enemy palettes to indicate faster movement speed
EnemyPalettes_F638:
ShellcreeperPalettes:
.byte OAMProp_Palette1,OAMProp_Palette2,OAMProp_Palette3,$FF ;shellcreeper palettes

SidestepperPalettes:
.byte OAMProp_Palette2,OAMProp_Palette1,OAMProp_Palette3,$FF ;sidestepper palettes

FighterflyPalettes:
.byte OAMProp_Palette0,OAMProp_Palette3,$FF ;fighterfly palettes

DATA_F643:
.byte $FB,$FB,$FD,$FE,$FE,$FF,$FF,$FF
.byte $FF

DATA_F64C:
.byte $AA

;gravity after coming out of pipe?
DATA_F64D:
.byte $F7,$F8,$FA,$FB,$FC,$FD,$FE,$FE
.byte $FE,$FE,$FE,$FF,$FF,$00,$FF,$00
.byte $00,$FF,$AA

;this is used for HUD (player 1 and TOP prefixes)
DATA_F660:
.byte $20,$63
.byte $01				;1 tile
.byte $2A				;I- (first player score)

.byte $20,$6B
.byte $03
.byte $2B,$2C,$2D			;TOP-
.byte VRAMWriteCommand_Stop		;stop

;this is also for HUD, for player 2, if applicable
DATA_F66B:
.byte $20,$75
.byte $02
.byte $29,$2A				;II-
.byte VRAMWriteCommand_Stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;InitLivesData_F671 (DATA_F671) - Life display OAM data
;Format:
;Byte 1 - Y-position
;Byte 2 - Sprite tile to display
;Byte 3 - Tile property
;Byte 4 - X-position
;Do note however that Y-position value is overwritten afterwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

InitLivesData_F671:
.byte $F4,Lives_Tile,$00,$40				;\
.byte $F4,Lives_Tile,$00,$4C				;|mario lives
.byte $F4,Lives_Tile,$00,$58				;/
.byte $F4,Lives_Tile,$01,$A8				;\
.byte $F4,Lives_Tile,$01,$B4				;|luigi lives
.byte $F4,Lives_Tile,$01,$C0				;/

;Title screen cursor OAM data, same format as above, Y-position is also overwritten.
DATA_F689:
.byte $F4,Cursor_Tile,$00,Cursor_XPos

;VRAM locations for score counters
ScoreVRAMUpdData_F68D:
.byte >VRAMLoc_TOPScore,<VRAMLoc_TOPScore
.byte $06						;oh, and length ofc
.byte $00

.byte >VRAMLoc_Player1Score,<VRAMLoc_Player1Score
.byte $06
.byte $00

.byte >VRAMLoc_Player2Score,<VRAMLoc_Player2Score
.byte $06
.byte $00

;initial values for respawn platforms
DATA_F699:
.byte $10,RespawnPlatform_Tile1,$03,$6C			;\mario's platform
.byte $10,RespawnPlatform_Tile1,$43,$73			;/
.byte $10,RespawnPlatform_Tile1,$03,$84			;\luigi's platform
.byte $10,RespawnPlatform_Tile1,$43,$8B			;/

;for bouncing upon death
PlayerDeathYSpeeds_F6A9:
.byte $FD,$FE,$FE,$FE,$FF,$FF,$00,$FF
.byte $00,$FF,$00,$FF,$00,$00,$00,$00
.byte $00,$00,$01,$00,$01,$00,$01,$00
.byte $01,$01,$02,$02,$02,$03,$AA

DATA_F6C8:
.byte $01					;CurrentEntity_ActiveFlag (obviously active)
.byte $00					;CurrentEntity_MovementBits
.byte $02					;CurrentEntity_TimerStorage
.byte $00					;CurrentEntity_UpdateTimer
.byte CoinSpinningAnimCycle_Start		;CurrentEntity_AnimationPointer
.byte Entity_Draw_8x16				;CurrentEntity_DrawMode
.byte GFX_Coin_Frame1				;CurrentEntity_DrawTile
.byte OAMProp_Palette2|OAMProp_BGPriority	;CurrentEntity_TileProps (the coin is coming out of the pipe... you know how it goes)
.byte $00					;CurrentEntity_YPos (overwritten afterwards)
.byte $00					;CurrentEntity_XPos (overwritten afterwards)
.byte $00					;CurrentEntity_OAMOffset (overwritten afterwards)
.byte $00					;CurrentEntity_PaletteOffset (does not affect coin)
.word DATA_F64C					;CurrentEntity_UpdateDataPointer (null by default)
.byte $00					;CurrentEntity_CurrentPlatform
.byte Entity_ID_Coin				;CurrentEntity_ID

.byte $00					;CurrentEntity_BumpedStateAndBits
.byte $01 					;CurrentEntity_MiscRAM
.byte $00					;CurrentEntity_PipeDir
.byte CoinXMovementData_Start			;CurrentEntity_XSpeedTableOffset
.byte $02					;CurrentEntity_XSpeedTableEntry
.byte $01					;CurrentEntity_XSpeed
.byte $00					;CurrentEntity_XSpeedAlterTimer
.byte $00					;CurrentEntity_XSpeedModifier
.byte $00					;CurrentEntity_TurningCounter
.byte $00					;CurrentEntity_DefeatedState
.byte $00,$00					;CurrentEntity_Player_VRAMPosLo/CurrentEntity_Player_VRAMPosHi (has no effect on anything other than players)
.byte $00					;CurrentEntity_WhichPlayerInteracted
.byte $00					;CurrentEntity_TileAtBottomVRAMPos
.byte $04,$03					;CurrentEntity_HitBoxHeight/CurrentEntity_HitBoxWidth

;used to animate unique defeats (coin & freezie)
;$CC - change CurrentEntity_DrawMode value with the next byte being input
;$DD - change CurrentEntity_DrawTile value with the next byte being input
;$EE - terminator
;other values represent y-speed during the animation
CoinPickupAnimationData_F6E8:
.byte $FE,$FE,$FE,$FF,$DD,GFX_CollectedCoin_Frame2
.byte $FF,$FF,$FF,$00,$DD,GFX_CollectedCoin_Frame3
.byte $FF,$FF,$00,$FF,$CC,Entity_Draw_16x16,$DD,GFX_CollectedCoin_Frame4
.byte $00,$00,$00,$00,$00,$00,$CC,Entity_Draw_8x16,$DD,GFX_CollectedCoin_Frame5
.byte $00,$00,$00,$00,$00,$00,$00,$00,$EE

FreezieDestructionAnimationData_F70F:
.byte $FE,$FE,$FE,$FF,$DD,GFX_Freezie_Destroyed2
.byte $FF,$FF,$FF,$00,$DD,GFX_Freezie_Destroyed3
.byte $00,$00,$00,$00,$00,$00,$EE

;some initial strings on phase load
DATA_F722:
PhaseString:
.byte $22,$4C
.byte @StringEnd-@StringStart
@StringStart:
	.byte "PHASE   "				;PHASE    (last 2 spaces are replaced with appropriate digits depending on phase number)
@StringEnd:

PEqualsString:
.byte $23,$41
.byte @StringEnd-@StringStart
@StringStart:
	.byte "P=  "					;P=   (same as above, spaces replaced with phase number digits)
@StringEnd:
.byte VRAMWriteCommand_Stop

;TEST YOUR SKILL string used when loading TEST YOUR SKILL! phase
DATA_F735:
.byte $21,$89
.byte @StringEnd-@StringStart
@StringStart:
	.byte "TEST YOUR SKILL"
@StringEnd:

;maybe make the rest follow the same "first size then tiles" convention
;then timer initialization
.byte $20,$8D
.byte $06
.byte $30,$31,$31,$31,$31,$32				;top border

.byte $20,$AD
.byte $06						;|20.0| (changes to 15.0 afterwads if in later TEST YOUR SKILL phases)
.byte $33,"20",DecimalSeparator,"0",$34

.byte $20,$CD
.byte $06
.byte $35,$36,$36,$36,$36,$37				;bottom border
.byte VRAMWriteCommand_Stop

;data for Freezie's platform freezing (replacing tiles, attributes)
;Middle platform
DATA_F763:
.byte $21,$EE
.byte VRAMWriteCommand_Repeat|$04
.byte $97

.byte $23,$DB
.byte $02
.byte $20,$80
.byte VRAMWriteCommand_Stop

DATA_F76D:
.byte $21,$EC
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $21,$F2
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $23,$DB
.byte $02
.byte $00,$00
.byte VRAMWriteCommand_Stop

DATA_F77B:
.byte $21,$EA
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $21,$F4
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $23,$DA
.byte $04
.byte $20,$00,$00,$80
.byte VRAMWriteCommand_Stop

DATA_F78B:
.byte $21,$E8
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $21,$F6
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $23,$DA
.byte $04
.byte $00,$00,$00,$00
.byte VRAMWriteCommand_Stop

DATA_F79B:
.byte $22,$A4
.byte VRAMWriteCommand_Repeat|$04
.byte $97

.byte $23,$E9
.byte $01
.byte $50

.byte VRAMWriteCommand_Stop

DATA_F7A4:
.byte $22,$A2
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $22,$A8
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $23,$E8
.byte $03
.byte $52,$00,$08

.byte VRAMWriteCommand_Stop

DATA_F7B3:
.byte $22,$A0
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $22,$AA
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $23,$E8
.byte $03
.byte $50,$00,$00
.byte VRAMWriteCommand_Stop

DATA_F7C2:
.byte $22,$B8
.byte VRAMWriteCommand_Repeat|$04
.byte $97

.byte $23,$EE
.byte $01
.byte $50
.byte VRAMWriteCommand_Stop

DATA_F7CB:
.byte $22,$B6
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $22,$BC
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $23,$ED
.byte $03
.byte $02,$00,$58

.byte VRAMWriteCommand_Stop

DATA_F7DA:
.byte $22,$B4
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $22,$BE
.byte VRAMWriteCommand_Repeat|$02
.byte $97

.byte $23,$ED
.byte $03
.byte $00,$00,$50
.byte VRAMWriteCommand_Stop

;x and y speed values for enemies that have been kicked by the player for each frame
;first byte is y-speed, second is x-speed
KickedEnemyXAndYSpeeds_F7E9:
.byte $00,$03
.byte $FF,$03
.byte $00,$03
.byte $00,$03
.byte $FF,$03
.byte $01,$03
.byte $01,$03
.byte $00,$03
.byte $01,$03
.byte $02,$03
.byte $02,$03
.byte $02,$02
.byte $02,$02
.byte $03,$02
.byte $03,$02
.byte $03,$02
.byte $03,$01
.byte $03,$01
.byte $03,$01
.byte $03,$01
.byte $04,$00
.byte $04,$01
.byte $04,$00
.byte $04,$01
.byte $04,$01
.byte $AA    				;will just fall down from now on       

DATA_F81C:
.byte $00,$01,$02,$02,$01,$00,$AA

;this table contains movement for Mario for demo mode. consists of pairs that are input and time for said input to be held.
Player1DemoInputs_F823:
.if Version <> PAL
  .byte $00,$5C
  .byte Input_Right,$50
  .byte $00,$10
  .byte Input_Left,$14
  .byte Input_Left|Input_A,$40
  .byte $00,$10
  .byte Input_Right,$28
  .byte $00,$50
  .byte Input_A,$40
  .byte Input_Left,$28
  .byte $00,$14
  .byte Input_Right,$10
  .byte Input_Right|Input_A,$40
  .byte $00,$48
  .byte Input_Right,$30
  .byte Input_Right|Input_A,$30
  .byte Input_Right,$10
  .byte $00,$10
  .byte Input_Left,$45
  .byte Input_Left|Input_A,$40
  .byte Input_Left,$20
  .byte $00,$08
  .byte Input_Right,$40
  .byte Input_Right|Input_A,$40
.else
  .byte $00,$70					;the demo movie plays a bit differently compared to an NTSC version (the inputs are different + all the timing and speed differences from before)
  .byte Input_Right,$38
  .byte $00,$10
  .byte Input_Left,$18
  .byte Input_Left|Input_A,$01
  .byte Input_Right,$38
  .byte Input_A,$60
  .byte Input_A,$48
  .byte Input_Left,$0E
  .byte Input_Left|Input_A,$40
  .byte $00,$10
  .byte Input_Right,$10
  .byte Input_Right|Input_A,$58
  .byte $00,$40
  .byte Input_A,$30
  .byte Input_A,$20
  .byte Input_Right,$20
  .byte Input_Left,$88
  .byte Input_Right,$20
  .byte Input_A,$40
  .byte Input_Left,$60
  .byte Input_Left|Input_A,$30
  .byte Input_Right,$50
  .byte Input_Right|Input_A,$80
.endif

.byte Demo_EndCommand

;same as above but for Luigi.
DATA_F854:
.if Version <> PAL
  .byte $00,$30
  .byte Input_Left,$50
  .byte $00,$10
  .byte Input_Right,$18
  .byte Input_Right|Input_A,$30
  .byte Input_Right|Input_A,$18
  .byte $00,$10
  .byte Input_Left,$24
  .byte Input_Left|Input_A,$60
  .byte Input_Left|Input_A,$40
  .byte $00,$08
  .byte Input_Right,$24
  .byte Input_Right|Input_A,$40
  .byte $00,$18
  .byte Input_Left,$10
  .byte Input_Left|Input_A,$40
  .byte $00,$40
  .byte Input_Right,$60
  .byte $00,$50
  .byte Input_Right,$FF
.else
  .byte $00,$A0					;Luigi's demo inputs also get hit by PAL-region stick
  .byte Input_Left,$38
  .byte Input_Right,$20
  .byte Input_Right|Input_A,$40
  .byte $00,$20
  .byte Input_Left,$10
  .byte Input_Left|Input_A,$39
  .byte Input_Left|Input_A,$20
  .byte $00,$30
  .byte Input_Left,$08
  .byte Input_Left|Input_A,$40
  .byte Input_A,$90
  .byte Input_Left,$20
  .byte Input_Right,$30
  .byte Input_Right|Input_A,$50
  .byte $00,$50
  .byte Input_Right,$B8
  .byte Input_Right|Input_A,$80
  .byte $00,$50
  .byte Input_Right,$FF
.endif

;Freespace from here on. 43 bytes in NTSC (and Gamecube, obviously) version, PAL version leaves only 7 bytes.

.segment "SOUND"				;sound engine goes here (specific address can be found in LinkerConfiguration.cfg).

SoundEngine_F8A7:
   NOP						;\and a bunch of NOPs that are here just because...?
   NOP						;|
   NOP						;|
   NOP						;|
   NOP						;|
   NOP						;|
   NOP						;/
   LDA #$C0					;\
   STA APU_FrameCounter				;/set APU frame counter to 4-step sequence and clear frame interrupt flag
   JSR CODE_FA91				;play sound effects and music and stuff

   LDA #$00					;\clear sound effect triggers
   STA Sound_Effect2				;|
   STA Sound_Effect				;|
   STA Sound_Jingle				;|
   STA $4011					;/and DMC load counter
   RTS						;

CODE_F8C2:
   LDX #$90
   BNE CODE_F8CB

CODE_F8C6:   
   LDY #$7F 

CODE_F8C8:   
   STY $4001
   
CODE_F8CB:
   STX $4000                
   RTS                      

CODE_F8CF:
   STX $F1                  
   STY $F0                  
   BNE CODE_F8D8
   
CODE_F8D5:
   JSR CODE_F8C8                
   
CODE_F8D8:
   LDX #$00					;timer for pulse 1

;used to set channel timer something
CODE_F8DA:
   TAY						;
   LDA DATA_F900+1,y				;
   BEQ CODE_F8EB
   STA $4002,x
   LDA DATA_F900,y
   ORA #$08
   STA $4003,x
   
CODE_F8EB:
   RTS
   
CODE_F8EC:
   JSR CODE_F96D
   
CODE_F8EF:
   LDX #$04					;timer for pulse 2
   BNE CODE_F8DA

CODE_F8F3:   
   TXA                      
   AND #$3E                 
   LDX #$08					;timer for triangle
   BNE CODE_F8DA

DATA_F8FA:
.byte $85,$85,$85,$8D,$8D,$8D

DATA_F900:
.byte $01
.byte $C4,$00,$00,$00,$69,$00,$D4
.byte $00,$C8,$00,$BD,$00,$B2,$00
.byte $A8,$00,$9F,$00,$8D,$00,$85
.byte $00,$7E,$00,$76,$00,$70,$01
.byte $AB,$01,$7C,$01,$67,$01,$52
.byte $01,$3F,$01,$1C,$01,$0C,$00
.byte $FD,$00,$EE,$00,$E1,$03,$57
.byte $02,$F9,$02,$A6,$02,$80,$02
.byte $3A,$02,$1A,$01,$FC,$01,$DF
.byte $06,$AE,$05,$F3,$05,$4D,$05
.byte $01,$04,$75,$03,$89,$00,$53

DATA_F94E:
.byte $03,$07,$0E,$1C,$38,$15,$2A
.byte $04,$08,$10,$20,$40,$18,$30
.byte $06,$05,$0A,$14,$28,$50,$1E
.byte $3C,$04,$0B,$16,$2C,$58,$21
.byte $07

CODE_F96B:
   LDY #$7F

CODE_F96D:  
   STX $4004                
   STY $4005                
   RTS

;Y into A, shift right 5 times
CODE_F974:
   TYA						;
   LSR A					;
   LSR A					;
   LSR A					;

;shift right 2 tiles
CODE_F978:
   LSR A					;

;shift right 1 time
CODE_F979:
   LSR A					;
   STA $00					;

;base value from Y minus the shifted value
   TYA						;
   SEC						;
   SBC $00					;
   RTS						;

CODE_F981:
   TAX                      
   ROR A                    
   TXA                      
   ROL A                    
   ROL A                    
   ROL A

CODE_F987:   
   AND #$07                 
   CLC                      
   ADC $068D                
   TAY                      
   LDA DATA_F94E,Y              
   RTS
   
DATA_F992:
.byte $8C,$84,$83,$8D,$8D,$83,$83,$8B
.byte $8C,$83,$8B

DATA_F99D:
.byte $8C,$8A,$8A,$8B,$8B

CODE_F9A2:
   STY $F0
   
   LDA #$85
   STA $F1
   
   LDA #$FE
   STA $F2
   
   LDX #$84                 
   LDY #$8A         
   LDA #$2A                 
   JSR CODE_F8D5
 
 CODE_F9B5:
   DEC $F1
   
   LDA $F1                  
   BNE CODE_F9BE                
   JMP CODE_FAEF
  
CODE_F9BE:
   CMP #$40                 
   BEQ CODE_F9DD                
   BCC CODE_F9E3                
   CMP #$78                 
   BCC CODE_F9D8                
   LSR A                    
   BCS CODE_FA1B
   
   LDA $F2                  
   TAY                      
   JSR CODE_F978                
   STA $F2                  
   STA $4002                
   BNE CODE_FA1B
  
CODE_F9D8:
   JSR CODE_F8C2                
   BNE CODE_FA1B
  
CODE_F9DD:
   LDA #$35                 
   STA $F2                  
   BNE CODE_F9F2
  
CODE_F9E3:
   LDX #$9C                 
   CMP #$18                 
   BCS CODE_F9ED                
   LSR A                    
   ORA #$90                 
   TAX
   
CODE_F9ED:
   DEC $06B7                
   BNE CODE_FA11

CODE_F9F2:  
   LDA #$04                 
   STA $06B7
   
   LDA $F2                  
   LSR A                    
   LSR A                    
   LSR A                    
   LSR A                    
   SEC                      
   ADC $F2                  
   STA $F2   
   ASL A                    
   ASL A                    
   STA $4002
   
   LDA $F2                  
   ROL A                    
   ROL A                    
   ROL A                    
   AND #$03                 
   STA $4003
  
CODE_FA11:
   LDY $06B7                
   LDA DATA_F99D,Y              
   TAY                      
   JSR CODE_F8C8
  
CODE_FA1B:
   JMP CODE_FD27
   
CODE_FA1E:
   STY $F0
   LDA #$14                 
   STA $F1                  
   LDX #$85                 
   LDY #$85                 
   LDA #$30                 
   JSR CODE_F8D5                

CODE_FA2D:
   LDA $F1
   CMP #$0D
   BNE CODE_FA38
   
   LDA #$30
   JSR CODE_F8D8

CODE_FA38:
   JMP CODE_FAEB
   
CODE_FA3B:
   LDX #$6E
   LDA #$12
   JSR CODE_F8CF
   BNE CODE_FA5B
   
CODE_FA44:
   LDA $F1
   CMP #$50
   BCS CODE_FA5F
   CMP #$46
   BCS CODE_FA71
   CMP #$37
   BCS CODE_FA5F
   BCC CODE_FA71
   
CODE_FA54:
   LDX #$1E
   LDA #$06
   JSR CODE_F8CF
   
CODE_FA5B:
   LDA #$06
   STA $F2
   
CODE_FA5F:
   LDX $F2
   
   LDY DATA_F992-1,x
   BNE CODE_FA76
   
CODE_FA66:
   LDX #$10
   LDA #$22
   
   JSR CODE_F8CF
   
   LDA #$06
   STA $F2
   
CODE_FA71:
   LDX $F2
   LDY DATA_F992+5,x
   
CODE_FA76:
   DEC $F2
   BNE CODE_FA7E
   
   LDA #$06
   STA $F2
   
CODE_FA7E:
   LDX #$9A
   LDA $F1
   CMP #$0A
   BCS CODE_FAE8
   BCC CODE_FAE5
   
CODE_FA88:
   JMP CODE_F9A2
   
CODE_FA8B:
   JMP CODE_F9B5
   
CODE_FA8E:
   JMP CODE_FA1E

CODE_FA91:
   LDA $FA					;check Sound_Effect2 first
   BNE CODE_FAD1				;

   LDY Sound_Effect2				;Sound_Effect2 into Y in case we init playing the sound
   LDA $F0					;Sound_Effect2 that is currently playing
   LSR A					;
   BCS CODE_FA8B				;continue playing Sound_Effect2_PlayerDead

   LSR Sound_Effect2				;
   BCS CODE_FA88				;init sound Sound_Effect2_PlayerDead

   LSR A					;
   BCS CODE_FA2D				;continue playing Sound_Effect2_POWBump

   LSR Sound_Effect2				;
   BCS CODE_FA8E				;init sound Sound_Effect2_POWBump

   LSR A					;
   BCS CODE_FA44				;continue playing Sound_Effect2_LastEnemyDead

   LSR Sound_Effect2				;
   BCS CODE_FA3B				;init Sound_Effect2_LastEnemyDead

   LSR Sound_Effect2				;
   BCS CODE_FA54				;init Sound_Effect2_EnemyKicked (since it's before "continue playing Sound_Effect2_EnemyKicked", it can interrupt the sound effect and restart playing it)

   LSR A					;
   BCS CODE_FA5F				;continue playing Sound_Effect2_EnemyKicked

   LSR A					;
   BCS CODE_FA71				;continue playing Sound_Effect2_EnemyHit

   LSR Sound_Effect2				;
   BCS CODE_FA66				;init Sound_Effect2_EnemyHit

   LSR A					;
   BCS CODE_FADB				;continue playing Sound_Effect2_Jump

   LSR Sound_Effect2				;
   BCS CODE_FAD4				;init sound Sound_Effect2_Jump

   LSR A					;
   BCS CODE_FAFF				;continue playing Sound_Effect2_Turning

   LSR Sound_Effect2				;
   BCS CODE_FAF8				;init sound Sound_Effect2_Turning

   LSR A					;
   BCS CODE_FB24				;continue playing Sound_Effect2_Step

   LSR Sound_Effect2				;
   BCS CODE_FB0F				;init sound Sound_Effect2_Step
   
CODE_FAD1:
   JMP CODE_FCC9				;
   
CODE_FAD4:
   LDX #$11
   LDA #$34
   JSR CODE_F8CF
   
CODE_FADB:
   LDA $F1
   LDY #$8C
   CMP #$08
   BCC CODE_FAE5

   LDA #$08
   
CODE_FAE5:
   ORA #$90
   TAX
   
CODE_FAE8:
   JSR CODE_F8C8
   
CODE_FAEB:
   DEC $F1
   BNE CODE_FAD1
   
CODE_FAEF:
   JSR CODE_F8C2

   LDA #$00
   STA $F0
   BEQ CODE_FAD1
   
CODE_FAF8:
   LDX #$09
   LDA #$04
   JSR CODE_F8CF
   
CODE_FAFF:
   LDY #$84
   
   LDA $F1
   CMP #$04                 
   BEQ CODE_FAEF                
   CMP #$08                 
   BCS CODE_FAE5
   
   LDY #$8B                 
   BNE CODE_FAE5
   
CODE_FB0F:
   STY $F0
   
   LDA #$05                 
   STA $F1

   INC Sound_Effect2_Step_Counter			;playing Step sound effect again, count that up
   LDA Sound_Effect2_Step_Counter			;
   AND #$07						;
   TAY							;
   LDA DATA_FB32,Y					;each different step is a different pulse
   JSR CODE_F8D8					;
   
CODE_FB24:
   LDA $F1                  
   LDY #$7F                 
   LDX #$90                 
   CMP #$04                 
   BCS CODE_FAE5
   
   LDA #$04                 
   BCC CODE_FAE8

;
DATA_FB32:
.byte $26,$22,$26,$22,$26,$22,$1C,$22

;something to do with freezie sound
DATA_FB3A:
.byte $83,$84,$82,$8E

CODE_FB3E:
   STY $FB
   
   LDA #$60                 
   STA $F3
   
   LDA #$19                 
   STA $F4

CODE_FB48:
   LDA $F3                  
   AND #$07                 
   BNE CODE_FB6C
   
   LDA $F4                  
   AND RandomNumberStorage			;sound effect and RNG? (i think this is freezy sound?)
   LSR A                    
   LSR A                    
   CLC                      
   ADC $F4
   BCS CODE_FB5C                
   STA $F4
  
CODE_FB5C:
   LDA $F4                  
   ROL A                    
   ROL A                    
   ROL A                    
   STA $4006

   ROL A                    
   AND #$07                 
   ORA #$08                 
   STA $4007

CODE_FB6C:
   LDA RandomNumberStorage			;freezie still?
   AND #$03                 
   LDA DATA_FB3A,Y              
   STA $4005                
   JMP CODE_FCA7

CODE_FB7A:
   STY $FB
   
   LDA #$28                 
   STA $F3
   
   LDA #$FE                 
   STA $F4
   
   JSR CODE_F96B                
   
CODE_FB87:
   LDY $F4                  
   LDA $F3                  
   AND #$03                 
   BEQ CODE_FB9A                
   CMP #$03                 
   BEQ CODE_FBA0                
   TYA                      
   JSR CODE_F979                
   TAY                      
   BNE CODE_FBA0
  
CODE_FB9A:
   TYA                      
   JSR CODE_F978                
   STA $F4

CODE_FBA0:  
   TYA                      
   CLC                      
   ROL A                    
   ROL A                    
   STA $4006                
   ROL A                    
   STA $4007                
   JMP CODE_FCA7
   
CODE_FBAE:
   STY $FB
   
   LDA #$1D                 
   STA $F3
   
   LDA #$08                 
   STA $F4
   
   LDA #$1A                 
   BNE CODE_FBC4
   
CODE_FBBC:
   LDA $F3                  
   CMP #$1A                 
   BNE CODE_FBC7
   
   LDA #$4C
  
CODE_FBC4:
   JSR CODE_F8EF
  
CODE_FBC7:
   LDX #$86                 
   DEC $F4                  
   BNE CODE_FBD3
   
   LDA #$04                 
   STA $F4                  
   LDX #$46
  
CODE_FBD3:
   JSR CODE_F96B                
   BNE CODE_FC38
   
CODE_FBD8:
   STY $FB                  
   LDA #$20                 
   STA $F3
   
   LDX #$46                 
   LDY #$BE                 
   LDA #$10                 
   BNE CODE_FC35

CODE_FBE6:   
   JMP CODE_FB3E
   
CODE_FBE9:
   JMP CODE_FB48                
  
CODE_FBEC:
   LDY $FE                  
   LDA $FB                  
   LSR A                    
   BCS CODE_FB87
   
   LSR $FE                  
   BCS CODE_FB7A                
   LSR $FE                  
   BCS CODE_FBAE                
   LSR A                    
   BCS CODE_FBBC                
   LSR A                    
   BCS CODE_FBE9                
   LSR $FE                  
   BCS CODE_FBE6                
   LSR $FE                  
   BCS CODE_FBD8                
   LSR A                    
   BCS CODE_FC38                
   LSR $FE                  
   BCS CODE_FC29                
   LSR A                    
   BCS CODE_FC38                
   LSR $FE                  
   BCS CODE_FC46                
   LSR A                    
   BCS CODE_FC38                
   LSR $FE                  
   BCS CODE_FC54                
   LSR A                    
   BCS CODE_FC5C                
   LSR $FE                  
   BCS CODE_FC79                
   LSR A                    
   BCS CODE_FC88                
   
CODE_FC28:
   RTS
   
CODE_FC29:
   STY $FB
   
   LDA #$18                 
   STA $F3

   LDX #$44                 
   LDY #$86                 
   LDA #$2A                 
 
CODE_FC35:
   JSR CODE_F8EC
   
CODE_FC38:
   DEC $F3                  
   BNE CODE_FC28
   
   LDA #$00                 
   STA $FB
   
   LDA #$10                 
   STA $4004                
   RTS                      
  
CODE_FC46:
   STY $FB
   
   LDA #$14                 
   STA $F3
   
   LDX #$A0                 
   LDY #$9D                 
   LDA #$34                 
   BNE CODE_FC35
   
CODE_FC54:
   STY $FB                  
   LDA #$2A                 
   STA $F3
   BNE CODE_FC60
   
CODE_FC5C:
   DEC $F4                  
   BNE CODE_FC69
  
CODE_FC60:
   LDA #$04                 
   JSR CODE_F8EF
   
   LDA #$06                 
   STA $F4
  
CODE_FC69:
   LDY $F4                  
   LDA DATA_F8FA-1,Y 				;load byte from table, that actually starts from legit opcode byte.
   TAY
   
   LDX #$88                 
   STX $4004                
   JSR CODE_F96D                
   BNE CODE_FC38
   
CODE_FC79:
   STY $FB
   
   LDA #$1C                 
   STA $F3
   
   LDA #$1C                 
   LDX #$95
   
   LDY #$95                 
   JSR CODE_F8EC
   
CODE_FC88:
   LDA $F3                  
   CMP #$17                 
   BCC CODE_FC95                
   BNE CODE_FC38
   
   LDA #$26                 
   JSR CODE_F8EF

CODE_FC95:  
   LDY #$97
   
   LDA $F3                  
   CMP #$0E                 
   BCS CODE_FCA1                
 
CODE_FC9D:
   LSR A                    
   ORA #$90                 
   TAY
   
CODE_FCA1:
   STY $4004                
   JMP CODE_FC38                
   
CODE_FCA7:
   LDY #$9A                 
   LDA $F3                  
   CMP #$14                 
   BCS CODE_FCA1                
   BCC CODE_FC9D

CODE_FCB1:
   LDA #$08					;hold triangle wave for this long
   STA Sound_Loop_Timer_Length			;

   LDA #$08					;length
   STA $4008					;

   LDA #Sound_Timer_BasePitch			;triangle pitch
   STA $400A					;

   LDA #$08					;frequency
   STA $400B					;

CODE_FCC4:
   DEC Sound_Loop_Timer_Length			;hold the same wave
   JMP CODE_FD27				;continue with jingle bussiness

CODE_FCC9:
   LDA $F9					;if this flag is set, move onto jingles
   BNE CODE_FD27				;

   LDA Sound_Loop				;check looping sounds
   LSR A					;bits 0 and 1 are unused
   LSR A					;

   LDX Sound_Loop_Timer_Length			;already playing a looping sound? (bonus phase timer to be specific)
   BNE CODE_FCC4				;

   LSR A					;
   BCS CODE_FCB1				;init Sound_Loop_Timer

   LSR A					;
   BCS CODE_FCE3				;init Sound_Loop_Fireball

   LDX Sound_Loop_Fireball_Length		;fireball note timer
   BNE CODE_FCF3				;init
   JMP CODE_FD27				;onto jingles

CODE_FCE3:
   LDA #$0E					;timer or length, whichever is more correct i dont know
   STA Sound_Loop_Fireball_Length		;

   LDA #Sound_Fireball_BasePitch		;base triangle pitch
   STA Sound_Loop_Fireball_Pitch		;

   LDA #$08					;triangle frequency
   STA $4008					;
   BNE CODE_FD0B				;

CODE_FCF3:
   DEC Sound_Loop_Fireball_Length		;

   LDA Sound_Loop_Fireball_Length		;check timer
   CMP #$08					;
   BCS CODE_FD0B				;for some time, it'll hold the same pitch

   LDY Sound_Loop_Fireball_Pitch		;the sound will now "vibrate" by changing its pitch
   JSR CODE_F974				;what actually happens is it hightens its base pitch every frame
   STA Sound_Loop_Fireball_Pitch		;then, depending on timer and RNG, the output will be higher pitch or lower

   LDA Sound_Loop_Fireball_Length		;bits 0 or 1 enabled
   AND #$03					;
   BEQ CODE_FD1A				;always low pitch

CODE_FD0B:
   LDA RandomNumberStorage			;different pitch depending on RNG
   LSR A					;
   BCC CODE_FD1A				;

   LDA Sound_Loop_Fireball_Pitch		;this will produce higher pitch sound
   CLC						;
   ROL A					;
   STA $400A					;
   BNE CODE_FD21				;

CODE_FD1A:
   LDA Sound_Loop_Fireball_Pitch		;this will produce lower pitch sound
   ROL A					;
   ROL A					;
   STA $400A					;

CODE_FD21:  
   ROL A					;length counter
   AND #$03					;
   STA $400B					;

;Loop sound over, perform sweet sweet jingles
CODE_FD27:
   LDA Sound_Jingle				;
   BNE CODE_FD33				;play jingle bells!

   LDA Sound_JinglePlayingFlag			;if the jingle is still playing, continue
   BNE CODE_FD78				;
   JMP CODE_FBEC				;otherwise play sound effects (they won't play during jingles)

CODE_FD33:
   LDY #$07					;

CODE_FD35:   
   ASL A					;get jingle bit
   BCS CODE_FD3B				;from highest to lowest
   DEY						;
   BNE CODE_FD35				;
  
CODE_FD3B:
   INC Sound_JinglePlayingFlag			;set flag to true
   STY Sound_CurrentJingleID			;

   LDA DATA_FE64,Y				;get offset for sounds first
   TAY						;
   
   LDA DATA_FE64,Y				;
   STA $068D					;
   
   LDA DATA_FE64+1,Y				;\note data pointer
   STA $F7					;|
						;|
   LDA DATA_FE64+2,Y				;|
   STA $F8					;/

   LDA DATA_FE64+3,Y
   STA $F9
   
   LDA DATA_FE64+4,Y              
   STA $FA
   
   LDA DATA_FE64+5,Y				;uhh, something???
   STA $0686					;seems to be only used for Sound_Jingle_TitleScreen
   
   LDA #$01                 
   STA $0695                
   STA $0696                
   STA $0698                
   STA $069A
   
   LDY #$00                 
   STY $0682
  
CODE_FD78:
   LDY $FA                  
   BEQ CODE_FDAF
   
   DEC $0696                
   BNE CODE_FDAF                
   INC $FA
   
   LDA ($F7),Y              
   BEQ CODE_FDBE                
   BPL CODE_FD95                
   JSR CODE_F987
   STA $0691

   LDY $FA                  
   INC $FA                  
   LDA ($F7),Y
  
CODE_FD95:
   JSR CODE_F8D8                
   BNE CODE_FD9E
   
   LDX #$10
   BNE CODE_FDA6
   
CODE_FD9E:
   LDX #$06                 
   LDA $F9                  
   BNE CODE_FDA6
   
   LDX #$86
  
CODE_FDA6:
   JSR CODE_F8C6                
   LDA $0691                
   STA $0696

CODE_FDAF:  
   DEC $0695                
   BNE CODE_FE02                
   LDY $0682                
   INC $0682

   LDA ($F7),Y              
   BNE CODE_FDDA
  
CODE_FDBE:
   JSR CODE_F8C2

;music over
   LDA #$00                 
   STA $FA                  
   STA $F9                  
   STA $F0                  
   STA $FB                  
   STA $06A2                
   STA $06C0					;
   STA $4008					;no more triangle
   
   LDA #$10					;constant volume for pulse
   STA $4004					;
   RTS
  
CODE_FDDA:
   JSR CODE_F981                
   STA $0695                
   TXA                      
   AND #$3E                 
   JSR CODE_F8EF                
   BEQ CODE_FE02
   
   LDX #$9F					;set pulse (square) constant max volume
   LDA Sound_CurrentJingleID			;
   BEQ CODE_FDFA				;check if current jingle is Sound_Jingle_GameStart, if so, skip over
   
   LDX #$87                 
   LDA $0695                
   CMP #$10                 
   BCS CODE_FDFA
   
   LDX #$84
  
CODE_FDFA:
   STX $4004
   
   LDA #$7F                 
   STA $4005                
   
CODE_FE02:
   LDY $F9                  
   BEQ CODE_FE2D                
   DEC $0698                
   BNE CODE_FE2D                
   INC $F9                  
   LDA ($F7),Y
   JSR CODE_F981
   STA $0698
   CLC                      
   ADC #$FE                 
   ASL A                    
   ASL A                    
   CMP #$38                 
   BCC CODE_FE20
   
   LDA #$38
  
CODE_FE20:
   LDY Sound_CurrentJingleID			;check if current jingle is Sound_Jingle_GameStart
   BNE CODE_FE27				;if not, set triangle channel value from above
   
   LDA #$FF					;max triangle settings

CODE_FE27:   
   STA $4008					;triangle stuff

   JSR CODE_F8F3
  
CODE_FE2D:
   LDA Sound_CurrentJingleID
   CMP #$07					;Sound_Jingle_TitleScreen>>4 ?
   BNE CODE_FE63

   DEC $069A                
   BNE CODE_FE63
   
   LDY $0686                
   INC $0686                
   LDA ($F7),Y              
   JSR CODE_F981                
   STA $069A                
   TXA                      
   AND #$3E                 
   BNE CODE_FE54
   
   LDA #$00                 
   LDX #$02                 
   LDY #$08                 
   BNE CODE_FE5A
  
CODE_FE54:
   LDA #$02                 
   LDX #$00                 
   LDY #$28

CODE_FE5A:  
   STA $400C                
   STX $400E                
   STY $400F

CODE_FE63:  
   RTS                      

DATA_FE64:
;first 8 bytes are offsets foreach Sound_Jingle entry
.byte $08,$0D,$12,$17,$1C,$21,$26,$2B

;if the format is the same as in SMB, it's as follows:
;1 byte - length byte offset
;2 bytes - sound data address
;1 byte - triangle data offset
;1 byte - square 1 data offset
;1 byte - square 2 data offset (only for title screen?)
.byte $0F,<DATA_FE95,>DATA_FE95,DATA_FEC5-DATA_FE95,$00
.byte $00,<DATA_FED1,>DATA_FED1,$00,DATA_FED9-DATA_FED1
.byte $00,<DATA_FEE6,>DATA_FEE6,DATA_FEF0-DATA_FEE6,$00
.byte $0F,<DATA_FEF3,>DATA_FEF3,$00,$00
.byte $07,<DATA_FEFC,>DATA_FEFC,DATA_FEFF-DATA_FEFC,$00
.byte $00,<DATA_FF0B,>DATA_FF0B,$00,$00
.byte $07,<DATA_FF0D,>DATA_FF0D,DATA_FF25-DATA_FF0D,$00
.byte $16,<DATA_FF44,>DATA_FF44,DATA_FF63-DATA_FF44,DATA_FF7C-DATA_FF44,DATA_FFC2-DATA_FF44

;$00 - stop command
DATA_FE95:
.byte $5D,$78,$5D,$78,$5C,$78,$5C,$62
.byte $E6,$65,$5E,$65,$5E,$64,$5E,$40
.byte $5E,$F8,$00

;Unused! a leftover from somewhere? maybe square sound? because with noise it doesnt sound good.
DATA_FEA8:
.byte $85,$06,$81,$26,$85,$06,$81,$26
.byte $06,$26,$06,$0E,$83,$12,$85,$10
.byte $81,$0A,$85,$10,$81,$0A,$10,$0A
.byte $2E,$0A,$83,$26,$00

DATA_FEC5:
.byte $5D,$78,$5D,$78,$1D,$5F,$40,$5F
.byte $40,$9E,$80,$F8

DATA_FED1:
.byte $6E,$6A,$A6,$A6,$A6,$AE,$07,$00

DATA_FED9:
.byte $82,$46,$38,$32,$4A,$48,$81,$40
.byte $42,$44,$48,$84,$30

DATA_FEE6:
.byte $66,$6E,$4A,$50,$52,$50,$4A,$6E
.byte $27,$00

DATA_FEF0:
.byte $E6,$DE,$39

DATA_FEF3:
.byte $04,$12,$04,$12,$04,$12,$04,$D2
.byte $00

DATA_FEFC:
.byte $83,$83,$00

DATA_FEFF:
.byte $46,$46,$4E,$52,$42,$4E,$12,$14
.byte $16,$18,$1A,$05

DATA_FF0B:
.byte $E6,$00

DATA_FF0D:
.byte $2E,$46,$02,$AE,$6A,$67,$28,$6A
.byte $02,$A6,$64,$63,$9E,$A4,$6A,$47
.byte $08,$4B,$02,$0C,$4F,$02,$07,$00

DATA_FF25:
.byte $86,$A6,$A2,$9C,$AA,$A2,$9C,$BC
.byte $9E,$BC,$B6,$B2,$26,$24,$26,$24
.byte $A6,$22,$1E,$22,$1E,$A2,$1C,$00
.byte $1C,$00,$1C,$00,$1C,$00,$1D

DATA_FF44:
.byte $47,$EA,$42,$66,$AA,$AC,$6A,$A6
.byte $47,$EA,$42,$66,$AA,$AC,$6A,$A6
.byte $6A,$AC,$86,$6C,$AA,$6C,$86,$8A
.byte $46,$4A,$4E,$D0,$D2,$11,$00

DATA_FF63:
.byte $77,$76,$F6,$5D,$5C,$DC,$77,$76
.byte $F6,$5D,$5C,$DC,$65,$64,$E4,$7F
.byte $7E,$FE,$BE,$B6,$9C,$B8,$A4,$9C
.byte $F6

DATA_FF7C:
.byte $82,$2A,$81,$36,$82,$24,$81,$1C
.byte $1E,$20,$22,$24,$1C,$26,$1C,$24
.byte $1C,$22,$82,$2A,$81,$36,$82,$24
.byte $81,$1C,$1E,$24,$22,$24,$1C,$26
.byte $1C,$24,$22,$1C,$24,$26,$1C,$2A
.byte $24,$26,$1C,$24,$26,$2A,$24,$2C
.byte $1E,$2A,$24,$2C,$0A,$2C,$06,$0A
.byte $0E,$06,$0A,$0E,$80,$2E,$86,$06
.byte $82,$3A,$81,$3C,$84,$36

DATA_FFC2:
.byte $40,$44,$44,$44,$40,$44,$40,$44
.byte $40,$44,$44,$44,$40,$44,$40,$44
.byte $40,$44,$44,$44,$40,$44,$40,$44
.byte $40,$44,$44,$44,$40,$44,$40,$44
.byte $40,$44,$44,$44,$40,$44,$44,$44
.byte $40,$44,$44,$44,$40,$44,$44,$84
.byte $84,$84,$84,$84,$44,$44,$44,$05

;NO freespace

.segment "VECTORS"
   .word NMI_C07D
   .word RESET_C000
   .word RESET_C000