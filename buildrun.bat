@echo off

odin build example -out:bin/odin-renderdoc.exe -debug

if %errorlevel% neq 0 exit echo Build failed. && /b %errorlevel%

if not "%1" == "norun" (
	bin\odin-renderdoc.exe
)
