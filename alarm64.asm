;==============================================================================
; ALARM64.ASM - x64 Interactive Command-line Alarm Clock Utility
;
; Assemble and link with:
; ml64.exe alarm64.asm /link /SUBSYSTEM:console /ENTRY:main /OUT:ALARM64.exe
;
; Copyright (c) 2026 by Bryan C.
; Licensed under the Apache License, Version 2.0
;==============================================================================

INCLUDELIB kernel32.lib

ExitProcess         PROTO
GetStdHandle        PROTO
ReadFile            PROTO
WriteConsoleA       PROTO
GetLocalTime        PROTO :PTR SYSTEMTIME
Beep                PROTO :DWORD, :DWORD
Sleep               PROTO :DWORD

STD_INPUT_HANDLE    EQU -10
STD_OUTPUT_HANDLE   EQU -11
MaxSize             EQU 64

; SYSTEMTIME structure
SYSTEMTIME STRUCT
    wYear           WORD ?
    wMonth          WORD ?
    wDayOfWeek      WORD ?
    wDay            WORD ?
    wHour           WORD ?
    wMinute         WORD ?
    wSecond         WORD ?
    wMilliseconds   WORD ?
SYSTEMTIME ENDS

        .DATA
SysTime     SYSTEMTIME <>
header      BYTE    "ALARM64 v1.0", 0Dh, 0Ah
prompt      BYTE    0Dh, 0Ah, "Enter alarm target time (HH:MM): "
error       BYTE    0Dh, 0Ah, "Invalid time format. Use 24h HH:MM.", 0Dh, 0Ah
quit        BYTE    0Dh, 0Ah, "Press Ctrl-C to terminate.", 0Dh, 0Ah
lbl_alarm   BYTE    0Dh, 0Ah, "Alarm set time: "
lbl_local   BYTE    0Dh, "Current time:   "
wake        BYTE    0Dh, "Alarm!"
blank       BYTE    0Dh, "      "
done        BYTE    0Dh, "Alarm completed.", 0Dh, 0Ah
cr          BYTE    0Dh
crlf        BYTE    0Dh, 0Ah
dblsp       BYTE    0Dh, 0Ah, 0Ah
buffer      BYTE    MaxSize DUP (?)
fmtbuf      BYTE    MaxSize DUP (?)
str_local   BYTE    MaxSize DUP (?)
stdin       QWORD   ?
stdout      QWORD   ?
nbrd        DWORD   ?
nbwr        DWORD   ?
num_wspace  DWORD   ?
num_digits  DWORD   ?
alarm_time  DWORD   ?

        .CODE
main    PROC
        sub     rsp, 40

        mov     rcx, STD_INPUT_HANDLE
        call    GetStdHandle
        mov     [stdin], rax

        mov     rcx, STD_OUTPUT_HANDLE
        call    GetStdHandle
        mov     [stdout], rax

        ; Display header.
        mov     rcx, [stdout]
        lea     rdx, header
        mov     r8, LENGTHOF header
        lea     r9, nbwr
        call    WriteConsoleA

        ; Prompt and read input.
time_prompt:
        mov     rcx, [stdout]
        lea     rdx, prompt
        mov     r8, LENGTHOF prompt
        lea     r9, nbwr
        call    WriteConsoleA

        mov     rcx, [stdin]
        lea     rdx, buffer
        mov     r8, MaxSize
        lea     r9, nbrd
        call    ReadFile

        ; Validate user input; acceptable format = HH:MM.
        lea     rsi, buffer                 ; RSI = pointer to source buffer
        lea     rdi, fmtbuf                 ; RDI = pointer to destination buffer
        xor     r8d, r8d                    ; R8D = white space counter
        xor     r9d, r9d                    ; R9D = digit counter (this should always = 4)

hour_first_digit:
        ; H position 1 / leading white space check:
        ; Acceptable range is 0-2 (10:00 or 20:00).
        mov     al, [rsi]
        cmp     al, ' '
        je      consume_leading_space       ; Consume leading white space
        cmp     al, '0'
        jb      time_invalid
        cmp     al, '2'
        ja      time_invalid
        mov     [rdi], al
        mov     cl, al                      ; CL = first hour digit, for second hour digit validation
        inc     rsi
        inc     rdi
        inc     r9d

        ; H position 2:
        ; If hour starts with 0 or 1, range is 0-9 (10:00 to 19:00).
        ; If hour starts with 2, range is 0-3 (20:00 to 23:00).
        mov     al, [rsi]
        cmp     al, '0'
        jb      time_invalid
        cmp     cl, '2'                     ; Is time after 20:00?
        je      hour_20_to_23               ; Yes
        cmp     al, '9'                     ; No
        ja      time_invalid
        mov     [rdi], al
        inc     rsi
        inc     rdi
        inc     r9d
        jmp     colon_separator
hour_20_to_23:
        cmp     al, '3'
        ja      time_invalid
        mov     [rdi], al
        inc     rsi
        inc     rdi
        inc     r9d

        ; Check for colon and remove for time comparison:
colon_separator:
        mov     al, [rsi]
        cmp     al, ':'
        jne     time_invalid
        jmp     consume_separator

minute_first_digit:
        ; M position 1
        ; Acceptable range is 0-5.
        mov     al, [rsi]
        cmp     al, '0'
        jb      time_invalid
        cmp     al, '5'
        ja      time_invalid
        mov     [rdi], al
        inc     rsi
        inc     rdi
        inc     r9d

        ; M positon 2:
        ; Acceptable range is 0-9.
        mov     al, [rsi]
        cmp     al, '0'
        jb      time_invalid
        cmp     al, '9'
        ja      time_invalid
        mov     [rdi], al
        inc     r9d
        mov     [num_wspace], r8d
        mov     [num_digits], r9d

        ; Trailing character check:
        ; Continue only if the next character is NULL, space, CR, or LF.
        ; Otherwise consider the value invalid.
        inc     rsi
        mov     al, [rsi]
        cmp     al, 0
        je      time_valid
        cmp     al, ' '
        je      time_valid
        cmp     al, 0Dh
        je      time_valid
        cmp     al, 0Ah
        je      time_valid
        jmp     time_invalid

consume_leading_space:
        inc     rsi
        inc     r8d
        jmp     hour_first_digit

consume_separator:
        inc     rsi
        jmp     minute_first_digit

time_invalid:
        mov     rcx, [stdout]
        lea     rdx, error
        mov     r8d, LENGTHOF error
        lea     r9, nbwr
        call    WriteConsoleA
        jmp     time_prompt
time_valid:

        ; Convert user input to an integer for comparison.
        mov     ebx, [num_digits]           ; Number of characters in the string
        xor     r8, r8                      ; Initial buffer position index = 0
        xor     rax, rax
        lea     rcx, fmtbuf                 ; RCX = pointer to formatted buffer
str_to_int_loop:
        movzx   rdx, BYTE PTR [rcx + r8]    ; RDX = digit character at buffer[index], zero-extended
        sub     rdx, '0'
        imul    rax, rax, 10
        add     rax, rdx
        inc     r8                          ; Increment buffer position
        dec     ebx                         ; Decrement digit counter
        test    ebx, ebx
        jnz     str_to_int_loop
        mov     [alarm_time], eax           ; Store alarm time in 'alarm_time'

        ; Alarm is set; print set time.
        mov     rcx, [stdout]
        lea     rdx, quit
        mov     r8, LENGTHOF quit
        lea     r9, nbwr
        call    WriteConsoleA

        mov     rcx, [stdout]
        lea     rdx, lbl_alarm
        mov     r8, LENGTHOF lbl_alarm
        lea     r9, nbwr
        call    WriteConsoleA

        mov     r10d, [nbrd]                ; Number of characters written to buffer
        mov     eax, [num_wspace]           ; Number of white spaces to skip in the buffer
        sub     r10d, eax                   ; Subtract white space character count from buffer length
        mov     rcx, [stdout]
        lea     rdx, buffer
        add     rdx, rax                    ; Advance to buffer past white spaces
        mov     r8d, r10d
        lea     r9, nbwr
        call    WriteConsoleA

        ; Compare loop has three functions:
        ; 1. Build a string from SysTime stuct for printing (wHour:wMinute).
        ; 2. Combine wMinute and wHour into a 4 digit integer time format (HHMM).
        ; 3. Compare alarm set time to the system local time, jump to alarm when they match.
compare_loop:
        lea     rdi, str_local              ; Pointer to buffer to build local time string
        lea     rcx, SysTime
        call    GetLocalTime

        ; Store hours in buffer.
        xor     edx, edx
        movzx   eax, SysTime.wHour
        mov     ecx, 10
        div     ecx
        add     al, '0'                     ; AL = first hour digit
        add     dl, '0'                     ; DL = second hour digit
        mov     [rdi], al
        inc     rdi
        mov     [rdi], dl
        inc     rdi

        ; Store ':' in buffer.
        mov     al, ':'
        mov     [rdi], al
        inc     rdi

        ; Store minutes in buffer.
        xor     edx, edx
        movzx   eax, SysTime.wMinute
        mov     ecx, 10
        div     ecx
        add     al, '0'                     ; AL = first minute digit
        add     dl, '0'                     ; DL = second minunte digit
        mov     [rdi], al
        inc     rdi
        mov     [rdi], dl

        ; Print local time label and local time string.
        ; 'lbl_local' begins with CR to overwrite the current line on each update.
        mov     rcx, [stdout]
        lea     rdx, lbl_local
        mov     r8, LENGTHOF lbl_local
        lea     r9, nbwr
        call    WriteConsoleA

        mov     rcx, [stdout]
        lea     rdx, str_local
        mov     r8, LENGTHOF str_local
        lea     r9, nbwr
        call    WriteConsoleA

        ; Compare current time to alarm set time.
        lea     rcx, SysTime
        call    GetLocalTime
        movzx   eax, SysTime.wHour
        movzx   ecx, SysTime.wMinute
        imul    eax, eax, 100               ; EAX = hours * 100 (12 to 1200)
        add     eax, ecx                    ; EAX = hours + minutes
        mov     edx, [alarm_time]
        cmp     eax, edx                    ; Have we reached the alarm set time?
        je      alarm                       ; Yes, sound the alarm
        mov     ecx, 10000                  ; No, sleep 10 seconds and check again
        call    Sleep
        jmp     compare_loop

        ; Sound the alarm!
alarm:
        mov     rcx, [stdout]
        lea     rdx, dblsp
        mov     r8, LENGTHOF dblsp
        lea     r9, nbwr
        call    WriteConsoleA

        mov     ebx, 400                    ; Number of alarm cycles (400 = 10 minutes)
beep_loop:
        mov     ecx, 700                    ; Beep frequency (Hz)
        mov     edx, 1000                   ; Beep duration (ms)
        call    Beep

        mov     rcx, [stdout]
        lea     rdx, blank
        mov     r8, LENGTHOF blank
        lea     r9, nbwr
        call    WriteConsoleA               ; Write blank message

        mov     ecx, 500                    ; Sleep 500 ms
        call    Sleep
        mov     rcx, [stdout]
        lea     rdx, wake
        mov     r8, LENGTHOF wake
        lea     r9, nbwr
        call    WriteConsoleA               ; Write alarm message

        dec     ebx                         ; Decrement cycles
        test    ebx, ebx
        jz      exit
        jmp     beep_loop

exit:
        mov     rcx, [stdout]
        lea     rdx, done
        mov     r8, LENGTHOF done
        lea     r9, nbwr
        call    WriteConsoleA

        xor     rcx, rcx
        call    ExitProcess
main    ENDP
        END
