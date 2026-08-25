# Dev layout: [ agent | shell / test ]
. "$PSScriptRoot\lib.ps1"
$ws   = Get-HWorkspaceId
$root = if ($env:HERDR_PANE_ID) { $env:HERDR_PANE_ID } else { Get-HPaneOfWorkspace $ws }
if (-not $root) { exit 1 }
$right = (Get-HJson @('pane','split',$root,'--direction','right','--ratio','0.45','--no-focus')).result.pane.pane_id
if ($right) { & $script:Herdr pane split $right --direction down --ratio 0.5 --no-focus *> $null }
& $script:Herdr pane rename $root $global:AgentKind *> $null
Start-HAgent $root (Split-Path (Get-HCwd) -Leaf) | Out-Null
