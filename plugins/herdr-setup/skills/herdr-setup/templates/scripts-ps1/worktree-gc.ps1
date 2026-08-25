# Cleanup: worktrees whose branch is already merged into base.
. "$PSScriptRoot\lib.ps1"
$root = Get-HGitRoot (Get-HCwd)
if (-not $root) { exit 1 }
Set-Location $root
$base = Get-HBaseBranch '.'
git fetch -q --prune 2>$null

Write-Host "Merged worktrees (base: $base)`n" -ForegroundColor White
$cands = @()
git worktree list --porcelain | Select-String '^worktree ' | ForEach-Object {
  $wt = Convert-HPath (($_.ToString() -replace '^worktree ','').Trim())
  if ($wt -eq $root) { return }
  $b = git -C $wt rev-parse --abbrev-ref HEAD 2>$null
  git merge-base --is-ancestor $b $base 2>$null
  if ($LASTEXITCODE -eq 0) {
    $dirty = (git -C $wt status --porcelain | Measure-Object -Line).Lines
    Write-Host ("  {0}  -> {1} {2}" -f $b, $wt, $(if ($dirty -gt 0) { "(! $dirty changes)" } else { '' })) -ForegroundColor Yellow
    $cands += $wt
  }
}
if (-not $cands) { Write-Host "  nothing to clean"; Start-Sleep 2; exit 0 }

if ((Read-Host "`nDelete all? [y/N]") -notmatch '^[yY]') { exit 0 }
# `workspace list` has no cwd; for a worktree the path is worktree.checkout_path.
$wsList = (Get-HJson @('workspace','list')).result.workspaces
foreach ($wt in $cands) {
  $ws = ($wsList | Where-Object {
           $_.worktree.checkout_path -and (Convert-HPath $_.worktree.checkout_path) -eq $wt
         } | Select-Object -First 1).workspace_id
  if ($ws) {
    & $script:Herdr worktree remove --workspace $ws *> $null
    if ($LASTEXITCODE -ne 0) { & $script:Herdr worktree remove --workspace $ws --force *> $null }
  } else {
    git worktree remove $wt 2>$null; if ($LASTEXITCODE -ne 0) { git worktree remove --force $wt }
  }
  Write-Host "  OK $wt" -ForegroundColor Green
}
Start-Sleep 2
