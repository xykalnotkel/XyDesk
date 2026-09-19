#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param([switch]$NoPause)
$ErrorActionPreference='Stop'
try {
 $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 if (!$admin) {throw 'Administrator permission required. No changes performed.'}
 $devices=@(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object {$_.InstanceId -like 'ROOT\MTTVDD\*'})
 if ($devices.Count -gt 0) {
  Write-Host 'Existing virtual display preserved. No reinstall, configuration overwrite, service restart or session change.'
  $devices | Select-Object Status,FriendlyName,InstanceId | Format-Table
 } elseif (Test-Path 'C:\VirtualDisplayDriver') {
  Write-Warning 'Existing configuration preserved. Review ownership/pending-reboot state before explicitly resuming Setup-VirtualDisplay.ps1.'
 } elseif ($PSCmdlet.ShouldProcess('New virtual display only','Install pinned driver and configure 1280x720 at 60Hz')) {
  & (Join-Path $PSScriptRoot 'Setup-VirtualDisplay.ps1') -Install -Confirm:$false
 }
 Write-Host 'No reboot, RDP disconnect, console-user switch or host restart performed.'
} catch {Write-Warning $_.Exception.Message; if($NoPause){throw}}
finally {if(!$NoPause -and !$WhatIfPreference){[void](Read-Host 'Press Enter to close')}}
