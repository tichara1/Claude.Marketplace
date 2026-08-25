# "What changed" - files vs the base branch. fzf optional.
. "$PSScriptRoot\lib.ps1"

$dir  = Get-HCwd
$root = Get-HGitRoot $dir
if (-not $root) { Write-Host "not a git repo" -ForegroundColor Red; Start-Sleep 2; exit 1 }
Set-Location $root

$base = Get-HBaseBranch $root
$mb   = (git merge-base HEAD $base 2>$null); if (-not $mb) { $mb = 'HEAD' }

$files = @(
  (git diff --name-only $mb),
  (git diff --name-only),
  (git ls-files --others --exclude-standard)
) | ForEach-Object { $_ } | Where-Object { $_ } | Select-Object -Unique

if (-not $files) { Write-Host "Clean.  base: $base" -ForegroundColor Green; Start-Sleep 2; exit 0 }

$branch = git rev-parse --abbrev-ref HEAD
Write-Host "$branch" -ForegroundColor White -NoNewline
Write-Host " vs " -NoNewline; Write-Host $base -ForegroundColor Cyan -NoNewline
Write-Host "   $(@($files).Count) files   $((git diff --shortstat $mb).Trim())`n"

if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
  git -c color.ui=always diff --stat $mb
  Write-Host "`n(fzf not installed -> listing only)" -ForegroundColor DarkGray
  Read-Host "Enter closes"; exit 0
}

$prev = "git -c color.ui=always diff $mb -- {} | delta 2>nul || git -c color.ui=always diff $mb -- {}"
$sel = $files | fzf --ansi --multi --height=100% --border `
  --header="enter=primary editor  ctrl-e=secondary  ctrl-y=copy  ctrl-a=send to agent" `
  --preview=$prev --preview-window="right,65%,border-left" `
  --expect=ctrl-e,ctrl-y,ctrl-a
if (-not $sel) { exit 0 }

$key = $sel[0]
if ($sel.Count -lt 2) { exit 0 }   # only the --expect key line, nothing selected

# @() is MANDATORY here. Without it a single selected file makes $picks a String, not
# an array, and $picks[0] returns the first CHARACTER ("C" of "C:\..."). The editor
# then receives the relative path "C" and opens "<cwd>\C" instead of the file.
$picks = @($sel[1..($sel.Count - 1)] | ForEach-Object { Join-Path $root $_ })

switch ($key) {
  'ctrl-e' { & "$PSScriptRoot\open-editor.ps1" $global:SecondaryEditor $picks[0] }
  'ctrl-y' { ($picks -join "`n") | Set-Clipboard }
  'ctrl-a' { & "$PSScriptRoot\send-to-agent.ps1" @picks }
  default  { & "$PSScriptRoot\open-editor.ps1" $global:PrimaryEditor $picks[0] }
}
