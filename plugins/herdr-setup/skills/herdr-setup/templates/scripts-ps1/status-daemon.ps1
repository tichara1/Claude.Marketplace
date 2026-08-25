# Background poller: fills the sidebar tokens $mod, $untracked and $sync per space.
#
# IMPORTANT: `workspace list` has NO cwd field. A loop testing $w.cwd skips every
# workspace and reports nothing, forever, while looking perfectly healthy.
# Get-HWorkspacePath resolves it via worktree.checkout_path or the first pane.
. "$PSScriptRoot\lib.ps1"

# Single instance across the whole user session. A pid file is not enough:
# HERDR_PLUGIN_STATE_DIR only exists in plugin context, so a manual run would track
# its state elsewhere and orphan processes accumulate.
$mutex = New-Object System.Threading.Mutex($false, 'Global\herdr-setup-status-daemon')
if (-not $mutex.WaitOne(0)) { exit 0 }

# Fetch must never block on credentials - without this the daemon freezes forever on
# a repo that asks for a password.
$env:GIT_TERMINAL_PROMPT = '0'

$interval  = $global:StatusInterval
$lastFetch = @{}

# Dedupe key for fetching. Several worktrees share one parent repo, so fetch once per
# repo rather than once per workspace.
function Get-RepoKey([string]$Dir) {
  $k = git -C $Dir rev-parse --path-format=absolute --git-common-dir 2>$null
  if ($LASTEXITCODE -eq 0 -and $k) { return $k.Trim().ToLowerInvariant() }
  return $null
}

function Invoke-RepoFetch([string]$Dir, [string]$Key) {
  if ($global:FetchIntervalSeconds -le 0) { return }
  $last = $lastFetch[$Key]
  if ($last -and ((Get-Date) - $last).TotalSeconds -lt $global:FetchIntervalSeconds) { return }
  # Stamp even on failure so an unreachable remote is not retried every cycle.
  $lastFetch[$Key] = Get-Date
  try {
    $p = Start-Process -FilePath 'git' -NoNewWindow -PassThru `
           -ArgumentList @('-C', $Dir, 'fetch', '--quiet', '--prune')
    if (-not $p.WaitForExit($global:FetchTimeoutMs)) { try { $p.Kill() } catch {} }
  } catch { }
}

function Get-GitTokens([string]$Dir) {
  # -uall expands untracked directories into individual files; without it a whole new
  # directory counts as a single entry.
  $lines = @(git -C $Dir status --porcelain --untracked-files=all 2>$null)
  if ($LASTEXITCODE -ne 0) { return $null }

  # NOT -like '??*'. In PowerShell '?' is a single-character wildcard, so '??*' matches
  # every line and everything would be counted as untracked. StartsWith is literal.
  $untracked = @($lines | Where-Object { $_.StartsWith('??') }).Count
  $mod       = $lines.Count - $untracked

  $sync = ''
  $ab = git -C $Dir rev-list --left-right --count '@{u}...HEAD' 2>$null
  if ($ab) {
    # left = commits only upstream (behind), right = commits only in HEAD (ahead)
    $p = $ab -split '\s+'
    if ([int]$p[1] -gt 0) { $sync += "^$($p[1])" }
    if ([int]$p[0] -gt 0) { $sync += "v$($p[0])" }
  }

  @{
    mod       = $(if ($mod -gt 0)       { "~$mod" }       else { '' })
    untracked = $(if ($untracked -gt 0) { "?$untracked" } else { '' })
    sync      = $sync
  }
}

while ($true) {
  foreach ($w in (Get-HJson @('workspace', 'list')).result.workspaces) {
    $d = Get-HWorkspacePath $w.workspace_id
    if (-not $d) { continue }
    $key = Get-RepoKey $d
    if (-not $key) { continue }        # not a git repo

    # Tokens are reported BEFORE fetching so the sidebar fills immediately on startup
    # instead of waiting on the network. The fetch shows up next cycle.
    $t = Get-GitTokens $d
    if ($t) {
      & $script:Herdr workspace report-metadata $w.workspace_id `
        --source "plugin:$global:PluginId" `
        --token "mod=$($t.mod)" --token "untracked=$($t.untracked)" --token "sync=$($t.sync)" `
        --ttl-ms (($interval + 60) * 1000) *> $null
    }
    Invoke-RepoFetch $d $key
  }
  Start-Sleep -Seconds $interval
}
