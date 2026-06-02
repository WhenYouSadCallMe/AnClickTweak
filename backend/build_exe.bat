@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "OUT_DIR=%CD%\dist"
set "OUT_EXE=%OUT_DIR%\anclick-backend.exe"

where go >nul 2>nul
if errorlevel 1 (
    echo [AnClick] Go not found. Please install Go first.
    if /I not "%~1"=="/nopause" pause
    exit /b 1
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo [AnClick] Building backend exe...
go build -trimpath -ldflags="-s -w" -o "%OUT_EXE%" .
if errorlevel 1 (
    echo [AnClick] Build failed.
    if /I not "%~1"=="/nopause" pause
    exit /b 1
)

echo [AnClick] Build success:
echo %OUT_EXE%
echo.
echo Double-click the exe to start the server and open the web console.

if /I not "%~1"=="/nopause" pause
