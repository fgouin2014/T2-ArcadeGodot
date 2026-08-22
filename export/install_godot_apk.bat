@echo off
echo [T2 ARCADE] Installation de l'APK Godot sur votre appareil Android...
echo.

set APK_PATH=%~dp0T2Arcade.apk

if not exist "%APK_PATH%" (
    echo [ERREUR] Le fichier T2Arcade.apk n'a pas ete trouve dans %~dp0
    echo Veuillez effectuer l'export dans Godot sous le nom T2Arcade.apk d'abord.
    echo.
    pause
    exit /b 1
)

adb install -r "%APK_PATH%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCÈS] T2 Arcade APK a ete installe sur votre appareil !
) else (
    echo.
    echo [eCHEC] Erreur lors de l'installation ADB. Assurez-vous que le telephone est branche avec le debogage USB.
)

echo.
pause
