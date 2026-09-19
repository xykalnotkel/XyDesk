# Explicit provisioning. 3010 is success pending reboot, never an install refusal.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param([switch]$Install, [switch]$VerifyOnly, [switch]$Resume)
$ErrorActionPreference = 'Stop'
function Get-XyDeskPnpDisposition {
    param([int]$Code)
    [pscustomobject]@{Code=$Code;Accepted=($Code -eq 0 -or $Code -eq 3010);RebootRequired=($Code -eq 3010)}
}
function Test-XyDeskRollback {
    param([bool]$CreatedThisAttempt, [bool]$InstallAccepted)
    return ($CreatedThisAttempt -and -not $InstallAccepted)
}
function Assert-XyDeskResumeOwner {
    param($Owner, [string]$Source)
    if ($Owner.createdBy -ne 'XyDesk setup' -or $Owner.profile -ne '1280x720' -or $Owner.source -ne $Source) {
        throw 'Ownership metadata does not match this XyDesk setup. No takeover.'
    }
    if ($Owner.instanceId) {
        if ($Owner.instanceId -notmatch '^ROOT\\MTTVDD\\[0-9A-F]{4,}$') { throw 'Unexpected owned device instance. Refusing resume.' }
    } elseif ($Owner.schema -ne 2) { throw 'Missing device identity in legacy metadata. Refusing resume.' }
}
function Test-XyDeskPendingReboot {
    param($Owner, [string]$BootId)
    if (-not $Owner) { return $false }
    return ($Owner.state -like '*reboot-required' -and $Owner.bootId -eq $BootId)
}
function Invoke-XyDeskPnp {
    param([string[]]$Arguments)
    $PSNativeCommandUseErrorActionPreference = $false # PS7 must allow inspecting success3010; harmless in PS5.
    & "$env:WINDIR\System32\pnputil.exe" @Arguments | Out-Host
    return [int]$LASTEXITCODE
}
function Write-XyDeskState {
    param([string]$Instance, [string]$State, [int]$Code, [string]$BootId)
    $record = @{schema=2;instanceId=$Instance;source=$url;profile='1280x720';createdBy='XyDesk setup';state=$State;lastCode=$Code;bootId=$BootId;updatedAt=[DateTime]::UtcNow.ToString('o')}
    $temporary = Join-Path $root 'xydesk-owner.json.tmp'
    $record | ConvertTo-Json | Set-Content $temporary -Encoding utf8
    Move-Item -LiteralPath $temporary -Destination (Join-Path $root 'xydesk-owner.json') -Force
}
if ($Resume -and -not $Install) { throw '-Resume requires -Install.' }
if ($Install -and $VerifyOnly) { throw 'Choose -Install OR -VerifyOnly.' }
if (-not $Install -and -not $VerifyOnly) {
    Write-Host 'No changes. Use -VerifyOnly, -Install, or -Install -Resume for a verified XyDesk-owned partial setup.'
    return
}
# Compile the native device registration helper even under -WhatIf; no calls yet.
if (-not ('XyDeskVddDevice' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.Text;
public static class XyDeskVddDevice {
 [StructLayout(LayoutKind.Sequential)] struct DevInfo { public uint size; public Guid cls; public uint inst; public IntPtr reserved; }
 [DllImport("setupapi.dll",SetLastError=true)] static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid g,IntPtr w);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiCreateDeviceInfoW(IntPtr s,string n,ref Guid g,string d,IntPtr w,uint f,ref DevInfo i);
 [DllImport("setupapi.dll",SetLastError=true)] static extern bool SetupDiSetDeviceRegistryPropertyW(IntPtr s,ref DevInfo i,uint p,byte[] b,uint z);
 [DllImport("setupapi.dll",SetLastError=true)] static extern bool SetupDiCallClassInstaller(uint f,IntPtr s,ref DevInfo i);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiGetDeviceInstanceIdW(IntPtr s,ref DevInfo i,StringBuilder b,uint n,out uint needed);
 [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr s);
 static void Check(bool ok) { if(!ok) throw new Win32Exception(Marshal.GetLastWin32Error()); }
 public static string Create() {
  Guid cls=new Guid("4d36e968-e325-11ce-bfc1-08002be10318");
  IntPtr set=SetupDiCreateDeviceInfoList(ref cls,IntPtr.Zero);
  if(set==new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error());
  DevInfo info=new DevInfo();info.size=(uint)Marshal.SizeOf(typeof(DevInfo));bool registered=false;
  try {
   Check(SetupDiCreateDeviceInfoW(set,"MttVDD",ref cls,"XyDesk Virtual720",IntPtr.Zero,1,ref info));
   byte[] ids=Encoding.Unicode.GetBytes("Root\\MttVDD\0\0");
   Check(SetupDiSetDeviceRegistryPropertyW(set,ref info,1,ids,(uint)ids.Length));
   Check(SetupDiCallClassInstaller(0x19,set,ref info));registered=true;
   var name=new StringBuilder(1024);uint needed;
   Check(SetupDiGetDeviceInstanceIdW(set,ref info,name,1024,out needed));return name.ToString();
  } catch { if(registered) SetupDiCallClassInstaller(5,set,ref info);throw; }
  finally { SetupDiDestroyDeviceInfoList(set); }
 }
}
'@
}
$root = 'C:\VirtualDisplayDriver'
$url = 'https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/download/25.7.23/VirtualDisplayDriver-x86.Driver.Only.zip'
$owner = $null
$existing = @()
if ($Install) {
    if (-not $PSCmdlet.ShouldProcess('Windows: pinned MttVDD device and XyDesk-owned config', 'Install/resume Virtual720 without automatic restart')) { return }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) { throw 'Administrator PowerShell required. No automatic elevation.' }
    if ($Resume) {
        $ownerPath = Join-Path $root 'xydesk-owner.json'
        if (-not (Test-Path -LiteralPath $ownerPath -PathType Leaf)) { throw 'No XyDesk ownership record. No files/devices changed.' }
        $owner = Get-Content -LiteralPath $ownerPath -Raw | ConvertFrom-Json
        Assert-XyDeskResumeOwner $owner $url
    } elseif (Test-Path -LiteralPath $root) {
        throw 'Existing config preserved. For the interrupted XyDesk setup use -Install -Resume; do not delete the directory blindly.'
    }
    $existing = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -eq 'Virtual Display Driver' -or $_.InstanceId -like 'ROOT\MTTVDD\*' })
    foreach ($device in $existing) {
        if (-not $Resume -or $device.InstanceId -ne $owner.instanceId) { throw 'Another virtual display device exists. No duplicate/foreign device takeover.' }
        $hardware = (Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds').Data
        if ($hardware -notcontains 'Root\MttVDD' -and $hardware -notcontains 'MttVDD') { throw 'Owned instance hardware ID changed. Refusing resume.' }
    }
}
if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'Pinned driver is AMD64 only.' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('XyDesk-VDD-' + [guid]::NewGuid().ToString('N'))
$createdThisAttempt = $null
$deviceId = $null
$installAccepted = $false
try {
    New-Item -ItemType Directory $temp | Out-Null
    $zip = Join-Path $temp 'driver.zip'
    $bundled = Join-Path $PSScriptRoot 'VirtualDisplayDriver.zip'
    if (Test-Path -LiteralPath $bundled) { Copy-Item -LiteralPath $bundled -Destination $zip }
    else { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip }
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'e24210692b442b39af763536330ce78b423f19342b7a7792c26de3944e418b3a') { throw 'Driver archive hash mismatch.' }
    Expand-Archive $zip -DestinationPath $temp
    $payload = Join-Path $temp 'VirtualDisplayDriver'
    $signature = Get-AuthenticodeSignature (Join-Path $payload 'mttvdd.cat')
    if ($signature.Status -ne 'Valid') { throw "Catalog signature not trusted: $($signature.Status). No security bypass." }
    Write-Host 'Pinned archive hash and Windows catalog signature: PASS. This is not a hardware/RDP test.'
    if ($VerifyOnly) { return }
    [xml]$config = Get-Content (Join-Path $payload 'vdd_settings.xml') -Raw
    $config.vdd_settings.monitors.count = '1'
    $resolutions = $config.vdd_settings.resolutions; $resolutions.RemoveAll()
    $resolution = $config.CreateElement('resolution')
    foreach ($entry in @(@('width','1280'),@('height','720'),@('refresh_rate','60'))) {
        $element=$config.CreateElement($entry[0]); $element.InnerText=$entry[1]; [void]$resolution.AppendChild($element)
    }
    [void]$resolutions.AppendChild($resolution)
    $global=$config.vdd_settings.global; $global.RemoveAll()
    $rate=$config.CreateElement('g_refresh_rate'); $rate.InnerText='60'; [void]$global.AppendChild($rate)
    $config.Save((Join-Path $payload 'vdd_settings.xml'))
    if ($Resume) {
        foreach ($file in @('MttVDD.inf','MttVDD.dll','mttvdd.cat')) {
            if ((Get-FileHash (Join-Path $root $file) -Algorithm SHA256).Hash -ne (Get-FileHash (Join-Path $payload $file) -Algorithm SHA256).Hash) { throw "Existing $file differs from pinned package. No overwrite." }
        }
        [xml]$currentConfig=Get-Content (Join-Path $root 'vdd_settings.xml') -Raw
        if ($currentConfig.OuterXml -ne $config.OuterXml) { throw 'Existing config differs from the XyDesk720 profile. No overwrite.' }
    } else { Copy-Item $payload $root -Recurse }
    $bootId = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
    if ($Resume -and (Test-XyDeskPendingReboot $owner $bootId)) {
        Write-Warning 'Setup is already pending a Windows reboot on this same boot. Device/config preserved; no install repetition or restart performed.'
        return
    }
    if ($existing.Count -eq 1) { $deviceId = $existing[0].InstanceId }
    Write-XyDeskState $deviceId 'validated' 0 $bootId
    $stage = Get-XyDeskPnpDisposition (Invoke-XyDeskPnp -Arguments @('/add-driver', (Join-Path $root 'MttVDD.inf')))
    if (-not $stage.Accepted) { throw "Driver staging failed/code $($stage.Code)." }
    if ($stage.RebootRequired) {
        Write-XyDeskState $deviceId 'staged-reboot-required' $stage.Code $bootId
        Write-Warning '3010: staging succeeded, Windows requires reboot. Config/device preserved. No reboot performed; do not restart a hosted runner without a recovery plan.'
        return
    }
    if (-not $deviceId) { $deviceId=[XyDeskVddDevice]::Create(); $createdThisAttempt=$deviceId }
    Write-XyDeskState $deviceId 'device-registered' 0 $bootId
    $result = Get-XyDeskPnpDisposition (Invoke-XyDeskPnp -Arguments @('/add-driver', (Join-Path $root 'MttVDD.inf'), '/install'))
    # Set BEFORE persistence/inspection: later errors must not remove an accepted device.
    $installAccepted = $result.Accepted
    if (-not $result.Accepted) { throw "Device install failed/code $($result.Code)." }
    if ($result.RebootRequired) {
        Write-XyDeskState $deviceId 'installed-reboot-required' $result.Code $bootId
        Write-Warning "3010: installation succeeded, Windows requires reboot. Device $deviceId RETAINED. No automatic reboot/service restart/RDP disconnect. Stop here and review runner recovery before planning a reboot."
        return
    }
    Write-XyDeskState $deviceId 'installed-pending-readiness' 0 $bootId
    $device = $null
    for ($i=0; $i -lt 10; $i++) {
        $device=Get-PnpDevice -InstanceId $deviceId -ErrorAction SilentlyContinue
        if ($device.Status -eq 'OK') { break }
        Start-Sleep -Seconds 1
    }
    if ($device.Status -ne 'OK') {
        Write-Warning "Installation accepted, but readiness not verified for $deviceId. Device retained for diagnosis, not removed."
        return
    }
    Write-XyDeskState $deviceId 'device-ready' 0 $bootId
    Write-Host "Driver device ready: $deviceId. This does NOT prove monitor visibility in RDP."
    $engine=Join-Path $PSScriptRoot 'xydesk-host.exe'
    if (Test-Path $engine) { & $engine --display-probe }
} catch {
    if (Test-XyDeskRollback ([bool]$createdThisAttempt) $installAccepted) {
        Write-Warning "Removing only newly-created $createdThisAttempt after a real failed install. Existing devices and accepted0/3010 installs are preserved."
        $removeCode = Invoke-XyDeskPnp -Arguments @('/remove-device', $createdThisAttempt)
        if ($removeCode -ne 0) { Write-Warning "Cleanup returned $removeCode; inspect the owned device. No reboot requested." }
    }
    throw
} finally {
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}
