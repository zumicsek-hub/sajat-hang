$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio C++ Build Tools, or use CMake with another C++17 compiler.' }
$vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vsRoot) { throw 'Visual Studio C++ toolchain was not found.' }
$compilerRoot = (Get-ChildItem -LiteralPath (Join-Path $vsRoot 'VC\Tools\MSVC') -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
$sdkVersion = (Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'Include') -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
$env:INCLUDE = "$compilerRoot\include;$sdkRoot\Include\$sdkVersion\ucrt;$sdkRoot\Include\$sdkVersion\shared;$sdkRoot\Include\$sdkVersion\um"
$env:LIB = "$compilerRoot\lib\x64;$sdkRoot\Lib\$sdkVersion\ucrt\x64;$sdkRoot\Lib\$sdkVersion\um\x64"
$buildDirectory = Join-Path $projectRoot '.build\native'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
$sourceFile = Join-Path $projectRoot 'native\tests\processor_test.cpp'
$includeDirectory = Join-Path $projectRoot 'packages\voice_audio\native\include'
$binary = Join-Path $buildDirectory 'dsp_tests.exe'
$object = Join-Path $buildDirectory 'processor_test.obj'
& "$compilerRoot\bin\Hostx64\x64\cl.exe" /nologo /std:c++17 /EHsc /W4 /WX /O2 "/I$includeDirectory" $sourceFile "/Fe$binary" "/Fo$object"
if ($LASTEXITCODE -ne 0) { throw 'DSP compilation failed.' }
& $binary
if ($LASTEXITCODE -ne 0) { throw 'DSP tests failed.' }
