@echo off

ml64.exe /c alarm64.asm
if errorlevel 1 goto :eof

rc.exe alarm64.rc
if errorlevel 1 goto :eof

link alarm64.obj alarm64.res /SUBSYSTEM:console /ENTRY:Start /OUT:ALARM64.exe
if errorlevel 1 goto :eof
