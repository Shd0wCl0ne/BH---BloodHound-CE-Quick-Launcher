@echo off
REM ============================================================
REM  bh.cmd - BloodHound CE quick launcher (Windows / CMD port)
REM  Usage: bh {up^|down^|status^|logs^|password^|reset^|url}
REM  Requires Docker Desktop running.
REM ============================================================
setlocal EnableExtensions EnableDelayedExpansion

REM Resolve this script's own directory (trailing backslash) so the
REM compose file is found next to it.
set "BH_DIR=%~dp0"
set "COMPOSE_FILE=%BH_DIR%docker-compose.yml"

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=help"

REM Docker daemon check (skip for help/url which don't touch docker)
if /i not "%ACTION%"=="help" if /i not "%ACTION%"=="url" (
    docker info >nul 2>&1
    if errorlevel 1 (
        echo [-] Docker is not running. Start Docker Desktop and try again.
        exit /b 1
    )
)

if /i "%ACTION%"=="up"       goto :up
if /i "%ACTION%"=="down"     goto :down
if /i "%ACTION%"=="status"   goto :status
if /i "%ACTION%"=="logs"     goto :logs
if /i "%ACTION%"=="password" goto :password
if /i "%ACTION%"=="reset"    goto :reset
if /i "%ACTION%"=="url"      goto :url
goto :help

:up
echo [*] Starting BloodHound CE...
docker compose -f "%COMPOSE_FILE%" up -d
echo [+] BloodHound UI: http://localhost:8080
echo [*] First run? Get the initial password with: bh password
goto :eof

:down
echo [*] Stopping BloodHound CE...
docker compose -f "%COMPOSE_FILE%" down
echo [+] Stopped.
goto :eof

:status
docker compose -f "%COMPOSE_FILE%" ps
goto :eof

:logs
set "SVC=%~2"
if "%SVC%"=="" set "SVC=bloodhound"
docker compose -f "%COMPOSE_FILE%" logs -f --tail=100 %SVC%
goto :eof

:password
echo [*] Searching for initial admin password in logs...
docker compose -f "%COMPOSE_FILE%" logs bloodhound 2>&1 | findstr /i /c:"Initial Password Set To" /c:"initial password"
if errorlevel 1 echo [-] No initial password found. Either already changed or containers haven't started yet.
goto :eof

:reset
set /p ANS=[!] This will DELETE all BloodHound data (graph + DB). Continue? [y/N]
if /i "%ANS%"=="y" (
    docker compose -f "%COMPOSE_FILE%" down --volumes
    docker volume rm bh_postgres-data bh_neo4j-data >nul 2>&1
    echo [+] Volumes removed. Run 'bh up' for a fresh instance.
) else (
    echo [*] Aborted.
)
goto :eof

:url
echo http://localhost:8080
goto :eof

:help
echo BloodHound CE Manager ^(Windows / CMD^)
echo.
echo   bh up              Start all containers ^(detached^)
echo   bh down            Stop all containers
echo   bh status          Show container status
echo   bh logs [service]  Tail logs ^(default: bloodhound^)
echo   bh password        Show initial admin password from logs
echo   bh reset           Stop and wipe all data volumes
echo   bh url             Print the UI URL
goto :eof
