@echo off
title DukeSoundboard - Map & Build Launcher
cls

set "MAP_FILE_ARG=%~1"

echo ==========================================================
echo        SELECT A MAP TO LAUNCH ON DEVICE / EMULATOR       
echo ==========================================================
echo  1] Level 1       - t2_xl1bck.tmj
echo  2] Hideout       - t2_hideout.tmj
echo  3] Stage 3       - t2_stage3.tmj
echo  4] Skynet 1      - t2_xl4skynt1.tmj
echo  5] X-Road        - t2_xroad.tmj
echo  6] Level 7       - t2_xfback2.tmj
echo  7] Test Chamber  - t2_testchamber.tmj
if not "%MAP_FILE_ARG%"=="" echo  0] Active Map    - %~nx1
echo ==========================================================

set /p choice="Enter map number [0-7]: "

set "MAP="
if "%choice%"=="0" set "MAP=%MAP_FILE_ARG%"
if "%choice%"=="1" set "MAP=maps/backdrops/level1/t2_xl1bck.tmj"
if "%choice%"=="2" set "MAP=maps/backdrops/level1/t2_hideout.tmj"
if "%choice%"=="3" set "MAP=maps/backdrops/level1/t2_stage3.tmj"
if "%choice%"=="4" set "MAP=maps/backdrops/level1/t2_xl4skynt1.tmj"
if "%choice%"=="5" set "MAP=maps/backdrops/level1/t2_xroad.tmj"
if "%choice%"=="6" set "MAP=maps/backdrops/level1/t2_xfback2.tmj"
if "%choice%"=="7" set "MAP=maps/backdrops/level1/t2_testchamber.tmj"

if "%MAP%"=="" goto INVALID_CHOICE

echo.
echo ----------------------------------------------------------
echo   CHOOSE LAUNCH MODE FOR MAP: %MAP%
echo ----------------------------------------------------------
echo  1] Fast Launch - ADB only - approx 1s
echo  2] Full Rebuild and Launch - gradlew installDebug - approx 10s
echo ----------------------------------------------------------
set /p mode="Enter mode [1-2]: "

if "%mode%"=="2" goto DO_REBUILD
goto DO_LAUNCH

:DO_REBUILD
echo.
echo ==========================================================
echo Rebuilding APK (gradlew installDebug)...
echo ==========================================================
cd /d "C:\androidProject\lastchance\DukeSoundboard"
call gradlew.bat installDebug
if errorlevel 1 goto BUILD_ERROR

:DO_LAUNCH
echo.
echo Waking screen and launching map: %MAP% ...
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
adb shell am force-stop com.lastchance.dukesoundboard
adb shell am start -n com.lastchance.dukesoundboard/.test.CorridorShooterActivity --es map_asset_path "%MAP%"

echo.
echo SUCCESS! Map launched on your device/emulator.
timeout /t 3 >nul
exit /b

:INVALID_CHOICE
echo.
echo Invalid choice! Exiting...
timeout /t 2 >nul
exit /b

:BUILD_ERROR
echo.
echo ERROR: Gradle build failed!
pause
exit /b
