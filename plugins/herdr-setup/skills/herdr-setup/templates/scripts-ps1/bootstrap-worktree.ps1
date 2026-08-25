# Event hook: worktree.created
#   1) copy untracked local files from the main checkout
#   2) dev layout (agent | shell / test)
#   3) start the agent with branch context
. "$PSScriptRoot\lib.ps1"

$ev     = (Get-HEventJson).data
$ws     = $ev.workspace.workspace_id
$path   = Convert-HPath $ev.worktree.path
$branch = $ev.worktree.branch
if (-not $ws -or -not $path) { exit 0 }

# --- 1) local files -----------------------------------------------------------
$main = (git -C $path worktree list --porcelain 2>$null | Select-String '^worktree ' | Select-Object -First 1)
if ($main) {
  $mainPath = Convert-HPath (($main.ToString() -replace '^worktree ', '').Trim())
  if ($mainPath -and $mainPath -ne $path) {
    # BootstrapCopy holds file names, not glob patterns - Get-ChildItem -Path cannot
    # expand `**`, so search recursively by -Filter and drop build directories.
    foreach ($nameOnly in $global:BootstrapCopy) {
      Get-ChildItem -Path $mainPath -Filter (Split-Path $nameOnly -Leaf) -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|node_modules|\.git)\\' } |
        ForEach-Object {
          $rel = $_.FullName.Substring($mainPath.Length).TrimStart('\')
          $dst = Join-Path $path $rel
          if (-not (Test-Path $dst)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item $_.FullName $dst
          }
        }
    }
  }
}

# --- 2) layout ----------------------------------------------------------------
$root  = Get-HPaneOfWorkspace $ws
$right = (Get-HJson @('pane', 'split', $root, '--direction', 'right', '--ratio', '0.45', '--no-focus')).result.pane.pane_id
if ($right) { & $script:Herdr pane split $right --direction down --ratio 0.5 --no-focus *> $null }
& $script:Herdr pane rename $root $global:AgentKind *> $null

# --- 3) restore + agent -------------------------------------------------------
if ($right -and $global:WorktreeSetupCommand) {
  & $script:Herdr pane run $right "cd '$path'; $global:WorktreeSetupCommand" *> $null
}
$prompt = $global:WorktreePrompt -replace '\{branch\}', $branch -replace '\{path\}', $path
Start-HAgent $root ($(if ($branch) { $branch } else { 'worktree' })) $prompt | Out-Null

Invoke-HNotify "Worktree ready" ($(if ($branch) { $branch } else { Split-Path $path -Leaf })) 'done'
