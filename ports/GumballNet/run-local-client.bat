@echo off
setlocal
set "GODOT_DIR=C:\Godot\Godot_v4.7.2-stable_mono_win64"
set "GODOT=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64_console.exe"
set "PROJECT_DIR=%~dp0."
set "CONTROLLER_DEVICE=%~1"
if "%CONTROLLER_DEVICE%"=="" set "CONTROLLER_DEVICE=0"

cd /d "%GODOT_DIR%"
echo Starting client with Xbox controller device %CONTROLLER_DEVICE%...
"%GODOT%" --path "%PROJECT_DIR%" -- --connect=127.0.0.1 --controller=%CONTROLLER_DEVICE%

echo.
echo This client stopped. Review any error above.
pause
