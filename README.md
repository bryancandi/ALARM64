# ALARM64

### An interactive command-line alarm clock utility written in x86-64 assembly (MASM) for Windows.

ALARM64 is a lightweight utility built in pure assembly. It provides a simple, interactive way to set an alarm for a specific time of day.

## Usage
When executed, this interactive command-line based alarm clock will prompt the user for a target alarm time in 24-hour format (HH:MM). If the input is invalid, the program will alert the user and prompt again to ensure the alarm is set correctly.

```text
.\ALARM64.exe

ALARM64 v1.1
----------------------------------------

Enter alarm target time (HH:MM): 07:00

Press Escape key to cancel the alarm.

Alarm set time: 07:00
Current time:   20:16
```

## Features
- **Small Footprint** - Written in pure x86-64 MASM assembly; ALARM64.exe process uses under 1 MB RAM.
- **Native Application** - Uses native Windows API calls for system time, timers, alarms.
- **Alarm Logic** - Sounds the alarm on the next occurrence of the entered target time whether it is the same day or the next day.

## Building from Source
To assemble and link the project, use the Microsoft Macro Assembler (included with Visual Studio Build Tools):

```powershell
ml64.exe alarm64.asm /link /SUBSYSTEM:console /ENTRY:start /OUT:ALARM64.exe
```
