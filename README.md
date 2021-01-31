# Summary

### WARNING: These scripts are a work in progress.

This Powershell module and companion scripts remove local user profiles from an array of remote computers.  

For gathering information and informing decisions about how to use this module, see [Get-LocalUserProfiles](https://github.com/engrit-illinois/Get-LocalUserProfiles).

See below for more detailed [context](#context), caveats, and [credits](#credits).  

# Usage

1. Download `Get-LocalUserProfiles.psm1`
2. Import it as a module: `Import-Module "c:\path\to\Get-LocalUserProfiles.psm1"`
3. Run it using the parameters documented below
- e.g. `Get-LocalUserProfiles -Computers "gelib-4c-*" -Log -Csv -PrintProfilesInRealtime`

# Parameters

### -Computers
WIP

### -DeleteProfilesOlderThan
WIP

### -TimeoutMins
WIP

### -ExcludedUsers
WIP

### -DeletionTimeEstimateMins
WIP

### -OUDN
WIP

### -Log
WIP

### -LogPath
WIP

### -MaxAsyncJobs
WIP

### -CIMTimeoutSec
WIP

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
  - Note: scripts run using the MECM Run Script feature have a basically undocumented (:rage:) timeout/maximum runtime of 60 minutes. This only affords time for a handful of profiles to be deleted, and a typicial lab computer in the author's environment can rack up several hundred stale profiles over the course of a semester, which would take this script (in its current implementation) many hours to delete. So it's not ideal.
- Similarly, `Remove-LocalUserProfiles_MECM-TS.ps1` is a script that can be used as a step in an MECM Task Sequence. It downloads the main module from GitHub and runs it with parameters given by the TS.