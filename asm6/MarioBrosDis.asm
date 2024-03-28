;Mario Bros. (NES) Disassembly.
;not very well documented yet.
;But it's pretty much an accurate byte-to-byte MB. disassembly.
;
;Do note that information related with NES's architecture, PPU, APU, CPU and etc. may be incorrect, because i'm not good at understanding things. oops.
;All ROM labels are going to be renamed from generic CODE_XXXX (or DATA_XXXX) to some name that briefly states routine's function.
;Same goes for RAM addresses, to make it easy to understand on what specific address does in code.
;For now, enjoy my barebones disassembly.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.incsrc Defines.asm				;load all defines for RAM addresses

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.incsrc iNES_Header.asm

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
   
ResetLoop:
   STA ($00),y					;
   
   DEY						;
   BNE ResetLoop				;
   
   DEC $01					;
   BPL ResetLoop				;we set reset loop by setting high and low bytes for inderect adressing, and decrease high byte
   
   TXA						;if POW block is non-existant (hit three time)
   BNE CODE_C02B				;

   LDX #$5F					;start "RNG" loop at $5F

CODE_C02B:
   STX RandomNumberStorage			;otherwise it starts at 1, 2 or 3 depending on POW block state before reset
   
   JSR CODE_CA1B				;clear screen(s)
   JSR CODE_CA2B				;"clear" sprite data
   
   LDY #$00					;load 00 into Y register....
   STA VRAMRenderAreaReg			;\initial camera position/no scroll
   STA VRAMRenderAreaReg			;/

   INY						;\increase Y register... but I'm sure LDY #$01 could've worked just fine.
   STY DemoFlag					;/initially demo flag is set
   
   LDA #$0F					;\enable all sound channels (except for DMC)
   STA APU_SoundChannels			;/
   
   LDA #$90					;enable VBlank (NMI) and background
   STA ControlBits				;
   STA Reg2000BitStorage			;backup enabled bits
   
   LDA #$06					;Bits 1 and 2 to be enabled for 2001
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
   JSR CODE_F8A7				;sound engine of some sorts
   
CODE_C060:
   JSR CODE_CD88				;handle various timers
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
   JSR CODE_D328				;randomize numbers in the mean time
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
   
   JSR CODE_CB58				;checks acts-like?
   JSR CODE_EE6A				;handles freezie's platform freezing
   JSR CODE_CCFF            			;handles buffered tile drawing
   JSR CODE_CA66            			;handle palette
   JSR CODE_CE09            			;keep camera still
   JSR CODE_CCC5            			;handle controllers
   JSR CODE_CAF7    				;something to do with entities

   LDY #$01					;"Frame has passed" flag.
   STY FrameFlag				;

   DEY						;
   STY $42					;

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
;$B1 - controller inputs of player 1
;$10 - controller inputs of player 2
;$05F7 - direction bits from which interaction has occured. Format: UD----RL, U - up, D - down, L - left, R - right.
CODE_C0B6:
   LDA $B0					;if current entity (presumably Mario) isn't active, return 
   BEQ CODE_C0BF				;

   LDA $0320					;if luigi is active, check collision between brothers?
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
   STA $05F7					;store bits of side from which interaction occured
   ORA #$00					;ok?
   BEQ CODE_C149				;no interaction if zero

   LDA $C6					;if both bros are in normal state, contine checking
   ORA $0336					;
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
   
   LDA $0321					;button inputs by second player
   STA $10					;into $10
   AND #$C0					;check if it is A or B
   BNE CODE_C152				;meaning the player is performing a jump (probably)
   
   LDA $B1					;check if it's player 1 who pressed A or B
   AND #$C0					;
   BNE CODE_C14F				;kinda cancel that jump
   
   LDA $B1					;then check direction
   AND #$03					;
   BEQ CODE_C15E				;if player 1 isn't moving, k
   
   LDA $10					;check if player 2's also moving
   AND #$03					;
   BEQ CODE_C161				;no, he isn't
   
   JSR CODE_C3A0				;currently unknown
   
   LDA $10					;if both players have pressed left or right
   AND #$03					;(i think this is bumping into each other when moving)
   EOR $B1					;
   AND #$03					;
   BEQ CODE_C13E				;if not, player don't bump into each other, do pushing
   
   LDA $05F7					;
   AND #$0F					;
   CMP #$02					;check if collided from the right...
   BEQ CODE_C12E				;
   
   LDA $B1					;otherwise mario's on the left
   JMP CODE_C130				;check player 1 direction first
   
CODE_C12E:
   LDA $10					;check player 2 direction first
   
CODE_C130:
   LSR A					;check if direction pressed is right (?)
   BCC CODE_C149				;if not, return

   LDA $C4					;probably speed, maybe
   CMP $0334					;bumped into each other with the same speed
   BEQ CODE_C15B				;
   BCS CODE_C158				;if mario's speed was hight, different kind of bump
   BCC CODE_C155				;
   
CODE_C13E:
   LDA $0334					;
   CMP $C4					;
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
   LDA $B1					;
   ORA $0321					;
   AND #$04					;
   BNE CODE_C193				;i think this checks if both are grounded?

   LDX #$01
   LDY #$03
   
   LDA $B1
   AND #$03
   STA $1D
   
   LDA $05F7
   AND #$03
   CMP $1D
   BNE CODE_C189
   STX $C5
   STY $B3
   DEX
   STX $C4
   BEQ CODE_C193
   
CODE_C189:
   STX $0335					;x-speed
   STY $0323
   DEX
   STX $0334
   
CODE_C193:
   JMP CODE_C149

CODE_C196:
   JSR CODE_C3A0
   
   LDA $10
   AND #$C0
   BEQ CODE_C158

CODE_C19F:
   LDA $05F7
   ASL A
   BCS CODE_C1CE
   
   LDA $0328
   SEC
   SBC $B8
   CMP #$0B
   BCC CODE_C221
   
   LDA $B1					;
   AND #$03					;
   BNE CODE_C212				;
   
   LDA $10					;if player 2 while jumping hits player 1 who falls down
   AND #$03					;
   BNE CODE_C221				;do something
   
   LDA #$01
   ORA $B1
   STA $B1
   BNE CODE_C212
   
CODE_C1C3:
   JSR CODE_C3A0
   LDA $B1
   AND #$C0
   BEQ CODE_C155
   BNE CODE_C19F
   
CODE_C1CE:
   LDA $B8
   SEC
   SBC $0328
   CMP #$0B
   BCC CODE_C221
   
   LDA $10					;if player 1 while jumping hits player 2 who falls down
   AND #$03
   BNE CODE_C212
   
   LDA $B1
   AND #$03
   BNE CODE_C221
   
   LDA #$01
   ORA $10
   STA $10
   BNE CODE_C212
   
CODE_C1EC: 
   LDA $B1
   AND #$FC
   ORA $1F
   STA $0321
   
   LDA $10
   AND #$FC
   ORA $1E
   STA $B1

CODE_C1FD: 
   LDX $BC
   LDY $BD
   
   LDA $032C
   STA $BC
   
   LDA $032D
   STA $BD
   
   STX $032C
   STY $032D
   RTS

CODE_C212:
   LDA $B1
   AND #$03
   STA $1E
   
   LDA $10
   AND #$03
   STA $1F
   
   JMP CODE_C1EC
   
CODE_C221:
   LDA $B1
   STA $0321
   
   LDA $10
   STA $B1
   JMP CODE_C1FD
   
CODE_C22D:
   JSR CODE_C41F
   DEY
   BEQ CODE_C282
   DEY
   BEQ CODE_C23C
   
CODE_C236:
   LDX #$06
   LDY #$41
   BNE CODE_C286
   
CODE_C23C:
   LDA $B8
   CMP $0328
   BCS CODE_C24B
   
   LDA $05F7
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

   LDA $B1					;cant move!
   ORA #$08					;
   STA $B1					;

   LDA #$2F					;timer?
   STA $BB

   LDA $10
   AND #$43
   CMP #$40
   BNE CODE_C26E
   
   LDA #$01
   STA $10
   
CODE_C26E:
   LDA $10
   AND #$03
   ORA #$80
   STA $0321
   
   LDA #<DATA_F350				;$50
   LDY #>DATA_F350				;$F3
   
CODE_C27B:
   STA $032C
   STY $032D
   RTS
   
CODE_C282:					;if luigi touches mario from side while airborn
   LDX #$05					;make mario face left if applicable
   LDY #$42					;make luigi face right, keep gravity
   
CODE_C286:
   STY $0321					;
   
   LDA $B1					;if mario is playing "squishing" animation (?)
   AND #$08					;
   BNE CODE_C2A7				;don't push him
   
   STX $B1					;push a little to the right
   JSR CODE_C3E3				;
   
   LDA $C4					;
   STA $00					;
   
   LDA $CD					;
   STA $01					;
   
   JSR CODE_C3C2				;
   STA $C2					;
   
   LDA $00					;
   BEQ CODE_C2A7				;
   STA $B4
   
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
   LDX #$06                 
   LDY #$41                 
   BNE CODE_C308

CODE_C2BC:
   LDA $0328                
   CMP $B8                  
   BCS CODE_C2CB
   
   LDA $05F7                
   LSR A                    
   BCS CODE_C304 
   BCC CODE_C2B6

;play squishing animation (Luigi)
CODE_C2CB:
   LDA #Entity_Draw_16x16
   STA Entity_Luigi_DrawMode
   
   LDA Entity_Luigi_OAMOffset				;remove top 2 tiles
   JSR CODE_C3F5
   
   LDA #GFX_Player_Squish1
   STA Entity_Luigi_DrawTile
   
   LDA $10						;
   ORA #$08						;can't move
   STA $0321						;
   
   LDA #$2F                 
   STA $032B
   
   LDA $B1                  
   AND #$43                 
   CMP #$40                 
   BNE CODE_C2F3
	
   LDA #$01                 
   STA $B1    
 
 CODE_C2F3:
   LDA $B1                  
   AND #$03                 
   ORA #$80                 
   STA $B1     
   
   LDA #<DATA_F350				;$50                 
   LDY #>DATA_F350				;$F3

CODE_C2FF:   
   STA $BC 
   STY $BD                  
   RTS

CODE_C304:
   LDX #$05
   LDY #$42
   
CODE_C308:
   STY $B1

   LDA $0321
   AND #$08
   BNE CODE_C32E
   
   STX $0321
   
   JSR CODE_C3E3
   
   LDA $0334
   STA $00
   
   LDA $033D
   STA $01
   
   JSR CODE_C3C2
   STA $0332
   
   LDA $00
   BEQ CODE_C32E
   STA $0324
   
CODE_C32E:
   LDA #<DATA_F33A				;$3A
   LDY #>DATA_F33A				;$F3
   BNE CODE_C2FF
   
CODE_C334:
   LDA $B1					;enable "being" pushed state bit?
   ORA #$04					;this is swapping directions, as well?
   STA $0321					;this is for luigi
   
   LDA $10					;same for mario
   ORA #$04					;
   STA $B1					;
   
   LDA $C4					;save mario's X-speed
   STA $00					;
   
   LDA $CD					;i don't know what this is
   STA $01					;
   
   JSR CODE_C3C2				;

   STA $C2					;
   STA $0332					;
   
   LDA $00					;
   BEQ CODE_C35A				;
  
   STA $B4					;
   STA $0324					;
   
 CODE_C35A:
   RTS						;
   
CODE_C35B:
   JSR CODE_C41F
   
   LDA $10                  
   AND #$03                 
   DEY                      
   BEQ CODE_C376                
   CMP #$02                 
   BNE CODE_C37A

CODE_C369:
   LDA #$06                 
   STA $B4
   
   LDX #$10                 
   LDY #$0D              
   LDA $10   
   JMP CODE_C402

CODE_C376:
   CMP #$01                 
   BEQ CODE_C369

CODE_C37A:
   JMP CODE_C3A8

CODE_C37D:
   JSR CODE_C429				;check which side we're pushing from, i think

   LDA $B1					;horizontal direction
   AND #Entity_MovementBits_MovingRight|Entity_MovementBits_MovingLeft	;whew, ugly! (need to change to something shorter maybe)
   DEY						;
   BEQ CODE_C399				;
   CMP #Entity_MovementBits_MovingLeft		;
   BNE CODE_C39D				;

CODE_C38B:
   LDA #$06					;
   STA Entity_Luigi_AnimationPointer		;show luigi as skidding

   LDX #$0D					;movement timers
   LDY #$10					;luigi's longer
   LDA $B1					;
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
   LDY #$00					;i think this is speed related
   STY $C1					;dunno what dis is
   STY $0331					;could be unused for luigi and marios entities
   INY						;
   STY $05FF					;
   
   LDY $BB					;not really sure what this is. direction related?
   BNE CODE_C3B9				;not sure if this check is necessary. if it's zero, we store zero? (because of LDA before required to be zero)
   STA $BB					;

CODE_C3B9:
   LDY $032B					;same for luigi
   BNE CODE_C3C1				;
   STA $032B					;
   
CODE_C3C1:
   RTS						;
   
CODE_C3C2:
   LDA $01
   CMP #$97
   BEQ CODE_C3DC
   
   LDA $00
   CMP #$02
   BNE CODE_C3D5
   
   LDA #$06
   STA $00

   LDA #$08
   RTS
   
CODE_C3D5:
   LDA #$00
   STA $00

   LDA #$05
   RTS
   
CODE_C3DC:
   LDA #$06
   STA $00

   LDA #$1C
   RTS
   
CODE_C3E3:
   LDA $C4					;\swap speed modifiers
   PHA						;|
   LDA $0334					;|luigi with mario and mario with luigi
   STA $C4					;|
   PLA						;|
   STA $0334					;/
   
   LDA #$01					;\slow down luigi
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
   AND #Entity_MovementBits_MovingRight|Entity_MovementBits_MovingLeft
   ORA #Entity_MovementBits_Skidding		;
   STA $B1					;so the players can't change move themselves for a little bit
   STA $0321					;both Mario and Luigi

   STX $C2					;pushing timers
   STY $0332					;

   LDY #$00					;
   STY $C4					;no skidding turning
   STY $0334					;
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
   
;Collision routine. Entity A refers to currently loaded entity in $B0 range, and entity B is in indirect addressing.
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
   LDY #$00					;
   LDA ($14),y					;if entity isn't active, return
   BEQ CODE_C4AE				;
   
   LDX #$40					;set bottom bit by default (D)
   LDY #$08					;
   LDA ($14),y					;check vertical difference between entities
   SEC						;
   SBC $B8					;
   BPL CODE_C46E				;
   EOR #$FF					;entity A is higher than B
   CLC						;
   ADC #$01					;invert value
   LDX #$80					;and set as collided from the top (U)
   
CODE_C46E:
   STX $1F					;
   
   PHA						;
   LDY #$1E					;
   LDA ($14),y					;entity B's hit box y-displacement.
   CLC						;
   ADC $CE					;entity A's hit box y-displacement.
   ADC $1D					;height
   STA $1E					;difference between collisions?
   PLA						;
   
   SEC						;
   SBC $1E					;
   BPL CODE_C4AE				;
   
   LDX #$01					;Left (L)
   LDY #$09					;now X-pos
   LDA ($14),y					;
   SEC						;
   SBC $B9					;check horizontal difference
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
   
   LDY #$1F					;
   LDA ($14),y					;Y-pos hitbox displacement
   CLC						;
   ADC $CF					;
   ADC $1C					;
   STA $1E					;
   PLA						;
   SEC						;
   SBC $1E					;
   BPL CODE_C4AE
   LDA $1F					;if both Y and x positions match, collision test is successfull.
   RTS						;

CODE_C4AE:
   JSR CODE_CDB4				;change entity B
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

   INY						;\no INC $26? Sad day
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
   AND #$0E					;|don't show sprites
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
   JSR CODE_CD9E				;
   
DATA_C510:
   .dw CODE_D34A				;gameplay init
   .dw CODE_E14A				;determine Phase number and if it's a "Test Your Skill!" Area
   .dw CODE_D3F9				;more init - sets Game A or B flag and enables gameplay palette flag
   .dw CODE_D3A8				;last init state?
   
   .dw CODE_C5A3				;actual gameplay!
   .dw CODE_D5E5				;paused (return)
   .dw CODE_E453				;coin counting after "Test Your Skill!" phase
   .dw CODE_D5E5				;return
   
   .dw CODE_D451				;game start
   .dw CODE_E129				;wait for next phase to begin/to take coin count for TEST YOUR SKILL
   .dw CODE_D45C				;unpause
   .dw CODE_E28B				;game over

CODE_C528:
   LDA Controller1InputHolding			;
   AND #Input_Select|Input_Start		;
   CMP #Input_Start				;if player pressed start, start the game
   BNE CODE_C543				;
   
   LDA #$00					;\
   STA DemoFlag					;|reset demo flag
   STA GameplayMode				;/initialize gameplay
   
   JSR CODE_D4FE				;
   JSR CODE_E132				;
   
   LDA #$02					;
   STA $2A					;
   STA $2D					;
   RTS						;
   
CODE_C543:
   LDX NonGameplayMode				;\if it's title screen init
   BEQ CODE_C58E				;/don't check things
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
   JSR CODE_D4FE				;mute sounds (not that they play during demo anyways...)
   
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
   LDA $2D					;keep timer if moving cursor
   CMP #$25					;(when song plays out)
   BCS CODE_C57E				;
   
   LDA #$25					;keep timer
   STA $2D					;

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
   JSR CODE_CD9E				;/

;Title screen and demo pointers
;those run untill we press start to start game
DATA_C593:
   .dw CODE_D40B				;loading title screen
   .dw CODE_D47D				;title screen
   .dw CODE_D491				;initialize demo
   .dw CODE_D496				;more init
   .dw CODE_D49B				;build phase (and more initialization)
   .dw CODE_D4A0				;enable screen display
   .dw CODE_D4AF				;playing title screen demo recording (or actual gameplay?)
   .dw CODE_D448				;reset pointer
   
CODE_C5A3:					;
   JSR CODE_D56E             
   JSR CODE_D202
   JSR CODE_D301                
   JSR CODE_C5DB   
   JSR CODE_C66A                
   JSR CODE_E783                
   JSR CODE_EA31                
   JSR CODE_E795    
   JSR CODE_EDEB				;run platform freezing effect
   JSR CODE_E2AB				;TEST YOUR SKILL related?
   JSR CODE_E21A
   JSR CODE_E1F7                
   JSR CODE_DFF8				;handle drawing/removing GAME OVER string and removing PHASE string
   JSR CODE_E1CE                
   JSR CODE_E26D                
   JSR CODE_E709                
   JSR CODE_EF32				;run score sprites' timers
   
   LDA #$01
   STA $42					;entity update flag? (for NMI)
   RTS

CODE_C5DB:
   LDA #$00                 
   STA $A0
   
   LDA #$03                 
   STA $A1               
   
   LDA #$02                 
   STA $33      
   
   LDA #$00                 
   STA $A2       
   STA $05FA
   
   LDA $19                  
   STA $0310      
   
   LDA $1B                  
   STA $0330

CODE_C5F8:   
   JSR CODE_CB9B
   
   LDA $B0                  
   BNE CODE_C605
   
   JSR CODE_DFBA     
   JMP CODE_C65D
   
CODE_C605:
   JSR CODE_D019
  
   LDX $BE                  
   INC $04AC,X              
   INC $04AC,X
   
   LDA $C6                  
   BEQ CODE_C636       
   AND #$F0                 
   BNE CODE_C629
   
   LDA $51                  
   BNE CODE_C62C
  
   JSR CODE_DEEC                
   LDA $C6                  
   BEQ CODE_C636   
   AND #$0C                 
   BNE CODE_C636                
   BEQ CODE_C62C
  
CODE_C629:  
   JSR CODE_DDE0
  
CODE_C62C:  
   JSR CODE_DFBA 
   JMP CODE_C657
  
   LDA $51					;unused? leftover?
   BNE CODE_C62C				;these can't be executed

CODE_C636:  
   LDA $33                  
   CMP #$02                 
   BNE CODE_C63F                
   JSR CODE_C0B6
   
CODE_C63F:
   LDA $05FD
   BEQ CODE_C647
   
   JSR CODE_CAB9

CODE_C647:   
   LDA $51                  
   BNE CODE_C62C
   
   JSR CODE_D6BA                
   JSR CODE_C785
   JSR CODE_CC3F
   JSR CODE_DC75
   
CODE_C657:
   JSR CODE_CBC4                
   JSR CODE_CBB6
  
CODE_C65D:
   JSR CODE_CBAE
   DEC $33       
   BNE CODE_C5F8
   
   LDA #$00                 
   STA $05FD                
   RTS
   
CODE_C66A:
   LDA $43                  
   BNE CODE_C66F                
   RTS

CODE_C66F:   
   STA $45                  
   STA $44                  
   STA $33
   
   LDA #$60                 
   STA $A0
   
   LDA #$03                 
   STA $A1
   
   LDA #$00                 
   STA $A2 
   
   LDA #$0D                 
   STA $05FA

CODE_C686:   
   JSR CODE_CB9B
   
   LDA $B0                  
   BNE CODE_C697
   
   DEC $45                  
   DEC $44                  
   JSR CODE_DFBD                
   JMP CODE_C75D

CODE_C697:  
   JSR CODE_D019                
   LDX $BE                  
   INC $04AC,X
   
   LDA $51                  
   BEQ CODE_C6BC
   
   LDA $C0                  
   BNE CODE_C6BC
   
   LDA $BF                  
   CMP #$40                 
   BEQ CODE_C6C9                
   CMP #$80                 
   BNE CODE_C6BC
   
   LDA #$00                 
   STA $04C0
   
   LDA #<DATA_F59E				;$9E                 
   LDY #>DATA_F59E				;$F5                 
   BNE CODE_C6CD

CODE_C6BC:  
   JMP CODE_ECEC

CODE_C6BF:
   LDA $C9                  
   BEQ CODE_C6E9
   
   LDA $BF                  
   CMP #$40                 
   BNE CODE_C6E0

CODE_C6C9:  
   LDA #<DATA_F5A4				;$A4                 
   LDY #>DATA_F5A4				;$F5
  
CODE_C6CD:
   STA $06                  
   STY $07
   
   LDA #$30                 
   STA $00
   
   JSR CODE_D789                
   LDA #$00                 
   STA $C9                  
   STA $C2                  
   BEQ CODE_C744

CODE_C6E0:  
   JSR CODE_DEAF                
   JSR CODE_DFBD                
   JMP CODE_C747
  
CODE_C6E9:
   JSR CODE_D6BA                
   JSR CODE_DB53                
   JSR CODE_DBFF
   
   LDA $C0                  
   BNE CODE_C6FC                
   JSR CODE_D9FE                
   JMP CODE_C708
  
CODE_C6FC:
   LDA $C0                  
   AND #$0F                 
   CMP #$03                 
   BEQ CODE_C744                
   CMP #$06                 
   BEQ CODE_C744

CODE_C708:  
   JSR CODE_DB2D
   
   LDA $C0                  
   ORA $C2                  
   BNE CODE_C73B
   
   LDA $46                  
   BEQ CODE_C73B
   
   LDA $BF                  
   LDY #$05                 
   LDX #$06                 
   CMP #$20                 
   BEQ CODE_C727
   
   LDY #$02                 
   LDX #$02                 
   CMP #$10                 
   BNE CODE_C73B

CODE_C727:  
   STY $C4                  
   STX $BB                  
   JSR CODE_CAB9                
   JSR CODE_D9B6
   
   LDA $BF                  
   CMP #$10                 
   BNE CODE_C73B
   
   LDA #$00
   STA $C7

CODE_C73B:   
   LDA $B3                  
   CMP #$05                 
   BCS CODE_C744                
   JSR CODE_C785

CODE_C744:  
   JSR CODE_CC73

CODE_C747:  
   JSR CODE_CBC4
   
   LDA $B0
   BEQ CODE_C758
   
   LDA $C9                  
   BNE CODE_C758
   
   LDA $BF                  
   CMP #$40                 
   BCC CODE_C75A

CODE_C758:  
   DEC $44

CODE_C75A:  
   JSR CODE_CBB6
  
CODE_C75D:
   JSR CODE_CBAE
   
   DEC $33                  
   BNE CODE_C782
   
   LDA $35                  
   CMP #$AA                 
   BNE CODE_C781
   
   LDA $45                  
   BNE CODE_C775   
   STA $43

CODE_C770:
   LDA #$01					;phase complete
   STA DisableControlFlag			;
   RTS						;

CODE_C775:
   LDA $44					;
   BEQ CODE_C770				;if all enemies are defeated, mark phase as complete
   CMP #$01					;if not last enemy alive
   BNE CODE_C781				;return
   
   LDA #$01					;mark last enemy (make them faster)
   STA $46					;
   
CODE_C781:
   RTS						;
   
CODE_C782:
   JMP CODE_C686                
   
CODE_C785:
   LDA $BF                  
   CMP #Entity_ID_Fighterfly			;check if figherfly
   BNE CODE_C7B7
   
   LDA $C0					;grounded flag?
   BNE CODE_C792				;

   JSR CODE_CE9C				;animate (animate while jumping and falling)

CODE_C792:  
   LDA CurrentEntity_Timer			;timer for fighterfly to jump?
   BEQ CODE_C797				;
   RTS						;

CODE_C797:   
   LDA $C0                  
   BNE CODE_C7B7
   
   LDA $B1                  
   AND #$C0                 
   BNE CODE_C7B7
   
   LDA $B1                  
   ORA #$80                 
   STA $B1
   
   LDX #<DATA_F36D				;$6D                 
   LDY #>DATA_F36D				;$F3                 
   LDA $BE
   BNE CODE_C7B3
   
   LDX #<DATA_F370				;$70      
   LDY #>DATA_F370				;$F3

CODE_C7B3:  
   STX $BC
   STY $BD
   
CODE_C7B7:
   LDA $B1                  
   STA $11
   
   JSR CODE_CCA0                
   BIT $11                  
   BMI CODE_C7C7                
   BVS CODE_C7CA
   
   JMP CODE_C7CD
   
CODE_C7C7:
   JMP CODE_C93A

CODE_C7CA:  
   JMP CODE_C9A1
  
CODE_C7CD:  
   LDA $BF                  
   AND #$F0                 
   BEQ CODE_C7DA
   
   LDA $C2
   BEQ CODE_C7DE
   
   JMP CODE_C8D1

CODE_C7DA:
   LDA $C6                  
   BNE CODE_C7F3
  
CODE_C7DE:
   LDA $CD                  
   JSR CODE_CAA4
   AND #$0F                 
   BNE CODE_C7EA
   
   JMP CODE_C97D
   
CODE_C7EA:
   LDA $BF                  
   AND #$0F                 
   BNE CODE_C7F3
   
   JMP CODE_C8D1


CODE_C7F3:
   LDA $C2                  
   BEQ CODE_C7F9
   DEC $C2

CODE_C7F9:   
   LDA $B1                  
   AND #$08					;grounded bit?
   BNE CODE_C86F				;if set, take care of movement
   
   LDA $C0                  
   BPL CODE_C824

;performing jump, wah, wahoo, yupee!
   LDA Sound_Effect2				;play sound
   ORA #Sound_Effect2_Jump			;
   STA Sound_Effect2				;
   
   LDA $B1                  
   AND #$33					;
   ORA #$80					;bits...
   STA $B1
   
   LDA #<DATA_F350				;$50                 
   STA $BC
   
   LDA #>DATA_F350				;$F3                 
   STA $BD
   
   LDA #GFX_Player_Jumping			;
   STA CurrentEntity_DrawTile			;
   
   LDA #$00                 
   STA $B4
   
   JMP CODE_C9E6
   
CODE_C824:
   AND #$03                 
   STA $1E

   LDA $B1                  
   STA $1F   
   AND #$04                 
   BNE CODE_C8AD
   
   LDA $B1                  
   AND #$03                 
   STA $1F 
   BEQ CODE_C891
   
   LDY $05FF                
   BNE CODE_C8B5                
   AND $1E                  
   BEQ CODE_C853
   
   LDA $C2                  
   BNE CODE_C8B5                
   STA $BB
   
   INC $C4                  
   JSR CODE_CAB9
   
   LDA #$08                 
   STA $C2                  
   JMP CODE_C8B5
  
CODE_C853:
   LDA $1F                  
   ORA #$04                 
   STA $1F
   
   LDA $C4                  
   STA $00
   
   LDA $CD                  
   STA $01
   
   JSR CODE_C3C2
   STA $C2

   LDA $00                  
   BEQ CODE_C86C                
   STA $B4

CODE_C86C:
   JMP CODE_C8B5

CODE_C86F:
   DEC $BB						;decrement timer
   BEQ CODE_C884					;if zero, become normal

   LDY #GFX_Player_Squish2				;

   LDA $BB						;show different frame depending on when
   CMP #$20						;
   BEQ CODE_C881					;

   LDY #GFX_Player_Squish1				;
   CMP #$10						;
   BNE CODE_C883					;

CODE_C881:   
   STY CurrentEntity_DrawTile				;

CODE_C883:
   RTS							;
   
CODE_C884:
   LDA #Entity_Draw_16x24			;the player becomes 16x24 again
   STA CurrentEntity_DrawMode			;
   
   LDA $B1					;restore control to the player
   AND #$F7					;
   STA $B1					;
   
   JMP CODE_CEBA				;restore gfx

CODE_C891:
   LDA $1E                  
   BNE CODE_C8A4

CODE_C895:
   LDA #$00                 
   STA $C4                  
   STA $BB
   
   JSR CODE_CAB9                
   JSR CODE_CEBA				;player stand still
   JMP CODE_C8B5

CODE_C8A4:  
   LDA #$05                 
   STA $C2
  
   LDA $1E                  
   JMP CODE_C8B7

CODE_C8AD:
   LDA $C2                  
   BNE CODE_C8B5
  
   STA $1F                  
   BEQ CODE_C895
  
CODE_C8B5:
   LDA $1F

CODE_C8B7:  
   STA $B1          
   STA $11

   LDA CurrentEntity_DrawTile				;only play step sound when this frame displays
   CMP #GFX_Player_Walk2				;
   BNE CODE_C8C7					;

   LDA Sound_Effect2					;
   ORA #Sound_Effect2_Step				;
   BNE CODE_C8CF					;

CODE_C8C7:  
   CMP #GFX_Player_Skid1				;play turning sound when this frame shows up
   BNE CODE_C8D1

   LDA Sound_Effect2					;
   ORA #Sound_Effect2_Turning				;

CODE_C8CF:
   STA Sound_Effect2					;

CODE_C8D1:  
   LDA $BF                  
   CMP #$40                 
   BCC CODE_C8E4
   
CODE_C8D7:
   LDA $C6                  
   BNE CODE_C8DE
   
   JSR CODE_CEA3
  
CODE_C8DE:
   JSR CODE_CAEB                
   JMP CODE_C8F4

CODE_C8E4:  
   JSR CODE_CAEB
   
   LDA $BF                  
   AND #$F0                 
   BEQ CODE_C8F1
   
   LDA $C8                  
   BNE CODE_C916

CODE_C8F1:  
   JSR CODE_CE95				;common movement animation routine
  
CODE_C8F4:
   LDY #$00
   
   LDA $BF                  
   AND #$0F                 
   BNE CODE_C90A
   
   LDA $C8                  
   BNE CODE_C916
   
   LDA $C6                  
   BNE CODE_C90A
   
   LDA #$03                 
   STA $C6                  
   LDY $C7

CODE_C90A:  
   TYA                      
   CLC                      
   ADC $C5                  
   LSR $11                  
   BCS CODE_C91C                
   LSR $11                  
   BCS CODE_C917

CODE_C916:  
   RTS                      

CODE_C917:
   EOR #$FF                 
   SEC                      
   BCS CODE_C91D
  
CODE_C91C:
   CLC

CODE_C91D:  
   ADC $B9                  
   STA $B9

   LDA $BF                  
   AND #$0F                 
   BEQ CODE_C936

   LDA $C1                  
   BEQ CODE_C92C                
   RTS                      

CODE_C92C:
   LDA $BB                  
   BNE CODE_C939                
   LDA $B1                  
   AND #$04                 
   BNE CODE_C939

CODE_C936:  
   JSR CODE_D9EA

CODE_C939:  
   RTS
   
CODE_C93A:
   CMP #$AA                 
   BEQ CODE_C97D
   CMP #$99                 
   BNE CODE_C959
   
   LDA $BF                  
   AND #$0F                 
   BNE CODE_C97D
   
   LDA $C0                  
   AND #$0F                 
   CMP #$0F                 
   BNE CODE_C954
   
   LDA #$FF                 
   STA $C0
  
CODE_C954:
   INC $C0                  
   JMP CODE_C97D
  
CODE_C959:
   TAY                      
   LDA $B8                  
   CMP #$20                 
   BCC CODE_C96F
   
   LDA $BF                  
   AND #$0F                 
   BEQ CODE_C96F
   
   LDA $CB                  
   JSR CODE_CAA4                
   ORA #$00                 
   BNE CODE_C973
  
CODE_C96F:
   TYA                      
   JMP CODE_C9DD

CODE_C973:
   JSR CODE_CF67
   
   LDA #<DATA_F32C					;$2C                 
   LDY #>DATA_F32C					;$F3
   JMP CODE_C992
  
CODE_C97D:
   LDA $BF
   CMP #$30
   BNE CODE_C98E
   
   LDA $C2                  
   BNE CODE_C99E                
   LDA #<DATA_F37B				;$7B                 
   LDY #>DATA_F37B				;$F3                 
   JMP CODE_C992
   
CODE_C98E:
   LDA #<DATA_F33A				;$3A                 
   LDY #>DATA_F33A				;$F3
  
CODE_C992:
   STA $BC                  
   STY $BD

   LDA $B1                  
   AND #$3F                 
   ORA #$40                 
   STA $B1

CODE_C99E:  
   JMP CODE_C9E6

CODE_C9A1:
   TAY
   
   LDA $CD  
   JSR CODE_CAA4
   AND #$0F                 
   BEQ CODE_C9D2
   
   LDA $B1                  
   AND #$3F                 
   STA $B1
   
   LDA $BF                  
   CMP #$30                 
   BNE CODE_C9BD
   
   LDA #$08                 
   STA $B3                  
   BNE CODE_C9CB

CODE_C9BD:
   LDA $BF   
   AND #$0F                 
   BEQ CODE_C9CB
   
   LDA #$00                 
   STA $C1
   
   LDA #$00      				;huh? They couldn't use one LDA #$00 for both C1 and B4?           
   STA $B4					;
   
CODE_C9CB:
   LDA $B8                  
   AND #$F8                 
   STA $B8

CODE_C9D1:   
   RTS
   
CODE_C9D2:
   TYA                      
   CMP #$CC                 
   BEQ CODE_C9F1                
   CMP #$AA                 
   BNE CODE_C9DD                

CODE_C9DB:
   LDA #$04
   
CODE_C9DD:   
   CLC                      
   ADC $B8                  
   CMP #$08                 
   BCC CODE_C9E6
   STA $B8

CODE_C9E6:  
   LDA $BF                  
   AND #$F0                 
   BNE CODE_C9F8
   
   LDA $C1                  
   JMP CODE_C9FE
   
CODE_C9F1:
   LDA $B2                  
   STA $B3                  
   JMP CODE_C9DB
  
CODE_C9F8:
   CMP #$30       
   BEQ CODE_CA0C

   LDA $C0 
  
CODE_C9FE:
   BEQ CODE_CA0C                
   AND #$F0
   CMP #$30                 
   BEQ CODE_C9D1
   
   LDA $2F                  
   AND #$03                 
   BEQ CODE_CA15
  
CODE_CA0C:
   LDA $BF                  
   CMP #$40                 
   BCS CODE_CA18                
   JSR CODE_CAEB
  
CODE_CA15:
   JMP CODE_C8F4
  
CODE_CA18:
   JMP CODE_C8D7

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Clear Screen Init
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Sets up values that'll be used in screen filler routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   
CODE_CA1B:
   LDA #$03					;
   JSR CODE_CA22				;

CODE_CA20:
   LDA #$01					;
   
CODE_CA22:   
   STA $01					;this is "VRAM" offset, needed to set-up proper tile update location
   
   LDA #$24					;set blank tile to be displayed on screen
   STA $00					;
   JMP CODE_CD43				;go and clear the screen
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Clear Sprites loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;"Clears" OAM, by putting it in "Hide zone" (and setting other values we don't care about)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   
CODE_CA2B:					;
   LDY #>OAM_Y					;OAM starting point, high byte
   STY $01					;

   LDY #<OAM_Y					;\OAM starting point, low byte
   STY $00					;/

   LDA #$F4					;

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
   LDY PaletteFlag			;check if it should update palette
   BEQ CODE_CA65			;return if not
   DEY					;check if supposed to load gameplay palette
   BEQ CODE_CA73			;do so if set, otherwise set palette for title screen
   
   LDA #<DATA_F227			;Setup address to read data from (DATA_F227)
   LDX #>DATA_F227			;
   BNE CODE_CA77			;

CODE_CA73:
   LDA #<DATA_F203			;setup different data address to read from (DATA_F203)
   LDX #>DATA_F203			;
   
CODE_CA77:
   LDY #$00				;
   STY PaletteFlag			;update once, don't waste time
   BEQ CODE_CA5E			;lets go call routine and store palettes to VRAM

CODE_CA7D:
   LDA $00
   LSR A
   LSR A
   LSR A
   STA $12
   
   LDA #$20
   STA $13
   
   LDA #$00
   STA $15
   
   LDA $01
   AND #$F8
   ASL A
   ROL $15
   ASL A
   ROL $15
   STA $14
   JSR CODE_CDB4
   
   LDA $15
   STA $00
   
   LDA $14
   STA $01
   RTS
   
CODE_CAA4:
   CMP #$92                 
   BCC CODE_CAB6                
   CMP #$A0                 
   BCC CODE_CAB3                
   CMP #$FA                 
   BCS CODE_CAB3                
   LDA #$02                 
   RTS     
  
CODE_CAB3:
   LDA #$01                 
   RTS

CODE_CAB6:
   LDA #$00                 
   RTS
   
CODE_CAB9:
   LDA #<DATA_F393			;$93     
   STA $14				;
   
   LDA #>DATA_F393			;$F3
   STA $15
   
   LDA $C3				;offset stored in entity's ram!
   STA $12
   
   LDA #$00				;
   STA $13
   
   JSR CODE_CDB4

CODE_CACC:
   LDA $C4                  
   ASL A
   CLC                      
   ADC $C4                  
   TAY                      
   LDA ($14),Y              
   CMP #$AA                 
   BNE CODE_CADE
   
   DEC $C4                  
   JMP CODE_CACC

CODE_CADE:  
   STA CurrentEntity_XSpeed			;set player's speed (possibly other entities too?)
   INY						;
   LDA ($14),Y					;some other entity ram (currently unknown)
   STA $B2                  
   INY                      
   LDA ($14),Y              
   STA $C7                  
   RTS 
   
CODE_CAEB:
   LDA $B3                  
   BEQ CODE_CAF2                
   PLA                      
   PLA                      
   RTS
   
CODE_CAF2:
   LDA $B2
   STA $B3
   RTS
   
CODE_CAF7:
   LDA $42
   BEQ CODE_CB4F
   
   LDA #$0D
   STA $33
   
   LDX #$01
   LDA FrameCounter				;do something every other frame...
   LSR A					;
   BCC CODE_CB08				;
   
   LDX #$0E
   
CODE_CB08:
   LDA #<Entity_Address
   STA $14
   
   LDA #>Entity_Address
   STA $15
   
   LDA #<Entity_Address_Size
   STA $12
   
   LDA #>Entity_Address_Size
   STA $13

CODE_CB18:
   LDY #$00
   LDA ($14),y				;if the entity isn't even active
   BEQ CODE_CB29			;
   
   LDY #$03				;
   LDA ($14),y				;decrease timer address for current entity (CurrentEntity_TimerB3)
   BEQ CODE_CB29			;
   SEC					;
   SBC #$01				;
   STA ($14),y				;

CODE_CB29:
   LDA $33
   CMP #$0B
   BCC CODE_CB40
   CPX #$0E
   BCS CODE_CB48
   
   LDY #$1B
   JSR CODE_CB50
   
CODE_CB38:
   LDY #$1D
   JSR CODE_CB50
   JMP CODE_CB48
   
CODE_CB40:
   CMP #$05
   BCC CODE_CB48
   
   CPX #$0E
   BCS CODE_CB38

CODE_CB48:
   JSR CODE_CDB4
   DEC $33
   BNE CODE_CB18

CODE_CB4F:
   RTS
   
CODE_CB50:
   LDA $0520,x
   STA ($14),y
   INX
   INX
   RTS
   
CODE_CB58:
   LDA $42
   BEQ CODE_CB84
   
   LDX #$00
   LDA $2F
   LSR A
   BCC CODE_CB65
   
   LDX #$0D
   
CODE_CB65:
   LDY #$06
   LDA HardwareStatus
   
CODE_CB6A:
   LDA $0520,x
   STA VRAMPointerReg
   INX
   LDA $0520,x
   STA VRAMPointerReg

   LDA VRAMUpdateRegister			;huh?
   LDA VRAMUpdateRegister
   STA $0520,x
   INX
   DEY
   BNE CODE_CB6A

CODE_CB84:
   RTS
   
CODE_CB85:
   LDA $A0                  
   STA $14
   
   LDA $A1                  
   STA $15
   
   LDA $A2                  
   STA $12
   
   LDA #$00                 
   STA $13
   
   JSR CODE_CDB4
   
   TAY                      
   TAX                      
   RTS                      
   
CODE_CB9B:
   JSR CODE_CB85

CODE_CB9E:
   LDA ($14),Y              
   STA $B0,X
   
   INY                      
   INX                      
   CPX #$20                 
   BNE CODE_CB9E
   
   LDA #$00                 
   TAY                      
   STA ($14),Y
   RTS
   
CODE_CBAE:
   LDA $A2                  
   CLC                      
   ADC #$20                 
   STA $A2                  
   RTS
   
CODE_CBB6:
   JSR CODE_CB85
   
CODE_CBB9:
   LDA $B0,X                
   STA ($14),Y              
   INY
   INX
   CPX #$20
   BNE CODE_CBB9 

CODE_CBC3:
   RTS

;seems to be a general sprite GFX drawing routine
CODE_CBC4:
   LDA CurrentEntity_ActiveFlag			;if current entity is non-existent
   BEQ CODE_CBC3				;don't draw

   LDA #>DATA_F296				;load pointer table for graphics for current entity
   STA $15

   LDA #<DATA_F296
   STA $14

   LDA CurrentEntity_DrawMode			;get
   JSR CODE_CC29				;

   LDA CurrentEntity_DrawTile			;first sprite tile to draw from (as in first tile is 12, then 13, then 14, etc.)
   STA $11					;

   LDY #$00					;
   LDX $BA					;OAM offset

CODE_CBDD:
   LDA ($12),Y					;
   BEQ CODE_CBE9				;check if it should animate with frame counter?
   BPL CODE_CBE4				;if bit 7 is set, it'll animate slower (or faster, idk)
   ASL A

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

   INX
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

CODE_CC3F:
   LDA $B8                  
   SEC                      
   SBC #$0F                 
   CMP #$20                 
   BCC CODE_CC4C                
   CMP #$E0                 
   BCC CODE_CC54
  
CODE_CC4C:
   LDA #$00                 
   STA $01                  
   LDA #$20                 
   BNE CODE_CC5F
  
CODE_CC54:
   STA $01
   
   LDA CurrentEntity_XPos
   STA $00                  
   JSR CODE_CA7D
   
   LDA $00

CODE_CC5F:
   LDX $05FA                
   STA $CA                  
   STA $0520,X
   
   INX                      
   LDA $01                  
   STA $C9                  
   STA $0520,X
   
   INX                      
   STX $05FA

CODE_CC73:
   LDA CurrentEntity_YPos			;
   CLC						;
   ADC #$08					;
   CMP #$E4					;check if current entity is low enough
   BCC CODE_CC84				;if not, well

   LDA #$00					;IDK what this is supposed to be. i think this is supposed to hide entity that's attempting to spawn in (if the same pipe is used by  different entity) but again IDK
   STA $01

   LDA #$20                 
   BNE CODE_CC8F
  
CODE_CC84:
   STA $01
   
   LDA CurrentEntity_XPos
   STA $00                  
   JSR CODE_CA7D
   
   LDA $00
  
CODE_CC8F:
   LDX $05FA
 
   STA $0520,X              
   INX
 
   LDA $01                  
   STA $0520,X

   INX                      
   STX $05FA                
   RTS
   
CODE_CCA0:
   STY $1E
   
   LDA $BC     
   STA $14
   
   LDA $BD                  
   STA $15
   
   LDY #$00                 
   LDA ($14),Y
   CMP #$AA                 
   BEQ CODE_CCC2                
   STY $13
   
   INY                      
   STY $12                  
   JSR CODE_CDB4
   
   LDY $14                  
   STY $BC
   
   LDY $15                  
   STY $BD
  
CODE_CCC2:  
   LDY $1E                  
   RTS

;Should be self-explanatory
;ReadControllers_CCC5:
CODE_CCC5:
   LDX #$01				;\prepare controller 2 for reading
   STX ControllerReg			;/
   DEX					;\
   TXA					;|prepare controller 1 for reading
   STA ControllerReg			;/
   JSR CODE_CCD3			;read input bits for controller 1
   INX					;then controller 2
   
CODE_CCD3:
   LDY #$08				;8 bits, of course
   
CODE_CCD5:
   PHA					;
   LDA ControllerReg,x			;load whatever bit
   
   STA $00				;store here
   LSR A				;\
   ORA $00				;|get rid of all bits but bit zero (that happens)
   LSR A				;/
   PLA					;
   ROL A				;"sum" active bits
   DEY					;\
   BNE CODE_CCD5			;/next button check
   
   STX $00				;\get index for single frame press
   ASL $00				;|
   LDX $00				;|
   LDY ControllerInputHolding,x		;|
   STY $00				;/store to scratch ram
   STA ControllerInputHolding,x		;\store controller input (holding)
   STA ControllerInputPress,x		;/(press)
   AND #$FF				;\if A and B are pressed
   BPL CODE_CCFE			;/meh
   
   BIT $00				;if these buttons are pressed again
   BPL CODE_CCFE			;don't reset bits
   
   AND #$7F				;\reset A and B press bits
   STA ControllerInputPress,x		;/
   
CODE_CCFE:
   RTS					;

;Draw tiles from Buffer
;BufferedDraw_CCFF:
CODE_CCFF:
   LDA BufferDrawFlag			;flag for tile update
   BEQ CODE_CD42			;obviously don't do that if not set
   
   LDA #<BufferAddr			;set buffer address as indirect address ($91)
   STA $00				;
   
   LDA #>BufferAddr			;$05
   STA $01				;
   
   LDA Reg2000BitStorage		; 
   AND #$FB				;enable any of bits except for bits 0 and 1
   STA ControlBits			;(which are related with nametables)
   STA Reg2000BitStorage		;back them up
   
   LDX HardwareStatus			;prepare for PPU drawing
   
   LDY #$00				;initialize Y register
   BEQ CODE_CD34			;jump ahead

CODE_CD1B:
   STA VRAMPointerReg			;set tile drawing position, high byte
   
   INY					;low byte
   LDA ($00),y				;
   STA VRAMPointerReg			;
   
   INY					;
   LDA ($00),y				;
   AND #$3F				;
   TAX					;set how many tiles to draw on a single line
   
CODE_CD2A:
   INY					;
   LDA ($00),y				;now, tiles
   STA VRAMUpdateRegister		;
   DEX					;
   BNE CODE_CD2A			;draw untill the end
   INY					;

CODE_CD34:
   LDA ($00),y				;if it transferred all tile data from buffer addresses by hitting address with 0, return
   BNE CODE_CD1B			;loop if must
   
   LDA #$00				;
   STA BufferOffset			;
   STA BufferAddr			;
   STA BufferDrawFlag			;end draw, reset flag

CODE_CD42:
   RTS					;
   
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
   
CODE_CD43:
   LDA HardwareStatus			;ready to draw
   
   LDA Reg2000BitStorage		;\
   AND #$FB				;|
   STA ControlBits			;|
   STA Reg2000BitStorage		;/
   
   LDA #$1C				;
   CLC					;

CODE_CD52:
   ADC #$04				;
   DEC $01				;calculate high byte of tile drawing starting point
   BNE CODE_CD52			;can be either 20 or 28
   STA $02				;
   STA VRAMPointerReg			;

   LDA #$00				;tile drawing's position, low byte
   STA VRAMPointerReg			;so, the final starting position is either 2000 or 2800

   LDX #$04				;to effectively clear full screen, we need to go from 0 to 255 (dec) 4 times! which is 8 horizontal tile lines from the top right to the bottom left tile. that's how many 8x8 tiles to clear
   LDY #$00				;(technically not, as this also affects attributes that start after 2xBF, but they get cleared afterwards anyway)

   LDA $00				;load tile to fill screen with (by default it's only 24. why they didn't load 24 directly is a mystery. They wanted to use this more than once, with different values loaded into $00? world may never know).

CODE_CD68:
   STA VRAMUpdateRegister		;\fill screen(s) with tiles
   DEY					;|
   BNE CODE_CD68			;|
   DEX					;|
   BNE CODE_CD68			;/

   LDA $02				;\calculate position of tile attribute data.
   ADC #$03				;|end result is either 23 or 2B
   STA VRAMPointerReg			;/

   LDA #$C0				;\attributes location, low byte
   STA VRAMPointerReg			;/

   LDY #$40				;64 attribute bytes
   LDA #$00				;zero 'em out

CODE_CD81:
   STA VRAMUpdateRegister		;\this loop clears tile attributes (y'know, 32x32 areas that contain palette data for each individual 16x16 in it tile)
   DEY					;|
   BNE CODE_CD81			;/
   RTS					;

;handle various timers
CODE_CD88:
   LDX #$01				;
   DEC TimingTimer			;tick tactics
   BPL CODE_CD94			;don't restore timing

   LDA #$0A				;some timers tick every 10 frames
   STA TimingTimer			;

   LDX #$03				;decrease timers from $2E downto $2B (otherwise only $2C and $2B)

CODE_CD94:
   LDA TimerBase2,x			;if timer is already 0, move onto the next timer
   BEQ CODE_CD9A			;

   DEC TimerBase2,x			;

CODE_CD9A:
   DEX					;
   BPL CODE_CD94			;loop
   RTS					;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Pointer routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Used for 2-byte jumps depending on loaded variable and table values after JSR to this routine.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;ExecutePoiters_CD9E:
CODE_CD9E:
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

;used for some offsets
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
   LDA CameraPosY				;restore camera position
   STA VRAMRenderAreaReg			;

   LDA CameraPosX				;
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

   JSR CODE_CE84				;

   LDA $00					;VRAM position, low byte
   STA BufferAddr,X				;

   JSR CODE_CE84				;

   LDA $05					;number of tiles to draw
   STA $06					;set up a loop
   STA BufferAddr,X 				;and save that information in the buffer.

CODE_CE5A:
   JSR CODE_CE84				;

   INY						;get those tiles in the buffer
   LDA ($02),Y					;
   STA BufferAddr,X				;

   DEC $06					;keep looping untill all bytes are in the buffer  
   BNE CODE_CE5A				;
   JSR CODE_CE84				;

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

CODE_CE84:   
   INX						;write next buffer byte
   TXA						;transfer into X for the next check

CODE_CE86:   
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
CODE_CE95:
   LDA CurrentEntity_Bits			;if an entity is either falling or jumping, don't animate
   AND #Entity_MovementBits_Jump|Entity_MovementBits_Fall
   BEQ CODE_CE9C				;
   RTS						;

CODE_CE9C:
   LDA CurrentEntity_Bits			;is entity even moving? no?
   AND #Entity_MovementBits_MovingRight|Entity_MovementBits_MovingLeft		;wew!
   BNE CODE_CEA3				;yes? dew yeet
   RTS						;

CODE_CEA3:
   LDY CurrentEntity_AnimationPointer		;
   LDA DATA_F4B2,Y				;
   CMP #$FF					;encountered loop command?
   BEQ CODE_CEB1				;use next byte to go to specified point
   STA CurrentEntity_DrawTile			;otherwise just show the frame

   INC CurrentEntity_AnimationPointer		;
   RTS						;

CODE_CEB1:
   INY						;
   LDA DATA_F4B2,Y				;reset animation cycle
   STA CurrentEntity_AnimationPointer		;
   JMP CODE_CEA3				;

CODE_CEBA:
   LDA #GFX_Player_Standing			;player stops, display standing animation
   STA CurrentEntity_DrawTile			;
   
   LDA #$00					;
   STA CurrentEntity_AnimationPointer		;reset animation pointer
   RTS						;
   
CODE_CEC3:
   LDA #$60
   STA $A0
   
   LDA #$03
   STA $A1
   
   LDA #<Entity_Address_Size
   STA $A2
   STA $12
   
   LDA #>Entity_Address_Size
   STA $13
   
   LDA #$06
   STA $33

CODE_CED9:
   LDY #$00
   
   LDA ($A0),y
   BEQ CODE_CEEF
   
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
   
   LDA #<DATA_F452			;$52                      
   STA $14
   
   LDA #>DATA_F452			;$F4            
   STA $15
   
   LDA $1E                  
   BEQ CODE_CF19

CODE_CF12:
   JSR CODE_CDB4
   
   DEC $1E
   BNE CODE_CF12

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
   
   LDA $30                  
   BEQ CODE_CF3B
   
   LDA #$01                 
   BNE CODE_CF53

CODE_CF3B:
   LDA $1F                  
   CMP #$02                 
   BNE CODE_CF48
   
   LDA $04F5                
   EOR #$03                 
   BNE CODE_CF53

CODE_CF48:
   JSR CODE_D328                
   AND #$01                 
   CLC                      
   ADC #$01           
   STA $04F5
   
CODE_CF53:
   LDX #$F0                 
   CMP #$01                 
   BEQ CODE_CF5B
   
   LDX #$10

CODE_CF5B:   
   LDY #$12                 
   STA ($A0),Y              
   TXA
   
   LDY #$09                 
   STA ($A0),Y
   
   INC $43                  
   RTS

;player's head hits the platform
CODE_CF67:
   LDA POWPowerTimer				;can't hit platforms if POW is active
   BNE CODE_CF88				;

   LDA $C1					;player's something...
   BNE CODE_CF88				;

   LDA $05FF					;flag...
   BNE CODE_CF88				;

   LDA FreezePlatformFlag			;there's a platform freezing somewhere?
   BNE CODE_CF88				;can't bump

   LDX CurrentEntity_ID				;
   LDY #$01					;set up ram offset for specific player
   CPX #$01					;
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
   LDA $C9					;
   CMP DATA_F574,X				;check VRAM location of the player
   BNE CODE_CFA7				;doesn't match

   LDA $CA					;high byte
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

   LDA $CB					;something something...
   CMP #$FA					;
   BCC CODE_CFB6				;
   JMP CODE_D2DF				;Hit POW block.

;check screen ends
CODE_CFB6:
   LDA $C9					;
   AND #$1F					;
   BEQ CODE_CF9E				;no bits set meaning VRAM low byte is 0, meaning the left side of the screen, show as 2x2 right platform end bump animation
   CMP #$1F					;
   BEQ CODE_CFC4				;exactly 1F? right side of the screen = 2x2 left platform end bump anim

   LDX #$03					;somewhere in the middle (3z2 animation)
   BNE CODE_CFC6				;

CODE_CFC4:
   LDX #$01					;

CODE_CFC6:  
   LDA #$DF					;(PlayersVRAMPos+FFDF, which means higher but also one tile to the left)
   STA $12					;

CODE_CFCA:
   LDA $CB					;probably supposed to tell the player that they can't hit the same area twice (probably in 2P mode)
   CMP #$A0					;
   BCS CODE_CF88				;return

   LDA #$FF					;
   STA $13					;basically adding such a big value will result in substraction instead due to overflow (can be either FFE0 or FFDF)

   LDA $CA					;store player's "VRAM" position
   STA $15					;

   LDA $C9					;
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

   LDA $CB					;use galaxy brain to calculate bump animation with platform tiles in mind
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
   
CODE_D019:
   LDA $B8                  
   LDY #$03     
   CMP #$50
   BCC CODE_D02C
   
   DEY                      
   CMP #$80
   BCC CODE_D02C
   DEY
   
   CMP #$B0                 
   BCC CODE_D02C                
   DEY
   
CODE_D02C:   
   STY $BE     
   RTS

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

CODE_D03F:
   INX                      
   TXA                      
   AND #$0F                 
   CMP #$09                 
   BCS CODE_D0B3                
   ASL A                    
   ASL A                    
   TAY                      
   STA $02
   
   LDX BufferOffset				;get VRAM pos high
   LDA DATA_F68D,Y				;
   STA BufferAddr,X				;

   JSR CODE_CE84				;
   INY						;
   LDA DATA_F68D,Y				;VRAM pos Low
   STA BufferAddr,X				;

   JSR CODE_CE84                
   INY
   LDA DATA_F68D,Y              
   AND #$07					;AND for some reason...
   STA BufferAddr,X
   STA $01                  
   TXA
   SEC                      
   ADC $01                  
   JSR CODE_CE86
   
   TAX						;
   STX BufferOffset				;end stuffing buffer with... well, stuff
   
   LDA #VRAMWriteCommand_Stop			;
   STA BufferAddr,X				;
   INY						;
   
   LDA DATA_F68D,Y				;
   STA $03					;
   
CODE_D083:
   DEX
   
   LDA $90,Y
   AND #$0F                 
   STA $0591,X
   
   DEC $01                  
   BEQ CODE_D0A2                
   DEX
   
   LDA $90,Y              
   AND #$F0                 
   LSR A                    
   LSR A                    
   LSR A                    
   LSR A                    
   STA $0591,X
   DEY
   
   DEC $01                  
   BNE CODE_D083

CODE_D0A2:  
   LDA $03                  
   AND #$01                 
   BEQ CODE_D0B3
   
   LDY $02				;\seems to be unused
   CLC					;|
   LDA $90,Y				;|
   ADC #$37				;|
   STA $0591,X				;/
  
CODE_D0B3:
   RTS

;score related
;Input:
;$05 - Hundreds and tens thousands to add
;$06 - Thousands and hundreds to add
;$07 - Tens and ones to add
;A - score address offset, where 0 - mario and 1 - luigi

CODE_D0B4:
   AND #$07				;get some bits (IDK why)
   ASL A				;
   ASL A				;x4 to get correct score address
   TAX					;into X
   
   LDA $04				;some flag thats never set?
   BEQ CODE_D0E4			;
   
   LDA $94,X				;\untriggered
   BEQ CODE_D0E8			;/
   
CODE_D0C1:
   CLC					;
   LDA $97,X				;store original value before calculation into $03
   STA $03				;
   
   LDA $07				;
   JSR CODE_D139			;calculate tens and ones
   STA $97,X				;

   LDA $96,X				;now calculate hundreds and thousands
   STA $03				;

   LDA $06				;
   JSR CODE_D139			;
   STA $96,X				;
   
   LDA $95,X				;and tens and ones
   STA $03				;
   
   LDA $05				;
   JSR CODE_D139			;
   STA $95,X				;
   RTS					;

CODE_D0E4:  
   LDA $94,X				;need to find out what this is
   BEQ CODE_D0C1

CODE_D0E8:   
   SEC
   LDA $97,X                
   STA $03
   
   LDA $07                  
   JSR CODE_D15A                
   STA $97,X
   
   LDA $96,X                
   STA $03
   
   LDA $06                  
   JSR CODE_D15A                
   STA $96,X
   
   LDA $95,X                
   STA $03
   
   LDA $05                  
   JSR CODE_D15A                
   STA $95,X
   
   LDA $95,X             		 ;\could work without LDA?
   BNE CODE_D116         		 ;/
   
   LDA $96,X                
   BNE CODE_D116                
   LDA $97,X                
   BEQ CODE_D11C

CODE_D116:  
   BCS CODE_D138                
   LDA $94,X                
   EOR #$FF

CODE_D11C:  
   STA $94,X                
   SEC                      
   LDA #$00                 
   STA $03

   LDA $97,X                
   JSR CODE_D15A                
   STA $97,X

   LDA $96,X                
   JSR CODE_D15A                
   STA $96,X

   LDA $95,X                
   JSR CODE_D15A                
   STA $95,X
  
CODE_D138:
   RTS

;Calculate counter value, like score
;Input:
;$03 - original value to add to
;A - value to add
;Output:
;A - result
;Carry - if next calculation in this routine should have a +1 to low digit
CODE_D139:
   JSR CODE_D17C			;
   ADC $01				;
   CMP #$0A				;if value less than A
   BCC CODE_D144			;don't round
   ADC #$05				;by adding 6 (incluing carry)
  
CODE_D144:
   CLC					;
   ADC $02				;
   STA $02				;
   LDA $03				;tens/thousands/ten thousands
   AND #$F0				;
   ADC $02				;and additional ten/whatev
   BCC CODE_D155			;overflow?

CODE_D151:   
   ADC #$5F				;+$60 (w/ right next)
   SEC					;and +1 for the next calculation (thats + $160)
   RTS					;

CODE_D155:   
   CMP #$A0				;hundreds and etc?
   BCS CODE_D151			;if so, add more + 10 AND 100
   RTS					;otherwise return

CODE_D15A:
   JSR CODE_D17C                
   SBC $01                  
   STA $01                  
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
;$01 - low digit (00-0F)
;$02 - high digit (00-F0) 

CODE_D17C:
   PHA					;
   AND #$0F				;
   STA $01				;save low digit
   PLA					;
   AND #$F0				;and high digit
   STA $02				;

   LDA $03				;calculate low digit of value we're about to calculate
   AND #$0F				;
   RTS					;

CODE_D18B:   
   LDA #$00                 
   STA $04                  
   CLC
   
   LDA $00                  
   ADC #$10                 
   AND #$F0                 
   LSR A                    
   LSR A                    
   TAY
   
   LDA $00                  
   AND #$07                 
   ASL A                    
   ASL A                    
   TAX

CODE_D1A0:
   LDA $90,Y              
   BEQ CODE_D1F6
   
   LDA $94,X                
   BEQ CODE_D1CF

CODE_D1A9:  
   SEC                      
   LDA $93,Y              
   STA $03
   
   LDA $97,X                
   JSR CODE_D15A
   
   LDA $92,Y              
   STA $03
   
   LDA $96,X                
   JSR CODE_D15A
   
   LDA $91,Y              
   STA $03
   
   LDA $95,X
   JSR CODE_D15A                
   BCS CODE_D1FA
   
   LDA $90,Y
   BNE CODE_D1FF
  
CODE_D1CF:
   LDA #$FF                 
   STA $04  
   SEC

CODE_D1D4:  
   TYA                      
   BNE CODE_D1F5                
   BCC CODE_D1E9
   
   LDA $94,X                
   STA $90
   
   LDA $95,X                
   STA $91
   
   LDA $96,X                
   STA $92
   
   LDA $97,X                
   STA $93
  
CODE_D1E9:
   LDA $00                  
   AND #$08                 
   BEQ CODE_D1F5
   
   DEX                      
   DEX                      
   DEX                      
   DEX                      
   BPL CODE_D1A0
  
CODE_D1F5:
   RTS

CODE_D1F6:
   LDA $94,X                
   BEQ CODE_D1A9
   
CODE_D1FA:
   LDA $90,Y              
   BNE CODE_D1CF
   
CODE_D1FF:
   CLC                      
   BCC CODE_D1D4                

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
;bit values that are used to skip tiles. if bit is not set, skip. values above mean: %11011000 - top left and bottom left are skipped (right platform's end), %11111100 - show full 3x2 animation, %01101100 - top right and bottom right are skipped.
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
   
   LDY #$01
   
   LDA $71
   CMP #$08
   BCC CODE_D31F
   
   LDY #$FF
   ORA #$F0
   EOR #$FF
   
CODE_D31F:
   CLC
   ADC $0D
   STA $0C
   
   STY $05F9
   RTS

;RNG_D328:
CODE_D328:
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

   LDA RandomNumberStorage			;$0500 contains random number (i don't think the output matters)
   RTS

CODE_D34A:
   LDA $2D					;wait a little
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
   STY Player2ScoreUpdate			;and his score

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
   STA $51					;phase complete
   STA LastEnemyFlag				;last enemy flag
   STA $05FB
   STA $05FC
   STA $43                  
   STA $44                  
   STA $45                  
   STA $46

   LDX #$03					;reset sound addresses

CODE_D3C6:
   STA Sound_Base,X				;
   DEX						;
   BPL CODE_D3C6				;

   LDA DemoFlag					;is it demo?
   BNE CODE_D3F5				;run it differently

   JSR CODE_D60F				;initialize lives
   JSR CODE_D5E6				;now load lives that should show up (player 1)
   JSR CODE_D5EC				;now for player 2

   LDA DisplayLevelNum				;if phase isn't first, we didn't start the game, play different sounds and stuff
   CMP #$01					;
   BNE CODE_D3ED				;

   LDA #$08					;
   STA GameplayMode				;gameplay mode = start phase

   LDA #$18					;wait a bit for music and stuff
   STA TransitionTimer				;

   LDA #Sound_Jingle_GameStart			;start game music
   STA Sound_Jingle				;

CODE_D3EA:
   JMP CODE_E13D				;enable display

 CODE_D3ED:
   LDA #Sound_Jingle_PhaseStart			;
   STA Sound_Jingle				;

   LDA #$0C					;shorter transition
   STA TransitionTimer				;

CODE_D3F5:
   INC GameplayMode				;next game state (gameplay)
   BNE CODE_D3EA				;and enable display

CODE_D3F9:
   JSR CODE_E132        			;call NMI and disable rendering    
   JSR CODE_CA20				;clear screen
   JSR CODE_CA2B				;remove all sprite tiles
   JSR CODE_D508				;draw main props (pipes, platforms and so on)
   JSR CODE_D61D				;show some initial strings

   INC GameplayMode  				;next gameplay state               
   RTS               				;       

CODE_D40B:
   JSR CODE_E132 				;turn off rendering 
   JSR CODE_CA20            			;clear screen
   JSR CODE_CA2B				;clear OAM

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
   BNE CODE_D47C				;always branch, though RTS would've fit in here (and it'd save 1 byte of space)

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
   LDA DATA_F823,X				;
   CMP #Demo_EndCommand				;if should end the demo
   BEQ CODE_D4F8				;end the demo (duh)
   STA Controller1InputPress			;store input

   INX						;
   LDA DATA_F823,X				;
   STA Demo_InputTimer_P1			;and how long to hold the input
   INX						;
   STX Demo_InputIndex_P1			;
   JMP CODE_D4D4				;now luigi

CODE_D4CA:
   DEY						;
   STY Demo_InputTimer_P1			;

   LDA $0310					;something about mario's direction?
   AND #$03					;
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

   LDA $0330					;something about luigi's direction?
   AND #$03					;
   STA Controller2InputPress			;

CODE_D4F5:
   JMP CODE_C5A3				;

CODE_D4F8:
   LDA #$05					;
   STA TransitionTimer				;

   INC NonGameplayMode				;

;MuteSounds_D4FE:
CODE_D4FE:
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

CODE_D56E:
   LDA $35
   CMP #$AA
   BEQ CODE_D58B
   CMP #$BB
   BEQ CODE_D58B
   
   LDA $2E
   BNE CODE_D58B
   
   LDA $41
   CMP #$02
   BEQ CODE_D588
   
   LDA $45
   CMP #$04
   BCS CODE_D58B

CODE_D588:
   JSR CODE_CEC3
   
CODE_D58B:
   RTS

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
   STA Player1ScoreUpdate			;draw player 1 score

   LDA TwoPlayerModeFlag			;check if in 2 player mode
   BEQ CODE_D5E5				;

   LDA #$01					;
   STA Player2ScoreUpdate			;draw luigi's score

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

CODE_D5DC:
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
   LDX Player1Lives				;load number of player 1's lives to display

   LDY #Lives_Mario_OAM_Slot*4			;OAM offset
   BNE CODE_D5F0				;Always branch

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
;InitLives_D60F:
CODE_D60F:
   LDY #$00					;

CODE_D611:   
   LDA DATA_F671,Y				;load in next order: Y-pos, sprite tile, tile prop, X-pos
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
   JSR CODE_D139				;but also make sure there's no hex (e.g. if 1A, change to 20)
   STA CurrentPhase				;

CODE_D67E:
   RTS						;

;supposed to initialize players!
CODE_D67F:
   LDY #$1F					;offset for player 1
   LDX #$1F

   LDA Player2GameOverFlag			;is luigi in the game?
   BNE CODE_D68F				;no, only init mario

   LDX #$3F					;can take luigi's props

   LDA Player1GameOverFlag			;is mario in the game?
   BNE CODE_D68F				;if not, luigi only

   LDY #$3F					;init both players

CODE_D68F:
   LDA DATA_F2EC,X				;
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

   LDA $34					;enemy level?
   JSR CODE_CC29				;get pointer

   LDA $12					;store pointer
   STA $36					;

   LDA $13					;
   STA $37					;

   LDA #$00					;initialize index for enemy table
   STA $35					;

   LDY #$00					;
   LDA ($36),Y					;load time for enemy to spawn upon phase load
   STA PipeDelayTimer				;
   RTS						;

;sets up graphical pointers and checks some stuff...
CODE_D6BA:
   LDA CurrentEntity_ID				;low nibble is only used by player entities
   AND #$0F					;
   BNE CODE_D710				;

   LDA CurrentEntity_ID				;
   LDX #<DATA_F584				;
   LDY #>DATA_F584				;
   CMP #Entity_ID_Shellcreeper			;
   BEQ CODE_D6E6				;

   LDX #<DATA_F58C				;
   LDY #>DATA_F58C				;
   CMP #Entity_ID_Sidestepper			;
   BEQ CODE_D6E6				;
   
   LDX #<DATA_F596				;$96                 
   LDY #>DATA_F596				;$F5                 
   CMP #Entity_ID_Fighterfly
   BEQ CODE_D6E6
   
   LDX #<DATA_F59E				;$9E                 
   LDY #>DATA_F59E				;$F5                 
   CMP #Entity_ID_Freezie
   BEQ CODE_D6E6
   
   LDX #<DATA_F5A4				;$A4                 
   LDY #>DATA_F5A4				;$F5
  
CODE_D6E6:
   STX $06                  
   STY $07
   
   LDA $C0                  
   BNE CODE_D6F1                
   JMP CODE_D73C

CODE_D6F1:  
   AND #$0F                 
   CMP #$02                 
   BNE CODE_D6FA                
   JMP CODE_D7C2

CODE_D6FA:
   CMP #$03                 
   BNE CODE_D701                
   JMP CODE_D80E

CODE_D701:
   CMP #$05                 
   BNE CODE_D708                
   JMP CODE_D855

CODE_D708:  
   CMP #$06                 
   BNE CODE_D70F                
   JMP CODE_D885

CODE_D70F:  
   RTS
  
CODE_D710:
   LDA $B1                  
   AND #$C0                 
   BNE CODE_D70F                
   JSR CODE_D90D                
   CMP #$02                 
   BNE CODE_D70F
   
   LDA $00                  
   STA $C1
   
   LDA $B1                  
   ORA #$80                 
   STA $B1

   LDA #$AD                 
   STA $BC
   
   LDA #$F5                 
   STA $BD
   
   LDA $B1                  
   AND #$08                 
   BEQ CODE_D70F
   
   LDA #$00                 
   STA $BB                  
   JMP CODE_C884
  
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
   CMP #GFX_AnimationCycle_SidestepperAngry	;
   BCC CODE_D753				;no, make it mad
   JMP CODE_D877				;yes, flip it

CODE_D753:
   LDA #GFX_AnimationCycle_SidestepperAngry	;sidestepper now appears angery
   STA CurrentEntity_AnimationPointer		;

   INC $C4                  
   JSR CODE_CAB9
   
   LDA $05F8                
   AND #$03                 
   STA $C1
   
   LDA #$04                 
   BNE CODE_D797

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
   LDA $9F
   STA $CC

CODE_D789:
   LDY #$04					;remove coin's sprite tiles... 4 tiles???
   JSR CODE_DFC4
   
   LDA #$06					;bits 1 and 2...
   BNE CODE_D797

CODE_D792:  
   JSR CODE_EE82

   LDA #$01					;the enemy can be kicked!

CODE_D797:   
   ORA $00
   STA $C0

   LDY #$04                 
   
CODE_D79D:
   JSR CODE_D9E0
   
   LDA $B1					;make immobile?
   AND #$3F					;
   ORA #$80					;
   STA $B1					;
   
   LDY #$00
   
CODE_D7AA:
   LDA ($06),Y              
   STA $BC
   
   INY                      
   LDA ($06),Y              
   STA $BD 
   
   LDA $C0					;did the enemy get hit (become kickable)?
   AND #$0F					;
   CMP #$01					;
   BNE CODE_D7C1				;if not, no sound

   LDA Sound_Effect2				;
   ORA #Sound_Effect2_EnemyHit			;hit enemy sound
   STA Sound_Effect2				;

CODE_D7C1:  
   RTS                      

CODE_D7C2:
   JSR CODE_D90D                
   CMP #$01                 
   BEQ CODE_D7CE                
   CMP #$02                 
   BEQ CODE_D7E4                
   RTS
   
CODE_D7CE:
   JSR CODE_C9CB

   LDA #$03                 
   STA $C0

   LDA $B1                  
   AND #$BF                 
   STA $B1

   LDY #$02                 
   JMP CODE_D7AA

CODE_D7E0:
   LDA #$00                 
   STA $B3

CODE_D7E4:  
   JSR CODE_D9EA
   
   LDA #$00                 
   STA $B3
   
   LDA $BF                  
   CMP #$20                 
   BNE CODE_D7FE
   
   LDA #$10                 
   STA $B4
   
   LDA $C4                  
   BEQ CODE_D7FE                
   DEC $C4                  
   JSR CODE_CAB9

CODE_D7FE:  
   LDY #$06                 
   JSR CODE_D79D
   
   LDA $C0                  
   ORA #$0F                 
   ORA $00                  
   STA $C0                  
   JMP CODE_D851                
   
CODE_D80E:
   JSR CODE_D90D                
   CMP #$02                 
   BEQ CODE_D7E0
   
   JSR CODE_CAEB                
   JSR CODE_CCA0                
   CMP #$FF                 
   BEQ CODE_D831
   
   CMP #$00                 
   BNE CODE_D829
   
   JSR CODE_D9C5                
   JSR CODE_CCA0

CODE_D829:  
   STA $B6                  
   JSR CODE_CCA0     
   STA $B3                  
   RTS                      
  
CODE_D831:
   INC $C4                  
   JSR CODE_CAB9
   
   LDA #$00                 
   STA $B3                  
   STA $C0

   LDY #$06                 
   JSR CODE_D9E0

   LDA $BF                  
   CMP #$30                 
   BEQ CODE_D851                
   CMP #$20                 
   BNE CODE_D84F
   
   LDA #$10                 
   STA $B4

CODE_D84F:  
   INC $BB                  
   
CODE_D851:
   JSR CODE_D9B6
   RTS
   
CODE_D855:
   JSR CODE_D90D                
   CMP #$01                 
   BEQ CODE_D861                
   CMP #$02                 
   BEQ CODE_D871                
   RTS
   
CODE_D861:
   JSR CODE_C9CB
   
   LDA $B1                  
   AND #$FC                 
   ORA $C1                  
   STA $B1

   LDA #$00					;reset some bits
   STA $C0                  
   RTS                      

CODE_D871:
   LDA $B1                  
   AND #$BF                 
   STA $B1

CODE_D877:
   JSR CODE_EE82				;add score

   LDA #$01					;make side stepper kickable
   ORA $00					;
   STA $C0					;

   LDY #$08					;draw as flipped
   JMP CODE_D79D				;

CODE_D885:   
   JSR CODE_CCA0                
   CMP #$EE                 
   BEQ CODE_D8C1                
   CMP #$DD                 
   BEQ CODE_D8AF                
   CMP #$CC                 
   BEQ CODE_D89E
   
   LDY $51                  
   BNE CODE_D89D                
   CLC                      
   ADC $B8                  
   STA $B8
   
CODE_D89D:   
   RTS

CODE_D89E:
   JSR CODE_CCA0                
   STA $B5                  
   CMP #$05                 
   BNE CODE_D885
   
   LDY #$04                 
   JSR CODE_DFC4                
   JMP CODE_D885                
  
CODE_D8AF:
   JSR CODE_CCA0                
   STA $B6   
   CMP #$4D                 
   BNE CODE_D8C0                
   LDA $51                  
   BNE CODE_D904
   
   LDA #$02                 
   STA $B7

CODE_D8C0:   
   RTS                      

  
CODE_D8C1:  
   LDA $04B0
   BNE CODE_D904
   
   LDA $51                  
   BNE CODE_D904

   LDA $B8				;Y-position for currently processed entity?
   CLC                      
   ADC #$0B                 
   TAX

   LDY $B9				;X-position for currently processed entity?

   LDA $CC				;currently processed player?
   STA $11
   
   LDA $BF
   CMP #$80                 
   BEQ CODE_D8E5
   
   LDA #$00				;spawn score 800 for collected coin
   JSR CODE_EEE3
   
   LDY #$08				;add 800 to score counter
   BNE CODE_D8F1
  
CODE_D8E5:
   LDA #$05				;spawn score 500 for freezie defeat
   JSR CODE_EEE3
   
   LDA #$00                 
   STA $04C1
   
   LDY #$05				;add 500 to score counter

CODE_D8F1:  
   STY $00

   LDX $CC                  
   LDA #$01                 
   STA $9D,X                
   TXA                      
   ORA #$08                 
   STA $01

   JSR CODE_DE83                
   JMP CODE_ECA2
  
CODE_D904:
   LDA #$00                 
   STA $B0                  
   LDY #$04                 
   JMP CODE_DFC4                
   
CODE_D90D:
   LDA $BF                  
   AND #$0F                 
   BNE CODE_D91A                
   LDA $C2                  
   BEQ CODE_D91A                
   LDA #$00                 
   RTS
   
CODE_D91A:
   LDA POWPowerTimer				;something to do with POW?
   BNE CODE_D988
   
   LDA $CD                  
   JSR CODE_CAA4				;get which height the entity's on?
   CMP #$02                 
   BEQ CODE_D928

CODE_D927:   
   RTS

CODE_D928:
   LDX $BE                  
   LDY $B9                  
   JSR CODE_EC67                
   JSR CODE_D990

CODE_D932:   
   LDA $00                  
   CMP #$30                 
   BEQ CODE_D968
   
   LSR A                  
   LSR A           
   LSR A            
   LSR A
   
CODE_D93C: 
   STA $1E

   LDA $B1    
   STA $05F8                
   AND #$FC                 
   ORA $1E                  
   STA $B1

CODE_D949:  
   LDA $BF                  
   AND #$F0                 
   BEQ CODE_D965
   
   LDY $C8                  
   BEQ CODE_D965                
   CMP #$30                 
   BEQ CODE_D961
   LDY #$03                 
   CMP #$20                 
   BEQ CODE_D95F                
   LDY #$06
   
CODE_D95F:
   STY $B5
  
CODE_D961:
   LDA #$00                 
   STA $C8

CODE_D965:  
   LDA #$02                 
   RTS

CODE_D968:  
   LDA $BF                  
   AND #$0F                 
   BNE CODE_D949
   
   LDA $B1                  
   AND #$03                 
   BEQ CODE_D93C                
   EOR #$03                 
   JMP CODE_D93C                
   
CODE_D979:
   LDA $CD                  
   JSR CODE_CAA4                
   CMP #$00         
   BEQ CODE_D927                
   LDA #$30                 
   STA $00                  
   BNE CODE_D932
   
CODE_D988:
   LDY POWWhoHit			;get player's entity ID
   DEY					;-1 because Mario's ID is 1 and Luigi's 2
   STY PlayerPOWScoreUpdate		;
   JMP CODE_D979			;
   
CODE_D990:
   LDA $32                  
   ASL A
   STA $00
   ASL A                    
   ASL A                    
   ASL A                    
   CLC                      
   ADC $00                  
   ADC #$A0
   
CODE_D99D:
   LDY #$03

CODE_D99F:   
   DEY                      
   CMP $CD                  
   BEQ CODE_D9AD                
   CLC                      
   ADC #$01                 
   CPY #$00                 
   BNE CODE_D99F                
   BEQ CODE_D99D

CODE_D9AD:  
   LDA DATA_D9B3,Y              
   STA $00                  
   RTS                      

DATA_D9B3:
.db $10,$30,$20

CODE_D9B6:
   PHA

CODE_D9B7:   
   LDY $BB                  
   LDA DATA_F638,Y              
   CMP #$FF                 
   BNE CODE_D9D4                
   DEC $BB                  
   JMP CODE_D9B7                

CODE_D9C5:
   PHA
   LDY $BB                  
   INY

CODE_D9C9:   
   LDA DATA_F638,Y              
   CMP #$FF                 
   BNE CODE_D9D4                
   DEY                      
   JMP CODE_D9C9                
   
CODE_D9D4:
   STA $1E
   
   LDA $B7                  
   AND #$E0                 
   ORA $1E                  
   STA $B7
   
   PLA                      
   RTS
   
CODE_D9E0:
   LDA ($06),Y              
   STA $B6                  
   INY
   
   LDA ($06),Y              
   STA $B5                  
   RTS                      
   
CODE_D9EA:
   LDA $B1                  
   LDY #$40                 
   LSR A                    
   BCS CODE_D9F3                
   LDY #$00

CODE_D9F3:   
   STY $1E

   LDA $B7                  
   AND #$BF                 
   ORA $1E                  
   STA $B7    
   RTS
   
CODE_D9FE:
   LDY $B9                  
   LDA $C2                  
   BNE CODE_DA61
   
   LDA $BE                  
   BEQ CODE_DA09                
   RTS
   
CODE_DA09:
   LDA $BF                  
   CMP #$30                 
   BNE CODE_DA32
   
   LDA $B1                  
   AND #$C0                 
   BNE CODE_DA1E
   
   LDA $B1                  
   LSR A                    
   BCS CODE_DA1F                
   CPY #$40                 
   BCC CODE_DA24
  
CODE_DA1E:
   RTS

CODE_DA1F:
   CPY #$C0                 
   BCS CODE_DA24                
   RTS                      

CODE_DA24:
   LDA $B1                  
   ORA #$80                 
   STA $B1
   
   LDA #<DATA_F64D			;$4D                 
   LDY #>DATA_F64D			;$F6 
   LDX #$03                 
   BNE CODE_DA46                

CODE_DA32:
   LDA $B1                  
   LSR A                    
   BCS CODE_DA3C                
   CPY #$28                 
   BCC CODE_DA40
   
CODE_DA3B:   
   RTS                      

CODE_DA3C:
   CPY #$D8                 
   BCC CODE_DA3B
   
CODE_DA40:
   LDA #<DATA_F643			;$43                 
   LDY #>DATA_F643			;$F6                 
   LDX #$02                 

CODE_DA46:
   STA $BC                  
   STY $BD
   
   LDA $B1                  
   AND #$03                 
   STA $C2
   
   LDA $B7                  
   ORA #$20                 
   STA $B7
   
   STX $B2                  
   LDA #$01                 
   STA $C5
   
   LDA #$00                 
   STA $C7                  
   RTS    

CODE_DA61:
   BPL CODE_DAA5                
   LSR A                    
   BCC CODE_DA75                
   CPY #$38                 
   BCS CODE_DA6D
   
CODE_DA6A:
   JMP CODE_DB1E

CODE_DA6D:  
   LDA #$00                 
   STA $05FB                
   JMP CODE_DA7E

CODE_DA75:  
   CPY #$C8                 
   BCS CODE_DA6A
   
   LDA #$00                 
   STA $05FC

;the entity has come out of the pipe fully
CODE_DA7E:  
   JSR CODE_DB34				;play appropriate sound for the entity that's exiting the pipe
   JSR CODE_CAB9
   
   LDA $B7                  
   AND #$DF                 
   STA $B7

   LDA #$00                 
   STA $C2

   LDA CurrentEntity_ID				;check if the entity is a fighter fly
   CMP #Entity_ID_Fighterfly			;
   BNE CODE_DAC0				;

   LDA #<DATA_F37B				;$7B
   LDY #>DATA_F37B				;$F3                 
   STA $BC					;
   STY $BD					;

   LDA $B1					;yeah, IDK what bit is set
   AND #$3F					;
   ORA #$40					;
   STA $B1					;
   RTS						;

CODE_DAA5:  
   JSR CODE_DB1E                
   JSR CODE_CCA0                
   CMP #$AA                 
   BEQ CODE_DAC1                
   TAY
   
   LDA $BF                  
   CMP #$30                 
   BNE CODE_DABA
   
   LDA $B3                  
   BNE CODE_DAC0
  
CODE_DABA:
   TYA                      
   CLC                      
   ADC $B8                  
   STA $B8

CODE_DAC0:  
   RTS

;entity enters inside the pipe
CODE_DAC1:   
   LDY CurrentEntity_XPos
   LDA $C2					;see if the entity has entered bottom-right pipe
   LSR A					;
   BCS CODE_DAE3				;yes,check if fully inside
   CPY #$18					;see if fully inside of the pipe
   BCS CODE_DAC0				;no, return
   
   LDA #$10					;
   STA CurrentEntity_XPos			;place entity inside the top-left pipe
   
   LDA $05FB					;the entity is hidden flag
   BNE CODE_DB19				;if it is, move it in the area, where entitites can't render (except for some entities in overscan area)
   JSR CODE_DFD3				;some reinitialization?
   
   LDA #$01                 
   STA $05FB

   LDA #$28                 
   LDY #$01                 
   BNE CODE_DAFC
  
CODE_DAE3:
   CPY #$E8                 
   BCC CODE_DAC0
   
   LDA #$F0					;place in the top-right
   STA CurrentEntity_XPos
   
   LDA $05FC                
   BNE CODE_DB19
   JSR CODE_DFD3
   
   LDA #$01                 
   STA $05FC
   
   LDA #$D8
   LDY #$02
  
CODE_DAFC:
   STA $B9                  
   STY $B1
   
   LDA #$2C
   STA $B8                  
   TYA   
   ORA #$80                 
   STA $C2
   
   LDA #$03                 
   STA $B2
   
   LDA CurrentEntity_ID				;check what enemy is this...
   CMP #Entity_ID_Fighterfly			;fighterfly?
   BNE CODE_DB18				;if not, return
   TYA						;
   ORA #$80					;enable some bit, IDK
   STA $B1					;
  
CODE_DB18:
   RTS                      

CODE_DB19:
   LDA #$F4					;
   STA CurrentEntity_YPos			;remain hidden
   RTS						;

;gravity?
CODE_DB1E:
   PHA                      
   LDA $71                  
   BEQ CODE_DB2B
   
   LDA $05F9                
   CLC                      
   ADC $B8                  
   STA $B8
   
CODE_DB2B:
   PLA                      
   RTS                      
   
CODE_DB2D:
   LDA $C6                  
   BEQ CODE_DB33                
   DEC $C6
   
CODE_DB33:
   RTS

;Play appropriate sound for entity that's fully come out of the pipe
CODE_DB34:
   LDA CurrentEntity_ID					;
   LDX #Sound_Effect_ShellCreeperPipeExit		;
   CMP #Entity_ID_Shellcreeper				;
   BEQ CODE_DB4A					;

   LDX #Sound_Effect_SidestepperPipeExit		;
   CMP #Entity_ID_Sidestepper				;
   BEQ CODE_DB4A					;

   LDX #Sound_Effect_FighterFlyPipeExit			;
   CMP #Entity_ID_Fighterfly				;
   BEQ CODE_DB4A					;

   LDX #Sound_Effect_CoinPipeExit			;coins and freezies use this sound
  
CODE_DB4A:
;alternative code:
;  TXA
;  ORA Sound_Effect
;  STA Sound_Effect
;  RTS

   STX $1E						;

   LDA Sound_Effect					;
   ORA $1E						;play da sound effect
   STA Sound_Effect					;
   RTS							;

CODE_DB53:
   LDY $33
   DEY                      
   BEQ CODE_DB33
   STY $11
   
   LDA FrameCounter			;run something every other frame
   AND #$01                 
   BNE CODE_DB6B
    
   CPY #$03                 
   BEQ CODE_DB6A                
   CPY #$04                 
   BEQ CODE_DB6A			;this line is unecessary btw 
   BNE CODE_DB73
  
CODE_DB6A:
   RTS

CODE_DB6B:
   CPY #$03 
   BEQ CODE_DB73  
   CPY #$04
   BNE CODE_DB6A

CODE_DB73:  
   LDA $A0                  
   STA $14
   
   LDA $A1                  
   STA $15
   
   LDA $A2                  
   CLC                      
   ADC #$20                 
   STA $12
   
   LDA #$00                 
   STA $13
   
   JSR CODE_CDB4
   
   LDY #$05                 
   LDX #$07                 
   JSR CODE_C44A                
   AND #$0F                 
   BEQ CODE_DB6A
   STA $1F                  
   EOR #$03                 
   STA $1E
   
   LDA $C0                  
   ORA $C2                  
   ORA $C8                  
   BNE CODE_DBC6
   
   LDA $BF                  
   CMP #$80                 
   BNE CODE_DBAC
   
   LDA $C1                  
   BNE CODE_DBC6
  
CODE_DBAC:
   LDY #$19                 
   LDA ($14),Y              
   BNE CODE_DBFE
   
   LDA $B1                  
   AND #$03                 
   CMP $1E                  
   BEQ CODE_DBC6
   
   LDA $B1                  
   AND #$FC                 
   ORA $1E                  
   STA $B1
   
   LDA #$01                 
   STA $C8

CODE_DBC6:  
   LDY #$10                 
   LDA ($14),Y
   LDY #$12                 
   ORA ($14),Y
   LDY #$18                 
   ORA ($14),Y              
   BNE CODE_DBFE
   
   LDY #$0F                 
   LDA ($14),Y              
   CMP #$80                 
   BNE CODE_DBE2
   
   LDY #$11                 
   LDA ($14),Y              
   BNE CODE_DBFE
  
CODE_DBE2:
   LDA $C9    
   BNE CODE_DBFE
   
   LDY #$01                 
   LDA ($14),Y              
   AND #$03                 
   CMP $1F                  
   BEQ CODE_DBFE
   
   LDA ($14),Y              
   AND #$FC                 
   ORA $1F                  
   STA ($14),Y
   
   LDY #$18                 
   LDA #$01                 
   STA ($14),Y
  
CODE_DBFE:
   RTS                      

CODE_DBFF:
   LDA $B3                  
   BNE CODE_DBFE
   
   LDX $C8                  
   BEQ CODE_DBFE
   
   LDA $B1                  
   AND #$C0                 
   BNE CODE_DBFE
   
   LDA $BF                  
   CMP #$30                 
   BEQ CODE_DC55
   
   LDY #$09                 
   CMP #$20                 
   BEQ CODE_DC1F
   
   LDY #$00                 
   CMP #$10                 
   BNE CODE_DC50

CODE_DC1F:  
   DEX                      
   TXA                      
   STY $1E                  
   CLC                      
   ADC $1E                  
   TAY                      
   LDA DATA_F626,Y
   CMP #$01                 
   BEQ CODE_DC3B                
   CMP #$FF                 
   BEQ CODE_DC44                
   STA $B6
   
   LDA #$05                 
   STA $B5

CODE_DC38:  
   INC $C8                  
   RTS
  
CODE_DC3B:
   LDA $B7                  
   EOR #$40                 
   STA $B7
  
   JMP CODE_DC38
  
CODE_DC44:
   LDA $BF                  
   LDY #$03                 
   CMP #$20                 
   BEQ CODE_DC4E
   
   LDY #$06

CODE_DC4E:   
   STY $B5                  
   
CODE_DC50:
   LDA #$00                 
   STA $C8                  
   RTS                      
  
CODE_DC55:
   CPX #$01                 
   BNE CODE_DC6E
   
   LDA #<DATA_F37B			;$7B                 
   STA $BC
   
   LDA #>DATA_F37B			;$F3                 
   STA $BD
   
   LDA $B1                  
   AND #$3F                 
   ORA #$40                 
   STA $B1
   
   LDA #$02                 
   STA $C8                  
   RTS
  
CODE_DC6E:
   LDA $B1                  
   AND #$C0                 
   BEQ CODE_DC50                
   RTS
   
CODE_DC75:
   LDA #$40                 
   STA $14

   LDA #$03                 
   STA $15                  
   LDY #$08                 
   LDA $04B0                
   BEQ CODE_DC86
   
   LDY #$0A

CODE_DC86:  
   STY $11
   
   JSR CODE_C446                
   STA $1E                  
   ORA #$00
   BNE CODE_DC92

CODE_DC91:
   RTS                      

CODE_DC92:
   LDA $C6                  
   BNE CODE_DC91
   
   LDY #$12                 
   LDA ($14),Y              
   BNE CODE_DC91
   
   LDY #$19                 
   LDA ($14),Y
   BNE CODE_DC91
   
   LDY #$0F                 
   LDA ($14),Y              
   CMP #$F0                 
   BEQ CODE_DCB9                
   CMP #$A0                 
   BEQ CODE_DCBC                
   CMP #$B0                 
   BEQ CODE_DCBF                
   CMP #$40                 
   BNE CODE_DCC2

   JMP CODE_DDC7
  
CODE_DCB9:
   JMP CODE_E29A
  
CODE_DCBC:  
   JMP CODE_E9B8				;
  
CODE_DCBF:  
   JMP CODE_E9B8              			;wait a sec, 2 indentical JMPs???
  
CODE_DCC2:
   LDY #$10					;(Entity_Address+10, for example if entity 0 thats $0310)
   LDA ($14),Y					;
   AND #$0F					;
   BEQ CODE_DCCE
  
   CMP #$04					;check if enemy's flipped?
   BCC CODE_DD2C				;kicked the enemy

;Hurt the player
CODE_DCCE:  
   LDA #$00
   STA $05FF

   LDY $BF					;check if current player is...
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
   LDA #$10					;player's state
   STA CurrentEntity_State			;got hit!

   LDA #$40					;
   STA CurrentEntity_Timer			;set the timer before dropping down

   LDA #GFX_Player_Hurt				;
   STA CurrentEntity_DrawTile			;

   LDA #Entity_Draw_16x24			;keep player as 16x24
   STA CurrentEntity_DrawMode			;

   LDA #<DATA_F6A9				;$A9                 
   LDY #>DATA_F6A9				;$F6                 
   STA $BC					;some kinda pointer
   STY $BD					;
   
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
   LDA #$20                 
   STA ($14),Y              
   RTS 
  
CODE_DD2C:
   LDA LastEnemyFlag			;was it the last enemy?
   BEQ CODE_DD3C			;if not, just kick

   LDA #$00				;\disable all sounds, all enemies defeated!
   STA Sound_Effect			;|
   STA Sound_Jingle			;|
   STA Sound_Loop			;/

   LDA #Sound_Effect2_LastEnemyDead	;last enemy dead sound
   BNE CODE_DD40			;

CODE_DD3C:  
   LDA Sound_Effect2			;normal kick
   ORA #Sound_Effect2_EnemyKicked	;

CODE_DD40:  
   STA Sound_Effect2			;

   LDA #$10                 
   LDY #$19                 
   STA ($14),Y

   LDA #<DATA_F7E9			;$E9                 
   LDY #$0C                 
   STA ($14),Y
   
   LDA #>DATA_F7E9			;$F7                 
   INY                      
   STA ($14),Y              
   LDA $B1                  
   AND #$03                 
   BNE CODE_DD5E
   
   LDA $05F7                
   AND #$0F

CODE_DD5E:  
   LSR A                    
   BCS CODE_DD65                
   LDA #$FF                 
   BNE CODE_DD67
  
CODE_DD65:
   LDA #$00

CODE_DD67:  
   LDY #$15                 
   STA ($14),Y

   LDY #$02                 
   LDA #$01                 
   STA ($14),Y
   INY                      
   STA ($14),Y
  
   LDX #$02  
   
   LDY $BF     
   DEY                      
   STY $11
   BNE CODE_DD7F        
   
   LDX #$00

CODE_DD7F:  
   LDA $04D0,X				;most likely a combo chain timer!!!
   BNE CODE_DD89
  
   LDA #$00                 
   STA $04D1,X
  
CODE_DD89:
   LDA #$34                 
   STA $04D0,X

   LDA $04D1,X              
   STA $1F
   CMP #$03                 
   BEQ CODE_DD9A
   
   INC $04D1,X
   
CODE_DD9A:
   LDY #$08                 
   LDA ($14),Y              
   TAX                      
   INY                      
   LDA ($14),Y              
   TAY
   LDA $1F
   JSR CODE_EEE3				;spawn score based on kill combo
   
   LDX $1F					;and actually add score
   LDA DATA_DDB0,X				;
   JMP CODE_DDB6				;

DATA_DDB0:
.db $08,$16,$24,$32				;800, 1600, 2400 and 3200 respectively.

   LDA #$08					;unused?

CODE_DDB6:
   STA $00
   
   LDX $BF                  
   DEX                      
   LDA #$01                 
   STA $9D,X
   
   TXA                      
   ORA #$08                 
   STA $01                  
   JMP CODE_DE83                
  
CODE_DDC7:
   LDY #$10                 
   LDA ($14),Y              
   BNE CODE_DE04 
   TYA   
   LDY #$19                 
   STA ($14),Y
   
   LDX $BF                  
   DEX                      
   TXA
   
   LDY #$1C                 
   STA ($14),Y              
   LDA $FE                  
   ORA #$02                 
   BNE CODE_DE2C                
   
CODE_DDE0:
   LDA $B3                  
   CMP #$04 
   BCS CODE_DE04
   
   LDA $C6                  
   AND #$F0                 
   CMP #$20                 
   BEQ CODE_DE2F
   
   LDA #$38                 
   STA $B6
   
   JSR CODE_CCA0
   CMP #$AA                 
   BNE CODE_DDFB
   
   LDA #$03

CODE_DDFB:   
   CLC                      
   ADC $B8                  
   CMP #$E8
   BCS CODE_DE05

CODE_DE02:   
   STA $B8
   
CODE_DE04:
   RTS        

CODE_DE05:
   LDA #$20                 
   STA $C6
   
   LDA $BA                  
   JSR CODE_C3F5

CODE_DE0E:
   LDA #$01                 
   STA $B5                  
   STA $B3
   
   LDA #$38                 
   STA $B4
   
   LDA #$05                 
   STA $B2
   
   LDA #$E0                 
   STA $B8
   
   LDA #$03                 
   STA $B7
   
   LDA $46                  
   BNE CODE_DE2E

   LDA $FE                  
   ORA #$80

CODE_DE2C:   
   STA $FE
  
CODE_DE2E:
   RTS                      
   
CODE_DE2F:
   JSR CODE_CAEB                
   LDA $B6                  
   CMP #$BC                 
   BEQ CODE_DE3B 
   JMP CODE_CEA3

CODE_DE3B:
   LDY #$04                 
   JSR CODE_DFC4
   
   LDA $BF                  
   AND #$0F                 
   BEQ CODE_DE4E
   
   LDA #$01                 
   STA $C6
   
   LDA #$F4                 
   BNE CODE_DE02

CODE_DE4E:  
   LDA $51                  
   BEQ CODE_DE57
   
   LDA #$00                 
   STA $B0                  
   RTS
   
CODE_DE57:
   LDX $BA
   
   LDA $B9                  
   PHA                      
   LDY #$00

CODE_DE5E:   
   LDA DATA_F6C8,Y              
   STA $B0,Y
   
   INY                      
   CPY #$20                 
   BNE CODE_DE5E
   
   STX $BA

   PLA                      
   LDY #$01                 
   LDX #$F0                 
   CMP #$80                 
   BCS CODE_DE78                
   LDY #$02                 
   LDX #$10

CODE_DE78:  
   STY $C2                  
   STY $B1                  
   STX $B9                  
   LDY #$04                 
   JMP CODE_DFC4
   
CODE_DE83:
   LDA $30                  
   BNE CODE_DEAE
   
   LDX #$00                 
   STX $04
   
   LDX #$00           				 ;The hell???  you guys can't use one LDX #$00 for everything?   
   STX $05                  
   STX $06                  
   STX $07
   
   LDA $01                  
   AND #$08                 
   BNE CODE_DE9A                
   INX

CODE_DE9A:  
   LDA $00                  
   STA $06,X                
   LDA $01                  
   JMP CODE_D0B4
   
CODE_DEA3:
   LDX #$1F

CODE_DEA5:   
   LDA DATA_F2EC,Y              
   STA $B0,X                
   DEY                      
   DEX                      
   BPL CODE_DEA5

CODE_DEAE:   
   RTS

CODE_DEAF:
   LDA $C9                  
   AND #$F0                 
   CMP #$20                 
   BNE CODE_DEBA
   JMP CODE_DE2F

CODE_DEBA:  
   JSR CODE_CCA0                
   CMP #$AA                 
   BNE CODE_DEC3
   
   LDA #$04

CODE_DEC3:  
   CLC                      
   ADC $B8                  
   CMP #$E8                 
   BCS CODE_DEE0
   
   STA $B8                  
   JSR CODE_CCA0                
   CMP #$AA                 
   BEQ CODE_DEDF                
   EOR $C5                  
   BPL CODE_DEDA                
   CLC                      
   ADC #$01
  
CODE_DEDA:
   CLC                      
   ADC $B9                  
   STA $B9

CODE_DEDF:  
   RTS
  
CODE_DEE0:
   LDA #$20                 
   STA $C9
   
   LDY #$04                 
   JSR CODE_DFC4                
   JMP CODE_DE0E                
   
CODE_DEEC:
   LDA $C6                  
   LDY $BF                  
   CMP #$01                 
   BNE CODE_DF37
   
   DEY						;check which player's dead
   BNE CODE_DF24
   
   JSR CODE_D5E6
   
   LDA $49                  
   BEQ CODE_DF07

CODE_DEFE:
   LDA #$00                 
   STA $B0

   LDY #$06                 
   JMP CODE_DFC4

CODE_DF07:  
   LDY #$1F                 
   JSR CODE_DEA3
   
   JSR CODE_DF9D
   
   LDA #$74					;respawn x-pos for mario
   
CODE_DF11:
   STA CurrentEntity_XPos

   LDA #$09					;
   STA CurrentEntity_YPos			;

   LDA #Player_State_AppearAfterDeath		;
   STA CurrentEntity_State			;

   LDA Sound_Jingle				;appear at the top of the screen
   ORA #Sound_Jingle_PlayerReappear		;
   STA Sound_Jingle				;
   JMP CODE_CEBA				;

CODE_DF24:  
   JSR CODE_D5EC
   
   LDA $4D                  
   BNE CODE_DEFE
   
   LDY #$3F                 
   JSR CODE_DEA3                
   JSR CODE_DFAC

   LDA #$8C					;respawn x-pos for luigi
   BNE CODE_DF11

CODE_DF37:  
   CMP #$02                 
   BNE CODE_DF60

   JSR CODE_CAEB
   
   INC CurrentEntity_YPos			;move the player down with the platform

   JSR GetRespawnPlatOAM_DFB0			;
   
   INC RespawnPlatform_OAM_Y,X			;
   INC RespawnPlatform_OAM_Y+4,X		;move respawn platform down
   
   LDA CurrentEntity_YPos			;if the player is at this position, don't move down anymore
   CMP #$28					;
   BEQ CODE_DF50				;
   RTS						;
   
CODE_DF50:
   LDA #$04					;
   LDY CurrentEntity_ID				;state depending on which player
   DEY						;
   BEQ CODE_DF59				;
   
   LDA #$08					;

CODE_DF59:   
   STA CurrentEntity_State			;
   
CODE_DF5B:
   LDA #$FF					;
   STA CurrentEntity_Timer			;
   RTS						;

CODE_DF60:
   LDA CurrentEntity_Bits			;check player's bits
   BEQ CODE_DF87				;no bit set - keep on platform
   BMI CODE_DF6C				;jumped off - remove the platform
   AND #$08					;
   BNE CODE_DF87				;some kinda but that's supposed to keep the player on the platform
   BEQ CODE_DF72				;otherwise we've pressed a direction button, let the player go

CODE_DF6C:
   LDA #GFX_Player_Jumping			;show player's jumping frame
   STA CurrentEntity_DrawTile			;
   BNE CODE_DF75				;
  
CODE_DF72:
   JSR CODE_CEA3				;show a walking frame

CODE_DF75:
   LDA #$00					;
   STA CurrentEntity_State			;let the player go
   STA CurrentEntity_Timer			;no more platform timer

   JSR GetRespawnPlatOAM_DFB0			;get platform's OAM

   LDA #$F4					;remove platform
   STA RespawnPlatform_OAM_Y,X			;
   STA RespawnPlatform_OAM_Y+4,X		;

CODE_DF86:
   RTS						;

CODE_DF87:
   LDA CurrentEntity_Timer			;see if the platform should decease
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
   
CODE_DFBA:
   JSR CODE_DFBD
   
CODE_DFBD:
   INC $05FA
   INC $05FA
   RTS

;this routine is used to remove sprite tiles
;Input Y - amount of tiles to remove
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
   LDA $BF                  
   CMP #$40                 
   BNE CODE_DFF7
   
   LDY #$00                 
   LDA $C1                  
   BNE CODE_DFF5
   
   PLA                      
   PLA
   
   LDA $04C0                
   BEQ CODE_DFEE
   
   LDA $04C1                
   BNE CODE_DFEE                
   JMP CODE_ECAF
   
CODE_DFEE:
   STY $B0                  
   LDY #$02                 
   JMP CODE_DFC4
  
CODE_DFF5:
   STY $C1                  
   
CODE_DFF7:
   RTS

;used to draw game over string (if necessary)
CODE_DFF8:
   LDA BufferDrawFlag				;drawing something? anything?
   BNE CODE_DFF7				;return
   
   LDA $04C5					;some flag i don't know about?
   BNE CODE_DFF7				;return

   LDX #<DATA_E0A8				;load empty string by default     
   LDY #>DATA_E0A8				;

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
   LDX #<DATA_E088				;GAME OVER string for if both players have game overed (or just Mario in 1P mode)            
   LDY #>DATA_E088				;
     
   LDA Player1TriggerGameOverFlag		;show mario game over string?
   BEQ CODE_E058				;check luigi instead

   LDA $0300					;check if mario's active
   BNE CODE_E058				;yes? check luigi

   LDA TwoPlayerModeFlag			;check for player 2
   BEQ CODE_E03C				;

   LDA Player2GameOverFlag			;did luigi game over, too?
   BNE CODE_E03C				;if so, we're displaying GAME OVER

   LDX #<DATA_E078				;MARIO GAME OVER   
   LDY #>DATA_E078				;

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

   LDA $0320					;is luigi still on screen?
   BNE CODE_E077				;yes, return

   LDA TwoPlayerModeFlag			;are we in 2 player mode even?
   BEQ CODE_E06D				;no, don't even question
   
   LDA Player1GameOverFlag			;did player 1 game over as well?
   BNE CODE_E06D				;yes, show GAME OVER for both
   
   LDX #<DATA_E098				;LUIGI GAME OVER
   LDY #>DATA_E098				;

CODE_E06D:  
   LDA #$00					;showing game over string once
   STA Player2TriggerGameOverFlag		;

   LDA #$FF					;luigi game over
   STA Player2GameOverFlag			;
   BNE CODE_E044				;

CODE_E077:
   RTS						;
 
;Strings, use row format (CODE_CE2C)
;first byte = $1F - 1 line, F characters

;MARIO GAME OVER
DATA_E078:
.db $1F,$16,$0A,$1B,$12,$18,$24,$10
.db $0A,$16,$0E,$24,$18,$1F,$0E,$1B

;if both players are dead in 2P mode or 1 player in 1P
;   GAME OVER   
DATA_E088:
.db $1F,$24,$24,$24,$10,$0A,$16,$0E
.db $24,$18,$1F,$0E,$1B,$24,$24,$24

;LUIGI GAME OVER
DATA_E098:
.db $1F,$15,$1E,$12,$10,$12,$24,$10
.db $0A,$16,$0E,$24,$18,$1F,$0E,$1B

;Empty string
DATA_E0A8:
.db $1F,$24,$24,$24,$24,$24,$24,$24
.db $24,$24,$24,$24,$24,$24,$24,$24

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
;Second byte - unknown, platform tile offset?
;Third byte - wavy (green) fireball frequency (with lower values meaning low frequency)
;Forth byte - diagonal (red) fireball frequency
DATA_E0D0:
.db $00,$00,$00,$00
.db $01,$00,$00,$00

;TEST YOUR SKILL start with $AA.
;Second byte - ledge tile offset, $04 - slippery surface (i think)
;3rd byte - Time in seconds.
.db $AA,$03,$20

.db $02,$01,$00,$00
.db $03,$01,$01,$00
.db $04,$02,$01,$01
.db $05,$02,$01,$01
.db $AA,$04,$20

.db $06,$03,$02,$01
.db $07,$03,$02,$01
.db $08,$03,$02,$02
.db $09,$03,$02,$02
.db $AA,$04,$15					;from this phase, timer is set to 15 sec (altough it shows 20 for a few frames, before snapping to the intended value)

.db $0A,$03,$03,$02
.db $07,$03,$03,$02
.db $09,$03,$03,$03
.db $09,$03,$03,$04
.db $AA,$04,$15

.db $0A,$03,$03,$04
.db $07,$03,$03,$04
.db $09,$03,$03,$04
.db $09,$03,$03,$04
.db $FF

;Demo phase properties
.db $0B,$00,$00,$00

;this game mode is simply waiting a bit after which set next phase stored in GameplayModeNext
CODE_E129:
   LDA TransitionTimer				;check for timer
   BNE CODE_E131				;return if ticking

   LDA GameplayModeNext				;\set next gamemode
   STA GameplayMode				;/

CODE_E131:
   RTS						;
   
CODE_E132:
   JSR CODE_D5DC				;wait for NMI

   LDA Reg2001BitStorage			;\
   AND #$E7					;|turn off sprite and background display
   STA RenderBits				;/
   RTS						;

CODE_E13D:
   JSR CODE_D5DC				;wait for NMI
   
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
   
   LDA #$03					;after bonus POW is restored
   STA POWHitsLeft				;
  
CODE_E170:
   LDA #$BB                 			;
   STA $35					;some kinda timer?
   
   JSR CODE_D67F				;put in players
   
   LDA #$00					;
   STA $030A					;
   
   LDA #$18					;
   STA $032A					;
   
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
   STA $04F3					;timer index for wavy fireball frequency
   
   INX						;forth and last phase prop.
   LDA DATA_E0D0,X				;
   STA $04FC					;timer index for diagonal reflecting fireball frequency
   INX						;
   STX PhaseLoad_PropIndex			;store prop. index for next time we enter this routine
   
   LDA #$00					;reset "enemies to defeat" index (?)
   STA $35					;
   JSR CODE_E97A				;
   JSR CODE_D67F				;put players in the game!
   JSR CODE_D69A				;
   
CODE_E1C4:
   JSR CODE_D672				;next phase, add a +1 to the phase number
   JSR CODE_D3F9				;
   
   LDA #$02					;
   BNE CODE_E1F4				;
   
CODE_E1CE:
   LDA $35					;are there more enemies to spawn?
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

   LDY #$00                 
   LDA Player1ScoreUpdate			;see if we should update player 1's score
   BEQ CODE_E20F				;no, check player 2
   STY Player1ScoreUpdate			;update once ofc

   LDA #$F0					;some kinda offset?

CODE_E20A:   
   STA $00					;
   JMP CODE_D02F				;

CODE_E20F:
   LDA Player2ScoreUpdate			;
   BEQ CODE_E219				;
   STY Player2ScoreUpdate			;

   LDA #$F1					;
   BNE CODE_E20A				;

CODE_E219:
   RTS						;
   
CODE_E21A:
   LDA #$F9                 
   STA $00                  
   JSR CODE_D18B

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
   
   JSR CODE_D4FE				;no sounds
   
   LDA #Sound_Jingle_GameOver			;game over!
   STA Sound_Jingle				;
   
   LDA #$20					;
   STA TransitionTimer				;
   
   LDA #$0B					;game over state
   STA GameplayMode				;
   
   JMP CODE_CA2B				;remove all sprite tiles

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
   LDY #$10                 
   LDA ($14),Y              
   BNE CODE_E2AA
   
   LDA $BF                  
   STA ($14),Y 

   LDA $FE                  
   ORA #$02                 
   STA $FE

CODE_E2AA:  
   RTS
  
CODE_E2AB:
   LDA TESTYOURSKILL_Flag		;check TEST YOUR SKILL flag
   BNE CODE_E2B1			;
   RTS					;

CODE_E2B1:
   CMP #$01				;if initialized
   BNE CODE_E329			;run TEST YOUR SKILL!
   
   LDA #<Entity_Address+$40		;initialize coins starting from entity $02
   STA EntityDataPointer
   
   LDA #>Entity_Address
   STA EntityDataPointer+1				;the address 
   
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
   LDA DATA_E6C5,Y 
   CPY #$0A                 
   BNE CODE_E2E4
   
   LDA $11                  
   PHA                      
   CLC                      
   ADC #$10                 
   STA $11                  
   PLA                      
   JMP CODE_E2FD
  
CODE_E2E4:
   CPY #$09                 
   BNE CODE_E2ED
   
   LDA DATA_E6E5,X              
   BNE CODE_E2FD

CODE_E2ED:  
   CPY #$08                 
   BNE CODE_E2F6
   
   LDA DATA_E6E5+1,X              
   BNE CODE_E2FD
   
CODE_E2F6:
   CPY #$04                 
   BNE CODE_E2FD                
   LDA DATA_E6E5+2,X

CODE_E2FD:
   STA (EntityDataPointer),Y              
   INY                      
   CPY #$20                 
   BNE CODE_E2D1
   
   INX                      
   INX                      
   INX                      
   JSR CODE_CDB4
   
   DEC $33                  
   BNE CODE_E2CF
   
   LDA #$00					;\reset collected coins from bonus phase    
   STA Player1BonusCoins			;|Mario's
   STA Player2BonusCoins			;/Luigi's
   
   LDA #$40                 
   STA $04B3
   
   LDA #$01                 
   STA $04B2
   
   LDA #$0A					;max coins?
   STA $04BC					;
   INC $04B0					;don't init, animate (i think)
   RTS     
  
CODE_E329:
   LDA BonusTimeMilliSecs			;see if time's up
   BNE CODE_E36C				;if we have millisecs, count them down

   LDA BonusTimeSecs				;if we have seconds, count them down also
   BNE CODE_E34E				;

;otherwise time is up

CODE_E333:
   LDA #$01					;players can't move anymore
   STA DisableControlFlag			;

   LDA #$00                 
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
   JSR CODE_D15A				;-1 sec (decimal)
   STA BonusTimeSecs				;
   
   LDA #$09					;
   STA BonusTimeMilliSecs			;9 millisecs for every second
   BNE CODE_E374				;
  
CODE_E36C:
   DEC BonusTimeMilliSecs_Timing		;decrease millisecs every x frames
   BNE CODE_E3AE				;
   
   DEC BonusTimeMilliSecs			;-1 millisecond
  
CODE_E374:
   LDA #$06					;
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

;animate coins?
CODE_E3AE:
   LDX #$40                 
   LDY #$03                 
   LDA $2F                  
   LSR A                    
   BCC CODE_E3BB

   LDX #$E0                 
   LDY #$03
  
CODE_E3BB:
   STX $A0                  
   STY $A1
   
   LDA #$05                 
   STA $33
   
   LDA #$00                 
   STA $A2
   
CODE_E3C7:
   JSR CODE_CB9B
   
   LDA $B0                  
   BEQ CODE_E3E3
   
   LDA $C0                  
   BNE CODE_E3F3
   
   LDA $B3                  
   BNE CODE_E3E0
   
   LDA $B2                  
   STA $B3                  
   JSR CODE_CE95
   
CODE_E3DD:
   JSR CODE_CBC4
  
CODE_E3E0:
   JSR CODE_CBB6
  
CODE_E3E3:
   JSR CODE_CBAE
   
   DEC $33                  
   BNE CODE_E3C7
   
   LDA $04BC                
   BNE CODE_E3F2
   JMP CODE_E333

CODE_E3F2:   
   RTS                      
   
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
   LDA #<DATA_F6E8				;           
   STA $BC
   
   LDA #>DATA_F6E8				;       
   STA $BD
   
   LDA #$07                 
   STA $B5
   
   LDY #$02                 
   JSR CODE_DFC4
   
   LDA #$08                 
   STA $C0
   
   LDA #$9E                 
   STA $B6                  
   BNE CODE_E3E0
  
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
   
   STA $B5                  
   CMP #$05                 
   BNE CODE_E41E
   
   LDY #$04                 
   JSR CODE_DFC4                
   JMP CODE_E41E
  
CODE_E440:
   JSR CODE_CCA0                
   STA $B6                  
   JMP CODE_E3DD

CODE_E448:  
   DEC $04BC                
   LDY #$04                 
   JSR CODE_DFC4                
   JMP CODE_E3E3

CODE_E453:
   JSR CODE_E1F7				;run "update score" routine

   LDA TESTYOURSKILL_CoinCountPointer		;
   JSR CODE_CD9E				;execute pointers

DATA_E45C:
.dw CODE_E464					;bonus end init
.dw CODE_E48A					;count mario's coins
.dw CODE_E49A					;count luigi's coins
.dw CODE_E4AA					;bonus/no bonus

CODE_E464:
   JSR CODE_E132				;turn off rendering & wait for NMI to occur
   JSR CODE_CA20				;clear screen
   JSR CODE_CA3B				;VRAM attributes and maybe something else  
   JSR CODE_CA2B				;clear OAM
   JSR CODE_D5BE				;draw some HUD elements
   JSR CODE_D60F				;prepare OAM slots for lives
   JSR CODE_D5E6				;set Mario's lives Y-position
   JSR CODE_D5EC				;same for Luigi
   JSR CODE_E13D				;wait for NMI and enable rendering
   
   LDA #$00					;zero out RAM addresses for next state
   STA $04BA					;some other pointer
   STA $2B					;timer

   INC TESTYOURSKILL_CoinCountPointer		;to the next state

CODE_E489:   
   RTS						;
   
CODE_E48A:
   LDA $2B					;wait for timer
   BNE CODE_E489				;
   
   LDA TESTYOURSKILL_CoinCountSubPointer	;execute Mario's pointers
   JSR CODE_CD9E				;
   
DATA_E494:
.dw CODE_E51A					;show Mario
.dw CODE_E5CE					;count his coins
.dw CODE_E670

CODE_E49A:
   LDA GeneralTimer2B				;wait for a bit...
   BNE CODE_E489				;
   
   LDA $04BA					;
   JSR CODE_CD9E				;
   
DATA_E4A4:
.dw CODE_E554					;show Luigi
.dw CODE_E646					;count his coins
.dw CODE_E6B8

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

   LDA #$08					;give score (mario)
   STA $01					;
   JSR CODE_DE83				;

CODE_E4ED:
   LDA Player2GameOverFlag			;is 2nd player alive and well?
   BNE CODE_E4FC				;if not, just cut to the chase

   LDA $1E					;luigi also deserves score! Team work, yeah!
   STA $00

   LDA #$09					;give score (luigi)
   STA $01					;
   JSR CODE_DE83				;

;Load PERFECT!! string 
CODE_E4FC:
   LDX #<DATA_E5A4				;             
   LDY #>DATA_E5A4				;
   
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
   LDX #<DATA_E568				;MARIO string   
   LDY #>DATA_E568				;

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
  LDX #<DATA_E56E				;LUIGI string
  LDY #>DATA_E56E				;
  BNE CODE_E530					;

;various strings for coin counting after TEST YOUR SKILL!
;format: first byte - high nibble is number of rows, low nibble is amount of bytes per-row
;MARIO
DATA_E568:
.db $15
.db $16,$0A,$1B,$12,$18

;LUIGI
DATA_E56E:
.db $15
.db $15,$1E,$12,$10,$12

;init mario and luigi sprite tiles, for after TEST YOUR SKILL! screen
DATA_E574:
;mario
.db $40,GFX_Player_Standing+1,OAMProp_XFlip|OAMProp_Palette0,$20
.db $40,GFX_Player_Standing,OAMProp_XFlip|OAMProp_Palette0,$28
.db $48,GFX_Player_Standing+3,OAMProp_XFlip|OAMProp_Palette0,$20
.db $48,GFX_Player_Standing+2,OAMProp_XFlip|OAMProp_Palette0,$28
.db $50,GFX_Player_Standing+5,OAMProp_XFlip|OAMProp_Palette0,$20
.db $50,GFX_Player_Standing+4,OAMProp_XFlip|OAMProp_Palette0,$28

;luigi
.db $78,GFX_Player_Standing+1,OAMProp_XFlip|OAMProp_Palette1,$20
.db $78,GFX_Player_Standing,OAMProp_XFlip|OAMProp_Palette1,$28
.db $80,GFX_Player_Standing+3,OAMProp_XFlip|OAMProp_Palette1,$20
.db $80,GFX_Player_Standing+2,OAMProp_XFlip|OAMProp_Palette1,$28
.db $88,GFX_Player_Standing+5,OAMProp_XFlip|OAMProp_Palette1,$20
.db $88,GFX_Player_Standing+4,OAMProp_XFlip|OAMProp_Palette1,$28

;PERFECT!! (!! is a single character)
DATA_E5A4:
.db $18
.db $19,$0E,$1B,$0F,$0E,$0C,$1D,$67

;5000PTS,
DATA_E5AD:
.db $18
.db $05,$00,$00,$00,$19,$1D,$1C,$65

;3000PTS,
DATA_E5B6:
.db $18
.db $03,$00,$00,$00,$19,$1D,$1C,$65

;     NO BONUS.
DATA_E5BF:
.db $1E
.db $24,$24,$24,$24,$24,$17,$18,$24,$0B,$18,$17,$1E,$1C,$26 

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
   JSR CODE_D139				;add score
   BCC CODE_E6A0				;
   INC $05					;

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

DATA_E6C5:
.db $01,$01,$03,$00,$2C,$05,$A5,$02
.db $00,$00,$00,$00,$00,$00,$00,$F0
.db $00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$0F,$0F

DATA_E6E5:
.db $38,$24,$2C,$C8,$24,$2E,$18,$5A
.db $2D,$2C,$5A,$30,$D4,$5A,$30,$E8
.db $5A,$2D,$60,$8A,$2F,$A0,$8A,$2E
.db $28,$BA,$2D,$D8,$BA,$30

;X 800 string
DATA_E703:
.db $15
.db $21,$24,$08,$00,$00

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

   LDA WaveFireball_SpawnTimer			;
   BEQ CODE_E72D				;
   DEC WaveFireball_SpawnTimer			;

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

CODE_E73E:
   LDA $0300                
   BEQ CODE_E768
   
   LDA $0316                
   BNE CODE_E768
   
   LDX #$00                 
   LDA $030E
   
CODE_E74D:
   CMP $04F6,X              
   BNE CODE_E769
   
   INC $04F7,X 

   LDY #$F0                 
   LDA $3A                  
   BEQ CODE_E75D
   
   LDY #$3E
   
CODE_E75D:
   TYA                      
   CMP $04F7,X              
   BCS CODE_E768
   
   LDA #$01                 
   STA $04F8,X
  
CODE_E768:
   RTS

CODE_E769:   
   STA $04F6,X
   
   LDA #$00                 
   STA $04F7,X              
   RTS

CODE_E772:   
   LDA $0320                
   BEQ CODE_E768
   
   LDA $0336                
   BNE CODE_E768
   
   LDA $032E                
   LDX #$03                 
   BNE CODE_E74D                
   
CODE_E783:
   LDX #$03                 
   LDY #$00

CODE_E787:   
   LDA $04AC,X              
   STA $04A8,X              
   TYA                      
   STA $04AC,X              
   DEX                      
   BPL CODE_E787                
   RTS

CODE_E795:
   LDA $04B0                
   BNE CODE_E7AC
   
   LDA $04F3                
   BEQ CODE_E7AD
   
   LDY $46                  
   BEQ CODE_E7AC                
   CMP #$04                 
   BCC CODE_E7AC
   
   LDA #$04                 
   STA $04F3
   
CODE_E7AC:
   RTS

CODE_E7AD:  
   LDA $04BE                
   BNE CODE_E7BD
   
   JSR CODE_EEAD                
   JSR CODE_E9A0
   
   LDA #$01                 
   STA $04BE
  
CODE_E7BD:
   JSR CODE_E73E
   JSR CODE_E772
  
   LDA $0430                
   BEQ CODE_E7CB                
   JMP CODE_E86B
   
CODE_E7CB:
   LDA $0431                
   BEQ CODE_E7D6

   DEC $0431                
   JMP CODE_E805
   
CODE_E7D6:
   LDA $51                  
   BNE CODE_E805
   
   LDA $04F8                
   BNE CODE_E806
   
   LDA $04FB                
   BNE CODE_E84A
   
CODE_E7E4:
   LDX $042A                
   LDA $0428                
   CLC                      
   ADC #$FC                 
   STA $0200,X
   
   LDA $0426                
   STA $0201,X
   
   LDA $0427                
   STA $0202,X
   
   LDA $0429                
   CLC                      
   ADC #$FC                 
   STA $0203,X
  
CODE_E805:
   RTS

;prepare fireball spawn (the green one)
CODE_E806:
   LDX $030E                
   LDA $04A8,X              
   CMP #$08                 
   BCS CODE_E805
   
   LDA #$00                 
   STA $04F8                
   STA $04F7
   STX $042E
   
   LDA DATA_F0A1,X           
   STA $0428
   
   LDA $0309
   
CODE_E824:
   LDY #$18                 
   LDX #$01                 
   CMP #$80					;check player's x-speed
   BCS CODE_E830				;if on the right side of the screen, show far to the right
   
   LDY #$E8                 
   LDX #$02
   
CODE_E830:
   STY $0429                
   STX $0421
   
   LDA #$01                 
   STA $0430                
   JSR CODE_E96D
   
   LDX #<DATA_EFDB				;$DB                 
   LDY #>DATA_EFDB				;$EF

CODE_E842:   
   STX $042C                
   STY $042D                
   BNE CODE_E805

CODE_E84A:  
   LDX $032E                
   LDA $04A8,X              
   CMP #$08                 
   BCS CODE_E805
   STX $042E
   
   LDA DATA_F0A1,X              
   STA $0428
   
   LDA #$00                 
   STA $04FB                
   STA $04FA
   
   LDA $0329                
   JMP CODE_E824
   
CODE_E86B:
   CMP #$01                 
   BNE CODE_E893
   
   JSR CODE_EA25                
   BCC CODE_E877                
   JMP CODE_E952
   
CODE_E877:
   JSR CODE_E9D3                
   CMP #$FF                 
   BNE CODE_E889
   
   LDA #$10                 
   STA $0430

CODE_E883:
   LDX #<DATA_F01B				;$1B                 
   LDY #>DATA_F01B				;$F0
   BNE CODE_E842
  
CODE_E889:
   CMP #$00                 
   BEQ CODE_E890                
   STA $0426
   
CODE_E890:
   JMP CODE_E7E4

CODE_E893:  
   CMP #$02                 
   BNE CODE_E8D3
   
   JSR CODE_E9D3                
   CMP #$FF                 
   BNE CODE_E889
   
   JSR CODE_E973
   
   LDY #$00                 
   STY $0430                
   DEY
   
   LDA $3A                  
   BEQ CODE_E8AD                
   LDY #$80
  
CODE_E8AD:
   STY $0431

   LDA #$F4                 
   STA $0428
   
   LDX $042A                
   STA $0200,X              
   JMP CODE_E805

CODE_E8BE:
   LDA #$02					;
   STA $00					;
   
   LDX PlayerPOWScoreUpdate			;who hit the POW, gains score

   LDA #$01					;update score for said player
   STA PlayerScoreUpdate,X			;
   
   TXA                      
   ORA #$08                 
   STA $01                  
   JSR CODE_DE83

CODE_E8D0:   
   JMP CODE_E952

CODE_E8D3:  
   JSR CODE_EA25                
   BCS CODE_E8D0
   
   LDX $042E                
   LDA $04A8,X              
   CMP #$09                 
   BCS CODE_E8D0
   
   LDA $0421                
   LSR A                    
   BCS CODE_E92E
   
   LDA $0429                
   CMP #$10                 
   BCS CODE_E8F2
   
   JMP CODE_E952
   
CODE_E8F2:
   JSR CODE_E9D3                
   CMP #$AA                 
   BEQ CODE_E883
   CMP #$BB                 
   BNE CODE_E907
   
   JSR CODE_E95E                
   BNE CODE_E905

   JMP CODE_E8BE

CODE_E905:  
   LDA #$00
  
CODE_E907:
   DEC $0429

CODE_E90A:   
   CLC                      
   ADC $0428   
   STA $0428
   
CODE_E911:
   LDX $0424                
   LDA DATA_F4B2,X
   CMP #$FF                 
   BNE CODE_E925
  
   INX                      
   LDA DATA_F4B2,X              
   STA $0424                
   JMP CODE_E911
  
CODE_E925:
   STA $0426                
   INC $0424                
   JMP CODE_E7E4
  
CODE_E92E:
   LDA $0429                
   CMP #$F4                 
   BCS CODE_E952
   
   JSR CODE_E9D3                
   CMP #$AA                 
   BEQ CODE_E948
   CMP #$BB                 
   BNE CODE_E94D
   
   JSR CODE_E95E                
   BNE CODE_E94B
   
   JMP CODE_E8BE
  
CODE_E948:
   JMP CODE_E883

CODE_E94B:  
   LDA #$00
  
CODE_E94D:
   INC $0429                
   BNE CODE_E90A
  
CODE_E952:
   LDA #$02                 
   STA $0430
   
   LDX #$06                 
   LDY #$F0                 
   JMP CODE_E842                

CODE_E95E:
   LDA $0428                
   JSR CODE_EEA5

   LDY $0429                
   JSR CODE_EC67                
   ORA #$00					;right...
   RTS

;enable fireball sound
CODE_E96D:
   LDA Sound_Loop				;
   ORA #Sound_Loop_Fireball			;
   BNE CODE_E977				;

;disable fireball sound
CODE_E973:
   LDA Sound_Loop				;
   AND #$FF-Sound_Loop_Fireball			;IDK how to EOR in assembler

CODE_E977:   
   STA Sound_Loop				;
   RTS						;

CODE_E97A:   
   LDA $04F3                
   LDY $3A                  
   BEQ CODE_E984                
   CLC                      
   ADC #$04
   
CODE_E984:
   TAX                      
   LDA DATA_F081,X              
   STA $04F3
   
   LDA $04FC                
   STA $04FD
   CPY #$00                 
   BEQ CODE_E998                
   CLC                      
   ADC #$04

CODE_E998:  
   TAX                      
   LDA DATA_F089,X              
   STA $04FC                
   RTS                      

CODE_E9A0:
   LDX #$1F
   
CODE_E9A2:
   LDA DATA_F061,X              
   STA $0420,X              
   DEX                      
   BPL CODE_E9A2                
   RTS                      
   
CODE_E9AC:
   LDX #$1F

CODE_E9AE:   
   LDA DATA_EFBB,X              
   STA $0340,X              
   DEX                      
   BPL CODE_E9AE                
   RTS                      
   
CODE_E9B8:
   LDY #$10                 
   LDA ($14),Y              
   CMP #$10                 
   BNE CODE_E9D2

   LDA #$02                 
   STA ($14),Y

   LDY #$0C                 
   LDA #$06                 
   STA ($14),Y

   INY                      
   LDA #$F0                 
   STA ($14),Y
   
   JMP CODE_DCCE
  
CODE_E9D2:
   RTS  

CODE_E9D3:
   LDA #$00                 
   LDX $042C                
   LDY $042D                
   JSR CODE_E9FA                
   CMP #$CC                 
   BNE CODE_E9E8
   
   JSR CODE_E96D                
   JMP CODE_E9D3
  
CODE_E9E8:
   CMP #$DD                 
   BNE CODE_E9D2                
   JSR CODE_E973                
   JMP CODE_E9D3                
   
CODE_E9F2:
   LDA #$01                 
   LDX $034C                
   LDY $034D
   
CODE_E9FA:
   STA $1E                  
   STX $14                  
   STY $15
   
   LDY #$00                 
   LDA ($14),Y              
   STY $13                  
   INY                      
   STY $12
   
   JSR CODE_CDB4                
   PHA                      
   LDX $14                  
   LDY $15                  
   LDA $1E                  
   BNE CODE_EA1D                
   STX $042C                
   STY $042D                
   PLA                      
   RTS                      

CODE_EA1D:
   STX $034C                
   STY $034D                
   PLA                      
   RTS                      
   
CODE_EA25:
   LDA $51                  
   BNE CODE_EA2F                
   LDA $71                  
   BNE CODE_EA2F                
   CLC                      
   RTS

CODE_EA2F:
   SEC
   RTS
 
CODE_EA31:
   LDA $04B0
   BEQ CODE_EA37
   
CODE_EA36:
   RTS

;reflecting fireball
CODE_EA37:
   LDA $04FC					;timer for when fireball should appear
   BNE CODE_EA36				;return
   
   LDA ReflectingFireball_MainCodeFlag		;run main code for fireball
   BNE CODE_EA4C				;

   JSR CODE_EEAD				;init some stuff
   JSR CODE_E9AC				;set initial values for reflecting fireball entity
   
   LDA #$01					;set the flag
   STA ReflectingFireball_MainCodeFlag		;
  
CODE_EA4C:
   LDA $0430                
   BNE CODE_EA54                
   JSR CODE_E973

CODE_EA54:  
   LDA $0350                
   CMP #$10                 
   BEQ CODE_EA97                
   CMP #$01                 
   BEQ CODE_EA91                
   CMP #$02                 
   BEQ CODE_EA94
   
   LDA #$28                 
   STA $0348
   
   LDA #$50                 
   STA $0349
   
   LDA $0342                
   BNE CODE_EA79
   
   LDA #$02                 
   STA $0355                
   BNE CODE_EA7C
  
CODE_EA79:
   DEC $0342

CODE_EA7C:  
   JSR CODE_EA25                
   BCS CODE_EA90
   
   LDA #$01                 
   LDX #<DATA_EF9D				;$9D                 
   LDY #>DATA_EF9D				;$EF
  
CODE_EA87:
   STA $0350                
   STX $034C                
   STY $034D

CODE_EA90:   
   RTS
   
CODE_EA91:
   JMP CODE_EC14

CODE_EA94:
   JMP CODE_EC30
   
CODE_EA97:
   JSR CODE_EA25
   BCC CODE_EA9F
   JMP CODE_EBE9
  
CODE_EA9F:
   LDA $0348                
   CMP #$18                 
   BCS CODE_EABD
   
   LDA $04FF                
   BNE CODE_EAB5
   
   LDA $0348
   CMP #$0C                 
   BCS CODE_EADF                
   JMP CODE_EBE9

CODE_EAB5:  
   LDA #$01

CODE_EAB7:   
   STA $0351                
   JMP CODE_EADF

CODE_EABD:  
   CMP #$D4                 
   BCC CODE_EAC5
   
   LDA #$00                 
   BEQ CODE_EAB7

CODE_EAC5:  
   LDA $0349                
   CMP #$0C                 
   BCS CODE_EAD3
   
   JSR CODE_EEBC
   
   LDA #$00                 
   BEQ CODE_EADC

CODE_EAD3:  
   CMP #$F8                 
   BCC CODE_EAE2                
   JSR CODE_EECC
   
   LDA #$01

CODE_EADC:  
   STA $0341

CODE_EADF:  
   JSR CODE_E96D

CODE_EAE2:  
   LDA $034B                
   BEQ CODE_EAED                
   DEC $034B
   
   JMP CODE_EB6B
  
CODE_EAED:
   LDA $035B                
   JSR CODE_CAA4        
   CMP #$00                 
   BEQ CODE_EB6B                
   CMP #$02                 
   BNE CODE_EB1C
   
   LDA $0348                
   JSR CODE_EEA5
   
   LDY $0349                
   JSR CODE_EC67
   
   LDA #$10                 
   STA $00
   
   LDX $9F
   
   LDA #$01                 
   STA $9D,X                
   TXA                      
   ORA #$08                 
   STA $01

   JSR CODE_DE83                
   JMP CODE_EBE9
  
CODE_EB1C:
   JSR CODE_E96D
   
   JSR CODE_D328                
   AND #$01                 
   CLC                      
   ADC $0343                
   STA $0343
   
   LDA #$08                 
   STA $034B
   
   LDX #$00

CODE_EB32:   
   LDA DATA_F574,X              
   CMP $0357                
   BNE CODE_EB42
   
   LDA DATA_F574+1,X              
   CMP $0358                
   BEQ CODE_EB4A

CODE_EB42:  
   INX                      
   INX                      
   CPX #$10                 
   BNE CODE_EB32                
   BEQ CODE_EB53

CODE_EB4A:  
   CPX #$08                 
   BCC CODE_EB5E                
   LDA $0341                
   BEQ CODE_EB63
  
CODE_EB53:
   LDA $0351                
   EOR #$01                 
   STA $0351                
   JMP CODE_EB6B
  
CODE_EB5E:
   LDA $0341                
   BEQ CODE_EB53

CODE_EB63:  
   LDA $0341                
   EOR #$01                 
   STA $0341
  
CODE_EB6B:
   LDY #$04                 
   LDA $0341                
   BEQ CODE_EB74                
   LDY #$FC
  
CODE_EB74:
   TYA                      
   CLC                      
   ADC $0349                
   STA $00
   
   LDY #$04                 
   LDA $0351                
   BNE CODE_EB84                
   LDY #$FC
  
CODE_EB84:
   TYA                      
   CLC                      
   ADC $0348                
   STA $01
   
   JSR CODE_CA7D

   LDA $00                  
   STA $0358                
   STA $0528
   
   LDA $01                  
   STA $0357                
   STA $0529
   
   LDA $0343                
   BNE CODE_EC13
   
   LDA $0342                
   STA $0343
   
   LDA $0348                
   LDY $0351                
   BNE CODE_EBB8                
   SEC                      
   SBC $0355                
   JMP CODE_EBBC

CODE_EBB8:
   CLC                      
   ADC $0355
  
CODE_EBBC:
   STA $0348
   
   LDA $0341                
   BNE CODE_EBC9                
   INC $0349                
   BNE CODE_EBCC
  
CODE_EBC9:
   DEC $0349

CODE_EBCC:  
   LDX $0344                
   LDA DATA_F4B2,X              
   CMP #$FF                 
   BNE CODE_EBE0                
   INX                      
   LDA DATA_F4B2,X              
   STA $0344                
   JMP CODE_EBCC

CODE_EBE0:  
   STA $0346                
   INC $0344                
   JMP CODE_EBF2

CODE_EBE9:  
   LDA #$02                 
   LDX #<DATA_F006				;$06                 
   LDY #>DATA_F006				;$F0                 
   JMP CODE_EA87

CODE_EBF2:  
   LDX $034A                
   LDA $0348                
   CLC
   ADC #$FC                 
   STA $0200,X
   
   LDA $0346                
   STA $0201,X
   
   LDA $0347                
   STA $0202,X              
   LDA $0349                
   CLC                      
   ADC #$FC                 
   STA $0203,X
  
CODE_EC13:
   RTS

CODE_EC14:   
   JSR CODE_E9F2                
   CMP #$FF                 
   BEQ CODE_EC25

CODE_EC1B:   
   CMP #$00                 
   BEQ CODE_EC13                
   STA $0346                
   JMP CODE_EBF2
  
CODE_EC25:
   LDA #$10                 
   STA $0350
   
   LDA #$1E						;bounce around for this long
   STA ReflectingFireball_Timer				;
   RTS							;

CODE_EC30:
   JSR CODE_E9F2                
   CMP #$FF                 
   BNE CODE_EC1B
   
   LDX $034A                
   LDA #$F4                 
   STA $0200,X
   
   LDA #$00                 
   STA $0350
   
   LDA $04FE                
   CMP #$02                 
   BEQ CODE_EC51                
   INC $04FE                
   LDA $04FE
  
CODE_EC51:
   LSR A                    
   LSR A                    
   LSR A                    
   LDY $3A                  
   BEQ CODE_EC5B                
   CLC                      
   ADC #$04
  
CODE_EC5B:
   CLC                      
   ADC $04FD                
   TAX                      
   LDA DATA_F089,X              
   STA $04FC                
   RTS                      

;check if the player have hit an entity with platform bump
;input:
;X - platform the entity's on
;Y - entity's x-pos that probably should make a contact with the bump.
;output:
;A - 0 = contact success, non-zero (FF in this case) = contact failure
CODE_EC67:
   LDA #$00					;
   STA $9F					;temporary counter for impacts
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
   INC $9F					;check next player probably

   LDY #$05					;luigi's impact
   LDA $9F					;got through both players?
   CMP #$02					;
   BNE CODE_EC6F				;not yet, loop

   LDA #$00					;
   STA $9F					;

   LDA #$FF					;epic fail, no entity has been affected
   RTS						;

CODE_ECA2:   
   LDA $04C0                
   BNE CODE_ECAA

CODE_ECA7:   
   JMP CODE_D904
   
CODE_ECAA:
   LDA $04C1                
   BNE CODE_ECA7

CODE_ECAF:
   LDA #$FF                 
   STA $04C2

   LDA #$01                 
   STA $04C1

   LDY $BA                  
   LDX #$1F

CODE_ECBD:   
   LDA DATA_ECCC,X              
   STA $B0,X                
   DEX                      
   BPL CODE_ECBD                
   STY $BA                  
   LDY #$04                 
   JMP CODE_DFC4                

DATA_ECCC:
.db $01,$00,$02,$00,$33,$05,$8C,$23
.db $00,$00,$00,$00,$4C,$F6,$00,$80
.db $00,$00,$01,$0A,$02,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$03

CODE_ECEC:
   LDA $BF                  
   CMP #$80                 
   BEQ CODE_ECFB
   
CODE_ECF2:
   JMP CODE_C6BF
   
   JSR CODE_DFBD      				;those are never referred to.          
   JMP CODE_C75A				;RIP?
  
CODE_ECFB:
   LDA $C0                  
   BNE CODE_ECF2
   
   LDA $04C2
   BEQ CODE_ED20
   
   DEC $04C2                
   BNE CODE_ECF2                
   JSR CODE_D328
   
   LDY #$01                 
   LDX #$F0                 
   AND #$01                 
   BEQ CODE_ED18                
   LDY #$02                 
   LDX #$10
  
CODE_ED18:
   STY $C2                  
   STY $B1                  
   STX $B9                  
   BNE CODE_ECF2
  
CODE_ED20:
   LDA $C1                  
   BNE CODE_ED6C
   
   LDA $B1                  
   AND #$C0                 
   BNE CODE_ECF2
   
   LDY $B9                  
   LDA $BE                  
   CMP #$01                 
   BEQ CODE_ED40                
   CMP #$02                 
   BNE CODE_ECF2                
   CPY #$80                 
   BNE CODE_ECF2
   
   LDA #$00                 
   LDX #$00                 
   BEQ CODE_ED50

CODE_ED40:  
   LDA #$09                 
   LDX #$01                 
   CPY #$30                 
   BEQ CODE_ED50  
   CPY #$D0                 
   BNE CODE_ECF2
   
   LDA #$10                 
   LDX #$02

CODE_ED50:  
   TAY                      
   LDA $04CD,X              
   BNE CODE_ECF2
   
   LDA #$01                 
   STX $04CC                
   TYA						;what was point of LDA #$01 then???       
   STA $04C6
   
   LDA #$00                 
   STA $04C5                
   STA $B1
   
   LDA #$80                 
   STA $C1                  
   BNE CODE_ECF2

;freezie explosion
CODE_ED6C:  
   DEC $C1					;if timer is zero, remove freezie, and change platform tiles to frozen ones
   BEQ CODE_EDAC				;
   
   LDA $C1                  
   LDY #Freezie_Explosion_Frame2
   CMP #$20                 
   BEQ CODE_ED9C                
   CMP #$40                 
   BNE CODE_EDA9

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
   JMP CODE_C6BF				;keep doing other entity functions?
  
CODE_EDAC:
   LDA BufferDrawFlag				;can't update?
   BNE CODE_EDE7				;keep them alive then
   
   LDA $75                  
   ORA $7A                  
   BNE CODE_EDE7
   STA $04CA
   
   LDY #$04                 
   JSR CODE_DFC4                
   JSR CODE_EF50
   
   LDA #$01                 
   STA $04C5
   LDX $04CC                
   STA $04CD,X
   
   LDA $04CD					;check freezie slots?
   AND $04CE                
   AND $04CF                
   BNE CODE_EDDD
   
   JSR CODE_ECAF                
   JMP CODE_EDA9
  
CODE_EDDD:
   LDA #$00					;
   STA FreezieCanAppearFlag			;don't appear anymore
   STA CurrentEntity_ActiveFlag			;freezie no more
   
   JMP CODE_C75A
  
CODE_EDE7:
   INC $C1                  
   BNE CODE_EDA9
   
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
   
   INX                      
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
.db >DATA_F763,<DATA_F763			;$F7,$63
.db >DATA_F76D,<DATA_F76D			;$F7,$6D
.db >DATA_F77B,<DATA_F77B			;$F7,$7B
.db >DATA_F78B,<DATA_F78B			;$F7,$8B
.db VRAMWriteCommand_Stop

.db >DATA_F79B,<DATA_F79B			;$F7,$9B
.db >DATA_F7A4,<DATA_F7A4			;$F7,$A4
.db >DATA_F7B3,<DATA_F7B3			;$F7,$B3
.db VRAMWriteCommand_Stop

.db >DATA_F7C2,<DATA_F7C2			;$F7,$C2
.db >DATA_F7CB,<DATA_F7CB			;$F7,$CB
.db >DATA_F7DA,<DATA_F7DA			;$F7,$DA
.db VRAMWriteCommand_Stop

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

;Keep checking for indirects after here...
CODE_EE82:
   LDA $00                  
   PHA
   
   LDA $06                  
   PHA
   
   LDA $07                  
   PHA
   
   LDA #$10                 
   STA $00                  
   LDX $9F

   LDA #$01                 
   STA $9D,X
   
   TXA                      
   STA $01                  
   JSR CODE_DE83
   
   PLA                      
   STA $07
   
   PLA                      
   STA $06
   
   PLA                      
   STA $00  
   RTS                      

CODE_EEA5:
   STA $B8                  
   JSR CODE_D019                
   LDX $BE                  
   RTS                      
   
CODE_EEAD:
   LDA $35                  
   CMP #$AA                 
   BNE CODE_EEB9
   
   LDA $45                  
   CMP #$04                 
   BCC CODE_EEBB

CODE_EEB9:  
   PLA						;terminate (return from routine that called this routine)
   PLA						;

CODE_EEBB:  
   RTS						;

CODE_EEBC:   
   JSR CODE_D328                
   AND #$07                 
   CLC                      
   ADC $0349                
   STA $0349
   
   INC $0348                
   RTS
   
CODE_EECC:
   JSR CODE_D328                
   AND #$03                 
   STA $07
   
   LDA $0349                
   SEC                      
   SBC $07                  
   STA $0349
   
   DEC $0348                
   DEC $0348                
   RTS

;spawn a score sprite
CODE_EEE3:
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

   LDY #$03					;
   LDA $11					;check which player triggered score
   BEQ CODE_EF16				;if it was Mario, set palette 3
   LDY #$02					;otherwise it's palette 2

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
   LDA #$40
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
   RTS                      

;related with freezie and freezing tiles (sprite tiles)
CODE_EF50:
   LDA $04CC
   ASL A
   ASL A                    
   ASL A                    
   ASL A                    
   TAX
   
   LDY #$00

CODE_EF5A:   
   LDA DATA_EF67,X
   STA $02B0,Y
   
   INX                      
   INY                      
   CPY #$10                 
   BNE CODE_EF5A                
   RTS                      
   
DATA_EF67:
.db $77,$8A,$03,$70,$77,$8B,$03,$78
.db $77,$8B,$43,$80,$77,$8A,$43,$88
.db $A7,$8A,$03,$20,$A7,$8B,$03,$28
.db $A7,$8B,$43,$30,$A7,$8A,$43,$38
.db $A7,$8A,$03,$C0,$A7,$8B,$03,$C8
.db $A7,$8B,$43,$D0,$A7,$8A,$43,$D8

;Sprite tile values for each score value.
DATA_EF97:
.db Score_8_Tile				;8 for 800
.db Score_16_Tile				;16 for 1600
.db Score_24_Tile				;24 for 2400
.db Score_32_Tile				;32 for 3200
.db Score_2_Tile				;2 for 200 (unused)
.db Score_5_Tile				;5 for 500

DATA_EF9D:
.db $9C,$00,$9D,$00,$9F,$00,$00 
.db $9D,$00,$9B,$00,$00,$92,$00,$00
.db $93,$00,$00,$94,$00,$00,$95,$00
.db $92,$00,$93,$00,$94,$00,$FF

;initial values for reflecting fireball
DATA_EFBB:
.db $01,$01,$03,$01,$3D,$07,$92,$02
.db $F4,$00,$04,$00,$00,$00,$00,$B0
.db $00,$01,$00,$00,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$04

DATA_EFDB:
.db $9C,$00,$9D,$00,$9F,$00,$9C,$00
.db $9D,$00,$9F,$00,$9C,$00,$9D,$00
.db $9F,$00,$9C,$00,$9D,$00,$9F,$00
.db $9C,$00,$9D,$00,$9F,$00,$9C,$00
.db $9D,$00,$9F,$00,$9C,$00,$9D,$00
.db $9B,$00,$FF

DATA_F006:
.db $9B,$00,$9C,$00,$9D,$00,$00,$9E
.db $00,$9F,$00,$9C,$00,$9D,$00,$00
.db $9E,$00,$9F,$00,$FF

DATA_F01B:
.db $00,$00,$FF,$FF,$DD,$FF,$FE,$FE
.db $FD,$FE,$FE,$FF,$FF,$00,$FF,$00
.db $FF,$00,$00,$00,$01,$00,$01,$00
.db $01,$01,$02,$02,$03,$02,$02,$01
.db $CC,$01,$01,$00,$00,$BB,$00,$00
.db $FF,$00,$FF,$FF,$DD,$FF,$FE,$FF
.db $FF,$FF,$FF,$00,$00,$00,$01,$01
.db $01,$02,$02,$01,$01,$CC,$01,$00
.db $01,$00,$00,$BB,$00,$AA

DATA_F061:
.db $01,$01,$00,$01,$3D,$07,$92,$01
.db $F4,$00,$00,$00,$00,$00,$00,$A0
.db $00,$80,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$04

DATA_F081:
.db $28,$1E,$0A,$05,$0F,$0A,$07,$03

DATA_F089:
.db $32,$32,$28,$26,$1E,$1E,$1C,$12
.db $28,$28,$1C,$12,$1C,$1C,$12,$0A
.db $1E,$14,$14,$12,$14,$12,$0A,$08
   
DATA_F0A1:
.db $CC,$9C,$6C,$3C

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Title screen tile layout data and attributes
;basically tilemap of title screen - logo and strings
;uses same data structure as other tables that use CODE_CE00
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DATA_F0A5:
.db $20,$83			;location to write to
.db $02				;amount of bytes to write in line
.db $76,$7A			;tiles to write

.db $20,$A3			;next location
.db $02				;amount of tiles
.db $77,$79			;tiles

.db $20,$9A			;etc.
.db $02
.db $7C,$7E

.db $20,$BA
.db $02
.db $7D,$7F

.db $21,$63
.db $02
.db $80,$82

.db $21,$83
.db $02
.db $81,$83

.db $21,$7A
.db $02
.db $84,$86

.db $21,$9A
.db $02
.db $85,$87

.db $20,$85
.db VRAMWriteCommand_Repeat|$0A
.db $7B

.db $20,$90
.db VRAMWriteCommand_Repeat|$0A
.db $7B

.db $21,$85
.db VRAMWriteCommand_Repeat|$0A
.db $89

.db $21,$90
.db VRAMWriteCommand_Repeat|$0A
.db $89

.db $20,$C3
.db $19				;this time we write 25 tiles in a row
.db $78,$24,$24,$68,$69,$69,$6B,$69,$68
.db $69,$68,$6B,$69,$24,$68,$69,$68
.db $69,$6B,$69,$6B,$69,$24,$24,$88

.db $20,$E6
.db $13				;this time 19 tiles
.db $68,$6A,$6A,$6E,$6A
.db $68,$6A,$68,$6E,$6A,$24,$68,$6A
.db $68,$6A,$6E,$6A,$6E,$71

.db $21,$06
.db $13
.db $68,$6A,$6A,$68,$6C,$68,$6D
.db $68,$6E,$6A,$24,$68,$6D,$68,$6D
.db $6E,$6A,$6F,$69

.db $21,$26
.db $13
.db $68,$6A,$6A,$6E,$6A,$68,$6A,$68,$6E
.db $6A,$24,$68,$6A,$68,$6A,$6E,$6A
.db $72,$6A

.db $21,$43
.db $19
.db $78,$24,$24,$68,$6A,$6A,$6E,$6A
.db $68,$6A,$68,$6F,$70,$24,$68,$70
.db $68,$6A,$6F,$70,$6F,$70,$73,$24,$88


;this is where strings are stored (1 PLAYER GAME A, 2 PLAYER GAME B, etc.)

;1 PLAYER GAME A
.db $22,$09
.db $0F
.db $01,$24,$19,$15,$0A,$22,$0E
.db $1B,$24,$10,$0A,$16,$0E,$24,$0A

;1 PLAYER GAME B
.db $22,$49
.db $0F
.db $01,$24,$19,$15,$0A
.db $22,$0E,$1B,$24,$10,$0A,$16,$0E
.db $24,$0B

;2 PLAYER GAME A
.db $22,$89
.db $0F
.db $02,$24,$19
.db $15,$0A,$22,$0E,$1B,$24,$10,$0A
.db $16,$0E,$24,$0A

;2 PLAYER GAME B
.db $22,$C9
.db $0F
.db $02,$24,$19,$15,$0A,$22,$0E,$1B,$24
.db $10,$0A,$16,$0E,$24,$0B

;(c)1983 NINTENDO CO.,LTD.
.db $23,$05
.db $16
.db $25,$01,$09,$08,$03,$24,$17
.db $12,$17,$1D,$0E,$17,$0D,$18,$24
.db $0C,$18,$28,$15,$1D,$0D,$26

;MADE IN JAPAN
.db $23,$4B
.db $0D
.db $16,$0A,$0D,$0E,$24,$12
.db $17,$24,$13,$0A,$19,$0A,$17

;finally, attributes to give our tiles some color
.db $23,$C8
.db $0F
.db $AA,$2A,$0A,$0A,$0A,$0A
.db $8A,$00,$FF,$30,$00,$00,$00,$00
.db $C0

.db $23,$D8
.db VRAMWriteCommand_Repeat|$08		;repeat 8 times same attribute
.db $FF

.db $23,$E0
.db VRAMWriteCommand_Repeat|$10
.db $55

.db $23,$F0
.db VRAMWriteCommand_Repeat|$08
.db $AA

.db VRAMWriteCommand_Stop		;end writing (finally)

;initialize platforms. do note that the tiles themselves aren't provided as they are stored from the address in RAM.
DATA_F1E7:
.db $21,$20
.db VRAMWriteCommand_Repeat|$0E

.db $21,$32
.db VRAMWriteCommand_Repeat|$0E

.db $21,$E8
.db VRAMWriteCommand_Repeat|$10

.db $22,$00
.db VRAMWriteCommand_Repeat|$04

.db $22,$1C
.db VRAMWriteCommand_Repeat|$04

.db $22,$A0
.db VRAMWriteCommand_Repeat|$0C

.db $22,$B4
.db VRAMWriteCommand_Repeat|$0C

.db VRAMWriteCommand_Stop

;more data, bottom bricks?
.db $23,$60
.db VRAMWriteCommand_Repeat|$20

.db $23,$80
.db VRAMWriteCommand_Repeat|$20

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DATA_F203 - Palette Data
;This is where Palette data uploaded to VRAM is located.
;It uses generic PPU write format, as other tables that use CODE_CE00 (to be explained).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DATA_F203:
.db $3F,$00				;PPU Address to write to
.db $20					;How many bytes to write (32 in dec)

;Gameplay Palette, used during, well, gameplay, including demo.
.db $0F,$30,$2C,$12			;>Background 0, used by Phase 1's platforms, frozen platforms, POW and player's roman number tiles
.db $0F,$30,$29,$09			;>Background 1, used by pipes
.db $0F,$30,$27,$18			;>Background 2, used by bonus phases' platforms, phase 4 platforms and phase 9 onward's platforms
.db $0F,$30,$26,$06			;>Background 3, used by phase 6's platforms

.db $0F,$16,$37,$12			;>Sprite 0, used by Mario and fighter fly
.db $0F,$30,$27,$19			;>Sprite 1, used by Luigi shellcreepers and fireballs
.db $0F,$30,$27,$16			;>Sprite 2, used by sidesteppers and fireballs
.db $0F,$2C,$12,$25			;>Sprite 3, used last enemy and by freezies

.db VRAMWriteCommand_Stop		;Command used to stop writing.

DATA_F227:
.db $3F,$00				;PPU Address
.db $14					;Write 20 bytes to PPU. That means no Sprite Palette 2-4 overwrite.

;Palette used for title screen.
.db $0F,$16,$16,$16			;>Background 0, used by MARIO BROS. logo
.db $0F,$27,$27,$27			;>Background 1, used by option strings
.db $0F,$30,$2C,$12			;>Background 2, used by logo's top border and copyright strings
.db $0F,$30,$29,$19			;>Background 3, used by logo's bottom border

.db $0F,$35,$35,$35			;>Sprite 1, used by select sprite

.db VRAMWriteCommand_Stop		;stop writing

;General attribute setup table
;attributes that ar written for all phases. that being HUD and brick floor. just like before, uses generic PPU write format.

DATA_F23F:
.db $23,$C0				;PPU address
.db $10					;16 bytes
.db $00,$00,$C0,$30,$00,$50,$00,$00
.db $55,$55,$00,$00,$00,$00,$55,$55

.db $23,$F0				;another PPU address, being at the bottom of the screen, aka brick flooring
.db $10					;16 bytes
.db $F5,$FF,$FF,$FF,$FF,$FF,$FF,$F5
.db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

.db VRAMWriteCommand_Stop		;stop write


;attributes used for ledge tiles 93 and 97
DATA_F266:
.db $23,$D0
.db VRAMWriteCommand_Repeat|$18		;repeat one byte $18 times
.db $00					;

.db $23,$E8
.db $08					;8 bytes
.db $50,$00,$00,$00,$00,$00,$00,$50	;

.db VRAMWriteCommand_Stop		;end

;attributes used for ledge tiles 94 and 96
DATA_F276:
.db $23,$D0
.db VRAMWriteCommand_Repeat|$18
.db $AA

.db $23,$E8
.db $08
.db $5A,$AA,$AA,$00,$00,$AA,$AA,$5A

.db VRAMWriteCommand_Stop		;stop write

;attributes used for ledge tile 95
DATA_F286:
.db $23,$D0
.db VRAMWriteCommand_Repeat|$18
.db $FF

.db $23,$E8
.db $08
.db $5F,$FF,$FF,$00,$00,$FF,$FF,$5F

.db VRAMWriteCommand_Stop

;graphic pointers for every entity in game
DATA_F296:
.dw DATA_F2A6				;$A6,$F2	;mario
.dw DATA_F2B9				;$B9,$F2
.dw DATA_F2C6				;$C6,$F2
.dw DATA_F2C6				;$C6,$F2
.dw DATA_F2D0				;$D0,$F2
.dw DATA_F2DA				;$DA,$F2
.dw DATA_F2E1				;$E1,$F2
.dw DATA_F2E8				;$E8,$F2

DATA_F2A6:
.db $00,$EF,$F8,$00,$EF,$00,$00,$F7
.db $F8,$00,$F7,$00,$00,$00,$F8,$00
.db $00,$00,$AA

DATA_F2B9:
.db $00,$F7,$F8,$00,$F7,$00,$00,$00
.db $F8,$00,$00,$00,$AA

DATA_F2C6:
.db $80,$F7,$F8,$01,$F7,$00,$00,$00
.db $FC,$AA

DATA_F2D0:
.db $00,$F7,$FC,$80,$00,$F8,$01,$00
.db $00,$AA

DATA_F2DA:
.db $00,$F7,$FC,$00,$00,$FC,$AA

DATA_F2E1:
.db $00,$F7,$F8,$00,$00,$FC,$AA

DATA_F2E8:
.db $00,$FC,$FC,$AA

;this table contains various initial props and such for Player entities
DATA_F2EC:
;Mario
.db $01,$00,$03,$00,$00,$00,$12,$40
.db $D0,$44,$10,$00,$00,$00,$00,$01
.db $00,$00,$00,$00,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$04

;Luigi
.db $01,$00,$03,$00,$00,$00,$12,$01
.db $D0,$C4,$28,$00,$00,$00,$00,$02
.db $00,$00,$00,$00,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$04

DATA_F32C:
.db $00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00

DATA_F33A:
.db $01,$00
.db $01,$00,$01,$01,$00,$01,$01,$02
.db $01,$02,$02,$02,$02,$02,$02,$03
.db $03,$03,$03,$AA

DATA_F350:
.db $FC,$FC,$FC,$FC
.db $FC,$FC,$FC,$FD,$FD,$FE,$FE,$FE
.db $FE,$FE,$FE,$FF,$FE,$FF,$FF,$FF

.db $00,$FF,$FF,$00,$FF,$00,$00,$00
.db $AA

DATA_F36D:
.db $FE,$FE,$FE

DATA_F370:
.db $FF,$FF,$FF,$FF
.db $FF,$00,$FF,$00,$FF,$00,$AA

DATA_F37B:
.db $00,$01,$00,$01,$00,$01,$01,$01
.db $02,$01,$01,$02,$03,$03,$04,$04
.db $CC,$04,$CC,$CC,$CC,$04,$CC,$AA

DATA_F393:
.db $01,$03,$00,$01,$02,$00,$01,$01
.db $00,$AA,$01,$03,$00,$01,$02,$00
.db $01,$01,$FF,$AA

.db $01,$02,$00,$01,$01,$FF,$01,$01
.db $FF,$01,$01,$00,$01,$01,$00,$01
.db $01,$01,$AA

;This set of data is enemy data to spawn from pipes per "Enemy level".
;First, there are pointers to appropriate tables.
DATA_F3BA:
.dw DATA_F3D2
.dw DATA_F3D9
.dw DATA_F3E4
.dw DATA_F3ED
.dw DATA_F3FA
.dw DATA_F403
.dw DATA_F40E
.dw DATA_F419
.dw DATA_F424
.dw DATA_F431
.dw DATA_F43E
.dw DATA_F449

;then there are tables for enemy spawns, each enemy takes a pair of bytes:
;first byte is timer for how long it should take to come out of the pipe
;second byte is the entity ID, where 0 - Shellkreeper, 1 - Sidestepper, 2 - Fighterfly.
;$AA is a terminator, making no more enemies spawn.

;3 shellkreepers
DATA_F3D2:
.db $05,$00
.db $12,$00
.db $1F,$00
.db $AA

;5 shellkreepers
DATA_F3D9:
.db $05,$00
.db $12,$00
.db $1F,$00
.db $19,$00
.db $1F,$00
.db $AA

;4 sidesteppers
DATA_F3E4:
.db $05,$01
.db $0C,$01
.db $2B,$01
.db $0C,$01
.db $AA

;4 sidesteppers and 2 shellkreepers
DATA_F3ED:
.db $03,$01
.db $0C,$01
.db $31,$00
.db $06,$00
.db $49,$01
.db $07,$01
.db $AA

;4 fighterflies
DATA_F3FA:
.db $0C,$02
.db $0C,$02
.db $31,$02
.db $0C,$02
.db $AA

;3 fighterflies and 2 sidesteppers
DATA_F403:
.db $0C,$02
.db $0C,$02
.db $31,$01
.db $06,$01
.db $31,$02
.db $AA

;4 shellkreepers, 1 fighterfly
DATA_F40E:
.db $03,$00
.db $0C,$00
.db $31,$02
.db $06,$00
.db $31,$00
.db $AA

;4 sidesteppers, 1 fighterfly
DATA_F419:
.db $03,$01
.db $0C,$01
.db $31,$02
.db $06,$01
.db $31,$01
.db $AA

;4 sidesteppers, 2 fighterflies
DATA_F424:
.db $0C,$02
.db $0C,$01
.db $31,$01
.db $06,$01
.db $31,$02
.db $12,$01
.db $AA

;4 sidesteppers, 2 fighterflies, different order
DATA_F431:
.db $03,$01
.db $0C,$01
.db $31,$01
.db $06,$02
.db $31,$02
.db $12,$01
.db $AA

;4 shellkreepers, 1 sidestepper
DATA_F43E:
.db $03,$00
.db $0C,$00
.db $31,$01
.db $06,$00
.db $06,$00
.db $AA

;4 shellkreepers, different timings
DATA_F449:
.db $01,$00
.db $05,$00
.db $40,$00
.db $FF,$00
.db $AA

DATA_F452:
.db $01,$00,$03,$00,$0A,$06,$52,$21
.db $28,$00,$00,$00,$4C,$F6,$00,$10
.db $00,$00,$00,$0A,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$06
.db $01,$00,$03,$00,$10,$03,$6C,$22
.db $28,$00,$00,$04,$4C,$F6,$00,$20
.db $00,$00,$00,$14,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$05,$06
.db $01,$00,$03,$00,$24,$03,$7D,$20
.db $28,$00,$00,$08,$4C,$F6,$00,$30
.db $00,$00,$00,$00,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$05,$06

;Holds frames for various animations for various entities (CurrentEntity_DrawTile values)
;FF is used to loop back to specified index (the byte right next to it)

DATA_F4B2:

;Player Running
.db GFX_Player_Walk1
.db GFX_Player_Walk2
.db GFX_Player_Walk3
.db GFX_Player_Walk2
.db $FF,$00

;Player Skidding
.db GFX_Player_Skid1
.db GFX_Player_Skid2
.db $FF,$06

;Shellcreeper Movement
.db GFX_Shellcreeper_Walk1
.db GFX_Shellcreeper_Walk2
.db GFX_Shellcreeper_Walk1
.db GFX_Shellcreeper_Walk3
.db $FF,$0A

;Sidestepper Movement
.db GFX_Sidestepper_Move1
.db GFX_Sidestepper_Move1
.db GFX_Sidestepper_Move2
.db GFX_Sidestepper_Move2
.db GFX_Sidestepper_Move1
.db GFX_Sidestepper_Move1
.db GFX_Sidestepper_Move3
.db GFX_Sidestepper_Move3
.db $FF,$10

;Sidestepper Movement (hit once)
.db GFX_Sidestepper_AngryMove1				;GFX_AnimationCycle_SidestepperAngry = $1A
.db GFX_Sidestepper_AngryMove1
.db GFX_Sidestepper_AngryMove2
.db GFX_Sidestepper_AngryMove2
.db GFX_Sidestepper_AngryMove1
.db GFX_Sidestepper_AngryMove1
.db GFX_Sidestepper_AngryMove3
.db GFX_Sidestepper_AngryMove3
.db $FF,$1A

;Fighterfly Movement
.db GFX_Fighterfly_Move1
.db GFX_Fighterfly_Move1
.db GFX_Fighterfly_Move2
.db GFX_Fighterfly_Move2
.db GFX_Fighterfly_Move3
.db GFX_Fighterfly_Move3
.db $FF,$24

;Coin
.db GFX_Coin_Frame1
.db GFX_Coin_Frame2
.db GFX_Coin_Frame3
.db GFX_Coin_Frame4
.db GFX_Coin_Frame5
.db $FF,$2C

;Freezie
.db GFX_Freezie_Move1
.db GFX_Freezie_Move2
.db GFX_Freezie_Move3
.db $FF,$33

;Splash
.db GFX_Splash_Frame1
.db GFX_Splash_Frame2
.db GFX_Splash_Frame3
.db $FF,$38

;Fireball
.db GFX_Fireball_Move1
.db GFX_Fireball_Move2
.db GFX_Fireball_Move3
.db GFX_Fireball_Move4
.db $FF,$3D

;pipes tiles and stuff

;top-left pipe
TEMP_Def = VRAMLoc_TopPipeLeft+2

DATA_F4F5:
.db >TEMP_Def,<TEMP_Def
.db $04
.db $52,$51,$3C,$50

TEMP_Def = VRAMLoc_TopPipeLeft+$20
.db >TEMP_Def,<TEMP_Def
.db $06
.db $41,$57,$56,$55,$47,$54

TEMP_Def = VRAMLoc_TopPipeLeft+$40
.db >TEMP_Def,<TEMP_Def
.db $06
.db $46,$5C,$5B,$5A,$4C,$59

TEMP_Def = VRAMLoc_TopPipeLeft+$60
.db >TEMP_Def,<TEMP_Def
.db $04
.db $49,$61,$49,$5F

;top-right pipe
TEMP_Def = VRAMLoc_TopPipeRight

.db >TEMP_Def,<TEMP_Def
.db $04
.db $39,$3C,$3A,$3B

TEMP_Def = VRAMLoc_TopPipeRight+$20
.db >TEMP_Def,<TEMP_Def
.db $06
.db $3D,$47,$3E,$3F,$40,$41

TEMP_Def = VRAMLoc_TopPipeRight+$40
.db >TEMP_Def,<TEMP_Def
.db $06
.db $42,$4C,$43,$44,$45,$46

TEMP_Def = VRAMLoc_TopPipeRight+$62
.db >TEMP_Def,<TEMP_Def
.db $04
.db $48,$49,$4A,$4B

;bottom-left pipe

TEMP_Def = VRAMLoc_BottomPipeLeft
.db >TEMP_Def,<TEMP_Def
.db $04
.db $41,$41,$41,$57

TEMP_Def = VRAMLoc_BottomPipeLeft+$20
.db >TEMP_Def,<TEMP_Def
.db $04
.db $46,$46,$46,$5C

TEMP_Def = VRAMLoc_BottomPipeLeft+$40
.db >TEMP_Def,<TEMP_Def
.db $04
.db $4B,$4B,$4B,$61

TEMP_Def = VRAMLoc_BottomPipeRight
;bottom-right pipe
.db >TEMP_Def,<TEMP_Def
.db $04
.db $40,$41,$41,$41

TEMP_Def = VRAMLoc_BottomPipeRight+$20
.db >TEMP_Def,<TEMP_Def
.db $04
.db $45,$46,$46,$46

TEMP_Def = VRAMLoc_BottomPipeRight+$40
.db >TEMP_Def,<TEMP_Def
.db $04
.db $4A,$4B,$4B,$4B
.db VRAMWriteCommand_Stop

;POW Block update data
;used for buffered write.
;first byte is a number of rows and tiles in said rows (low nibble - amount of tiles, high nibble - rows)

DATA_F560:
.db $22,$24,$24,$24,$24			;No POW block
.db $22,$FE,$FF,$90,$91			;hit twice
.db $22,$FC,$FD,$8E,$8F			;hit once
.db $22,$FA,$FB,$8C,$8D			;full POW block

;VRAM locations for platform edges that can be bumped from below (so only 2x2 tiles instead of 3x2 are shown)
DATA_F574:
.db $2D,$21
.db $F7,$21
.db $03,$22
.db $AB,$22

.db $32,$21
.db $E8,$21
.db $1C,$22
.db $B4,$22

;pointers and values for entities' graphical display
DATA_F584:
.dw DATA_F5AA
.dw DATA_F5CA

.db GFX_Shellcreeper_Flipped1,Entity_Draw_8x16_Shift
.db GFX_Shellcreeper_Walk1,Entity_Draw_8x16_Shift

DATA_F58C:
.dw DATA_F5AA
.dw DATA_F5EA

;key frames for sidestepper and drawing mode
.db GFX_Sidestepper_AngryMove1,Entity_Draw_8x16_FlickerTop
.db GFX_Sidestepper_Move1,Entity_Draw_8x16_FlickerTop
.db GFX_Sidestepper_Flipped1,Entity_Draw_8x16_FlickerBottom

DATA_F596:
.dw DATA_F5BD
.dw DATA_F608

.db GFX_Fighterfly_Flipped1,Entity_Draw_8x16_FlickerBottom
.db GFX_Fighterfly_Move1,Entity_Draw_8x16_FlickerTop

DATA_F59E:
.dw DATA_F70F
.dw $0000			;unused null pointer

.db GFX_Freezie_Destroyed1,Entity_Draw_8x16_FlickerBottom

DATA_F5A4:
.dw DATA_F6E8
.dw $0000			;unused null pointer

.db GFX_CoinCollected,Entity_Draw_8x8

DATA_F5AA:
.db $FD,$FE,$FE,$FE,$FE,$FF,$FF,$FF
.db $FE,$00,$FF,$00,$FE,$00,$FF,$00
.db $00,$00,$99

DATA_F5BD:
.db $FE,$FE,$FE,$FF,$FF,$FF,$00,$FF
.db $00,$FF,$00,$00,$99

DATA_F5CA:
.db $58,$40,$5A,$40,$58,$40,$5A,$30
.db $58,$30,$5A,$20,$58,$20,$5A,$20
.db $58,$20,$5A,$18,$58,$10,$00,$5A
.db $10,$58,$10,$5A,$08,$58,$08,$FF

DATA_F5EA:
.db $D9,$40,$DC,$40,$D9,$40,$DC,$30
.db $D9,$30,$DC,$20,$D9,$20,$DC,$20
.db $D9,$18,$DC,$10,$00,$D9,$10,$DC
.db $08,$D9,$08,$DC,$08,$FF

DATA_F608:
.db $E0,$60,$E3,$40,$E0,$30,$E3,$20
.db $E0,$20,$E3,$18,$E0,$18,$E3,$10
.db $E0,$10,$00,$E3,$08,$E0,$08,$E3
.db $08,$E0,$08,$E3,$04,$FF

DATA_F626:
.db $E6,$E6,$E6,$E6,$01,$E6,$E6,$E6
.db $FF,$75,$75,$75,$75,$01,$75,$75
.db $75,$FF              
   
DATA_F638:
.db $01,$02,$03,$FF,$02,$01,$03,$FF
.db $00,$03,$FF

DATA_F643:
.db $FB,$FB,$FD,$FE,$FE,$FF,$FF,$FF
.db $FF,$AA

DATA_F64D:
.db $F7,$F8,$FA,$FB,$FC,$FD,$FE,$FE
.db $FE,$FE,$FE,$FF,$FF,$00,$FF,$00
.db $00,$FF,$AA

;this is used for HUD (player 1 and TOP prefixes)
DATA_F660:
.db $20,$63
.db $01				;1 tile
.db $2A				;I- (first player score)

.db $20,$6B
.db $03
.db $2B,$2C,$2D			;TOP-
.db VRAMWriteCommand_Stop	;stop

;this is also for HUD, for player 2, if applicable
DATA_F66B:
.db $20,$75
.db $02
.db $29,$2A			;II-
.db VRAMWriteCommand_Stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DATA_F671 - Life display OAM data
;Format:
;Byte 1 - Y-position
;Byte 2 - Sprite tile to display
;Byte 3 - Tile property
;Byte 4 - X-position
;Do note however that Y-position value is overwritten afterwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;InitLivesData_F671:
DATA_F671:
.db $F4,Lives_Tile,$00,$40				;\
.db $F4,Lives_Tile,$00,$4C				;|mario lives
.db $F4,Lives_Tile,$00,$58				;/
.db $F4,Lives_Tile,$01,$A8				;\
.db $F4,Lives_Tile,$01,$B4				;|luigi lives
.db $F4,Lives_Tile,$01,$C0				;/

;Title screen cursor OAM data, same format as above, Y-position is also overwritten.
DATA_F689:
.db $F4,Cursor_Tile,$00,Cursor_XPos

;VRAM locations for score counters
DATA_F68D:
.db >VRAMLoc_TOPScore,<VRAMLoc_TOPScore
.db $06						;oh, and length ofc
.db $00

.db >VRAMLoc_Player1Score,<VRAMLoc_Player1Score
.db $06
.db $00

.db >VRAMLoc_Player2Score,<VRAMLoc_Player2Score
.db $06
.db $00

;initial values for respawn platforms
DATA_F699:
.db $10,RespawnPlatform_Tile1,$03,$6C			;\mario's platform
.db $10,RespawnPlatform_Tile1,$43,$73			;/
.db $10,RespawnPlatform_Tile1,$03,$84			;\luigi's platform
.db $10,RespawnPlatform_Tile1,$43,$8B			;/

DATA_F6A9:
.db $FD,$FE,$FE,$FE,$FF,$FF,$00,$FF
.db $00,$FF,$00,$FF,$00,$00,$00,$00
.db $00,$00,$01,$00,$01,$00,$01,$00
.db $01,$01,$02,$02,$02,$03,$AA

DATA_F6C8:
.db $01,$00,$02,$00,$2C,$05,$A1,$22
.db $00,$00,$00,$00,$4C,$F6,$00,$40
.db $00,$01,$00,$0A,$02,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$03

DATA_F6E8:
.db $FE,$FE,$FE,$FF,$DD,$47,$FF,$FF
.db $FF,$00,$DD,$48,$FF,$FF,$00,$FF
.db $CC,$01,$DD,$49,$00,$00,$00,$00
.db $00,$00,$CC,$05,$DD,$4D,$00,$00
.db $00,$00,$00,$00,$00,$00,$EE

DATA_F70F:
.db $FE,$FE,$FE,$FF,$DD,$EB,$FF,$FF
.db $FF,$00,$DD,$F0,$00,$00,$00,$00
.db $00,$00,$EE

;some initial strings on phase load
DATA_F722:
.db $22,$4C
.db $08
.db $19,$11,$0A,$1C,$0E,$24,$24,$24			;PHASE    (last 2 spaces are replaced with appropriate digits depending on phase number)

.db $23,$41
.db $04
.db $19,$2E,$24,$24					;P=   (same as above, spaces replaced with phase number digits)
.db VRAMWriteCommand_Stop

;TEST YOUR SKILL string used when loading TEST YOUR SKILL! phase
DATA_F735:
.db $21,$89
.db $0F
.db $1D,$0E,$1C,$1D,$24,$22,$18,$1E			;TEST YOUR SKILL
.db $1B,$24,$1C,$14,$12,$15,$15	

;then timer initialization
.db $20,$8D
.db $06
.db $30,$31,$31,$31,$31,$32				;top border

.db $20,$AD
.db $06							;|20.0| (changes to 15.0 afterwads if in later TEST YOUR SKILL phases)
.db $33,$02,$00,$66,$00,$34

.db $20,$CD
.db $06
.db $35,$36,$36,$36,$36,$37				;bottom border
.db VRAMWriteCommand_Stop

;data for Freezie's platform freezing (replacing tiles, attributes)
;Middle platform
DATA_F763:
.db $21,$EE
.db VRAMWriteCommand_Repeat|$04
.db $97

.db $23,$DB
.db $02
.db $20,$80
.db VRAMWriteCommand_Stop

DATA_F76D:
.db $21,$EC
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $21,$F2
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $23,$DB
.db $02
.db $00,$00
.db VRAMWriteCommand_Stop

DATA_F77B:
.db $21,$EA
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $21,$F4
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $23,$DA
.db $04
.db $20,$00,$00,$80
.db VRAMWriteCommand_Stop

DATA_F78B:
.db $21,$E8
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $21,$F6
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $23,$DA
.db $04
.db $00,$00,$00,$00
.db VRAMWriteCommand_Stop

DATA_F79B:
.db $22,$A4
.db VRAMWriteCommand_Repeat|$04
.db $97

.db $23,$E9
.db $01
.db $50

.db VRAMWriteCommand_Stop

DATA_F7A4:
.db $22,$A2
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $22,$A8
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $23,$E8
.db $03
.db $52,$00,$08

.db VRAMWriteCommand_Stop

DATA_F7B3:
.db $22,$A0
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $22,$AA
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $23,$E8
.db $03
.db $50,$00,$00
.db VRAMWriteCommand_Stop

DATA_F7C2:
.db $22,$B8
.db VRAMWriteCommand_Repeat|$04
.db $97

.db $23,$EE
.db $01
.db $50
.db VRAMWriteCommand_Stop

DATA_F7CB:
.db $22,$B6
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $22,$BC
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $23,$ED
.db $03
.db $02,$00,$58

.db VRAMWriteCommand_Stop

DATA_F7DA:
.db $22,$B4
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $22,$BE
.db VRAMWriteCommand_Repeat|$02
.db $97

.db $23,$ED
.db $03
.db $00,$00,$50
.db VRAMWriteCommand_Stop

DATA_F7E9:
.db $00,$03,$FF,$03,$00,$03,$00,$03
.db $FF,$03,$01,$03,$01,$03,$00,$03
.db $01,$03,$02,$03,$02,$03,$02,$02
.db $02,$02,$03,$02,$03,$02,$03,$02
.db $03,$01,$03,$01,$03,$01,$03,$01
.db $04,$00,$04,$01,$04,$00,$04,$01
.db $04,$01,$AA           

DATA_F81C:
.db $00,$01,$02,$02,$01,$00,$AA

;this table contains movement for Mario for demo mode. consists of pairs that are input and time for said input to be held.
DATA_F823:
.db $00,$5C
.db Input_Right,$50
.db $00,$10
.db Input_Left,$14
.db Input_Left|Input_A,$40
.db $00,$10
.db Input_Right,$28
.db $00,$50
.db Input_A,$40
.db Input_Left,$28
.db $00,$14
.db Input_Right,$10
.db Input_Right|Input_A,$40
.db $00,$48
.db Input_Right,$30
.db Input_Right|Input_A,$30
.db Input_Right,$10
.db $00,$10
.db Input_Left,$45
.db Input_Left|Input_A,$40
.db Input_Left,$20
.db $00,$08
.db Input_Right,$40
.db Input_Right|Input_A,$40
.db Demo_EndCommand

;same as above but for Luigi.
DATA_F854:
.db $00,$30
.db Input_Left,$50
.db $00,$10
.db Input_Right,$18
.db Input_Right|Input_A,$30
.db Input_Right|Input_A,$18
.db $00,$10
.db Input_Left,$24
.db Input_Left|Input_A,$60
.db Input_Left|Input_A,$40
.db $00,$08
.db Input_Right,$24
.db Input_Right|Input_A,$40
.db $00,$18
.db Input_Left,$10
.db Input_Left|Input_A,$40
.db $00,$40
.db Input_Right,$60
.db $00,$50
.db Input_Right,$FF    

;Freespace! European version leaves only a few bytes of it (7 to be exact).
.db $FF,$FF,$FF
.db $FF,$FF,$FF
.db $FF,$FF,$FF         
.db $FF,$FF,$FF        
.db $FF,$FF,$FF         
.db $FF,$FF,$FF         
.db $FF,$FF,$FF           
.db $FF,$FF,$FF           
.db $FF,$FF,$FF          
.db $FF,$FF,$FF        
.db $FF,$FF,$FF           
.db $FF,$FF,$FF     
.db $FF,$FF,$FF         
.db $FF,$FF,$FF,$FF       

.org $F8A7					;sound engine is at this specific location.
CODE_F8A7:
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
.db $85,$85,$85,$8D,$8D,$8D

DATA_F900:
.db $01
.db $C4,$00,$00,$00,$69,$00,$D4
.db $00,$C8,$00,$BD,$00,$B2,$00
.db $A8,$00,$9F,$00,$8D,$00,$85
.db $00,$7E,$00,$76,$00,$70,$01
.db $AB,$01,$7C,$01,$67,$01,$52
.db $01,$3F,$01,$1C,$01,$0C,$00
.db $FD,$00,$EE,$00,$E1,$03,$57
.db $02,$F9,$02,$A6,$02,$80,$02
.db $3A,$02,$1A,$01,$FC,$01,$DF
.db $06,$AE,$05,$F3,$05,$4D,$05
.db $01,$04,$75,$03,$89,$00,$53

DATA_F94E:
.db $03,$07,$0E,$1C,$38,$15,$2A
.db $04,$08,$10,$20,$40,$18,$30
.db $06,$05,$0A,$14,$28,$50,$1E
.db $3C,$04,$0B,$16,$2C,$58,$21
.db $07

CODE_F96B:
   LDY #$7F

CODE_F96D:  
   STX $4004                
   STY $4005                
   RTS
   
CODE_F974:
   TYA                      
   LSR A                    
   LSR A                    
   LSR A

CODE_F978:   
   LSR A

CODE_F979:   
   LSR A                     
   STA $00                  
   TYA                      
   SEC                      
   SBC $00                  
   RTS                      

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
.db $8C,$84,$83,$8D,$8D,$83,$83,$8B
.db $8C,$83,$8B

DATA_F99D:
.db $8C,$8A,$8A,$8B,$8B

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
   LDY $FF					;
   LDA $F0					;
   LSR A					;
   BCS CODE_FA8B				;
   LSR $FF					;
   BCS CODE_FA88				;
   LSR A					;
   BCS CODE_FA2D				;
   LSR $FF					;
   BCS CODE_FA8E				;
   LSR A					;
   BCS CODE_FA44				;
   LSR $FF					;
   BCS CODE_FA3B				;
   LSR $FF					;
   BCS CODE_FA54				;
   LSR A					;
   BCS CODE_FA5F				;
   LSR A					;
   BCS CODE_FA71				;
   LSR $FF					;
   BCS CODE_FA66				;
   LSR A					;
   BCS CODE_FADB				;
   LSR $FF					;
   BCS CODE_FAD4				;
   LSR A					;
   BCS CODE_FAFF				;
   LSR $FF					;
   BCS CODE_FAF8				;
   LSR A					;
   BCS CODE_FB24				;
   LSR $FF					;
   BCS CODE_FB0F				;
   
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
   
   INC $06F0                
   LDA $06F0                
   AND #$07                 
   TAY                      
   LDA DATA_FB32,Y              
   JSR CODE_F8D8
   
CODE_FB24:
   LDA $F1                  
   LDY #$7F                 
   LDX #$90                 
   CMP #$04                 
   BCS CODE_FAE5
   
   LDA #$04                 
   BCC CODE_FAE8

;unused data?
DATA_FB32:
.db $26,$22,$26,$22,$26,$22,$1C,$22

DATA_FB3A:
.db $83,$84,$82,$8E
   
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
   LDA RandomNumberStorage
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
   LDA #$08                 
   STA $F5
   
   LDA #$08                 
   STA $4008
   
   LDA #$34                 
   STA $400A
   
   LDA #$08                 
   STA $400B
   
CODE_FCC4:
   DEC $F5                  
   JMP CODE_FD27
   
CODE_FCC9:
   LDA $F9						;   
   BNE CODE_FD27					;
   
   LDA Sound_Loop					;check looping sounds
   LSR A                    
   LSR A                    
   LDX $F5                  
   BNE CODE_FCC4                
   LSR A                    
   BCS CODE_FCB1                
   LSR A                    
   BCS CODE_FCE3
   
   LDX $06C0                
   BNE CODE_FCF3                
   JMP CODE_FD27
  
CODE_FCE3:
   LDA #$0E                 
   STA $06C0
   
   LDA #$FE                 
   STA $F6
   
   LDA #$08                 
   STA $4008                
   BNE CODE_FD0B
  
CODE_FCF3:
   DEC $06C0
   
   LDA $06C0                
   CMP #$08                 
   BCS CODE_FD0B
   
   LDY $F6                  
   JSR CODE_F974
   STA $F6
   
   LDA $06C0                
   AND #$03                 
   BEQ CODE_FD1A
  
CODE_FD0B:
   LDA RandomNumberStorage
   LSR A                    
   BCC CODE_FD1A
   
   LDA $F6                  
   CLC                      
   ROL A                    
   STA $400A                
   BNE CODE_FD21
   
CODE_FD1A:
   LDA $F6
   ROL A                    
   ROL A                    
   STA $400A

CODE_FD21:  
   ROL A                    
   AND #$03                 
   STA $400B                
   
CODE_FD27:
   LDA Sound_Jingle				;
   BNE CODE_FD33				;play jingle bells!

   LDA Sound_JinglePlayingFlag			;if the jingle is still playing, continue
   BNE CODE_FD78                
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
   
   LDA #$10					;constant volume
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
.db $08,$0D,$12,$17,$1C,$21,$26,$2B

;if the format is the same as in SMB, it's as follows:
;1 byte - length byte offset
;2 bytes - sound data address
;1 byte - triangle data offset
;1 byte - square 1 data offset
;1 byte - square 2 data offset (only for title screen?)
.db $0F,<DATA_FE95,>DATA_FE95,$30,$00
.db $00,<DATA_FED1,>DATA_FED1,$00,$08
.db $00,<DATA_FEE6,>DATA_FEE6,$0A,$00
.db $0F,<DATA_FEF3,>DATA_FEF3,$00,$00
.db $07,<DATA_FEFC,>DATA_FEFC,$03,$00
.db $00,<DATA_FF0B,>DATA_FF0B,$00,$00
.db $07,<DATA_FF0D,>DATA_FF0D,$18,$00
.db $16,<DATA_FF44,>DATA_FF44,$1F,$38,$7E

;$00 - stop command
DATA_FE95:
.db $5D,$78,$5D,$78,$5C,$78,$5C,$62
.db $E6,$65,$5E,$65,$5E,$64,$5E,$40
.db $5E,$F8,$00      

;Unused! a leftover from somewhere? maybe square or triangle sound? because with noise it doesnt sound good.
DATA_FEA8:
.db $85,$06,$81,$26,$85,$06,$81,$26
.db $06,$26,$06,$0E,$83,$12,$85,$10
.db $81,$0A,$85,$10,$81,$0A,$10,$0A
.db $2E,$0A,$83,$26,$00

DATA_FEC5:
.db $5D,$78,$5D,$78,$1D,$5F,$40,$5F
.db $40,$9E,$80,$F8

DATA_FED1:
.db $6E,$6A,$A6,$A6,$A6,$AE,$07,$00

DATA_FED9:
.db $82,$46,$38,$32,$4A,$48,$81,$40
.db $42,$44,$48,$84,$30

DATA_FEE6:
.db $66,$6E,$4A,$50,$52,$50,$4A,$6E
.db $27,$00

;...
.db $E6,$DE,$39

DATA_FEF3:
.db $04,$12,$04,$12,$04,$12,$04,$D2
.db $00

DATA_FEFC:
db $83,$83,$00

;...
.db $46,$46,$4E,$52,$42,$4E
.db $12,$14,$16,$18,$1A,$05

DATA_FF0B:
.db $E6,$00

DATA_FF0D:
.db $2E,$46,$02,$AE,$6A,$67,$28,$6A
.db $02,$A6,$64,$63,$9E,$A4,$6A,$47
.db $08,$4B,$02,$0C,$4F,$02,$07,$00
.db $86,$A6,$A2,$9C,$AA,$A2,$9C,$BC
.db $9E,$BC,$B6,$B2,$26,$24,$26,$24
.db $A6,$22,$1E,$22,$1E,$A2,$1C,$00
.db $1C,$00,$1C,$00,$1C,$00,$1D

DATA_FF44:
.db $47,$EA,$42,$66,$AA,$AC,$6A,$A6
.db $47,$EA,$42,$66,$AA,$AC,$6A,$A6
.db $6A,$AC,$86,$6C,$AA,$6C,$86,$8A
.db $46,$4A,$4E,$D0,$D2,$11,$00

.db $77,$76
.db $F6,$5D,$5C,$DC,$77,$76,$F6,$5D
.db $5C,$DC,$65,$64,$E4,$7F,$7E,$FE
.db $BE,$B6,$9C,$B8,$A4,$9C,$F6,$82
.db $2A,$81,$36,$82,$24,$81,$1C,$1E
.db $20,$22,$24,$1C,$26,$1C,$24,$1C
.db $22,$82,$2A,$81,$36,$82,$24,$81
.db $1C,$1E,$24,$22,$24,$1C,$26,$1C
.db $24,$22,$1C,$24,$26,$1C,$2A,$24
.db $26,$1C,$24,$26,$2A,$24,$2C,$1E
.db $2A,$24,$2C,$0A,$2C,$06,$0A,$0E
.db $06,$0A,$0E,$80,$2E,$86,$06,$82
.db $3A,$81,$3C,$84,$36,$40,$44,$44
.db $44,$40,$44,$40,$44,$40,$44,$44
.db $44,$40,$44,$40,$44,$40,$44,$44
.db $44,$40,$44,$40,$44,$40,$44,$44
.db $44,$40,$44,$40,$44,$40,$44,$44
.db $44,$40,$44,$44,$44,$40,$44,$44
.db $44,$40,$44,$44,$84,$84,$84,$84
.db $84,$44,$44,$44,$05

   .org $FFFA						;Interrupt vectors at set location

   .dw NMI_C07D
   .dw RESET_C000
   .dw RESET_C000

  .incbin MarioBrosGFX.bin				;i'll leave this so I don't have to add this each time