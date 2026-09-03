param(
    [ValidateSet("plan", "install")]
    [string]$Mode = "plan"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$LocalBin = Join-Path $RepoRoot ".cache\ccvl\bin"
$PythonVersion = (Get-Content -Raw (Join-Path $RepoRoot ".python-version")).Trim()
$Pyproject = Get-Content -Raw (Join-Path $RepoRoot "pyproject.toml")
if ($Pyproject -notmatch '"pypdf==([^"\r\n]+)"') {
    throw "pyproject.toml does not pin pypdf"
}
$PypdfVersion = $Matches[1]
$env:PATH = "$LocalBin;$env:PATH"
$env:UV_PROJECT_ENVIRONMENT = Join-Path $RepoRoot ".cache\ccvl\venv"
$env:UV_CACHE_DIR = Join-Path $RepoRoot ".cache\ccvl\uv-cache"
$env:UV_PYTHON_INSTALL_DIR = Join-Path $RepoRoot ".cache\ccvl\python"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-PlatformKey {
    $Architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    switch ($Architecture) {
        "X64" { return "Windows-x86_64" }
        "Arm64" { return "Windows-aarch64" }
        default { throw "Unsupported Windows architecture: $Architecture" }
    }
}

function Get-ToolPath([string]$Tool) {
    $LocalPath = Join-Path $LocalBin "$Tool.exe"
    if (Test-Path -LiteralPath $LocalPath -PathType Leaf) {
        return $LocalPath
    }
    if ($env:CCVL_BOOTSTRAP_FORCE_LOCAL -eq "1") {
        return $null
    }
    $Command = Get-Command $Tool -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $Command) {
        return $Command.Source
    }
    return $null
}

function Test-ToolVersion([string]$Tool, [string]$Expected) {
    $Path = Get-ToolPath $Tool
    if ($null -eq $Path) {
        return $false
    }
    $Output = (& $Path --version 2>&1 | Out-String)
    return $LASTEXITCODE -eq 0 -and $Output.Contains($Expected)
}

function Install-Tool($Asset, [string]$TemporaryRoot) {
    $Download = Join-Path $TemporaryRoot $Asset.asset
    Write-Host "Downloading pinned $($Asset.tool) $($Asset.version)"
    Invoke-WebRequest -UseBasicParsing -Uri $Asset.url -OutFile $Download
    $ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Download).Hash.ToLowerInvariant()
    if ($ActualHash -ne $Asset.sha256) {
        throw "Checksum mismatch for $($Asset.asset)"
    }

    $Destination = Join-Path $LocalBin "$($Asset.tool).exe"
    if ($Asset.kind -eq "file") {
        Copy-Item -LiteralPath $Download -Destination $Destination -Force
    }
    elseif ($Asset.kind -eq "archive" -and $Asset.asset.EndsWith(".zip")) {
        $Extracted = Join-Path $TemporaryRoot $Asset.tool
        Expand-Archive -LiteralPath $Download -DestinationPath $Extracted -Force
        $Candidate = Get-ChildItem -Path $Extracted -Recurse -File -Filter "$($Asset.tool).exe" |
            Select-Object -First 1
        if ($null -eq $Candidate) {
            throw "$($Asset.tool).exe was not found in $($Asset.asset)"
        }
        Copy-Item -LiteralPath $Candidate.FullName -Destination $Destination -Force
    }
    else {
        throw "Unsupported Windows asset format: $($Asset.asset)"
    }
    Unblock-File -LiteralPath $Destination
}

$Platform = Get-PlatformKey
$Assets = Import-Csv (Join-Path $PSScriptRoot "tool-assets.csv") |
    Where-Object { $_.platform -eq $Platform }
$ExpectedTools = @("typst", "typstyle", "uv")
if (@($Assets).Count -ne $ExpectedTools.Count) {
    throw "Incomplete tool asset table for $Platform"
}

$Missing = @()
foreach ($Tool in $ExpectedTools) {
    $Asset = $Assets | Where-Object { $_.tool -eq $Tool }
    $ExpectedVersion = switch ($Tool) {
        "typst" { "typst $($Asset.version)" }
        "uv" { "uv $($Asset.version)" }
        default { $Asset.version }
    }
    if (-not (Test-ToolVersion $Tool $ExpectedVersion)) {
        $Missing += $Tool
    }
}

Write-Host "ccvl bootstrap plan"
Write-Host "  platform: $Platform"
Write-Host "  pinned local tools: $(if ($Missing.Count) { $Missing -join ' ' } else { 'none' })"
$RuntimeState = "synchronize"
$RuntimePython = Join-Path $env:UV_PROJECT_ENVIRONMENT "Scripts\python.exe"
if (Test-Path -LiteralPath $RuntimePython -PathType Leaf) {
    & $RuntimePython -c "import platform,pypdf,sys;sys.exit(platform.python_version()!=sys.argv[1] or pypdf.__version__!=sys.argv[2])" $PythonVersion $PypdfVersion
    if ($LASTEXITCODE -eq 0) { $RuntimeState = "ready" }
}
Write-Host "  managed runtime: $RuntimeState (Python $PythonVersion with frozen uv.lock)"
Write-Host "  host packages: none"

if ($Mode -eq "plan") {
    Write-Host "No changes made. Run .\ccvl.cmd setup to execute this plan."
    return
}

New-Item -ItemType Directory -Force -Path $LocalBin | Out-Null
$TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "ccvl-bootstrap-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
try {
    foreach ($Tool in $Missing) {
        $Asset = $Assets | Where-Object { $_.tool -eq $Tool }
        Install-Tool $Asset $TemporaryRoot
    }
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        [IO.Directory]::Delete($TemporaryRoot, $true)
    }
}

$UvPath = Get-ToolPath "uv"
if ($null -eq $UvPath) {
    throw "uv is unavailable after bootstrap"
}
Push-Location $RepoRoot
try {
    & $UvPath sync --frozen --no-dev --python $PythonVersion
    if ($LASTEXITCODE -ne 0) { throw "uv sync failed" }
    & $UvPath run --frozen --no-dev --python $PythonVersion python (Join-Path $PSScriptRoot "doctor.py")
    if ($LASTEXITCODE -ne 0) { throw "ccvl doctor failed" }
}
finally {
    Pop-Location
}
Write-Host "Bootstrap complete. Managed runtime ready; downloaded assets remain below .cache/ccvl/."
