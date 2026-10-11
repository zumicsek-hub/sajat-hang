param([int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterBin = Split-Path $flutterCommand.Source -Parent
$dart = Join-Path $flutterBin 'cache\dart-sdk\bin\dart.exe'
$snapshot = Join-Path $flutterBin 'cache\flutter_tools.snapshot'
if (!(Test-Path -LiteralPath $snapshot)) { throw 'Run flutter doctor once to initialize the Flutter SDK.' }
$stateDirectory = Join-Path $projectRoot '.build\tool-state'
New-Item -ItemType Directory -Force -Path $stateDirectory | Out-Null
$env:APPDATA = $stateDirectory
$env:LOCALAPPDATA = $stateDirectory
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
Push-Location $projectRoot
try {
  & $dart $snapshot pub get
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
  Write-Host "UI preview only, no microphone processing: http://localhost:$Port"
  & $dart $snapshot run -d web-server --web-hostname 127.0.0.1 --web-port $Port
} finally { Pop-Location }
