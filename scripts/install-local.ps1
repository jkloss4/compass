<#
.SYNOPSIS
  Copies the addon folder from this repo into the WoW AddOns folder (for testing local changes).
.PARAMETER AddOnsPath
  Path to Interface\AddOns. Defaults to the retail install used on this machine.
#>
param(
  [string]$AddOnsPath = "C:\Games\Battle.net\Games\World of Warcraft\_retail_\Interface\AddOns"
)
$repo = Split-Path -Parent $PSScriptRoot
foreach ($name in "Compass") {
  # /MIR makes the installed folder an exact mirror (removes files deleted from the repo); only touches this folder.
  robocopy (Join-Path $repo $name) (Join-Path $AddOnsPath $name) /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $name (exit $LASTEXITCODE)" }
  Write-Host "installed $name"
}
Write-Host "Done. In game: /reload"

# robocopy exit codes 1-7 mean success; don't leak them as the script's exit code
exit 0
