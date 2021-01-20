##
#At the first time this script must be started via a PowerShell shell launched with administrator privileges
##
#Values of interest will be stored in Registry
##
#Logic of the check :
#compare the boot counter value saved in the registry (after the user logged in) and the current Power Cycle Count value
# if [registry_value] is equal to ([current_value] - 1) => ALL OK
#	-> ([-1] because the current boot doesn't count in our check)
# OR if [registry_value] is equal to ([current_value] => ALL OK as well
# 	-> This test was add because of the scheduled task used to launch the script at each user session login 
# else maybe a pb...
##

$logo = @"
  ____              _    _____ _               _             
 |  _ \            | |  / ____| |             | |            
 | |_) | ___   ___ | |_| |    | |__   ___  ___| | _____ _ __ 
 |  _ < / _ \ / _ \| __| |    | '_ \ / _ \/ __| |/ / _ \ '__|
 | |_) | (_) | (_) | |_| |____| | | |  __/ (__|   <  __/ |   
 |____/ \___/ \___/ \__|\_____|_| |_|\___|\___|_|\_\___|_|   
                                                             
                                                             
"@

function CheckForAdminConsole
{
	Write-Host "Checking for elevated permissions..."

	if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) 
	{
		Write-Warning "Insufficient permissions to run this script. Open the PowerShell console as an administrator and run this script again."
		Break
	}
	else 
	{
		Write-Host "Code is running as administrator. Go on executing the script..."
	}
}

function getPowerCycleCountSmartData
{
	$driveletter = 'C'

	$fulldiskid = (Get-Partition | Where DriveLetter -eq $driveletter | Select DiskId | Select-String "(\\\\\?\\.*?#.*?#)(.*)(#{.*})")

	$diskid = $fulldiskid.Matches.Groups[2].Value

	try
	{
		$rawsmartdata = (Get-WmiObject -Namespace 'Root\WMI' -Class 'MSStorageDriver_ATAPISMartData' -ErrorAction Stop | Where-Object 'InstanceName' -like "*$diskid*" | Select-Object -ExpandProperty 'VendorSpecific')
	}
	catch
	{
		Write-Output "[!] The Get-WmiObject on class 'MSStorageDriver_ATAPISMartData' threw an exception: Your HDD/SSD may doesn’t support S.M.A.R.T."
		Exit
	}

	log -Message "Get Power Cycle Count Smart Data info"
	
	For ($i = 2; $i -lt $rawsmartdata.Length; $i++)
	{
		If (0 -eq ($i - 2) % 12 -And $rawsmartdata[$i] -ne "0")
		{
			# Get the Power Cycle Count data (id = 12 in decimal)
			If ($rawsmartdata[$i] -eq 12)
			{
				# Get the raw attribute value
				$rawvalue = ($rawsmartdata[$i + 6] * 256 + $rawsmartdata[$i + 5])
				return $rawvalue;
			}
		}
	}
}

# Function used for the first time usage
function checkIfBCRegistryKeyExists($HddName)
{
	If (Test-Path 'HKLM:\SOFTWARE\BootCounter')
	{
		log -Message "Key exists let's check the boot counter..."
		$ret = checkIfBootCounterExists -HddName $HddName
		If ($ret -eq $true) {return $true}
		Else 
		{
			warningHDDModel
			return $false
		}
	}
	Else {
			#replace by a popup ?
			Write-Host "No registry key detected ... first time usage ?"
			Write-Host ""
			Write-Host "[Y] Yes first time usage"
			Write-Host "[N] Nope... it's weird..."
			Write-Host ""
			Write-Host -nonewline "Type your choice (Y/N) and press enter:"
			$choice = read-host
			$check = $choice -match '^[yn]+$'
			If (-not $check) {Write-Host "Invalid choice ! Focus !"}
			Else {
					switch -Regex ($choice)
					{
						"Y"
						{
							Write-Host "Ok it's your first time ! Welcome !! initialization ongoing ..."
							initialization -HddName $HddName
						}
						"N"
						{
							Write-Host "mmmmh that's weird..."
							#additional checks TODO ?
						}
					}
				}
		}
}

function checkIfBootCounterExists($HddName)
{
	If (Get-ItemProperty -Path 'HKLM:\SOFTWARE\BootCounter' -Name $HddName -ErrorAction SilentlyContinue) 
	{
		log -Message "Registry check : Value $HddName exists let's get its boot counter..."
		return $true
	}
	Else
	{
		log -Message "Registry check : No value $HddName detected... HDD model may have changed please check..."
		return $false
	}
}

function getBootCounter($HddName)
{
	$value = Get-ItemProperty -Path 'HKLM:\SOFTWARE\BootCounter' -Name $HddName 
	$bootcounter = $value.$HddName
	log -Message "Power Cycle Count = $bootcounter"
	return $bootcounter
}

function popupAnomalyBC
{
	$pop = New-Object -ComObject Wscript.Shell
	#$result will be 1
	$result = $pop.popup("Anomaly detected in the boot counter...", 0, "Boot Checker", 0+48)
}

function initialization($HddName)
{
	# This function is used at the first time usage
	# Initialization function will set up the following items :
	# - HKLM:\SOFTWARE\BootCounter registry key
	# - HKLM:\SOFTWARE\BootCounter\xxx registry value
	# -- Where the name of the value depends on the name of your HDD/SSD
	# -- the data of this value is the current Power Cycle Count Smart data of your HDD/SSD
	# - creation of the Logs directory, at the root of the current directory where this script is stored
	
	$pop = New-Object -ComObject Wscript.Shell
	
	$currentPCCSmartData = getPowerCycleCountSmartData
	$currentPCC = $currentPCCSmartData
	
	$curdir = Get-Location
	
	initRegistry -HddName $HddName -PCcounter $currentPCC
	initLogDir
	log -Message "init info HKLM:\SOFTWARE\BootCounter registry key created"
	log -Message "init info HKLM:\SOFTWARE\BootCounter\$HddName registry value created and data set to $currentPCC"

	log -Message "Initialization done"
	
	$pop.popup("Initialization finished... Exiting", 0, "Boot Checker", 0+48)
	exit
}

function initLogDir
{
	$currentDir = Get-Location
	$logDirPath = "$currentDir\Logs"
	$isLogDirPresent = Test-Path $logDirPath -PathType Container
	
	If ($isLogDirPresent -eq $false)
	{
		New-Item -Path $currentDir -Name "Logs" -ItemType "directory"
	}
	
	Set-ItemProperty -Path 'HKLM:\SOFTWARE\BootCounter' -Name "FilePath" -Value $logDirPath
	
	log -Message "init info Logs directory created"
	log -Message "init info BootCheckerLog registry value created"
}

function initRegistry($HddName, $PCcounter)
{
	If (Get-ItemProperty -Path 'HKLM:\SOFTWARE\' -Name 'BootCounter' -ErrorAction SilentlyContinue)
	{
		return
	}
	Else
	{
		New-Item -Path 'HKLM:\SOFTWARE\' -Name 'BootCounter' –Force
				
		Set-ItemProperty -Path 'HKLM:\SOFTWARE\BootCounter' -Name $HddName -Value $PCcounter		
	}
	return
}

function warningHDDModel
{
	$msg = "No value $hddname detected... HDD model may have changed please check..."
	$pop = New-Object -ComObject Wscript.Shell
	
	log -Message $msg
	$pop.popup($msg, 0, "Boot Checker", 0+48)
	
	exit
}

function updateBootCounter($HddName, $currentPCCVal)
{
	Set-ItemProperty -Path 'HKLM:\SOFTWARE\BootCounter' -Name $HddName -Value $currentPCCVal -Force
	log -Message "Power Cycle Count value = $currentPCCVal"
}

function log($Message)
{
	$logpath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\BootCounter\' -Name 'FilePath' -ErrorAction SilentlyContinue).filepath
	
	$logfilefullpath = "$logpath\$logfile"
	
	$curdate = Get-Date -Format "[MM/dd/yyyy HH:mm:ss K]"
	$fullmsg = "$curdate $Message"
	
	Out-File -FilePath $logfilefullpath -InputObject $fullmsg -Encoding UTF8 -Append
}

function initTheMainHdd($hdd)
{
	$dl = 'C'
	$fdid = (Get-Partition | Where DriveLetter -eq $dl | Select DiskId | Select-String "(\\\\\?\\.*?#.*?#)(.*)(#{.*})")
	$details = $fdid.Matches.Groups[1].Value -split '&'
	$vendorP = $details[1] -split '_'
	Foreach ($h in $hdd)
	{
		If ($h.friendlyname -Match $vendorP[1])
		{
			$Phdd = $h.number
		}
	}
	Write-Host "OK BootChecker will be setup for the main HDD..."
	Write-Host "Your main HDD is :"
	write-output($hdd[$Phdd])
	Write-Host ""
	Write-Host -nonewline "Is it correct ?(Y/N)"
	$choicephdd = read-host
	$checkcph = $choicephdd -match '^[yn]+$'
	If (-not $checkcph) {Write-Host "Invalid choice ! Focus !"}
	Else {
			switch -Regex ($choicephdd)
			{
				"Y"
				{
					$HddName = $hdd[$Phdd].friendlyname+' '+$hdd[$Phdd].serialnumber;
					initialization -HddName $HddName
				}
				"N"
				{
					$choicenumber = $hdd.number
					Write-Host "OK sorry shit happens... here is your hdd list:"
					write-output($hdd)
					Write-Host ""
					Write-Host "I will trust your next choice so please no joke or the setup of BootChecker will be compromised..."
					Write-Host ""
					Write-Host -nonewline "Please enter the number of your main HDD:($choicenumber)"
					$mchoicephdd = read-host
					$HddName = $hdd[$mchoicephdd].friendlyname+' '+$hdd[$mchoicephdd].serialnumber;
					initialization -HddName $HddName
				}
			}
		}
}

Write-Host $logo

CheckForAdminConsole

$script:sname = $MyInvocation.MyCommand.Name

$logdate = Get-Date -Format "MM-dd-yyyy"
$script:logfile = 'BootCheckerLog_' + $logdate + '.txt'

$hdd = get-disk;

If ($hdd.Count -ge 1)
{
	Write-Host "Multiple Hard Drive Disks have been detected..."
	Write-Host ""
	write-output($hdd)
	Write-Host ""
	Write-Host "Choose how to setup BootChecker :"
	Write-Host ""
	Write-Host "[P] Setup BootChecker for the main HDD (with the OS)"
	Write-Host "[A] Setup BootChecker for ALL HDDs"
	Write-Host ""
	Write-Host -nonewline "Type your choice (P/A) and press enter:"
	$choicehdd = read-host
	$checkch = $choicehdd -match '^[pa]+$'
	If (-not $checkch) {Write-Host "Invalid choice ! Focus !"}
	Else {
			switch -Regex ($choicehdd)
			{
				"P"
				{
					initTheMainHdd -hdd $hdd
				}
				"A"
				{
					Write-Host "Well... this choice will be available in the next update so stay tuned !"
					initTheMainHdd -hdd $hdd
				}
			}
		}
}
Else
{
	$HddName = $hdd[0].friendlyname+' '+$hdd[0].serialnumber;
}

$PCCSmartData = getPowerCycleCountSmartData
$currentPCC = [Int]$PCCSmartData

$check = checkIfBCRegistryKeyExists -HddName $HddName
If ($check -eq $true)
{
	$counter = getBootCounter -HddName $HddName
	If (([int]$counter -eq ($currentPCC - 1)))
	{
		log -Message "Check Boot Counter [SUCCESS]"
		updateBootCounter -HddName $HddName -currentPCCVal $currentPCC
		log -Message "Boot counter updated"
	}
	Elseif ([int]$counter -eq $currentPCC)
	{
		log -Message "Boot Counter already equal to the Power Cycle Count smart data"
		log -Message "Check Boot Counter [SUCCESS]"
	}
	Else
	{
		log -Message "Check Boot Counter [FAIL]"
		log -Message "Recorded Boot Counter [$counter]"
		log -Message "Current Power Cycle Count [$currentPCC]"
		popupAnomalyBC
	}
}

