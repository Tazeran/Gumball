@echo off
setlocal

set "GODOT_DIR=C:\Godot\Godot_v4.7.2-stable_mono_win64"
set "GODOT_GUI=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64.exe"
set "GODOT_CONSOLE=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64_console.exe"
set "PROJECT_DIR=%~dp0"

if not exist "%GODOT_GUI%" (
    echo Godot was not found at:
    echo   %GODOT_GUI%
    echo.
    echo Edit GODOT_DIR near the top of this file if Godot is installed elsewhere.
    pause
    exit /b 1
)

echo Starting the authoritative server on UDP 42837...
start "GumballNet Dedicated Server" "%GODOT_CONSOLE%" --headless --path "%PROJECT_DIR%" --server

echo Waiting briefly for the server to bind its port...
timeout /t 2 /nobreak >nul

echo Starting client 1...
start "GumballNet Client 1" "%GODOT_GUI%" --path "%PROJECT_DIR%" -- --connect=127.0.0.1

echo Starting client 2...
start "GumballNet Client 2" "%GODOT_GUI%" --path "%PROJECT_DIR%" -- --connect=127.0.0.1

echo.
echo Local match launched: one server and two clients.
echo Close the dedicated-server window when you are finished.
endlocal
