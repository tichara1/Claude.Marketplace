# New worktree with a branch prefix. Bound to a popup key.
. "$PSScriptRoot\lib.ps1"

$dir  = Get-HCwd
$root = Get-HGitRoot $dir
if (-not $root) { Write-Host "This workspace is not a git repo." -ForegroundColor Red; Start-Sleep 2; exit 1 }
Set-Location $root

Write-Host "New worktree" -ForegroundColor White -NoNewline
Write-Host "  repo: $(Split-Path $root -Leaf)"
Write-Host "prefix: $global:WorktreePrefix/" -ForegroundColor Cyan
Write-Host "(change `$global:WorktreePrefix in settings.ps1)`n" -ForegroundColor DarkGray

$raw = Read-Host "name (e.g. 'kafka retry' or 'EETS-1234 toll sync')"
if (-not $raw.Trim()) { exit 0 }

$ticket = [regex]::Match($raw, '^[A-Z][A-Z0-9]+-[0-9]+').Value
if ($ticket) {
  $rest   = Get-HSlug ($raw.Substring($ticket.Length))
  $branch = "$global:WorktreePrefix/$($ticket.ToLower())-$rest".TrimEnd('-')
} else {
  $branch = "$global:WorktreePrefix/$(Get-HSlug $raw)"
}

$defBase = Get-HBaseBranch $root
$base = Read-Host "base ref [$defBase]"
if (-not $base) { $base = $defBase }

Write-Host "`n-> branch: " -NoNewline; Write-Host $branch -ForegroundColor Green
Write-Host "-> base:   $base`n"
if ((Read-Host "Create? [Y/n]") -match '^[nN]') { exit 0 }

$label = if ($ticket) { $ticket } else { Get-HSlug $raw }
$out = & $script:Herdr worktree create --cwd $root --branch $branch --base $base --label $label --focus 2>&1 | Out-String
if ($out -match '"error"') { Write-Host $out -ForegroundColor Red; Read-Host "Enter closes"; exit 1 }
Write-Host "OK - bootstrap runs in the background (worktree.created hook)" -ForegroundColor Green
Start-Sleep 1
