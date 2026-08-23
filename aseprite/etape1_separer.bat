@echo off
setlocal enabledelayedexpansion
set "ASEPRITE_PATH=C:\androidProject\aseprite\build\bin\aseprite.exe"

echo --- ETAPE 1 : Separation et Nettoyage des Tags ---

for /f "delims=" %%f in ('dir *.ase /b /o:n 2^>nul') do (
    set "FILE_NAME=%%~nf"
    echo [Traitement de] : %%f
    
    mkdir "%%~nf" 2>nul
    
    :: Exportation initiale
    "%ASEPRITE_PATH%" -b "%%f" --save-as "%%~nf/%%~nf_{frame01}.png"
    

)

echo.
echo Separation et nettoyage termines ! Les tags vides ont ete nommes 'statique'.
pause
