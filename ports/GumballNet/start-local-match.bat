@echo off
setlocal

set "GODOT_DIR=C:\Godot\Godot_v4.7.2-stable_mono_win64"
set "GODOT_CONSOLE=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64_console.exe"
rem The trailing dot prevents %~dp0's final backslash from escaping a quoted argument.
set "PROJECT_DIR=%~dp0."

if not exist "%GODOT_CONSOLE%" (
    echo Godot was not found at:
    echo   %GODOT_CONSOLE%
    echo.
    echo Edit GODOT_DIR near the top of this file if Godot is installed elsewhere.
    pause
    exit /b 1
)

netstat -ano -p UDP | findstr /C:":42837 " >nul
if not errorlevel 1 (
    echo UDP port 42837 is already in use.
    echo A previous GumballNet server may still be running.
    echo Close its console window, then run this launcher again.
    pause
    exit /b 2
)

echo Starting the authoritative server on UDP 42837...
start "GumballNet Dedicated Server" "%PROJECT_DIR%\run-local-server.bat"

echo Waiting briefly for the server to bind its port...
ping 127.0.0.1 -n 3 >nul

echo Starting client 1...
start "GumballNet Client 1" "%PROJECT_DIR%\run-local-client.bat"

echo Starting client 2...
start "GumballNet Client 2" "%PROJECT_DIR%\run-local-client.bat"

echo.
echo Local match launched: one server and two clients.
echo Each process has a console window so startup errors remain visible.
echo Close all three console windows when you are finished.
endlocal
