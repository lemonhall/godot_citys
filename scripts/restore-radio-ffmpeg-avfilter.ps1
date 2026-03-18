param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$archiveDir = Join-Path $repoRoot 'city_game\native\radio_backend\thirdparty\ffmpeg\archives'
$archivePart = Join-Path $archiveDir 'avfilter-11.dll.7z.001'
$stagingDir = Join-Path $archiveDir '_extract_avfilter_tmp'
$targets = @(
    (Join-Path $repoRoot 'city_game\native\radio_backend\bin\win64\avfilter-11.dll'),
    (Join-Path $repoRoot 'city_game\native\radio_backend\thirdparty\ffmpeg\windows-x64-shared\ffmpeg-8.1-full_build-shared\bin\avfilter-11.dll')
)

if (-not (Test-Path $archivePart)) {
    throw "Missing split archive part: $archivePart"
}

$sevenZip = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
if (-not $sevenZip) {
    throw '7z.exe was not found in PATH.'
}

if (Test-Path $stagingDir) {
    Remove-Item -Recurse -Force $stagingDir
}
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

& $sevenZip x $archivePart "-o$stagingDir" -y | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "7z extraction failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $stagingDir)) {
    throw "Extraction staging directory missing: $stagingDir"
}

$sourceDllItem = Get-ChildItem $stagingDir -Recurse -Filter 'avfilter-11.dll' | Select-Object -First 1
if (-not $sourceDllItem) {
    throw 'Extracted DLL missing inside split archive payload.'
}
$sourceDll = $sourceDllItem.FullName

if (-not (Test-Path $sourceDll)) {
    throw "Extracted DLL missing: $sourceDll"
}

foreach ($target in $targets) {
    $targetDir = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    if ((Test-Path $target) -and -not $Force) {
        Write-Output "skip $target"
        continue
    }
    Copy-Item $sourceDll $target -Force
    Write-Output "restored $target"
}
