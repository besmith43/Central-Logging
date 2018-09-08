# get credentials

$user = "TTU\besmith2"

$pass_plain = get-content "password.txt"

$pass = $pass_plain | Convertto-securestring -asplaintext -force

$credential = New-Object -typename "System.Management.Automation.PSCredential" -argumentlist $user,$pass

# get date for folder name

$date = get-date -UFormat "%m-%d-%Y"

# get whitelist contents

$whitelist = get-content "$PSScriptRoot\whitelist.txt"

# foreach computer in whitelist

foreach ($computer in $whitelist)
{

	# test connection to computer

	if (test-connection -computername $computer -quiet)
	{

		# if successful; new-pssession

		$session = new-pssession -computername $computer -credential $credential

		# get-eventlog to csv to C:\temp\sysperf\logs

		$eventlogjob = invoke-command -session $session -scriptblock {

			new-item -erroraction ignore -itemtype directory -path C:\Temp\SysPerf\Eventlogs

			get-eventlog -logname "SysPerf" | export-csv "C:\Temp\SysPerf\Eventlogs\SysPerf.csv"

			get-eventlog -logname "Application" | export-csv "C:\Temp\SysPerf\Eventlogs\Application.csv"

			get-eventlog -logname "OAlerts" | export-csv "C:\Temp\SysPerf\Eventlogs\OAlerts.csv"

			get-eventlog -logname "Security" | export-csv "C:\Temp\SysPerf\Eventlogs\Security.csv"

			get-eventlog -logname "System" | export-csv "C:\Temp\SysPerf\Eventlogs\System.csv"

			get-eventlog -logname "Windows Powershell" | export-csv "C:\Temp\SysPerf\Eventlogs\Powershell.csv"

		} -AsJob

		$eventlogjob | wait-job

		# copy from session

		new-item -erroraction ignore -itemtype directory -path "$PSScriptRoot\$computer\"

		new-item -erroraction ignore -itemtype directory -path "$PSScriptRoot\$computer\$date\"

		copy-item -fromsession $session -path "C:\Temp\SysPerf\Eventlogs\*.csv" -Destination "$PSScriptRoot\$computer\$date\" -recurse

		# delete original and clear eventlogs

		$cleanupjob = invoke-command -session $session -scriptblock { remove-item -path "C:\Temp\SysPerf\Eventlogs\*.csv" } -AsJob
		$cleanupjob | wait-job

	}

		# else; send email with computer name to besmith@tntech.edu
	else
	{
		send-mailmessage -to besmith@tntech.edu -subject "Collect Eventlog Failed" -body "$computer was not online when an attempt was made to collect its eventlogs for the sysperf application"
	}

}
