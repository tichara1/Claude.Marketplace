# Open a plugin pane entrypoint as a popup (action -> popup bridge).
. "$PSScriptRoot\lib.ps1"
$ep = if ($args.Count -gt 0) { $args[0] } else { 'diff' }
$pluginId = if ($env:HERDR_PLUGIN_ID) { $env:HERDR_PLUGIN_ID } else { $global:PluginId }
# NOTE: `--placement popup` is valid even though `plugin pane open --help` omits it.
& $script:Herdr plugin pane open --plugin $pluginId --entrypoint $ep --placement popup *> $null
