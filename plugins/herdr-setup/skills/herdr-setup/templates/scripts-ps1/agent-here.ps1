# Start the agent in the current (or root) pane of this workspace.
. "$PSScriptRoot\lib.ps1"
$ws = Get-HWorkspaceId
$pane = if ($env:HERDR_PANE_ID) { $env:HERDR_PANE_ID } else { Get-HPaneOfWorkspace $ws }
if (-not $pane) { exit 1 }
$label = Split-Path (Get-HCwd) -Leaf
$name = Start-HAgent $pane $label
if ($name) { Invoke-HNotify "Agent running" "$label ($name)" 'done' }
