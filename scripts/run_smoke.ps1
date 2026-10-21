param(
    [string]$GodotExecutable = "",
    [switch]$Headless,
    [ValidateSet("flow", "persistence", "transitions", "audio", "localization", "all")]
    [string]$Suite = "flow",
    [string]$Scene = "res://core/debug/phase0_smoke_runner.tscn"
)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$candidates = @($GodotExecutable, $env:GODOT_BIN, "godot4", "godot", "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
$resolvedExecutable = $null
foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($null -ne $command) { $resolvedExecutable = $command.Source; break }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $resolvedExecutable = $candidate; break }
}
if (-not $resolvedExecutable) { throw "Godot not found. Pass -GodotExecutable or set GODOT_BIN." }
# Isolate the child before any autoload reads or writes user data.
$runRoot = Join-Path $projectRoot (".local/smoke/" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
if ([IO.Path]::GetExtension($resolvedExecutable) -eq ".cmd") {
    $wrapper = Get-Content -LiteralPath $resolvedExecutable -Raw
    if ($wrapper -match '"([^"\r\n]+\.exe)"') { $resolvedExecutable = $Matches[1] }
    else { throw "Pass the Godot EXE with -GodotExecutable; unsupported wrapper: $resolvedExecutable" }
}
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $resolvedExecutable
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $Headless.IsPresent
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in @("--path", $projectRoot, "--scene", $Scene, "--max-fps", "60")) { $startInfo.ArgumentList.Add($argument) }
if ($Headless) { $startInfo.ArgumentList.Add("--headless") }
$startInfo.Environment["APPDATA"] = Join-Path $runRoot "AppData"
$startInfo.Environment["LOCALAPPDATA"] = Join-Path $runRoot "LocalAppData"
$startInfo.Environment["XDG_DATA_HOME"] = Join-Path $runRoot "data"
$startInfo.Environment["XDG_CONFIG_HOME"] = Join-Path $runRoot "config"
$startInfo.Environment["GAME_TEMPLATE_SMOKE_ISOLATED"] = "1"
$startInfo.Environment["GAME_TEMPLATE_SMOKE_SUITE"] = $Suite
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$null = $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(90000)) {
    $process.Kill($true)
    throw "Smoke timed out. Artifacts: $runRoot"
}
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $runRoot "stdout.log"), $stdout)
[IO.File]::WriteAllText((Join-Path $runRoot "stderr.log"), $stderr)
Write-Host $stdout
if ($stderr) { Write-Host $stderr }
$results = @(Get-ChildItem -LiteralPath $runRoot -Filter phase0_smoke_result.txt -File -Recurse)
if ($process.ExitCode -ne 0 -or $stderr -match '(?m)^(SCRIPT ERROR|ERROR):' -or $results.Count -ne 1 -or (Get-Content -LiteralPath $results[0].FullName -Raw).Trim() -ne "PASS") {
    throw "Smoke failed (exit $($process.ExitCode)). Artifacts: $runRoot"
}
Write-Host "PASS ($Suite). Artifacts: $runRoot"
