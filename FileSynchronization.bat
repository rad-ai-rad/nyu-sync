@echo off

:start
move /Y "Z:\Visage\Imaging\RisPACSXML\Out\*" "C:\Visage\Imaging\RisPACSXML\Out\" >nul 2>&1
del /F /Q "Z:\Visage\In\I-*.xml" >nul 2>&1
del /F /Q "Z:\Visage\Imaging\RisPACSXML\In\History\*" >nul 2>&1
for /D %%D in ("Z:\Visage\Imaging\RisPACSXML\In\History\*") do rd /S /Q "%%~fD"
shutdown /a >nul 2>&1
timeout /t 2 /nobreak >nul
goto start
