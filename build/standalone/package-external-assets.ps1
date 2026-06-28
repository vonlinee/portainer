param(
  [string]$EnvName = $(if ($env:ENV) { $env:ENV } else { "production" }),
  [string]$Platform = $(if ($env:PLATFORM) { $env:PLATFORM } else { "windows" }),
  [string]$Arch = $(if ($env:ARCH) { $env:ARCH } else { "amd64" }),
  [string]$OutputDir,
  [string]$SkipGoGet = $(if ($env:SKIP_GO_GET) { $env:SKIP_GO_GET } else { "true" })
)

$ErrorActionPreference = "Stop"

function Write-Info {
  param([string]$Message)
  Write-Host "[package-external-assets] $Message"
}

function Invoke-Native {
  param(
    [scriptblock]$Command,
    [string]$Description
  )

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $global:LASTEXITCODE = 0
    $ErrorActionPreference = "Continue"
    & $Command
    if ($LASTEXITCODE -ne 0) {
      throw "$Description failed with exit code $LASTEXITCODE"
    }
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

function Resolve-InvocationPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }

  return Join-Path $InvocationDir $Path
}

function Assert-PackageOutputAvailable {
  param(
    [string]$OutputDir,
    [string]$BinaryName
  )

  $binaryPath = Join-Path $OutputDir $BinaryName
  if (-not (Test-Path $binaryPath)) {
    return
  }

  try {
    $stream = [System.IO.File]::Open($binaryPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $stream.Dispose()
  } catch {
    throw "Cannot overwrite package output because '$binaryPath' is locked by another process. Stop the running Portainer process or pass -OutputDir to use a different package directory. Original error: $($_.Exception.Message)"
  }
}

function Reset-PackageOutputDirectory {
  param([string]$OutputDir)

  if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    return
  }

  try {
    Remove-Item -Recurse -Force $OutputDir
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
  } catch {
    throw "Cannot recreate package output directory '$OutputDir'. Stop any running Portainer process using files under this directory, or pass -OutputDir to use a different package directory. Original error: $($_.Exception.Message)"
  }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../..")
$InvocationDir = Get-Location

if (-not $OutputDir) {
  $OutputDir = Join-Path $InvocationDir "package"
} else {
  $OutputDir = Resolve-InvocationPath $OutputDir
}

$BinaryName = if ($Platform -eq "windows") { "portainer.exe" } else { "portainer" }
Assert-PackageOutputAvailable -OutputDir $OutputDir -BinaryName $BinaryName

Push-Location $ProjectRoot
try {
  Write-Info "Building frontend assets..."
  $env:NODE_ENV = $EnvName
  $previousCI = $env:CI
  try {
    $env:CI = "true"
    Invoke-Native -Description "Frontend build" -Command {
      pnpm run build --config "webpack/webpack.$EnvName.js"
    }
  } finally {
    if ($null -eq $previousCI) {
      Remove-Item Env:\CI -ErrorAction SilentlyContinue
    } else {
      $env:CI = $previousCI
    }
  }

  Write-Info "Building server binary..."
  $env:SKIP_GO_GET = $SkipGoGet
  & .\build\standalone\build-server.ps1 -Platform $Platform -Arch $Arch -SkipGoGet $SkipGoGet

  Write-Info "Creating package directory: $OutputDir"
  Reset-PackageOutputDirectory -OutputDir $OutputDir

  Copy-Item "dist\$BinaryName" (Join-Path $OutputDir $BinaryName)
  Copy-Item "dist\public" (Join-Path $OutputDir "public") -Recurse
  Copy-Item "dist\mustache-templates" (Join-Path $OutputDir "mustache-templates") -Recurse

  @"
Portainer external-assets standalone package

Contents:
  $BinaryName
  public/
  mustache-templates/

Run:
  .\$BinaryName --assets . --data .\data
"@ | Set-Content -Encoding UTF8 (Join-Path $OutputDir "README.txt")

  Write-Info "Package complete: $OutputDir"
} finally {
  Pop-Location
}
