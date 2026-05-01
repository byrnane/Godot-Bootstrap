param(
	[string]$GodotExecutable = "",
	[switch]$Headless
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$smokeScene = "res://core/debug/phase0_smoke_runner.tscn"
$resultPath = Join-Path $env:APPDATA "Godot\app_userdata\Game Template\phase0_smoke_result.txt"
$knownExecutablePaths = @(
	"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)

function Add-Candidate {
	param(
		[System.Collections.Generic.List[string]]$Candidates,
		[string]$Value
	)

	if ([string]::IsNullOrWhiteSpace($Value)) {
		return
	}

	if (-not $Candidates.Contains($Value)) {
		$Candidates.Add($Value)
	}
}

function Resolve-GodotExecutable {
	param([string]$preferredExecutable)

	$candidates = [System.Collections.Generic.List[string]]::new()
	Add-Candidate -Candidates $candidates -Value $preferredExecutable
	Add-Candidate -Candidates $candidates -Value $env:GODOT_BIN

	# PATH-based aliases stay first so existing local setups behave the same.
	foreach ($commandName in @("godot4", "godot")) {
		Add-Candidate -Candidates $candidates -Value $commandName
	}

	# Steam installs often live outside PATH on Windows.
	foreach ($path in $knownExecutablePaths) {
		Add-Candidate -Candidates $candidates -Value $path
	}

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate) {
			return $candidate
		}

		$command = Get-Command $candidate -ErrorAction SilentlyContinue
		if ($null -ne $command) {
			return $command.Source
		}
	}

	throw "Godot executable was not found. Pass -GodotExecutable, set GODOT_BIN, or update the known executable paths in scripts/run_smoke.ps1."
}

function Main {
	$resolvedExecutable = Resolve-GodotExecutable -preferredExecutable $GodotExecutable
	Write-Host "Using Godot executable: $resolvedExecutable"
	Write-Host "Project root: $projectRoot"

	if (Test-Path $resultPath) {
		Remove-Item $resultPath -Force
	}

	$arguments = @("--path", $projectRoot, "--scene", $smokeScene)
	if ($Headless) {
		$arguments = @("--headless") + $arguments
	}

	# Start-Process keeps exit handling consistent across shells and terminals.
	$process = Start-Process -FilePath $resolvedExecutable -ArgumentList $arguments -Wait -PassThru -NoNewWindow
	$godotExitCode = $process.ExitCode
	Write-Host "Godot exit code: $godotExitCode"

	if (-not (Test-Path $resultPath)) {
		throw "Smoke result file was not generated: $resultPath"
	}

	$result = (Get-Content $resultPath -Raw)
	$normalizedResult = $result.Trim().Trim([char]0xFEFF)
	if ($normalizedResult -eq "PASS") {
		Write-Host "Smoke result: PASS"
		exit 0
	}

	Write-Host "Smoke result contents:"
	Write-Host $normalizedResult
	throw "Smoke run finished without PASS status."
}

Main
