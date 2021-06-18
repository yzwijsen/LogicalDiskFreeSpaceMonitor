# SCOM-LogicalDiskFreeSpaceMonitor
powershell script to monitor logical disk space through System Center Operations Manager.

It uses the same logic as the default logical disk monitors (both % and Mb threshold need to be met) but unlike the default monitors it only has one set of thresholds. This way you can create seperate monitors for Warning or Error threshold levels and have each generate a separate alert. That makes it easier for ticketing / notification systems since you won't have to deal with alert severities changing over time.

No distinction is made between system and non-system drives however.
If you want different thresholds for system and non-system drives you can create a dynamic scom group with all system or non-system drives and create an override for the group.

There are two versions of the script. One uses the powershell Get-PSDrive cmdlet to gather drive data, the other uses WMI instead.
