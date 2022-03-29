param (
#[System.Management.Automation.PSCredential]$Credential,
[string]$CollegeOU,
[switch]$UseBlackList,
[switch]$version
)

if ($version)
{
    $version_var = Get-Content -path "$PSScriptRoot\version.txt"
    write-host "Deploy SysPerf App Version $version_var"
    exit
}

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

if ($UseBlackList)
{
	if (test-path -Path "$PSScriptRoot\blacklist.txt")
	{
		$blacklist = get-content "$PSScriptRoot\blacklist.txt"
	}
	else
	{
		new-item -path "$PSScriptRoot\blacklist.txt" -ItemType "file"
		exit
	}

	foreach ($computer in $blacklist)
{

	# create PSSession

	if (Test-Connection -ComputerName $computer -Count 1 -Quiet)
	{
		$session = new-pssession -computername $computer

		if (!$session)
		{
			set-log -message "Failed to make connection with $computer"
			continue
		}

		set-log -message "Session created with $computer" -logfile "deployment-log.txt"
	}
	else
	{
		set-log -message "$computer was not online" -logfile "deployment-log.txt"
		continue
	}

	# Setting Execution Policy

	$exejob = Invoke-Command -Session $session -ScriptBlock {
		if ($(Get-ExecutionPolicy) -ne "Unrestricted")
		{
			Set-ExecutionPolicy Unrestricted
		}
	}
	$exejob | Wait-Job

	# check if 2 triggers are active, directory structure exists, and added to path

	$collectiontask = $Null
	$performancetask = $Null
	$directorystructure = $Null

	$collectiontask = Invoke-Command -Session $session -ScriptBlock { 
		$remote_collection_task = Get-ScheduledTask -TaskName "Log System Information" -ErrorAction SilentlyContinue
		return $remote_collection_task
	}

	$performancetask = Invoke-Command -Session $session -ScriptBlock {
		$remote_performance_task = Get-ScheduledTask -taskname "Log System Performance" -ErrorAction SilentlyContinue
		return $remote_performance_task
	}

	$directorystructure = invoke-command -session $session -scriptblock {
		$remote_directory_structure_test = test-path -path "C:\Temp\SysPerf"
		return $remote_directory_structure_test
	}

	# copy files into directory structure

	if (!$directorystructure)
	{
		set-log -message "Setting up folder structure on $computer" -logfile "deployment-log.txt"

		$directoryjob = Invoke-Command -Session $session -ScriptBlock {
			if (test-path -path C:\Temp\)
			{
				new-item -erroraction ignore -itemtype Directory -path C:\Temp\
			}
		}
		$directoryjob | Wait-Job
	}

	# testing that C:\Temp is hidden  (also for good measure)
	$hiddenjob = Invoke-Command -Session $session -ScriptBlock {
		if (!$($(get-item -path C:\Temp\ -Force).Attributes -match "Hidden"))
		{
			$(get-item -path C:\Temp\ -Force).attributes = "Hidden"
		}
	}
	$hiddenjob | Wait-Job

	# copying the files over regardless of the folder structure (basically for good measure)
	copy-item -tosession $session -path "$PSScriptRoot\SysPerf\" -Destination "C:\Temp\" -Recurse -Force

	# run scripts to create triggers

	if (!$collectiontask)
	{
		set-log -message "triggering daily collection on $computer" -logfile "deployment-log.txt"
		$collectionJob = invoke-command -session $session -scriptblock { Invoke-Expression -Command "C:\Temp\SysPerf\trigger-collection.ps1" } -AsJob
		$collectionJob | wait-job
	}

	if (!$performancetask)
	{
		set-log -message "triggering sysperf collection on $computer" -logfile "deployment-log.txt"
		$performancejob = invoke-command -session $session -scriptblock { Invoke-Expression -Command "C:\Temp\SysPerf\trigger-sysperf.ps1" } -AsJob
		$performancejob | wait-job
	}

	# run once

	$first_time = Invoke-Command -Session $session -ScriptBlock {
		Start-ScheduledTask -TaskName "Log System Performance"
		Start-ScheduledTask -TaskName "Log System Information"
	}
	$first_time | Wait-Job

	# check that SysPerf EventLog was made

	$sysperf_made = $Null

	$sysperf_made = Invoke-Command -Session $session -ScriptBlock {
		if ([System.Diagnostics.EventLog]::Exists('SysPerf'))
		{
			return $true
		}
		else
		{
			return $false
		}
	}

	if ($sysperf_made)
	{
		set-log -message "SysPerf Event Log was successfully made on $computer" -logfile "deployment-log.txt"
	}
	else
	{
		set-log -message "SysPerf Event Log was unsuccessful on $computer" -logfile "deployment-log.txt"
	}
	
	# add hostname to whitelist outside of PSSession
	
	$computer | out-file -filepath "$PSScriptRoot\whitelist.txt" -append

	# removing from blacklist array

	$blacklist = $blacklist | Where-Object { $_ -ne $computer }

	# close session connections

	remove-pssession -session $session
}

	# overwrite blacklist file with new blacklist after attempting to connect to every blacklisted computer

	$blacklist | Out-File -FilePath "$PSScriptRoot\blacklist.txt"

	exit
}

import-module ActiveDirectory

if (!$CollegeOU)
{
	#$OU = "OU=CoA&S Wks,OU=TTU Workstations,DC=tntech,DC=edu"
	$OU = "OU=English,OU=CoA&S Wks,OU=TTU Workstations,DC=tntech,DC=edu"
}
else
{
    $CollegeOU = $OU
}

# get root OU of College

#get-ADOrganizationalUnit -searchbase $OU -searchscope Subtree -Filter * | select-object name, DistinguishedName

# get whitelist of systems that already have it installed

$computers = get-adcomputer -filter * -searchbase $OU -property *

if (test-path -path "$PSScriptRoot\whitelist.txt")
{
	$whitelist = get-content "$PSScriptRoot\whitelist.txt"
}
else
{
	new-item -path "$PSScriptRoot\whitelist.txt" -ItemType "file"
}

if (test-path -Path "$PSScriptRoot\blacklist.txt")
{
	$blacklist = get-content "$PSScriptRoot\blacklist.txt"
}
else
{
	new-item -path "$PSScriptRoot\blacklist.txt" -ItemType "file"
}

$tobesetup = @()

# compare the 2 and use foreach loop to add each name that don't match to array

foreach ($computer in $computers)
{
	if ($computer.operatingsystemversion -match "10.0")
	{
		#write-host "$computer.name is Windows 10"
		$comp_name = $computer.name
		
		$ending = $comp_name.substring($comp_name.get_length() - 3)
		
		if ($ending -match "D")
		{
			#write-host "$computer.name is a destkop"
			$match = $whitelist | select-string $computer.name

			if (!$match)
			{
				#Write-Host "$computer.name is not a match for the whitelist"
				$string = $computer.name | out-string
				$string = $string.Trim()
				$tobesetup += $string
			}
		}
	}
}

# foreach loop over the array to deploy the app

foreach ($computer in $tobesetup)
{

	# create PSSession

	if (Test-Connection -ComputerName $computer -Count 1 -Quiet)
	{
		$session = new-pssession -computername $computer

		if (!$session)
		{
			set-log -message "Failed to make connection with $computer"
			$computer | out-file -filepath "$PSScriptRoot\blacklist.txt" -append
			continue
		}

		set-log -message "Session created with $computer" -logfile "deployment-log.txt"
	}
	else
	{
		set-log -message "$computer was not online" -logfile "deployment-log.txt"
		$computer | out-file -filepath "$PSScriptRoot\blacklist.txt" -append
		continue
	}

	# Setting Execution Policy

	$exejob = Invoke-Command -Session $session -ScriptBlock {
		if ($(Get-ExecutionPolicy) -ne "Unrestricted")
		{
			Set-ExecutionPolicy Unrestricted
		}
	}
	$exejob | Wait-Job

	# check if 2 triggers are active, directory structure exists, and added to path

	$collectiontask = $Null
	$performancetask = $Null
	$directorystructure = $Null

	$collectiontask = Invoke-Command -Session $session -ScriptBlock { 
		$remote_collection_task = Get-ScheduledTask -TaskName "Log System Information" -ErrorAction SilentlyContinue
		return $remote_collection_task
	}

	$performancetask = Invoke-Command -Session $session -ScriptBlock {
		$remote_performance_task = Get-ScheduledTask -taskname "Log System Performance" -ErrorAction SilentlyContinue
		return $remote_performance_task
	}

	$directorystructure = invoke-command -session $session -scriptblock {
		$remote_directory_structure_test = test-path -path "C:\Temp\SysPerf"
		return $remote_directory_structure_test
	}

	# copy files into directory structure

	if (!$directorystructure)
	{
		set-log -message "Setting up folder structure on $computer" -logfile "deployment-log.txt"

		$directoryjob = Invoke-Command -Session $session -ScriptBlock {
			if (test-path -path C:\Temp\)
			{
				new-item -erroraction ignore -itemtype Directory -path C:\Temp\
			}
		}
		$directoryjob | Wait-Job
	}

	# testing that C:\Temp is hidden  (also for good measure)
	$hiddenjob = Invoke-Command -Session $session -ScriptBlock {
		if (!$($(get-item -path C:\Temp\ -Force).Attributes -match "Hidden"))
		{
			$(get-item -path C:\Temp\ -Force).attributes = "Hidden"
		}
	}
	$hiddenjob | Wait-Job

	# copying the files over regardless of the folder structure (basically for good measure)
	copy-item -tosession $session -path "$PSScriptRoot\SysPerf\" -Destination "C:\Temp\" -Recurse -Force

	# run scripts to create triggers

	if (!$collectiontask)
	{
		set-log -message "triggering daily collection on $computer" -logfile "deployment-log.txt"
		$collectionJob = invoke-command -session $session -scriptblock { Invoke-Expression -Command "C:\Temp\SysPerf\trigger-collection.ps1" } -AsJob
		$collectionJob | wait-job
	}

	if (!$performancetask)
	{
		set-log -message "triggering sysperf collection on $computer" -logfile "deployment-log.txt"
		$performancejob = invoke-command -session $session -scriptblock { Invoke-Expression -Command "C:\Temp\SysPerf\trigger-sysperf.ps1" } -AsJob
		$performancejob | wait-job
	}
	
	# run once and make the eventlog now

	$first_time = Invoke-Command -Session $session -ScriptBlock {
		new-eventlog -logname "SysPerf" -source "perf"
		new-eventlog -logname "SysPerf" -source "daily collection"
		limit-eventlog -logname "SysPerf" -MaximumSize 1GB
		Start-ScheduledTask -TaskName "Log System Performance"
		Start-ScheduledTask -TaskName "Log System Information"
	}
	$first_time | Wait-Job

	# check that SysPerf EventLog was made

	$sysperf_made = $Null

	$sysperf_made = Invoke-Command -Session $session -ScriptBlock {
		if ([System.Diagnostics.EventLog]::Exists('SysPerf'))
		{
			return $true
		}
		else
		{
			return $false
		}
	}

	if ($sysperf_made)
	{
		set-log -message "SysPerf Event Log was successfully made on $computer" -logfile "deployment-log.txt"
	}
	else
	{
		set-log -message "SysPerf Event Log was unsuccessful on $computer" -logfile "deployment-log.txt"
	}

	# add hostname to whitelist outside of PSSession
	
	$computer | out-file -filepath "$PSScriptRoot\whitelist.txt" -append

	# close session connections

	remove-pssession -session $session
}
