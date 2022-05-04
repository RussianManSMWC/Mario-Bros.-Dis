;converts standart utf-8 charset into the one used by this game

;numbers 0-9
.CHARMAP $30,$00
.CHARMAP $31,$01
.CHARMAP $32,$02
.CHARMAP $33,$03
.CHARMAP $34,$04
.CHARMAP $35,$05
.CHARMAP $36,$06
.CHARMAP $37,$07
.CHARMAP $38,$08
.CHARMAP $39,$09

;letters (upper case)
.CHARMAP $41,$0A
.CHARMAP $42,$0B
.CHARMAP $43,$0C
.CHARMAP $44,$0D
.CHARMAP $45,$0E
.CHARMAP $46,$0F
.CHARMAP $47,$10
.CHARMAP $48,$11
.CHARMAP $49,$12
.CHARMAP $4A,$13
.CHARMAP $4B,$14
.CHARMAP $4C,$15
.CHARMAP $4D,$16
.CHARMAP $4E,$17
.CHARMAP $4F,$18
.CHARMAP $50,$19
.CHARMAP $51,$1A
.CHARMAP $52,$1B
.CHARMAP $53,$1C
.CHARMAP $54,$1D
.CHARMAP $55,$1E
.CHARMAP $56,$1F
.CHARMAP $57,$20
.CHARMAP $58,$21
.CHARMAP $59,$22
.CHARMAP $5A,$23

;there are no lower case letters

;empty space
.CHARMAP $20,$24

;dot
.CHARMAP $2E,$26

;comma
.CHARMAP $2C,$27

;equals sign
.CHARMAP $3D,$2E

;question mark
.CHARMAP $3F,$2F

;apostrophe
.CHARMAP $27,$65

;some non-standart character tiles
CopyrightSymbol = $25
DecimalSeparator = $66				;like a dot but in the middle, used for bonus timer
TwoExclamationMarks = $67			;there isn't a singular exclamation mark character, only two together
DotAndComma = $28				;not semicolon