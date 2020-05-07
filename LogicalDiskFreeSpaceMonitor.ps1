<#
	SCOM Logical Disk Free Space Monitor.
	Written By Yannick Zwijsen
	
	ThresholdConfig:
	This parameter takes
	0 - Both % and Mb thresholds need to be passed
	1 - Either % or Mb thresholds need to be passed
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

Log-Info "LogicalDiskFreeSpaceMonitor.ps1 Started || $TargetDriveLetter $PercentageFreeThreshold $MegabytesFreeThreshold"

$ScomAPI = New-Object -comObject "MOM.ScriptAPI"
$PropertyBag = $ScomAPI.CreatePropertyBag()

#remove colon from drive leter parameter
$DriveLetter = $TargetDrive.Replace(":","")
$BytesFreeThreshold = $MegabytesFreeThreshold * 1024 * 1024

#Gather Drive Data
$Drive = Get-PSDrive $DriveLetter
$DriveFreeBytes = $Drive | Select-Object -ExpandProperty Free
$DriveUsedBytes = $Drive | Select-Object -ExpandProperty Used

#Calculate Additional Data
$DriveTotalBytes = $DriveUsedBytes + $DriveFreeBytes
$DriveFreePercent = $DriveFreeBytes / $DriveTotalBytes * 100

$DriveThresholdPassed = switch ($ThresholdConfig)
{
	0 {$DriveFreePercent -lt $PercentageFreeThreshold -and $DriveFreeBytes -lt $BytesFreeThreshold}
	1 {$DriveFreePercent -lt $PercentageFreeThreshold -or $DriveFreeBytes -lt $BytesFreeThreshold}
	2 {$DriveFreePercent -lt $PercentageFreeThreshold}
	3 {$DriveFreeBytes -lt $BytesFreeThreshold}
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

Log-Info "LogicalDiskFreeSpaceMonitor.ps1 Completed `n Drive: $TargetDriveLetter `n State: $State `n Free Mb: $DriveFreeMegaBytes `n Free Percent: $DriveFreePercent"

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
