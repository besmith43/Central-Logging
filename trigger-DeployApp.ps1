$action = new-scheduledtaskaction -execute powershell.exe -argumentlist $("-command $(resolve-path '.\deploy-app.ps1')")
$trigger = new-scheduledtasktrigger -daily -at 5pm
$settings = new-scheduledtasksettingsset -dontstopifgoingonbatteries -startwhenavailable

register-scheduledtask -action $action -trigger $trigger -user "NT AUTHORITY\SYSTEM" -taskname "Deploy Application" -runlevel Highest -settings $settings -description "runs script to deploy application to new systems as they are added to a domain OU"

