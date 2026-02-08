;insert useful macros here

;Word - the 16-bit value we store, Addr - 16-bit address we store the word to. This can be used to set up pointers or VRAM locations to draw to in RAM.
.macro Macro_SetWord Word, Addr
  LDA #<Word
  STA Addr

  LDA #>Word
  STA Addr+1
.endmacro

;used to set up a pointer with X and Y. X - low byte, Y - high byte
.macro Macro_LoadWordXY Word
  LDX #<Word
  LDY #>Word
.endmacro

.macro Macro_StoreWordXY Addr
  STX Addr
  STY Addr+1
.endmacro

;used to set up a pointer with A and Y. A - low byte, Y - high byte
.macro Macro_LoadWordAY Word
  LDA #<Word
  LDY #>Word
.endmacro

.macro Macro_StoreWordAY Addr
  STA Addr
  STY Addr+1
.endmacro

;used to set up a pointer with A and X. A - low byte, X - high byte
.macro Macro_LoadWordAX Word
  LDA #<Word
  LDX #>Word
.endmacro

.macro Macro_StoreWordAX Addr
  STA Addr
  STX Addr+1
.endmacro

.macro Macro_MoveWord Addr, Addr2
  LDA Addr
  STA Addr2

  LDA Addr+1
  STA Addr2+1
.endmacro