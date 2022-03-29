<#
#
#	collect-sysinfo
#
#	description: collects information on the system once per day and adds it to the sysperf eventlog
#
#	3 - hard drive information
#	4 - bios version
#	5 - gpu info
#	6 - OS info
#	7 - monitor
#	8 - model
#	9 - installed programs
#
#>

# check if source exists
if (![system.diagnostics.eventlog]::sourceexists("daily collection"))
{
	new-eventlog -logname "SysPerf" -source "daily collection"
	limit-eventlog -logname "SysPerf" -MaximumSize 1GB
}

$hdds = get-wmiobject -class win32_logicaldisk | select deviceid, volumename, size, freespace | out-string

$encryption = manage-bde -status | out-string

$ram = get-wmiobject -class win32_physicalmemory | select devicelocator, capacity, speed | out-string

$bios = get-wmiobject -class win32_bios | select name, serialnumber | out-string

$os = get-wmiobject -class win32_operatingsystem | select name, version | out-string

$gpus = get-wmiobject -class win32_videocontroller | select name, videomodedescription | out-string

$monitors = get-wmiobject -class Win32_DesktopMonitor | select name | out-string

$model = get-wmiobject -class Win32_ComputerSystemProduct | select name | out-string

$installed_programs = get-wmiobject -class Win32_InstalledWin32Program | select name, vendor, version

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 3 -entrytype Information -message $hdds

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 3 -entrytype Information -message $encryption

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 2 -entrytype Information -message $ram

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 4 -entrytype Information -message $bios

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 5 -entrytype Information -message $gpus

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 6 -entrytype Information -message $os

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 7 -entrytype Information -message $monitors

write-eventlog -logname "SysPerf" -source "daily collection" -EventID 8 -entrytype Information -message $model

foreach ($installed_program in $installed_programs)
{
	$installed_program_string = $installed_program | out-string
	write-eventlog -logname "SysPerf" -source "daily collection" -EventID 9 -entrytype Information -message $installed_program_string
}
