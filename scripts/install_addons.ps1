#requires -Version 7.0
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Install-AddonPatches($Addon) {
    if (-not $Addon.PSObject.Properties["patches"]) { return }
    foreach ($patch in @($Addon.patches)) {
        if ([string]::IsNullOrWhiteSpace($patch)) { continue }
        $patchPath = Join-Path $PSScriptRoot $patch
        $addonDirectory = "addons/$($Addon.folder)"
        $null = Get-Command git -ErrorAction Stop
        $reverseCheck = & git -C $projectRoot apply --reverse --check --directory=$addonDirectory -- $patchPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$($Addon.folder): patch $patch already applied."
            continue
        }
        $forwardCheck = & git -C $projectRoot apply --check --directory=$addonDirectory -- $patchPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Patch $patch does not match $($Addon.folder). Local files preserved. $forwardCheck"
        }
        & git -C $projectRoot apply --directory=$addonDirectory -- $patchPath
        if ($LASTEXITCODE -ne 0) { throw "Failed to apply $patch to $($Addon.folder)." }
        Write-Host "$($Addon.folder): applied $patch."
    }
}

$addons = Get-Content -LiteralPath (Join-Path $PSScriptRoot "addons.lock.json") -Raw | ConvertFrom-Json
foreach ($addon in $addons) {
    $destination = Join-Path $projectRoot ("addons/" + $addon.folder)
    if (Test-Path -LiteralPath (Join-Path $destination "plugin.cfg")) {
        Write-Host "$($addon.folder): already installed; local files preserved."
        Install-AddonPatches $addon
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
    Install-AddonPatches $addon
}
