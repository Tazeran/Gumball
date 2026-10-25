@echo off
setlocal

set "GODOT_DIR=C:\Godot\Godot_v4.7.2-stable_mono_win64"
set "GODOT_CONSOLE=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64_console.exe"
set "GODOT_GUI=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64.exe"
rem The trailing dot prevents %~dp0's final backslash from escaping a quoted argument.
set "PROJECT_DIR=%~dp0."

rem Development window layout. Adjust these for your monitor resolution.
set "CLIENT_SIZE=1840x1035"
set "CLIENT_1_POSITION=20,40"
set "CLIENT_2_POSITION=1940,40"
set "CLIENT_SCREEN=0"

if not exist "%GODOT_CONSOLE%" (
    echo Godot was not found at:
    echo   %GODOT_CONSOLE%
    echo.
    echo Edit GODOT_DIR near the top of this file if Godot is installed elsewhere.
    pause
    exit /b 1
)
if not exist "%GODOT_GUI%" (
    echo Godot was not found at:
    echo   %GODOT_GUI%
    pause
    exit /b 1
)

echo Closing previous GumballNet clients and servers...
powershell.exe -NoProfile -Command "$project = '%PROJECT_DIR%'; Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot_v4.7.2*' -and $_.CommandLine -like ('*' + $project + '*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
ping 127.0.0.1 -n 2 >nul

netstat -ano -p UDP | findstr /C:":42837 " >nul
if not errorlevel 1 (
    echo UDP port 42837 is already in use.
    echo Existing GumballNet processes were closed, so another program owns the port.
    echo Close that program or change the configured game port before trying again.
    pause
    exit /b 2
)

echo Starting the authoritative server on UDP 42837...
start "GumballNet Dedicated Server" /D "%GODOT_DIR%" "%GODOT_CONSOLE%" --headless --path "%PROJECT_DIR%" --server

echo Waiting briefly for the server to bind its port...
ping 127.0.0.1 -n 3 >nul

echo Starting client 1...
start "GumballNet Client 1 - Controller 1" /D "%GODOT_DIR%" "%GODOT_GUI%" --path "%PROJECT_DIR%" --windowed --resolution %CLIENT_SIZE% --position %CLIENT_1_POSITION% --screen %CLIENT_SCREEN% -- --connect=127.0.0.1 --local-players=1 --controllers=0

echo Starting client 2...
start "GumballNet Client 2 - Controller 2" /D "%GODOT_DIR%" "%GODOT_GUI%" --path "%PROJECT_DIR%" --windowed --resolution %CLIENT_SIZE% --position %CLIENT_2_POSITION% --screen %CLIENT_SCREEN% -- --connect=127.0.0.1 --local-players=1 --controllers=1

echo.
echo Local match launched: one server and two clients.
echo The one persistent console window is the dedicated server.
echo Close the server console and both game windows when you are finished.
endlocal
