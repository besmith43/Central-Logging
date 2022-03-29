param (
[string]$CollegeOU,
[switch]$UseWhiteList,
[switch]$version
)


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

if ($UseWhiteList)
{
    if (test-path "$PSScriptRoot\whitelist.txt")
    {
        $whitelist = get-content "$PSScriptRoot\whitelist.txt"
    }
    else
    {
        set-log -message "There isn't a whitelist file and thus you need to uninstall per OU" -logfile "Uninstall-log.txt"
    }

    foreach ($computer in $whitelist)
    {
        if (test-connection -computername $computer -quiet -count 1)
        {
            set-log -message "Attempting to connect to $computer" -logfile "Uninstall-log.txt"

            $session = new-pssession -computername $computer
            
            if (!$session)
		    {
			    set-log -message "remote session failed to $computer" -logfile "Uninstall-log.txt"
			    continue
            }

            set-log -message "Connection made to $computer" -logfile "Uninstall-log.txt"

            set-log -message "Uninstalling SysPerf from $computer" -logfile "Uninstall-log.txt"
            
            $uninstall_task = Invoke-Command -Session $session -ScriptBlock {
                
                if ([System.Diagnostics.EventLog]::Exists('SysPerf'))
                {
                    Remove-EventLog -LogName "SysPerf"
                }

                $perf_task = Get-ScheduledTask -TaskName "Log System Performance" -ErrorAction SilentlyContinue
                if ($perf_task)
                {
                    $perf_task | Unregister-ScheduledTask -Confirm:$false
                }

                $collection_task = Get-ScheduledTask -TaskName "Log System Information" -ErrorAction SilentlyContinue
                if ($collection_task)
                {
                    $collection_task | Unregister-ScheduledTask -Confirm:$false
                }

                if (test-path -path "C:\Temp\SysPerf")
                {
                    remove-item "C:\Temp\SysPerf\" -Recurse -Force
                }
            }
            $uninstall_task | Wait-Job

            set-log -message "SysPerf is completely uninstalled from $computer" -logfile "Uninstall-log.txt"
        }
        else
        {
            set-log -message "$computer is not online" -logfile "Uninstall-log.txt"
        }
    }
}
else
{
    # base on OU for removal
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

    $computers = get-adcomputer -filter * -searchbase $OU -property *

    $tobeuninstalled = @()

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
				    $tobeuninstalled += $string
			    }
		    }
	    }
    }

    foreach ($computer in $tobeuninstalled)
    {
        if (test-connection -computername $computer -quiet -count 1)
        {
            set-log -message "Attempting to connect to $computer" -logfile "Uninstall-log.txt"

            $session = new-pssession -computername $computer
            
            if (!$session)
		    {
			    set-log -message "remote session failed to $computer" -logfile "Uninstall-log.txt"
			    continue
            }

            set-log -message "Connection made to $computer" -logfile "Uninstall-log.txt"

            set-log -message "Uninstalling SysPerf from $computer" -logfile "Uninstall-log.txt"
            
            $uninstall_task = Invoke-Command -Session $session -ScriptBlock {
                
                if ([System.Diagnostics.EventLog]::Exists('SysPerf'))
                {
                    Remove-EventLog -LogName "SysPerf"
                }

                $perf_task = Get-ScheduledTask -TaskName "Log System Performance" -ErrorAction SilentlyContinue
                if ($perf_task)
                {
                    $perf_task | Unregister-ScheduledTask -Confirm:$false
                }

                $collection_task = Get-ScheduledTask -TaskName "Log System Information" -ErrorAction SilentlyContinue
                if ($collection_task)
                {
                    $collection_task | Unregister-ScheduledTask -Confirm:$false
                }

                if (test-path -path "C:\Temp\SysPerf")
                {
                    remove-item "C:\Temp\SysPerf\" -Recurse -Force
                }
            }
            $uninstall_task | Wait-Job

            set-log -message "SysPerf is completely uninstalled from $computer" -logfile "Uninstall-log.txt"
        }
        else
        {
            set-log -message "$computer is not online" -logfile "Uninstall-log.txt"
        }
    }
}