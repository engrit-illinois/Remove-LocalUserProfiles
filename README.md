# Summary

This Powershell module and companion scripts remove local user profiles from the local computer.  

For gathering information and informing decisions about how to use this module, see [Get-LocalUserProfiles](https://github.com/engrit-illinois/Get-LocalUserProfiles).

See below for more detailed [context](#context), caveats, and [credits](#credits).  

# Usage

1. Download `Remove-LocalUserProfiles.psm1` to the appropriate subdirectory of your PowerShell [modules directory](https://github.com/engrit-illinois/how-to-install-a-custom-powershell-module).
2. Run it using the parameters documented below
    - e.g. `Remove-LocalUserProfiles -DeleteProfilesOlderThan 10 -TimeoutMins 55 -ExcludeUsers "netid1","netid2"`

# Parameters

### -DeleteProfilesOlderThan \<int\>
Required integer >= `0`.  
The maximum "age" a profile must be to not be deleted.  
Based on the profile's `LastUseTime` property.  
See [context](#context) for more details/caveats about this.  

### -UseMinsInsteadOfDays
Optional switch.  
If specified, the value given for -DeleteProfilesOlderThan will be treated as a quantity of minutes, instead of days.  
This was a quick hack, and the module output will still reflect as if days were being used.  

### -TimeoutMins \<int\>
Required integer.  
The maximum number of minutes that the script will run before gracefully aborting.  
This is to avoid getting ungracefully cut off in the middle of deleting profiles by an external timeout in whatever process in running the script. e.g. The MECM "Run Scripts" feature has a static timeout of 60 mins.  
It's recommended to provide a buffer of a few minutes, so if the parent process times out in 60 mins, set this to ~55.  
The script keeps track of the longest amount of time it took to delete any profile. If there's less than that much time left before this `-TimeoutMins` value, it will exit before starting to delete another profile.  
As such, this script is _not_ guaranteed to delete _all_ targeted profiles, if it runs out of time.  

### -ExcludeUsers \<string\>
Optional string.  
A string representing a comma-separated list of NetIDs to exclude from having their local profiles deleted.  
e.g. `-ExcludeUsers "netid1,netid2,netid3"`.  

### -DeletionTimeEstimateMins \<int\>
Optional integer.  
An initial, minimum estimate for how long profiles will take to delete.  
As the script runs, it will keep track of the longest amount of time it took to delete any profile. This value starts at the value of `-DeletionTimeEstimateMins`, and is updated each time a profile takes longer than that. If there's less than this much time left before the built-in timeout occurs (based on `-TimeoutMins`), the script will exit before starting to delete another profile.  
Default is `1`.  

### -Log \<string\>
Optional string.  
The full path to the log file that will be created.  
Default is `c:\engrit\logs\Remove-LocalUserProfiles_yyyy-MM-dd_HH-mm-ss.log`.  

### -TSVersion \<string\>
Optional string.  
Just a value that is logged.  
Only useful when running the script from an MECM Task Sequence, via `Remove-LocalUserProfiles_RunInMECMTS.ps1`.  
Useful for making sure the correct TS was run, when looking at logs.  

### -Loud
Optional switch.  
When specified, all log messages are also output to the console.  
This is off by default because anything output can cause messy return values when running the script from the MECM "Run Scripts" feature, i.e. via `Remove-LocalUserProfiles_RunAsMECMScript.ps1`.  

# Context

This module works as described, however, like many similar solutions out there, it relies on `LastUseTime` property of the `Win32_UserProfile` WMI class.  Due to either Windows bugs, or incompatibilities with other tools, this LastUseTime property (and also alternate data sources, such as the modified time of `NTUSER.dat`) has proven to be completely unreliable as a source for determining when a user last logged in. This appears to be due to these sources being erroneously updated by unknown mechanisms. It seems that this issue has only really been identified since around the v1703-v1709 era of Windows 10. This is very frustrating for IT pros looking to rely on that information.  

I created [Get-LocalUserProfiles](https://github.com/engrit-illinois/Get-LocalUserProfiles) to help workaround this issue by gathering as much data as possible about the state of local user profiles in our environment.  

Sources on the issue:
- https://techcommunity.microsoft.com/t5/windows-10-deployment/issue-with-date-modified-for-ntuser-dat/m-p/102438
- https://community.spiceworks.com/topic/2263965-find-last-user-time
- https://powershell.org/forums/topic/incorrect-information-gets-recorded-in-win32_userprofile-lastusetime-obj/

# Credits

This module was based closely on various scripts written for the purposes of deleting old, stale profiles.
- https://gallery.technet.microsoft.com/scriptcenter/Remove-Old-Local-User-080438f6#content
- https://gallery.technet.microsoft.com/scriptcenter/How-to-delete-user-d86ffd3c/view/Discussions/0

# Notes
- By mseng3
- `Remove-LocalUserProfiles_original.psm1` is an unedited copy of the source inspiration scripts mentioned in the credits section. For reference only. Do not use this.
- `Remove-LocalUserProfiles_RunAsMECMScript.ps1` is a script that can be used with the MECM "Run Scripts" feature. It simply downloads the main module from GitHub and runs it with relevant parameters. It is currently in MECM as a script named `Delete local user profiles older than X days`.
  - Note: scripts run using the MECM Run Script feature have a basically undocumented (:rage:) timeout/maximum runtime of 60 minutes. This only affords time for a handful of profiles to be deleted, and a typicial lab computer in the author's environment can rack up several hundred stale profiles over the course of a semester, which would take this script (in its current implementation) many hours to delete. So it's not ideal. However this version has been crafted to exit cleanly after the given timeout variable, and can simply be run again and again until no more targeted profiles are left.
- Similarly, `Remove-LocalUserProfiles_RunInMECMTS.ps1` is a script that can be used as a step in an MECM Task Sequence. It downloads the main module from GitHub and runs it with parameters given by the TS.
- Note: `Remove-LocalUserProfiles_BETA.psm1` (and `README_BETA.md`) are currently a work in progress. It is the next version which will support running the module remotely on multiple computers, via asynchronous jobs.
