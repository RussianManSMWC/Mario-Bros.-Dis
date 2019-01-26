;Mario Bros. (NES) Disassembly.
;not very much documented yet. there are probably some leftovers from my debugging. though I made sure to clean this file.
;But it's pretty much an accurate byte-to-byte MB. disassembly.
;
;Do note that information related with NES's architecture, PPU, APU, CPU and etc. may be incorrect, because I'm an awful programmer. whoops.
;All ROM labels are going to be renamed from generic CODE_XXXX (or DATA_XXXX), to some name that briefly states routine's function.
;Same goes for RAM addresses, to make it easy to understand on what specific address does in code.
;For now, enjoy my barebones disassembly.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.incsrc Defines.asm					;load all defines for RAM addresses

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   .db "NES", $1A
   
   .db $01						;16KB PRG space (for code) = 1
   .db $01						;8KB CHR space (for GFX) = 1
   .db $01						;It's supposed to mirror vertically, though sometimes PPU viewer shows tilemap being mirrored horizontally in my emulator. But who cares? It doesn't affect game at all.
   .db $00						;Mapper 0 - NROM
   
   .db $00,$00,$00,$00					;bytes that don't do anything
   .db $00,$00,$00,$00					;
   
   .org $C000						;starting point = $C000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Reset routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Obviously runs at reset, clearing adresses, disabling/enabling NES registers, and etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


RESET:
   CLD							;Disable Decimal Mode
   SEI							;
   
vblankloop:
   LDA $2002						;V-blank loop 1 to waste some cycles
   BPL vblankloop					;required to enable other PPU registers

   LDX #$00						;
   STX $2000						;
   STX $2001						;
   DEX							;
   TXS							;
   
   LDX $70						;why this is needed?
   
   LDY #$06						;set up RAM clearing loop
   STY $01						;
   
   LDY #$00						;
   STY $00						;clear ~$600 bytes
   
   LDA #$00						;reset all those bytes
   
ResetLoop:
   STA ($00),y						;
   
   DEY							;
   BNE ResetLoop					;
   
   DEC $01						;
   BPL ResetLoop					;we set reset loop by setting high and low bytes for inderect adressing, and decrease high byte
   
   TXA							;I still have no idea
   BNE CODE_C02B					;
   LDX #$5F						;

CODE_C02B:
   STX $0500						;
   JSR CODE_CA1B					;clear screen(s)
   JSR CODE_CA2B					;"clear" sprite data
   
   LDY #$00						;load 00 into Y register....
   STA $2005						;\initial camera position/no scroll
   STA $2005						;/

   INY							;\increase Y register... but I'm sure LDY #$01 could've worked just fine.
   STY DemoFlag						;/initially demo flag is set
   
   LDA #$0F						;\enable all sound channels (except for DMC)
   STA $4015						;/
   
   LDA #$90						;enable VBlank (NMI) and background
   STA $2000						;
   STA $09						;backup enabled bits
   
   LDA #$06						;Bits 1 and 2 to be enabled for 2001
   STA Reg2001BitStorage				;which are "background left column enable" and "sprite left column enable"

CODE_C04F:   
   LDA #$00						;reset frame window flag
   STA $20						;
   
   LDA $30						;if in actual gameplay (not title screen or demo recording)
   BEQ CODE_C05D					;always play sound effects
   
   LDA $50						;if not in title screen mode (demo recording, titlescreen/gameplay inits), don't play sounds
   CMP #$01						;
   BNE CODE_C060					;
   
CODE_C05D:
   JSR CODE_F8A7					;sound engine of some sorts
   
CODE_C060:
   JSR CODE_CD88					;
   JSR CODE_C4B8					;

   LDA #$01						;
   STA $22						;

CODE_C06A:
   LDA $20						;if in frame hasn't passed
   BEQ CODE_C077					;do other things

   INC $2F						;increase frame counter, well, every frame (duh)
   
   LDA #$00						;
   STA $22						;"Disables" NMI
   JMP CODE_C04F					;run some routines that update things every frame, like sounds and stuff
   
CODE_C077:
   JSR CODE_D328
   JMP CODE_C06A

NMI:
   PHA							;\usual stuff - save all registers
   TXA							;|
   PHA							;|
   TYA							;|
   PHA							;/because interrupt can, well, interrupt any process anytime, so we want to make sure we don't mess any registers we had
   
   LDA #$00						;\OAM DMA
   STA $2003						;|
   LDA #$02						;|
   STA $4014						;/
   
   LDA $22						;some sort of "update" flag that allows NMI to update things
   BEQ CODE_C0AC					;although it doesn't do much in practice.
   
   JSR CODE_CB58					;some important routines, probably to keep Graphics on screen and etc.
   JSR CODE_EE6A					;
   JSR CODE_CCFF            				;   
   JSR CODE_CA66            				;   
   JSR CODE_CE09            				;   
   JSR CODE_CCC5            				;   
   JSR CODE_CAF7    					;seems to handle player's collision and enemy movement

   LDY #$01						;"Frame has passed" flag.
   STY $20						;
   
   DEY							;
   STY $42						;

CODE_C0AC:   
   LDA #$01						;"Was interrupted" flag, required to exit loop waiting for interrupt to happen
   STA InterruptedFlag					;

   PLA							;\restore all registers
   TAY							;|
   PLA							;|
   TAX							;|
   PLA							;/
   RTI							;exit interrupt
   
CODE_C0B6:
   LDA $B0
   BEQ CODE_C0BF
   
   LDA $0320
   BNE CODE_C0C2
   
CODE_C0BF:
   JMP CODE_C149
   
CODE_C0C2:
   LDA #$20
   STA $14
   
   LDA #$03
   STA $15
   
   LDA #$01
   STA $11
   
   LDY #$0B
   LDX #$08
   JSR CODE_C44A
   STA $05F7
   ORA #$00
   BEQ CODE_C149
   
   LDA $C6
   ORA $0336
   BEQ CODE_C0F3
   TAX
   AND #$F0
   BNE CODE_C149
   TXA
   AND #$0F
   CMP #$04
   BEQ CODE_C0F3
   CMP #$08
   BNE CODE_C149
   
CODE_C0F3:
   LDA #$00
   STA $05FE
   
   LDA $0321
   STA $10
   AND #$C0
   BNE CODE_C152
   
   LDA $B1
   AND #$C0
   BNE CODE_C14F
   
   LDA $B1
   AND #$03
   BEQ CODE_C15E
   
   LDA $10
   AND #$03
   BEQ CODE_C161
   
   JSR CODE_C3A0
   
   LDA $10
   AND #$03
   EOR $B1
   AND #$03
   BEQ CODE_C13E
   
   LDA $05F7
   AND #$0F
   CMP #$02
   BEQ CODE_C12E
   
   LDA $B1
   JMP CODE_C130
   
CODE_C12E:
   LDA $10
   
CODE_C130:
   LSR A
   BCC CODE_C149

   LDA $C4
   CMP $0334
   BEQ CODE_C15B
   BCS CODE_C158
   BCC CODE_C155
   
CODE_C13E:
   LDA $0334					;
   CMP $C4					;
   BEQ CODE_C164				;
   BCS CODE_C155
   BCC CODE_C158
   
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
   LDA $B1
   ORA $0321
   AND #$04
   BNE CODE_C193

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
   STX $0335
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
   
   LDA $B1			;
   AND #$03			;
   BNE CODE_C212		;
   
   LDA $10			;if player 2 while jumping hits player 1 who falls down
   AND #$03			;
   BNE CODE_C221		;do something
   
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
   
   LDA $10			;if player 1 while jumping hits player 2 who falls down
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
   
CODE_C24B:
   LDA #$01
   STA $B5
   
   LDA $BA
   JSR CODE_C3F5
   
   LDA #$1E
   STA $B6
   
   LDA $B1
   ORA #$08
   STA $B1
   
   LDA #$2F
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
   
   LDA #$50
   LDY #$F3
   
CODE_C27B:
   STA $032C
   STY $032D
   RTS
   
CODE_C282:
   LDX #$05
   LDY #$42
   
CODE_C286:
   STY $0321
   
   LDA $B1
   AND #$08
   BNE CODE_C2A7
   
   STX $B1
   JSR CODE_C3E3
   
   LDA $C4
   STA $00
   
   LDA $CD
   STA $01
   
   JSR CODE_C3C2
   STA $C2
   
   LDA $00                  
   BEQ CODE_C2A7
   STA $B4
   
CODE_C2A7:
   LDA #$3A
   LDY #$F3
   
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

CODE_C2CB:
   LDA #$01                 
   STA $0325     
   
   LDA $032A
   JSR CODE_C3F5
   
   LDA #$1E         
   STA $0326  
   
   LDA $10                  
   ORA #$08                 
   STA $0321   
   
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
   
   LDA #$50                 
   LDY #$F3

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
   LDA #$3A
   LDY #$F3
   BNE CODE_C2FF
   
CODE_C334:
   LDA $B1
   ORA #$04
   STA $0321
   
   LDA $10
   ORA #$04
   STA $B1
   
   LDA $C4
   STA $00
   
   LDA $CD
   STA $01
   
   JSR CODE_C3C2
   
   STA $C2
   STA $0332
   
   LDA $00
   BEQ CODE_C35A
   
   STA $B4
   STA $0324
   
 CODE_C35A:
   RTS
   
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
   JSR CODE_C429
   
   LDA $B1
   AND #$03
   DEY
   BEQ CODE_C399
   CMP #$02
   BNE CODE_C39D
   
CODE_C38B:
   LDA #$06
   STA $0324
   
   LDX #$0D
   LDY #$10
   LDA $B1
   
   JMP CODE_C402
   
CODE_C399:
   CMP #$01
   BEQ CODE_C38B

CODE_C39D:
   JMP CODE_C3A8
   
CODE_C3A0:
   LDA $05FF
   BEQ CODE_C3A8
   PLA
   PLA
   RTS
   
CODE_C3A8:
   LDY #$00
   STY $C1
   STY $0331
   INY
   STY $05FF
   
   LDY $BB
   BNE CODE_C3B9
   
   STA $BB
   
CODE_C3B9:
   LDY $032B
   BNE CODE_C3C1
   STA $032B
   
CODE_C3C1:
   RTS
   
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
   LDA $C4                  
   PHA           
   LDA $0334                
   STA $C4                  
   PLA                      
   STA $0334
   
   LDA #$01                 
   STA $05FD                
   RTS
   
CODE_C3F5:
   CLC
   ADC #$10
   TAY
   LDA #$F4
   STA $0200,y
   STA $0204,y
   RTS
 
CODE_C402:
   AND #$03
   ORA #$04
   STA $B1
   STA $0321
   
   STX $C2
   
   STY $0332
   
   LDY #$00
   STY $C4
   STY $0334
   STY $05FE
   INY
   STY $05FD
   RTS
   
CODE_C41F:
   LDA $0329
   STA $1F
   
   LDA $B9
   JMP CODE_C430

CODE_C429:
   LDA $B9
   STA $1F
   LDA $0329
   
CODE_C430:
   SEC
   SBC $1F
   BPL CODE_C43C
   CMP #$FB
   BCS CODE_C440
   
   LDY #$03
   RTS
   
CODE_C43C:
   CMP #$05
   BCS CODE_C443
   
CODE_C440:
   LDY #$02
   RTS
   
CODE_C443:
   LDY #$01
   RTS
   
CODE_C446:
   LDY #$00
   LDX #$00
   
CODE_C44A:
   STY $1C
   STX $1D
   
   LDA #$20
   STA $12
   
   LDA #$00
   STA $13

CODE_C456:
   LDY #$00
   LDA ($14),y
   
   BEQ CODE_C4AE
   
   LDX #$40
   LDY #$08
   LDA ($14),y
   SEC
   SBC $B8
   BPL CODE_C46E
   EOR #$FF
   CLC
   ADC #$01
   LDX #$80
   
CODE_C46E:
   STX $1F
   
   PHA
   LDY #$1E
   LDA ($14),y
   CLC
   ADC $CE
   ADC $1D
   STA $1E
   PLA
   
   SEC
   SBC $1E
   BPL CODE_C4AE
   
   LDX #$01
   LDY #$09
   LDA ($14),y
   SEC
   SBC $B9
   BPL CODE_C494
   EOR #$FF
   CLC
   ADC #$01
   LDX #$02
   
CODE_C494:
   PHA
   
   TXA
   ORA $1F
   STA $1F
   
   LDY #$1F
   LDA ($14),y
   CLC
   ADC $CF
   ADC $1C
   STA $1E
   PLA
   SEC
   SBC $1E
   BPL CODE_C4AE

   LDA $1F
   RTS
   
CODE_C4AE:
   JSR CODE_CDB4
   DEC $11
   BNE CODE_C456
   LDA #$00
   RTS
   
CODE_C4B8:
   LDA $30					;
   BNE CODE_C528				;
   
   LDA $18
   AND #$10
   BEQ CODE_C507
   
   LDY $26
   BNE CODE_C50B
   
   INY
   STY $26
   
   LDY $40
   CPY #$05
   BEQ CODE_C4F9
   CPY #$04
   BEQ CODE_C4D7
   CPY #$06
   BNE CODE_C50B

CODE_C4D7:
   LDX #$05
   
CODE_C4D9:
   LDA $2A,X
   STA $5A,X
   DEX
   BPL CODE_C4D9

   LDA Reg2001BitStorage		;\
   AND #$0E				;|only leave background for render
   STA $2001				;|
   STA Reg2001BitStorage		;/

   STY $3B

   LDA #$05
   STA $40

   LDA #$00
   STA $FF
   STA $FE
   STA $FC
   BEQ CODE_C501
   
CODE_C4F9:
   LDA #$14
   STA $2B
   
   LDA #$0A
   STA $40
   
CODE_C501:
   LDA #$08
   STA $FD
   BNE CODE_C50B
   
CODE_C507:
   LDA #$00
   STA $26
   
CODE_C50B:
   LDA $40					;another gamemode pointer? this time for actual gameplay
   JSR CODE_CD9E				;
   
DATA_C510:
   .dw CODE_D34A				;gameplay init
   .dw CODE_E14A				;determine Phase number and if it's a "Test Your Skill!" Area
   .dw CODE_D3F9				;more init - sets Game A or B flag and enables gameplay palette flag
   .dw CODE_D3A8				;actual gameplay
   
   .dw CODE_C5A3				;game pause?
   .dw CODE_D5E5				;return
   .dw CODE_E453				;coin counting after "Test Your Skill!" phase
   .dw CODE_D5E5				;return
   
   .dw CODE_D451				;phase start
   .dw CODE_E129				;wait for next phase to begin (after clearing all enemies)
   .dw CODE_D45C				;unpause
   .dw CODE_E28B				;game over

   
CODE_C528:
   LDA $18
   AND #$30
   CMP #$10
   BNE CODE_C543
   
   LDA #$00
   STA $30
   STA $40
   
   JSR CODE_D4FE
   JSR CODE_E132
   
   LDA #$02
   STA $2A
   STA $2D
   RTS
   
CODE_C543:
   LDX $50
   BEQ CODE_C58E
   CMP #$20                 
   BNE CODE_C568                
   CPX #$01                 
   BNE CODE_C561
   
   LDA $28                  
   BNE CODE_C574
   
   LDY $29                  
   INY                      
   CPY #$04                 
   BNE CODE_C55C

   LDY #$00
   
CODE_C55C:   
   STY $29                  
   JMP CODE_C570

CODE_C561:
   JSR CODE_D4FE
   
   STA $50                  
   BEQ CODE_C58E

CODE_C568:   
   CMP #$00                 
   BNE CODE_C570 
   
   STA $28                  
   BEQ CODE_C57E

CODE_C570:  
   LDA #$01                 
   STA $28
   
CODE_C574:
   LDA $2D                  
   CMP #$25                 
   BCS CODE_C57E
   
   LDA #$25                 
   STA $2D

CODE_C57E:   
   CPX #$01                 
   BNE CODE_C58E
   
   LDA $29                  
   ASL A             
   ASL A  
   ASL A      
   ASL A        
   CLC                      
   ADC #$80                 
   STA $0200
 
CODE_C58E:   
   LDA $50  					;\Set up pointers based on $50 value                
   JSR CODE_CD9E				;/

DATA_C593:
   .dw CODE_D40B				;loading title screen
   .dw CODE_D47D				;title screen
   .dw CODE_D491				;initialize gameplay
   .dw CODE_D496				;preparing gameplay area
   .dw CODE_D49B				;same as before?
   .dw CODE_D4A0				;enable screen display
   .dw CODE_D4AF				;playing title screen demo recording (or actual gameplay?)
   .dw CODE_D448				;reset pointer
   
CODE_C5A3:					;seems to handle all things during normal gameplay
   JSR CODE_D56E             
   JSR CODE_D202
   JSR CODE_D301                
   JSR CODE_C5DB   
   JSR CODE_C66A                
   JSR CODE_E783                
   JSR CODE_EA31                
   JSR CODE_E795    
   JSR CODE_EDEB                
   JSR CODE_E2AB                
   JSR CODE_E21A
   JSR CODE_E1F7                
   JSR CODE_DFF8                
   JSR CODE_E1CE                
   JSR CODE_E26D                
   JSR CODE_E709                
   JSR CODE_EF32
   
   LDA #$01
   STA $42
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
   
   LDA #$9E                 
   LDY #$F5                 
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
   LDA #$A4                 
   LDY #$F5
  
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
   LDA #$01                 
   STA $51                  
   RTS                      

CODE_C775:
   LDA $44                  
   BEQ CODE_C770                
   CMP #$01                 
   BNE CODE_C781
   
   LDA #$01                 
   STA $46                  
   
CODE_C781:
   RTS
   
CODE_C782:
   JMP CODE_C686                
   
CODE_C785:
   LDA $BF                  
   CMP #$30                 
   BNE CODE_C7B7
   
   LDA $C0                  
   BNE CODE_C792                
   JSR CODE_CE9C

CODE_C792:  
   LDA $B3                  
   BEQ CODE_C797                
   RTS

CODE_C797:   
   LDA $C0                  
   BNE CODE_C7B7
   
   LDA $B1                  
   AND #$C0                 
   BNE CODE_C7B7
   
   LDA $B1                  
   ORA #$80                 
   STA $B1
   
   LDX #$6D                 
   LDY #$F3                 
   LDA $BE
   BNE CODE_C7B3
   
   LDX #$70      
   LDY #$F3

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
   AND #$08                 
   BNE CODE_C86F
   
   LDA $C0                  
   BPL CODE_C824
   
   LDA $FF                  
   ORA #$20                 
   STA $FF
   
   LDA $B1                  
   AND #$33                 
   ORA #$80                 
   STA $B1
   
   LDA #$50                 
   STA $BC
   
   LDA #$F3                 
   STA $BD
   
   LDA #$18                 
   STA $B6
   
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
   DEC $BB                  
   BEQ CODE_C884

   LDY #$22
   
   LDA $BB                  
   CMP #$20                 
   BEQ CODE_C881                
   LDY #$1E                 
   CMP #$10                 
   BNE CODE_C883

CODE_C881:   
   STY $B6
   
CODE_C883:
   RTS
   
CODE_C884:
   LDA #$00                 
   STA $B5
   
   LDA $B1                  
   AND #$F7                 
   STA $B1
   
   JMP CODE_CEBA

CODE_C891:
   LDA $1E                  
   BNE CODE_C8A4

CODE_C895:
   LDA #$00                 
   STA $C4                  
   STA $BB
   
   JSR CODE_CAB9                
   JSR CODE_CEBA                
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
   
   LDA $B6                  
   CMP #$0C                 
   BNE CODE_C8C7
   
   LDA $FF                  
   ORA #$80                 
   BNE CODE_C8CF

CODE_C8C7:  
   CMP #$26                 
   BNE CODE_C8D1                
   LDA $FF                  
   ORA #$40

CODE_C8CF:
   STA $FF

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
   JSR CODE_CE95
  
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
   
   LDA #$2C                 
   LDY #$F3                 
   JMP CODE_C992
  
CODE_C97D:
   LDA $BF                  
   CMP #$30                 
   BNE CODE_C98E
   
   LDA $C2                  
   BNE CODE_C99E                
   LDA #$7B                 
   LDY #$F3                 
   JMP CODE_C992
   
CODE_C98E:
   LDA #$3A                 
   LDY #$F3
  
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
   LDA #$03				;
   JSR CODE_CA22			;

CODE_CA20:
   LDA #$01				;
   
CODE_CA22:   
   STA $01				;this is "VRAM" offset, needed to set-up proper tile update location
   
   LDA #$24				;set blank tile to be displayed on screen
   STA $00				;
   JMP CODE_CD43			;go and clean screen
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Clear Sprites loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;"Clears" OAM, by putting it in "Hide zone" (and setting other values we don't care about)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   
CODE_CA2B:				;
   LDY #$02				;OAM starting point, high byte
   STY $01				;

   LDY #$00				;\OAM starting point, low byte
   STY $00				;/
   
   LDA #$F4				;dummy props
   
CODE_CA35:
   STA ($00),y				;
   DEY					;
   BNE CODE_CA35			;loop
   RTS					;

CODE_CA3B:
   LDA #$3F
   LDX #$F2                 
   JSR CODE_CA5E
   
   LDA #$66                 
   LDX #$F2
   LDY $32                  
   BEQ CODE_CA5E                
   CPY #$04                 
   BEQ CODE_CA5E
   
   LDA #$76                 
   LDX #$F2                 
   CPY #$01                 
   BEQ CODE_CA5E
   CPY #$03                 
   BEQ CODE_CA5E
   
   LDA #$86                 
   LDX #$F2
   
CODE_CA5E:
   STA $00
   STX $01
   JSR CODE_CE00
   
CODE_CA65:
   RTS
  
CODE_CA66:
   LDY $3F
   BEQ CODE_CA65
   DEY
   BEQ CODE_CA73
   
   LDA #$27
   LDX #$F2
   BNE CODE_CA77

CODE_CA73:
   LDA #$03
   LDX #$F2
   
CODE_CA77:
   LDY #$00
   STY $3F
   BEQ CODE_CA5E

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
   LDA #$93     
   STA $14
   
   LDA #$F3                 
   STA $15
   
   LDA $C3                  
   STA $12
   
   LDA #$00                 
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
   STA $C5                  
   INY                      
   LDA ($14),Y              
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
   LDA $2F
   LSR A
   BCC CODE_CB08
   
   LDX #$0E
   
CODE_CB08:
   LDA #$00
   STA $14
   
   LDA #$03
   STA $15
   
   LDA #$20
   STA $12
   
   LDA #$00
   STA $13

CODE_CB18:
   LDY #$00
   LDA ($14),y
   
   BEQ CODE_CB29
   
   LDY #$03
   LDA ($14),y
   BEQ CODE_CB29
   SEC
   SBC #$01
   STA ($14),y

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
   LDA $2002
   
CODE_CB6A:
   LDA $0520,x
   STA $2006
   INX
   LDA $0520,x
   STA $2006
   LDA $2007
   LDA $2007
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
   
CODE_CBC4:
   LDA $B0                  
   BEQ CODE_CBC3
   
   LDA #$F2                 
   STA $15
   
   LDA #$96                 
   STA $14

   LDA $B5                  
   JSR CODE_CC29
   
   LDA $B6                  
   STA $11
   
   LDY #$00                 
   LDX $BA

CODE_CBDD:
   LDA ($12),Y              
   BEQ CODE_CBE9                
   BPL CODE_CBE4                
   ASL A

CODE_CBE4:  
   EOR $2F                  
   LSR A                    
   BCS CODE_CC1D

CODE_CBE9:  
   INY                      
   LDA ($12),Y
   
   INY                      
   CLC                      
   ADC $B8                  
   ADC #$FF                 
   STA $0200,X
   
   INX                      
   LDA $11                  
   STA $0200,X
   
   INC $11
   
   INX                      
   LDA $B7                  
   STA $0200,X 
   
   INX                      
   LDA ($12),Y
   
   BIT $B7                  
   BVS CODE_CC0D                
   CLC                      
   BCC CODE_CC13

CODE_CC0D:  
   EOR #$FF                 
   SEC                      
   SBC #$08                 
   SEC
   
CODE_CC13:  
   ADC $B9                  
   INY                      
   STA $0200,X              
   INX                      
   JMP CODE_CC22

CODE_CC1D:
   INY 
   INY                      
   INY                      
   INC $11

CODE_CC22:   
   LDA ($12),Y              
   CMP #$AA                 
   BNE CODE_CBDD                
   RTS                      
   
CODE_CC29:
   ASL A                    
   STA $12
   
   LDA #$00                 
   TAY                      
   ROL A                    
   STA $13
   
   JSR CODE_CDB4
   
   LDA ($14),Y              
   STA $12                  
   INY                      
   LDA ($14),Y              
   STA $13                  
   RTS                      
   
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
   
   LDA $B9
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
   LDA $B8                  
   CLC                      
   ADC #$08                 
   CMP #$E4
   BCC CODE_CC84
   
   LDA #$00                 
   STA $01
   
   LDA #$20                 
   BNE CODE_CC8F
  
CODE_CC84:
   STA $01
   
   LDA $B9                  
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
   
CODE_CCC5:
   LDX #$01
   STX $4016
   DEX
   TXA
   STA $4016
   JSR CODE_CCD3
   INX
   
CODE_CCD3:
   LDY #$08
   
CODE_CCD5:
   PHA
   LDA $4016,x
   
   STA $00
   LSR A
   ORA $00
   LSR A
   PLA
   ROL A
   DEY
   BNE CODE_CCD5
   
   STX $00
   ASL $00
   LDX $00
   LDY $18,x
   STY $00
   STA $18,x
   STA $19,x
   AND #$FF
   BPL CODE_CCFE
   
   BIT $00
   BPL CODE_CCFE
   
   AND #$7F
   STA $19,x
   
CODE_CCFE:
   RTS
   
CODE_CCFF:
   LDA $21
   BEQ CODE_CD42
   
   LDA #$91
   STA $00
   
   LDA #$05
   STA $01
   
   LDA $09				; 
   AND #$FB				;
   STA $2000				;enable any of bits except for bits 0 and 1
   STA $09				;back them up
   
   LDX $2002
   
   LDY #$00
   BEQ CODE_CD34

CODE_CD1B:
   STA $2006
   
   INY
   LDA ($00),y
   STA $2006
   
   INY
   LDA ($00),y
   AND #$3F
   TAX
   
CODE_CD2A:
   INY
   LDA ($00),y
   STA $2007
   DEX
   BNE CODE_CD2A
   INY

CODE_CD34:
   LDA ($00),y
   BNE CODE_CD1B
   
   LDA #$00
   STA $0590
   STA $0591
   STA $21

CODE_CD42:
   RTS
   
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
   LDA $2002				;ready to draw
   
   LDA $09				;\
   AND #$FB				;|
   STA $2000				;|
   STA $09				;/
   
   LDA #$1C				;
   CLC					;
   
CODE_CD52:
   ADC #$04				;
   DEC $01				;calculate high byte of tile drawing starting point
   BNE CODE_CD52			;can be either 20 or 28
   STA $02				;
   STA $2006				;
   
   LDA #$00				;tile drawing's position, low byte
   STA $2006				;so, the final starting position is either 2000 or 2800
   
   LDX #$04				;to effectively clear full screen, we need to go from 0 to 255 (dec) 4 times! which is 8 horizontal tile lines from the top right to the bottom left tile. that's how many 8x8 tiles to clear
   LDY #$00				;(technically not, as this also affects attributes that start after 2xBF, but they get cleared afterwards anyway)
   
   LDA $00				;load tile to fill screen with (by default it's only 24. why they didn't load 24 directly is a mystery. They wanted to use this more than once, with different values loaded into $00? world may never know).
   
CODE_CD68:
   STA $2007				;\fill screen(s) with tiles
   DEY					;|
   BNE CODE_CD68			;|
   DEX					;|
   BNE CODE_CD68			;/
   
   LDA $02				;\calculate position of tile attribute data.
   ADC #$03				;|end result is either 23 or 2B
   STA $2006				;/
   
   LDA #$C0				;\attributes location, low byte
   STA $2006				;/
   
   LDY #$40				;64 attribute bytes
   LDA #$00				;zero 'em out
 
CODE_CD81:
   STA $2007				;\this loop clears tile attributes (y'know, 32x32 areas that contain palette data for each individual 16x16 in it tile)
   DEY					;|
   BNE CODE_CD81			;/
   RTS					;
   
CODE_CD88:
   LDX #$01				;seems to handle various timers in game
   DEC $2A				;general timer?
   BPL CODE_CD94			;
   
   LDA #$0A				;restore $2A
   STA $2A				;
   
   LDX #$03				;decrease timers from $2E downto $2B (otherwise only $2C and $2B)
   
CODE_CD94:
   LDA $2B,x				;
   BEQ CODE_CD9A			;
   DEC $2B,x				;decrease some other timers
   
CODE_CD9A:
   DEX					;
   BPL CODE_CD94			;loop
   RTS					;
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Pointer routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Used for 2-byte jumps depending on loaded variable and table values after JSR to this routine.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CODE_CD9E:
   ASL A				;loaded value multiply by 2
   TAY                      		;turn into y
   INY                      		;and add 1 (to jump over jsr's bytes and load table values correctly)
   PLA                      		;pull our previous location that JSR pushed for us
   STA $14                  		;low byte
   PLA                      		;
   STA $15 				;high byte
   
   LDA ($14),Y              		;load new location from the table, low byte
   TAX                      		;turn it into x
   INY                      		;increase Y for high byte
   LDA ($14),Y              		;get it
   STA $15                  		;and store
   STX $14                  		;low byte stored into x goes here
   JMP ($0014)              		;perform jump to set location
   
CODE_CDB4:
   PHA
   CLC
   LDA $14
   ADC $12
   STA $14
   
   LDA $15
   ADC $13
   STA $15
   PLA
   RTS
   
CODE_CDC4:				;this is probably tile drawing routine, that draws specific tiles at specific locations.
   STA $2006				;load locations for tile to draw
   INY					;

   LDA ($00),y				;low byte
   STA $2006				;
   INY					;

   LDA ($00),y				;
   ASL A				;
   PHA					;
   LDA $09
   ORA #$04
   BCS CODE_CDDA
   AND #$FB
   
CODE_CDDA:
   STA $2000
   STA $09
   PLA
   ASL A
   BCC CODE_CDE6
   ORA #$02
   INY

CODE_CDE6:
   LSR A
   LSR A
   TAX
   
CODE_CDE9:
   BCS CODE_CDEC
   INY
   
CODE_CDEC:
   LDA ($00),y
   STA $2007
   DEX
   BNE CODE_CDE9
   SEC
   TYA
   ADC $00
   STA $00
   LDA #$00
   ADC $01
   STA $01
   
CODE_CE00:
   LDX $2002
   LDY #$00
   LDA ($00),y
   BNE CODE_CDC4

CODE_CE09:   
   PHA
   LDA $0B
   STA $2005
   LDA $0C
   STA $2005
   PLA
   RTS

CODE_CE16:
   LDA #$00                 
   STA $03
   
   LDA #$02                 
   STA $04
   
   LDY $02                  
   DEY                      
   LDX $02
   
CODE_CE23:
   LDA ($00),Y              
   STA ($03),Y              
   DEY                      
   DEX                      
   BNE CODE_CE23                
   RTS                      
   
CODE_CE2C:
   LDA #$01                 
   STA $21
   
   LDY #$00
   LDA ($02),Y              
   AND #$0F
   STA $05

   LDA ($02),Y              
   LSR A
   LSR A
   LSR A 
   LSR A      
   STA $04
   
   LDX $0590

CODE_CE43:   
   LDA $01
   STA $0591,X
   
   JSR CODE_CE84
   
   LDA $00                  
   STA $0591,X
   
   JSR CODE_CE84
   
   LDA $05         
   STA $06      
   STA $0591,X 
   
CODE_CE5A:
   JSR CODE_CE84
   
   INY                      
   LDA ($02),Y              
   STA $0591,X              
   DEC $06                  
   BNE CODE_CE5A
   JSR CODE_CE84
   
   STX $0590         
   CLC                      
   LDA #$20  
   ADC $00                  
   STA $00
   
   LDA #$00                 
   ADC $01                  
   STA $01
   
   DEC $04                  
   BNE CODE_CE43
   
   LDA #$00                 
   STA $0591,X              
   RTS

CODE_CE84:   
   INX                      
   TXA

CODE_CE86:   
   CMP #$2F                 
   BCC CODE_CE94
   
   LDX $0590
   
   LDA #$00                 
   STA $0591,X 
   
   PLA                      
   PLA

CODE_CE94:   
   RTS

CODE_CE95:
   LDA $B1                  
   AND #$C0                 
   BEQ CODE_CE9C                
   RTS                      
   
CODE_CE9C:
   LDA $B1                  
   AND #$03                 
   BNE CODE_CEA3                
   RTS                      
  
CODE_CEA3:
   LDY $B4                  
   LDA DATA_F4B2,Y              
   CMP #$FF                 
   BEQ CODE_CEB1
   
   STA $B6                  
   INC $B4                  
   RTS                      

CODE_CEB1:
   INY                      
   LDA DATA_F4B2,Y              
   STA $B4                  
   JMP CODE_CEA3
  
CODE_CEBA:
   LDA #$12
   STA $B6
   
   LDA #$00
   STA $B4
   RTS
   
CODE_CEC3:
   LDA #$60
   STA $A0
   
   LDA #$03
   STA $A1
   
   LDA #$20
   STA $A2
   STA $12
   
   LDA #$00
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
   STA $2E
   TYA

CODE_CF04:   
   STA $35
   
   LDA #$52                      
   STA $14
   
   LDA #$F4            
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
   
CODE_CF67:
   LDA $71                  
   BNE CODE_CF88
   
   LDA $C1                  
   BNE CODE_CF88
   
   LDA $05FF                
   BNE CODE_CF88
   
   LDA $04C5                
   BNE CODE_CF88
   
   LDX $BF                  
   LDY #$01                 
   CPX #$01                 
   BEQ CODE_CF83
   
   LDY #$06
   
CODE_CF83:
   LDA $74,Y              
   BEQ CODE_CF89
  
CODE_CF88:
   RTS                      

CODE_CF89:
   LDX #$00
   
CODE_CF8B:
   LDA $C9                  
   CMP DATA_F574,X              
   BNE CODE_CFA7
   
   LDA $CA
   INX 
   CMP DATA_F574,X              
   BNE CODE_CFA8                
   CPX #$08                 
   BCC CODE_CFC4

CODE_CF9E:
   LDX #$02                 
   LDA #$E0                 
   STA $12                  
   JMP CODE_CFCA
  
CODE_CFA7:
   INX
  
CODE_CFA8:
   INX                      
   CPX #$10                 
   BCC CODE_CF8B
  
   LDA $CB                  
   CMP #$FA                 
   BCC CODE_CFB6                
   JMP CODE_D2DF
   
CODE_CFB6:
   LDA $C9                  
   AND #$1F                 
   BEQ CODE_CF9E                
   CMP #$1F                 
   BEQ CODE_CFC4
   
   LDX #$03                 
   BNE CODE_CFC6
  
CODE_CFC4:
   LDX #$01

CODE_CFC6:  
   LDA #$DF                 
   STA $12
  
CODE_CFCA:
   LDA $CB                  
   CMP #$A0                 
   BCS CODE_CF88
   
   LDA #$FF                 
   STA $13
   
   LDA $CA                  
   STA $15
   
   LDA $C9                  
   STA $14
   
   LDA #$01                 
   STA $83,Y
   
   LDA $BE                  
   CLC                      
   ADC #$01                 
   STA $84,Y
   
   LDA $B9                  
   STA $85,Y              
   JSR CODE_CDB4
   
   LDA $CB                  
   SEC                      
   SBC #$93                 
   STX $00
   
   ASL A                    
   ASL A                    
   ASL A                    
   ASL A                    
   ORA $00                  
   STA $74,Y
   
   DEY                      
   LDA #$00                 
   STA $0074,Y
   
   INY                      
   INY                      
   STA $0074,Y
   
   INY                      
   LDA $14                  
   STA $0074,Y
   
   INY                      
   LDA $15                  
   STA $0074,Y              
   RTS                      
   
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
   
CODE_D02F:
   LDA #$01                 
   STA $21
   
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
   
   LDX $0590                
   LDA DATA_F68D,Y
   
   STA $0591,X              
   JSR CODE_CE84                
   INY
   
   LDA DATA_F68D,Y              
   STA $0591,X
   
   JSR CODE_CE84                
   INY                      
   LDA DATA_F68D,Y              
   AND #$07                 
   STA $0591,X
   STA $01                  
   TXA
   SEC                      
   ADC $01                  
   JSR CODE_CE86
   
   TAX                      
   STX $0590
   
   LDA #$00                 
   STA $0591,X
   INY
   
   LDA DATA_F68D,Y              
   STA $03
   
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
   
   LDY $02                  
   CLC                      
   LDA $90,Y              
   ADC #$37                 
   STA $0591,X
  
CODE_D0B3:
   RTS
   
CODE_D0B4:
   AND #$07                 
   ASL A                    
   ASL A                    
   TAX
   
   LDA $04                  
   BEQ CODE_D0E4
   
   LDA $94,X                
   BEQ CODE_D0E8
   
CODE_D0C1:
   CLC                      
   LDA $97,X                
   STA $03
   
   LDA $07                  
   JSR CODE_D139                
   STA $97,X

   LDA $96,X                
   STA $03

   LDA $06                  
   JSR CODE_D139                
   STA $96,X
   
   LDA $95,X                
   STA $03
   
   LDA $05                  
   JSR CODE_D139                
   STA $95,X                
   RTS

CODE_D0E4:  
   LDA $94,X                
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
  
CODE_D139:
   JSR CODE_D17C                
   ADC $01                  
   CMP #$0A                 
   BCC CODE_D144                
   ADC #$05
  
CODE_D144:
   CLC                      
   ADC $02                  
   STA $02                  
   LDA $03                  
   AND #$F0                 
   ADC $02                  
   BCC CODE_D155

CODE_D151:   
   ADC #$5F                 
   SEC                      
   RTS

CODE_D155:   
   CMP #$A0
   BCS CODE_D151
   RTS

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
   
CODE_D17C:
   PHA                      
   AND #$0F                 
   STA $01                  
   PLA                      
   AND #$F0                 
   STA $02

   LDA $03                  
   AND #$0F                 
   RTS

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
   
   ;.db $20,$5A,$D1,$B0,$30,$B9,$90,$00
   
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
   LDA $71                  
   BNE CODE_D217

   LDA $2F                  
   LSR A                   
   LDY #$00                 
   BCC CODE_D20F                
   LDY #$05

CODE_D20F:   
   STY $05                  
   INY                      
   LDA $0074,Y
   BNE CODE_D218
   
CODE_D217:
   RTS                      

CODE_D218:
   STA $10                  
   AND #$F0                 
   STA $00
   LSR A
   LSR A
   LSR A
   CLC                      
   ADC $00                  
   ADC #$A0                 
   STA $01

   INY                      
   LDA $74,Y
   
   TAX                      
   CLC
   ADC #$01                 
   STA $74,Y 
   
   LDA DATA_F81C,X
   CMP #$AA                 
   BEQ CODE_D297
   
   ASL A                    
   STA $00
   
   ASL A
   CLC                      
   ADC $00
   ADC $01
   STA $11

   LDA $10                  
   AND #$0F                 
   CMP #$01
   BNE CODE_D251
   
   LDA #$D8                 
   BNE CODE_D257
   
CODE_D251:
   CMP #$02
   BNE CODE_D25B
   
   LDA #$6C
   
CODE_D257:
   LDX #$22
   BNE CODE_D25F

CODE_D25B:
   LDA #$FC                 
   LDX #$23
   
CODE_D25F:   
   STX $0540
   STA $10
   
   LDA #$00                 
   STA $07
   
   LDX #$00
   
CODE_D26A:
   ASL $10
   BCC CODE_D277
   
   LDA $07                  
   CLC                      
   ADC $11                  
   STA $0541,X
   
   INX
   
CODE_D277:
   INC $07
   
   LDA $07                  
   CMP #$06                 
   BNE CODE_D26A

CODE_D27F:
   INY                      
   LDA $74,Y        
   STA $00
   
   INY                      
   LDA $74,Y              
   STA $01
   
   LDA #$40   
   STA $02
   
   LDA #$05                 
   STA $03
   
   JSR CODE_CE2C                
   RTS                      

CODE_D297:
   LDA #$00                 
   STA $84,Y
   
   LDA $10                  
   LSR A                    
   LSR A                    
   LSR A                    
   LSR A                    
   CLC                      
   ADC #$93                 
   TAX
   
   LDA #$24                 
   STA $0541                
   STA $0542                
   STA $0543
   
   LDA $10                  
   AND #$0F                 
   CMP #$03                 
   BNE CODE_D2C7 
   
   TXA                      
   STA $0544                
   STA $0545                
   STA $0546                
   LDA #$23                 
   BNE CODE_D2D0
  
CODE_D2C7:
   TXA                      
   STA $0543                
   STA $0544
   
   LDA #$22
   
CODE_D2D0:   
   STA $0540
   
   LDY $05                  
   INY                      
   LDA #$00                 
   STA $74,Y
   
   INY                      
   JMP CODE_D27F

CODE_D2DF:
   LDA PowHitsLeft			;if POW can still be hit
   BNE CODE_D2E4			;run interaction
   RTS                      

CODE_D2E4:
   LDA POWPowerTimer			;if POW isn't in effect
   BEQ CODE_D2E9			;hit everything
   RTS

CODE_D2E9:
   LDA #$0F				;set POW effect timer 
   STA POWPowerTimer
   
   LDA $BF
   STA $72
   
   LDA #$00
   STA $2C
   
   DEC PowHitsLeft			;POW's "hitpoints" -1
   JSR CODE_D593
   
   LDA $FF                  
   ORA #$02                 
   STA $FF        
   RTS
   
CODE_D301:
   LDA POWPowerTimer			;if POW's in effect
   BNE CODE_D306			;decrease timers
   RTS					;
   
CODE_D306:
   LDA $2C				;
   BEQ CODE_D30B			;
   RTS					;
   
CODE_D30B:
   LDA #$01				;
   STA $2C				;
   
   DEC POWPowerTimer			;decrease POW's effect timer
   
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
   
CODE_D328:
   LDA $0500
   AND #$02
   STA $07
   
   LDA $0501
   AND #$02
   EOR $07
   CLC
   BEQ CODE_D33A
   SEC

CODE_D33A:
   ROR $0500
   ROR $0501
   ROR $0502
   ROR $0503

   LDA $0500
   RTS
   
CODE_D34A:				;
   LDA $2D				;wait a little
   BNE CODE_D3A7			;
   
   LDA #$00				;
   STA $31				;
   STA $41				;reset number display
   
   LDA #$03				;
   STA PowHitsLeft			;initialize POW's hitpoints
   
   LDX #$02				;
   LDY #$00				;
   STX Player1Lives			;set first player's lifes
   STY GameOverFlag			;reset general gameover flag
   STY $AD				;
   
   LDA DemoFlag				;check if it's a demo movie (?)
   BEQ CODE_D36D			;if not, welp
   
   LDA #$55				;
   STA $31				;timer?
   JMP CODE_D37D			;demo always has 2 players
   
CODE_D36D:
   LDA $29				;if game mode is 2 Players mode
   CMP #$02				;
   BCS CODE_D37D			;set lives for second player as well
   
   STY Player2Lives			;otherwise don't display luigi's lifes
   STY Player2ScoreDisplay		;and his score
   
   LDY #$FF				;
   LDA #$00				;
   BEQ CODE_D381			;
   
CODE_D37D:
   STX Player2Lives			;luigi's lifes

   LDA #$02				;

CODE_D381:
   STY $4E				;either disable or enable 2nd player sprite
   STY $AE				;?
   STA $39				;disable or enable second player's score display (not sure how it works)
   
   LDA #$00				;reset gameover flag for both mario and luigi
   STA $49				;
   STA $4D				;
   
   LDX #$07				;

CODE_D38F:
   STA $94,x				;this loop clears mario and luigi's scores
   DEX					;
   BPL CODE_D38F			;
   
   LDY #$00				;\check if it's game A or B
   LDA $29				;|check chosen option
   BEQ CODE_D39F			;|0 - Game A was chosen
   CMP #$02				;|
   BEQ CODE_D39F			;|2 - Game A 2 Players was chosen
   INY					;/otherwise it's game B
   
CODE_D39F:
   STY GameAorBFlag			;
   
   LDA #$01				;\use gameplay palette
   STA PaletteFlag			;/
   INC $40				;change game state

CODE_D3A7:
   RTS					;
   
CODE_D3A8:
   LDA $2D				;more timer before transitions
   BNE CODE_D3A7			;
   
   LDA #$00                 		;reset lotta flags 'n values
   STA MarioGameOverFlag                ;mario's gameover flag
   STA LuigiGameOverFlag                ;luigi's gameover flag
   STA $51                  
   STA $46                  
   STA $05FB                
   STA $05FC
   STA $43                  
   STA $44                  
   STA $45                  
   STA $46
   
   LDX #$03
   
CODE_D3C6:
   STA $FC,X                
   DEX                      
   BPL CODE_D3C6
   
   LDA $30                  
   BNE CODE_D3F5
   
   JSR CODE_D60F                
   JSR CODE_D5E6                
   JSR CODE_D5EC
   
   LDA $41                  
   CMP #$01                 
   BNE CODE_D3ED
   
   LDA #$08                 
   STA $40
   
   LDA #$18                 
   STA $2D
   
   LDA #$01                 
   STA $FD                  
   
CODE_D3EA:
   JMP CODE_E13D    

 CODE_D3ED:
   LDA #$02
   STA $FD
   
   LDA #$0C                 
   STA $2D
   
CODE_D3F5:
   INC $40				;next game state
   BNE CODE_D3EA
   
CODE_D3F9:
   JSR CODE_E132        		;call NMI and enable rendering (probably (it doesn't actually))       
   JSR CODE_CA20                
   JSR CODE_CA2B                
   JSR CODE_D508                
   JSR CODE_D61D
   
   INC $40  				;next game state?                
   RTS               			;       
   
CODE_D40B:
   JSR CODE_E132 			;    
   JSR CODE_CA20            		;   
   JSR CODE_CA2B
   
   LDX #$A5                 
   LDY #$F0                 
   JSR CODE_D5D5
   
   LDA #$02                 
   STA $3F
   
   LDA #$01                 
   STA $28
   
   LDA #$89                 
   STA $00
   
   LDA #$F6                 
   STA $01
   
   LDA #$04                 
   STA $02                  
   JSR CODE_CE16
   
   INC $50
   
   LDY $52                  
   BNE CODE_D440
   
   LDY #$02                 
   STY $52
   
   LDA #$4F                 
   BNE CODE_D444
  
CODE_D440:
   DEC $52
   
   LDA #$25

CODE_D444:  
   STA $2D                  
   BNE CODE_D3EA
   
CODE_D448:
   LDA $2D                  
   BNE CODE_D450
   
   LDA #$00                 
   STA $50

CODE_D450:   
   RTS
   
CODE_D451:
   LDA $2D                  
   BNE CODE_D459
   
   LDA #$04                 
   BNE CODE_D47A
   
CODE_D459:
   JMP CODE_E1F7
   
CODE_D45C:
   LDA $2B                  
   BEQ CODE_D46F                
   CMP #$0A                 
   BNE CODE_D47C
   
   LDA Reg2001BitStorage		;\
   ORA #$10				;|enable sprite render
   STA $2001				;|
   STA Reg2001BitStorage		;/
   BNE CODE_D47C			;always branch, though RTS would've fit in here (and it'd save 1 byte of space)
   
CODE_D46F:
   LDX #$05
   
CODE_D471:
   LDA $5A,X                
   STA $2A,X                
   DEX                      
   BPL CODE_D471

   LDA $3B
   
CODE_D47A:
   STA $40
   
CODE_D47C:
   RTS

CODE_D47D:   
   LDY $2D                  
   BEQ CODE_D48E                
   CPY #$4B                 
   BNE CODE_D48D
   
   LDA #$80                 
   STA $FD

   LDY #$48                 
   STY $2D
   
CODE_D48D:
   RTS                      

CODE_D48E:
   INC $50
   RTS
   
CODE_D491:
   INC $50                  
   JMP CODE_D34A

CODE_D496:   
   INC $50
   JMP CODE_E14A
   
CODE_D49B:
   INC $50
   JMP CODE_D3F9
   
CODE_D4A0:
   INC $50
   
   LDA #$00                 
   STA $55                  
   STA $56                  
   STA $57                  
   STA $58
   
   JMP CODE_D3A8

CODE_D4AF:   
   LDY $56                  
   BNE CODE_D4CA
   
   LDX $55                  
   LDA DATA_F823,X              
   CMP #$AA                 
   BEQ CODE_D4F8
   STA $19
   
   INX                      
   LDA DATA_F823,X              
   STA $56                  
   INX                      
   STX $55                  
   JMP CODE_D4D4
  
CODE_D4CA:
   DEY                      
   STY $56

   LDA $0310                
   AND #$03                 
   STA $19
  
CODE_D4D4:
   LDY $58                  
   BNE CODE_D4EB
   
   LDX $57                  
   LDA DATA_F854,X              
   STA $1B                  
   INX                      
   LDA DATA_F854,X              
   STA $58                  
   INX                      
   STX $57                  
   JMP CODE_D4F5
  
CODE_D4EB:
   DEY                      
   STY $58
   
   LDA $0330                
   AND #$03                 
   STA $1B
  
CODE_D4F5:
   JMP CODE_C5A3

CODE_D4F8:  
   LDA #$05                 
   STA $2D

   INC $50                                     
   
CODE_D4FE:
   LDA #$00
   LDX #$03

CODE_D502:
   STA $FC,x
   DEX
   BPL CODE_D502
   RTS

CODE_D508:
   JSR CODE_CA3B
   
   LDA $32                  
   CLC                      
   ADC #$93                 
   STA $07
   
   LDX #$00                 
   LDY #$00                 
   STY $1C

CODE_D518:
   LDA #$03                 
   STA $02

CODE_D51C:
   LDA DATA_F1E7,Y              
   STA $0540,X              
   INY                      
   INX                      
   DEC $02                  
   BNE CODE_D51C
   
   LDA $1C                  
   BEQ CODE_D53A
   
   LDA #$92                 
   STA $0540,X              
   INX
   
   LDA $1C                  
   CMP #$02                 
   BEQ CODE_D54F                
   BNE CODE_D54A
  
CODE_D53A:
   LDA DATA_F1E7,Y              
   STA $00
   
   LDA $07                  
   STA $0540,X              
   INX
   
   LDA $00                  
   BNE CODE_D518                
   INY
   
CODE_D54A:
   INC $1C                  
   JMP CODE_D518
  
CODE_D54F:
   LDA #$00                 
   STA $0540,X
   
   LDX #$40                 
   LDY #$05                 
   JSR CODE_D5D5                
   JSR CODE_D58C                
   JSR CODE_D593                
   JSR CODE_D5BE
   
   LDA #$00                 
   LDX #$09
   
CODE_D568:
   STA $74,X                
   DEX                      
   BPL CODE_D568                
   RTS                      
   
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

CODE_D58C:
   LDX #$F5                 
   LDY #$F4                 
   JMP CODE_D5D5                
   
CODE_D593:
   LDA $70                  
   ASL A                    
   ASL A                    
   CLC                      
   ADC $70                  
   STA $12
   
   LDA #$00                 
   STA $13
   
   LDA #$60                 
   STA $14
   
   LDA #$F5                 
   STA $15                  
   JSR CODE_CDB4
   
   LDA #$AF                 
   STA $00
   
   LDA #$22
   STA $01   
   
   LDA $14                  
   STA $02        
   
   LDA $15                  
   STA $03                  
   JMP CODE_CE2C                

CODE_D5BE:
   LDX #$60                 
   LDY #$F6                 
   JSR CODE_D5D5
   
   LDA #$01                 
   STA $9D
   
   LDA $39                  
   BEQ CODE_D5E5
   
   LDA #$01                 
   STA $9E
   
   LDX #$6B                 
   LDY #$F6                 
   
CODE_D5D5:
   STX $00                  
   STY $01                  
   JMP CODE_CE00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;NMI Wait
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This block of code specifically waits for NMI to happen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CODE_D5DC:
   LDA #$00                 		;reset wait flag
   STA InterruptedFlag             	;
   NOP					;and a single NOP for some reason
   
CODE_D5E1:
   LDA InterruptedFlag              	;wait for NMI to happen
   BEQ CODE_D5E1			;

CODE_D5E5:
   RTS					;
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   
CODE_D5E6:
   LDX Player1Lives			;load number of player 1's lives to display
   
   LDY #$D0				;OAM offset
   BNE CODE_D5F0			;Always branch

CODE_D5EC:
   LDX Player2Lives			;load number of player 2's lives to display
   LDY #$DC				;

CODE_D5F0:   
   LDA DemoFlag				;if it's demo recording, don't show lives
   BNE CODE_D609			;
   
   LDA #$03				;can only display max 3 lives for each player
   STA $1E				;

   LDA #$20				;Y-position onscreen
   INX					;

CODE_D5FB:   
   DEX                      		;if lives shouldn't be shown in case player doesn't have enough
   BEQ CODE_D60A			;don't show up
   
CODE_D5FE:
   STA $0200,Y				;set Y-position of OAM tile with given offset
   INY					;\
   INY					;|
   INY					;|
   INY					;/next tile's Y-position
   DEC $1E				;life limit to be shown
   BNE CODE_D5FB			;if not all, loop

CODE_D609:  
   RTS					;

CODE_D60A:  
   LDA #$F4				;"Hide zone" - Y-position were sprite tiles don't render (i'll probably need to move this term somewhere on top)
   INX					;they could've used INX right before CODE_D5FE
   BNE CODE_D5FE			;that'd save 1 byte of space. I know, that's a lot.

;this prepares life display, load values from table, tiles, props and X-positions
;Y-positions point to "Hide zone", but they're get overwritten afterwards.
CODE_D60F:
   LDY #$00				;

CODE_D611:   
   LDA DATA_F671,Y			;load in next order: Y-pos, sprite tile, tile prop, X-pos
   STA $02D0,Y				;

   INY					;
   CPY #$18				;loop untill all 6 tiles are initialized ($18/4)
   BNE CODE_D611			;
   RTS					;
   
CODE_D61D:
   LDA $30                  
   BNE CODE_D67E
   
   LDA #$24                 
   STA $01
   
   LDX #$00                 
   LDA $41                  
   AND #$F0                 
   BEQ CODE_D634
   LSR A                    
   LSR A                    
   LSR A                    
   LSR A                    
   STA $00,X
   INX
  
CODE_D634:
   LDA $41                  
   AND #$0F                 
   STA $00,X
   
   LDY #$12

CODE_D63C:   
   LDA DATA_F722,Y              
   STA $0540,Y
   DEY                      
   BPL CODE_D63C
   
   LDA $00                  
   STA $0549                
   STA $0550
   
   LDA $01                  
   STA $054A                
   STA $0551
   
   LDA #$FF                 
   STA $04F1
   
   LDX #$40                 
   LDY #$05                 
   JSR CODE_D5D5
   
   LDA $04B0                
   BEQ CODE_D67E 
   
   LDA #$F0                 
   STA $04F0
   
   LDX #$35                 
   LDY #$F7                 
   JMP CODE_D5D5                
   
CODE_D672:
   LDA #$01                 
   STA $03                  
   CLC                      
   LDA $41                  
   JSR CODE_D139                
   STA $41

CODE_D67E:   
   RTS                      

CODE_D67F:
   LDY #$1F                 
   LDX #$1F
   
   LDA $4E                  
   BNE CODE_D68F
   
   LDX #$3F
   
   LDA $4A                  
   BNE CODE_D68F
   
   LDY #$3F
   
CODE_D68F:
   LDA DATA_F2EC,X              
   STA $0300,X              
   DEX                      
   DEY                      
   BPL CODE_D68F                
   RTS                      
 
CODE_D69A:
   LDA #$BA                 
   STA $14
   
   LDA #$F3                 
   STA $15
   
   LDA $34                  
   JSR CODE_CC29
   
   LDA $12                  
   STA $36
   
   LDA $13                  
   STA $37
   
   LDA #$00                 
   STA $35
   
   LDY #$00                 
   LDA ($36),Y              
   STA $2E                  
   RTS                      

   
CODE_D6BA:
   LDA $BF                  
   AND #$0F                 
   BNE CODE_D710
   
   LDA $BF                  
   LDX #$84                 
   LDY #$F5                 
   CMP #$10
   BEQ CODE_D6E6
   
   LDX #$8C                 
   LDY #$F5                 
   CMP #$20                 
   BEQ CODE_D6E6
   
   LDX #$96                 
   LDY #$F5                 
   CMP #$30                 
   BEQ CODE_D6E6
   
   LDX #$9E                 
   LDY #$F5                 
   CMP #$80                 
   BEQ CODE_D6E6
   
   LDX #$A4                 
   LDY #$F5
  
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
   JSR CODE_D90D                
   CMP #$02                 
   BEQ CODE_D744                
   RTS
   
CODE_D744:
   LDA $BF
   CMP #$20                 
   BNE CODE_D767
   
   LDA $B4                  
   CMP #$1A                 
   BCC CODE_D753                
   JMP CODE_D877
  
CODE_D753:
   LDA #$1A                 
   STA $B4                  
   INC $C4                  
   JSR CODE_CAB9
   
   LDA $05F8                
   AND #$03                 
   STA $C1
   
   LDA #$04                 
   BNE CODE_D797
  
CODE_D767:
   CMP #$40                 
   BEQ CODE_D77F                
   CMP #$80                 
   BNE CODE_D792
   
   LDA $FE                  
   ORA #$01                 
   STA $FE
   
   LDA #$F4                 
   STA $02B0                
   STA $02B4                
   BNE CODE_D785

CODE_D77F:  
   LDA $FE                  
   ORA #$02                 
   STA $FE
  
CODE_D785:
   LDA $9F
   STA $CC

CODE_D789:
   LDY #$04                 
   JSR CODE_DFC4
   
   LDA #$06                 
   BNE CODE_D797

CODE_D792:  
   JSR CODE_EE82                
   LDA #$01

CODE_D797:   
   ORA $00
   STA $C0                  
   LDY #$04                 
   
CODE_D79D:
   JSR CODE_D9E0
   
   LDA $B1                  
   AND #$3F                 
   ORA #$80                 
   STA $B1
   
   LDY #$00
   
CODE_D7AA:
   LDA ($06),Y              
   STA $BC
   
   INY                      
   LDA ($06),Y              
   STA $BD 
   
   LDA $C0                  
   AND #$0F                 
   CMP #$01                 
   BNE CODE_D7C1

   LDA $FF                  
   ORA #$10                 
   STA $FF

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
   LDA #$00                 
   STA $C0                  
   RTS                      

CODE_D871:
   LDA $B1                  
   AND #$BF                 
   STA $B1
   
CODE_D877:
   JSR CODE_EE82
   
   LDA #$01                 
   ORA $00                  
   STA $C0                  
   LDY #$08                 
   JMP CODE_D79D

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

   LDA $B8                  
   CLC                      
   ADC #$0B                 
   TAX

   LDY $B9

   LDA $CC                  
   STA $11
   
   LDA $BF                  
   CMP #$80                 
   BEQ CODE_D8E5
   
   LDA #$00                 
   JSR CODE_EEE3        
   
   LDY #$08
   BNE CODE_D8F1
  
CODE_D8E5:
   LDA #$05                 
   JSR CODE_EEE3                
   LDA #$00                 
   STA $04C1
   
   LDY #$05

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
   LDA $71                  
   BNE CODE_D988
   
   LDA $CD                  
   JSR CODE_CAA4                
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
   LDY $72                  
   DEY                      
   STY $9F                  
   JMP CODE_D979
   
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
   
   LDA #$4D                 
   LDY #$F6                 
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
   LDA #$43                 
   LDY #$F6                 
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

CODE_DA7E:  
   JSR CODE_DB34                
   JSR CODE_CAB9
   
   LDA $B7                  
   AND #$DF                 
   STA $B7
   
   LDA #$00                 
   STA $C2
   
   LDA $BF                  
   CMP #$30                 
   BNE CODE_DAC0
   
   LDA #$7B                 
   LDY #$F3                 
   STA $BC                  
   STY $BD
   
   LDA $B1                  
   AND #$3F                 
   ORA #$40                 
   STA $B1                  
   RTS

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

CODE_DAC1:   
   LDY $B9                  
   LDA $C2                  
   LSR A                    
   BCS CODE_DAE3                
   CPY #$18                 
   BCS CODE_DAC0
   
   LDA #$10                 
   STA $B9
   
   LDA $05FB                
   BNE CODE_DB19                
   JSR CODE_DFD3
   
   LDA #$01                 
   STA $05FB                
   LDA #$28                 
   LDY #$01                 
   BNE CODE_DAFC
  
CODE_DAE3:
   CPY #$E8                 
   BCC CODE_DAC0
   
   LDA #$F0                 
   STA $B9
   
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
   
   LDA $BF                  
   CMP #$30                 
   BNE CODE_DB18                
   TYA                      
   ORA #$80                 
   STA $B1
  
CODE_DB18:
   RTS                      

CODE_DB19:
   LDA #$F4
   STA $B8
   RTS
   
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
   
CODE_DB34:
   LDA $BF                  
   LDX #$10                 
   CMP #$10                 
   BEQ CODE_DB4A
   
   LDX #$20                 
   CMP #$20                 
   BEQ CODE_DB4A                
   LDX #$40                 
   CMP #$30                 
   BEQ CODE_DB4A                
   LDX #$08
  
CODE_DB4A:
   STX $1E                  
   LDA $FE                  
   ORA $1E                  
   STA $FE                  
   RTS
   
CODE_DB53:
   LDY $33                  
   DEY                      
   BEQ CODE_DB33
   STY $11
   
   LDA $2F                  
   AND #$01                 
   BNE CODE_DB6B                
   CPY #$03                 
   BEQ CODE_DB6A                
   CPY #$04                 
   BEQ CODE_DB6A                
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
   
   LDA #$7B                 
   STA $BC
   
   LDA #$F3                 
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
   LDY #$10                 
   LDA ($14),Y
   AND #$0F
   BEQ CODE_DCCE
  
   CMP #$04                 
   BCC CODE_DD2C

CODE_DCCE:  
   LDA #$00                 
   STA $05FF
   
   LDY $BF                  
   LDX #$00                 
   DEY                      
   BEQ CODE_DCDC
   
   LDX #$04

CODE_DCDC:  
   LDA $48,X                
   BEQ CODE_DCE5
  
   DEC $48,X                
   JMP CODE_DCEA

CODE_DCE5:  
   INX                      
   LDA #$01                 
   STA $48,X

CODE_DCEA:  
   LDA #$10                 
   STA $C6
   
   LDA #$40                 
   STA $B3
   
   LDA #$32                 
   STA $B6
   
   LDA #$00                 
   STA $B5
   
   LDA #$A9                 
   LDY #$F6                 
   STA $BC                  
   STY $BD
   
   LDA $FF                  
   ORA #$01                 
   STA $FF
   
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
   LDA ($14),Y              
   EOR #$03                 
   STA ($14),Y

   LDY #$03                 
   LDA #$20                 
   STA ($14),Y              
   RTS 
  
CODE_DD2C:
   LDA $46                  
   BEQ CODE_DD3C                
   LDA #$00                 
   STA $FE                  
   STA $FD                  
   STA $FC

   LDA #$04
   BNE CODE_DD40

CODE_DD3C:  
   LDA $FF                  
   ORA #$08

CODE_DD40:  
   STA $FF                  
   LDA #$10                 
   LDY #$19                 
   STA ($14),Y

   LDA #$E9                 
   LDY #$0C                 
   STA ($14),Y
   
   LDA #$F7                 
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
   LDA $04D0,X              
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
   JSR CODE_EEE3
   
   LDX $1F                  
   LDA DATA_DDB0,X              
   JMP CODE_DDB6

DATA_DDB0:
.db $08,$16,$24,$32				;

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
   
   DEY                      
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
   
   LDA #$74
   
CODE_DF11:
   STA $B9
   
   LDA #$09                 
   STA $B8
   
   LDA #$02                 
   STA $C6
   
   LDA $FD                  
   ORA #$10                 
   STA $FD                  
   JMP CODE_CEBA

CODE_DF24:  
   JSR CODE_D5EC
   
   LDA $4D                  
   BNE CODE_DEFE
   
   LDY #$3F                 
   JSR CODE_DEA3                
   JSR CODE_DFAC  
   LDA #$8C                 
   BNE CODE_DF11

CODE_DF37:  
   CMP #$02                 
   BNE CODE_DF60                
   JSR CODE_CAEB
   
   INC $B8                  
   JSR CODE_DFB0
   
   INC $02C0,X              
   INC $02C4,X
   
   LDA $B8                  
   CMP #$28                 
   BEQ CODE_DF50                
   RTS
   
CODE_DF50:
   LDA #$04                 
   LDY $BF                  
   DEY                      
   BEQ CODE_DF59
   
   LDA #$08

CODE_DF59:   
   STA $C6                  
   
CODE_DF5B:
   LDA #$FF
   STA $B3
   RTS

CODE_DF60:   
   LDA $B1                  
   BEQ CODE_DF87                
   BMI CODE_DF6C                
   AND #$08                 
   BNE CODE_DF87                
   BEQ CODE_DF72
   
CODE_DF6C:
   LDA #$18                 
   STA $B6                  
   BNE CODE_DF75
  
CODE_DF72:
   JSR CODE_CEA3
  
CODE_DF75:
   LDA #$00                 
   STA $C6                  
   STA $B3

   JSR CODE_DFB0
   
   LDA #$F4                 
   STA $02C0,X              
   STA $02C4,X
  
CODE_DF86:
   RTS                      
   
CODE_DF87:
   LDA $B3                  
   BNE CODE_DF86                
   JSR CODE_DFB0                
   LDA $02C1,X              
   CMP #$CF                 
   BEQ CODE_DF75
   
   INC $02C1,X              
   INC $02C5,X              
   BNE CODE_DF5B     
   
CODE_DF9D:
   LDY #$07

CODE_DF9F:   
   LDX #$07

CODE_DFA1:   
   LDA DATA_F699,Y              
   STA $02C0,Y              
   DEY                      
   DEX                      
   BPL CODE_DFA1                
   RTS

CODE_DFAC:
   LDY #$0F
   BNE CODE_DF9F

CODE_DFB0:
   LDX #$08
   LDY $BF
   DEY
   BNE CODE_DFB9
   
   LDX #$00
   
CODE_DFB9:
   RTS
   
CODE_DFBA:
   JSR CODE_DFBD
   
CODE_DFBD:
   INC $05FA
   INC $05FA
   RTS
   
CODE_DFC4:
   LDA #$F4
   LDX $BA
   
CODE_DFC8:
   STA $0200,x
   INX
   INX
   INX
   INX
   DEY
   BNE CODE_DFC8
   RTS
   
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
   
CODE_DFF8:
   LDA $21                  
   BNE CODE_DFF7
   
   LDA $04C5                
   BNE CODE_DFF7
   
   LDX #$A8                 
   LDY #$E0                 
   LDA $04F0                
   BEQ CODE_E00F
   
   DEC $04F0                
   BEQ $E049
   
CODE_E00F:
   LDA $04F1                
   BEQ CODE_E023
   
   DEC $04F1                
   BNE CODE_E023
   
   LDA #$49                 
   STA $00
   
   LDA #$22                 
   STA $01                  
   BNE CODE_E051
  
CODE_E023:
   LDX #$88                 
   LDY #$E0                 
   LDA $49
   BEQ CODE_E058
   
   LDA $0300                
   BNE CODE_E058
   
   LDA $39                  
   BEQ CODE_E03C
   
   LDA $4E                  
   BNE CODE_E03C
   
   LDX #$78                 
   LDY #$E0
  
CODE_E03C:
   LDA #$00                 
   STA $49
   
   LDA #$FF                 
   STA $4A

   
CODE_E044:
   LDA #$FF                		 ;
   STA $04F0
   
   LDA #$89                 
   STA $00
   
   LDA #$21                 
   STA $01
  
CODE_E051:
   STX $02                  
   STY $03                  
   JMP CODE_CE2C
  
CODE_E058:
   LDA $4D                  
   BEQ CODE_E077
   
   LDA $0320                
   BNE CODE_E077
   
   LDA $39                  
   BEQ CODE_E06D
   
   LDA $4A                  
   BNE CODE_E06D
   
   LDX #$98                 
   LDY #$E0

CODE_E06D:  
   LDA #$00                 
   STA $4D
   
   LDA #$FF                 
   STA $4E
   BNE CODE_E044
  
CODE_E077:
   RTS                      
   
DATA_E078:
.db $1F,$16,$0A,$1B,$12,$18,$24,$10
.db $0A,$16,$0E,$24,$18,$1F,$0E,$1B
.db $1F,$24,$24,$24,$10,$0A,$16,$0E
.db $24,$18,$1F,$0E,$1B,$24,$24,$24
.db $1F,$15,$1E,$12,$10,$12,$24,$10
.db $0A,$16,$0E,$24,$18,$1F,$0E,$1B
.db $1F,$24,$24,$24,$24,$24,$24,$24
.db $24,$24,$24,$24,$24,$24,$24,$24
   
CODE_E0B8:
   LDA #$03                 
   STA $01
   
   LDA #$00                 
   STA $00 
   TAY                      
   JSR CODE_CA35
   
   LDA #$04                 
   STA $01
   
   LDA #$00                 
   STA $00                  
   TAY                      
   JMP CODE_CA35                

DATA_E0D0:
.db $00,$00,$00,$00,$01,$00,$00,$00
.db $AA,$03,$20,$02,$01,$00,$00,$03
.db $01,$01,$00,$04,$02,$01,$01,$05
.db $02,$01,$01,$AA,$04,$20,$06,$03
.db $02,$01,$07,$03,$02,$01,$08,$03
.db $02,$02,$09,$03,$02,$02,$AA,$04
.db $15,$0A,$03,$03,$02,$07,$03,$03
.db $02,$09,$03,$03,$03,$09,$03,$03
.db $04,$AA,$04,$15,$0A,$03,$03,$04
.db $07,$03,$03,$04,$09,$03,$03,$04
.db $09,$03,$03,$04,$FF,$0B,$00,$00
.db $00
   
CODE_E129:
   LDA $2D                  
   BNE CODE_E131
   
   LDA $3B                  
   STA $40
   
CODE_E131:
   RTS                      
   
CODE_E132:
   JSR CODE_D5DC			;wait for NMI

   LDA Reg2001BitStorage		;\
   AND #$E7				;|turn off sprite and background display
   STA $2001				;/
   RTS					;
   
CODE_E13D:
   JSR CODE_D5DC			;wait for NMI
   
   LDA Reg2001BitStorage		;\
   ORA #$18				;|enable sprites and background display
   STA $2001				;|
   STA Reg2001BitStorage		;/
   RTS					;

CODE_E14A:   
   JSR CODE_E0B8
   
   LDX $31
   
CODE_E14F:
   LDA DATA_E0D0,X              
   CMP #$AA                 
   BNE CODE_E188                
   INX                      
   LDA DATA_E0D0,X              
   STA $32
   
   INX                      
   LDA DATA_E0D0,X              
   STA $04B1
   
   INX                      
   STX $31
   
   LDA $41                  
   CMP #$07                 
   BCC CODE_E170
   
   LDA #$03                 
   STA PowHitsLeft
  
CODE_E170:
   LDA #$BB                 
   STA $35
   
   JSR CODE_D67F
   
   LDA #$00                 
   STA $030A
   
   LDA #$18                 
   STA $032A
   
   LDA #$01                 
   STA $04B0
   BNE CODE_E1C4
  
CODE_E188:
   CMP #$FF                 
   BNE CODE_E190
   
   LDX #$41                 
   BNE CODE_E14F
  
CODE_E190:
   LDA DATA_E0D0,X              
   STA $34
   
   INX                      
   LDA DATA_E0D0,X              
   STA $32
   
   INX                      
   LDY #$01                 
   LDA $41                  
   CMP #$08                 
   BCC CODE_E1A7                
   STY $04C0
   
CODE_E1A7:
   LDA DATA_E0D0,X              
   STA $04F3
   
   INX                      
   LDA DATA_E0D0,X              
   STA $04FC                
   INX                      
   STX $31
   
   LDA #$00                 
   STA $35                  
   JSR CODE_E97A                
   JSR CODE_D67F                
   JSR CODE_D69A
   
CODE_E1C4:
   JSR CODE_D672               
   JSR CODE_D3F9
   
   LDA #$02                 
   BNE CODE_E1F4                
   
CODE_E1CE:
   LDA $35                  
   CMP #$AA                 
   BNE CODE_E1F6
   
   LDA $45                  
   BNE CODE_E1F6
   
   LDA $2D                  
   BNE CODE_E1F6
   
   LDY #$FF                 
   LDA $49
   
   BEQ CODE_E1E4                
   STY $4A
   
CODE_E1E4:
   LDA $4D                  
   BEQ CODE_E1EA                
   STY $4E
   
CODE_E1EA:
   LDA #$10
   
CODE_E1EC:
   STA $2D
   
   LDA #$01                 
   STA $3B
   
   LDA #$09

CODE_E1F4:   
   STA $40

CODE_E1F6:   
   RTS                      
   
CODE_E1F7:
   LDA $21                  
   BNE CODE_E219
   
   LDA $04C5                
   BNE CODE_E219
   
   LDY #$00                 
   LDA $9D                  
   BEQ CODE_E20F                
   STY $9D
   
   LDA #$F0

CODE_E20A:   
   STA $00                  
   JMP CODE_D02F
  
CODE_E20F:
   LDA $9E                  
   BEQ CODE_E219                
   STY $9E
   
   LDA #$F1                 
   BNE CODE_E20A
  
CODE_E219:
   RTS                      
   
CODE_E21A:
   LDA #$F9                 
   STA $00                  
   JSR CODE_D18B
   
   LDA $AD                  
   BNE CODE_E239
   
   LDA $4A                  
   BNE CODE_E239
   
   LDA $95                  
   CMP #$02                 
   BCC CODE_E239
   
   INC $AD                  
   INC $48                  
   JSR CODE_D5E6                
   JMP CODE_E24E
  
CODE_E239:
   LDA $AE                  
   BNE CODE_E25F
   
   LDA $4E                  
   BNE CODE_E25F
   
   LDA $99                  
   CMP #$02                 
   BCC CODE_E25F
   
   INC $AE                  
   INC $4C                  
   JSR CODE_D5EC
  
CODE_E24E:
   LDA $2D                  
   BEQ CODE_E258
   
   LDA #$01                 
   STA $54                  
   BNE CODE_E25E
  
CODE_E258:
   LDA $FD                  
   ORA #$08                 
   STA $FD

CODE_E25E:  
   RTS                      

CODE_E25F:
   LDA $2D                  
   BNE CODE_E25E
   
   LDA $54                  
   BEQ CODE_E25E
   
   LDA #$00                 
   STA $54                  
   BEQ CODE_E258

CODE_E26D:   
   LDA $4A                  
   BEQ CODE_E25E
   
   LDA $4E                  
   BEQ CODE_E25E
   
   LDA #$00                 
   STA $52
   
   JSR CODE_D4FE
   
   LDA #$40                 
   STA $FD
   
   LDA #$20                 
   STA $2D
   
   LDA #$0B                 
   STA $40
   
   JMP CODE_CA2B
   
CODE_E28B:
   LDA $2D                  
   BNE CODE_E299
   
   LDA #$01                 
   STA $30                  
   STA $28

   LDA #$00                 
   STA $50

CODE_E299:
   RTS                      
   
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
   LDA $04B0
   BNE CODE_E2B1
   RTS

CODE_E2B1:
   CMP #$01                 
   BNE CODE_E329
   
   LDA #$40                 
   STA $14
   
   LDA #$03                 
   STA $15
   
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
   STA ($14),Y              
   INY                      
   CPY #$20                 
   BNE CODE_E2D1
   
   INX                      
   INX                      
   INX                      
   JSR CODE_CDB4
   
   DEC $33                  
   BNE CODE_E2CF
   
   LDA #$00				;\reset collected coins from bonus phase    
   STA Player1BonusCoins		;|Mario's
   STA Player2BonusCoins		;/Luigi's
   
   LDA #$40                 
   STA $04B3
   
   LDA #$01                 
   STA $04B2
   
   LDA #$0A                 
   STA $04BC                
   INC $04B0                
   RTS     
  
CODE_E329:
   LDA $04B2                
   BNE CODE_E36C
   
   LDA $04B1                
   BNE CODE_E34E
   
CODE_E333:
   LDA #$01                 
   STA $51
   
   LDA #$00                 
   STA $04B0                
   STA $FC                  
   STA $04B4
   
   LDA #$10                 
   STA $2D
   
   LDA #$06                 
   STA $3B
   
   LDA #$09                 
   STA $40                  
   RTS                      

CODE_E34E:
   STA $03                  
   CMP #$18                 
   BEQ CODE_E358                
   CMP #$13                 
   BNE CODE_E35C
  
CODE_E358:
   LDA #$04                 
   STA $FC

CODE_E35C:  
   LDA #$01                 
   SEC                      
   JSR CODE_D15A
   STA $04B1
   
   LDA #$09                 
   STA $04B2                
   BNE CODE_E374                
  
CODE_E36C:
   DEC $04B3                
   BNE CODE_E3AE
   
   DEC $04B2
  
CODE_E374:
   LDA #$06                 
   STA $04B3
   
   LDA #$14                 
   STA $0540
   
   LDA $04B1                
   LSR A                    
   LSR A                    
   LSR A                    
   LSR A                    
   STA $0541
   
   LDA $04B1                
   AND #$0F                 
   STA $0542
   
   LDA #$66                 
   STA $0543
   
   LDA $04B2                
   STA $0544
   
   LDA #$AE                 
   STA $00
   
   LDA #$20                 
   STA $01
   
   LDA #$40                 
   STA $02
   
   LDA #$05                 
   STA $03                  
   JSR CODE_CE2C
  
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
   
   INC Player1BonusCoins		;increase "bonus coins collected" counter for player 1
   BNE CODE_E403			;always branch

CODE_E400:  
   INC Player2BonusCoins		;increase "bonus coins collected" counter for player 2
  
CODE_E403:
   LDA #$E8                 
   STA $BC
   
   LDA #$F6                 
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
   JSR CODE_E1F7		;related with bonus end after either timer runs out or player(s) collect all coins
   LDA $04B4			;
   JSR CODE_CD9E		;execute pointers

DATA_E45C:
.dw CODE_E464			;bonus end init
.dw CODE_E48A			;give coins
.dw CODE_E49A			;wait for result
.dw CODE_E4AA			;bonus/no bonus

CODE_E464:
   JSR CODE_E132		;turn off rendering & wait for NMI to occur
   JSR CODE_CA20		;clear screen
   JSR CODE_CA3B		;write stuff 
   JSR CODE_CA2B		;clear OAM
   JSR CODE_D5BE		;write score bar 
   JSR CODE_D60F		;prepare OAM slots for lives
   JSR CODE_D5E6		;set Mario's lives Y-position
   JSR CODE_D5EC		;same for Luigi
   JSR CODE_E13D		;wait for NMI and enable rendering
   
   LDA #$00			;zero out RAM addresses for next state
   STA $04BA			;to be investigated what they're for
   STA $2B			;

   INC $04B4			;to the next state

CODE_E489:   
   RTS				;
   
CODE_E48A:
   LDA $2B                  
   BNE CODE_E489
   
   LDA $04BA                
   JSR CODE_CD9E
   
DATA_E494:
;.db $1A,$E5,$CE,$E5,$70,$E6

.dw CODE_E51A
.dw CODE_E5CE
.dw CODE_E670

CODE_E49A:
   LDA $2B                  
   BNE CODE_E489
   
   LDA $04BA                
   JSR CODE_CD9E
   
DATA_E4A4:
;.db $54,$E5,$46,$E6,$B8,$E6

.dw CODE_E554
.dw CODE_E646
.dw CODE_E6B8

CODE_E4AA:
   LDA $04B5                
   CLC                      
   ADC $04B6                
   LDX #$BF                 
   LDY #$E5                 
   CMP #$0A                 
   BNE CODE_E506
   
   LDX #$AD                 
   LDY #$E5                 
   LDA $41                  
   CMP #$07                 
   BCS CODE_E4CB
   
   LDX #$B6                 
   LDY #$E5                 
   LDA #$30                 
   BNE CODE_E4CD

CODE_E4CB:  
   LDA #$50

CODE_E4CD:  
   STA $1E                  
   STX $02                  
   STY $03
   
   LDA #$D0                 
   STA $00                  
   LDA #$22                 
   STA $01                  
   JSR CODE_CE2C
   
   LDA $1E                  
   STA $00
   
   LDA $4A                  
   BNE CODE_E4ED                
   LDA #$08                 
   STA $01                  
   JSR CODE_DE83
  
CODE_E4ED:
   LDA $4E                  
   BNE CODE_E4FC
   
   LDA $1E                  
   STA $00
   
   LDA #$09                 
   STA $01
   
   JSR CODE_DE83
   
CODE_E4FC:
   LDX #$A4                 
   LDY #$E5
   
   LDA $FD                  
   ORA #$04                 
   STA $FD

CODE_E506:  
   LDA #$C7                 
   STA $00
   
   LDA #$22                 
   STA $01
   STX $02                  
   STY $03
   
   JSR CODE_CE2C                
   LDA #$10                 
   JMP CODE_E1EC                
   
CODE_E51A:
   LDA $4A                  
   BEQ CODE_E522                
 
CODE_E51E:
   INC $04B4
   RTS
   
CODE_E522:
   LDA #$17                 
   STA $1E
   
   LDA #$27                 
   STA $00
   
   LDA #$21                 
   LDX #$68                 
   LDY #$E5                 
  
CODE_E530:
   STA $01                  
   STX $02                  
   STY $03
   JSR CODE_CE2C
   
   LDX $1E                  
   LDY #$17
   
CODE_E53D:
   LDA DATA_E574,X              
   STA $0200,X
   DEX                      
   DEY                      
   BPL CODE_E53D                
   INC $04BA
   
   LDA #$00                 
   STA $04BB
   
   LDA #$10                 
   STA $2B                  
   RTS                                      
   
CODE_E554:
  LDA $4E                  
  BNE CODE_E51E
  
  LDA #$2F                 
  STA $1E
  
  LDA #$07                 
  STA $00
  
  LDA #$22                 
  LDX #$6E
  
  LDY #$E5                 
  BNE CODE_E530                
  
DATA_E568:				;unused data?
.db $15,$16,$0A,$1B,$12,$18
.db $15,$15,$1E,$12,$10,$12
   
DATA_E574:
.db $40
.db $13,$40,$20,$40,$12,$40,$28,$48
.db $15,$40,$20,$48,$14,$40,$28,$50
.db $17,$40,$20,$50,$16,$40,$28,$78
.db $13,$41,$20,$78,$12,$41,$28,$80
.db $15,$41,$20,$80,$14,$41,$28,$88
.db $17,$41,$20,$88,$16,$41,$28,$18
.db $19,$0E,$1B,$0F,$0E,$0C,$1D,$67
.db $18,$05,$00,$00,$00,$19,$1D,$1C
.db $65,$18,$03,$00,$00,$00,$19,$1D
.db $1C,$65,$1E,$24,$24,$24,$24,$24
.db $17,$18,$24,$0B,$18,$17,$1E,$1C
.db $26

CODE_E5CE:
   LDA $04B5                
   BEQ CODE_E639
   CMP $04BB                
   BEQ CODE_E631
   
   LDA $04BB                
   ASL A                    
   ASL A                    
   ASL A                    
   TAX                      
   LDY #$41
   
   LDA $04B5                
   CMP #$06                 
   LDA $04BB
   BCC CODE_E5F6                
   LDY #$38                 
   CMP #$05                 
   BCC CODE_E5F6                
   LDY #$4A                 

CODE_E5F3:
   SEC                      
   SBC #$05

CODE_E5F6:				;related with coin sprites, for "test your skill" bonus?
   STY $1E				;

   ASL A                   		;
   ASL A                    		;
   STA $1F				;
   
   ASL A                  		;
   CLC                      		;
   ADC $1F                  		;
   ADC #$70                 		;
   STA $0233,X              		;
   STA $0237,X				;Tile's X position
   
   LDA #$02                 		;tile property (sprite palette 2)
   STA $0232,X              		;
   STA $0236,X 				;
   
   LDA #$A5				;coin's top tile		  
   STA $0231,X 				;
   
   LDA #$A6       			;          
   STA $0235,X				;bottom tile
   
   LDA $1E            			;      
   STA $0230,X             		;Tile's Y position
   CLC                     		;
   ADC #$08                 		;bottom tile 8 pixels lower
   STA $0234,X				;
   
   INC $04BB				;
   
   LDA #$0A                 		;
   STA $2B				;
   
   LDA #$20              		;   
   STA $FD                  		;
   RTS                      		;
   
CODE_E631:
   INC $04BA				;
   
   LDA #$10                		;
   STA $2B                 		;
   RTS                      		;
   
CODE_E639:
   LDA #$00                 
   STA $04BA
   
   INC $04B4
   
   LDA #$10                 
   STA $2B                  
   RTS                      

   
CODE_E646:
   LDA $04B6                
   BEQ CODE_E639                
   CMP $04BB                
   BEQ CODE_E631
   
   LDA $04BB                
   ASL A                    
   ASL A                    
   ASL A                    
   CLC                      
   ADC #$50                 
   TAX
   
   LDY #$79                 
   LDA $04B6                
   CMP #$06
   LDA $04BB
   BCC CODE_E5F6                
   LDY #$70                 
   CMP #$05                 
   BCC CODE_E5F6
   
   LDY #$82                 
   BCS CODE_E5F3

CODE_E670:
   LDA #$00                 
   STA $1F
   
   LDX #$37                 
   LDY #$21                 
   LDA $04B5
  
CODE_E67B:
   STA $1E                  
   STX $00                  
   STY $01
   
   LDA #$03                 
   STA $02
   
   LDA #$E7                 
   STA $03
   
   JSR CODE_CE2C
   
   LDA #$00                 
   STA $04                  
   STA $05                  
   STA $07
   
   LDY #$08                 
   STY $03
   
CODE_E698:
   CLC                      
   JSR CODE_D139
   BCC CODE_E6A0                
   INC $05
   
CODE_E6A0:
   DEC $1E                  
   BNE CODE_E698                
   STA $06
   
   LDA $1F                  
   JSR CODE_D0B4
   
   LDA #$20                 
   STA $2B
   
   LDA #$00                 
   STA $04BA
   
   INC $04B4                
   RTS
  
CODE_E6B8:
   LDA #$01                 
   STA $1F
   
   LDX #$17                 
   LDY #$22

   LDA $04B6
   BNE CODE_E67B   

DATA_E6C5:
.db $01,$01,$03,$00,$2C,$05,$A5,$02
.db $00,$00,$00,$00,$00,$00,$00,$F0
.db $00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$0F,$0F

DATA_E6E5:
.db $38,$24,$2C,$C8,$24,$2E,$18,$5A
.db $2D,$2C,$5A,$30,$D4,$5A,$30,$E8
.db $5A,$2D,$60,$8A,$2F,$A0,$8A,$2E
.db $28,$BA,$2D,$D8,$BA,$30,$15,$21
.db $24,$08,$00,$00
   
CODE_E709:
   LDA $04D0                
   BEQ CODE_E711                
   DEC $04D0
  
CODE_E711:
   LDA $04D2                
   BEQ CODE_E719                
   DEC $04D2
   
CODE_E719:
   INC $27                  
   LDA $27                  
   CMP #$3E                 
   BCC CODE_E73D
   
   LDA #$00                 
   STA $27
   
   LDA $04F3                
   BEQ CODE_E72D                
   DEC $04F3
  
CODE_E72D:
   LDA $04FC                
   BEQ CODE_E735                
   DEC $04FC
   
CODE_E735:
   LDA $04FF                
   BEQ CODE_E73D                
   DEC $04FF
  
CODE_E73D:
   RTS                      

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
   CMP #$80                 
   BCS CODE_E830
   
   LDY #$E8                 
   LDX #$02
   
CODE_E830:
   STY $0429                
   STX $0421
   
   LDA #$01                 
   STA $0430                
   JSR CODE_E96D
   
   LDX #$DB                 
   LDY #$EF

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
   LDX #$1B                 
   LDY #$F0
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
   LDA #$02                 
   STA $00
   
   LDX $9F                  
   LDA #$01                 
   STA $9D,X
   
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
   ORA #$00                 
   RTS
   
CODE_E96D:
   LDA $FC                  
   ORA #$08                 
   BNE CODE_E977                
   
CODE_E973:
   LDA $FC                  
   AND #$F7

CODE_E977:   
   STA $FC                  
   RTS

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
   
CODE_EA37:
   LDA $04FC                
   BNE CODE_EA36
   
   LDA $04BF                
   BNE CODE_EA4C                
   JSR CODE_EEAD                
   JSR CODE_E9AC
   
   LDA #$01                 
   STA $04BF
  
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
   LDX #$9D                 
   LDY #$EF
  
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
   
   LDA DATA_F575,X              
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
   LDX #$06                 
   LDY #$F0                 
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
   
   LDA #$1E                 
   STA $04FF                
   RTS                      

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

   
CODE_EC67:
   LDA #$00      
   STA $9F   
   STY $1F
   
   LDY #$00

CODE_EC6F:   
   LDA $84,Y              
   BEQ CODE_EC91                
   TXA                      
   CMP $85,Y              
   BNE CODE_EC91
   
   LDA $1F                  
   SEC                      
   SBC #$10                 
   CMP $86,Y              
   BCS CODE_EC91
   
   LDA $1F                  
   CLC                      
   ADC #$10                 
   CMP $86,Y              
   BCC CODE_EC91                
   LDA #$00                 
   RTS

CODE_EC91:  
   INC $9F                  
   LDY #$05
   
   LDA $9F                  
   CMP #$02                 
   BNE CODE_EC6F
   
   LDA #$00                 
   STA $9F
   
   LDA #$FF  
   RTS

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

CODE_ED6C:  
   DEC $C1                  
   BEQ CODE_EDAC
   
   LDA $C1                  
   LDY #$6A                 
   CMP #$20                 
   BEQ CODE_ED9C                
   CMP #$40                 
   BNE CODE_EDA9
   
   LDA $B8                  
   CLC                      
   ADC #$07                 
   STA $02B0                
   STA $02B4
   
   LDA #$03                 
   STA $02B2                
   STA $02B6
   
   LDA $B9                  
   STA $02B7                
   SEC                      
   SBC #$08                 
   STA $02B3
   
   LDY #$68

CODE_ED9C:  
   STY $02B1
   
   INY                      
   STY $02B5

   LDA $FE                  
   ORA #$04                 
   STA $FE

CODE_EDA9:  
   JMP CODE_C6BF
  
CODE_EDAC:
   LDA $21                  
   BNE CODE_EDE7
   
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
   
   LDA $04CD                
   AND $04CE                
   AND $04CF                
   BNE CODE_EDDD
   
   JSR CODE_ECAF                
   JMP CODE_EDA9
  
CODE_EDDD:
   LDA #$00
   STA $04C0                
   STA $B0
   
   JMP CODE_C75A
  
CODE_EDE7:
   INC $C1                  
   BNE CODE_EDA9

   
CODE_EDEB:
   LDA $04C5                
   BNE CODE_EDF1                
   RTS

CODE_EDF1:
   LDA $04CA                
   BEQ CODE_EE1F
   
   DEC $04CA
   
   LDA $02B3                
   BEQ CODE_EE1E                
   CMP #$40                 
   BEQ CODE_EE1E                
   CMP #$A0                 
   BEQ CODE_EE1E
   
   DEC $02B3                
   DEC $02B3
   
   DEC $02B7                
   DEC $02B7
   
   INC $02BB                
   INC $02BB
   
   INC $02BF                
   INC $02BF

CODE_EE1E:   
   RTS

CODE_EE1F:   
   LDX $04C6                
   LDA DATA_EE53,X
   BEQ CODE_EE40 
   STA $04C9
   
   INX                      
   LDA DATA_EE53,X              
   STA $04C8
   
   LDA #$01                 
   STA $04C7
   
   INX                      
   STX $04C6

   LDA #$08                 
   STA $04CA                
   RTS
   
CODE_EE40:
   LDA #$00                 
   STA $04C5                
   STA $04C7
   
   LDA #$F4                 
   LDX #$0F

CODE_EE4C:   
   STA $02B0,X              
   DEX                      
   BPL CODE_EE4C                
   RTS                      

   
DATA_EE53:
.db $F7,$63,$F7,$6D,$F7,$7B,$F7,$8B
.db $00,$F7,$9B,$F7,$A4,$F7,$B3,$00
.db $F7,$C2,$F7,$CB,$F7,$DA,$00

CODE_EE6A:
   LDA $04C7
   BEQ CODE_EE81
   
   LDA $04C8
   STA $00
   
   LDA $04C9
   STA $01

   JSR CODE_CE00

   LDA #$00
   STA $04C7

CODE_EE81:
   RTS
   
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
   PLA                      
   PLA

CODE_EEBB:  
   RTS

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
   
CODE_EEE3:
   STA $1E                  
   TXA                      
   SEC
   LDX $04D5
   BEQ CODE_EEEE                
   SBC #$08
  
CODE_EEEE:
   SBC #$18                 
   STA $02E8,X              
   STA $02EC,X              
   TYA                      
   SEC                      
   SBC #$08                 
   STA $02EB,X              
   TYA                      
   STA $02EF,X

   LDY $1E                  
   LDA DATA_EF97,Y              
   STA $02E9,X
   
   LDA #$45                 
   STA $02ED,X              
   LDY #$03                 
   LDA $11                  
   BEQ CODE_EF16                
   LDY #$02
  
CODE_EF16:
   TYA                      
   STA $02EA,X              
   STA $02EE,X

   LDX #$00                 
   LDY #$08                 
   LDA $04D5                
   BEQ CODE_EF29                
   INX                      
   LDY #$00
   
CODE_EF29:
   LDA #$40                 
   STA $04D6,X              
   STY $04D5                
   RTS
   
CODE_EF32:
   LDX #$00                 
   LDY #$00

CODE_EF36:   
   LDA $04D6,X
   BEQ CODE_EF48
   
   DEC $04D6,X              
   BNE CODE_EF48
   
   LDA #$F4                 
   STA $02E8,Y              
   STA $02EC,Y
   
CODE_EF48:
   LDY #$08                 
   INX                      
   CPX #$02                 
   BNE CODE_EF36                
   RTS                      


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
   
DATA_EF97:
.db $40,$42,$43,$44,$3E

DATA_EF9C:
.db $3F,$9C,$00,$9D,$00,$9F,$00,$00
.db $9D,$00,$9B,$00,$00,$92,$00,$00
.db $93,$00,$00,$94,$00,$00,$95,$00
.db $92,$00,$93,$00,$94,$00,$FF

DATA_EFBB:
.db $01,$01,$03,$01,$3D,$07,$92,$02
.db $F4,$00,$04,$00,$00,$00,$00,$B0
.db $00,$01,$00,$00,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$04
.db $9C,$00,$9D,$00,$9F,$00,$9C,$00
.db $9D,$00,$9F,$00,$9C,$00,$9D,$00
.db $9F,$00,$9C,$00,$9D,$00,$9F,$00
.db $9C,$00,$9D,$00,$9F,$00,$9C,$00
.db $9D,$00,$9F,$00,$9C,$00,$9D,$00
.db $9B,$00,$FF,$9B,$00,$9C,$00,$9D
.db $00,$00,$9E,$00,$9F,$00,$9C,$00
.db $9D,$00,$00,$9E,$00,$9F,$00,$FF
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
.db $CC,$9C,$6C,$3C,$20,$83,$02,$76
.db $7A,$20,$A3,$02,$77,$79,$20,$9A
.db $02,$7C,$7E,$20,$BA,$02,$7D,$7F
.db $21,$63,$02,$80,$82,$21,$83,$02
.db $81,$83,$21,$7A,$02,$84,$86,$21
.db $9A,$02,$85,$87,$20,$85,$4A,$7B
.db $20,$90,$4A,$7B,$21,$85,$4A,$89
.db $21,$90,$4A,$89,$20,$C3,$19,$78
.db $24,$24,$68,$69,$69,$6B,$69,$68
.db $69,$68,$6B,$69,$24,$68,$69,$68
.db $69,$6B,$69,$6B,$69,$24,$24,$88
.db $20,$E6,$13,$68,$6A,$6A,$6E,$6A
.db $68,$6A,$68,$6E,$6A,$24,$68,$6A
.db $68,$6A,$6E,$6A,$6E,$71,$21,$06
.db $13,$68,$6A,$6A,$68,$6C,$68,$6D
.db $68,$6E,$6A,$24,$68,$6D,$68,$6D
.db $6E,$6A,$6F,$69,$21,$26,$13,$68
.db $6A,$6A,$6E,$6A,$68,$6A,$68,$6E
.db $6A,$24,$68,$6A,$68,$6A,$6E,$6A
.db $72,$6A,$21,$43,$19,$78,$24,$24
.db $68,$6A,$6A,$6E,$6A,$68,$6A,$68
.db $6F,$70,$24,$68,$70,$68,$6A,$6F
.db $70,$6F,$70,$73,$24,$88,$22,$09
.db $0F,$01,$24,$19,$15,$0A,$22,$0E
.db $1B,$24,$10,$0A,$16,$0E,$24,$0A
.db $22,$49,$0F,$01,$24,$19,$15,$0A
.db $22,$0E,$1B,$24,$10,$0A,$16,$0E
.db $24,$0B,$22,$89,$0F,$02,$24,$19
.db $15,$0A,$22,$0E,$1B,$24,$10,$0A
.db $16,$0E,$24,$0A,$22,$C9,$0F,$02
.db $24,$19,$15,$0A,$22,$0E,$1B,$24
.db $10,$0A,$16,$0E,$24,$0B,$23,$05
.db $16,$25,$01,$09,$08,$03,$24,$17
.db $12,$17,$1D,$0E,$17,$0D,$18,$24
.db $0C,$18,$28,$15,$1D,$0D,$26,$23
.db $4B,$0D,$16,$0A,$0D,$0E,$24,$12
.db $17,$24,$13,$0A,$19,$0A,$17,$23
.db $C8,$0F,$AA,$2A,$0A,$0A,$0A,$0A
.db $8A,$00,$FF,$30,$00,$00,$00,$00
.db $C0,$23,$D8,$48,$FF,$23,$E0,$50
.db $55,$23,$F0,$48,$AA,$00

DATA_F1E7:
.db $21,$20,$4E,$21,$32,$4E,$21,$E8
.db $50,$22,$00,$44,$22,$1C,$44,$22
.db $A0,$4C,$22,$B4,$4C,$00,$23,$60
.db $60,$23,$80,$60,$3F,$00,$20,$0F
.db $30,$2C,$12,$0F,$30,$29,$09,$0F
.db $30,$27,$18,$0F,$30,$26,$06,$0F
.db $16,$37,$12,$0F,$30,$27,$19,$0F
.db $30,$27,$16,$0F,$2C,$12,$25,$00
.db $3F,$00,$14,$0F,$16,$16,$16,$0F
.db $27,$27,$27,$0F,$30,$2C,$12,$0F
.db $30,$29,$19,$0F,$35,$35,$35,$00

DATA_F23F:
.db $23,$C0,$10,$00,$00,$C0,$30,$00
.db $50,$00,$00,$55,$55,$00,$00,$00
.db $00,$55,$55,$23,$F0,$10,$F5,$FF
.db $FF,$FF,$FF,$FF,$FF,$F5,$FF,$FF
.db $FF,$FF,$FF,$FF,$FF,$FF,$00,$23
.db $D0,$58,$00,$23,$E8,$08,$50,$00
.db $00,$00,$00,$00,$00,$50,$00

DATA_F276:
.db $23,$D0,$58,$AA,$23,$E8,$08,$5A
.db $AA,$AA,$00,$00,$AA,$AA,$5A,$00
.db $23,$D0,$58,$FF,$23,$E8,$08,$5F
.db $FF,$FF,$00,$00,$FF,$FF,$5F,$00
.db $A6,$F2,$B9,$F2,$C6,$F2

.db $C6,$F2,$D0,$F2,$DA,$F2,$E1,$F2
.db $E8,$F2,$00,$EF,$F8,$00,$EF,$00
.db $00,$F7,$F8,$00,$F7,$00,$00,$00
.db $F8,$00,$00,$00,$AA,$00,$F7,$F8
.db $00,$F7,$00,$00,$00,$F8,$00,$00
.db $00,$AA,$80,$F7,$F8,$01,$F7,$00
.db $00,$00,$FC,$AA,$00,$F7,$FC,$80
.db $00,$F8,$01,$00,$00,$AA,$00,$F7
.db $FC,$00,$00,$FC,$AA,$00,$F7,$F8
.db $00,$00,$FC,$AA,$00,$FC,$FC,$AA
   
DATA_F2EC:
.db $01,$00,$03,$00,$00,$00,$12,$40
.db $D0,$44,$10,$00,$00,$00,$00,$01
.db $00,$00,$00,$00,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$04
.db $01,$00,$03,$00,$00,$00,$12,$01
.db $D0,$C4,$28,$00,$00,$00,$00,$02
.db $00,$00,$00,$00,$00,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$04
.db $00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$01,$00
.db $01,$00,$01,$01,$00,$01,$01,$02
.db $01,$02,$02,$02,$02,$02,$02,$03
.db $03,$03,$03,$AA,$FC,$FC,$FC,$FC
.db $FC,$FC,$FC,$FD,$FD,$FE,$FE,$FE
.db $FE,$FE,$FE,$FF,$FE,$FF,$FF,$FF
.db $00,$FF,$FF,$00,$FF,$00,$00,$00
.db $AA,$FE,$FE,$FE,$FF,$FF,$FF,$FF
.db $FF,$00,$FF,$00,$FF,$00,$AA,$00
.db $01,$00,$01,$00,$01,$01,$01,$02
.db $01,$01,$02,$03,$03,$04,$04,$CC
.db $04,$CC,$CC,$CC,$04,$CC,$AA,$01
.db $03,$00,$01,$02,$00,$01,$01,$00
.db $AA,$01,$03,$00,$01,$02,$00,$01
.db $01,$FF,$AA

.db $01,$02,$00,$01,$01,$FF,$01,$01
.db $FF,$01,$01,$00,$01,$01,$00,$01
.db $01,$01,$AA,$D2,$F3,$D9,$F3,$E4
.db $F3,$ED,$F3,$FA,$F3,$03,$F4,$0E
.db $F4,$19,$F4,$24,$F4,$31,$F4,$3E
.db $F4,$49,$F4,$05,$00,$12,$00,$1F
.db $00,$AA,$05,$00,$12,$00,$1F,$00
.db $19,$00,$1F,$00,$AA,$05,$01,$0C
.db $01,$2B,$01,$0C,$01,$AA,$03,$01
.db $0C,$01,$31,$00,$06,$00,$49,$01
.db $07,$01,$AA,$0C,$02,$0C,$02,$31
.db $02,$0C,$02,$AA,$0C,$02,$0C,$02
.db $31,$01,$06,$01,$31,$02,$AA,$03
.db $00,$0C,$00,$31,$02,$06,$00,$31
.db $00,$AA,$03,$01,$0C,$01,$31,$02
.db $06,$01,$31,$01,$AA,$0C,$02,$0C
.db $01,$31,$01,$06,$01,$31,$02,$12
.db $01,$AA,$03,$01,$0C,$01,$31,$01
.db $06,$02,$31,$02,$12,$01,$AA,$03
.db $00,$0C,$00,$31,$01,$06,$00,$06
.db $00,$AA,$01,$00,$05,$00,$40,$00
.db $FF,$00,$AA                  
   
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

 
DATA_F4B2:
.db $06,$0C,$00,$0C,$FF,$00,$26,$2C
.db $FF,$06,$52,$54,$52,$56,$FF,$0A
.db $6C,$6C,$6F,$6F,$6C,$6C,$72,$72
.db $FF,$10,$D0,$D0,$D3,$D3,$D0,$D0
.db $D6,$D6,$FF,$1A,$7D,$7D,$80,$80
.db $83,$83,$FF,$24,$A1,$A3,$A5,$A7
.db $A9,$FF,$2C,$8C,$8E,$90,$FF,$33
.db $B4,$B8,$BC,$FF,$38


DATA_F4EF:
.db $92,$93,$94,$95,$FF,$3D,$20,$82
.db $04,$52,$51,$3C,$50,$20,$A0,$06
.db $41,$57,$56,$55,$47,$54,$20,$C0
.db $06,$46,$5C,$5B,$5A,$4C,$59,$20
.db $E0,$04,$49,$61,$49,$5F,$20,$9A
.db $04,$39,$3C,$3A,$3B,$20,$BA,$06
.db $3D,$47,$3E,$3F,$40,$41,$20,$DA
.db $06,$42,$4C,$43,$44,$45,$46,$20
.db $FC,$04,$48,$49,$4A,$4B,$22,$E0
.db $04,$41,$41,$41,$57,$23,$00,$04
.db $46,$46,$46,$5C,$23,$20,$04,$4B
.db $4B,$4B,$61,$22,$FC,$04,$40,$41
.db $41,$41,$23,$1C,$04,$45,$46,$46
.db $46,$23,$3C,$04,$4A,$4B,$4B,$4B
.db $00,$22,$24,$24,$24,$24,$22,$FE
.db $FF,$90,$91,$22,$FC,$FD,$8E,$8F
.db $22,$FA,$FB,$8C,$8D  

DATA_F574:
.db $2D

DATA_F575:
.db $21,$F7,$21,$03,$22,$AB,$22,$32
.db $21,$E8,$21,$1C,$22,$B4,$22,$AA
.db $F5,$CA,$F5,$58,$06,$52,$06,$AA
.db $F5,$EA,$F5,$D0,$03,$6C,$03,$D9
.db $04,$BD,$F5,$08,$F6,$E0,$04,$7D
.db $03,$0F,$F7,$00,$00    
.db $E8,$04,$E8,$F6,$00,$00
.db $46,$07,$FD,$FE,$FE,$FE,$FE,$FF
.db $FF,$FF,$FE,$00,$FF,$00,$FE,$00
.db $FF,$00,$00,$00,$99,$FE,$FE,$FE
.db $FF,$FF,$FF,$00,$FF,$00,$FF,$00
.db $00,$99,$58,$40,$5A,$40,$58,$40
.db $5A,$30,$58,$30,$5A,$20,$58,$20
.db $5A,$20,$58,$20,$5A,$18,$58,$10
.db $00,$5A,$10,$58,$10,$5A,$08,$58
.db $08,$FF,$D9,$40,$DC,$40,$D9,$40
.db $DC,$30,$D9,$30,$DC,$20,$D9,$20
.db $DC,$20,$D9,$18,$DC,$10,$00,$D9
.db $10,$DC,$08,$D9,$08,$DC,$08,$FF
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
.db $00,$03,$FF,$FB,$FB,$FD,$FE,$FE
.db $FF,$FF,$FF,$FF,$AA,$F7,$F8,$FA
.db $FB,$FC,$FD,$FE,$FE,$FE,$FE,$FE
.db $FF,$FF,$00,$FF,$00,$00,$FF,$AA
.db $20,$63,$01,$2A,$20,$6B,$03,$2B
.db $2C,$2D,$00,$20,$75,$02,$29,$2A
.db $00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DATA_F671 - Life display OAM data
;Format:
;Byte 1 - Y-position
;Byte 2 - Sprite tile to display
;Byte 3 - Tile property
;Byte 4 - X-position
;Do note however that Y-position value is overwritten afterwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DATA_F671:
.db $F4,$DF,$00,$40,$F4,$DF,$00,$4C
.db $F4,$DF,$00,$58,$F4,$DF,$01,$A8
.db $F4,$DF,$01,$B4,$F4,$DF,$01,$C0

;Title screen cursor OAM data, same format as above, Y-position is also overwritten.
.db $F4,$EE,$00,$38

DATA_F68D:
.db $20,$6E,$06,$00,$20,$64,$06,$00
.db $20,$77,$06,$00      

DATA_F699:
.db $10,$CD,$03,$6C,$10,$CD,$43,$73
.db $10,$CD,$03,$84,$10,$CD,$43,$8B
.db $FD,$FE,$FE,$FE,$FF,$FF,$00,$FF
.db $00,$FF,$00,$FF,$00,$00,$00,$00
.db $00,$00,$01,$00,$01,$00,$01,$00
.db $01,$01,$02,$02,$02,$03,$AA

DATA_F6C8:
.db $01,$00,$02,$00,$2C,$05,$A1,$22
.db $00,$00,$00,$00,$4C,$F6,$00,$40
.db $00,$01,$00,$0A,$02,$01,$00,$00
.db $00,$00,$00,$00,$00,$00,$04,$03
.db $FE,$FE,$FE,$FF,$DD,$47,$FF,$FF
.db $FF,$00,$DD,$48,$FF,$FF,$00,$FF
.db $CC,$01,$DD,$49,$00,$00,$00,$00
.db $00,$00,$CC,$05,$DD,$4D,$00,$00
.db $00,$00,$00,$00,$00,$00,$EE,$FE
.db $FE,$FE,$FF,$DD,$EB,$FF,$FF,$FF
.db $00,$DD,$F0,$00,$00,$00,$00,$00
.db $00,$EE

DATA_F722:
.db $22,$4C,$08,$19,$11,$0A,$1C,$0E
.db $24,$24,$24,$23,$41,$04,$19,$2E
.db $24,$24,$00,$21,$89,$0F,$1D,$0E
.db $1C,$1D,$24,$22,$18,$1E,$1B,$24
.db $1C,$14,$12,$15,$15,$20,$8D,$06
.db $30,$31,$31,$31,$31,$32,$20,$AD
.db $06,$33,$02,$00,$66,$00,$34,$20
.db $CD,$06,$35,$36,$36,$36,$36,$37
.db $00,$21,$EE,$44,$97,$23,$DB,$02
.db $20,$80,$00,$21,$EC,$42,$97,$21
.db $F2,$42,$97,$23,$DB,$02,$00,$00
.db $00,$21,$EA,$42,$97,$21,$F4,$42
.db $97,$23,$DA,$04,$20,$00,$00,$80
.db $00,$21,$E8,$42,$97,$21,$F6,$42
.db $97,$23,$DA,$04,$00,$00,$00,$00
.db $00,$22,$A4,$44,$97,$23,$E9,$01
.db $50,$00,$22,$A2,$42,$97,$22,$A8
.db $42,$97,$23,$E8,$03,$52,$00,$08
.db $00,$22,$A0,$42,$97,$22,$AA,$42
.db $97,$23,$E8,$03,$50,$00,$00,$00
.db $22,$B8,$44,$97,$23,$EE,$01,$50
.db $00,$22,$B6,$42,$97,$22,$BC,$42
.db $97,$23,$ED,$03,$02,$00,$58,$00
.db $22,$B4,$42,$97,$22,$BE,$42,$97
.db $23,$ED,$03,$00,$00,$50,$00,$00
.db $03,$FF,$03,$00,$03,$00,$03,$FF
.db $03,$01,$03,$01,$03,$00,$03,$01
.db $03,$02,$03,$02,$03,$02,$02,$02
.db $02,$03,$02,$03,$02,$03,$02,$03
.db $01,$03,$01,$03,$01,$03,$01,$04
.db $00,$04,$01,$04,$00,$04,$01,$04
.db $01,$AA              

DATA_F81C:
.db $00,$01,$02,$02,$01,$00,$AA

DATA_F823:
.db $00,$5C,$01,$50,$00,$10,$02,$14
.db $82,$40,$00,$10,$01,$28,$00,$50
.db $80,$40,$02,$28,$00,$14,$01,$10
.db $81,$40,$00,$48,$01,$30,$81,$30
.db $01,$10,$00,$10,$02,$45,$82,$40
.db $02,$20,$00,$08,$01,$40,$81,$40
.db $AA                  

DATA_F854:
.db $00,$30,$02,$50,$00,$10,$01,$18
.db $81,$30,$81,$18,$00,$10,$02,$24
.db $82,$60,$82,$40,$00,$08,$01,$24
.db $81,$40,$00,$18,$02,$10,$82,$40
.db $00,$40,$01,$60,$00,$50,$01,$FF    

DATA_F87C:            				;a bunch of FFs. It's possible there was some coding/routine before that they've removed. 
.db $FF,$FF,$FF         			;or it's just some random freespace, IDK
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

CODE_F8A7:
   NOP						;\and a bunch of NOPs that are here just because...?
   NOP						;|
   NOP						;|
   NOP						;|
   NOP						;|
   NOP						;|
   NOP						;/
   LDA #$C0					;\what this does?
   STA $4017					;/it enables bits that do nothing. (investigate)
   JSR CODE_FA91				;
   
   LDA #$00					;
   STA $FF					;
   STA $FE					;
   STA $FD					;
   STA $4011					;
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
   LDX #$00
   
CODE_F8DA:
   TAY
   LDA DATA_F900+1,y
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
   LDX #$04                 
   BNE CODE_F8DA

CODE_F8F3:   
   TXA                      
   AND #$3E                 
   LDX #$08                 
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
   LDA $FA					;seems to be related with sound effect/music playing (sound engine)
   BNE CODE_FAD1				;I hope it's easier than it looks
   LDY $FF					;
   LDA $F0					;If value in $F0
   LSR A					;/2
   BCS CODE_FA8B				;if it caused bits to shift onto carry flag, branch
   LSR $FF					;Divide FF by 2
   BCS CODE_FA88				;did it caused set carry flag? branch if some
   LSR A					;I hope you get the idea
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
   JMP CODE_FCC9				;if there's no sound to play... more checkes
   
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
   AND $0500                
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
   LDA $0500
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
   BNE CODE_FD27				;
   
   LDA $FC                  
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
   LDA $0500                
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
   LDA $FD                  
   BNE CODE_FD33                
   LDA $06A2                
   BNE CODE_FD78                
   JMP CODE_FBEC
 
CODE_FD33:
   LDY #$07

CODE_FD35:   
   ASL A                    
   BCS CODE_FD3B                
   DEY                      
   BNE CODE_FD35
  
CODE_FD3B:
   INC $06A2                
   STY $06F2                
   LDA DATA_FE64,Y              
   TAY
   
   LDA DATA_FE64,Y              
   STA $068D
   
   LDA DATA_FE64+1,Y              
   STA $F7
   
   LDA DATA_FE64+2,Y              
   STA $F8                  
   LDA DATA_FE64+3,Y
   STA $F9
   
   LDA DATA_FE64+4,Y              
   STA $FA
   
   LDA DATA_FE64+5,Y
   STA $0686
   
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
   
   LDA #$00                 
   STA $FA                  
   STA $F9                  
   STA $F0                  
   STA $FB                  
   STA $06A2                
   STA $06C0                
   STA $4008
   
   LDA #$10                 
   STA $4004                
   RTS
  
CODE_FDDA:
   JSR CODE_F981                
   STA $0695                
   TXA                      
   AND #$3E                 
   JSR CODE_F8EF                
   BEQ CODE_FE02
   
   LDX #$9F                 
   LDA $06F2                
   BEQ CODE_FDFA
   
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
   LDY $06F2                
   BNE CODE_FE27
   
   LDA #$FF

CODE_FE27:   
   STA $4008                
   JSR CODE_F8F3
  
CODE_FE2D:
   LDA $06F2
   CMP #$07
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
.db $08,$0D,$12,$17,$1C,$21,$26,$2B
.db $0F,$95,$FE,$30,$00,$00,$D1,$FE
.db $00,$08,$00,$E6,$FE,$0A,$00,$0F
.db $F3,$FE,$00,$00,$07,$FC,$FE,$03
.db $00,$00,$0B,$FF,$00,$00,$07,$0D
.db $FF,$18,$00,$16,$44,$FF,$1F,$38
.db $7E,$5D,$78,$5D,$78,$5C,$78,$5C
.db $62,$E6,$65,$5E,$65,$5E,$64,$5E
.db $40,$5E,$F8,$00      
   
DATA_FEA8:
.db $85,$06,$81,$26,$85,$06,$81,$26
.db $06,$26,$06,$0E,$83,$12,$85,$10
.db $81,$0A,$85,$10,$81,$0A,$10,$0A
.db $2E,$0A,$83,$26,$00

DATA_FEC5:
.db $5D,$78,$5D,$78,$1D,$5F,$40,$5F
.db $40,$9E,$80,$F8,$6E,$6A,$A6,$A6
.db $A6,$AE,$07,$00,$82,$46,$38,$32
.db $4A,$48,$81,$40,$42,$44,$48,$84
.db $30,$66,$6E,$4A,$50,$52,$50,$4A
.db $6E,$27,$00,$E6,$DE,$39,$04,$12
.db $04,$12,$04,$12,$04,$D2,$00,$83
.db $83,$00,$46,$46,$4E,$52,$42,$4E
.db $12,$14,$16,$18,$1A,$05,$E6,$00
.db $2E,$46,$02,$AE,$6A,$67,$28,$6A
.db $02,$A6,$64,$63,$9E,$A4,$6A,$47
.db $08,$4B,$02,$0C,$4F,$02,$07,$00
.db $86,$A6,$A2,$9C,$AA,$A2,$9C,$BC
.db $9E,$BC,$B6,$B2,$26,$24,$26,$24
.db $A6,$22,$1E,$22,$1E,$A2,$1C,$00
.db $1C,$00,$1C,$00,$1C,$00,$1D,$47
.db $EA,$42,$66,$AA,$AC,$6A,$A6,$47
.db $EA,$42,$66,$AA,$AC,$6A,$A6,$6A
.db $AC,$86,$6C,$AA,$6C,$86,$8A,$46
.db $4A,$4E,$D0,$D2,$11,$00,$77,$76
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

   .dw NMI
   .dw RESET
   .dw RESET
