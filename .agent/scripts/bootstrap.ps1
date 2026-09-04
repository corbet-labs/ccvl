param(
    [ValidateSet("plan", "install")]
    [string]$Mode = "plan"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$CacheRoot = if (Test-Path Env:CCVL_BOOTSTRAP_CACHE_ROOT) {
    $env:CCVL_BOOTSTRAP_CACHE_ROOT
}
else {
    Join-Path $RepoRoot ".agent\cache\ccvl"
}
$LocalBin = Join-Path $CacheRoot "bin"
$CargoHome = Join-Path $CacheRoot "cargo"
$RustupHome = Join-Path $CacheRoot "rustup"
$TargetDir = Join-Path $CacheRoot "target"
$Binary = Join-Path $LocalBin "ccvl.exe"
$InstallStamp = Join-Path $CacheRoot "install.sha256"
$ToolchainFile = Get-Content -Raw (Join-Path $RepoRoot "rust-toolchain.toml")
if ($ToolchainFile -notmatch '(?m)^\s*channel\s*=\s*"([^"]+)"') {
    throw "rust-toolchain.toml does not declare a Rust channel"
}
$RustVersion = $Matches[1]

function Get-PlatformKey {
    $Architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    switch ($Architecture) {
        "X64" { return "Windows-x86_64" }
        "Arm64" { return "Windows-aarch64" }
        default { throw "Unsupported Windows architecture: $Architecture" }
    }
}

function Get-CommandPath([string]$Name) {
    $Command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $Command) {
        return $null
    }
    return $Command.Source
}

function Test-RustVersion([string]$Output) {
    return $Output -eq "rustc $RustVersion" -or $Output.StartsWith("rustc $RustVersion ")
}

function Invoke-OutsideRepository([string]$Executable, [string[]]$Arguments) {
    Push-Location ([IO.Path]::GetTempPath())
    try {
        $Output = (& $Executable @Arguments 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return $Output
    }
    finally {
        Pop-Location
    }
}

function Invoke-ManagedRustup([string[]]$Arguments) {
    $Rustup = Join-Path $CargoHome "bin\rustup.exe"
    if (-not (Test-Path -LiteralPath $Rustup -PathType Leaf)) {
        return $null
    }
    $OldCargoHome = $env:CARGO_HOME
    $OldRustupHome = $env:RUSTUP_HOME
    try {
        $env:CARGO_HOME = $CargoHome
        $env:RUSTUP_HOME = $RustupHome
        return Invoke-OutsideRepository $Rustup $Arguments
    }
    finally {
        $env:CARGO_HOME = $OldCargoHome
        $env:RUSTUP_HOME = $OldRustupHome
    }
}

function Test-ManagedRust {
    $Rustc = Invoke-ManagedRustup @("run", $RustVersion, "rustc", "--version")
    if ($null -eq $Rustc -or -not (Test-RustVersion $Rustc)) {
        return $false
    }
    return $null -ne (Invoke-ManagedRustup @("run", $RustVersion, "cargo", "--version"))
}

function Get-SourceFingerprint {
    if ($env:CCVL_BOOTSTRAP_TESTING -eq "1") {
        if (Test-Path Env:CCVL_BOOTSTRAP_TEST_FINGERPRINT) {
            return $env:CCVL_BOOTSTRAP_TEST_FINGERPRINT
        }
        return "test-fingerprint"
    }
    $Files = @(
        Get-Item -LiteralPath (Join-Path $RepoRoot "Cargo.toml")
        Get-Item -LiteralPath (Join-Path $RepoRoot "Cargo.lock")
        Get-Item -LiteralPath (Join-Path $RepoRoot "rust-toolchain.toml")
        Get-ChildItem -LiteralPath (Join-Path $RepoRoot ".agent\src") -Recurse -File -Filter "*.rs" |
            Sort-Object FullName
    )
    $Lines = foreach ($File in $Files) {
        $Relative = $File.FullName.Substring($RepoRoot.Length + 1).Replace("\", "/")
        $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $File.FullName).Hash.ToLowerInvariant()
        "$Relative $Hash"
    }
    $Bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Lines -join "`n") + "`n")
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($Hasher.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $Hasher.Dispose()
    }
}

$Platform = Get-PlatformKey
$Assets = @(Import-Csv (Join-Path $PSScriptRoot "tool-assets.csv") |
    Where-Object { $_.tool -eq "rustup-init" -and $_.platform -eq $Platform })
if ($Assets.Count -ne 1) {
    throw "Incomplete rustup-init asset table for $Platform"
}
$Asset = $Assets[0]

$Fingerprint = Get-SourceFingerprint
$BinaryState = "install"
if ((Test-Path -LiteralPath $Binary -PathType Leaf) -and
    (Test-Path -LiteralPath $InstallStamp -PathType Leaf) -and
    ((Get-Content -Raw -LiteralPath $InstallStamp).Trim() -eq $Fingerprint)) {
    $BinaryState = "ready"
}

$SystemKind = "none"
$SystemCargo = $null
$SystemRustup = $null
if ($env:CCVL_BOOTSTRAP_FORCE_LOCAL -ne "1") {
    $CandidateRustup = Get-CommandPath "rustup"
    if ($null -ne $CandidateRustup) {
        $CandidateRustc = Invoke-OutsideRepository $CandidateRustup @("run", $RustVersion, "rustc", "--version")
        $CandidateCargo = Invoke-OutsideRepository $CandidateRustup @("run", $RustVersion, "cargo", "--version")
        if ($null -ne $CandidateRustc -and (Test-RustVersion $CandidateRustc) -and
            $null -ne $CandidateCargo) {
            $SystemKind = "rustup"
            $SystemRustup = $CandidateRustup
        }
    }
    if ($SystemKind -eq "none" -and $null -eq $CandidateRustup) {
        $CandidateRustcPath = Get-CommandPath "rustc"
        $CandidateCargoPath = Get-CommandPath "cargo"
        if ($null -ne $CandidateRustcPath -and $null -ne $CandidateCargoPath) {
            $CandidateRustc = Invoke-OutsideRepository $CandidateRustcPath @("--version")
            if ($null -ne $CandidateRustc -and (Test-RustVersion $CandidateRustc)) {
                $SystemKind = "standalone"
                $SystemCargo = $CandidateCargoPath
            }
        }
    }
}

$ToolchainState = "install"
if (Test-ManagedRust) {
    $ToolchainState = "managed"
}
elseif ($SystemKind -ne "none") {
    $ToolchainState = "system"
}

Write-Output "ccvl bootstrap plan"
Write-Output "  platform: $Platform"
switch ($ToolchainState) {
    "managed" { Write-Output "  Rust toolchain: managed $RustVersion" }
    "system" { Write-Output "  Rust toolchain: system $RustVersion" }
    default {
        Write-Output "  Rust toolchain: install $RustVersion with pinned rustup-init $($Asset.version)"
    }
}
Write-Output "  ccvl binary: $BinaryState"
Write-Output "  missing bootstrap commands: none"
Write-Output "  host packages: none"
if ($BinaryState -eq "ready") {
    Write-Output "No ccvl build changes required."
}

if ($Mode -eq "plan") {
    Write-Output "No changes made. Run .\ccvl.cmd setup to execute this plan."
    return
}

$TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "ccvl-bootstrap-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
try {
    if ($ToolchainState -eq "install") {
        New-Item -ItemType Directory -Force -Path $CargoHome, $RustupHome | Out-Null
        $Download = Join-Path $TemporaryRoot $Asset.asset
        Write-Output "Downloading pinned rustup-init $($Asset.version)"
        Invoke-WebRequest -UseBasicParsing -Uri $Asset.url -OutFile $Download
        $ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Download).Hash.ToLowerInvariant()
        if ($ActualHash -ne $Asset.sha256) {
            throw "Checksum mismatch for $($Asset.asset)"
        }
        Unblock-File -LiteralPath $Download
        $OldCargoHome = $env:CARGO_HOME
        $OldRustupHome = $env:RUSTUP_HOME
        try {
            $env:CARGO_HOME = $CargoHome
            $env:RUSTUP_HOME = $RustupHome
            & $Download -y --no-modify-path --profile minimal --default-toolchain $RustVersion
            if ($LASTEXITCODE -ne 0) {
                throw "rustup-init failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            $env:CARGO_HOME = $OldCargoHome
            $env:RUSTUP_HOME = $OldRustupHome
        }
        if (-not (Test-ManagedRust)) {
            throw "Managed Rust $RustVersion is unavailable after installation"
        }
        $ToolchainState = "managed"
    }

    if ($BinaryState -eq "install") {
        New-Item -ItemType Directory -Force -Path $CacheRoot, $CargoHome, $TargetDir | Out-Null
        $CargoArguments = @(
            "install", "--locked", "--force", "--path", $RepoRoot, "--root", $CacheRoot
        )
        $OldCargoHome = $env:CARGO_HOME
        $OldRustupHome = $env:RUSTUP_HOME
        $OldTargetDir = $env:CARGO_TARGET_DIR
        try {
            $env:CARGO_HOME = $CargoHome
            $env:CARGO_TARGET_DIR = $TargetDir
            Push-Location $TemporaryRoot
            try {
                switch ($ToolchainState) {
                    "managed" {
                        $env:RUSTUP_HOME = $RustupHome
                        $Rustup = Join-Path $CargoHome "bin\rustup.exe"
                        & $Rustup run $RustVersion cargo @CargoArguments
                    }
                    "system" {
                        if ($SystemKind -eq "rustup") {
                            & $SystemRustup run $RustVersion cargo @CargoArguments
                        }
                        else {
                            & $SystemCargo @CargoArguments
                        }
                    }
                }
                if ($LASTEXITCODE -ne 0) {
                    throw "cargo install failed with exit code $LASTEXITCODE"
                }
            }
            finally {
                Pop-Location
            }
        }
        finally {
            $env:CARGO_HOME = $OldCargoHome
            $env:RUSTUP_HOME = $OldRustupHome
            $env:CARGO_TARGET_DIR = $OldTargetDir
        }
        if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) {
            throw "cargo install did not produce $Binary"
        }
        $Fingerprint = Get-SourceFingerprint
        [IO.File]::WriteAllText(
            $InstallStamp,
            "$Fingerprint`n",
            [Text.UTF8Encoding]::new($false)
        )
    }

    Push-Location $RepoRoot
    try {
        & $Binary setup
        if ($LASTEXITCODE -ne 0) {
            throw "ccvl setup verification failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        [IO.Directory]::Delete($TemporaryRoot, $true)
    }
}
Write-Output "Setup complete. The repository-local binary is $Binary."
