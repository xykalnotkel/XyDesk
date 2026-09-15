[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]] $Binary,

    [Parameter(Mandatory = $true)]
    [string] $StagingRoot
)

# Audit dependency native Windows XyDesk tanpa menyalin DLL dari System32.
#
# Klasifikasi:
#   - Windows system/API: disediakan Windows, tidak dibundle.
#   - MSVC/UCRT runtime: dicatat; build host mengusahakan static CRT.
#   - nvEncodeAPI64.dll: API driver NVIDIA opsional, tidak dibundle.
#   - nama lain: dependency aplikasi; wajib ditemukan di staging bundle.
#
# Script ini sengaja mengaudit xydesk-host.exe dan xydesk.exe saja. Electron
# memiliki daftar DLL Chromium-nya sendiri; DLL itu bukan dependency engine Rust.

$ErrorActionPreference = 'Stop'

function Resolve-DumpBin {
    $command = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $installations = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        foreach ($installation in $installations) {
            $candidate = Get-ChildItem (Join-Path $installation 'VC\Tools\MSVC') -Filter dumpbin.exe -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
            if ($candidate) {
                return $candidate
            }
        }
    }

    $roots = @(
        (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio')
    ) | Where-Object { $_ -and (Test-Path $_) }
    $fallback = Get-ChildItem $roots -Filter dumpbin.exe -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($fallback) {
        return $fallback
    }

    throw 'dumpbin.exe tidak ditemukan. Audit MSVC membutuhkan Visual Studio C++ tools.'
}

function Get-DllDependencies([string] $Path, [string] $DumpBin) {
    $output = & $DumpBin /DEPENDENTS $Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "dumpbin gagal untuk $Path`n$output"
    }

    $names = @(
        $output | ForEach-Object {
            if ($_ -match '^\s+([A-Za-z0-9._-]+\.dll)\s*$') {
                $matches[1].ToLowerInvariant()
            }
        }
    ) | Sort-Object -Unique
    return $names
}

function Get-DependencyClass([string] $Name) {
    $lower = $Name.ToLowerInvariant()
    if ($lower -match '^(api-ms-win|ext-ms-win)-') {
        return 'Windows API set'
    }
    if ($lower -eq 'nvencodeapi64.dll' -or $lower -like 'nvencodeapi*.dll') {
        return 'NVIDIA driver optional'
    }
    if ($lower -match '^(msvcp|vcruntime|concrt|ucrtbase).*\.dll$' -or $lower -match '^api-ms-win-crt-') {
        return 'MSVC/UCRT runtime'
    }

    $systemPath = Join-Path $env:SystemRoot ("System32\{0}" -f $Name)
    if (Test-Path $systemPath) {
        return 'Windows system/driver'
    }
    return 'Application dependency'
}

$dumpbin = Resolve-DumpBin
$staging = (Resolve-Path $StagingRoot).Path
Write-Host "[INFO] dumpbin: $dumpbin"
Write-Host "[INFO] staging: $staging"

$allApplicationDlls = @()
$dynamicRuntimeDlls = @()
$failures = @()

foreach ($item in $Binary) {
    if (-not (Test-Path $item)) {
        throw "Binary tidak ditemukan: $item"
    }

    $path = (Resolve-Path $item).Path
    Write-Host "`n=== $path ==="
    $dependencies = Get-DllDependencies $path $dumpbin
    if ($dependencies.Count -eq 0) {
        Write-Host '[OK] Tidak ada import DLL.'
        continue
    }

    foreach ($name in $dependencies) {
        $class = Get-DependencyClass $name
        switch ($class) {
            'Application dependency' {
                $allApplicationDlls += $name
                $bundled = Get-ChildItem $staging -Recurse -File -Filter $name -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($null -eq $bundled) {
                    $failures += "$name diimport oleh $path tetapi tidak ada di staging bundle"
                    Write-Host "[FAIL] $name => dependency aplikasi, TIDAK dibundle"
                } else {
                    Write-Host "[OK]   $name => dependency aplikasi, bundle: $($bundled.FullName)"
                }
            }
            'MSVC/UCRT runtime' {
                $dynamicRuntimeDlls += $name
                Write-Host "[INFO] $name => MSVC/UCRT runtime; tidak disalin dari System32"
            }
            'NVIDIA driver optional' {
                Write-Host "[INFO] $name => driver NVIDIA opsional; tidak dibundle"
            }
            default {
                Write-Host "[INFO] $name => $class; tidak dibundle"
            }
        }
    }
}

# Opus harus berasal dari object/static archive build.rs, bukan DLL runtime.
$opusDlls = Get-ChildItem $staging -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '(?i)(^|[-_])(?:lib)?opus.*\.dll$' }
if ($opusDlls) {
    $failures += 'DLL Opus ditemukan di staging; libopus vendor wajib statik'
    $opusDlls | ForEach-Object { Write-Host "[FAIL] DLL Opus tidak boleh dibundle: $($_.FullName)" }
} else {
    Write-Host '[OK] Tidak ada opus*.dll/libopus*.dll; libopus vendor tetap statik.'
}

if ($dynamicRuntimeDlls.Count -gt 0) {
    $dynamicRuntimeDlls = $dynamicRuntimeDlls | Sort-Object -Unique
    Write-Host "[INFO] Import MSVC/UCRT dinamis terdeteksi: $($dynamicRuntimeDlls -join ', ')"
    Write-Host '[INFO] Runtime ini bukan DLL yang disalin dari runner; installer harus memakai static CRT atau prerequisite VC++ resmi.'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`n[OK] Audit dependency Windows selesai. Application DLL terdeteksi: $((@($allApplicationDlls) | Sort-Object -Unique) -join ', ')"
