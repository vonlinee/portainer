param(
  [string]$Platform = "windows",
  [string]$Arch = "amd64",
  [string]$ProjectRoot,
  [string]$SkipGoGet = $(if ($env:SKIP_GO_GET) { $env:SKIP_GO_GET } else { "true" })
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ProjectRoot) {
  $ProjectRoot = Resolve-Path $ProjectRoot
} else {
  $ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../..")
}

function Get-CommandOutputOrDefault {
  param(
    [scriptblock]$Command,
    [string]$DefaultValue = "N/A"
  )

  try {
    $value = & $Command
    if ($LASTEXITCODE -ne 0 -or -not $value) {
      return $DefaultValue
    }

    return ($value | Select-Object -First 1).ToString().Trim()
  } catch {
    return $DefaultValue
  }
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

Push-Location $ProjectRoot
try {
  New-Item -ItemType Directory -Force -Path "dist" | Out-Null

  $TemplatesDist = Join-Path $ProjectRoot "dist\mustache-templates"
  if (Test-Path $TemplatesDist) {
    Remove-Item -Recurse -Force $TemplatesDist
  }
  Copy-Item "mustache-templates" $TemplatesDist -Recurse

  if ($SkipGoGet -ne "true") {
    Push-Location (Join-Path $ProjectRoot "api")
    try {
      Invoke-Native -Description "Go dependency download" -Command {
        go get -t -v ./...
      }
    } finally {
      Pop-Location
    }
  }

  $BuildNumber = if ($env:BUILDNUMBER) { $env:BUILDNUMBER } else { "N/A" }
  $ContainerImageTag = if ($env:CONTAINER_IMAGE_TAG) { $env:CONTAINER_IMAGE_TAG } else { "N/A" }
  $NodeVersion = Get-CommandOutputOrDefault { node -v }
  $PnpmVersion = Get-CommandOutputOrDefault { pnpm -v }
  $WebpackVersion = Get-CommandOutputOrDefault {
    $line = pnpm list webpack --depth=0 | Select-String -Pattern "webpack" | Select-Object -First 1
    if ($line) {
      ($line.ToString() -split "\s+")[-1]
    }
  }
  $GoVersion = Get-CommandOutputOrDefault {
    ((go version) -split "\s+")[2]
  }
  $GitCommitHash = Get-CommandOutputOrDefault {
    git rev-parse --short HEAD
  }
  $DockerVersion = Get-CommandOutputOrDefault {
    go list -m -f "{{.Version}}" github.com/docker/docker
  }
  $ComposeVersion = Get-CommandOutputOrDefault {
    go list -m -f "{{.Version}}" github.com/docker/compose/v2
  }
  $KubectlVersion = Get-CommandOutputOrDefault {
    (go list -modfile go.mod -m -f "{{.Version}}" k8s.io/kubectl) -replace "^v0\.", "v1." -replace "^0\.", "1."
  }
  $HelmVersion = Get-CommandOutputOrDefault {
    go list -modfile go.mod -m -f "{{.Version}}" helm.sh/helm/v4
  }

  $LdFlags = @(
    "-s",
    "-X", "github.com/portainer/liblicense.LicenseServerBaseURL=https://api.portainer.io",
    "-X", "github.com/portainer/portainer/pkg/build.BuildNumber=$BuildNumber",
    "-X", "github.com/portainer/portainer/pkg/build.ImageTag=$ContainerImageTag",
    "-X", "github.com/portainer/portainer/pkg/build.NodejsVersion=$NodeVersion",
    "-X", "github.com/portainer/portainer/pkg/build.PnpmVersion=$PnpmVersion",
    "-X", "github.com/portainer/portainer/pkg/build.WebpackVersion=$WebpackVersion",
    "-X", "github.com/portainer/portainer/pkg/build.GitCommit=$GitCommitHash",
    "-X", "github.com/portainer/portainer/pkg/build.GoVersion=$GoVersion",
    "-X", "github.com/portainer/portainer/pkg/build.DepComposeVersion=$ComposeVersion",
    "-X", "github.com/portainer/portainer/pkg/build.DepDockerVersion=$DockerVersion",
    "-X", "github.com/portainer/portainer/pkg/build.DepKubectlVersion=$KubectlVersion",
    "-X", "github.com/portainer/portainer/pkg/build.DepHelmVersion=$HelmVersion"
  ) -join " "

  $BinaryName = if ($Platform -eq "windows") { "portainer.exe" } else { "portainer" }
  $OutputPath = Join-Path $ProjectRoot "dist\$BinaryName"

  $env:GOOS = $Platform
  $env:GOARCH = $Arch
  $env:CGO_ENABLED = "0"

  Invoke-Native -Description "Go build" -Command {
    go build `
      -trimpath `
      --installsuffix cgo `
      --ldflags $LdFlags `
      -o $OutputPath `
      ./api/cmd/portainer
  }
} finally {
  Pop-Location
}
