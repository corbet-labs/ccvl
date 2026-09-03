param(
    [Parameter(Position = 0)]
    [string]$Command = "help",
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = $PSScriptRoot
$LocalBin = Join-Path $RepoRoot ".cache\ccvl\bin"
$PythonVersion = (Get-Content -Raw (Join-Path $RepoRoot ".python-version")).Trim()
$env:PATH = "$LocalBin;$env:PATH"
$env:UV_PROJECT_ENVIRONMENT = Join-Path $RepoRoot ".cache\ccvl\venv"
$env:UV_CACHE_DIR = Join-Path $RepoRoot ".cache\ccvl\uv-cache"
$env:UV_PYTHON_INSTALL_DIR = Join-Path $RepoRoot ".cache\ccvl\python"

function Show-Usage {
    @"
Usage: .\ccvl.cmd <command> [arguments]

  setup                              Install pinned local tools and verify ccvl
  bootstrap                          Show the setup plan without changing anything
  doctor                             Report and verify the managed toolchain
  check                              Run all deterministic checks
  profile-status [station-plan]      Check CV station coverage and MECE ownership
  measure [--all]                    Measure the general CV and cover letter
  measure-opportunity <organisation-key> <position-key>
                                     Measure one keyed opportunity
  public-check                       Run checks required before publication
  build                              Build the general CV and cover letter
  new-opportunity <organisation-key> <position-key>
                                     Create one keyed opportunity from the template
  build-cv <locale> [pages]          Build one CV (default: four pages)
  build-cl <locale>                  Build one cover letter
  build-opportunity <organisation-key> <position-key>
                                     Build one keyed opportunity package
  help                               Show this help
"@
}

function Invoke-UvPython([string]$Script, [string[]]$ScriptArguments = @()) {
    $Uv = Get-Command uv -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $Uv) {
        throw "uv is not available. Run .\ccvl.cmd setup first."
    }
    Push-Location $RepoRoot
    try {
        & $Uv.Source run --frozen --no-dev --python $PythonVersion python $Script @ScriptArguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Script failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

switch ($Command.ToLowerInvariant()) {
    "setup" {
        & (Join-Path $RepoRoot "scripts\bootstrap.ps1") install
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Invoke-UvPython (Join-Path $RepoRoot "scripts\check.py")
    }
    "bootstrap" {
        & (Join-Path $RepoRoot "scripts\bootstrap.ps1") plan
    }
    "doctor" { Invoke-UvPython (Join-Path $RepoRoot "scripts\doctor.py") }
    "check" { Invoke-UvPython (Join-Path $RepoRoot "scripts\check.py") }
    "profile-status" { Invoke-UvPython (Join-Path $RepoRoot "scripts\station_plan.py") $Arguments }
    "measure" { Invoke-UvPython (Join-Path $RepoRoot "scripts\line_metrics.py") $Arguments }
    "measure-opportunity" {
        if ($Arguments.Count -ne 2) { throw (Show-Usage) }
        Invoke-UvPython (Join-Path $RepoRoot "scripts\line_metrics.py") @(
            "--opportunity", $Arguments[0], $Arguments[1]
        )
    }
    "public-check" { Invoke-UvPython (Join-Path $RepoRoot "scripts\public_check.py") }
    "build" { Invoke-UvPython (Join-Path $RepoRoot "scripts\render.py") @("general") }
    "new-opportunity" {
        if ($Arguments.Count -ne 2) { throw (Show-Usage) }
        Invoke-UvPython (Join-Path $RepoRoot "scripts\opportunity.py") @($Arguments[0], $Arguments[1])
    }
    "build-cv" {
        if ($Arguments.Count -lt 1 -or $Arguments.Count -gt 2) { throw (Show-Usage) }
        $Pages = if ($Arguments.Count -eq 2) { $Arguments[1] } else { "4" }
        Invoke-UvPython (Join-Path $RepoRoot "scripts\render.py") @("cv", $Arguments[0], $Pages)
    }
    "build-cl" {
        if ($Arguments.Count -ne 1) { throw (Show-Usage) }
        Invoke-UvPython (Join-Path $RepoRoot "scripts\render.py") @("cl", $Arguments[0])
    }
    "build-opportunity" {
        if ($Arguments.Count -ne 2) { throw (Show-Usage) }
        Invoke-UvPython (Join-Path $RepoRoot "scripts\render.py") @(
            "opportunity", $Arguments[0], $Arguments[1]
        )
    }
    { $_ -in @("help", "-h", "--help") } { Show-Usage }
    default { throw "Unknown command: $Command`n`n$(Show-Usage)" }
}
