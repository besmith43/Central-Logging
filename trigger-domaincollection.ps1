$action = new-scheduledtaskaction -execute powershell.exe -argumentlist $("-command $(resolve-path '.\collect-eventlogs.ps1')")
$trigger = new-scheduledtasktrigger -weekly -daysofweek Sunday -at 8am 
$settings = new-scheduledtasksettingsset -dontstopifgoingonbatteries -startwhenavailable

register-scheduledtask -action $action -trigger $trigger -user "NT AUTHORITY\SYSTEM" -taskname "Collect Eventlogs" -runlevel Highest -settings $settings -description "runs script to collect the eventlogs of all computers on the whitelist (that is with the sysperf application installed and running)"

