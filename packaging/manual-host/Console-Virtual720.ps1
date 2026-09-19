#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
 [ValidateSet('Start','Stop','Status','Credentials','RevokeAccess')][string]$Action='Status',
 [string]$ConsoleUser='runneradmin',
 [string]$HostDirectory=$PSScriptRoot
)
$ErrorActionPreference='Stop'
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$admin) {throw 'Administrator PowerShell required. No automatic elevation.'}
$name='XyDesk-Virtual720-Console'
$engine=[IO.Path]::GetFullPath((Join-Path $HostDirectory 'xydesk-host.exe'))
$account=New-Object Security.Principal.NTAccount("$env:COMPUTERNAME\$ConsoleUser")
$sid=$account.Translate([Security.Principal.SecurityIdentifier]).Value
$profile=Get-CimInstance Win32_UserProfile | Where-Object {$_.SID -eq $sid}
if (!$profile) {throw 'Console user profile not found. No account created or session moved.'}
$state=Join-Path $profile.LocalPath 'AppData\Local\XyDesk-RemoteCore-Test'
if (-not ('XyDeskConsoleSession' -as [type])) {
 Add-Type 'using System.Runtime.InteropServices; public static class XyDeskConsoleSession { [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId(); }'
}
$consoleSession=[XyDeskConsoleSession]::WTSGetActiveConsoleSessionId()
function Get-OwnedHost {
 @(Get-CimInstance Win32_Process -Filter "Name='xydesk-host.exe'" | Where-Object {
   if ($_.ExecutablePath -ine $engine -or $_.SessionId -ne $consoleSession) {return $false}
   $owner=Invoke-CimMethod -InputObject $_ -MethodName GetOwnerSid
   $owner.ReturnValue -eq 0 -and $owner.Sid -eq $sid
 })
}
$task=Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
if ($task) {
 $registeredSid=if ($task.Principal.UserId -match '^S-1-') {$task.Principal.UserId} else {(New-Object Security.Principal.NTAccount($task.Principal.UserId)).Translate([Security.Principal.SecurityIdentifier]).Value}
 if ($registeredSid -ne $sid) {throw 'Task belongs to another account. Refusing takeover.'}
 $arguments=($task.Actions | Select-Object -First 1).Arguments
 if ($arguments -match '-EncodedCommand\s+(\S+)') {
  try {$arguments=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1]))}catch{throw 'Unknown task command.'}
 }
 if ($arguments -notmatch 'Start-Virtual720\.ps1|Console-Worker\.ps1') {throw 'Unknown task action. Refusing takeover.'}
}
if ($Action -eq 'Stop') {
 if (!$PSCmdlet.ShouldProcess('Only the XyDesk console task and its owned engine','Stop (RDP remains connected)')) {return}
 $owned=Get-OwnedHost
 if ($task) {Disable-ScheduledTask -TaskName $name | Out-Null; Stop-ScheduledTask -TaskName $name; Start-Sleep -Seconds 2}
 foreach ($p in $owned) {
  $now=Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ProcessId)"
  if ($now -and $now.CreationDate -eq $p.CreationDate -and $now.ExecutablePath -ieq $engine) {Stop-Process -Id $p.ProcessId -Force}
 }
 Write-Host 'Console host stopped. Task disabled until Start. Identity, driver, Windows and RDP preserved.'
 return
}
if ($Action -eq 'Credentials') {
 Write-Warning 'Private connection details. Do not send this output or a screenshot to chat.'
 Write-Host 'Device ID:'; Get-Content (Join-Path $state 'device_id')
 Write-Host 'Password:'; Get-Content (Join-Path $state 'password')
 return
}
if ($Action -eq 'RevokeAccess') {
 if (!$PSCmdlet.ShouldProcess('All remembered browsers for this console identity','Revoke access')) {return}
 $old=$env:XYDESK_HOME
 try {$env:XYDESK_HOME=$state; & $engine --revoke-remembered; if ($LASTEXITCODE -ne 0){throw 'Revoke failed.'}}
 finally {$env:XYDESK_HOME=$old}
 return
}
if ($Action -eq 'Start') {
 if (!$PSCmdlet.ShouldProcess("Existing logged-in $ConsoleUser console",'Start Virtual720 without RDP disconnect')) {return}
 & (Join-Path $HostDirectory 'Start-TestHost.ps1') -CheckOnly
 $owned=Get-OwnedHost
 if ($owned.Count -gt 0 -or ($task -and $task.State -eq 'Running')) {throw 'Console host/task already running. Use Status, or Stop before replacing it. No duplicate started.'}
 $worker=Join-Path $HostDirectory 'Console-Worker.ps1'
 if (!(Test-Path -LiteralPath $worker)) {throw 'Console worker missing.'}
 $actionSpec=New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -File "'+$worker+'"') -WorkingDirectory $HostDirectory
 $principal=New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$ConsoleUser" -LogonType Interactive -RunLevel Highest
 $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
 Register-ScheduledTask -TaskName $name -Action $actionSpec -Principal $principal -Settings $settings -Description 'XyDesk console Virtual720; explicit manual start, owned process tree' -Force | Out-Null
 Start-ScheduledTask -TaskName $name
 Start-Sleep -Seconds 8
}
Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue | Format-List TaskName,State
Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue | Format-List LastRunTime,LastTaskResult
Get-OwnedHost | Format-Table Name,ProcessId,SessionId -AutoSize
$log=Join-Path $state 'console-status.log'
if (Test-Path $log) {Get-Content -LiteralPath $log -Tail 15}
Write-Host 'Running is process status, not proof of signaling or streaming. Status log omits credentials.'
