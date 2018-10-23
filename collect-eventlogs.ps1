function set-log
{
	param (
		[string]$message,
		[string]$logfile
	)

	write-host $message

	$date = get-date -format g

	$message = "$message - $date"

	if (!$(test-path -path "$PSScriptRoot\Logs"))
	{
		new-item -path "$PSScriptRoot\Logs\" -ItemType Directory
	}

	if (test-path -path "$PSScriptRoot\Logs\$logfile")
	{
		$message | out-file -filepath "$PSScriptRoot\Logs\$logfile" -append
	}
	else
	{
		new-item -path "$PSScriptRoot\Logs\$logfile" -ItemType "file"
		$message | out-file -filepath "$PSScriptRoot\Logs\$logfile" -append
	}
}

# get date for folder name

$date = get-date -UFormat "%m-%d-%Y"

# get whitelist contents

$whitelist = get-content "$PSScriptRoot\whitelist.txt"

# foreach computer in whitelist

foreach ($computer in $whitelist)
{

	# test connection to computer

	if (test-connection -computername $computer -quiet -count 1)
	{

		# if successful; new-pssession

		set-log -message "Attempting to connect to $computer" -logfile "Collection-log-$date.txt"

		$session = new-pssession -computername $computer

		if (!$session)
		{
			set-log -message "remote session failed to $computer" -logfile "Collection-log-$date.txt"
			continue
		}

		# get-eventlog to csv to C:\temp\sysperf\logs

		set-log -message "exporting eventlogs to csv on $computer" -logfile "Collection-log-$date.txt"

		$eventlogjob = invoke-command -session $session -scriptblock {

			new-item -erroraction ignore -itemtype directory -path C:\Temp\SysPerf\Eventlogs

			if ([System.Diagnostics.EventLog]::Exists('SysPerf'))
			{
				get-eventlog -logname "SysPerf" | export-csv "C:\Temp\SysPerf\Eventlogs\SysPerf.csv"
			}

			if ([System.Diagnostics.Eventlog]::Exists('Application'))
			{
				get-eventlog -logname "Application" | export-csv "C:\Temp\SysPerf\Eventlogs\Application.csv"
			}

			if ([System.Diagnostics.Eventlog]::Exists('OAlerts'))
			{
				get-eventlog -logname "OAlerts" | export-csv "C:\Temp\SysPerf\Eventlogs\OAlerts.csv"
			}

			if ([System.Diagnostics.Eventlog]::Exists('Security'))
			{
				get-eventlog -logname "Security" | export-csv "C:\Temp\SysPerf\Eventlogs\Security.csv"
			}

			if ([System.Diagnostics.Eventlog]::Exists('System'))
			{
				get-eventlog -logname "System" | export-csv "C:\Temp\SysPerf\Eventlogs\System.csv"
			}

			if ([System.Diagnostics.Eventlog]::Exists('Windows Powershell'))
			{
				get-eventlog -logname "Windows Powershell" | export-csv "C:\Temp\SysPerf\Eventlogs\Powershell.csv"
			}

		} -AsJob

		$eventlogjob | wait-job

		# copy from session

		new-item -erroraction ignore -itemtype directory -path "$PSScriptRoot\EventLogs\$computer\"

		new-item -erroraction ignore -itemtype directory -path "$PSScriptRoot\EventLogs\$computer\$date\"

		copy-item -FromSession $session -path "C:\Temp\SysPerf\Eventlogs\" -Destination "$PSScriptRoot\EventLogs\$computer\$date\" -Recurse

		move-item -path "$PSScriptRoot\EventLogs\$computer\$date\Eventlogs\*.csv" -Destination "$PSScriptRoot\EventLogs\$computer\$date\"

		remove-item -Path "$PSScriptRoot\EventLogs\$computer\$date\Eventlogs\"

		# delete original and clear eventlogs

		$cleanupjob = invoke-command -session $session -scriptblock { remove-item -path "C:\Temp\SysPerf\Eventlogs\*.csv" } -AsJob
		$cleanupjob | wait-job

		Remove-PSSession -Session $session

		set-log -message "starting script to process eventlogs collected from $computer" -logfile "Collection-log-$date.txt"
		
		$Command = "$PSScriptRoot\process-eventlog.ps1 -hostname $computer -date $date"

		Invoke-Expression -Command $Command
	}
	else
	{
		set-log -message "$computer was not online on $date" -logfile "Collection-log-$date.txt"
	}
}
