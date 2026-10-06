[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('ana', 'open', IgnoreCase = $false)]
    [string] $Edition
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script = Join-Path $root 'installer\windows\swiftie-quiz.nsi'
$source = Join-Path $root 'build\windows\x64\runner\Release'
$outDir = Join-Path $root 'build\release'
$productName = if ($Edition -eq 'open') { 'Project Swiftie Open' } else { 'Project Swiftie' }
$setup = Join-Path $outDir "${productName}_${Version}_x64-setup.exe"

if (-not (Test-Path -LiteralPath (Join-Path $source 'swiftie-quiz.exe'))) {
    throw "swiftie-quiz.exe is missing from $source; run flutter build windows --release first"
}

$makensis = Get-Command makensis -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source
if (-not $makensis) {
    $makensis = @(
        (Join-Path ${env:ProgramFiles(x86)} 'NSIS\makensis.exe'),
        (Join-Path $env:ProgramFiles 'NSIS\makensis.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $makensis) {
    throw 'makensis was not found; install NSIS 3 with choco install nsis -y'
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
& $makensis "/DSOURCE_DIR=$source" "/DVERSION=$Version" "/DEDITION=$Edition" "/DOUTFILE=$setup" $script
if ($LASTEXITCODE -ne 0) {
    throw "makensis failed with exit code $LASTEXITCODE"
}

Write-Output $setup
