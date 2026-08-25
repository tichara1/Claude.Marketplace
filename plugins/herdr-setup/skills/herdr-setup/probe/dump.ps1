# Calibration probe. Dumps every HERDR_* variable so the installer can learn the
# real shape of HERDR_PLUGIN_CONTEXT_JSON / HERDR_PLUGIN_EVENT_JSON on this build.
# Argument 1 is a tag identifying which trigger fired.
param([string]$Tag = 'unknown')

$dir = if ($env:HERDR_PLUGIN_STATE_DIR) { $env:HERDR_PLUGIN_STATE_DIR } else { $env:TEMP }
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$out = Join-Path $dir "probe-$Tag.json"

$vars = @{}
Get-ChildItem env: | Where-Object { $_.Name -like 'HERDR*' } | ForEach-Object {
  $vars[$_.Name] = $_.Value
}

# Record which names are ABSENT too - that is what caught the scripts relying on
# HERDR_ACTIVE_PANE_CWD, which exists in the binary but is never set here.
$payload = [ordered]@{
  tag          = $Tag
  cwd          = (Get-Location).Path
  script_root  = $PSScriptRoot
  herdr_vars   = $vars
  all_var_names = (Get-ChildItem env: | Select-Object -ExpandProperty Name | Sort-Object)
}

$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $out -Encoding UTF8
Write-Output "probe:$out"
