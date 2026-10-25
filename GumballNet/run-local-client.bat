@echo off
setlocal
set "GODOT_DIR=C:\Godot\Godot_v4.7.2-stable_mono_win64"
set "GODOT=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64_console.exe"
set "PROJECT_DIR=%~dp0."
set "CONTROLLER_DEVICES=%~1"
set "LOCAL_PLAYERS=%~2"
if "%CONTROLLER_DEVICES%"=="" set "CONTROLLER_DEVICES=0"
if "%LOCAL_PLAYERS%"=="" set "LOCAL_PLAYERS=1"

cd /d "%GODOT_DIR%"
echo Starting client with %LOCAL_PLAYERS% local player(s) on controller device(s) %CONTROLLER_DEVICES%...
"%GODOT%" --path "%PROJECT_DIR%" -- --connect=127.0.0.1 --local-players=%LOCAL_PLAYERS% --controllers=%CONTROLLER_DEVICES%

echo.
echo This client stopped. Review any error above.
pause
