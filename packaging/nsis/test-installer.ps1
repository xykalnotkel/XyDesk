# Hanya dijalankan pada runner build Windows sementara; tidak memulai host/RDP.
param([Parameter(Mandatory=$true)][string]$Installer, [Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference = 'Stop'
$Installer = (Resolve-Path $Installer).Path
$checks = [Collections.Generic.List[string]]::new()
$base = Join-Path $env:RUNNER_TEMP ('xydesk-nsis-' + [guid]::NewGuid().ToString('N'))
$installed = Join-Path $base 'Host with spaces'
$occupied = Join-Path $base 'Occupied'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\XyDeskHostTest'
if (Test-Path $key) { throw 'Runner sudah memiliki instalasi; tes menolak menyentuhnya.' }
New-Item -ItemType Directory $occupied -Force | Out-Null
Set-Content (Join-Path $occupied 'keep.txt') 'do-not-delete'
function RunSetup($dir) {
    $p = Start-Process -FilePath $Installer -ArgumentList "/S /D=$dir" -Wait -PassThru
    return $p.ExitCode
}
if ((RunSetup $occupied) -eq 0) { throw 'Folder berisi data tidak ditolak' }
if ((Get-Content (Join-Path $occupied 'keep.txt') -Raw).Trim() -ne 'do-not-delete') { throw 'Data folder lain berubah' }
if (Test-Path (Join-Path $occupied 'xydesk-host.exe')) { throw 'Engine tertulis di folder yang ditolak' }
$checks.Add('non-empty unrelated directory rejected without changes')
if ((RunSetup $installed) -ne 0) { throw 'Silent install gagal' }
$engine = Join-Path $installed 'xydesk-host.exe'
$manifest = Get-Content (Join-Path $installed 'manifest.json') -Raw | ConvertFrom-Json
$expected = '058bed366bc58ade31326d13187526b5428a35a5c2f5d07ee5e61992ae2b2142'
if ((Get-FileHash $engine -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Payload engine berubah saat dipasang' }
if ($manifest.sha256 -ne $expected) { throw 'Manifest engine salah' }
& $engine --help | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Engine hasil instalasi tidak bisa dijalankan' }
$checks.Add('silent install to path with spaces; installed MSVC engine hash and --help verified')
$props = Get-ItemProperty $key
if ($props.InstallLocation -ne $installed -or $props.DisplayVersion -ne '6.8.5') { throw 'Registrasi Apps tidak cocok' }
$desktop = [Environment]::GetFolderPath('Desktop')
$programs = [Environment]::GetFolderPath('Programs')
$shortcut = Join-Path $programs 'XyDesk Host Test\XyDesk Host Test.lnk'
if (-not (Test-Path $shortcut) -or -not (Test-Path (Join-Path $desktop 'XyDesk Host Test.lnk'))) { throw 'Shortcut hilang' }
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcut)
if ($link.Arguments -notlike '*Start-TestHost.ps1*') { throw 'Target shortcut salah' }
# Uji perintah shortcut dengan CheckOnly, tanpa NoExit, tanpa meminta token/stream.
$argsCheck = $link.Arguments.Replace('-NoExit ', '') + ' -CheckOnly'
Write-Host ('CheckOnly target: ' + $link.TargetPath)
Write-Host ('CheckOnly args: ' + $argsCheck)
$stdout = Join-Path $base 'launcher-out.txt'
$stderr = Join-Path $base 'launcher-error.txt'
$p = Start-Process -FilePath $link.TargetPath -ArgumentList $argsCheck -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if ($p.ExitCode -ne 0) {
    Write-Host ('CheckOnly exit: ' + $p.ExitCode)
    Get-Content $stdout -ErrorAction SilentlyContinue | Select-Object -First 20
    Get-Content $stderr -ErrorAction SilentlyContinue | Select-Object -First 20
    throw 'Launcher shortcut gagal CheckOnly di Windows PowerShell'
}
$checks.Add('Apps registration, desktop/Start Menu shortcuts and actual PowerShell shortcut command verified')
Set-Content (Join-Path $installed 'keep-user.txt') 'user-file'
if ((RunSetup $installed) -ne 0) { throw 'Reinstall di lokasi sendiri gagal' }
if ((Get-Content (Join-Path $installed 'keep-user.txt') -Raw).Trim() -ne 'user-file') { throw 'Reinstall mengubah file tambahan' }
if ((RunSetup $occupied) -eq 0) { throw 'Install kedua memindahkan registrasi ke folder lain' }
if ((Get-ItemProperty $key).InstallLocation -ne $installed) { throw 'Registrasi instalasi pertama berubah' }
$checks.Add('reinstall preserves extra files; different install location cannot hijack registration')
$dataDir = Join-Path $env:LOCALAPPDATA 'XyDesk-RemoteCore-Test'
New-Item -ItemType Directory $dataDir -Force | Out-Null
$sentinel = Join-Path $dataDir ('nsis-test-' + [guid]::NewGuid().ToString('N') + '.txt')
Set-Content $sentinel 'identity-preservation-fixture'
$uninstaller = Join-Path $installed 'Uninstall-XyDesk-Host-Test.exe'
$p = Start-Process -FilePath $uninstaller -ArgumentList '/S' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'Uninstall gagal' }
if ((Test-Path $engine) -or (Test-Path $key) -or (Test-Path $shortcut) -or (Test-Path (Join-Path $desktop 'XyDesk Host Test.lnk'))) { throw 'Uninstall meninggalkan engine/registrasi/shortcut' }
if (-not (Test-Path $sentinel) -or -not (Test-Path (Join-Path $installed 'keep-user.txt'))) { throw 'Uninstall menghapus data yang harus dipertahankan' }
$checks.Add('silent uninstall removes engine/registration/shortcuts but preserves identity and extra files')
Remove-Item $sentinel
# Folder base sepenuhnya dibuat tes ini dengan GUID; bukan folder instalasi pengguna.
Remove-Item $base -Recurse -Force
[ordered]@{
    result = 'PASS'; sourceSha = $env:GITHUB_SHA; testedAt = [DateTime]::UtcNow.ToString('o')
    installer = (Split-Path $Installer -Leaf)
    sha256 = (Get-FileHash $Installer -Algorithm SHA256).Hash.ToLowerInvariant()
    bytes = (Get-Item $Installer).Length
    engineSha256 = $expected
    checks = $checks.ToArray()
    remoteDesktopHardwareTested = $false
    productionDeployed = $false
} | ConvertTo-Json -Depth 4 | Set-Content $Report -Encoding utf8
Get-Content $Report
