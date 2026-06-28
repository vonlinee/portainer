param(
  [string]$PackageDir,
  [string]$InstallDir,
  [string]$DataDir,
  [string]$LogsDir,
  [string]$EnvName = "production",
  [string]$Platform = "windows",
  [string]$Arch = "amd64",
  [string]$SkipGoGet = "true",
  [string]$Bind = $(if ($env:BIND) { $env:BIND } else { ":9000" }),
  [string]$BindHttps = $(if ($env:BIND_HTTPS) { $env:BIND_HTTPS } else { ":9443" }),
  [string]$TunnelPort = $(if ($env:TUNNEL_PORT) { $env:TUNNEL_PORT } else { "8000" }),
  [string]$HostUrl = $(if ($env:HOST_URL) { $env:HOST_URL } else { "" }),
  [string]$AdminPasswordFile,
  [string]$AdminPasswordHash,
  [switch]$EnableSetupToken,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"

function Write-Info {
  param([string]$Message)
  Write-Host "[deploy-external-assets] $Message"
}

function New-RandomPassword {
  $bytes = New-Object byte[] 24
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($bytes)
  } finally {
    $rng.Dispose()
  }

  return [Convert]::ToBase64String($bytes).TrimEnd("=")
}

function Write-PasswordFile {
  param(
    [string]$Path,
    [string]$Password
  )

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Password, $encoding)
}

function Resolve-InvocationPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }

  return Join-Path $InvocationDir $Path
}

function Get-NormalizedPath {
  param([string]$Path)

  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Assert-InstallDirSafe {
  param(
    [string]$InstallDir,
    [string]$ProjectRoot
  )

  if ((Get-NormalizedPath $InstallDir) -eq (Get-NormalizedPath $ProjectRoot)) {
    throw "InstallDir cannot be the source project root: $InstallDir. Choose a deployment directory, for example -InstallDir ..\portainer-runtime or run this script from the desired install directory."
  }
}

function Assert-BinaryPathAvailable {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return
  }

  try {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $stream.Dispose()
  } catch {
    throw "Cannot overwrite '$Path' because it is locked by another process. Stop the running Portainer process or choose a different directory. Original error: $($_.Exception.Message)"
  }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../..")
$InvocationDir = Get-Location

if (-not $InstallDir) {
  $InstallDir = $InvocationDir
} else {
  $InstallDir = Resolve-InvocationPath $InstallDir
}
if (-not $PackageDir) {
  $PackageDir = Join-Path $InstallDir "package"
} else {
  $PackageDir = Resolve-InvocationPath $PackageDir
}
if (-not $DataDir) {
  $DataDir = Join-Path $InstallDir "data"
} else {
  $DataDir = Resolve-InvocationPath $DataDir
}
if (-not $LogsDir) {
  $LogsDir = Join-Path $InstallDir "logs"
} else {
  $LogsDir = Resolve-InvocationPath $LogsDir
}

if ($AdminPasswordFile -and $AdminPasswordHash) {
  throw "Use only one of -AdminPasswordFile or -AdminPasswordHash."
}

Assert-InstallDirSafe -InstallDir $InstallDir -ProjectRoot $ProjectRoot

$ExpectedBinaryName = if ($Platform -eq "windows") { "portainer.exe" } else { "portainer" }
Assert-BinaryPathAvailable -Path (Join-Path $PackageDir $ExpectedBinaryName)
Assert-BinaryPathAvailable -Path (Join-Path $InstallDir $ExpectedBinaryName)

Write-Info "Packaging external-assets artifact..."
& (Join-Path $ScriptDir "package-external-assets.ps1") `
  -EnvName $EnvName `
  -Platform $Platform `
  -Arch $Arch `
  -OutputDir $PackageDir `
  -SkipGoGet $SkipGoGet

$BinaryName = if (Test-Path (Join-Path $PackageDir "portainer.exe")) { "portainer.exe" } else { "portainer" }
$PackageBinary = Join-Path $PackageDir $BinaryName
if (-not (Test-Path $PackageBinary)) {
  throw "Package binary not found: $PackageBinary. Packaging did not produce the expected binary."
}

$PackagePublic = Join-Path $PackageDir "public"
if (-not (Test-Path $PackagePublic)) {
  throw "Package public directory not found: $PackagePublic"
}

Write-Info "Installing package to: $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
Copy-Item $PackageBinary (Join-Path $InstallDir $BinaryName) -Force

$InstallPublic = Join-Path $InstallDir "public"
$InstallTemplates = Join-Path $InstallDir "mustache-templates"
if (Test-Path $InstallPublic) {
  Remove-Item -Recurse -Force $InstallPublic
}
if (Test-Path $InstallTemplates) {
  Remove-Item -Recurse -Force $InstallTemplates
}
Copy-Item $PackagePublic $InstallPublic -Recurse
$PackageTemplates = Join-Path $PackageDir "mustache-templates"
if (Test-Path $PackageTemplates) {
  Copy-Item $PackageTemplates $InstallTemplates -Recurse
}

if ($AdminPasswordFile -and -not [System.IO.Path]::IsPathRooted($AdminPasswordFile)) {
  $AdminPasswordFile = Join-Path $InvocationDir $AdminPasswordFile
}

if (-not $AdminPasswordFile -and -not $AdminPasswordHash -and -not $EnableSetupToken) {
  $AdminPasswordFile = Join-Path $InstallDir "admin-password.txt"
  if (-not (Test-Path $AdminPasswordFile)) {
    Write-PasswordFile -Path $AdminPasswordFile -Password (New-RandomPassword)
    Write-Info "Generated initial admin password file: $AdminPasswordFile"
  } else {
    Write-Info "Using existing initial admin password file: $AdminPasswordFile"
  }
  Write-Info "Initial administrator username: admin"
}

if ($AdminPasswordFile -and -not (Test-Path $AdminPasswordFile)) {
  throw "Admin password file not found: $AdminPasswordFile"
}

$ServerArgs = @(
  "--assets", $InstallDir,
  "--data", $DataDir,
  "--bind", $Bind,
  "--bind-https", $BindHttps,
  "--tunnel-port", $TunnelPort
)

if ($AdminPasswordFile) {
  $ServerArgs += @("--admin-password-file", $AdminPasswordFile)
} elseif ($AdminPasswordHash) {
  $ServerArgs += @("--admin-password", $AdminPasswordHash)
} elseif (-not $EnableSetupToken) {
  $ServerArgs += "--no-setup-token"
}
if ($HostUrl) {
  $ServerArgs += @("--host", $HostUrl)
}
if ($ExtraArgs) {
  $ServerArgs += $ExtraArgs
}

$BinaryPath = Join-Path $InstallDir $BinaryName
Write-Info "Starting Portainer external-assets deployment..."
Write-Info "HTTP bind address: $Bind"
Write-Info "HTTPS bind address: $BindHttps"
Write-Info "Logs directory: $LogsDir"
& $BinaryPath @ServerArgs
