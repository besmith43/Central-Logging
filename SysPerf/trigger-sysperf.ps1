$action = new-scheduledtaskaction -execute powershell.exe -argument $("-Noninteractive -NoProfile -ExecutionPolicy Bypass -command C:\Temp\SysPerf\log-sysperf.ps1")
$trigger = new-scheduledtasktrigger -once -at (get-date) -repetitioninterval (new-timespan -minutes 1)
$settings = new-scheduledtasksettingsset -dontstopifgoingonbatteries -startwhenavailable
$principal = New-ScheduledTaskPrincipal -userid "NT Authority\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

register-scheduledtask -action $action -trigger $trigger -taskname "Log System Performance" -Principal $principal -settings $settings -description "runs script to log system performance of average processor load and ram usage"

