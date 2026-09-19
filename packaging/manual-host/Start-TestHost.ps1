#requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckOnly, [switch]$KeepDesktopResolution, [switch]$VirtualDisplay720p)
$ErrorActionPreference = 'Stop'
$engine = Join-Path $PSScriptRoot 'xydesk-host.exe'
$manifest = Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Engine tidak ditemukan. Ekstrak seluruh ZIP dahulu.' }
# SHA-256 lewat .NET agar tidak bergantung pada autoload Get-FileHash
# (Windows PowerShell 5.1 dapat mewarisi PSModulePath milik PowerShell 7).
$bytes = [IO.File]::ReadAllBytes($engine)
$sha = [Security.Cryptography.SHA256]::Create()
try { $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
finally { $sha.Dispose() }
if ($hash -ne $manifest.sha256) { throw 'Checksum engine tidak cocok. Jangan jalankan paket ini.' }
if ($bytes.Length -lt 256 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw 'Berkas bukan executable Windows.' }
$pe = [BitConverter]::ToInt32($bytes, 0x3c)
if ($pe -lt 0 -or $pe + 6 -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes, $pe) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) { throw 'Paket ini harus berisi PE Windows x64.' }
Write-Host "Checksum dan format Windows x64 cocok. Source: $($manifest.sourceSha)"
if ($CheckOnly) { return }
if (-not [Environment]::Is64BitOperatingSystem -or [Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Jalankan pada Windows x64.' }
if (-not $env:LOCALAPPDATA) { throw 'Profil pengguna Windows belum siap.' }

# Identitas uji terpisah; tidak membaca atau mengganti ID/password host lama.
$previousHome = $env:XYDESK_HOME
$env:XYDESK_HOME = Join-Path $env:LOCALAPPDATA 'XyDesk-RemoteCore-Test'
try {
    New-Item -ItemType Directory -Path $env:XYDESK_HOME -Force | Out-Null
    $identityText = & $engine --identity-json
    if ($LASTEXITCODE -ne 0) { throw 'Engine gagal menyiapkan identitas uji.' }
    $identity = $identityText | ConvertFrom-Json
    if ($identity.deviceId -notmatch '^\d{9}$' -or $identity.password.Length -lt 6) { throw 'Format identitas engine tidak valid.' }
    Write-Host 'Meminta izin signaling untuk perangkat uji. Jangan membagikan isi konsol atau merekam transcript.'
    $body = @{ id = $identity.deviceId; claim = $identity.password } | ConvertTo-Json -Compress
    try {
        $token = [string](Invoke-RestMethod -Method Post -Uri 'https://signal.xydesk.my.id/host-token' -ContentType 'application/json' -Body $body -TimeoutSec 20)
    } catch {
        throw 'Gagal memperoleh izin signaling. Periksa jaringan dan layanan XyDesk; jangan kirim password/token ke chat.'
    }
    $token = $token.Trim()
    if ($token -notmatch '^\d+\.\d{9}\.[a-f0-9]{64}$') { throw 'Respons signaling bukan token host yang valid.' }
    Write-Host 'Host uji dimulai. Biarkan RDP terbuka dan desktop tidak terkunci selama uji pertama.'
    Write-Host 'Gunakan ID/password yang ditampilkan engine pada client. Ctrl+C untuk berhenti.'
    $extra = @()
    if ($KeepDesktopResolution -and $VirtualDisplay720p) { throw 'Choose keep resolution OR virtual720.' }
    if ($KeepDesktopResolution) { $extra += '--keep-desktop-resolution' }
    if ($VirtualDisplay720p) { $extra += '--virtual-display-720p' }
    Write-Host 'Saat tersambung, host meminta mode desktop 16:9 yang didukung. Gunakan -KeepDesktopResolution untuk menonaktifkan.'
    & $engine --url 'wss://signal.xydesk.my.id/ws' --token $token @extra
    if ($LASTEXITCODE -ne 0) { throw 'Host uji berhenti dengan galat. Mulai ulang launcher secara manual bila ingin mencoba lagi.' }
} finally {
    $token = $null
    $body = $null
    $identity = $null
    $identityText = $null
    if ($null -eq $previousHome) { Remove-Item Env:XYDESK_HOME -ErrorAction SilentlyContinue }
    else { $env:XYDESK_HOME = $previousHome }
}
