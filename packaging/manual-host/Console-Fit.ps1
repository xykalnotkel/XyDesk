#requires -Version 5.1
# Menarik jendela yang "nyasar" di monitor lain kembali ke layar primary sesi
# pemanggil (layar yang di-stream). Dipakai sekali setelah tata letak monitor
# berubah, atau untuk aplikasi yang mengingat posisi lama di monitor headless.
# Tidak menutup aplikasi, tidak mengubah ukuran melebihi layar, tidak reboot.
[CmdletBinding(SupportsShouldProcess=$true)]
param([int]$Margin=40)
$ErrorActionPreference='Stop'
if (-not ('XyDeskFit' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class XyDeskFit {
 public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
 [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
 public static List<IntPtr> Windows() { var list = new List<IntPtr>(); EnumWindows(delegate(IntPtr h, IntPtr p) { list.Add(h); return true; }, IntPtr.Zero); return list; }
}
'@
}
$primaryWidth=[XyDeskFit]::GetSystemMetrics(0)
$primaryHeight=[XyDeskFit]::GetSystemMetrics(1)
$moved=0; $index=0
foreach($hwnd in [XyDeskFit]::Windows()){
 if(-not [XyDeskFit]::IsWindowVisible($hwnd)){continue}
 if([XyDeskFit]::IsIconic($hwnd)){continue}
 $rect=New-Object XyDeskFit+RECT
 if(-not [XyDeskFit]::GetWindowRect($hwnd,[ref]$rect)){continue}
 if($rect.Left -eq -32000){continue}
 $offscreen = $rect.Left -ge $primaryWidth -or $rect.Right -le 0 -or $rect.Top -ge $primaryHeight -or $rect.Bottom -le 0
 if(-not $offscreen){continue}
 if(-not $PSCmdlet.ShouldProcess("Jendela $hwnd",'Pindah ke layar primary sesi ini')){continue}
 $width=[Math]::Min([Math]::Max($rect.Right-$rect.Left,320),$primaryWidth-2*$Margin)
 $height=[Math]::Min([Math]::Max($rect.Bottom-$rect.Top,240),$primaryHeight-2*$Margin)
 $x=$Margin+(($index*28)%[Math]::Max(1,$primaryWidth-$width-$Margin))
 $y=$Margin+(($index*28)%[Math]::Max(1,$primaryHeight-$height-$Margin))
 [void][XyDeskFit]::SetWindowPos($hwnd,[IntPtr]::Zero,$x,$y,$width,$height,0x44)
 $moved++; $index++
}
Write-Host "$moved jendela nyasar dipindah ke layar primary sesi ini (layar yang di-stream). Aplikasi tidak ditutup."
