##Write-Host  [char]0xFDFD

<# 
.Synopsis
This script will grab a bunch of metrics from the SQL server, looping all instances on this machine and generate some outputs.

.Description
Looping all instances on this server the script will attempt to gain access to the instance if none has been granted. The script will then update the support files and dump metrics. These metrics will also be uploaded to Lexel for further evaluation.

.Parameter Mode
The mode the script runs in, no value will set this script in default mode
Options are Default, Advanced and Auto.

.Example 
 # Run the script normally ,this script will not attempt to gain access to SQL server
.\SQLHealthCheck.ps1

.Notice
This script has the ability to grant access to SQL server. By running this script you take on all liability, risk and direct or indirect consequences to running this script
There is no guarantee, warranty of liability; implied, or otherwise; direct or indirect; to running the content of this file 
This script is distrubeted under the MIT License.
For more information  https://github.com/SQLAdrian/Lazydba/blob/master/LICENSE

.Example 
 # Run the script in advanced mode
.\SQLHealthCheck.ps1 -mode Advanced

# Run the script in advanced mode, this script will now attempt to gain access to SQL server
.\SQLHealthCheck.ps1 -mode Advanced -hack Yes

# Run the script in update mode, this will just update stored procedures
.\SQLHealthCheck.ps1 -mode Update

.Notes 
This script assumes you are running under an account with Administrative privelages

Version History 
v1.0 - 2017/03/01 - Adrian Sullivan - Initial release into the wild
v1.1 - 201/02/14 - Adrian Sullivan - Updated download files
No implied warranty, no guarantee, run this script at your own risk.

.Link 
http://lexel.co.nz, adrian.sullivan@lexel.co.nz
#> 
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false,Position=1)]
   [string]$Mode
   , [Parameter(Mandatory=$false,Position=2)]
   [string]$Hack
   , [Parameter(Mandatory=$false,Position=3)]
   [string]$DownloadPath
)

$Mode  = $Mode.ToUpper();
$Hack  = $Hack.ToUpper();
if(!($DownloadPath))
{
 $DownloadPath = pwd
}

#00. Configuration stuff for this scripts
#Add-Type -assembly "system.io.compression.filesystem"
$currentpath = $DownloadPath
$PushToDatabase = $False

if("neednewfolder" -eq "not now")
{
	$timestampforfile =  (get-date).ToString('yyyy_MM_dd_HH_mm');
	$outfolder = "$currentpath\$timestampforfile"
	New-Item -ErrorAction SilentlyContinue -ItemType directory -Path $outfolder | Out-Null
}

#Test for runas administrator, thanks Ben https://blogs.msdn.microsoft.com/virtual_pc_guy/2010/09/23/a-self-elevating-powershell-script/

# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

if($Mode -eq "ADVANCED")
{
	# Check to see if we are currently running "as Administrator"
	if ($myWindowsPrincipal.IsInRole($adminRole))
	{
	#   # We are running "as Administrator" - so change the title and background color to indicate this
	#   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
	#   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
	#   clear-host
	}
	else
	{
		Write-Host "This script needs to run as Administrator" -Foregroundcolor  "yellow"
		Write-Host "Press any key to continue. To cancel press 'N'" -Foregroundcolor  "yellow"
		$cancelnow = (Read-Host "Continue").ToUpper()
		if($cancelnow -eq "N")
		{
			Write-Host "Talk to the Lexel DBA team for more guidance" -Foregroundcolor  "yellow"
			exit
		}
		# We are not running "as Administrator" - so relaunch as administrator
		$args = "-file $currentpath\SQLHealthCheck.ps1"
		Start-Process powershell -verb runas -ArgumentList "-file $currentpath\SQLHealthCheck.ps1"
		# Exit from the current, unelevated, process
		exit
	}
}

#Exlude these files from being executed by the script when looping the .sql files
$ExludedFiles = @("sp_BlitzTrace.sql","00. TestPermission.sql","Check_BP_Servers.sql","MaintenanceSolution.sql")
$downloadsplease = $false

if( $mode -eq "UPDATE")
{
	$downloadsplease = $true
}

if($downloadsplease)
{
	#Single files first
    $urls  = @()
	
	$obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/SQLAdrian/Lazydba/master/SQLSteward.sql" 
	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "SQLSteward.sql" 
	$urls += $obj_c;

	$obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzWho.sql" 
	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "sp_BlitzWho.sql" 
	$urls += $obj_c;

    $obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_Blitz.sql" 
	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "sp_Blitz.sql" 
	$urls += $obj_c;

    $obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzCache.sql" 
	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "sp_BlitzCache.sql" 
	$urls += $obj_c;

    $obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzFirst.sql" 
    $obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "sp_BlitzFirst.sql" 
	$urls += $obj_c;

	$obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzIndex.sql" 
	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "sp_BlitzIndex.sql" 
	$urls += $obj_c;
	
	$obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/Microsoft/tigertoolbox/master/BPCheck/Check_BP_Servers.sql" 
	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "Check_BP_Servers.sql" 
	$urls += $obj_c;
#	
#	$obj_c = New-Object System.Object; 
#	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://raw.githubusercontent.com/olahallengren/sql-server-maintenance-solution/master/MaintenanceSolution.sql"
#	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "MaintenanceSolution.sql" 
#	$urls += $obj_c;
#	
#	$obj_c = New-Object System.Object; 
#	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://codeload.github.com/ktaranov/sqlserver-kit/zip/master" 
#	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "sqlserver-kit.zip" 
#	$urls += $obj_c;
#	
#	$obj_c = New-Object System.Object;
#	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://codeload.github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/zip/dev" 
#	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "SQL-Server-First-Responder-Kit.zip" 
#	$urls += $obj_c;
#	
#	$obj_c = New-Object System.Object; 
#	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://codeload.github.com/olahallengren/sql-server-maintenance-solution/zip/master" 
#	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "sql-server-maintenance-solution.zip" 
#	$urls += $obj_c;

#	$obj_c = New-Object System.Object; 
#	$obj_c | Add-Member -MemberType NoteProperty -Name URL -Value "https://github.com/SQLAdrian/Lazydba/raw/master/Resources.zip" 
#	$obj_c | Add-Member -MemberType NoteProperty -Name SaveAsName -Value "Resources.zip" 
#	$urls += $obj_c;






	$storageDir =  $DownloadPath;
	$webclient = New-Object System.Net.WebClient
	foreach( $url in $urls)
	{
		$file =$url.SaveAsName
		$file = ("$storageDir\$file").Replace("%20"," ");
		#Clean up old file
		if(Test-path $file) {Remove-item $file }

		Write-Host "Downloading update for $file"
		$webclient.DownloadFile($url.URL,$file)

    if($url.SaveAsName -eq "SQLSteward")
    {
         $file = "$storageDir\SQLSteward"
        $find = 'SET @RunUpdatedVersion = 1'
        $replace = 'SET @RunUpdatedVersion = 0'

        (Get-Content $file).replace($find, $replace) | Set-Content $file
    }
	}
    $webclient.Dispose()
}


#$SQLWriter_ImagePath =  "C:\Program Files\Microsoft SQL Server\90\Shared\sqlwriter.exe"
#"C:\Program Files\Microsoft SQL Server\90\Shared\sqlwriter.exe" -S <SERVER>{\INSTANCE} -E -Q "CREATE LOGIN [<DOMAIN>\lexeladmin] FROM WINDOWS; EXECUTE sp_addsrvrolemember @loginame = '<DOMAIN>\lexeladmin', @rolename = 'sysadmin'"
$account = whoami
Write-Progress -id 1 -Activity "Lexel: Running SQL data grabs" -Status "1% Complete:" -PercentComplete 1
			
#01. Get all SQL instances
$SQLInstances = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances;
$Server = hostname
#01.1 Get all network instances as well
# works but slows down things $NetworkSQL = (sqlcmd -L )

#Check if SQL server is running, if no instances are up then exit.
$SQLInstances = (get-service mssql*| Where-Object {$_.Status -ne "Stopped"  -AND $_.DisplayName -like "SQL Server (*"})
$SQLInstancesCount = 0;
foreach($countSQLInstances in $SQLInstances)
{
	$SQLInstancesCount ++;
}
if($SQLInstances.Count -eq 0)
{
	Write-Host "We couldn't find any active SQL services" -Foregroundcolor "Yellow"
	Write-Host "Try starting up the required instances and try again" -Foregroundcolor "Yellow"
}
else
{

}
#01.2 Loop all intances
foreach($RunningInstance in $SQLInstances)
{
	

	$SQLInstance = $RunningInstance.Name.Replace("MSSQL$","")
	Write-Host $RunningInstance.Name -Foregroundcolor "Yellow"
	if($SQLInstance -ne "MSSQLSERVER")
	{
		$SQLInstance = "$Server\$SQLInstance"
	}
	if($SQLInstance -eq "MSSQLSERVER")
	{
		$SQLInstance = "$Server"
	}
	#$SQLInstance
	Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "1% Complete:" -PercentComplete 1 
	#02. Test permissions
	$GetPermission = $false
	Try
	{
        $SQLQuery = "SET NOCOUNT ON;select 1 from sys.dm_broker_connections;"
	    $TestThisInstance = invoke-sqlcmd -ServerInstance $SQLInstance "$SQLQuery" -ErrorAction SilentlyContinue 
		#$TestThisInstance = oSQL -S $SQLInstance -E -Q  
        $TestThisInstance = sqlcmd -S $SQLInstance -E -d "master" -Q "$SQLQuery"
	}
	Catch [system.exception]
	{
		Write-Host 'Error during login. This sometimes occurs when SQL server runs using local computer Service accounts. Please check'
        $GetPermission = $true
	}
	$GetPermission = $false

    cd $currentpath
	
	Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "25% Complete:" -PercentComplete 25 

	#03. Now we will run the SQL scripts in this folder against each instance

	#Get file names to run
	$Folder = $DownloadPath
	$FileNames = Get-ChildItem -Path $Folder -Filter "*.sql" -exclude "Maintenance*","*Test*", "*BP_*" -Name | Sort-Object
	
	#Let's create the store procedures that we will be using, note that we are filtering only scripts that generate stored procedures
	#Run SQLCMD for each file
	
	Try
	{
		if( $mode -eq "UPDATE")
		{
			Write-Host "Let's update some scripts";
			#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			#THIS WILL UDPATE ALL STORED PROCEDURES
			#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			ForEach ($FileName in $FileNames)
			{

				foreach($urltotest in $urls)
				
				{
				if ($urltotest.SaveAsName  -contains $FileName)
					{
						Write-Host "Will do this one: $FileName"
						#If the file is not in the excluded list then run it
						$File = $DownloadPath + "\" + $FileName
						$OutFile = $File + ".csv"
						#sqlcmd -S $SQLInstance -E -i $File -s "~" -o $OutFile
						
						foreach( $url in $urls)
							{
								if($url.SaveAsName -eq $FileName)
								{
									Write-Host "Updating SP: $FileName";
									sqlcmd -S $SQLInstance -E -d "master" -I -i $File
								}
							}
					}
				}
			}
			#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			
		
		}
	}
	catch
	{
		Write-Host "Error encountered trying to parse $SQLInstance"
	}
	Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "100% Complete:" -PercentComplete 100
	$progress_overall = [math]::floor(95/($SQLInstancesCount))
	Write-Progress -id 1 -Activity "Lexel: Running SQL data grabs" -Status "$progress_overall% Complete:" -PercentComplete $progress_overall
	
}

Write-Host "I think we are done here for now." -Foregroundcolor Green

#	#Run SQLCMD for each file
#	ForEach ($FileName in $FileNames)
#
#	{
#	 $File = $Folder + $FileName
#	sqlcmd -S $SQLInstance -i $File
#
#	}


