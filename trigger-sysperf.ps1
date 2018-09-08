$action = new-scheduledtaskaction -execute powershell.exe -argumentlist $("-command $(resolve-path '.\log-sysperf.ps1')")
$trigger = new-scheduledtasktrigger -once -at (get-date) -repetitioninterval (new-timespan -minutes 1)

register-scheduledtask -action $action -trigger $trigger -user "NT AUTHORITY\SYSTEM" -taskname "Log System Performance" -description "runs script to log system performance of average processor load and ram usage"

