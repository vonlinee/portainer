param(
  [string]$EnvName = $(if ($env:ENV) { $env:ENV } else { "production" }),
  [string]$Platform = $(if ($env:PLATFORM) { $env:PLATFORM } else { "windows" }),
  [string]$Arch = $(if ($env:ARCH) { $env:ARCH } else { "amd64" }),
  [string]$OutputDir,
  [string]$SkipGoGet = $(if ($env:SKIP_GO_GET) { $env:SKIP_GO_GET } else { "true" }),
  [switch]$KeepBuildWorkDir
)

$ErrorActionPreference = "Stop"

function Write-Info {
  param([string]$Message)
  Write-Host "[package-embedded-assets] $Message"
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
$BuildWorkDir = Join-Path $ProjectRoot "dist\embedded-build-work"

if (-not $OutputDir) {
  $OutputDir = Join-Path $InvocationDir "package"
} else {
  $OutputDir = Resolve-InvocationPath $OutputDir
}

$BinaryName = if ($Platform -eq "windows") { "portainer.exe" } else { "portainer" }
Assert-PackageOutputAvailable -OutputDir $OutputDir -BinaryName $BinaryName

$packageCompleted = $false
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

  Write-Info "Preparing temporary embedded build workspace..."
  if (Test-Path $BuildWorkDir) {
    Remove-Item -Recurse -Force $BuildWorkDir
  }
  New-Item -ItemType Directory -Force -Path $BuildWorkDir | Out-Null

  Copy-Item "api" (Join-Path $BuildWorkDir "api") -Recurse
  Copy-Item "pkg" (Join-Path $BuildWorkDir "pkg") -Recurse
  Copy-Item "mustache-templates" (Join-Path $BuildWorkDir "mustache-templates") -Recurse
  Copy-Item "go.mod" (Join-Path $BuildWorkDir "go.mod")
  Copy-Item "go.sum" (Join-Path $BuildWorkDir "go.sum")

  $EmbeddedPublicDir = Join-Path $BuildWorkDir "api\embedded\public"
  if (Test-Path $EmbeddedPublicDir) {
    Remove-Item -Recurse -Force $EmbeddedPublicDir
  }
  New-Item -ItemType Directory -Force -Path $EmbeddedPublicDir | Out-Null
  Copy-Item "dist\public\*" $EmbeddedPublicDir -Recurse

  Write-Info "Building embedded server binary..."
  $env:SKIP_GO_GET = $SkipGoGet
  & (Join-Path $ScriptDir "build-server.ps1") -Platform $Platform -Arch $Arch -ProjectRoot $BuildWorkDir -SkipGoGet $SkipGoGet

  Write-Info "Creating package directory: $OutputDir"
  Reset-PackageOutputDirectory -OutputDir $OutputDir

  Copy-Item (Join-Path $BuildWorkDir "dist\$BinaryName") (Join-Path $OutputDir $BinaryName)
  Copy-Item (Join-Path $BuildWorkDir "dist\mustache-templates") (Join-Path $OutputDir "mustache-templates") -Recurse

  @"
Portainer embedded-assets standalone package

Contents:
  $BinaryName
  mustache-templates/

Frontend assets are embedded in the binary.

Run:
  .\$BinaryName --assets-mode embedded --data .\data
"@ | Set-Content -Encoding UTF8 (Join-Path $OutputDir "README.txt")

  Write-Info "Package complete: $OutputDir"
  $packageCompleted = $true
} finally {
  Pop-Location

  if ($packageCompleted -and -not $KeepBuildWorkDir -and (Test-Path $BuildWorkDir)) {
    Write-Info "Cleaning temporary embedded build workspace: $BuildWorkDir"
    Remove-Item -Recurse -Force $BuildWorkDir
  } elseif (-not $packageCompleted -and (Test-Path $BuildWorkDir)) {
    Write-Info "Keeping temporary embedded build workspace for troubleshooting: $BuildWorkDir"
  }
}
