# Mario-Bros.-Dis
This is a byte-to-byte accurate disassembly of Mario Bros. for NES and its different versions - NTSC (Japan/USA ("World")), PAL (Europe) and Gamecube.

I didn't included graphics data for it, you'll have to get it yourself (you can use included python script under "misc" folder to rip graphics from the ROM image).

Assembles with "CC65" compiler/assembler (there's also asm6 version if you want, though it's outdated).

If you want to compile a Gamecube version, use LinkerConfiguration_GAMECUBE.cfg specifically (I haven't figured out how to disable specific segments without borking the game).

TO DO: Disassemble "Classic Serie" version (may need to create a separate repository).
