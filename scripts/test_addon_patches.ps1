#requires -Version 7.0
$ErrorActionPreference = "Stop"
$fixtureRoot = Join-Path (Split-Path -Parent $PSScriptRoot) (".local/addon-patch-tests/" + [guid]::NewGuid().ToString("N"))
$fixtureScripts = Join-Path $fixtureRoot "scripts"
$fixtureAddon = Join-Path $fixtureRoot "addons/fixture"
New-Item -ItemType Directory -Path $fixtureScripts,$fixtureAddon -Force | Out-Null
git -C $fixtureRoot init --quiet
if ($LASTEXITCODE -ne 0) { throw "Failed to initialize the isolated fixture repository." }
[IO.File]::WriteAllText((Join-Path $fixtureRoot ".gitignore"), "addons/`n")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "install_addons.ps1") -Destination $fixtureScripts
[IO.File]::WriteAllText((Join-Path $fixtureAddon "plugin.cfg"), "[plugin]`nname=fixture`n")
$target = Join-Path $fixtureAddon "cleanup.gd"
[IO.File]::WriteAllText($target, "before`n")
[IO.File]::WriteAllText((Join-Path $fixtureScripts "addons.lock.json"), '[{"folder":"fixture","patches":["cleanup.patch"]}]')
$patch = @'
diff --git a/cleanup.gd b/cleanup.gd
--- a/cleanup.gd
+++ b/cleanup.gd
@@ -1 +1 @@
-before
+after
'@ + "`n"
[IO.File]::WriteAllText((Join-Path $fixtureScripts "cleanup.patch"), $patch)
$installer = Join-Path $fixtureScripts "install_addons.ps1"
& $installer
if ([IO.File]::ReadAllText($target) -ne "after`n") { throw "Patch was not applied." }
& $installer
if ([IO.File]::ReadAllText($target) -ne "after`n") { throw "Repeated install changed patched files." }
[IO.File]::WriteAllText($target, "owner edit`n")
$rejected = $false
try { & $installer } catch { $rejected = $true }
if (-not $rejected) { throw "Unknown local edits were accepted." }
if ([IO.File]::ReadAllText($target) -ne "owner edit`n") { throw "Local edits were overwritten." }
Write-Host "PASS: addon patches apply once and preserve conflicting local edits. Artifacts: $fixtureRoot"
exit 0
