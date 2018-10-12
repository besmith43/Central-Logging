This tool is to deploy, log, and collect system analytics on all Windows 10 Desktops in the college of Arts and Sciences.

Effectively it works as follows

    deploy-app.ps1
        when run this queries active directory to obtain a list of all computers
        then cycles through said list to determine if a machine is a desktop (noted solely by the -D nomenclature) and if it has Windows 10 (based on what is stated by AD)
        then it creates a remote ps session and drops the required scripts onto the computer and runs them (therefore hopefully starting 2 scheduled task sequences)

    Trigger-sysperf.ps1
        starts the scheduled task to run log-sysperf.ps1 every minute

    Trigger-Collection.ps1
        starts the scheduled task that runs once a day to collect system information that doesn't change often

    Collect-Eventlogs.ps1
        creates remote ps sessions with all computers on the whitelist to collect their eventlogs into a csv format, migrate them onto my desktop computer, and trigger process-eventlog.ps1

    Process-Eventlog.ps1
        processes the csv's collected for a specific machine in order to form the data into useable graphs and tables.  Also triggers warning if certain criteria are met

    