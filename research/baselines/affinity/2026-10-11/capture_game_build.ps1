# Read-only installed DD2/REFramework environment capture. Does not change game files.
param(
    [Parameter(Mandatory=$true)]
    [string]$GameDir
)
$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $GameDir).Path
$exe = Join-Path $resolved 'DD2.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'DD2.exe was not found in GameDir.' }
$dll = Join-Path $resolved 'dinput8.dll'
# Standard Steam library layout is ...\steamapps\common\<game folder>
$steamapps = Split-Path -Parent (Split-Path -Parent $resolved)
$manifest = Join-Path $steamapps 'appmanifest_2054970.acf'
$buildid = $null
if (Test-Path -LiteralPath $manifest) {
    $content = Get-Content -LiteralPath $manifest -Raw
    if ($content -match '"buildid"\s+"(\d+)"') { $buildid = $Matches[1] }
}
$exeFile = Get-Item -LiteralPath $exe
$result = [ordered]@{
    capturedLocalTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    steamBuildIDFromLocalManifest = $buildid
    manifestFound = (Test-Path -LiteralPath $manifest)
    gameExe = [ordered]@{
        fileName = 'DD2.exe'
        version = $exeFile.VersionInfo.FileVersion
        productVersion = $exeFile.VersionInfo.ProductVersion
        sha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes = $exeFile.Length
    }
    reframeworkDll = $(if (Test-Path -LiteralPath $dll) {
        [ordered]@{ fileName = 'dinput8.dll'; sha256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash.ToLowerInvariant() }
    } else { $null })
    note = 'Installed game executable hash is local evidence; Steam public build history is not.'
}
$output = Join-Path (Get-Location).Path 'DD2_Installed_Environment.json'
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding UTF8
Write-Host "Saved: $output"
