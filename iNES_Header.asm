MAPPER = 0					;which mapper it's using (NROM)
MIRRORING = 1					;vertical mirroring (supposedly)

.if Version = PAL
  REGION = 1					;obviously the TV system is PAL for PAL version
.else
  REGION = 0
.endif

   .byte "NES", $1A

.if Version = Gamecube
   .byte $02					;16KB PRG space (for code) = 2
.else
   .byte $01					;16KB PRG space (for code) = 1
.endif

   .byte $01					;8KB CHR space (for GFX) = 1
   .byte MAPPER<<4&$F0|MIRRORING		;Mapper = 0 and Mirroring is (supposedly) vertical
   .byte MAPPER&$F0				;Mapper is still NROM, and the system is NES (not PlayChoice-10)

   .byte $00					;PRG RAM-Size (useless)
   .byte REGION					;the only thing that matters - TV System (NTSC or PAL)
   .byte $00,$00,$00,$00,$00,$00		;the rest don't matter for this game