#requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
if (-not ('XyDeskConsoleLifetime' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class XyDeskConsoleLifetime {
 [StructLayout(LayoutKind.Sequential)] struct Basic {public long time1,time2;public uint flags;public UIntPtr min,max;public uint processes;public UIntPtr affinity;public uint priority,scheduling;}
 [StructLayout(LayoutKind.Sequential)] struct Io {public ulong a,b,c,d,e,f;}
 [StructLayout(LayoutKind.Sequential)] struct Extended {public Basic basic;public Io io;public UIntPtr processMemory,jobMemory,peakProcess,peakJob;}
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attrs,string name);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int cls,ref Extended value,uint size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
 [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
 [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
 static IntPtr job;
 public static void OwnChildren() {
  job=CreateJobObject(IntPtr.Zero,null);if(job==IntPtr.Zero)throw new Win32Exception();
  var info=new Extended();info.basic.flags=0x2000;
  if(!SetInformationJobObject(job,9,ref info,(uint)Marshal.SizeOf(typeof(Extended))))throw new Win32Exception();
  if(!AssignProcessToJobObject(job,GetCurrentProcess()))throw new Win32Exception();
  // Keep the handle for the worker lifetime. OS handle closure kills its children.
 }
}
'@
}
if ($CheckOnly) { Write-Host 'Console job helper compiled; no task/process changes.'; return }
$session = [Diagnostics.Process]::GetCurrentProcess().SessionId
if ($session -ne [XyDeskConsoleLifetime]::WTSGetActiveConsoleSessionId()) { throw 'Not in the active console session. No host launched.' }
[XyDeskConsoleLifetime]::OwnChildren()
$state = Join-Path $env:LOCALAPPDATA 'XyDesk-RemoteCore-Test'
New-Item -ItemType Directory -Path $state -Force | Out-Null
& (Join-Path $PSScriptRoot 'Start-TestHost.ps1') -VirtualDisplay720p -Supervise -LogPath (Join-Path $state 'console-status.log')
