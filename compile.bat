@del MarioBros.o
@del MarioBros.nes
@echo.
@echo Compiling...
cc65\bin\ca65 MarioBrosDisCA65.asm -g -o MarioBrosDis.o
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Linking...
cc65\bin\ld65 -o MarioBrosDis.nes -C LinkerConfiguration.cfg MarioBrosDis.o
@echo.
@echo Success!
@pause
@GOTO endbuild
:failure
@echo.
@echo Build error!
@pause
:endbuild
