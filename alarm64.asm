;============================================================================
; ALARM64.ASM - x64 Interactive Command-line Alarm Clock Utility
;
; Assemble and link with:
; ml64.exe alarm64.asm /link /SUBSYSTEM:console /ENTRY:start /OUT:ALARM64.exe
;
; Copyright (c) 2026 by Bryan C.
; Licensed under the Apache License, Version 2.0
;============================================================================

INCLUDELIB kernel32.lib                     ; Link the Windows kernel library
INCLUDELIB user32.lib                       ; Link the Windows user interface library

;----------------------------------------------------------------------------
; Win32 function prototypes with arguments.
; x64 args in: RCX, RDX, R8, R9, stack
;----------------------------------------------------------------------------

; --- Process & System ---
ExitProcess         PROTO uExitCode:DWORD
Sleep               PROTO dwMilliseconds:DWORD

; --- Time & Date ---
GetLocalTime        PROTO lpSystemTime:PTR SYSTEMTIME

; --- Console & File I/O ---
GetStdHandle        PROTO nStdHandle:DWORD
ReadFile            PROTO hFile:QWORD, lpBuffer:PTR, nNumberOfBytesToRead:DWORD, lpNumberOfBytesRead:PTR, lpOverlapped:PTR
WriteFile           PROTO hFile:QWORD, lpBuffer:PTR, nNumberOfBytesToWrite:DWORD, lpNumberOfBytesWritten:PTR, lpOverlapped:PTR
ReadConsoleInputW   PROTO hConsoleInput:QWORD, lpBuffer:PTR INPUT_RECORD, nLength:DWORD, lpNumberOfEventsRead:PTR
GetNumberOfConsoleInputEvents PROTO hConsoleInput:QWORD, lpcNumberOfEvents:PTR

; --- Device ---
Beep                PROTO dwFreq:DWORD, dwDuration:DWORD

;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------

STD_INPUT_HANDLE    EQU -10
STD_OUTPUT_HANDLE   EQU -11
MaxSize             EQU 64
KEY_EVENT           EQU 0001h               ; KEY_EVENT_RECORD structure
KEY_DOWN            EQU 1h                  ; KEY_DOWN TRUE
VK_ESCAPE           EQU 1Bh                 ; ESC virtual key code

;----------------------------------------------------------------------------
; Macros
;----------------------------------------------------------------------------

; WriteFile macro for static buffers.
mWriteFile  MACRO   buffer:REQ
    mov     rcx, [stdout]                   ; Arg 1 = hFile (value)
    lea     rdx, buffer                     ; Arg 2 = lpBuffer (pointer)
    mov     r8, SIZEOF buffer               ; Arg 3 = nNumberOfBytesToWrite (value)
    lea     r9, nbwr                        ; Arg 4 = lpNumberOfBytesWritten (pointer)
    mov     QWORD PTR [rsp+32], 0           ; Arg 5 = lpOverlapped (NULL pointer on stack)
    call    WriteFile
    test    eax, eax                        ; Non-zero = success; zero = failure
    jz      write_failure
ENDM

; Handle console input events and check for exit key press.
mReadExitKey MACRO
    LOCAL   event_loop, continue
event_loop:
    ; Was an input event detected?
    mov     rcx, [stdin]                    ; Handle to console input buffer
    lea     rdx, eventsRead                 ; Pointer to a variable that receives the number of input records read
    call    GetNumberOfConsoleInputEvents
    test    rax, rax                        ; Non-zero = success; zero = failure
    jz      continue                        ; API failed, disregard and keep running the alarm
    cmp     eventsRead, 0                   ; Any events read?
    je      continue                        ; No, continue

    ; If this code is reached, an input event was detected; process it.
    mov     rcx, [stdin]                    ; Handle to console input buffer
    lea     rdx, irInBuf                    ; Pointer to array of INPUT_RECORD structures that receives the input buffer data
    mov     r8, 1                           ; Size of the array pointed to by the lpBuffer parameter, in array elements
    lea     r9, eventsRead                  ; Pointer to a variable that receives the number of input records read
    call    ReadConsoleInputW               ; Call to populate struct with key events
    test    rax, rax                        ; Non-zero = success; zero = failure
    jz      continue                        ; API failed, disregard and keep running the alarm

    cmp     irInBuf.EventType, KEY_EVENT    ; Was the event a KEY_EVENT?
    jne     event_loop                      ; No, go back and check again
    cmp     irInBuf.KeyEvent.bKeyDown, KEY_DOWN ; Was the event a KEY_DOWN?
    jne     event_loop                      ; No, go back and check again
    cmp     irInBuf.KeyEvent.wVirtualKeyCode, VK_ESCAPE ; ESC key pressed?
    je      exit_esc                        ; Yes, exit
    jmp     event_loop                      ; No, key was not ESC, go back and check again
continue:
ENDM

;----------------------------------------------------------------------------
; Structures
;----------------------------------------------------------------------------

; Key Event Record and Input Record structure populated by ReadConsoleInput.
KEY_EVENT_RECORD STRUCT
    bKeyDown          DWORD ?
    wRepeateCount     WORD  ?
    wVirtualKeyCode   WORD  ?
    wVirtualScanCode  WORD  ?

    UNION
        UnicodeChar   WORD  ?
        AsciiChar     BYTE  ?
    ENDS

    dwControlKeyState DWORD ?
KEY_EVENT_RECORD ENDS

INPUT_RECORD STRUCT
    EventType       WORD ?
    Reserved        WORD ?

    UNION
        KeyEvent    KEY_EVENT_RECORD <>
    ENDS
INPUT_RECORD ENDS

; System Time structure populated by GetLocalTime.
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

;----------------------------------------------------------------------------
; Data Segment
;----------------------------------------------------------------------------

        .DATA
irInBuf     INPUT_RECORD <>                 ; Instance of INPUT_RECORD with default initialization
SysTime     SYSTEMTIME <>                   ; Instance of SYSTEMTIME with default initialization
header      BYTE    0Dh, 0Ah, "ALARM64 v1.1", 0Dh, 0Ah
separator   BYTE    "----------------------------------------", 0Dh, 0Ah
prompt      BYTE    0Dh, 0Ah, "Enter alarm target time (HH:MM): "
error       BYTE    0Dh, 0Ah, "Invalid time format. Use 24h HH:MM.", 0Dh, 0Ah
quit        BYTE    0Dh, 0Ah, "Press ESC to cancel the alarm.", 0Dh, 0Ah
lbl_alarm   BYTE    0Dh, 0Ah, "Alarm set time: "
lbl_local   BYTE    0Dh, "Current time:   "
wake        BYTE    0Dh, "Alarm!"
blank       BYTE    0Dh, "      "
done        BYTE    0Dh, "Alarm completed.", 0Dh, 0Ah
esc_done    BYTE    0Dh, 0Ah, 0Ah, "Alarm cancelled by user.", 0Dh, 0Ah
cr          BYTE    0Dh
crlf        BYTE    0Dh, 0Ah
dblsp       BYTE    0Dh, 0Ah, 0Ah
err_handle  BYTE    0Dh, 0Ah, "ALARM64: GetStdHandle system call failure.", 0Dh, 0Ah
err_read    BYTE    0Dh, 0Ah, "ALARM64: ReadFile system call failure.", 0Dh, 0Ah
err_write   BYTE    0Dh, 0Ah, "ALARM64: WriteFile system call failure.", 0Dh, 0Ah
err_beep    BYTE    0Dh, 0Ah, "ALARM64: Beep system call failure.", 0Dh, 0Ah
buffer      BYTE    MaxSize DUP (?)
fmtbuf      BYTE    MaxSize DUP (?)
str_local   BYTE    MaxSize DUP (?)
stdin       QWORD   ?
stdout      QWORD   ?
nbrd        DWORD   ?                       ; Number of bytes read
nbwr        DWORD   ?                       ; Number of bytes written
eventsRead  DWORD   ?                       ; Number of input events read
num_wspace  DWORD   ?
num_digits  DWORD   ?
alarm_time  DWORD   ?

;----------------------------------------------------------------------------
; Code Segment
;----------------------------------------------------------------------------

        .CODE
start   PROC    USES rbx rsi rdi r12
        ; Program entry procedure uses 4 non-volatile registers. The USES directive pushes them on the stack.
        ; Since 4 pushes x 8 bytes = 32 bytes (a multiple of 16), stack alignment remains unchanged.
        ; We will reserve 32 bytes for "shadow space" and an additional 8 bytes for alignment.
        ; Process entry begins with RSP misaligned by 8 bytes per the Windows x64 ABI because
        ; CALL pushes an 8-byte return address onto the stack.
        sub     rsp, 40                     ; Reserve shadow space on stack (32 bytes + 8 to align)

        mov     rcx, STD_INPUT_HANDLE       ; nStdHandle
        call    GetStdHandle
        cmp     eax, -1                     ; Check for failure code (-1)
        je      get_handle_failure
        mov     [stdin], rax                ; Store handle for use with ReadFile

        mov     rcx, STD_OUTPUT_HANDLE      ; nStdHandle
        call    GetStdHandle
        cmp     eax, -1                     ; Check for failure code (-1)
        je      get_handle_failure
        mov     [stdout], rax               ; Store handle for use with WriteFile

        ; Write header and separator.
        mWriteFile  header
        mWriteFile  separator

        ; Write prompt and read input.
time_prompt:
        mWriteFile  prompt

        mov     rcx, [stdin]                ; Arg 1 = hFile (value)
        lea     rdx, buffer                 ; Arg 2 = lpBuffer (pointer)
        mov     r8, MaxSize                 ; Arg 3 = nNumberOfBytesToRead (value)
        lea     r9, nbrd                    ; Arg 4 = lpNumberOfBytesRead (pointer)
        mov     QWORD PTR [rsp+32], 0       ; Arg 5 = lpOverlapped (NULL pointer on stack)
        call    ReadFile
        test    eax, eax                    ; Non-zero = success; zero = failure
        jz      read_failure

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
        mWriteFile  error
        jmp     time_prompt
time_valid:

        ; Convert user input to an integer for comparison.
        mov     ebx, [num_digits]           ; EBX = number of characters in the string
        xor     r8, r8                      ; R8 = buffer position index (0)
        xor     rax, rax
        lea     rcx, fmtbuf                 ; RCX = pointer to formatted buffer
str_to_int_loop:
        movzx   rdx, BYTE PTR [rcx+r8]      ; RDX = digit character at buffer[index], zero-extended
        sub     rdx, '0'
        imul    rax, rax, 10
        add     rax, rdx
        inc     r8                          ; Increment buffer position
        dec     ebx                         ; Decrement digit counter
        test    ebx, ebx
        jnz     str_to_int_loop
        mov     [alarm_time], eax           ; Store alarm time in 'alarm_time'

        ; Alarm is set.
        ; Sound a test tone to ensure the alarm cannot fail silently due to a Beep system call failure.
        ; Write cancel alarm instruction and alarm set time.
        mov     ecx, 700                    ; dwFreq (Hz)
        mov     edx, 250                    ; dwDuration (ms)
        call    Beep
        test    eax, eax                    ; Non-zero = success; zero = failure
        jz      beep_failure

        mWriteFile  quit
        mWriteFile  lbl_alarm

        mov     r10d, [nbrd]                ; R10D = number of bytes written to buffer
        mov     eax, [num_wspace]           ; EAX = number of white spaces to skip in the buffer
        sub     r10d, eax                   ; Subtract white space count from buffer length
        mov     rcx, [stdout]
        lea     rdx, buffer
        add     rdx, rax                    ; Advance to buffer past white spaces
        mov     r8d, r10d
        lea     r9, nbwr
        mov     QWORD PTR [rsp+32], 0
        call    WriteFile
        test    eax, eax                    ; Non-zero = success; zero = failure
        jz      write_failure

        ; Compare loop has four functions:
        ; 1. Check if exit key has been pressed.
        ; 2. Build a string from SysTime stuct for printing (wHour:wMinute).
        ;    Count characters while building string in non-volatile register R12D to survive calls.
        ; 3. Combine wMinute and wHour into a 4 digit integer time format (HHMM).
        ; 4. Compare alarm set time to the system local time, jump to alarm when they match.
compare_loop:
        mReadExitKey                        ; Check for exit key press.

        lea     rdi, str_local              ; RDI = pointer to buffer to build local time string
        xor     r12d, r12d                  ; R12D = counter for characters written to local time string
        lea     rcx, SysTime                ; Arg 1 = pointer to the time structure
        call    GetLocalTime                ; Call to populate struct with current time data

        ; Store hours in buffer.
        xor     edx, edx                    ; EDX = division remainder (clear)
        movzx   eax, SysTime.wHour
        mov     ecx, 10
        div     ecx
        add     al, '0'                     ; AL = first hour digit
        add     dl, '0'                     ; DL = second hour digit
        mov     [rdi], al
        inc     rdi
        inc     r12d
        mov     [rdi], dl
        inc     rdi
        inc     r12d

        ; Store ':' in buffer.
        mov     al, ':'
        mov     [rdi], al
        inc     rdi
        inc     r12d

        ; Store minutes in buffer.
        xor     edx, edx
        movzx   eax, SysTime.wMinute
        mov     ecx, 10
        div     ecx
        add     al, '0'                     ; AL = first minute digit
        add     dl, '0'                     ; DL = second minute digit
        mov     [rdi], al
        inc     rdi
        inc     r12d
        mov     [rdi], dl
        inc     r12d

        ; Write local time label and local time string.
        ; 'lbl_local' begins with CR to overwrite the current line on each update.
        mWriteFile  lbl_local

        mov     rcx, [stdout]
        lea     rdx, str_local
        mov     r8d, r12d                   ; R12D = number of characters written to 'str_local'
        lea     r9, nbwr
        mov     QWORD PTR [rsp+32], 0
        call    WriteFile
        test    eax, eax                    ; Non-zero = success; zero = failure
        jz      write_failure

        ; Compare current time to alarm set time.
        movzx   eax, SysTime.wHour
        movzx   ecx, SysTime.wMinute
        imul    eax, eax, 100               ; EAX = hours * 100 (12 to 1200)
        add     eax, ecx                    ; EAX = hours + minutes
        mov     edx, [alarm_time]
        cmp     eax, edx                    ; Have we reached the alarm set time?
        je      alarm                       ; Yes, sound the alarm
        mov     ecx, 1000                   ; dwMilliseconds (ms)
        call    Sleep                       ; No, sleep, then check again
        jmp     compare_loop

        ; Sound the alarm!
alarm:
        mWriteFile  dblsp                   ; Write double space
        mov     ebx, 400                    ; EBX = number of alarm cycles (400 = 10 minutes)
beep_loop:
        mReadExitKey                        ; Check for exit key press.

        mov     ecx, 700                    ; dwFreq (Hz)
        mov     edx, 1000                   ; dwDuration (ms)
        call    Beep
        test    eax, eax                    ; Non-zero = success; zero = failure
        jz      beep_failure

        mWriteFile  blank                   ; Write blank message

        mov     ecx, 500                    ; Sleep 500 ms
        call    Sleep

        mWriteFile  wake                    ; Write 'Alarm!' message

        dec     ebx                         ; Decrement cycles
        test    ebx, ebx
        jz      exit_done
        jmp     beep_loop

get_handle_failure:
        mWriteFile  err_handle
        jmp     exit
read_failure:
        mWriteFile  err_read
        jmp     exit
write_failure:
        mWriteFile  err_write
        jmp     exit
beep_failure:
        mWriteFile  err_beep
        jmp     exit

exit_esc:
        mWriteFile  esc_done                ; Write ESC alarm termination message
        jmp     exit
exit_done:
        mWriteFile  done                    ; Write alarm completed message
exit:
        xor     ecx, ecx                    ; uExitCode
        call    ExitProcess
start   ENDP
        END
