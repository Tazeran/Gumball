@echo off
setlocal
set "GODOT_DIR=C:\Godot\Godot_v4.7.2-stable_mono_win64"
set "GODOT=%GODOT_DIR%\Godot_v4.7.2-stable_mono_win64_console.exe"
set "PROJECT_DIR=%~dp0."

cd /d "%GODOT_DIR%"
"%GODOT%" --headless --path "%PROJECT_DIR%" --server

echo.
echo The dedicated server stopped. Review any error above.
pause
