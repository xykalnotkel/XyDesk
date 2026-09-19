#requires -Version 5.1
# Menjadikan monitor virtual 1280x720 layar PRIMARY pada sesi pemanggil,
# supaya jendela aplikasi baru terbuka di layar yang di-stream, bukan di
# monitor headless sebelah. Idempoten: bila sudah primary, tidak mengubah apa pun.
# Tidak menyentuh sesi lain, tidak reboot, tidak mengubah resolusi.
[CmdletBinding(SupportsShouldProcess=$true)]
param([int]$Width=1280,[int]$Height=720)
$ErrorActionPreference='Stop'
if (-not ('XyDeskDisplayLayout' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class XyDeskDisplayLayout {
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Ansi)] public struct DISPLAY_DEVICE { public int cb; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string DeviceName; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string DeviceString; public int StateFlags; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string DeviceID; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string DeviceKey; }
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Ansi)] public struct DEVMODE { [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string dmDeviceName; public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra; public int dmFields; public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput; public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string dmFormName; public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight; public int dmDisplayFlags; public int dmDisplayFrequency; public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType; public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight; }
 [DllImport("user32.dll",CharSet=CharSet.Ansi)] public static extern bool EnumDisplayDevices(string lpDevice,int iDevNum,ref DISPLAY_DEVICE lpDisplayDevice,int dwFlags);
 [DllImport("user32.dll",CharSet=CharSet.Ansi)] public static extern bool EnumDisplaySettings(string lpszDeviceName,int iModeNum,ref DEVMODE lpDevMode);
 [DllImport("user32.dll",CharSet=CharSet.Ansi)] public static extern int ChangeDisplaySettingsEx(string lpszDeviceName,ref DEVMODE lpDevMode,IntPtr hwnd,int dwflags,IntPtr lParam);
 public const int ENUM_CURRENT_SETTINGS=-1;
 public const int ATTACHED_TO_DESKTOP=0x1; public const int PRIMARY=0x4;
 public const int DM_POSITION=0x20; public const int DM_PRIMARY=0x40000;
 public const int CDS_NORESET=0x10000000; public const int CDS_UPDATEREGISTRY=0x1;
 public static bool Current(string deviceName,ref DEVMODE mode){ mode.dmSize=(short)Marshal.SizeOf(typeof(DEVMODE)); return EnumDisplaySettings(deviceName,ENUM_CURRENT_SETTINGS,ref mode); }
}
'@
}
$displays=@()
for($i=0;;$i++){
 $dev=New-Object -TypeName 'XyDeskDisplayLayout+DISPLAY_DEVICE'
 $dev.cb=[System.Runtime.InteropServices.Marshal]::SizeOf($dev.GetType())
 if(-not [XyDeskDisplayLayout]::EnumDisplayDevices($null,$i,[ref]$dev,0)){break}
 if(($dev.StateFlags -band [XyDeskDisplayLayout]::ATTACHED_TO_DESKTOP) -ne [XyDeskDisplayLayout]::ATTACHED_TO_DESKTOP){continue}
 $mode=New-Object -TypeName 'XyDeskDisplayLayout+DEVMODE'
 if(-not [XyDeskDisplayLayout]::Current($dev.DeviceName,[ref]$mode)){continue}
 $displays+=[pscustomobject]@{Name=$dev.DeviceName;Label=$dev.DeviceString;DeviceId=$dev.DeviceID;Primary=(($dev.StateFlags -band [XyDeskDisplayLayout]::PRIMARY) -eq [XyDeskDisplayLayout]::PRIMARY);Width=$mode.dmPelsWidth;Height=$mode.dmPelsHeight;Mode=$mode}
}
$target=$displays | Where-Object { ($_.Label -like '*Virtual Display Driver*' -or $_.DeviceId -like '*MTTVDD*') -and $_.Width -eq $Width -and $_.Height -eq $Height } | Select-Object -First 1
if (-not $target) { Write-Warning "Virtual display ${Width}x${Height} tidak ditemukan di sesi ini. Tidak ada yang diubah."; return }
if ($target.Primary) { Write-Host "Virtual display sudah primary di sesi ini. Tidak ada yang diubah."; return }
if (-not $PSCmdlet.ShouldProcess("Sesi ini: $($displays | ForEach-Object { $_.Name })",'Jadikan monitor virtual 720p layar primary')) { return }
$x=0
$ordered=@($target)+@($displays | Where-Object { $_.Name -ne $target.Name })
foreach($display in $ordered){
 $mode=$display.Mode
 $mode.dmFields=[XyDeskDisplayLayout]::DM_POSITION
 $mode.dmPositionX=$x; $mode.dmPositionY=0
 if($display.Name -eq $target.Name){ $mode.dmFields=$mode.dmFields -bor [XyDeskDisplayLayout]::DM_PRIMARY }
 $code=[XyDeskDisplayLayout]::ChangeDisplaySettingsEx($display.Name,[ref]$mode,[IntPtr]::Zero,([XyDeskDisplayLayout]::CDS_NORESET -bor [XyDeskDisplayLayout]::CDS_UPDATEREGISTRY),[IntPtr]::Zero)
 if($code -ne 0){ throw "ChangeDisplaySettingsEx gagal untuk $($display.Name) dengan kode $code. Topologi sebelumnya dipertahankan sampai panggilan commit." }
 $x+=$display.Width
}
$empty=New-Object -TypeName 'XyDeskDisplayLayout+DEVMODE'
$commit=[XyDeskDisplayLayout]::ChangeDisplaySettingsEx($null,[ref]$empty,[IntPtr]::Zero,0,[IntPtr]::Zero)
if($commit -ne 0){ throw "Commit tata letak gagal dengan kode $commit." }
Write-Host "Monitor virtual ${Width}x${Height} kini primary di sesi ini. Jendela baru terbuka di layar yang di-stream. Tidak ada reboot."
