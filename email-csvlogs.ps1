$date = get-date -UFormat "%m-%d-%Y"

$hostname = hostname

$username = "besmith@tntech.edu"
$pwdTxt = Get-Content "$PSScriptRoot\password.txt"
$securePwd = $pwdTxt | ConvertTo-SecureString 
$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd

if (!$(test-path -path C:\Temp\SysPerf\Eventlogs))
{
    new-item -ErrorAction ignore -ItemType Directory -path C:\Temp\SysPerf\Eventlogs
}

new-item -erroraction ignore -itemtype directory -path C:\Temp\SysPerf\Eventlogs\$date-$hostname\

get-eventlog -logname "SysPerf" | export-csv "C:\Temp\SysPerf\Eventlogs\$date-$hostname\SysPerf.csv"

get-eventlog -logname "Application" | export-csv "C:\Temp\SysPerf\Eventlogs\$date-$hostname\Application.csv"

get-eventlog -logname "OAlerts" | export-csv "C:\Temp\SysPerf\Eventlogs\$date-$hostname\OAlerts.csv"

get-eventlog -logname "Security" | export-csv "C:\Temp\SysPerf\Eventlogs\$date-$hostname\Security.csv"

get-eventlog -logname "System" | export-csv "C:\Temp\SysPerf\Eventlogs\$date-$hostname\System.csv"

get-eventlog -logname "Windows Powershell" | export-csv "C:\Temp\SysPerf\Eventlogs\$date-$hostname\Powershell.csv"

Compress-Archive -path C:\Temp\SysPerf\Eventlogs\$date-$hostname\ -DestinationPath C:\Temp\SysPerf\Eventlogs\$date-$hostname

Send-MailMessage -to besmith@tntech.edu -from besmith@tntech.edu -smtpserver outlook.office365.com -subject "SysPerf Checkin" -Attachments "C:\Temp\SysPerf\Eventlogs\$date-$hostname.zip" -usessl -Credential $creds
