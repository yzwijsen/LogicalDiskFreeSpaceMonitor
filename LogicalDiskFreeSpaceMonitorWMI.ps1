<#
	SCOM Logical Disk Free Space Monitor.
	Written By Yannick Zwijsen
	
	ThresholdConfig parameter:
	0 - Both % and Mb thresholds need to be passed
	1 - Either % or Mb thresholds needs to be passed
	2 - Only % threshold needs to be passed
	3 - Only Mb threshold needs to be passed
#>

param(
	[Parameter()]
	[string]$TargetDrive,
	[Parameter()]
	[int]$PercentageFreeThreshold,
	[Parameter()]
	[int]$MegabytesFreeThreshold,
	[Parameter()]
	[int]$ThresholdConfig = 0
)

function Log-Info($message)
{
	Write-EventLog -LogName "Operations Manager" -Source "Health Service Script" -EventID 3000 -EntryType Information -Message $message
}

function Get-DiskInfo($disk)
{
	return (Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$disk'"| Select-Object Size,FreeSpace)
}

Log-Info "LogicalDiskFreeSpaceMonitor.ps1 Started || $TargetDrive $PercentageFreeThreshold $MegabytesFreeThreshold"

$ScomAPI = New-Object -comObject "MOM.ScriptAPI"
$PropertyBag = $ScomAPI.CreatePropertyBag()

#Convert FreeThreshold from megabytes to bytes
$BytesFreeThreshold = $MegabytesFreeThreshold * 1024 * 1024

#Gather Drive Data
$Drive = Get-DiskInfo $TargetDrive

#Retry if data is suspicious or invalid
if ($Drive.FreeSpace -eq 0 -or $Drive.Size -eq 0)
{
	Start-Sleep	10

	# Get drive data again
	$Drive = Get-DiskInfo $TargetDrive
}

$DriveFreeBytes = $Drive | Select-Object -ExpandProperty FreeSpace
$DriveTotalBytes = $Drive | Select-Object -ExpandProperty Size

#Calculate Additional Data
$DriveUsedBytes = $DriveTotalBytes - $DriveFreeBytes
$DriveFreePercent = $DriveFreeBytes / $DriveTotalBytes * 100

$DriveThresholdPassed = switch ($ThresholdConfig)
{
	0 {$DriveFreePercent -lt $PercentageFreeThreshold -and $DriveFreeBytes -lt $BytesFreeThreshold} #Both thresholds will be checked
	1 {$DriveFreePercent -lt $PercentageFreeThreshold -or $DriveFreeBytes -lt $BytesFreeThreshold} #Either % or Mb thresholds will be checked
	2 {$DriveFreePercent -lt $PercentageFreeThreshold} #Only % threshold will be checked
	3 {$DriveFreeBytes -lt $BytesFreeThreshold} #Only Mb threshold will be checked
	default {$DriveFreePercent -lt $PercentageFreeThreshold -and $DriveFreeBytes -lt $BytesFreeThreshold} #Both thresholds will be checked
}

# Check if Threshold was met
if ($DriveThresholdPassed)
{
	$State = "Unhealthy"
}
else
{
	$State = "Healthy"
}

#Calculate Mb values and round results for display in the SCOM alert description
$DriveFreeMegaBytes = [Math]::Round(($DriveFreeBytes / 1024 / 1024),2)
$DriveUsedMegaBytes = [Math]::Round(($DriveUsedBytes / 1024 / 1024),2)
$DriveTotalMegaBytes = [Math]::Round(($DriveTotalBytes / 1024 / 1024),2)
$DriveFreePercent = [Math]::Round($DriveFreePercent,2)

Log-Info "LogicalDiskFreeSpaceMonitor.ps1 Completed `n Drive: $TargetDrive `n State: $State `n Free Mb: $DriveFreeMegaBytes `n Free Percent: $DriveFreePercent"

#Expose Data to SCOM Alert
$PropertyBag.AddValue("State",$State)
$PropertyBag.AddValue("DriveLetter",$TargetDrive)
$PropertyBag.AddValue("FreeMb",$DriveFreeMegaBytes)
$PropertyBag.AddValue("UsedMb",$DriveUsedMegaBytes)
$PropertyBag.AddValue("TotalMb",$DriveTotalMegaBytes)
$PropertyBag.AddValue("FreePercent",$DriveFreePercent)
$PropertyBag.AddValue("ThresholdMb",$MegabytesFreeThreshold)
$PropertyBag.AddValue("ThresholdPercent",$PercentageFreeThreshold)

#Return PropertyBag
$PropertyBag
