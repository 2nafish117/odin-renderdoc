@echo off

odin build . -out:bin/odin-renderdoc.exe -debug

if %errorlevel% neq 0 exit echo Build failed. && /b %errorlevel%

if not "%1" == "norun" (
	bin\odin-renderdoc.exe
)
