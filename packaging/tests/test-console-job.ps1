# No driver install, account/session changes, or scheduled task registration.
$ErrorActionPreference='Stop'
$worker=(Resolve-Path (Join-Path $PSScriptRoot '../manual-host/Console-Worker.ps1')).Path
$root=Join-Path $env:TEMP ('XyDesk-JobTest-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
$pidFile=Join-Path $root 'child.txt'
$body=@'
$ErrorActionPreference='Stop'
& '__WORKER__' -CheckOnly
[XyDeskConsoleLifetime]::OwnChildren()
$child=Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList '-NoProfile -Command Start-Sleep -Seconds 120' -PassThru
$child.Id | Set-Content '__PID__'
Start-Sleep -Seconds 120
'@
$body=$body.Replace('__WORKER__',$worker.Replace("'","''")).Replace('__PID__',$pidFile.Replace("'","''"))
$encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
$shell=(Get-Process -Id $PID).Path
$parent=$null;$child=$null
try {
 $parent=Start-Process -FilePath $shell -ArgumentList "-NoProfile -NonInteractive -EncodedCommand $encoded" -RedirectStandardOutput (Join-Path $root 'out.txt') -RedirectStandardError (Join-Path $root 'err.txt') -PassThru
 for($i=0;$i -lt 60;$i++){if(Test-Path $pidFile){break};if($parent.HasExited){throw (Get-Content (Join-Path $root 'err.txt') -Raw)};Start-Sleep -Milliseconds 250}
 if(!(Test-Path $pidFile)){throw 'Child PID was not recorded.'}
 $child=Get-Process -Id ([int](Get-Content $pidFile -Raw))
 Stop-Process -Id $parent.Id -Force
 for($i=0;$i -lt 40;$i++){if($child.HasExited){break};Start-Sleep -Milliseconds 100}
 if(!$child.HasExited){throw 'Stopping worker left its child alive.'}
 Write-Host 'CONSOLE_JOB_PASS: parent termination killed owned child; no driver/RDP changes.'
} finally {
 if($parent -and !$parent.HasExited){$parent.Kill()}
 if($child -and !$child.HasExited){$child.Kill()}
 Remove-Item -LiteralPath $root -Recurse -Force
}
