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
)

$Mode  = $Mode.ToUpper();
$Hack  = $Hack.ToUpper();

#00. Configuration stuff for this scripts
Add-Type -assembly "system.io.compression.filesystem"
$currentpath = $pwd
$PushToDatabase = $False

#Extract Scripts.zip file containing all out working bits
$MostRecentScriptFile = Get-ChildItem *"Resources.zip" | Sort-Object Name -descending | Select-Object -First 1
if($MostRecentScriptFile)
{
	$shell_app = new-object -com shell.application
	$zip_file = $shell_app.namespace((Get-Location).Path + "\" + $MostRecentScriptFile.Name)
	$destination = $shell_app.namespace((Get-Location).Path)
	$destination.Copyhere($zip_file.items(), 0x14)
}
else
{
	if($Mode -ne "AUTO")
	{
		Write-Host "Let us update the support files.." -Foregroundcolor "magenta"
		Write-Host "Let's try to download them." -Foregroundcolor "magenta"
		$url = "https://github.com/SQLAdrian/Lazydba/raw/master/Resources.zip"
		$storageDir = $pwd
		try
		{
			$webclient = New-Object System.Net.WebClient
			
			$arr = $url -split ""
			[array]::Reverse($arr)
			$url2 = $arr -join ''
			$file = $url.Substring($url.Length - $url2.IndexOf("/"))
			$file = "$storageDir\$file"
			$webclient.DownloadFile($url,$file)
			
		}
		catch
		{
		
		}
		$MostRecentScriptFile = Get-ChildItem *"Resources.zip" | Sort-Object Name -descending | Select-Object -First 1
		if(!($MostRecentScriptFile))
		{
			Write-Host "Could not download. Exiting"
			exit
		}
		$shell_app = new-object -com shell.application
		$zip_file = $shell_app.namespace((Get-Location).Path + "\" + $MostRecentScriptFile.Name)
		$destination = $shell_app.namespace((Get-Location).Path)
		$destination.Copyhere($zip_file.items(), 0x14)
	}
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

if $mode -eq "UPDATE")
{
	$downloadsplease = $true
}

if($downloadsplease)
{
	$urls = @("https://raw.githubusercontent.com/SQLAdrian/Lazydba/master/sqlsteward.sql" `
	, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzWho.sql" `
	, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_Blitz.sql" `
	, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzCache.sql" `
	, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzFirst.sql" `
	, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzIndex.sql" `
	, "https://raw.githubusercontent.com/Microsoft/tigertoolbox/master/BPCheck/Check_BP_Servers.sql" `
	, "https://raw.githubusercontent.com/olahallengren/sql-server-maintenance-solution/master/MaintenanceSolution.sql" `
	)
	#Leave out the big ones for now
	#, "https://codeload.github.com/ktaranov/sqlserver-kit/zip/master" `
	#, "https://codeload.github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/zip/dev" `
	#, "https://codeload.github.com/olahallengren/sql-server-maintenance-solution/zip/master" `
	
	$storageDir = $pwd
	$webclient = New-Object System.Net.WebClient
	foreach( $url in $urls)
	{
		$arr = $url -split ""
		[array]::Reverse($arr)
		$url2 = $arr -join ''
		$file = $url.Substring($url.Length - $url2.IndexOf("/"))
		$file = ("$storageDir\$file").Replace("%20"," ");
		$webclient.DownloadFile($url,$file)
	}
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

#Check if SQL server is running, if no instances are up then exit.
$SQLInstances = (get-service mssql*| Where-Object {$_.Status -ne "Stopped"  -AND $_.DisplayName -like "SQL Server (*"})
if($SQLInstances.Count -eq 0)
{
	Write-Host "We couldn't find any active SQL services" -Foregroundcolor "Yellow"
	Write-Host "Try starting up the required instances and try again" -Foregroundcolor "Yellow"
}
else
{
	$timestampforfile =  (get-date).ToString('yyyy_MM_dd_HH_mm');
	$outfolder = "$currentpath\$timestampforfile"
	New-Item -ErrorAction Ignore -ItemType directory -Path $outfolder | Out-Null
}
#01.2 Loop all intances
foreach($RunningInstance in $SQLInstances)
{
	try
	{
	$SQLInstance = $RunningInstance.Name.Replace("MSSQL$","")
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
        
	}
	Catch [system.exception]
	{
		Write-Host 'Error during login'
        $GetPermission = $true
	}
	
    cd $currentpath
	
	if($Mode -eq "ADVANCED" -AND $Hack -eq "Yes")
	{
		$GetPermission = $true
	}
	else
	{
		$GetPermission = $false
	}
	
	
	if($GetPermission)
	{
        Write-Host "Login failed, attempting to gain access"
		#Connecting to this server failed, we can brute force out way in if required
		$BruteForce = $true
		
		#02.1 Test if current user is some sort of administrator, we are looking for local or domain level admin
		
		#Running as Administrator
		$RunAsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
		Write-Host "You are an admin: $RunAsAdmin"
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
                $TestZippath = ("$currentpath\$extractfile").Replace(".zip",".exe")
                if(!(Test-Path "$TestZippath"))
                {
                    try 
                    {
                        [io.compression.zipfile]::ExtractToDirectory($BackUpPath, $destination)
                    }
                    catch
                    {
					    Write-Host "Error with zip file"
                        #file already exists
                    }
                }
				
			}
			$I = 10
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			#We won't try to gain access using PsExec, but will directly grant sysadmin rights to this account on the SQL server.
			Write-Host "You are about to force access to the $SQLInstance SQL instance" -Foregroundcolor Red
			
			
			#Stop the VSS writer service
			#Write-Host "DEBUG > Stopping SQLWriter Service"
			#cannot find..??
			
			$SQLWriter =  get-service SQLWriter
			if( $SQLWriter.Status -eq "Running")
			{
				try {$sqltokill = get-process sqlwriter;$sqltokill.kill() } catch{}
			}
			#while($SQLWriter.Status -ne 'Stopped')
			#{
			#   Start-Sleep -Seconds 0.5
			#   Write-Host "Waiting for SQL Writer to stop"
			#}
			
			
			#Rename the original SQL Writer to a bak_ version
			#Write-Host "DEBUG > renaming sqlwriter files"
            try
            {
			    Rename-Item $SQLWriter_ImagePath.replace('"', '') bak_sqlwriter.exe
			    Rename-Item "$currentpath\sqlwriter_hack.exe" sqlwriter.exe
                Copy-Item "$currentpath\sqlwriter.exe" $SQLWriter_ImagePathFileLocation
			}
            catch
            {
                #Assume files are already there
            }
			
			$I = 15
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			$newvalue = ''+$SQLWriter_ImagePath+' -S '+$SQLInstance+' -E -Q "CREATE LOGIN ['+$account+'] FROM WINDOWS; EXECUTE sp_addsrvrolemember @loginame = '''+$account+''', @rolename = ''sysadmin''"'
			
			Get-ItemProperty -path $path -name ImagePath -ErrorAction SilentlyContinue | % { Set-ItemProperty -path $_.PSPath -name ImagePath $newvalue }
			try
			{
				#The restart will fail becuase of the change in registry that now granted access to the instance
				Start-Service sqlwriter -ErrorAction Stop # -ErrorAction Stop
			}
			catch
			{
				$I = 45
				Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			}
			#put the files back
			Remove-Item "$SQLWriter_ImagePathFileLocation\sqlwriter.exe"
			Rename-Item "$SQLWriter_ImagePathFileLocation\bak_sqlwriter.exe"  sqlwriter.exe
			Remove-Item "$currentpath\sqlwriter.exe"
			$I = 65
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I
			
			Get-ItemProperty -path $path -name ImagePath -ErrorAction SilentlyContinue | % { Set-ItemProperty -path $_.PSPath -name ImagePath $SQLWriter_ImagePath }
			Restart-Service sqlwriter
			$I = 100
			Write-Progress -Activity "Hacking $SQLInstance in Progress" -Status "$I% Complete:" -PercentComplete $I	
			Write-host "Congratulations, you should now be a sysadmin on this SQL instance"
			Start-Service sqlwriter
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
	
	
	if( $mode -eq "UPDATE")
	{
		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		#THIS WILL UDPATE ALL STORED PROCEDURES
		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		ForEach ($FileName in $FileNames)
		{
			if(!($ExludedFiles -contains $File))
			{
				#If the file is not in the excluded list then run it
				$File = $Folder.Path + "\" + $FileName
				$OutFile = $File + ".csv"
				#sqlcmd -S $SQLInstance -E -i $File -s "~" -o $OutFile
				sqlcmd -S $SQLInstance -E -I -i $File
			}
		}
		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		
	
	}
	else
	{
	#Now we need to run the stored procedures
	#sqlcmd -S $SQLInstance -Q "" -i $File -s "~" -o $OutFile;
	$datestamp = Get-Date
	$domain = (Get-WmiObject Win32_ComputerSystem).Domain.replace(".local","")
	$datasource = ".windows.net"
	$datausername = ""
	$datapassword = ""
	$database = ""
	$DBSchema = "Access"
	$connectionstring = "Data Source=$datasource;User=$datausername;password=$datapassword;Initial Catalog=$database" 
	$batchsize = 5000 
	
	$SQLnameforfile = $SQLInstance.Replace("\","_");
	
	
	#Create container
	$ScriptsConfig  = @()
	
	$obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name ScriptName -Value "sqlsteward" 
	$obj_c | Add-Member -MemberType NoteProperty -Name spCommand -Value "EXEC [dbo].[sqlsteward] @TopQueries = 50, @FTECost  = 60000, @ShowQueryPlan = 0, @PrepForExport = 1;"
	$ScriptsConfig += $obj_c;
	
	$obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name ScriptName -Value "sp_Blitz" 
	$obj_c | Add-Member -MemberType NoteProperty -Name spCommand -Value "EXEC [dbo].[sp_Blitz] @CheckUserDatabaseObjects = 1 ,@CheckProcedureCache = 1 ,@OutputType = 'TABLE' ,@OutputProcedureCache = 0 ,@CheckProcedureCacheFilter = NULL,@CheckServerInfo = 1;" 
	$ScriptsConfig += $obj_c;
	
	$obj_c = New-Object System.Object; 
	$obj_c | Add-Member -MemberType NoteProperty -Name ScriptName -Value "sp_BlitzIndex" 
	$obj_c | Add-Member -MemberType NoteProperty -Name spCommand -Value "EXEC [dbo].[sp_BlitzIndex] @Mode = 4, @SkipStatistics = 0, @GetAllDatabases = 1, @OutputServerName = 1, @OutputDatabaseName = 1;"
	$ScriptsConfig += $obj_c;
	

	
	
	$currentscript = 1
	Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "25% Complete:" -PercentComplete 25 
	Write-Progress -id 4 -ParentId 2 -Activity "Lexel: Running SQL Scripts" -Status "0% Complete:" -PercentComplete 0
	foreach($script in $ScriptsConfig)
	{
		$ScriptName = $script.ScriptName
		$spCommand = $script.spCommand
		$targetTable = "$DBSchema"+"."+"$ScriptName"
		Write-Progress -id 3 -ParentId 2 -Activity "SQL running $ScriptName" -Status "0% Complete:" -PercentComplete 0
	
	
		$OutFile = "$outfolder" + "\" + $SQLnameforfile + "_" + $timestampforfile + "_" + "$ScriptName" + ".csv"
		$SQLout = @(invoke-sqlcmd -ServerInstance $SQLInstance "$spCommand" -QueryTimeout 1200 )
		Write-Progress -id 3 -ParentId 2 -Activity "$ScriptName exporting to CSV" -Status "50% Complete:" -PercentComplete 50
		#dump into CSV so it exists somewhere
		$SQLout | export-csv -notypeinformation -path $OutFile
		
		if($PushToDatabase)
		{
			# Create the datatable, and autogenerate the columns. 
			$datatable = New-Object System.Data.DataTable ;
			#Get your columns from the target database mate
			$SQLQuery = "SELECT c.name FROM sys.columns c INNER JOIN sys.tables t ON t.object_id = c.object_id INNER JOIN sys.schemas s ON s.schema_id = t.schema_id WHERE s.name +'.'+ t.name = '$targetTable' ORDER BY c.column_id"
			$columns = @((invoke-sqlcmd -ServerInstance $datasource -Database $database -username $datausername -password $datapassword -query "$SQLQuery" -QueryTimeout 1200 ).Name)
			
			Write-Progress -id 3 -ParentId 2 -Activity "$ScriptName exporting to SQL" -Status "60% Complete:" -PercentComplete 60
			foreach ($column in $columns) {$datatable.Columns.Add($column) | Out-Null; };
			#After datatable has been created, add the following default valued columns if they don't exist as yet
			foreach($datarow in $SQLout)
			{
				$newrow = $dataTable.NewRow();
				foreach ($column in $columns) {$newrow[$column] = $datarow.$column};
				if(!($datarow.evaldate)){$newrow["evaldate"] = $datestamp.ToString()};
				if(!($datarow.domain)){$newrow["domain"] = $domain.ToString()};
				if(!($datarow.SQLInstance)){$newrow["SQLInstance"] = $SQLInstance};
				if($ScriptName -eq "sp_BlitzIndex" )
				{
					if(!($datarow."Details: schema.table.index(indexid)")){$newrow["Details"] = $datarow."Details: schema.table.index(indexid)"};
					if(!($datarow."Definition: [Property] ColumnName {datatype maxbytes}")){$newrow["Definition"] = $datarow."Definition: [Property] ColumnName {datatype maxbytes}"};
				}
				$datatable.Rows.Add($newrow);
			}
			if("This still has to be " -eq "configured")
			{
				$bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($connectionstring, [System.Data.SqlClient.SqlBulkCopyOptions]::TableLock) 
				$bulkcopy.DestinationTableName = $targetTable
				$bulkcopy.bulkcopyTimeout = 0 
				$bulkcopy.batchsize = $batchsize 
				try
				{
					$bulkCopy.WriteToServer($datatable)
				}
				catch
				{
					Write-Host "Error writing to SQL server" -Foregroundcolor Red
				}
			}
		}
		Write-Progress -id 3 -ParentId 2 -Activity "Lexel: Running SQL $ScriptName" -Status "100% Complete:" -PercentComplete 100
############################
		$progress_scripts = [math]::floor((($currentscript)/($ScriptsConfig.Count))*100)
		Write-Progress -id 4 -ParentId 2 -Activity "Lexel: Running SQL scripts" -Status "$progress_scripts% Complete:" -PercentComplete $progress_scripts
		$currentscript ++
		$overall_progress_instance = [math]::floor(75*$progress_scripts/100)
		Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "$overall_progress_instance% Complete:" -PercentComplete $overall_progress_instance 
	}
	}
	}
	catch
	{
		Write-Host "Error encountered trying to parse $SQLInstance"
	}
	Write-Progress -id 2 -ParentId 1 -Activity "Lexel: Parsing $SQLInstance" -Status "100% Complete:" -PercentComplete 100
	$progress_overall = [math]::floor(95/($SQLInstances.Count))
	Write-Progress -id 1 -Activity "Lexel: Running SQL data grabs" -Status "$progress_overall% Complete:" -PercentComplete $progress_overall
	
}

if( $mode -ne "UPDATE")
{
	$outputzipdestination = "$currentpath" + "\" + $SQLnameforfile + "_" + $timestampforfile + ".zip"
	If(Test-path $outputzipdestination) {Remove-item $outputzipdestination}
	if($outfolder)
	{
		[io.compression.zipfile]::CreateFromDirectory($outfolder , $outputzipdestination) 
		If(Test-path $outfolder) {Remove-item $outfolder -Recurse}
	}
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


