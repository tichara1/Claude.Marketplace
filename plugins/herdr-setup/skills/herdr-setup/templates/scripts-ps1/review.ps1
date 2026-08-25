# Pre-commit review: diff -> agent in headless mode -> output into the popup.
. "$PSScriptRoot\lib.ps1"
$root = Get-HGitRoot (Get-HCwd)
if ($root) { Set-Location $root }
$base = Get-HBaseBranch '.'
$mb   = (git merge-base HEAD $base 2>$null); if (-not $mb) { $mb = 'HEAD' }
$diff = ((git diff $mb) + (git diff --cached)) -join "`n"
if (-not $diff.Trim()) { Write-Host "No diff."; Start-Sleep 2; exit 0 }

Write-Host "Review $(git rev-parse --abbrev-ref HEAD) vs $base`n" -ForegroundColor White
$diff | & $global:AgentKind -p $global:ReviewPrompt | Out-Host
Read-Host "`nEnter closes"
