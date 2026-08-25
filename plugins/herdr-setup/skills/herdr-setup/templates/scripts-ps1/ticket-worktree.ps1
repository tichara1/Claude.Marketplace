# Link handler: Ctrl+click a GitHub issue / Jira ticket -> worktree named after it.
. "$PSScriptRoot\lib.ps1"
$url = $env:HERDR_PLUGIN_CLICKED_URL
if (-not $url -and $args.Count -gt 0) { $url = $args[0] }
if (-not $url) { exit 0 }

$root = Get-HGitRoot (Get-HCwd)
if (-not $root) { exit 0 }

$key = switch -Regex ($url) {
  'atlassian\.net/browse/' { ($url -split '/')[-1] }
  'github\.com/'           { "gh-$(($url -split '/')[-1])" }
  default                  { "task-$(Get-Date -Format HHmm)" }
}
$branch = "$global:WorktreePrefix/$(Get-HSlug $key)"

$out = & $script:Herdr worktree create --cwd $root --branch $branch --label $key --focus 2>&1 | Out-String
if ($out -match '"error"') { Invoke-HNotify "Worktree failed" $key; exit 1 }
$ws = ($out | ConvertFrom-Json).result.workspace.workspace_id
if ($ws) { & $script:Herdr workspace report-metadata $ws --source "plugin:$global:PluginId" --token "ticket=$key" *> $null }
Invoke-HNotify "Worktree from ticket" $key 'done'
