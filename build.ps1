# mtab build script: compile MoonBit to wasm-gc and stage the web artifact.
# Usage:  .\build.ps1            (debug)
#         .\build.ps1 -Release   (release, smaller wasm)
param(
  [switch]$Release
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$mode = if ($Release) { 'release' } else { 'debug' }
Write-Host "==> moon build --target wasm-gc ($mode)"
moon build --target wasm-gc $(if ($Release) { '--release' })
if ($LASTEXITCODE -ne 0) { throw "moon build failed" }

$src = Join-Path $root "_build/wasm-gc/$mode/build/main/main.wasm"
$dstDir = Join-Path $root 'web/wasm'
$dst = Join-Path $dstDir 'main.wasm'
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
Copy-Item $src $dst -Force

$size = (Get-Item $dst).Length
Write-Host ("==> staged {0} ({1:N0} bytes)" -f $dst, $size)
