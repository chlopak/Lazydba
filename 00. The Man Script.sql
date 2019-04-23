PRINT 'SQL server evaluation script @ 24 March 2019 af.sullivan@outlook.com ' + NCHAR(65021)
DECLARE @License NVARCHAR(4000)
SET @License = '----------------
MIT License
Copyright (c) ' + CONVERT(VARCHAR(4),DATEPART(YEAR,GETDATE())) + ' Adrian Sullivan

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
----------------
'
SET NOCOUNT ON
SET ANSI_WARNINGS ON
SET QUOTED_IDENTIFIER ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/* Before doing anything, you can rather run the current version of this script from the interwebs*/
use [Master]
DECLARE @pstext VARCHAR(8000)

BEGIN
	/*Generate PowerShell to download your file*/
	EXEC sp_configure 'show advanced options', 1
	RECONFIGURE
	-- enable xp_cmdshell
	EXEC sp_configure 'xp_cmdshell', 1
	RECONFIGURE
	-- hide advanced options
	EXEC sp_configure 'show advanced options', 0
	RECONFIGURE
	SET @pstext = '$thispath = pwd;' ;
	SET @pstext = @pstext + '$notthispath = "C:\Windows\system32"; ';
	SET @pstext = @pstext + ' ; ';
	SET @pstext = @pstext + 'if($thispath.Path -eq $notthispath)';
	SET @pstext = @pstext + '{$thispath = "C:\Temp"};'; /*{$thispath = $env:TEMP};*/
	SET @pstext = @pstext + '$url = "https://raw.githubusercontent.com/SQLAdrian/Lazydba/master/SQLHealthCheck.ps1" ;';
	SET @pstext = @pstext + '$path = "$thispath\SQLHealthCheck.ps1";';
	SET @pstext = @pstext + '$thispath;';
	SET @pstext = @pstext + '$this = (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/SQLAdrian/Lazydba/master/SQLHealthCheck.ps1");';
	SET @pstext = @pstext + '$this| Out-File $path;';
    SET @pstext = @pstext + 'Write-Host "Go to $thispath to see the files";';
	SET @pstext = @pstext + 'cd $thispath;';
	SET @pstext = @pstext + '.\SQLHealthCheck.ps1 -mode UPDATE -DownloadPath $thispath;';
	--SET @pstext = @pstext + 'sqlcmd -S $SQLInstance -E -I -i $File";';
	--SET @pstext = @pstext + ' |ConvertTo-XML -As string '
	SET @pstext = REPLACE(REPLACE(@pstext,'"','"""'),';;',';')
	SET @pstext = 'powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -Command "' + @pstext + '" '
	PRINT @pstext
	EXEC xp_cmdshell @pstext
END

	EXEC dbo.sp_BlitzWho 
		@ShowSleepingSPIDs =1,
		@ExpertMode = 1

	EXEC master.[dbo].[sqlsteward] 
		@TopQueries = 50
		, @FTECost  = 60000
		, @ShowQueryPlan = 1
		, @PrepForExport = 1
		, @Export = 'Screen' 
		, @ExportSchema   = 'dbo'
		, @ExportDBName = 'master'
		, @ExportTableName = 'sqlsteward_output'
		, @ExportCleanupDays  = 180

	EXEC [dbo].[sp_Blitz] 
		@CheckUserDatabaseObjects = 1 
		, @CheckProcedureCache = 1 
		, @OutputType = 'TABLE' 
		, @OutputProcedureCache = 0 
		, @CheckProcedureCacheFilter = NULL
		, @CheckServerInfo = 1
		, @OutputXMLasNVARCHAR = 1
		, @OutputDatabaseName = 'master'
		, @OutputSchemaName = 'dbo'
		, @OutputTableName = 'sp_Blitz_output'

IF 1 = 2 --Optional 
BEGIN
	EXEC dbo.sp_BlitzFirst 
		@ExpertMode = 1
		, @CheckProcedureCache = 1
		, @FileLatencyThresholdMS = 0
		, @Seconds = 30;

	EXEC [dbo].[sp_BlitzIndex] @Mode = 4, @SkipStatistics = 0, @GetAllDatabases = 1, @OutputServerName = 1, @OutputDatabaseName = 1;
END



