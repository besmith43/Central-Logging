param (
	[string]$hostname,
	[string]$date
)

class averagecpuload
{
	[datetime]$time
	[int]$average
}

class numberofprocesses
{
	[datetime]$time
	[int]$numofprocesses
}

class numberofusers
{
	[datetime]$time
	[int]$numofusers
}

class topprocesses
{
	[datetime]$time
	[string]$total
	[string]$process1
	[string]$process2
	[string]$process3
	[string]$process4
	[string]$process5
}

class ramused
{
	[datetime]$time
	[int]$amountoframused
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

#$logs = import-csv "$PSScriptRoot\eventlogs\sysperf.csv"
if (test-path -path "$PSScriptRoot\Eventlogs\$hostname\$date\sysperf.csv")
{
	$logs = import-csv "$PSScriptRoot\Eventlogs\$hostname\$date\sysperf.csv"
}
else
{
	set-log -message "SysPerf.csv does not exist for $hostname on $date" -logfile "process-log-$date.txt"
	exit
}

$bootdrivefull= $false
$numcpuaverages = 0
$averageramusage = 0
$averageload = @()
$numprocesses = @()
$numusers = @()
$topprocs = @()
$cpu = $Null
$ram = $Null
$ramusage = @()
$hdd = @()
$bitlocker = $Null
$bios = $Null
$gpu = $Null
$os = $Null
$monitor = $Null
$model = $Null
$installedprograms = @()

foreach ($log in $logs)
{
	$eventid = $log.("EventID")

	$message = $log.("Message")

	$time = $log.("TimeGenerated")

	if ([datetime]$time -lt $((get-date).addDays(-7)))
	{
		continue
	}

	$source = $log.("Source")

	# check if cpu, eventid 1

	if ($eventid -eq 1)
	{
		# 4 types of process events

		# if contains average; then it has the average cpu load
		
		if ($message -match "average")
		{
			$message = $message.split("`n")
			$message = $message[3]
			$message = $message.split(" ")
			$message = [int]$message[$($message.count - 1)]

			$currentaverage = new-object averagecpuload
			$currentaverage.time = $time
			$currentaverage.average = $message
			
			$averageload += $currentaverage

			$numcpuaverages += 1
		}

		# if contains maxnumberofprocesses; then pull numberofprocesses and numberofusers
		
		if ($message -match "maxnumberofprocesses")
		{
			$messagearray = $message.split(";")

			$numofprocesses = $messagearray[1].split("=")

			$numofprocesses = [int]$numofprocesses[1]

			$nump = new-object numberofprocesses
			$nump.numofprocesses = $numofprocesses
			$nump.time = $time

			$numprocesses += $nump

			$numofusers = $messagearray[3].split("=")

			$numofusers = $numofusers[1]

			$numofusers = $numofusers.substring(0,$($numofusers.length-1))

			$numofusers = [int]$numofusers

			$numu = new-object numberofusers
			$numu.numofusers = $numofusers
			$numu.time = $time

			$numusers += $numu
		}

		# if contains currentclockspeed; ignore for now

		if ($message -match "currentclockspeed")
		{
			if (!$cpu)
			{
				$message = $message.split(";")
				$message = $message[0]
				$message = $message.substring(7)
				$cpu = $message
			}
		}

		# if contains instance name; pull 3 lines after total and idle

		if ($message -match "instancename")
		{
			$message = $message.split("`n")
			$total = $message[3]
			$process1 = $message[4]
			$process2 = $message[5]
			$process3 = $message[6]
			$process4 = $message[7]
			$process5 = $message[8]

			$topp = new-object topprocesses
			$topp.total = $total
			$topp.process1 = $process1
			$topp.process2 = $process2
			$topp.process3 = $process3
			$topp.process4 = $process4
			$topp.process5 = $process5
			$topp.time = $time

			$topprocs += $topp
		}
	}

	# check if ram, eventid 2

	if ($eventid -eq 2)
	{
		if ($source -match "perf")
		{
			# get free memory and total memory to find amount of free memory

			$message = $message.split(";")

			$ramfree = $message[0].split("=")
			
			$ramfree = [int]$ramfree[1] / 1MB

			$totalram = $message[1].split("=")

			$totalram = $totalram[1]

			$totalram = $totalram.substring(0,$($totalram.length - 1))

			$totalram = [int]$totalram / 1MB

			$amountramused = $totalram - $ramfree

			$amountr = new-object ramused

			$amountr.time = $time
			$amountr.amountoframused = $amountramused

			$ramusage += $amountr

			$averageramusage += 1
		}

		if ($source -match "daily collection")
		{
			# record the spec of ram modules

			if (!$ram)
			{
				$ram = $message
			}
		}
	}

	# check if hard drive, eventid 3

	if ($eventid -eq 3)
	{
		# there are 2 types

		# if contains bitlocker; then log the bitlocker message
		
		if ($message -match "bitlocker")
		{
			if (!$bitlocker)
			{
				$bitlocker = $message
			}
		}

		# else; log drives and storage capacities

		else
		{
			if (!$hdd)
			{
				$message = $message.split("`n")
				$hdd1 = $message[3]
				$hdd2 = $message[4]
				$hdd3 = $message[5]

				$hdd1 = $hdd1.split(" ")
				$hdd1count = $hdd1.count
				$hdd1driveletter = $hdd1[0]
				$hdd1size = [math]::Round($([int64]$hdd1[$($hhd1count-2)] / 1GB))
				$hdd1freespace = [math]::Round($([int64]$hdd1[$($hdd1count-1)] / 1GB))
				$hdd1string = "$hdd1driveletter    $hdd1freespace    $hdd1size"
				$hdd += [string]$hdd1string

				$hdd1percentfree = $hdd1freespace / $hdd1size

				if ($hdd1percentfree -le 0.15)
				{
					$bootdrivefull = $true
				}

				$hdd2 = $hdd2.split(" ")
				$hdd2count = $hdd2.count
				if ($hdd2count -gt 1)
				{
					$hdd2driveletter = $hdd2[0]
					$hdd2size = [math]::Round($([int64]$hdd2[$($hhd1count-2)] / 1GB))
					$hdd2freespace = [math]::Round($([int64]$hdd2[$($hdd1count-1)] / 1GB))
					$hdd2string = "$hdd2driveletter    $hdd2freespace    $hdd2size"
					$hdd += [string]$hdd2string
				}

				$hdd3 = $hdd3.split(" ")
				$hdd3count = $hdd3.count
				if ($hdd3count -gt 1)
				{
					$hdd3driveletter = $hdd3[0]
					$hdd3size = [math]::Round($([int64]$hdd3[$($hhd1count-2)] / 1GB))
					$hdd3freespace = [math]::Round($([int64]$hdd3[$($hdd1count-1)] / 1GB))
					$hdd3string = "$hdd3driveletter    $hdd3freespace    $hdd3size"
					$hdd += [string]$hdd3string
				}
			}	
		}
	}

	# check if bios, eventid 4

	if ($eventid -eq 4)
	{
		# log bios version and serial number

		if (!$bios)
		{
			$bios = $message
		}
	}

	# check if gpu, eventid 5
	
	if ($eventid -eq 5)
	{
		# log video card name, and discription

		if (!$gpu)
		{
			$gpu = $message
		}
	}

	# check if OS, eventid 6

	if ($eventid -eq 6)
	{
		#log OS name and version

		if (!$os)
		{
			$os = $message
		}
	}

	# check if monitor, eventid 7

	if ($eventid -eq 7)
	{
		# log the monitor name

		if (!$monitor)
		{
			$monitor = $message
		}
	}

	# check if model, eventid 8

	if ($eventid -eq 8)
	{
		# log the model of computer
		
		if (!$model)
		{
			$model = $message
		}
	}

	# check if installed program, eventid 9

	if ($eventid -eq 9)
	{
		# log the name, vendor, and version 
		
		$message = $message.split("`n")

		$message = $message[3]

		$installedprograms += $message
	}
}

# now to cushion the data collected

# get the overall average cpu time

$averagecpuloadtotal = 0

foreach ($cpuload in $averageload)
{
	$averagecpuloadtotal += $cpuload.average
}

$averagecpuloadtotal = $averagecpuloadtotal / $numcpuaverages

# get overall average ram usage

$averageramusagetotal = 0

foreach ($ramuse in $ramusage)
{
	$averageramusagetotal += $ramuse.amountoframused
}

$averageramusagetotal = $averageramusagetotal / $averageramusage

# get unique programs from installed programs list

$installedprograms = $installedprograms | select-object -uniq

# now it's time to make bar graphs out of the data

import-module "$PSScriptRoot\PoshCharts-Dev\PoshCharts\PoshCharts.psm1"

$averageload | out-barchart -XField time -YField average -Title "Average CPU Load over time" -includelegend -tofile "$PSScriptRoot\eventlogs\$hostname\$date\averagecpuload.jpeg" 2> $null

$numprocesses | out-barchart -XField time -YField numofprocesses -Title "The number of Processes over time" -includelegend -tofile "$PSScriptRoot\eventlogs\$hostname\$date\numberofprocesses.jpeg" 2> $null

$ramusage | out-barchart -XField time -YField amountoframused -Title "The amount of System RAM used over time" -includelegend -tofile "$PSScriptRoot\eventlogs\$hostname\$date\amountoframused.jpeg" 2> $null

$Word = New-Object -ComObject Word.Application

$Document = $Word.Documents.Add()
$Selection = $Word.Selection

$Selection.TypeText("Computer Name: $hostname")
$Selection.TypeParagraph()
$Selection.TypeParagraph()
$Selection.TypeText("Model of CPU: $cpu")
$Selection.TypeParagraph()
$Selection.InlineShapes.AddPicture("$PSScriptRoot\eventlogs\$hostname\$date\averagecpuload.jpeg") 1> $Null
$Selection.TypeParagraph()
$Selection.InlineShapes.AddPicture("$PSScriptRoot\eventlogs\$hostname\$date\numberofprocesses.jpeg") 1> $Null
$Selection.TypeParagraph()
$Selection.TypeParagraph()
$Selection.TypeParagraph()
$Selection.TypeText("RAM") 
$Selection.TypeParagraph()
$Selection.TypeText("$ram")
$Selection.TypeParagraph()
$Selection.InlineShapes.AddPicture("$PSScriptRoot\eventlogs\$hostname\$date\amountoframused.jpeg") 1> $Null
$Selection.TypeParagraph()
$Selection.InsertNewPage()
$Selection.TypeText("Hard Drives")
$Selection.TypeParagraph()
$Selection.TypeText("Drive Letter  FreeSpace   Total Size")
$Selection.TypeParagraph()
foreach($hd in $hdd)
{
	$Selection.TypeText("$hd")
	$Selection.TypeParagraph()
}
$Selection.TypeParagraph()
$Selection.TypeText("Bitlocker Status")
$Selection.TypeParagraph()
$Selection.TypeText("$bitlocker")
$Selection.TypeParagraph()
$Selection.InsertNewPage()
$Selection.TypeText("Bios Info")
$Selection.TypeParagraph()
$Selection.TypeText("$bios")
$Selection.TypeParagraph()
$Selection.TypeText("GPU Model")
$Selection.TypeParagraph()
$Selection.TypeText("$gpu")
$Selection.TypeParagraph()
$Selection.TypeText("Operating System")
$Selection.TypeParagraph()
$Selection.TypeText("$os")
$Selection.TypeParagraph()
$Selection.TypeText("Monitors")
$Selection.TypeParagraph()
$Selection.TypeText("$monitor")
$Selection.TypeParagraph()
$Selection.TypeText("Model of Computer")
$Selection.TypeParagraph()
$Selection.TypeText("$model")
$Selection.TypeParagraph()
$Selection.InsertNewPage()
$Selection.TypeText("Installed Programs")
foreach ($program in $installedprograms)
{
	$Selection.TypeParagraph()
	$Selection.TypeText("$program")
}

write-host "Average Cpu Load:  $averagecpuloadtotal"
write-host "Average Ram Usage:  $averageramusagetotal"

if ($bootdrivefull)
{
	write-host "Boot drive has less than 15% free space"
	if (!$(test-path -path "$PSScriptRoot\Processed-Logs\Warning"))
	{
		new-item -path "$PSScriptRoot\Processed-Logs\Warning\" -ItemType Directory
	}
	$Report = "$PSScriptRoot\Processed-Logs\Warning\$hostname-$date.doc"	
}
elseif ($averagecpuloadtotal -ge 90)
{
	write-host "Average CPU Usage higher than 90"
	if (!$(test-path -path "$PSScriptRoot\Processed-Logs\Warning"))
	{
		new-item -path "$PSScriptRoot\Processed-Logs\Warning\" -ItemType Directory
	}
	$Report = "$PSScriptRoot\Processed-Logs\Warning\$hostname-$date.doc"
}
elseif ($averageramusagetotal -ge 90)
{
	write-host "Average Ram usage higher than 90"
	if (!$(test-path -path "$PSScriptRoot\Processed-Logs\Warning"))
	{
		new-item -path "$PSScriptRoot\Processed-Logs\Warning\" -ItemType Directory
	}
	$Report = "$PSScriptRoot\Processed-Logs\Warning\$hostname-$date.doc"
}
else
{
	$Report = "$PSScriptRoot\Processed-Logs\$hostname-$date.doc"	
}

$Document.SaveAs([ref]$Report,[ref]$SaveFormat::wdFormatDocument)
$word.Quit()

$null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$word)
[gc]::Collect()
[gc]::WaitForPendingFinalizers()
Remove-Variable word
