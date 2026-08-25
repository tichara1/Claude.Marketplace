# open-editor.ps1 <rider|code|cursor|idea|explorer> [path]
param([string]$What = '', [string]$Target = '')
. "$PSScriptRoot\lib.ps1"

if (-not $What) { $What = $global:PrimaryEditor }

if (-not $Target) {
  $d = Get-HCwd
  $r = Get-HGitRoot $d
  $Target = if ($r) { $r } else { $d }
}

# The path must be passed to -ArgumentList EXPLICITLY QUOTED. A JetBrains Toolbox shim
# builds its argument list with `set "args=%args%%1 "` and then calls `start`, so an
# unquoted path containing a space falls apart - `start` would take "C:\Program" as the
# program name. The trailing backslash must be trimmed or it escapes the closing quote.
function Start-Ide([string[]]$Candidates, [string]$AppFallback) {
  $arg = '"' + $Target.TrimEnd('\') + '"'
  foreach ($c in $Candidates) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { Start-Process -FilePath $cmd.Source -ArgumentList $arg; return $true }
  }
  # JetBrains Toolbox shim directory
  $tb = Join-Path $env:LOCALAPPDATA 'JetBrains\Toolbox\scripts'
  foreach ($c in $Candidates) {
    $p = Join-Path $tb "$c.cmd"
    if (Test-Path $p) { Start-Process -FilePath $p -ArgumentList $arg; return $true }
  }
  if ($AppFallback) {
    $p = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs", "$env:ProgramFiles" -Filter $AppFallback -Recurse -ErrorAction SilentlyContinue -Depth 4 | Select-Object -First 1
    if ($p) { Start-Process -FilePath $p.FullName -ArgumentList $arg; return $true }
  }
  return $false
}

$done = switch ($What) {
  'rider'    { Start-Ide @('rider', 'rider64') 'rider64.exe' }
  'code'     { Start-Ide @('code', 'code-insiders') 'Code.exe' }
  'cursor'   { Start-Ide @('cursor') 'Cursor.exe' }
  'idea'     { Start-Ide @('idea', 'idea64') 'idea64.exe' }
  'subl'     { Start-Ide @('subl') 'sublime_text.exe' }
  'explorer' { Start-Process explorer.exe $Target; $true }
  default    { Write-Host "unknown editor: $What" -ForegroundColor Red; $false }
}

if ($done) { Invoke-HNotify $What (Split-Path $Target -Leaf) }
else { Invoke-HNotify "Could not find $What" "add it to PATH" }
