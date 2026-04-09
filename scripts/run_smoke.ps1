param(
	[string]$GodotExecutable = "",
	[switch]$Headless
)

$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
	$PSNativeCommandUseErrorActionPreference = $false
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$smokeScene = "res://core/debug/phase0_smoke_runner.tscn"
$resultPath = Join-Path $env:APPDATA "Godot\app_userdata\Game Template\phase0_smoke_result.txt"

function Resolve-GodotExecutable {
	param([string]$preferredExecutable)

	$candidates = @()
	if (-not [string]::IsNullOrWhiteSpace($preferredExecutable)) {
		$candidates += $preferredExecutable
	}
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
		$candidates += $env:GODOT_BIN
	}
	$candidates += "godot4"
	$candidates += "godot"

	foreach ($candidate in $candidates) {
		if ([string]::IsNullOrWhiteSpace($candidate)) {
			continue
		}
		$command = Get-Command $candidate -ErrorAction SilentlyContinue
		if ($null -ne $command) {
			return $candidate
		}
	}

	throw "Godot executable was not found. Pass -GodotExecutable or set GODOT_BIN."
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

	& $resolvedExecutable @arguments

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
