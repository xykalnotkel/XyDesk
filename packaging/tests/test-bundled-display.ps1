$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot '..\manual-host'
$hash=(Get-FileHash (Join-Path $root 'VirtualDisplayDriver.zip') -Algorithm SHA256).Hash.ToLowerInvariant()
if($hash -ne 'e24210692b442b39af763536330ce78b423f19342b7a7792c26de3944e418b3a'){throw 'Bundled driver changed'}
# Existing device path must exit without invoking the provisioner.
function Get-PnpDevice {param([switch]$PresentOnly,$ErrorAction) [pscustomobject]@{InstanceId='ROOT\MTTVDD\0000';Status='OK';FriendlyName='Virtual Display Driver'}}
& (Join-Path $root 'Configure-Display.ps1') -NoPause -WhatIf
if($LASTEXITCODE){throw 'Configuration guard failed'}
Write-Host 'Bundled hash and existing-device no-change path PASS; no driver installation performed.'
