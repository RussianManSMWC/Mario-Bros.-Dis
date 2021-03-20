   .db "NES", $1A

   .db $01					;16KB PRG space (for code) = 1
   .db $01					;8KB CHR space (for GFX) = 1
   .db $01					;It's supposed to mirror vertically, though sometimes PPU viewer shows tilemap being mirrored horizontally in my emulator. But who cares? It doesn't affect the game at all.
   .db $00					;Mapper 0 - NROM

   .db $00,$00,$00,$00				;bytes that don't do anything
   .db $00,$00,$00,$00				;

   .org $C000					;starting point = $C000