param(
  [string]$DataPath,
  [string]$AssetsPath,
  [string]$Bind = ":9000",
  [string]$BindHttps = ":9443",
  [string]$TunnelPort = "8000",
  [string]$HostUrl = "",
  [switch]$Build,
  [switch]$EnableSetupToken,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"

function Write-Info {
  param([string]$Message)
  Write-Host "[local-server] $Message"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")

if (-not $DataPath) {
  $LocalAppData = [Environment]::GetFolderPath("LocalApplicationData")
  if (-not $LocalAppData) {
    $LocalAppData = Join-Path $env:USERPROFILE "AppData\Local"
  }

  $DataPath = Join-Path $LocalAppData "PortainerCE\data"
}

if (-not $AssetsPath) {
  $AssetsPath = Join-Path $ProjectRoot "dist"
}

$DistPublicPath = Join-Path $AssetsPath "public"
Write-Info "Preparing local Portainer server environment..."
New-Item -ItemType Directory -Force -Path $DataPath | Out-Null
New-Item -ItemType Directory -Force -Path $DistPublicPath | Out-Null

$serverArgs = @(
  "--data", $DataPath,
  "--assets", $AssetsPath,
  "--bind", $Bind,
  "--bind-https", $BindHttps,
  "--tunnel-port", $TunnelPort
)

if (-not $EnableSetupToken) {
  $serverArgs += "--no-setup-token"
}

if ($HostUrl) {
  $serverArgs += @("--host", $HostUrl)
}

if ($ExtraArgs) {
  $serverArgs += $ExtraArgs
}

Write-Info "Project root: $ProjectRoot"
Write-Info "Data path: $DataPath"
Write-Info "Assets path: $AssetsPath"
Write-Info "HTTP bind address: $Bind"
Write-Info "HTTPS bind address: $BindHttps"
Write-Info "Tunnel port: $TunnelPort"
Write-Info "CSP environment value: false"
Write-Info "Build before start: $Build"
Write-Info "Setup token enabled: $EnableSetupToken"

if ($HostUrl) {
  Write-Info "Environment host URL: $HostUrl"
} else {
  Write-Info "Environment host URL: not configured"
}

if ($ExtraArgs) {
  Write-Info "Extra Portainer arguments: $($ExtraArgs -join ' ')"
}

Push-Location $ProjectRoot
try {
  $env:CSP = "false"

  if ($Build) {
    $BinaryPath = Join-Path $ProjectRoot "dist\portainer.exe"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BinaryPath) | Out-Null
    Write-Info "Building Portainer server binary..."
    go build -o $BinaryPath .\api\cmd\portainer
    Write-Info "Starting Portainer server from binary: $BinaryPath"
    & $BinaryPath @serverArgs
  } else {
    Write-Info "Starting Portainer server with go run..."
    go run .\api\cmd\portainer @serverArgs
  }
} finally {
  Pop-Location
}
