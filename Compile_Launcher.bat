@echo off
REM ========================================
REM Script de Compilación FORZADA con Icono
REM ========================================

echo.
echo Compilando AI Hub con icono personalizado...
echo.

REM 1. Eliminar ejecutable anterior
if exist "AI_Hub.exe" (
    echo Eliminando AI_Hub.exe anterior...
    del /F /Q "AI_Hub.exe"
)

REM 2. Verificar icono
if not exist "icons\app_icon.ico" (
    echo ERROR: No se encuentra icons\app_icon.ico
    pause
    exit /b 1
)

echo Icono encontrado: icons\app_icon.ico

REM 3. Compilar con ruta absoluta al icono
set CSC_PATH=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
set ICON_PATH=%CD%\icons\app_icon.ico

echo.
echo Compilando con:
echo - Compilador: %CSC_PATH%
echo - Icono: %ICON_PATH%
echo.

"%CSC_PATH%" /target:winexe /out:AI_Hub.exe /win32icon:"%ICON_PATH%" AI_Hub_Launcher.cs

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   COMPILACION EXITOSA
    echo ========================================
    echo.
    echo Verifica que AI_Hub.exe tenga el icono morado.
    echo Si aun muestra el icono generico, el archivo .ico puede estar corrupto.
    echo.
) else (
    echo.
    echo ========================================
    echo   ERROR en la compilacion
    echo ========================================
    echo.
)

pause
