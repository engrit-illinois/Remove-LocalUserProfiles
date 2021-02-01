# Documentation home: https://github.com/engrit-illinois/Remove-LocalUserProfiles
# By mseng3

function Remove-LocalUserProfiles {

	param(
		# Which computers to target
		# Script will target local computer only if none given
		[string[]]$Computers,
		
		# Limit search to computers in this OU
		[string]$OUDN = "OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu",
		
		# Delete profiles that are older than the given number of days
		[Parameter(Mandatory=$true)]
		[int]$DeleteProfilesOlderThan,
		
		# Timeout gracefully via self-regulation because MECM Run Scripts feature will timeout ungracefully at 60 mins
		# Recommended to make this a few minutes less than the expected ungraceful timeout
		[Parameter(Mandatory=$true)]
		[int]$TimeoutMins,
		
		# Comma-separated list of NetIDs
		[string]$ExcludedUsers,
		
		# Not implemented yet
		[int]$MaxAsyncJobs = 1,
		
		# A starting lowball (i.e. minimum) estimate for how long it will take to delete a single profile
		# This will become more accurate once we clock the actual deletions
		[int]$DeletionTimeEstimateMins = 1,
		
		[switch]$Log,
		[string]$LogPath = "c:\engrit\logs\Remove-LocalUserProfiles_$(Get-Date -Format `"yyyy-MM-dd_HH-mm-ss`").log",
		
		[string]$TSVersion = "unspecified",
		
		[int]$CIMTimeoutSec = 60,
		
		[switch]$Loud
	)

	$SCRIPT_VERSION = "v1.6"
	
	function log {
		param (
			[Parameter(Position=0)]
			[string]$Msg = "",
			
			[int]$L = 0, # level of indentation
			[int]$V = 0, # verbosity level
			[switch]$NoTS, # omit timestamp
			[switch]$NoNL, # omit newline after output
			[switch]$NoLog # skip logging to file
		)
		
		for($i = 0; $i -lt $L; $i += 1) {
			$Msg = "$Indent$Msg"
		}
		
		if(!$NoTS) {
			$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss:ffff"
			$Msg = "[$ts] $Msg"
		}
		
		# Check if this particular message is too verbose for the given $Verbosity level
		if($V -le $Verbosity) {
			
			# If we're allowing console output, then Write-Host
			if(!$NoConsoleOutput) {
				if($NoNL) {
					Write-Host $Msg -NoNewline
				}
				else {
					Write-Host $Msg
				}
			}
			
			# Check if this particular message is supposed to be logged
			if(!$NoLog) {
				
				# If we're allowing logging, then log
				if($Log) {
					
					# Check that the logfile already exists, and if not, then create it (and the full directory path that should contain it)
					if(!(Test-Path -PathType leaf -Path $LogPath)) {
						New-Item -ItemType File -Force -Path $LogPath | Out-Null
					}
					
					if($NoNL) {
						$Msg | Out-File $LogPath -Append -NoNewline
					}
					else {
						$Msg | Out-File $LogPath -Append
					}
				}
			}
		}
	}

	function Quit($msg) {
		log "Quitting with message: `"$msg`"."
		$quitTime = Get-Date
		$runTime = New-TimeSpan -Start $startTime -End $quitTime
		log "Total runtime: `"$runTime`""
		Write-Output $msg
		exit
	}
	
	function Get-CompNameString($comps) {
		$list = ""
		foreach($comp in $comps) {
			$list = "$list, $($comp.Name)"
		}
		$list = $list.Substring(2,$list.length - 2) # Remove leading ", "
		$list
	}

	function Get-Comps($compNames) {
		log "Getting computer names..."
		
		$comps = @()
		foreach($name in @($compNames)) {
			$comp = Get-ADComputer -Filter "name -like '$name'" -SearchBase $OUDN
			$comps += $comp
		}
		$list = Get-CompNameString $comps
		log "Found $($comps.count) computers in given array: $list." -L 1
	
		log "Done getting computer names." -V 2
		$comps
	}
	
	function Dump-InitInfo {
		log "Script version: `"$SCRIPT_VERSION`""
		log "TS version: `"$TSVersion`""
		log "-DeleteProfilesOlderThan: `"$DeleteProfilesOlderThan`""
		log "-ExcludedUsers: `"$ExcludedUsers`""
	}

	function Get-ProfilesFrom($comp) {
		$compName = $comp.Name
		log "Getting profiles from `"$compName`"..." -L 1
		$profiles = Get-CIMInstance -ComputerName $compName -ClassName "Win32_UserProfile" -OperationTimeoutSec $CIMTimeoutSec
		
		# Ignore system profiles
		$profiles = $profiles | Where { $_.LocalPath -notlike "*$env:SystemRoot*" }
		
		log "Found $(@($profiles).count) profiles." -L 2 -V 1
		$comp | Add-Member -NotePropertyName "_Profiles" -NotePropertyValue $profiles -Force
		log "Done getting profiles from `"$compname`"." -L 1 -V 2
		$comp
	}
	
	function Start-AsyncJobGetProfilesFrom($comp) {
		# If there are already the max number of jobs running, then wait
		$running = @(Get-Job | Where { $_.State -eq 'Running' })
		if($running.Count -ge $MaxAsyncJobs) {
			$running | Wait-Job -Any | Out-Null
		}
		
		# After waiting, start the job
		Start-Job {
			# Each job gets profiles, and returns a modified $comp object with the profiles included
			# We'll collect each new $comp object into the $comps array when we use Recieve-Job
			$comp = Get-ProfilesFrom($comp)
			return $comp
		} | Out-Null
	}
	
	function Get-ProfilesAsync($comps) {
		# Async example: https://stackoverflow.com/a/24272099/994622
		
		# For each computer start an asynchronous job
		foreach ($comp in $comps) {
			Start-AsyncJobGetProfilesFrom $comp
		}
		
		# Wait for all the jobs to finish
		Wait-Job * | Out-Null

		# Once all jobs are done, start processing their output
		# We can't directly write over each $comp in $comps, because we don't know which one is which without doing a bunch of extra logic
		# So just make a new $comps instead
		$newComps = @()
		foreach($job in Get-Job) {
			$comp = Receive-Job $job
			$comps += $comp
		}
		
		# Remove all the jobs
		Remove-Job -State Completed
		
		$newComps
	}
	
	function Get-Profiles($comps) {
		log "Retrieving profiles..."
		
		if($MaxAsyncJobs -lt 2) {
			foreach($comp in $comps) {
				$comp = Get-ProfilesFrom($comp)
			}
		}
		else {
			$comps = Get-ProfilesAsync $comps
		}
		
		log "Done retrieving profiles." -V 2
		$comps
	}
	
	function Remove-ProfilesFrom($comp) {
		
		$profiles = $comp._Profiles
		
		if(!$profiles) {
			Quit "Profiles found is null!"
		}
		else {
			$count = @($profiles).count
			$profilesCount = $count
			
			if($count -lt 1) {
				Quit "Zero profiles found!"
			}
			else {
				log "    Found $count profiles."
			
				log "Filtering profiles to those older than $DeleteProfilesOlderThan days..."
				$profiles = $profiles | Where { $_.LastUseTime -le $oldestDate }
				$count = @($profiles).count
				
				if($count -lt 1) {
					Quit "Zero profiles older than $DeleteProfilesOlderThan found."
				}
				else {
					log "    $count profiles remain."
					
					log "Filtering out system profiles..."
					$profiles = $profiles | Where { $_.LocalPath -notlike "*$env:SystemRoot*" }
					$count = @($profiles).count
					
					if($count -lt 1) {
						Quit "Zero non-system profiles older than $DeleteProfilesOlderThan found."
					}
					else {
						log "    $count profiles remain."
						
						if($ExcludedUsers) {
							log "-ExcludedUsers was specified: `"$ExcludedUsers`""
							
							$users = $ExcludedUsers.Split(",")
							$users = $users.Replace("`"","")
							log "    users: $users"
							
							log "    Filtering out excluded users..."
							foreach($user in $users) {
								log "        Filtering out user: `"$user`"..."
								$profiles = $profiles | Where { $_.LocalPath -notlike "*$user*" }
							}
							$count = @($profiles).count
							
							if($count -lt 1) {
								Quit "Zero non-system, non-excluded profiles older than $DeleteProfilesOlderThan found."
							}
							else {
								log "        $count profiles remain."
							}
						}
						else {
							log "No -ExcludedUsers were specified."
						}
			
						log "Deleting remaining profiles..."
						$profiles = $profiles | Sort LocalPath
						$profilesAttempted = @($profiles).count
						
						# Keep track of how much time it takes roughly to delete a profile
						# Start out with a lowball value (since we have plenty of time), and
						# update the estimate every time a profile takes longer to delete.
						$estDeleteTime = New-TimeSpan -Minutes $DeletionTimeEstimateMins
						log "    Initial estimated deletion time: `"$estDeleteTime`""
						
						foreach($profile in $profiles) {
							log "    Processing profile: `"$($profile.LocalPath)`"..."
							
							# Check that there's at least enough time to delete one more profile
							# before the configured timeout occurs
							log "        Current estimated deletion time: `"$estDeleteTime`""
							$currentTime = Get-Date
							$timeLeft = New-TimeSpan -Start $currentTime -End $endTime
							log "        Time left before timeout: `"$timeLeft`""
							if($timeLeft -lt $estDeleteTime) {
								log "        Looks like there's probably not enough time for any more deletions."
								$timedOut = $true
								break
							}
							else {
								log "        Looks like there's probably enough time for at least one more deletion."
								
								log "        Deleting profile..."
								$startDeleteTime = Get-Date
								$startDeleteDeletions = $profilesDeleted
								try {
									# Delete() method works with Get-WMIObject, but not with Get-CIMInstance
									# https://www.reddit.com/r/PowerShell/comments/7qu9dg/inconsistent_results_with_calling_win32/
									#$profile.Delete()
									$profile | Remove-CIMInstance
									log "            Profile deleted."
									$profilesDeleted += 1
								}
								catch {
									log "            Failed to delete profile."
									log ($_ | ConvertTo-Json | Out-String)
									$profilesFailed += 1
								}
								$endDeleteTime = Get-Date
								$deleteTime = New-TimeSpan -Start $startDeleteTime -End $endDeleteTime
								if($profilesDeleted -gt $startDeleteDeletions) {
									log "        Time taken to delete: `"$deleteTime`""
									if($deleteTime -gt $estDeleteTime) {
										log "        Deletion took longer than current estimate. Updating to `"$estDeleteTime`"."
										$estDeleteTime = $deleteTime
									}
								}
							}
						}
						log "Done deleting profiles."
					}
				}
			}
		}
	}
	
	function Start-AsyncJobRemoveProfilesFrom($comp) {
		# If there are already the max number of jobs running, then wait
		$running = @(Get-Job | Where { $_.State -eq 'Running' })
		if($running.Count -ge $MaxAsyncJobs) {
			$running | Wait-Job -Any | Out-Null
		}
		
		# After waiting, start the job
		Start-Job {
			Remove-ProfilesFrom $comp
		} | Out-Null
	}
	
	function Remove-ProfilesAsync($comps) {
		# Async example: https://stackoverflow.com/a/24272099/994622
		
		# For each computer start an asynchronous job
		foreach ($comp in $comps) {
			Start-AsyncJobRemoveProfilesFrom $comp
		}
		
		# Wait for all the jobs to finish
		Wait-Job * | Out-Null

		# Remove all the jobs
		Remove-Job -State Completed
	}
	
	function Remove-Profiles($comps) {
		log "Removing profiles..."
		
		if($MaxAsyncJobs -lt 2) {
			foreach($comp in $comps) {
				$comp = Remove-ProfilesFrom $comp
			}
		}
		else {
			$comps = Remove-ProfilesAsync $comps
		}
		
		log "Done removing profiles." -V 2
	}
	
	function Dump-SummaryInfo {
		log "Profiles total: $profilesCount"
		log "Filtered profiles targeted for deletion: $profilesAttempted"
		log "Targeted profiles successfully deleted: $profilesDeleted"
		log "Targeted profiles failed to delete: $profilesFailed"
	}
	
	function Return-Result {
		if($profilesFailed -lt 1) {
			if($timedOut) {
				Quit "Timeout reached. Before that, all targeted profiles were deleted successfully."
			}
			else {
				Quit "All targeted profiles were deleted successfully."
			}
		}
		else {
			if($profilesFailed -eq $profilesAttempted) {
				if($timedOut) {
					Quit "Timeout reached. Before that, all targeted profiles failed to delete!"
				}
				else {
					Quit "All targeted profiles failed to delete!"
				}
			}
			else {
				if($timedOut) {
					Quit "Timeout reached. Before that, some, but not all targeted profiles failed to delete."
				}
				else {
					Quit "Some, but not all targeted profiles failed to delete."
				}
			}
		}
	}
	
	function Do-Stuff {
		
		# Calculate timeout variables
		$startTime = Get-Date
		$endTime = $startTime.AddMinutes($TimeoutMins)
		$timedOut = $false

		# Tracking variables
		$profilesCount = 0
		$profilesAttempted = 0
		$profilesDeleted = 0
		$profilesFailed = 0
		$oldestDate = (Get-Date).AddDays(-$DeleteProfilesOlderThan)
		log "oldestDate: $oldestDate"
		
		# Dump some infos
		Dump-InitInfo
		
		if($DeleteProfilesOlderThan -lt 1) {
			Quit "-DeleteProfilesOlderThan value is less than 1!"
		}
		else {
			$comps = Get-Comps $Computers
			Remove-Profiles $comps
		}

		Dump-SummaryInfo

		Return-Result
	}
	
	Do-Stuff

	Quit "Unknown result."

	log "EOF"
}