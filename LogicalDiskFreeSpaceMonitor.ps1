param($TargetDriveLetter, $PercentageFreeThreshold, $MegabytesFreeThreshold)

$ScomAPI = New-Object -comObject "MOM.ScriptAPI"
$PropertyBag = $ScomAPI.CreatePropertyBag()

#remove colon from drive leter parameter
$DriveLetter = $TargetDriveLetter.Replace(":","")
$BytesFreeThreshold = $MegabytesFreeThreshold * 1024 * 1024

#Gather Drive Data
$Drive = Get-PSDrive $DriveLetter
$DriveFreeBytes = $Drive | Select-Object -ExpandProperty Free
$DriveUsedBytes = $Drive | Select-Object -ExpandProperty Used

#We could use wmi as well
#$Drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$($TargetDrive):'" | Select-Object FreeSpace, Size

#Calculate Additional Data
$DriveTotalBytes = $DriveUsedBytes + $DriveFreeBytes
$DriveFreePercent = $DriveFreeBytes / $DriveTotalBytes * 100

# Check if Threshold was met
if ($DriveFreePercent -lt $PercentageFreeThreshold -and $DriveFreeBytes -lt $BytesFreeThreshold)
{
	$PropertyBag.AddValue("State","Unhealthy") 
}
else
{
	$PropertyBag.AddValue("State","Healthy") 
}

#Calculate Mb values for SCOM Alert
$DriveFreeMegaBytes = $DriveFreeBytes * 1024 * 1024
$DriveUsedMegaBytes = $DriveUsedBytes * 1024 * 1024
$DriveTotalMegaBytes = $DriveTotalBytes * 1024 * 1024

#Expose Data to SCOM Alert
$PropertyBag.AddValue("DriveLetter",$TargetDriveLetter)
$PropertyBag.AddValue("FreeMb",$DriveFreeMegaBytes)
$PropertyBag.AddValue("UsedMb",$DriveUsedMegaBytes)
$PropertyBag.AddValue("TotalMb",$DriveTotalMegaBytes)
$PropertyBag.AddValue("FreePercent",$DriveFreePercent)
$PropertyBag.AddValue("ThresholdMb",$MegabytesFreeThreshold)
$PropertyBag.AddValue("ThresholdPercent",$PercentageFreeThreshold)

#Return PropertyBag
$PropertyBag
