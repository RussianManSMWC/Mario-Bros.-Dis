;I ❤ ENUMS!! Oh wait, wrong game. Uh... I think they are likeable.

;not gameplay game modes
.enum
  NonGameplayMode_InitTitleScreen
  NonGameplayMode_TitleScreenMain
  NonGameplayMode_InitDemoGameplay
  NonGameplayMode_LoadDemoPhaseProps
  NonGameplayMode_LoadDemoGame
  NonGameplayMode_InitDemoGame
  NonGameplayMode_DemoGameMain
  NonGameplayMode_EndDemoGame
.endenum

;gameplay game modes
.enum
  GameplayMode_InitGameplay
  GameplayMode_LoadPhaseProps
  GameplayMode_LoadGame
  GameplayMode_InitGame
  GameplayMode_GameMain
  GameplayMode_GamePaused
  GameplayMode_BonusCoinCount
  GameplayMode_Unknown
  GameplayMode_PhaseStart
  GameplayMode_PhaseEnd
  GameplayMode_GameUnpause
  GameplayMode_GameOver
.endenum

;entity draw modes (CurrentEntity_DrawMode)
.enum
  Entity_Draw_16x24                                         ;used by mario and luigi
  Entity_Draw_16x16                                         ;used by coin effect (kinda popping effect that looks 16x16) and players when squished
  Entity_Draw_8x16_FlickerTopDupe                           ;appears to be identical to the below value that appears to be used frequently
  Entity_Draw_8x16_FlickerTop                               ;used by sidesteppers and fighterflies, they change top tile position every frame.
  Entity_Draw_8x16_FlickerBottom                            ;used by sidesteppers and fighterflies when flipped over, same as above, but it's the bottom tile that flickers
  Entity_Draw_8x16                                          ;8x16. used by coins, freezies and other effects
  Entity_Draw_8x16_Shift                                    ;8x16 but the top tile is slightly shifted horizontally. used by Shellcreepers
  Entity_Draw_8x8                                           ;should be obvious, used for fireballs and various effects
.endenum

;score bonuses
.enum
  Score_ID_800
  Score_ID_1600
  Score_ID_2400
  Score_ID_3200
  Score_ID_200                                              ;unused
  Score_ID_500
.endenum

;version defines
.enum
  NTSC
  PAL
  Gamecube
.endenum