# Documentation home: https://github.com/engrit-illinois/Get-LocalUserProfiles
# By mseng3

# Get access to TS variables
$tsEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment

# Get parameter variables
$DeleteProfilesOlderThan = $tsEnv.Value('EngrIT_DeleteProfilesOlderThan')
$ExcludedUsers = $tsEnv.Value('EngrIT_ExcludedUsers')
$TimeoutMins = $tsEnv.Value('EngrIT_TimeoutMins')
$TSVersion = $tsEnv.Value('EngrIT_TSVersion')

# Set module variables
$moduleURL = $tsEnv.Value('EngrIT_ModuleURL')
$modulePath = $tsEnv.Value('EngrIT_ModulePath')

# Initialize log
$logPath = $tsEnv.Value('EngrIT_LogPath')
"Initializing log..." | Out-File $logPath

# Download module content
"Downloading module content from `"$moduleURL`"..." | Out-File $logPath -Append
$webrequest = Invoke-WebRequest -Uri $moduleURL
if($webrequest.StatusCode -ne 200) {
	throw "Could not download module!"
}
else {
	# Save module content to file
	"Saving module content to `"$modulePath`"..." | Out-File $logPath -Append
	$webrequest.Content | Out-File $modulePath

	# Import module
	"Importing module from `"$modulePath`"..." | Out-File $logPath -Append
	Import-Module $modulePath -Force

	# Run module
	"Running module..." | Out-File $logPath -Append
	Remove-LocalUserProfiles -DeleteProfilesOlderThan $DeleteProfilesOlderThan -ExcludedUsers $ExcludedUsers -TimeoutMins $TimeoutMins -TSVersion $TSVersion | Out-File $logPath -Append
}