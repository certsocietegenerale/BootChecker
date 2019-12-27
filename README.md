# BootChecker

**Disclaimer**: _Our script relies – among other things - on the idea of Ivan Kwiatkowski [@JusticeRage](https://twitter.com/justicerage) presented at BotConf 2018 during the Lightning talks session. 
The original script developed by Ivan is available on his Github repository:_ https://github.com/JusticeRage/freedomfighting/blob/master/boot_check.py.

_Our script is still in development; it’s shared here as proof of concept and can be used publicly. However, please keep in mind that it’s not a “security product”. So, please check for known bugs before installing and using BootChecker._

## 1)	Introduction

Ivan released his script at the end of 2018. No Windows version was available at that time. So we decided to make one.

We used PowerShell scripting language to tale advantage from full access to the Windows Management Instrumentation components and to get the S.M.A.R.T data without a third-party software.

The main goal of this script is quite simple: get the **power cycle count S.M.A.R.T** data from the HDD/SSD used to store your operating system and store it in the registry. At the next boot or log-in session the script will execute to compare the value stored inside the registry with the actual value of the **power cycle count S.M.A.R.T** data. 

If the result is a difference of one everything is good. **If you have a difference of more than one you may be facing an Evil-Maid attack** (or a special situation due to your IT environment or Windows itself… – see *the known limitations section : Microsoft Windows Hibernation*).

## 2)	Installation

We tried to make the installation as easy as possible.
a)	Create a directory where you want to store the PowerShell script.
b)	Copy/paste the PowerShell script to this newly created directory.
c)	Launch a PowerShell shell with the administrator privileges and move inside the created directory.
d)	The script will launch some check and will ask you if it is your first-time usage - type Y.
e)	If the script detects more than one HDD/SDD, it will try to detect your main HDD/SSD and will ask you if it’s OK; otherwise you can choose your main disk yourself.
f)	At the first-time usage, the script will create:
i)	The data it needs inside the registry.
ii)	The **Logs** directory at the root of the current directory (where the script is stored).

And that’s all for the script. Now each time you will launch it, it will check if there is a difference in the power cycle count S.M.A.R.T data.

**We let you choose your method to run this script automatically at each boot or log-in session since it depends on your IT environment.** We give you an example of a scheduled task used to test the script in our IT environment (see in the annexe section). This scheduled task will launch the boot checker script each time a user will log into his session.

This script was developed and tested with PowerShell version 5.1.16299.1146.

## 3)	Usage

As described above, this script will compare the previous value of **power cycle count S.M.A.R.T** data stored inside a registry key with the current **power cycle count S.M.A.R.T** value.

If a difference is greater than one is detected, a warning popup will be displayed.

 

The script fills out a log file each time it runs. The log file contains basic data like the result of the value comparison and the value of the previous and current **power cycle count S.M.A.R.T counter**. Each line of log is timestamped.

## 4)	Evil maid attack

“*An evil maid attack is an attack on an unattended device, in which an attacker with physical access alters it in some undetectable way so that they can later access the device, or the data on it.*” [Wikipedia](https://en.wikipedia.org/wiki/Evil_maid_attack)

In our scenario, you left your laptop unattended and someone wanted to dump the content of your HDD/SSD. We assume you have locked your session, put your system in hibernation or shut down your computer prior to leaving it alone. If an attacker wants to dump your HDD/SSD data, he has two options: 
* Physically open your laptop, extract your HDD/SSD and use a tool (or another computer) to copy the data.
* Reboot your laptop on a live operating system from a custom USB key.

On both case the HDD/SSD will be powered-on and its **power cycle count S.M.A.R.T** data will be incremented by one. This modification will be detected by the script, which will warn you with a pop-up. 


## 5)	Known limitations

### a)	Microsoft Windows Hibernation Microsoft-Windows-Power-Troubleshooter

If you leave your computer in the sleep/hibernation mode, sometimes the Windows system can exit from sleep/hibernation state and power on your HDD/SSD for different reasons. This will increment the **power cycle count S.M.A.R.T** data of your HDD/SSD and the next time the script will be launched it will raise an alert. A false-positive one.

After some checks, we noticed that event id’s 42 and 107 from Kernel-power source are present when this kind of event occurs. 

 

**In the next update the script will check if event-id 42 or 107 are present to try to detect false positives and it will ask you if your computer has been left in sleep/hibernation state.**

### b)	You have more than one HDD/SDD in your computer

As previously mentioned, the script will attempt to detect your main HDD/SSD during the first initialization. At that moment, the security check related to the **power cycle count S.M.A.R.T** data is only performed on the main HDD/SSD. If you have sensible data on a second HDD/SSD and someone extracts it with a duplication action, the script will not warn you about this.

**The check for additional HDD/SSD will be added in the next update.**
