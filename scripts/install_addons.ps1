#requires -Version 7.0
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$addons = Get-Content -LiteralPath (Join-Path $PSScriptRoot "addons.lock.json") -Raw | ConvertFrom-Json
foreach ($addon in $addons) {
    $destination = Join-Path $projectRoot ("addons/" + $addon.folder)
    if (Test-Path -LiteralPath (Join-Path $destination "plugin.cfg")) {
        Write-Host "$($addon.folder): already installed; local files preserved."
        continue
    }
    if (Test-Path -LiteralPath $destination) {
        throw "Incomplete addon directory: $destination. Move it aside before installing."
    }
    $work = Join-Path $projectRoot (".local/addon-install/" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $archive = Join-Path $work "addon.zip"
    Invoke-WebRequest -Uri $addon.url -OutFile $archive -TimeoutSec 60
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $addon.sha256) {
        throw "SHA-256 mismatch for $($addon.folder). Nothing installed."
    }
    $unpacked = Join-Path $work "unpacked"
    Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
    $candidates = @(Get-ChildItem -LiteralPath $unpacked -Filter plugin.cfg -File -Recurse |
        Where-Object { $_.Directory.Name -eq $addon.folder })
    if ($candidates.Count -ne 1) { throw "Unexpected archive layout for $($addon.folder)." }
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $candidates[0].Directory.FullName -Destination $destination -Recurse
    Write-Host "$($addon.folder) $($addon.version): installed."
}
