# Send a list of files as a prompt to the agent running in this workspace.
. "$PSScriptRoot\lib.ps1"
if ($args.Count -eq 0) { exit 0 }
$ws = Get-HWorkspaceId
$a  = (Get-HJson @('agent','list')).result.agents | Where-Object { $_.workspace_id -eq $ws } | Select-Object -First 1
if (-not $a) { Invoke-HNotify "No agent" "no agent running in this workspace"; exit 0 }
$target = if ($a.name) { $a.name } else { $a.pane_id }
& $script:Herdr agent prompt $target "$($global:SendFilesPrompt): $($args -join ', ')" *> $null
Invoke-HNotify "Sent to agent" "$($args.Count) file(s)"
