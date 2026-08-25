# [[startup]] hook - launch the daemon in the background and exit (a hook is not a
# supervisor).
#
# IMPORTANT: [[startup]] only runs at SERVER START, not on plugin link/unlink. After
# changing the daemon you must restart the herdr server or run this script by hand.
#
# Double-launch is prevented by the daemon itself (a global mutex). A pid file here
# would not be enough - HERDR_PLUGIN_STATE_DIR only exists in plugin context, so a
# manual run would keep its state somewhere else.
Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden `
  -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\status-daemon.ps1") | Out-Null
