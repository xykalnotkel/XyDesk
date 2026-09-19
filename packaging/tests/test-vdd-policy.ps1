$ErrorActionPreference='Stop'
$script = Join-Path $PSScriptRoot '../manual-host/Setup-VirtualDisplay.ps1'
$tokens=$null;$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
# Load only pure policy functions. No native helper, file, device, or network action.
$names=@('Get-XyDeskPnpDisposition','Test-XyDeskRollback','Assert-XyDeskResumeOwner','Test-XyDeskPendingReboot')
foreach($name in $names){
 $node=$ast.FindAll({param($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst]},$false)|Where-Object Name -eq $name
 if(@($node).Count -ne 1){throw "Missing policy function $name"}
 Invoke-Expression $node.Extent.Text
}
$count=0
function Assert($condition,$message){if(-not $condition){throw $message};$script:count++}
foreach($code in @(0,3010,5,3017,-1,1)){
 $d=Get-XyDeskPnpDisposition $code
 Assert ($d.Accepted -eq ($code -in @(0,3010))) "Accepted mismatch $code"
 Assert ($d.RebootRequired -eq ($code -eq 3010)) "Reboot mismatch $code"
 Assert ((Test-XyDeskRollback $true $d.Accepted) -eq (-not $d.Accepted)) "New device rollback $code"
 Assert (-not (Test-XyDeskRollback $false $d.Accepted)) "Existing device must not be removed $code"
}
$owner=[pscustomobject]@{createdBy='XyDesk setup';profile='1280x720';source='pinned';instanceId='ROOT\MTTVDD\0000'}
Assert-XyDeskResumeOwner $owner 'pinned';Assert $true 'Legacy interrupted ownership accepted'
foreach($field in @('createdBy','profile','source','instanceId')){
 $copy=$owner|ConvertTo-Json|ConvertFrom-Json;$copy.$field='foreign';$failed=$false
 try{Assert-XyDeskResumeOwner $copy 'pinned'}catch{$failed=$true}
 Assert $failed "Reject foreign $field"
}
$owner.instanceId=$null;$failed=$false
try{Assert-XyDeskResumeOwner $owner 'pinned'}catch{$failed=$true}
Assert $failed 'Reject legacy missing identity'
$owner|Add-Member -NotePropertyName schema -NotePropertyValue 2;Assert-XyDeskResumeOwner $owner 'pinned';Assert $true 'Allow schema2 staged ownership'
$pending=[pscustomobject]@{state='installed-reboot-required';bootId='bootA'}
Assert (Test-XyDeskPendingReboot $pending 'bootA') 'No repeated install before reboot'
Assert (-not (Test-XyDeskPendingReboot $pending 'bootB')) 'Changed boot can resume'
Assert (-not (Test-XyDeskPendingReboot $null 'bootA')) 'Fresh install is not pending'
$pending.state='staged-reboot-required';Assert (Test-XyDeskPendingReboot $pending 'bootA') 'Staging3010 also stops repeat'
Write-Host "VDD_POLICY_PASS: $count assertions; no driver installation/removal/reboot performed."
