<#
.SYNOPSIS
  bh.ps1 - BloodHound CE quick launcher (Windows / PowerShell port of `bh`)
.DESCRIPTION
  Orchestrates the BloodHound CE docker-compose stack on Windows 11.
  Requires Docker Desktop (or Docker Engine + compose v2) running.
.EXAMPLE
  .\bh.ps1 up
  .\bh.ps1 password
#>

$ErrorActionPreference = 'Stop'

# Resolve the directory this script lives in (so docker-compose.yml is found next to it)
$BH_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$COMPOSE_FILE = Join-Path $BH_DIR 'docker-compose.yml'

# No 'sudo' on Windows — Docker Desktop runs the daemon for the logged-in user.
# Just verify the daemon is reachable.
function Test-Docker {
    try { docker info *> $null; return $true } catch { return $false }
}

# IMPORTANT: Do not call this as `Invoke-Compose down -v`.
# PowerShell binds -v to -Verbose and silently drops it, so volumes never get deleted.
function Invoke-Compose {
    param([Parameter(Mandatory = $true)][string[]]$ComposeArgs)
    & docker compose -f $COMPOSE_FILE @ComposeArgs
}

$cmd = if ($args.Count -ge 1) { $args[0] } else { 'help' }

if ($cmd -notin @('help', 'url') -and -not (Test-Docker)) {
    Write-Host '[-] Docker is not running. Start Docker Desktop and try again.' -ForegroundColor Red
    exit 1
}

switch ($cmd) {
    'up' {
        Write-Host '[*] Starting BloodHound CE...' -ForegroundColor Cyan
        Invoke-Compose -ComposeArgs @('up', '-d')
        Write-Host '[+] BloodHound UI: http://localhost:8080' -ForegroundColor Green
        Write-Host '[*] First run? Get the initial password with: .\bh.ps1 password'
    }
    'down' {
        Write-Host '[*] Stopping BloodHound CE...' -ForegroundColor Cyan
        Invoke-Compose -ComposeArgs @('down')
        Write-Host '[+] Stopped.' -ForegroundColor Green
    }
    'status' {
        Invoke-Compose -ComposeArgs @('ps')
    }
    'logs' {
        $service = if ($args.Count -ge 2) { $args[1] } else { 'bloodhound' }
        Invoke-Compose -ComposeArgs @('logs', '-f', '--tail=100', $service)
    }
    'password' {
        Write-Host '[*] Searching for initial admin password in logs...' -ForegroundColor Cyan
        $hit = (Invoke-Compose -ComposeArgs @('logs', 'bloodhound') 2>&1) |
            Select-String -Pattern 'Initial Password Set To|initial password' -CaseSensitive:$false
        if ($hit) { $hit } else {
            Write-Host "[-] No initial password found. Either already changed or containers haven't started yet."
            Write-Host '[*] Tip: run bh reset (fixed to actually wipe volumes), then bh up, wait ~30s, then bh password.'
        }
    }
    'reset' {
        $ans = Read-Host '[!] This will DELETE all BloodHound data (graph + DB). Continue? [y/N]'
        if ($ans.ToLower() -eq 'y') {
            Invoke-Compose -ComposeArgs @('down', '--volumes')
            # Also remove by name in case compose project binding left them behind
            docker volume rm bh_postgres-data bh_neo4j-data 2>$null | Out-Null
            Write-Host "[+] Volumes removed. Run '.\bh.ps1 up' for a fresh instance." -ForegroundColor Green
        } else {
            Write-Host '[*] Aborted.'
        }
    }
    'url' {
        Write-Output 'http://localhost:8080'
    }
    default {
        @'
BloodHound CE Manager (Windows / PowerShell)

  .\bh.ps1 up              Start all containers (detached)
  .\bh.ps1 down            Stop all containers
  .\bh.ps1 status          Show container status
  .\bh.ps1 logs [service]  Tail logs (default: bloodhound)
  .\bh.ps1 password        Show initial admin password from logs
  .\bh.ps1 reset           Stop and wipe all data volumes
  .\bh.ps1 url             Print the UI URL
'@ | Write-Output
    }
}
