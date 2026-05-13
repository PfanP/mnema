# Mnema Windows Installer
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1
# Or with a custom port: $env:MNEMA_PORT=5858; powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$InstallDir = "$env:USERPROFILE\.mnema"
$ComposeFile = "$InstallDir\docker-compose.yml"
$EnvFile = "$InstallDir\.env"
$Image = "mnemaai/mnema:latest"
$MongoImage = "mongodb/mongodb-atlas-local:8"
$MnemaPort = if ($env:MNEMA_PORT) { $env:MNEMA_PORT } else { "5757" }

function Write-Info  { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "Warning: $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "Error: $msg" -ForegroundColor Red }

function Exit-WithTroubleshooting {
  param($code)
  if ($code -ne 0) {
    Write-Host ""
    Write-Err "Installation failed (exit code $code)."
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  - Is Docker Desktop running?"
    Write-Host "  - Is port $MnemaPort available? Run: netstat -ano | findstr :$MnemaPort"
    Write-Host "  - Check logs: docker compose -f `"$ComposeFile`" logs"
    Write-Host ""
    Write-Host "To retry, re-run this script."
  }
}

Write-Info "Checking prerequisites..."

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Err "Docker is required but not installed."
  Write-Host "  Install Docker Desktop from: https://docs.docker.com/desktop/install/windows-install/"
  exit 1
}

$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Err "Docker is installed but not running."
  Write-Host "  Start Docker Desktop and try again."
  exit 1
}

$composeVersion = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Err "Docker Compose (v2) is required but not found."
  Write-Host "  It ships with Docker Desktop - ensure your installation is up to date."
  exit 1
}

$portInUse = netstat -ano 2>$null | Select-String ":$MnemaPort " | Where-Object { $_ -match "LISTENING" }
if ($portInUse) {
  Write-Err "Port $MnemaPort is already in use."
  Write-Host "  Either free the port or set a custom port before running:"
  Write-Host "  `$env:MNEMA_PORT=5858; powershell -ExecutionPolicy Bypass -File install.ps1"
  exit 1
}

if (Test-Path $ComposeFile) {
  Write-Warn "Existing installation found at $InstallDir"
  $reply = Read-Host "  Overwrite and reinstall? [y/N]"
  if ($reply -notmatch '^[Yy]') {
    Write-Host "Aborted."
    exit 0
  }
  Write-Info "Stopping existing containers..."
  docker compose -f "$ComposeFile" down 2>$null
}

Write-Info "Installing Mnema..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# --- Generate Mongo credentials ---
# PowerShell equivalent of openssl rand: use RNGCryptoServiceProvider for secure random
$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
$bytes = New-Object byte[] 32
$rng.GetBytes($bytes)
$MongoPass = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
$rng.Dispose()

$MongoUser = "mnema"

# Write .env with restricted permissions
@"
MONGO_INITDB_ROOT_USERNAME=$MongoUser
MONGO_INITDB_ROOT_PASSWORD=$MongoPass
MNEMA_PORT=$MnemaPort
"@ | Set-Content -Path $EnvFile -Encoding UTF8

# Restrict .env to current user only
$acl = Get-Acl $EnvFile
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
  [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
  "FullControl",
  "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl $EnvFile $acl

# --- Docker volume paths on Windows ---
# Docker Desktop expects forward-slash paths for bind mounts.
# Convert Windows path: C:\Users\name\.mnema -> /c/Users/name/.mnema
$InstallDirDocker = $InstallDir -replace '\\', '/' -replace '^([A-Za-z]):', { '/' + $args[0].Groups[1].Value.ToLower() }

# --- Write docker-compose.yml ---
@"
services:
  mongo:
    image: $MongoImage
    restart: unless-stopped
    environment:
      MONGODB_INITDB_ROOT_USERNAME: `${MONGO_INITDB_ROOT_USERNAME}
      MONGODB_INITDB_ROOT_PASSWORD: `${MONGO_INITDB_ROOT_PASSWORD}
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - internal
    volumes:
      - mongo_data:/data/db

  mnema:
    image: $Image
    restart: unless-stopped
    ports:
      - "`${MNEMA_PORT:-5757}:5757"
    volumes:
      - $InstallDirDocker/config:/app/config
      - $InstallDirDocker:/app/.mnema
    environment:
      CONFIG_PATH: /app/config/bootstrap.toml
      MNEMA_HOME: /app/.mnema
      MONGODB_URI: mongodb://`${MONGO_INITDB_ROOT_USERNAME}:`${MONGO_INITDB_ROOT_PASSWORD}@mongo:27017/?directConnection=true&authSource=admin
    depends_on:
      mongo:
        condition: service_healthy
    networks:
      - internal
      - external

networks:
  internal:
    internal: true
  external:

volumes:
  mongo_data:
"@ | Set-Content -Path $ComposeFile -Encoding UTF8

Write-Info "Pulling latest image..."
docker pull $Image
if ($LASTEXITCODE -ne 0) {
  Write-Err "Failed to pull image: $Image"
  Write-Host "  Check your internet connection and that the image name is correct."
  Exit-WithTroubleshooting 1
  exit 1
}

Write-Info "Starting Mnema..."
docker compose -f "$ComposeFile" --env-file "$EnvFile" up -d
if ($LASTEXITCODE -ne 0) {
  Write-Err "Failed to start containers."
  Write-Host "  Check logs with: docker compose -f `"$ComposeFile`" logs"
  Exit-WithTroubleshooting 1
  exit 1
}

Write-Info "Waiting for Mnema to be ready..."
$attempts = 0
$maxAttempts = 30
$ready = $false

while ($attempts -lt $maxAttempts) {
  try {
    $response = Invoke-WebRequest -Uri "http://localhost:$MnemaPort/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
      $ready = $true
      break
    }
  } catch {
    # Not ready yet
  }
  $attempts++
  Start-Sleep -Seconds 2
}

if (-not $ready) {
  Write-Warn "Mnema started but did not become healthy within 60 seconds."
  Write-Host "  Check logs: docker compose -f `"$ComposeFile`" logs mnema"
  Write-Host "  It may still be initializing. Try opening http://localhost:$MnemaPort in a moment."
} else {
  Write-Info "Mnema is ready!"
}

$tokenLine = docker compose -f "$ComposeFile" logs mnema 2>$null |
  Select-String "API token:" |
  Select-Object -Last 1

Write-Host ""
Write-Host ("=" * 62)
Write-Host "  Mnema is running at http://localhost:$MnemaPort"
Write-Host ""
Write-Host "  Your API token:"
if ($tokenLine) {
  Write-Host "  $($tokenLine.Line.Trim())"
} else {
  Write-Host "  (check logs: docker compose -f `"$ComposeFile`" logs mnema)"
}
Write-Host ""
Write-Host "  Open http://localhost:$MnemaPort/onboarding to get started."
Write-Host ("=" * 62)
Write-Host ""