;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;NES Hardware Registers

ControlBits = $2000
RenderBits = $2001
HardwareStatus = $2002
OAMAddress = $2003

VRAMRenderAreaReg = $2005                                   ;write twice to point to to where the screen should point at (used to show things on screen and screen scrolling)
VRAMPointerReg = $2006                                      ;write twice to point to address in VRAM to update
VRAMUpdateRegister = $2007                                  ;write value to update VRAM address with

;this applies to all channels (except DMC (Delta Modulation Channel))
APU_ChannelFrequency = $4002
APU_ChannelFrequencyHigh = $4003

APU_ChannelRegister1 = $4000                                ;generic name that applies to all registers.
APU_ChannelRegister2 = $4001

APU_Square1DutyAndVolume = $4000                            ;bitwise DDLc vvvv, DD - Duty cycle (pulse width, the available values are 12.5%, 25%, 50% and 25% negated (basically the same?)), L - length counter halt (play sound indefinitely), c - constant volume/envelope (if clear, the volume goes down when the sound ends), v - volume bits, as you can imagine the higher it is, the louder it gets
APU_Square1Sweep = $4001                                    ;makes the sound "sweep" up or down its frequency (bitwise: EPPP NSSS, E - enable sweep, PPP - the divider's period (P+1 half-frames), N - negate flag, if clear, will sweep toward lower frequency, set - sweep toward higher frequency, SSS = shift count)
APU_Square1Frequency = $4002
APU_Square1FrequencyHigh = $4003                            ;first 3 bits are an extension to the above frequency thing, the rest are "Length counter load" bits, how long the sound will play (if L bit from APU_Square1DutyAndVolume isn't set)

APU_Square2DutyAndVolume = $4004                            ;same for the second square channel
APU_Square2Sweep = $4005
APU_Square2Frequency = $4006
APU_Square2FrequencyHigh = $4007

APU_TriangleLinearCounter = $4008                           ;bit 7 halts linear counter for constant noise, otherwise the channel will silence itself after playing the sound, the rest of the bits are how long the sound will play, basically like length counter load bits, but more flexible? but also doesn't allow for longer timing
;$4009 is unused for triangle
APU_TriangleFrequency = $400A                               ;think of it like a pitch control/how "long" the triangle is. the lower value is, the higher pitch it'll be
APU_TriangleFrequencyHigh = $400B                           ;first 3 bits are an extension to the above "pitch" thing, the rest are how long the sound will play  (in the context of the triangle channel, this is basically redundant, as there's already timer bits at APU_TriangleLinearCounter, the channel will be silenced once either reaches 0)

APU_NoiseVolume = $400C	                                    ;--LC VVVV, L - length counter halt (play the sound indefinitely if set), c - constant volume/envelope (if clear, the volume goes down when the sound ends), V - volume
;$400D is unused for noise
APU_NoiseLoop = $400E                                       ;bit 7 enables the loop, the bits 0 through 3 are the noise's period
APU_NoiseLength = $400F                                     ;same length counter load bits as previous channels, if length counter halt bit is clear, the noise will play for a certain amount of time

APU_DMCFrequency = $4010                                    ;IL-- RRRR. I - IRQ enabled flag, L - loop flag, R - rate index, basically determines the frequency of the sample
APU_DMCLoadCounter = $4011                                  ;like a timer for how long it runs, I guess? Like linear counter for other channels.... I THINK??? QUESTION MARK????????
APU_DMCSampleAddress = $4012                                ;where in ROM is the sample we're playing, starting from $C000 plus (input * 64).
APU_DMCSampleLength = $4013                                 ;how long is the sample? (input * 16) plus 1.

OAMDMAReg = $4014

APU_SoundChannels = $4015                                   ;used to enable channels (also, if read, returns some bit stuff, but it's not relevant here)
ControllerReg = $4016                                       ;$4016 - First controller, $4017 (read) - Second controller. also used for zapper
APU_FrameCounter = $4017                                    ;(write) bit 6 can enable IRQ and bit 7 changes step mode (4 or 5 step sequence for envelope/sweep/length of sound channels (except DMC)). IRQ only triggers at the end of the 4-step sequence (bit 7 must be clear).