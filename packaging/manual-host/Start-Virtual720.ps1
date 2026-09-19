[CmdletBinding()]
param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
# Distinct entry point: never silently fall back to the RDP display.
& (Join-Path $PSScriptRoot 'Start-TestHost.ps1') -CheckOnly:$CheckOnly -VirtualDisplay720p
