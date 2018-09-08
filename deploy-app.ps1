param (
[System.Management.Automation.PSCredential]$Credential,
[string]$CollegeOU,
[switch]$version
)

if ($version)
{
    $version_var = Get-Content -path "$PSScriptRoot\version.txt"
    write-host "Deploy SysPerf App Version $version_var"
    exit
}

import-module ActiveDirectory

if (!$Credential)
{
	$Credential = get-credential
}

if (!$CollegeOU)
{
    $OU = "OU=CoA&S Wks,OU=TTU Workstations,DC=tntech,DC=edu"
}
else
{
    $CollegeOU = $OU
}

# get root OU of College

get-ADOrganizationalUnit -searchbase $OU searchscope Subtree -Filter * -credential $Credential | select-object name, DistinguishedName

# get whitelist of systems that already have it installed

get-adcomputer -filter * -searchbase $OU | select-object name, DistinguishedName

$whitelist = get-content "$PSScriptRoot\whitelist.txt"

$tobesetup = @()

# compare the 2 and use foreach loop to add each name that don't match to array

foreach ($computer in $computers)
{
	$match = $whitelist | select-string $computer.name

	if (!$match)
	{
		$string = $computername.name | out-string
		$tobesetup += $string
	}
}

# foreach loop over the array to deploy the app

foreach ($computer in $tobesetup)
{

	# create PSSession

	$session = new-pssession -computername $computer -credential $credential

	# check if 2 triggers are active, directory structure exists, and added to path

	$collectiontask = $Null
	$performancetask = $Null
	$directorystructure = $Null

    # need to fix this

	#invoke-command -session $session -scriptblock {

	#	$Using:collectiontask = get-scheduledtask -taskname "Log System Information"

	#	$Using:performancetask = get-scheduledtask -taskname "Log System Performance"

	#	$Using:directorystructure = get-path -path "C:\Temp\SysPerf"

	#}

	# copy files into directory structure

	if (!$directorystructure)
	{
		new-psdrive -name "P" -root "\\$computer\c$" -PSProvider "FileSystem" -credential $credential

		new-item -erroraction ignore -itemtype Directory -path P:\Temp\

		$(get-item -path P:\Temp\ -Force).attributes = "Hidden"

		copy-item -path "$PSScriptRoot\SysPerf" -Destination "P:\Temp\SysPerf\"

		get-psdrive P | remove-psdrive
	}

	# run scripts to create triggers

	if (!$collectiontask)
	{
		$collectionJob = invoke-command -session $session -scriptblock { start-process -filepath "C:\Temp\SysPerf\trigger-collection.ps1" -wait } -AsJob
		$collectionJob | wait-job
	}

	if (!$performancetask)
	{
		$performancejob = invoke-command -session $session -scriptblock { start-process -filepath "C:\Temp\SysPerf\trigger-sysperf.ps1" -wait } -AsJob
		$performancejob | wait-job
	}

	# add hostname to whitelist outside of PSSession
	
	$computer | out-file -filepath "$PSScriptRoot\whitelist.txt" -append

	# close session connections

	remove-pssession -session $session
}
