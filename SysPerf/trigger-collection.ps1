$action = new-scheduledtaskaction -execute powershell.exe -argument $("-Noninteractive -NoProfile -ExecutionPolicy Bypass -command C:\Temp\SysPerf\collect-sysinfo.ps1")
$trigger = new-scheduledtasktrigger -daily -at 9am 
$settings = new-scheduledtasksettingsset -dontstopifgoingonbatteries -startwhenavailable

register-scheduledtask -action $action -trigger $trigger -user "NT AUTHORITY\SYSTEM" -taskname "Log System Information" -runlevel Highest -settings $settings -description "runs script to collect and log system information daily such as hard drive conditions, bios version, OS build, gpu and monitor setup, and installed programs"

