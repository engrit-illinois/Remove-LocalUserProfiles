# Documentation home: https://github.com/engrit-illinois/Get-LocalUserProfiles
# By mseng3

# Get access to TS variables
$tsEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment

# Get local path variables
$modulePath = $tsEnv.Value('EngrIT_ModulePath')

# Initialize log
$logPath = $tsEnv.Value('EngrIT_LogPath')
"Initializing log..." | Out-File $logPath

# Delete module if it already exists in the local path
if(Test-Path -PathType leaf -Path $modulePath) {
	Remove-Item -Path $modulePath -Force
}

# Download module
$moduleURL = $tsEnv.Value('EngrIT_ModuleURL')
"Downloading module from `"$moduleURL`"..." | Out-File $logPath -Append
$webrequest = Invoke-WebRequest -Uri $moduleURL
if($webrequest.StatusCode -eq 200) {
	$moduleContent = $webrequest.Content
}
else {
	throw "Could not download module!"
}

# Import module
"Importing module from `"$modulePath`"..." | Out-File $logPath -Append
Import-Module $modulePath -Force

# Get parameter variables
$age = $tsEnv.Value('EngrIT_DeleteProfilesOlderThan')
$excluded = $tsEnv.Value('EngrIT_ExcludedUsers')
$timeout = $tsEnv.Value('EngrIT_TimeoutMins')
$tsver = $tsEnv.Value('EngrIT_TSVersion')

# Run module
"Running module..." | Out-File $logPath -Append
Remove-LocalUserProfiles -DeleteProfilesOlderThan $age -ExcludedUsers $excluded -TimeoutMins $timeout -TSVersion $tsver