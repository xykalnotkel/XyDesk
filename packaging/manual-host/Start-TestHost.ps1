#requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckOnly, [switch]$KeepDesktopResolution, [switch]$VirtualDisplay720p, [switch]$Supervise, [string]$LogPath)
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
    Write-Host 'Engine memperbarui izin signaling otomatis; ID/password tetap tersimpan. Jangan membagikan isi konsol.'
    Write-Host 'Host uji dimulai. Biarkan RDP terbuka dan desktop tidak terkunci selama uji pertama.'
    Write-Host 'Gunakan ID/password yang ditampilkan engine pada client. Ctrl+C untuk berhenti.'
    $extra = @()
    if ($KeepDesktopResolution -and $VirtualDisplay720p) { throw 'Choose keep resolution OR virtual720.' }
    if ($KeepDesktopResolution) { $extra += '--keep-desktop-resolution' }
    if ($VirtualDisplay720p) { $extra += '--virtual-display-720p' }
    Write-Host 'Saat tersambung, host meminta mode desktop 16:9 yang didukung. Gunakan -KeepDesktopResolution untuk menonaktifkan.'
    $delay = 1
    do {
        $started = [DateTime]::UtcNow
        if ($LogPath) {
            if ((Test-Path $LogPath) -and (Get-Item $LogPath).Length -gt 1048576) { Move-Item $LogPath ($LogPath + '.previous') -Force }
            $savedPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $PSNativeCommandUseErrorActionPreference = $false
            & $engine --url 'wss://signal.xydesk.my.id/ws' --managed-auth @extra 2>&1 | ForEach-Object {
                $line = $_.ToString()
                if ($line -match '^\[xydesk-host\] pairing (DITERIMA|DITOLAK|GAGAL)') {
                    Add-Content -LiteralPath $LogPath -Value (([DateTime]::UtcNow.ToString('o')) + ' [pair-diag] ' + $Matches[1])
                }
                # Allow-list operational messages. Never log ID/password, control tokens,
                # peer labels, pairing grants, or arbitrary server response bodies.
                if ($line -match '^\[cursor\]' -or $line -match '^\[xydesk-host\] (terhubung ke|terdaftar sebagai|koneksi signaling putus|signaling heartbeat timeout|token endpoint|refresh |identity unavailable)') {
                    Add-Content -LiteralPath $LogPath -Value (([DateTime]::UtcNow.ToString('o')) + ' ' + $line.Substring(0,[Math]::Min(256,$line.Length)))
                }
            }
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = $savedPreference
        } else {
            & $engine --url 'wss://signal.xydesk.my.id/ws' --managed-auth @extra
            $exitCode = $LASTEXITCODE
        }
        if (-not $Supervise) {
            if ($exitCode -ne 0) { throw "Host stopped/code $exitCode." }
            break
        }
        if (([DateTime]::UtcNow - $started).TotalSeconds -ge 60) { $delay = 1 }
        if ($LogPath) { Add-Content -LiteralPath $LogPath -Value "Host exited/code $exitCode; retry after $delay seconds." }
        Start-Sleep -Seconds $delay
        $delay = [Math]::Min(30, $delay * 2)
    } while ($Supervise)

} finally {
    $token = $null
    $body = $null
    $identity = $null
    $identityText = $null
    if ($null -eq $previousHome) { Remove-Item Env:XYDESK_HOME -ErrorAction SilentlyContinue }
    else { $env:XYDESK_HOME = $previousHome }
}
