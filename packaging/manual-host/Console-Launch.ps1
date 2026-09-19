#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$AppPath,[string]$Arguments='',[string]$ConsoleUser='runneradmin')
$ErrorActionPreference='Stop'
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$admin) {throw 'Administrator PowerShell required. No automatic elevation.'}
$full=[IO.Path]::GetFullPath($AppPath)
if (-not (Test-Path -LiteralPath $full)) {throw 'Application not found. No process started.'}
if (!$PSCmdlet.ShouldProcess("Console session of $ConsoleUser",'Start application on the virtual 720p desktop')) {return}
$name='XyDesk-Console-Launch'
Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
$action=New-ScheduledTaskAction -Execute $full -Argument $Arguments
$principal=New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$ConsoleUser" -LogonType Interactive
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Description 'One-shot launch into the XyDesk console desktop' -Force | Out-Null
Start-ScheduledTask -TaskName $name
Start-Sleep -Seconds 2
Get-ScheduledTask -TaskName $name | Format-List TaskName,State
Write-Host 'App started in the console desktop (the streamed 720p screen), not in this RDP session.'
