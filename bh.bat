@echo off
REM ============================================================
REM  bh.bat - shim that runs the PowerShell launcher (bh.ps1)
REM  Lets you type plain `bh ...` in BOTH CMD and PowerShell and
REM  get the richer PowerShell version. Forwards all arguments.
REM  Requires Docker Desktop running.
REM ============================================================
setlocal

REM Prefer PowerShell 7 (pwsh) if present, else fall back to Windows PowerShell.
where pwsh >nul 2>&1
if %errorlevel%==0 (
    set "PS=pwsh"
) else (
    set "PS=powershell"
)

%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0bh.ps1" %*
exit /b %errorlevel%
