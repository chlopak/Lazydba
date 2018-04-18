PRINT 'SQL server evaluation script @ 11 July 2017 adrian.sullivan@lexel.co.nz ' + NCHAR(65021)
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

/* Reference sources. Sources refer either to articles offering great insight, or to clever ways to look at data.
All code used in this script is original code and great effort has been made to ensure that no copy/past extracts have been taken from any source. 
There are tons of folk out there who have contributed to this effort in some form or another. Attempts have been made to quote sources and authors where available.
If you feel any contribution should further be accredited or referenced, please let me know, I would appreciate and make the required changes.
*/
SET NOCOUNT ON
DECLARE @References TABLE(Authors VARCHAR(250), [Source] VARCHAR(250) , Detail VARCHAR(500))
INSERT INTO @References VALUES ('Brent Ozar Unlimited','http://FirstResponderKit.org', 'Default Server Configuration values')
INSERT INTO @References VALUES ('Talha, Johann','http://stackoverflow.com/questions/10577676/how-to-obtain-failed-jobs-from-sql-server-agent-through-script','')
INSERT INTO @References VALUES ('Gregory Larsen','http://www.databasejournal.com/features/mssql/daily-dba-monitoring-tasks.html', '')
INSERT INTO @References VALUES ('Leonid Sheinkman','http://www.databasejournal.com/scripts/all-database-space-used-and-free.html', '')
INSERT INTO @References VALUES ('Unn Known','http://www.sqlserverspecialists.com/2012/10/script-to-monitor-sql-server-cpu-usage.html','')
INSERT INTO @References VALUES ('Uday Arumilli','http://udayarumilli.com/monitor-cpu-utilization-io-usage-and-memory-usage-in-sql-server/','')
INSERT INTO @References VALUES ('Peter Scharlock','https://blogs.msdn.microsoft.com/mssqlisv/2009/06/29/interesting-issue-with-filtered-indexes/','')
INSERT INTO @References VALUES ('Stijn, Sanath Kumar','http://stackoverflow.com/questions/9235527/incorrect-set-options-error-when-building-database-project','')
INSERT INTO @References VALUES ('Julian Kuiters','http://www.julian-kuiters.id.au/article.php/set-options-have-incorrect-settings','')
INSERT INTO @References VALUES ('Basit A Masood-Al-Farooq','https://basitaalishan.com/2014/01/22/get-sql-server-physical-cores-physical-and-virtual-cpus-and-processor-type-information-using-t-sql-script/','')
INSERT INTO @References VALUES ('Paul Randal','http://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/','')
INSERT INTO @References VALUES ('wikiHow','http://www.wikihow.com/Calculate-Confidence-Interval','')
INSERT INTO @References VALUES ('Periscope Data','https://www.periscopedata.com/blog/how-to-calculate-confidence-intervals-in-sql','')
INSERT INTO @References VALUES ('Jon M Crawford','https://www.sqlservercentral.com/Forums/Topic922290-338-1.aspx','')
INSERT INTO @References VALUES ('Robert L Davis','http://www.sqlsoldier.com/wp/sqlserver/breakingdowntempdbcontentionpart2','')
INSERT INTO @References VALUES ('Jonathan Kehayias','https://www.red-gate.com/simple-talk/sql/database-administration/great-sql-server-debates-lock-pages-in-memory/','For locked pages guidance')
INSERT INTO @REFERENCES VALUES ('Laerte Junior','https://www.red-gate.com/simple-talk/sql/database-administration/the-posh-dba-solutions-using-powershell-and-sql-server/','For doing PowerShell magic in SQL')
INSERT INTO @REFERENCES VALUES ('Robert Davis','http://www.sqlservercentral.com/blogs/robert_davis/2010/03/05/Breaking-Down-TempDB-Contention/','TempDB contention')

SET NOCOUNT ON
SET ANSI_WARNINGS ON
SET QUOTED_IDENTIFIER ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/* Before doing anything, you can rather run the current version of this script from the interwebs*/
use [Master]
DECLARE @RunBlitz BIT
SET @RunBlitz = 0
DECLARE @pstext VARCHAR(8000)
DECLARE @RunUpdatedVersion INT /*Valid values, 0, 1, 99*/
 /*Only modify this following line if you want recursive pain. ! it should read "SET @RunUpdatedVersion = ?" where ? is the option */
SET @RunUpdatedVersion = 1

IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND OBJECT_ID = OBJECT_ID('dbo.sqlsteward'))
    SET @RunUpdatedVersion = 1

IF @RunUpdatedVersion = 1
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

    -- Insert statements for procedure here
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

	EXEC dbo.sp_BlitzFirst 
		@ExpertMode = 1
		, @CheckProcedureCache = 1
		, @FileLatencyThresholdMS = 0
		, @Seconds = 30;

	EXEC [dbo].[sp_BlitzIndex] @Mode = 4, @SkipStatistics = 0, @GetAllDatabases = 1, @OutputServerName = 1, @OutputDatabaseName = 1;



/*Do Do follows*/
/* need some tools
	SET @pstext = '$thispath = pwd;Install-Module dbatools -Force' ; --
	SET @pstext = @pstext + 'Update-DbaTools;' ;
	SET @pstext = @pstext + 'Copy-DbaLogin -Source SUN -Destination MOON;' ;
	SET @pstext = @pstext + 'Copy-DbaCredential -Source SUN -Destination MOON;' ;
	SET @pstext = @pstext + 'Copy-DbaAgentProxyAccount -Source SUN -Destination MOON;' ;
	SET @pstext = @pstext + 'Copy-DbaAgentJob -Source SUN -Destination MOON;' ;
	SET @pstext = @pstext + 'Copy-DbaLinkedServer -Source SUN -Destination MOON ;' ;
	SET @pstext = @pstext + 'Copy-DbaSsisCatalog -Source SUN -Destination MOON ;' ;
*/
/*
USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'RunDiagnostics', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'RunDiagnostics', @server_name = N'LXLSQL01'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'RunDiagnostics', @step_name=N'Run sp_Blitz to table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dbo].[sp_Blitz] 
		@CheckUserDatabaseObjects = 1 
		, @CheckProcedureCache = 1 
		, @OutputType = ''TABLE'' 
		, @OutputProcedureCache = 1 
		, @CheckProcedureCacheFilter = NULL
		, @CheckServerInfo = 1
		, @OutputXMLasNVARCHAR = 1
		, @OutputDatabaseName = ''master''
		, @OutputSchemaName = ''dbo''
		, @OutputTableName = ''sp_Blitz_output''', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'RunDiagnostics', @step_name=N'Run sqlsteward to table', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC master.[dbo].[sqlsteward] 
		@TopQueries = 50
		, @FTECost  = 60000
		, @ShowQueryPlan = 1
		, @PrepForExport = 1
		, @Export = ''Table'' 
		, @ExportSchema   = ''dbo''
		, @ExportDBName = ''master''
		, @ExportTableName = ''sqlsteward_output''
		, @ExportCleanupDays  = 180
', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'RunDiagnostics', @step_name=N'End', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'PRINT ''End''', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'RunDiagnostics', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'', 
		@notify_netsend_operator_name=N'', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'RunDiagnostics', @name=N'LEXEL - Weekly Diagnostics', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20180404, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

*/

