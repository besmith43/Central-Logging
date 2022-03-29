<#
#	this script logs system performance every minute
#	
#	Event ID's and what they mean
#
#	1 = Cpu usage
#	2 = Ram usage
#	
#>

if (![system.diagnostics.eventlog]::sourceexists("perf"))
{
	new-eventlog -logname "SysPerf" -source "perf"
    limit-eventlog -logname "SysPerf" -MaximumSize 1GB
}

$cpu_averageload = get-wmiobject -class win32_processor | measure-object -property LoadPercentage -Average | select-object Average | out-string

$cpu = get-wmiobject -class win32_processor | select-object name, currentclockspeed, currentvoltage, maxclockspeed, numberofcores, numberoflogicalprocessors

$processes = get-wmiobject -class win32_operatingsystem | select-object maxnumberofprocesses, numberofprocesses, maxprocessmemorysize, numberofusers

$active_processes = Get-Counter '\Process(*)\% Processor Time' | Select-Object -ExpandProperty countersamples | Select-Object -Property instancename, cookedvalue | Sort-Object -Property cookedvalue -Descending | Select-Object -First 20 | format-table InstanceName,@{L='CPU';E={($_.Cookedvalue/100).toString('P')}} -AutoSize | out-string

$ram = get-wmiobject -class win32_operatingsystem | select-object freephysicalmemory, totalvisiblememorysize

write-eventlog -logname "SysPerf" -source "perf" -EventID 1 -entrytype Information -message $cpu_averageload

write-eventlog -logname "SysPerf" -source "perf" -EventID 1 -entrytype Information -message $cpu

write-eventlog -logname "SysPerf" -source "perf" -EventID 1 -entrytype Information -message $processes

write-eventlog -logname "SysPerf" -source "perf" -EventID 1 -entrytype Information -message $active_processes

write-eventlog -logname "SysPerf" -source "perf" -EventID 2 -entrytype Information -message $ram

