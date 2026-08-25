# Sidebar: show only agents in blocked/done state. Press again to restore.
. "$PSScriptRoot\lib.ps1"
$stateDir = if ($env:HERDR_PLUGIN_STATE_DIR) { $env:HERDR_PLUGIN_STATE_DIR } else { $env:TEMP }
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$flag = Join-Path $stateDir 'attention.on'

# NOTE: `source` must be "plugin:<real-plugin-id>" - an arbitrary string returns
# plugin_not_found.
$src = "plugin:$global:PluginId"

if (Test-Path $flag) {
  Remove-Item $flag -Force
  Invoke-HSocket "{`"id`":`"v`",`"method`":`"agent.view.clear`",`"params`":{`"source`":`"$src`"}}" | Out-Null
  Invoke-HNotify "Sidebar" "all agents"
} else {
  New-Item -ItemType File -Path $flag -Force | Out-Null
  $req = "{`"id`":`"v`",`"method`":`"agent.view.set`",`"params`":{`"source`":`"$src`",`"label`":`"waiting`",`"filter`":{`"op`":`"in`",`"field`":`"status`",`"values`":[`"blocked`",`"done`"]},`"sort`":[{`"field`":`"attention`",`"order`":`"desc`"},{`"field`":`"state_change_seq`",`"order`":`"desc`"}]}}"
  Invoke-HSocket $req | Out-Null
  Invoke-HNotify "Sidebar" "blocked / done only" 'request'
}
