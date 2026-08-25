# Event hook: workspace.created -> start the agent in the root pane.
#
# IMPORTANT: creating a worktree emits BOTH worktree.created AND workspace.created.
# Worktrees are skipped here and handled by bootstrap-worktree.ps1, otherwise the
# agent would start twice. The discriminator is data.workspace.worktree - the
# workspace.created payload carries no `branch` field, so testing for one fails.
. "$PSScriptRoot\lib.ps1"
if (-not $global:AgentAutostart) { exit 0 }

$ev = Get-HEventJson
if (-not $ev) { exit 0 }
$ws = $ev.data.workspace
if (-not $ws.workspace_id) { exit 0 }
if ($ws.worktree) { exit 0 }

# The workspace.created payload has no cwd - it must be fetched from the server.
$cwd = Get-HWorkspacePath $ws.workspace_id
if (-not $cwd) { exit 0 }

git -C $cwd rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }        # git repos only

Start-Sleep -Milliseconds 1200
$pane = Get-HPaneOfWorkspace $ws.workspace_id
if ($pane) { Start-HAgent $pane (Split-Path $cwd -Leaf) | Out-Null }
