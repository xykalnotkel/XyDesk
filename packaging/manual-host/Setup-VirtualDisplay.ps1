# Explicit provisioning only. Never imported/called by capture or installer.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param([switch]$Install, [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
if (-not $Install -and -not $VerifyOnly) {
    Write-Host 'No changes. Use -VerifyOnly to validate the pinned package, or -Install as Administrator.'
    Write-Host 'RDP can hide console monitors. Driver installation does not prove that this RDP session can capture one.'
    return
}
if ($Install -and $VerifyOnly) { throw 'Choose -Install OR -VerifyOnly.' }
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
if ($Install) {
    if (-not $PSCmdlet.ShouldProcess('Windows: new MttVDD adapter and C:\VirtualDisplayDriver config', 'Install pinned virtual display driver with one1280x720 mode')) { return }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) { throw 'Run this script in an Administrator PowerShell; no automatic elevation.' }
    if (Test-Path 'C:\VirtualDisplayDriver') { throw 'Existing C:\VirtualDisplayDriver preserved. Configure1280x720 using its owner/VDD Control, then run XyDesk Virtual720. No overwrite.' }
    $existing = @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -eq 'Virtual Display Driver' -or $_.InstanceId -like 'ROOT\MTTVDD\*' })
    if ($existing.Count) { throw 'Existing virtual display preserved. Do not create duplicate adapters; configure the existing driver first.' }
}
if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'Pinned driver is AMD64 only.' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('XyDesk-VDD-' + [guid]::NewGuid().ToString('N'))
$created = $null
try {
    New-Item -ItemType Directory $temp | Out-Null
    $zip = Join-Path $temp 'driver.zip'
    $url = 'https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/download/25.7.23/VirtualDisplayDriver-x86.Driver.Only.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'e24210692b442b39af763536330ce78b423f19342b7a7792c26de3944e418b3a') { throw 'Driver archive hash mismatch; refusing install.' }
    Expand-Archive $zip -DestinationPath $temp
    $payload = Join-Path $temp 'VirtualDisplayDriver'
    $signature = Get-AuthenticodeSignature (Join-Path $payload 'mttvdd.cat')
    if ($signature.Status -ne 'Valid') { throw "Catalog signature not trusted: $($signature.Status). No certificate import/security bypass will be attempted." }
    Write-Host 'Pinned archive hash and Windows catalog signature: PASS. This is not a hardware/RDP test.'
    if ($VerifyOnly) { return }
    [xml]$config = Get-Content (Join-Path $payload 'vdd_settings.xml') -Raw
    $config.vdd_settings.monitors.count = '1'
    $resolutions = $config.vdd_settings.resolutions
    $resolutions.RemoveAll()
    $resolution = $config.CreateElement('resolution')
    foreach ($entry in @(@('width','1280'),@('height','720'),@('refresh_rate','60'))) {
        $element = $config.CreateElement($entry[0]);$element.InnerText=$entry[1];[void]$resolution.AppendChild($element)
    }
    [void]$resolutions.AppendChild($resolution)
    $global = $config.vdd_settings.global;$global.RemoveAll()
    $rate = $config.CreateElement('g_refresh_rate');$rate.InnerText='60';[void]$global.AppendChild($rate)
    $config.Save((Join-Path $payload 'vdd_settings.xml'))
    Copy-Item $payload 'C:\VirtualDisplayDriver' -Recurse
    & "$env:WINDIR\System32\pnputil.exe" /add-driver 'C:\VirtualDisplayDriver\MttVDD.inf'
    if ($LASTEXITCODE -ne 0) { throw "Driver staging refused/code $LASTEXITCODE. No reboot/security change performed; setup files retained." }
    $created = [XyDeskVddDevice]::Create()
    @{instanceId=$created;source=$url;profile='1280x720';createdBy='XyDesk setup'} | ConvertTo-Json | Set-Content 'C:\VirtualDisplayDriver\xydesk-owner.json' -Encoding utf8
    & "$env:WINDIR\System32\pnputil.exe" /add-driver 'C:\VirtualDisplayDriver\MttVDD.inf' /install
    if ($LASTEXITCODE -ne 0) { throw "Device install refused/code $LASTEXITCODE. No automatic restart." }
    Start-Sleep -Seconds 3
    $device = Get-PnpDevice -InstanceId $created
    if ($device.Status -ne 'OK') { throw "Driver device not ready: $($device.Status). See Device Manager; no bypass/reboot attempted." }
    Write-Host "Driver device ready: $created. This does NOT prove monitor visibility in RDP."
    $engine = Join-Path $PSScriptRoot 'xydesk-host.exe'
    if (Test-Path $engine) { & $engine --display-probe }
    Write-Host 'Next: run Start-Virtual720.ps1. It refuses a missing/invisible virtual monitor instead of capturing RDP.'
} catch {
    if ($created) {
        Write-Warning "Removing only the newly-created device $created after failure. Staged driver/config retained for diagnosis."
        & "$env:WINDIR\System32\pnputil.exe" /remove-device $created | Out-Host
    }
    throw
} finally {
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}
