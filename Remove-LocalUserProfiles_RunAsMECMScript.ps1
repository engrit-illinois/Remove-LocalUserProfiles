# Documentation home: https://github.com/engrit-illinois/Get-LocalUserProfiles
# By mseng3

param(
	[Parameter(Mandatory=$true)]
	[int]$DeleteProfilesOlderThan,
	
	[string]$ExcludedUsers,
	
	[int]$TimeoutMins = 55
)

# Local path variables
$drive = "c"
$baseDir = "$($drive):\engrit"
$logDir = "$($baseDir)\logs"
$scriptDir = "$($baseDir)\scripts"

# Make local paths
cmd /c mkdir $baseDir
cmd /c mkdir $logDir
cmd /c mkdir $scriptDir

# Set module vars
$repo = "https://raw.githubusercontent.com/engrit-illinois/Remove-LocalUserProfiles/main"
$moduleName = "Remove-LocalUserProfiles"
$moduleExt = "psm1"
$moduleFileName = "$($moduleName).$($moduleExt)"
$moduleURL = "$repo/$moduleFileName"
$modulePath = "$scriptDir\$moduleFileName"

# Initialize log
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = "$logDir\$($moduleName)_RunAsMECMScript_$($timestamp).log"
"Initializing log..." | Out-File $logPath

# Download module
"Downloading module from `"$moduleURL`"..." | Out-File $logPath -Append
Invoke-WebRequest -Uri $moduleURL | Out-File $modulePath

# Import module
"Importing module from `"$modulePath`"..." | Out-File $logPath -Append
Import-Module $modulePath -Force

# Run module
"Running module..." | Out-File $logPath -Append
Remove-LocalUserProfiles -DeleteProfilesOlderThan $DeleteProfilesOlderThan -ExcludedUsers $ExcludedUsers -TimeoutMins $TimeoutMins -TSVersion "Running as MECM Script" | Tee-Object -FilePath $logPath -Append