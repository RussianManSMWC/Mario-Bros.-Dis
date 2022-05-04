   .byte "NES", $1A

   .byte $01					;16KB PRG space (for code) = 1
   .byte $01					;8KB CHR space (for GFX) = 1
   .byte $01					;It's supposed to mirror vertically, though sometimes PPU viewer shows tilemap being mirrored horizontally in my emulator. But who cares? It doesn't affect the game at all.
   .byte $00					;Mapper 0 - NROM

   .byte $00,$00,$00,$00			;bytes that don't do anything
   .byte $00,$00,$00,$00			;