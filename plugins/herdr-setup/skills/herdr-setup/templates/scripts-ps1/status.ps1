# Tab bar right edge: branch, change count, how many agents are waiting.
#
# IMPORTANT: HERDR_ACTIVE_PANE_CWD does not exist. Relying on it made cwd fall back to
# the server's working directory, so the branch never rendered. The focused pane has to
# come from `herdr pane current`.
$Herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }

function Get-HJ([string[]]$A) {
  try { (& $Herdr @A 2>$null | Out-String) | ConvertFrom-Json } catch { $null }
}

$out = ''
$d = (Get-HJ @('pane','current')).result.pane.cwd
if ($d) {
  $d = ($d -replace '^\\\?\', '' -replace '/', '\').TrimEnd('\')
  $b = git -C $d rev-parse --abbrev-ref HEAD 2>$null
  if ($LASTEXITCODE -eq 0 -and $b) {
    $n  = (git -C $d status --porcelain 2>$null | Measure-Object -Line).Lines
    $ab = git -C $d rev-list --left-right --count '@{u}...HEAD' 2>$null
    $sync = ''
    if ($ab) { $p = $ab -split '\s+'; if ([int]$p[1] -gt 0) { $sync += "^$($p[1])" }; if ([int]$p[0] -gt 0) { $sync += "v$($p[0])" } }
    $out = $b.Trim()
    if ($n -gt 0) { $out += " +-$n" }
    if ($sync)    { $out += " $sync" }
  }
}
$agents = (Get-HJ @('agent','list')).result.agents
$w = @($agents | Where-Object { $_.agent_status -in 'blocked','done' }).Count
if ($w -gt 0) { $out += "  !$w" }
Write-Output $out
