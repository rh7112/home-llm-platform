# Registers cloudflared as a Scheduled Task instead of a Windows Service.
#
# Why: on Windows, `cloudflared service install` silently ignores any --config
# flag passed at install time. When the resulting service runs as LocalSystem,
# it looks for its config in LocalSystem's own profile
# (C:\Windows\System32\config\systemprofile\.cloudflared\), not yours -- so it
# crash-loops on startup unless you manually copy everything there. A Scheduled
# Task running as your own user sidesteps all of that: it uses your normal
# %USERPROFILE%\.cloudflared\ folder, exactly like running the command manually
# in a terminal (which always worked).
#
# Fill in your own username, cloudflared install path, config path, and tunnel
# name before running.

$cloudflaredExe = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
$configPath     = "$env:USERPROFILE\.cloudflared\config.yml"
$tunnelName     = "<your-tunnel-name>"
$taskUser       = "$env:USERNAME"

$action = New-ScheduledTaskAction -Execute $cloudflaredExe `
    -Argument "--config `"$configPath`" --loglevel info --logfile `"$env:USERPROFILE\.cloudflared\tunnel.log`" tunnel run $tunnelName"
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId $taskUser -LogonType S4U -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName "CloudflaredTunnel" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
Start-ScheduledTask -TaskName "CloudflaredTunnel"

Start-Sleep -Seconds 5
Get-ScheduledTask -TaskName "CloudflaredTunnel" | Get-ScheduledTaskInfo
& $cloudflaredExe tunnel info $tunnelName
