@echo off

mkdir bin

odin build example -out:bin/odin-renderdoc.exe -vet -strict-style -vet-tabs -disallow-do -warnings-as-errors -debug

if %errorlevel% neq 0 exit echo Build failed. && /b %errorlevel%

if not "%1" == "norun" (
	bin\odin-renderdoc.exe
)
