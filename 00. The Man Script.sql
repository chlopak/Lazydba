/*PRINT NCHAR(65021), SQL server evaluation script*/

SET NOCOUNT ON
SET ANSI_WARNINGS ON
SET QUOTED_IDENTIFIER ON

IF OBJECT_ID('dbo.the_management_script') IS NULL
  EXEC ('CREATE PROCEDURE dbo.[the_management_script] AS RETURN 0;')
GO


ALTER PROCEDURE [dbo].[the_management_script]
    @TopQueries TINYINT = 50  /*How many queries need to be looked at, TOP xx*/
	, @FTECost MONEY = 60000/*Average price in $$$ that you pay someone at your company*/
	, @MinExecutionCount TINYINT = 1 /*This can go to 0 for more details, but first attend to often used queries. Run this with 0 before making any big decisions*/
	, @ShowQueryPlan TINYINT = 0 /*Set to 1 to include the Query plan in the output*/
	, @PrepForExport TINYINT = 0 /*When the intent of this script is to use this for some type of hocus-pocus magic metrics, set this to 1*/

/*WITH RECOMPILE - Some functionality is disabled when you recompile, especially the esitamated operator cost*/
AS
	/*PRINT NCHAR(65021), SQL server management script*/

	/* R U L E S
	1. Each declare on a new line
	2. Each column on a new line
	3. "," in from of new lines
	4. All (table columns) have ( and ) in new lines with tab indent
	5. All ends with ";"
	6. All comments in / * * / not --
	7. All descriptive comments above DECLAREs
		Comments can also be in SET @comment = ''
	8. All Switches are 0=off and 1=on and TINYINT type
	9. SELECT -option- <first column>
	, <column>
	FROM.. where more than 1 column is returned, or whatever reads better
	OPTION (RECOMPILE)

	Section:
	DECLARE section variables
	--------
	Do stuff
	*/
	PRINT NCHAR(65021)
	DECLARE @c_r AS CHAR(2) = CHAR(13) + CHAR(10)
	PRINT REPLACE(REPLACE(REPLACE(REPLACE(''+@c_r+'	[   ....,,:,,....[[ '+@c_r+'[   ,???????????????????:.[   '+@c_r+'[ .???????????????????????,[  '+@c_r+'s=.  ??????&&&$$??????. .7s '+@c_r+'s~$.. ...&&&&&... ..7Is '+@c_r+'s~&$+....[[.. =7777Is '+@c_r+'s~&&&&$$7I777Iv7777I[[  '+@c_r+'s~&&&&$$Ivv7777Is '+@c_r+'s~&$$... &$.. ..777?..vIs '+@c_r+'s~&$  &$$.  77?..77? .vIs '+@c_r+'s~&$. .&$  $I77=  7? .vIs '+@c_r+'s~&$$,. .$$ .$I777..7? .vIs '+@c_r+'s~&&$+ .$  ~I77. ,7? .vIs '+@c_r+'s~&$..   & ...  :77? ....77Is '+@c_r+'s~&&&&$$I:..vv7I[ '+@c_r+'s~&&&&$$Ivv7777Is '+@c_r+'s.&&&&$$Ivv7777.s '+@c_r+'s .&&&&$Ivv777.['+@c_r+'[ ..7&&&Ivv..[  '+@c_r+'[[........... ..[[ ', '&','$$$'),'v', '77777'),'[', '      '),'s','    ')
	PRINT REPLACE(REPLACE(REPLACE(REPLACE('.m__._. _.m__. __.__.. _.. _. _. m_..m_.m_. m.m_.m__ '+@c_r+' |_. _|g g| m_g.\/.i / \. | \ g / mi/ m|i_ \ |_ _|i_ \|_. _|'+@c_r+'. g.g_gi_i g\/g./ _ \.i\g \m \ g..g_) g g |_) g i'+@c_r+'. g.i_.|gm.g.g / m \ g\.im) |gm i_ <.g i__/.g.'+@c_r+'. |_i|_g_||m__g_i|_|/_/. \_\|_| \_gm_/.\m_||_| \_\|m||_i. |_i'+@c_r+'........................................... ','i','|.'),'.','  '),'m','___'),'g','| |')

	/* Reference sources
		sp_Blitz from http://FirstResponderKit.org
		The default server configuration values were take from sp_Blitz
		http://stackoverflow.com/questions/10577676/how-to-obtain-failed-jobs-from-sql-server-agent-through-script
		http://www.databasejournal.com/features/mssql/daily-dba-monitoring-tasks.html
		http://www.databasejournal.com/scripts/all-database-space-used-and-free.html
		http://www.sqlserverspecialists.com/2012/10/script-to-monitor-sql-server-cpu-usage.html
		http://udayarumilli.com/monitor-cpu-utilization-io-usage-and-memory-usage-in-sql-server/
	*/

	SET NOCOUNT ON;
	SET ANSI_WARNINGS ON;
	SET QUOTED_IDENTIFIER ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	/*@ShowWarnings = 0 > Only show warnings */
	DECLARE @ShowWarnings TINYINT 
	SET @ShowWarnings = 0;

	/*Script wide variables*/
	DECLARE @DaysUptime NUMERIC(23,2);
	DECLARE @dynamicSQL NVARCHAR(4000) ;
	SET @dynamicSQL = N'';
	DECLARE @MinWorkerTime BIGINT ;
	SET @MinWorkerTime = 0.01 * 1000000;
	DECLARE @LeftText INT ;
	SET @LeftText = 50; /*The lengh that you want to trim text*/
	DECLARE @oldestcachequery DATETIME ;
	DECLARE @lastservericerestart DATETIME;
	DECLARE @DaysOldestCachedQuery MONEY;
	DECLARE @CachevsUpdate MONEY;
	DECLARE @Databasei_Count INT;
	DECLARE @Databasei_Max INT;
	DECLARE @DatabaseName SYSNAME;
	DECLARE @DatabaseState TINYINT;
	DECLARE @RecoveryModel TINYINT;
	DECLARE @comment NVARCHAR(MAX);
	DECLARE @StartTest DATETIME 
	DECLARE @EndTest DATETIME; 
	DECLARE @ThisistoStandardisemyOperatorCostMate INT;
	DECLARE @secondsperoperator FLOAT;
	DECLARE @totalMemoryGB MONEY, @AvailableMemoryGB MONEY, @UsedMemory MONEY
	DECLARE @VMType VARCHAR(200), @ServerType VARCHAR(20)
	DECLARE @MaxRamServer INT,@SQLVersion tinyint
	DECLARE @ts BIGINT;
	DECLARE @Kb FLOAT;
	DECLARE @PageSize FLOAT;
	DECLARE @VLFcount INT;
	DECLARE @starttime DATETIME;
	SET @starttime = GETDATE()

	SELECT @SQLVersion = @@MicrosoftVersion / 0x01000000  OPTION (RECOMPILE)-- Get major version
	DECLARE @sqlrun NVARCHAR(4000), @rebuildonline VARCHAR(30), @isEnterprise INT, @i_Count INT, @i_Max INT;

	DECLARE @NeverUsedIndex TABLE(
		DB VARCHAR(250)
		,Consideration VARCHAR(50)
		,TableName VARCHAR(50)
		,TypeDesc VARCHAR(50)
		,IndexName VARCHAR(250)
		,Updates BIGINT
		,last_user_scan DATETIME
		,last_user_seek DATETIME
		,Pages BIGINT
	)

	DECLARE @FileSize TABLE
	(  
		DatabaseName sysname 
		, [FileName] VARCHAR(MAX) NULL
		, FileSize INT NULL
		, FileGroupName VARCHAR(MAX) NULL
		, LogicalName VARCHAR(MAX) NULL
		, maxsize MONEY NULL
		, growth MONEY NULL
	);
	DECLARE @FileStats TABLE 
	(  
		FileID INT
		, FileGroup INT  NULL
		, TotalExtents INT  NULL
		, UsedExtents INT  NULL
		, LogicalName VARCHAR(MAX)  NULL
		, FileName VARCHAR(MAX)  NULL
	);
	DECLARE @LogSpace TABLE 
	( 
		DatabaseName sysname NULL
		, LogSize FLOAT NULL
		, SpaceUsedPercent FLOAT NULL
		, Status bit NULL
	);
	IF OBJECT_ID('tempdb..#HeapTable') IS NOT NULL
				DROP TABLE #HeapTable;
			CREATE TABLE #HeapTable 
			( 
				DB VARCHAR(250)
				, [schema] VARCHAR(250)
				, [table] VARCHAR(250)
				, [rows] BIGINT
				, user_seeks BIGINT
				, user_scans BIGINT
				, user_lookups BIGINT
				, user_updates BIGINT
				, last_user_seek DATETIME
				, last_user_scan DATETIME
				, last_user_lookup DATETIME
			);

	IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL
				DROP TABLE #LogSpace;
			CREATE TABLE #LogSpace  
			( 
				DatabaseName sysname NULL
				, LogSize FLOAT NULL
				, SpaceUsedPercent FLOAT NULL
				, Status bit NULL
				, VLFCount INT NULL
			);
	IF OBJECT_ID('tempdb..#Action_Statistics') IS NOT NULL
				DROP TABLE #Action_Statistics;
			CREATE TABLE #Action_Statistics 
			(
				Id INT IDENTITY(1,1)
				, DBname VARCHAR(100)
				, TableName VARCHAR(100)
				, StatsID TINYINT
				, StatisticsName VARCHAR(500)
				, SchemaName VARCHAR(100)
				, ModificationCount BIGINT
				, LastUpdated DATETIME
			);
	IF OBJECT_ID('tempdb..#MissingIndex') IS NOT NULL
				DROP TABLE #MissingIndex;
			CREATE TABLE #MissingIndex 
			(
				DB VARCHAR(250)
				, magic_benefit_number NUMERIC(29,4)
				, [Table] VARCHAR(2000)
				, ChangeIndexStatement VARCHAR(4000)
				, equality_columns VARCHAR(4000)
				, inequality_columns VARCHAR(4000)
				, included_columns VARCHAR(4000)
			);

	IF OBJECT_ID('tempdb..#output_man_script') IS NOT NULL
				DROP TABLE #output_man_script;
			CREATE TABLE #output_man_script 
			(
				evaldate DATETIME DEFAULT GETDATE()
				, domain VARCHAR(50) DEFAULT DEFAULT_DOMAIN()
				, SQLInstance VARCHAR(50) DEFAULT @@SERVERNAME
				, SectionID TINYINT NULL
				, Section VARCHAR(MAX)
				, Summary VARCHAR(MAX)
				, Details VARCHAR(MAX)
				, QueryPlan XML NULL
				, ID INT IDENTITY(1,1)
			)
	IF OBJECT_ID('tempdb..#ConfigurationDefaults') IS NOT NULL
				DROP TABLE #ConfigurationDefaults;
			CREATE TABLE #ConfigurationDefaults
				(
				  name NVARCHAR(128) ,
				  DefaultValue BIGINT,
				  CheckID INT
				);
	IF OBJECT_ID('tempdb..#db_sps') IS NOT NULL
				DROP TABLE #db_sps;
	CREATE TABLE #db_sps 
				(
					[dbname] VARCHAR(500)
					, [SP Name] NVARCHAR(4000)
					, [TotalLogicalWrites] BIGINT
					, [AvgLogicalWrites] BIGINT
					, execution_count BIGINT
					, [Calls/Second] INT
					, [total_elapsed_time] BIGINT
					, [avg_elapsed_time] BIGINT
					, cached_time DATETIME
				);
	IF OBJECT_ID('tempdb..#querystats') IS NOT NULL
				DROP TABLE #querystats
	CREATE TABLE #querystats
				(
					 Id INT IDENTITY(1,1)
					, [execution_count] [bigint] NOT NULL
					, [total_logical_reads] [bigint] NOT NULL
					, [Total_MBsRead] [money] NULL
					, [total_logical_writes] [bigint] NOT NULL
					, [Total_MBsWrite] [money] NULL
					, [total_worker_time] [bigint] NOT NULL
					, [total_elapsed_time_in_S] [money] NULL
					, [total_elapsed_time] [money] NULL
					, [last_execution_time] [datetime] NOT NULL
					, [plan_handle] [varbinary](64) NOT NULL
					, [sql_handle] [varbinary](64) NOT NULL
				);

	IF OBJECT_ID('tempdb..#notrust') IS NOT NULL
				DROP TABLE #notrust
	CREATE TABLE #notrust
				(
				KeyType VARCHAR(20)
				, Tablename VARCHAR(500)
				, KeyName VARCHAR(500)
				, DBCCcommand VARCHAR(2000)
				, Fix VARCHAR(2000)
				)
		

	IF OBJECT_ID('tempdb..#dbccloginfo') IS NOT NULL
				DROP TABLE #dbccloginfo
	CREATE TABLE #dbccloginfo  
			(id INT IDENTITY(1,1) 
			)

	IF CONVERT(TINYINT,@SQLVersion) >= 11 -- post-SQL2012 
	BEGIN
		SET @dynamicSQL =  'Alter table #dbccloginfo Add [RecoveryUnitId] int'
		EXEC sp_executesql @dynamicSQL;
		PRINT @dynamicSQL
	END

	Alter table #dbccloginfo Add fileid smallint 
	Alter table #dbccloginfo Add file_size BIGINT
	Alter table #dbccloginfo Add start_offset BIGINT  
	Alter table #dbccloginfo Add fseqno int
	Alter table #dbccloginfo Add [status] tinyint
	Alter table #dbccloginfo Add parity tinyint
	Alter table #dbccloginfo Add create_lsn numeric(25,0)  


	DECLARE
	@value VARCHAR(64),
	@key VARCHAR(512) = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\'
	+ 'ControlPanel\NameSpace\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}';

	EXEC master..xp_regread 
	@rootkey = 'HKEY_LOCAL_MACHINE',
	@key = @key,
	@value_name = 'PreferredPlan',
	@value = @value OUTPUT;

	IF @value = '381b4222-f694-41f0-9685-ff5bb260df2e' 
	PRINT 'High-Performance Enabled'
	IF @value <> '381b4222-f694-41f0-9685-ff5bb260df2e' 
	PRINT 'Check Power Options' 
	RAISERROR (N'Power Options checked',0,1) WITH NOWAIT;


	SET @rebuildonline = 'OFF';				/* Assume this is not Enterprise, we will test in the next line and if it is , woohoo. */
	SELECT @isEnterprise = PATINDEX('%enterprise%',@@Version) OPTION (RECOMPILE);
	IF (@isEnterprise > 0) 
	BEGIN 
		SET @rebuildonline = 'ON'; /*Can also use CAST(SERVERPROPERTY('EngineEdition') AS INT), thanks http://www.brentozar.com/ */
	END

	INSERT #output_man_script (SectionId,Section,Summary, Details) SELECT 0,'@' + CONVERT(VARCHAR,GETDATE(),120),'------','------'
	INSERT #output_man_script (SectionId,Section,Summary)
	VALUES (0, 'Domain',DEFAULT_DOMAIN())
	,(0, 'Server',@@SERVERNAME)
	,(0, 'User',CURRENT_USER )
	,(0, 'Logged in',SYSTEM_USER)

			/*----------------------------------------
			--Before anything else, look for things that might point to breaking behaviour. Look for out of support SQL bits floating around
			--WORKAROUND - create all indexes using the deafult SET settings of the applications connecting into the server
			--F-U-C-K DANGER WILL ROBINSON
			/*
			https://blogs.msdn.microsoft.com/mssqlisv/2009/06/29/interesting-issue-with-filtered-indexes/
			http://stackoverflow.com/questions/9235527/incorrect-set-options-error-when-building-database-project
			http://www.julian-kuiters.id.au/article.php/set-options-have-incorrect-settings
			*/
			----------------------------------------*/

	IF EXISTS(SELECT 1 FROM sys.dm_exec_sessions T 
	WHERE ((
	quoted_identifier = 0 
	OR ansi_nulls = 0
	OR ansi_padding= 0
	OR ansi_warnings= 0
	OR arithabort= 0
	OR concat_null_yields_null= 0
	) AND LEN(T.nt_user_name) > 1 AND T.program_name NOT LIKE 'SQLAgent - %' ) OR T.client_version < 6)
	BEGIN

		INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 1,'!!! WARNING - UNSUPPORTED SQL !!!','------','------'
		INSERT #output_man_script (SectionId, Section,Summary, Details  )
		SELECT DISTINCT 1, '!!! WARNING !!!' 
		+CASE 
		WHEN T.client_version = 4 THEN 'SQL 2000'
		WHEN T.client_version = 5 THEN 'SQL 2005'
		WHEN T.client_version = 6 THEN 'SQL 2008'
		WHEN T.client_version = 7 THEN 'SQL 2012'
		ELSE 'SQL 2014+'
		END [Section]
		, T.program_name
		+ '; DB: ' +DB_NAME(T.database_id) 
		+ '; Interface: '+ T.client_interface_name
		+ '; User: ' + T.nt_user_name
		+ '; Host: ' + T.host_name [Summary]
		, '' + CASE WHEN quoted_identifier = 0 THEN ';quoted_identifier: OFF' ELSE '' END
		+ ''+  CASE WHEN ansi_nulls = 0 THEN ';ansi_null: OFF' ELSE '' END
		+ ''+  CASE WHEN ansi_padding = 0 THEN ';ansi_padding: OFF' ELSE '' END
		+ ''+  CASE WHEN ansi_warnings = 0 THEN ';ansi_warnings: OFF' ELSE '' END
		+ ''+  CASE WHEN arithabort = 0 THEN ';arithabort: OFF' ELSE '' END
		+ ''+  CASE WHEN concat_null_yields_null = 0 THEN ';concat_null_yields_null: OFF' ELSE '' END
		FROM sys.dm_exec_sessions T
		WHERE ((
	quoted_identifier = 0 
	OR ansi_nulls = 0
	OR ansi_padding= 0
	OR ansi_warnings= 0
	OR arithabort= 0
	OR concat_null_yields_null= 0
	)
		AND LEN(T.nt_user_name) > 1
		AND T.program_name NOT LIKE 'SQLAgent - %' )
		OR T.client_version < 6
		ORDER BY Section, [Summary]
		PRINT N'WARNING! UNSUPPORTED! Your have SET options that might break stuff on SQL 2005+. You just got 99 problems son.';
		PRINT N'DANGER WILL ROBINSON';
		INSERT #output_man_script (SectionID, Section,Summary, Details) SELECT 1,'!!! WARNING - CHECK YOU SETs !!!','------','------'
	END
	RAISERROR (N'Done checking for possible breaking SQL 2000 things',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Before anything else, look for things that might point to breaking behaviour. Like databse with bad default settings
			----------------------------------------*/

	IF EXISTS(SELECT 1
		FROM sys.databases
		WHERE is_ansi_nulls_on = 0
		OR is_ansi_padding_on= 0
		OR is_ansi_warnings_on= 0
		OR is_arithabort_on= 0
		OR is_concat_null_yields_null_on= 0
		OR is_numeric_roundabort_on= 0
		OR is_quoted_identifier_on= 1)
	BEGIN

		INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 1,'!!! WARNING - POTENTIALLY BREAKING DEFAULT DB SETTINGS!!!','------','------'
		INSERT #output_man_script (SectionId, Section,Summary)
		SELECT 1, name
		, ''+  CASE WHEN is_quoted_identifier_on = 0 THEN '; quoted_identifier: OFF' ELSE '' END
		+ ''+  CASE WHEN is_ansi_nulls_on = 0 THEN '; ansi_null: OFF' ELSE '' END
		+ ''+  CASE WHEN is_ansi_padding_on = 0 THEN '; ansi_padding : OFF' ELSE '' END
		+ ''+  CASE WHEN is_ansi_warnings_on = 0 THEN '; ansi_warnings : OFF' ELSE '' END
		+ ''+  CASE WHEN is_arithabort_on = 0 THEN '; arithabort : OFF' ELSE '' END
		+ ''+  CASE WHEN is_concat_null_yields_null_on = 0 THEN '; concat_null_yields_null: OFF' ELSE '' END
		+ ''+  CASE WHEN is_numeric_roundabort_on = 1 THEN '; is_numeric_roundabort_on: ON' ELSE '' END
	FROM sys.databases
	WHERE is_ansi_nulls_on = 0
	OR is_ansi_padding_on= 0
	OR is_ansi_warnings_on= 0
	OR is_arithabort_on= 0
	OR is_concat_null_yields_null_on= 0
	OR is_numeric_roundabort_on= 1
	OR is_quoted_identifier_on= 0
	
	END

	RAISERROR (N'Done checking for possible breaking SQL 2000 things',0,1) WITH NOWAIT;
			/*----------------------------------------
			--Benchmark, not for anything else besides getting a number
			----------------------------------------*/


	SET @StartTest = GETDATE();
	
	WITH  E00(N)	AS (SELECT 1 UNION ALL SELECT 1)
		, E02(N)	AS (SELECT 1 FROM E00 a, E00 b)
		, E04(N)	AS (SELECT 1 FROM E02 a, E02 b)
		, E08(N)	AS (SELECT 1 FROM E04 a, E04 b)
		, E16(N)	AS (SELECT 1 FROM E08 a, E08 b)
		, cteTally(N) AS (SELECT ROW_NUMBER() OVER (ORDER BY N) FROM E16)
	SELECT 
		@ThisistoStandardisemyOperatorCostMate = count(N) 
	FROM cteTally OPTION (RECOMPILE);
	SET @EndTest = GETDATE();
	SELECT TOP 1  
		@secondsperoperator = (qs.total_worker_time/qs.execution_count/1000)/0.7248/1000  
	FROM sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
	WHERE qs.total_logical_reads = 0 
	AND qs.last_execution_time BETWEEN @StartTest AND @EndTest
	AND PATINDEX('%ThisistoStandardisemyOperatorCostMate%',CAST(qt.TEXT AS VARCHAR(MAX))) > 0
	--OPTION (RECOMPILE);
	PRINT N'Your cost (in seconds) per operator roughly equates to around '+ CONVERT(VARCHAR,ISNULL(@secondsperoperator,0)) + ' seconds' ;
	RAISERROR (N'Benchmarking done',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Build database table to use throughout this script
			----------------------------------------*/

	DECLARE @Databases TABLE
	(
		id INT IDENTITY(1,1)
		, databasename VARCHAR(250)
		, [compatibility_level] BIGINT
		, user_access BIGINT
		, user_access_desc VARCHAR(50)
		, [state] BIGINT
		, state_desc  VARCHAR(50)
		, recovery_model BIGINT
		, recovery_model_desc  VARCHAR(50)
		, create_date DATETIME
	);
	SET @dynamicSQL = 'SELECT 
	db.name
	, db.compatibility_level
	, db.user_access
	, db.user_access_desc
	, db.state
	, db.state_desc
	, db.recovery_model
	, db.recovery_model_desc
	, db.create_date
	FROM sys.databases db ';
	IF 'Yes please dont do the system databases' IS NOT NULL
	BEGIN
		SET @dynamicSQL = @dynamicSQL + ' WHERE database_id > 4 AND state NOT IN (2,3,6)';
	END
	SET @dynamicSQL = @dynamicSQL + ' OPTION (RECOMPILE)'
	INSERT INTO @Databases 

	EXEC sp_executesql @dynamicSQL ;
	SET @Databasei_Max = (SELECT MAX(id) FROM @Databases );

			/*----------------------------------------
			--Get uptime and cache age
			----------------------------------------*/

	SET @oldestcachequery = (SELECT  MIN(creation_time) FROM sys.dm_exec_query_stats WITH (NOLOCK));
	SET @lastservericerestart = (SELECT create_date FROM sys.databases WHERE name = 'tempdb');

	SELECT @DaysUptime = CAST(DATEDIFF(hh,@lastservericerestart,GETDATE())/24. AS NUMERIC (23,2)) OPTION (RECOMPILE);
	SELECT @DaysOldestCachedQuery = CAST(DATEDIFF(hh,@oldestcachequery,GETDATE())/24. AS NUMERIC (23,2)) OPTION (RECOMPILE);

	IF @DaysUptime = 0 
		SET @DaysUptime = .1;
	IF @DaysOldestCachedQuery = 0 
		SET @DaysOldestCachedQuery = .1;

	SET @CachevsUpdate = @DaysOldestCachedQuery*100/@DaysUptime
	IF @CachevsUpdate < 1
		SET @CachevsUpdate = 1
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 2,'CACHE - Cache Age As portion of Overall Uptime','------','------'
	INSERT #output_man_script (SectionId, Section,Summary )
	SELECT 2,'['+REPLICATE('|', @CachevsUpdate) + REPLICATE('''',100-@CachevsUpdate ) +']'
	, 'Uptime:'
	+ CONVERT(VARCHAR,@DaysUptime)
	+ '; Oldest Cache:'
	+ CONVERT(VARCHAR,@DaysOldestCachedQuery )
	+ '; Cache Timestamp:'
	+ CONVERT(VARCHAR,@oldestcachequery,120)



	RAISERROR (N'Server uptime and cache age established',0,1) WITH NOWAIT;



	   /*----------------------------------------
			--Internals and Memory usage
			----------------------------------------*/
	SELECT @UsedMemory = CONVERT(MONEY,physical_memory_in_use_kb)/1024 /1000
	FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE)
	SELECT @totalMemoryGB = CONVERT(MONEY,total_physical_memory_kb)/1024/1000
	, @AvailableMemoryGB =  CONVERT(MONEY,available_physical_memory_kb)/1024/1000 
	FROM sys.dm_os_sys_memory WITH (NOLOCK) OPTION (RECOMPILE);
	SELECT @VMType = RIGHT(@@version,CHARINDEX('(',REVERSE(@@version)))


	/*https://basitaalishan.com/2014/01/22/get-sql-server-physical-cores-physical-and-virtual-cpus-and-processor-type-information-using-t-sql-script/ */

	IF @SQLVersion = 11
	BEGIN
		EXEC sp_executesql N'set @_MaxRamServer= (select physical_memory_kb/1024 from sys.dm_os_sys_info);', N'@_MaxRamServer INT OUTPUT', @_MaxRamServer = @MaxRamServer OUTPUT
	END
	ELSE
	IF @SQLVersion in (10,9)
	BEGIN
		EXEC sp_executesql N'set @_MaxRamServer= (select physical_memory_in_bytes/1024/1024 from sys.dm_os_sys_info) ;', N'@_MaxRamServer INT OUTPUT', @_MaxRamServer = @MaxRamServer OUTPUT
	END

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 3,'MEMORY - SQL Memory usage of total allocated','------','------'
	INSERT #output_man_script (SectionId, Section,Summary ,Details )

 
	SELECT 3,'['+REPLICATE('|', CONVERT(MONEY,CONVERT(FLOAT,@UsedMemory)/CONVERT(FLOAT,@AvailableMemoryGB)) * 100) + REPLICATE('''',100-(CONVERT(MONEY,CONVERT(FLOAT,@UsedMemory)/CONVERT(FLOAT,@AvailableMemoryGB)) * 100) ) +']' 
	, 'Physical Cores:' + CONVERT(VARCHAR,([cpu_count] / [hyperthread_ratio]) )
	+'; Virtual CPUs:' + CONVERT(VARCHAR,[cpu_count]  )
	+'; VM Type:' + @VMType
	+'; CPU Affinity:'+ [affinity_type_desc] 
	+'; MemoryGB:' + CONVERT(VARCHAR, CONVERT(MONEY,CONVERT(FLOAT,@totalMemoryGB)))
	+'; SQL Allocated:' +CONVERT(VARCHAR, CONVERT(MONEY,CONVERT(FLOAT,@UsedMemory))) 
	+'; Suggested MAX:' + CONVERT(VARCHAR, CASE 
	 WHEN @MaxRamServer < = 1024*2 THEN @MaxRamServer - 512  /*When the RAM is Less than or equal to 2GB*/
	 WHEN @MaxRamServer < = 1024*4 THEN @MaxRamServer - 1024 /*When the RAM is Less than or equal to 4GB*/
	 WHEN @MaxRamServer < = 1024*16 THEN @MaxRamServer - 1024 - Ceiling((@MaxRamServer-4096) / (4.0*1024))*1024 /*When the RAM is Less than or equal to 16GB*/

		-- My machines memory calculation
		-- RAM= 16GB
		-- Case 3 as above:- 16384 RAM-> MaxMem= 16384-1024-[(16384-4096)/4096] *1024
		-- MaxMem= 12106

		WHEN @MaxRamServer > 1024*16 THEN @MaxRamServer - 4096 - Ceiling((@MaxRamServer-1024*16) / (8.0*1024))*1024 /*When the RAM is Greater than or equal to 16GB*/
		END) 
	+'; Used by SQL:'+ CONVERT(VARCHAR, CONVERT(FLOAT,@UsedMemory))
	+'; Memory State:' + ISNULL((SELECT system_memory_state_desc from  sys.dm_os_sys_memory),'')  [Internals: Details] 
	, ('ServerName:'+ replace(replace(replace(replace(CONVERT(NVARCHAR,SERVERPROPERTY('ServerName')), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' ') 
		+'; Version:'+ LEFT( @@version, PATINDEX('%-%',( @@version))-2) 
		+'; VersionNr:'+ replace(replace(replace(replace(CONVERT(NVARCHAR,SERVERPROPERTY('ProductVersion')), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' ') 
		+'; OS:'+ RIGHT( @@version, LEN(@@version) - PATINDEX('% on %',( @@version))-3) 
		+'; Edition:'+ replace(replace(replace(replace(CONVERT(NVARCHAR,SERVERPROPERTY('Edition')), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' ') 
		+'; HADR:'+ replace(replace(replace(replace(CONVERT(NVARCHAR,SERVERPROPERTY('IsHadrEnabled')), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' ') 
		+'; SA:'+ replace(replace(replace(replace(CONVERT(NVARCHAR,SERVERPROPERTY('IsIntegratedSecurityOnly' )), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' ')
		+'; Licenses:'+ ISNULL(replace(replace(replace(replace(CONVERT(NVARCHAR,SERVERPROPERTY('NumLicenses' )), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' ') ,'')
		+'; Level:'+ replace(replace(replace(replace(CONVERT(NVARCHAR,SERVERPROPERTY('ProductLevel')), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' '))  [More Details] 
		FROM [sys].[dm_os_sys_info] OPTION (RECOMPILE);

			/*----------------------------------------
			--Get some CPU history
			----------------------------------------*/

	SELECT @ts =(
	SELECT cpu_ticks/(cpu_ticks/ms_ticks)
	FROM sys.dm_os_sys_info 
	) OPTION (RECOMPILE)

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 4,'CPU - Average CPU usage of SQL process as % of total CPU usage','------','------'
	INSERT #output_man_script (SectionId, Section,Summary  )
	SELECT 4, '['+REPLICATE('|', AVG(CONVERT(MONEY,SQLProcessUtilization))) + REPLICATE('''',100-(AVG(CONVERT(MONEY,SQLProcessUtilization)) )) +']'
	,('Avg CPU:'+ CONVERT(VARCHAR,AVG(SQLProcessUtilization))
	+'%; CPU Idle:' + CONVERT(VARCHAR,AVG(SystemIdle))
	+ '%; Other:'+ CONVERT(VARCHAR, 100 - AVG(SQLProcessUtilization) - AVG(SystemIdle))
	+'%; From:'+ CONVERT(VARCHAR, MIN([Event_Time]),120)
	+'; To:' + CONVERT(VARCHAR, MAX([Event_Time]),120)) 
	FROM 
	(
		SELECT SQLProcessUtilization
		, SystemIdle
		, DATEADD(ms,-1 *(@ts - [timestamp])
		, GETDATE())AS [Event_Time]
		FROM 
		(
			SELECT 
			record.value('(./Record/@id)[1]','int') AS record_id
			, record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int') AS [SystemIdle]
			, record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]','int') AS [SQLProcessUtilization]
			, [timestamp]
			FROM 
			(
				SELECT
				[timestamp]
				, convert(xml, record) AS [record] 
				FROM sys.dm_os_ring_buffers 
				WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
				AND record LIKE'%%'
			)AS x
		) as y
	) T1
	HAVING AVG(T1.SQLProcessUtilization) >= (CASE WHEN @ShowWarnings = 1 THEN 20 ELSE 0 END)
	OPTION (RECOMPILE)

	RAISERROR (N'Checked CPU usage for the last 5 minutes',0,1) WITH NOWAIT;


			/*----------------------------------------
			--Failed logins on the server
			----------------------------------------*/

	DECLARE @LoginLog TABLE( LogDate DATETIME, ProcessInfo VARCHAR(200), [Text] VARCHAR(MAX))
	IF  @ShowWarnings = 0 
	BEGIN
		SET @dynamicSQL = 'EXEC sp_readerrorlog 0, 1, ''Login failed'' '
		INSERT @LoginLog
		EXEC sp_executesql @dynamicSQL
		IF EXISTS (SELECT 1 FROM @LoginLog)
		BEGIN
			INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 5, 'LOGINS - Failed Logins','------','------'
			INSERT #output_man_script (SectionId, Section,Summary  )
			SELECT TOP 15 5, 'Date:'
			+ CONVERT(VARCHAR,LogDate,120)
			,
			+ Text 
			FROM @LoginLog ORDER BY LogDate DESC
			OPTION (RECOMPILE)
		END
	END
	RAISERROR (N'Server logins have been checked from the log',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Agent log for errors
			----------------------------------------*/

	DECLARE @Errorlog TABLE( LogDate DATETIME, ErrorLevel INT, [Text] VARCHAR(4000))
	/*Ignore the agent logs if you cannot find it, else errors will come*/
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM master.dbo.sysprocesses WHERE LEFT(program_name, 8) = 'SQLAgent')
		BEGIN   
			SET @dynamicSQL = 'EXEC sp_readerrorlog 1, 2, ''Error:'' '
			INSERT @Errorlog
			EXEC sp_executesql @dynamicSQL
		END  
		BEGIN   
			SET @dynamicSQL = 'EXEC sp_readerrorlog 1, 1, ''Error:'' '
			INSERT @Errorlog
			EXEC sp_executesql @dynamicSQL
		END
		IF EXISTS (SELECT * FROM @Errorlog)
		BEGIN
			INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 6,'AGENT LOG Errors','------','------'
			INSERT #output_man_script (SectionId, Section,Summary, Details  )
			SELECT 6, 'Date:'+ CONVERT(VARCHAR,LogDate ,120)
			, 'ErrorLevel:'+ CONVERT(VARCHAR,ErrorLevel)
			,[Text]  FROM @Errorlog ORDER BY LogDate DESC
			OPTION (RECOMPILE)
		END  
	END TRY
	BEGIN CATCH
		RAISERROR (N'Error reading agent log',0,1) WITH NOWAIT;
	END CATCH
	RAISERROR (N'Agent log parsed for errors',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Look for failed agent jobs
			----------------------------------------*/
	IF EXISTS (
	SELECT *  
	FROM msdb.dbo.sysjobhistory DBSysJobHistory
		JOIN (
			SELECT DBSysJobHistory.job_id
				, DBSysJobHistory.step_id
				, MAX(DBSysJobHistory.instance_id) as instance_id
			FROM msdb.dbo.sysjobhistory DBSysJobHistory
			GROUP BY DBSysJobHistory.job_id
				, DBSysJobHistory.step_id
		) AS Instance ON DBSysJobHistory.instance_id = Instance.instance_id
	WHERE DBSysJobHistory.run_status <> 1
	)
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 7, 'FAILED AGENT JOBS','------','------'
	INSERT #output_man_script (SectionId, Section,Summary, Details  )
	SELECT  7,'Job Name:' + SysJobs.name
		+'; Step:'+ SysJobSteps.step_name 
		+ ' - '+ Job.run_status
		, 'MessageId: ' +CONVERT(VARCHAR,Job.sql_message_id)
		+ '; Severity:'+ CONVERT(VARCHAR,Job.sql_severity)
		, 'Message:'+ Job.message
		+'; Date:' + CONVERT(VARCHAR, Job.exec_date,120)
		/*, Job.run_duration
		, Job.server
		, SysJobSteps.output_file_name
		*/
	FROM
	(
		SELECT Instance.instance_id
			,DBSysJobHistory.job_id
			,DBSysJobHistory.step_id
			,DBSysJobHistory.sql_message_id
			,DBSysJobHistory.sql_severity
			,DBSysJobHistory.message
			,(CASE DBSysJobHistory.run_status 
				WHEN 0 THEN 'Failed' 
				WHEN 1 THEN 'Succeeded' 
				WHEN 2 THEN 'Retry' 
				WHEN 3 THEN 'Canceled' 
				WHEN 4 THEN 'In progress'
			  END
			) as run_status
			,((SUBSTRING(CAST(DBSysJobHistory.run_date AS VARCHAR(8)), 5, 2) + '/'
			  + SUBSTRING(CAST(DBSysJobHistory.run_date AS VARCHAR(8)), 7, 2) + '/'
			  + SUBSTRING(CAST(DBSysJobHistory.run_date AS VARCHAR(8)), 1, 4) + ' '
			  + SUBSTRING((REPLICATE('0',6-LEN(CAST(DBSysJobHistory.run_time AS VARCHAR)))
			  + CAST(DBSysJobHistory.run_time AS VARCHAR)), 1, 2) + ':'
			  + SUBSTRING((REPLICATE('0',6-LEN(CAST(DBSysJobHistory.run_time AS VARCHAR)))
			  + CAST(DBSysJobHistory.run_time AS VARCHAR)), 3, 2) + ':'
			  + SUBSTRING((REPLICATE('0',6-LEN(CAST(DBSysJobHistory.run_time as VARCHAR)))
			  + CAST(DBSysJobHistory.run_time AS VARCHAR)), 5, 2))) [exec_date]
			,DBSysJobHistory.run_duration
			,DBSysJobHistory.retries_attempted
			,DBSysJobHistory.server
		FROM msdb.dbo.sysjobhistory DBSysJobHistory
		JOIN (
			SELECT DBSysJobHistory.job_id
				, DBSysJobHistory.step_id
				, MAX(DBSysJobHistory.instance_id) as instance_id
			FROM msdb.dbo.sysjobhistory DBSysJobHistory
			GROUP BY DBSysJobHistory.job_id
				, DBSysJobHistory.step_id
		) AS Instance ON DBSysJobHistory.instance_id = Instance.instance_id
		WHERE DBSysJobHistory.run_status <> 1
	) AS Job
	JOIN msdb.dbo.sysjobs SysJobs
		   ON (Job.job_id = SysJobs.job_id)
	JOIN msdb.dbo.sysjobsteps SysJobSteps
		   ON (Job.job_id = SysJobSteps.job_id 
		   AND Job.step_id = SysJobSteps.step_id)
	OPTION (RECOMPILE);
	RAISERROR (N'Checked for failed agent jobs',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Look for failed backups
			----------------------------------------*/
	IF EXISTS
	(
		SELECT *
		FROM (
			SELECT *
			FROM msdb.dbo.backupset x  
			WHERE backup_finish_date = (
				SELECT max(backup_finish_date) 
				FROM msdb.dbo.backupset 
				WHERE database_name =   x.database_name 
			)    
		) a  
		RIGHT OUTER JOIN sys.databases b  ON a.database_name =   b.name  
		WHERE b.name <> 'tempdb' /*Exclude tempdb*/
		AND (backup_finish_date < DATEADD(d,-1,GETDATE())  
		OR backup_finish_date IS NULL) 
	)
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 8,'DATABASE - No recent Backups','------','------'
	INSERT #output_man_script (SectionId, Section,Summary  )

	SELECT 8, name [Section] , ('; Backup Finish Date:' + ISNULL(CONVERT(VARCHAR,backup_finish_date,120),'')
		+ '; Type:' +coalesce(type,'NO BACKUP')) [Summary]
	FROM (
		SELECT database_name
			, backup_finish_date
			, CASE WHEN  type = 'D' THEN 'Full'    
			  WHEN  type = 'I' THEN 'Differential'                
			  WHEN  type = 'L' THEN 'Transaction Log'                
			  WHEN  type = 'F' THEN 'File'                
			  WHEN  type = 'G' THEN 'Differential File'                
			  WHEN  type = 'P' THEN 'Partial'                
			  WHEN  type = 'Q' THEN 'Differential partial'   
			  END AS type 
		FROM msdb.dbo.backupset x  
		WHERE backup_finish_date = (
			SELECT max(backup_finish_date) 
			FROM msdb.dbo.backupset 
			WHERE database_name =   x.database_name 
		)    
	) a  
	RIGHT OUTER JOIN sys.databases b  ON a.database_name =   b.name  
	WHERE b.name <> 'tempdb' /*Exclude tempdb*/
	AND (backup_finish_date < DATEADD(d,-1,GETDATE())  
	OR backup_finish_date IS NULL)
	OPTION (RECOMPILE);
	RAISERROR (N'Checked for failed backups',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Look for backups and recovery model information
			----------------------------------------*/
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 9, 'DATABASE - RPO in minutes and RTO in 15 min slices','------','------'
	INSERT #output_man_script (SectionId, Section,Summary  )
	SELECT 9,  REPLICATE('|',DATEDIFF(MINUTE,CASE 
	WHEN recovery_model = 'FULL' AND x.[Last Transaction Log] > x.[Last Full] THEN x.[Last Transaction Log]
	WHEN recovery_model = 'FULL' AND x.[Last Transaction Log] <= x.[Last Full] THEN [Last Full]
	ELSE x.[Last Full] END, GETDATE())/15) +' ' + 
	CONVERT(VARCHAR,DATEDIFF(MINUTE,CASE 
	WHEN recovery_model = 'FULL' AND x.[Last Transaction Log] > x.[Last Full] THEN x.[Last Transaction Log]
	WHEN recovery_model = 'FULL' AND x.[Last Transaction Log] <= x.[Last Full] THEN [Last Full]
	ELSE x.[Last Full] END, GETDATE())) + ' minutes'
	, ('DB:'
	+ database_name
	+ ' - '
	+ recovery_model
	+ ';Last Full:'
	+ CONVERT(VARCHAR,x.[Last Full],120)
	+ '; Last TL:'
	+ CONVERT(VARCHAR,x.[Last Transaction Log],120)
	+';Best RTO:'
	+ LEFT(CONVERT(VARCHAR,DATEADD(SECOND,x.Timetaken,0) ,114),8)
	)
	FROM 
	(
		SELECT  database_name, recovery_model
		, MAX(DATEDIFF(SECOND,backup_start_date, backup_finish_date)) 'Timetaken'
		, MAX(CASE WHEN  type = 'D' THEN backup_finish_date ELSE 0 END) 'Last Full'   
		, MIN(CASE WHEN  type = 'D' THEN backup_start_date ELSE 0 END) 'First Full'             
		, MAX(CASE WHEN  type = 'L' THEN backup_finish_date ELSE 0 END) 'Last Transaction Log'  
		, MIN(CASE WHEN  type = 'L' THEN backup_start_date ELSE 0 END) 'First Transaction Log'  
		FROM msdb.dbo.backupset
		WHERE type IN ('D', 'L')
		AND database_name NOT IN ('model','master','msdb')
		GROUP BY database_name, recovery_model
	) x 
	ORDER BY [Last Full] ASC
	OPTION (RECOMPILE);
	RAISERROR (N'Recovery Model information matched with backups',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Check for disk space and latency on the server
			----------------------------------------*/

	DECLARE @fixeddrives TABLE(drive VARCHAR(5), FreeSpaceMB MONEY)
	INSERT @fixeddrives
	EXEC MASTER..xp_fixeddrives 

	/* more useful info
	SELECT * FROM sys.dm_os_sys_info 
	EXEC xp_msver
	*/
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 10, 'Disk Latency and Space','------','------'
	INSERT #output_man_script (SectionId, Section,Summary  )

	SELECT 10, UPPER([Drive]) + '\ ' + REPLICATE('|',CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE (io_stall/(num_of_reads + num_of_writes)) END) +' '+ CONVERT(VARCHAR, CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE (io_stall/(num_of_reads + num_of_writes)) END) + ' ms' 
	, 'FreeSpace:'+ CONVERT(VARCHAR,[AvailableGBs]) + 'GB'
	+ '; Read:' + CONVERT(VARCHAR,CASE WHEN num_of_reads = 0 THEN 0 ELSE (io_stall_read_ms/num_of_reads) END )
	+ '; Write:' + CONVERT(VARCHAR, CASE WHEN io_stall_write_ms = 0 THEN 0 ELSE (io_stall_write_ms/num_of_writes) END )
	+ '; Total:' + CONVERT(VARCHAR, CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE (io_stall/(num_of_reads + num_of_writes)) END) 
	+ ' (Latency in ms)'
	/*
	, CASE WHEN num_of_reads = 0 THEN 0 ELSE (num_of_bytes_read/num_of_reads) END AS [Avg Bytes/Read]
	, CASE WHEN io_stall_write_ms = 0 THEN 0 ELSE (num_of_bytes_written/num_of_writes) END AS [Avg Bytes/Write]
	, CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE ((num_of_bytes_read + num_of_bytes_written)/(num_of_reads + num_of_writes)) END AS [Avg Bytes/Transfer]
	*/
	FROM (
	SELECT LEFT(mf.physical_name, 2) AS Drive
		, MAX(CAST(fd.FreeSpaceMB / 1024 as decimal(20,2))) [AvailableGBs]
		, SUM(num_of_reads) AS num_of_reads
		, SUM(io_stall_read_ms) AS io_stall_read_ms
		, SUM(num_of_writes) AS num_of_writes
		, SUM(io_stall_write_ms) AS io_stall_write_ms
		, SUM(num_of_bytes_read) AS num_of_bytes_read
		, SUM(num_of_bytes_written) AS num_of_bytes_written
		, SUM(io_stall) AS io_stall
		  FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
		  INNER JOIN sys.master_files AS mf WITH (NOLOCK)
		  ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
		  INNER JOIN @fixeddrives fd ON fd.drive = LEFT(mf.physical_name, 1)
	  
		  GROUP BY LEFT(mf.physical_name, 2)) AS tab
	ORDER BY CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE (io_stall/(num_of_reads + num_of_writes)) END OPTION (RECOMPILE);
	RAISERROR (N'Checked for disk latency and space',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Check for disk space on the server
			----------------------------------------*/



	SELECT @Kb = 1024.0;
	SELECT @PageSize=v.low/@Kb 
	FROM master..spt_values v 
	WHERE v.number=1 AND v.type='E';

	INSERT @LogSpace 
	EXEC sp_executesql N'DBCC sqlperf(logspace) WITH NO_INFOMSGS';
	INSERT #LogSpace
	SELECT DatabaseName
	, LogSize
	, SpaceUsedPercent
	, Status 
	, NULL
	FROM @LogSpace 
	OPTION (RECOMPILE)

	SET @Databasei_Count = 1; 
	WHILE @Databasei_Count <= @Databasei_Max 
	BEGIN 
		SELECT @DatabaseName = d.databasename, @DatabaseState = d.state FROM @Databases d WHERE id = @Databasei_Count AND d.state NOT IN (2,6)
		IF EXISTS( SELECT @DatabaseName)
		BEGIN
			SET @dynamicSQL = 'USE [' + @DatabaseName + '];
			DBCC showfilestats WITH NO_INFOMSGS;'
			INSERT @FileStats
			EXEC sp_executesql @dynamicSQL;
			SET @dynamicSQL = 'USE [' + @DatabaseName + '];
			SELECT ''' +@DatabaseName + ''', filename, size, ISNULL(FILEGROUP_NAME(groupid),''LOG''), [name] ,maxsize, growth  FROM dbo.sysfiles sf ; '
			INSERT @FileSize 
			EXEC sp_executesql @dynamicSQL;
			SET @dynamicSQL = 'USE [' + @DatabaseName + '];
			DBCC loginfo WITH NO_INFOMSGS;'

			INSERT #dbccloginfo
			EXEC sp_executesql @dynamicSQL;

			SELECT @VLFcount = COUNT(*) FROM #dbccloginfo 
			DELETE FROM #dbccloginfo
			UPDATE #LogSpace SET VLFCount =  @VLFcount WHERE DatabaseName = @DatabaseName
		END
		SET @Databasei_Count = @Databasei_Count + 1
	END

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 11, 'DATABASE FILES - Disk Usage Ordered by largest','------','------'
	INSERT #output_man_script (SectionId, Section,Summary, Details)

	SELECT 11,
	REPLICATE('|',100-[FreeSpace %]) + REPLICATE('''',[FreeSpace %]) +' ('+ CONVERT(VARCHAR,CONVERT(INT,ROUND(100-[FreeSpace %],0))) + '%)'
	, ('DB:'
	+ DatabaseName 
	+ '; MAX:'
	+ CONVERT(VARCHAR,maxsize)
	+ '; Growth:'
	+ CASE WHEN growth <= 100 THEN CONVERT(VARCHAR,growth) + '%' ELSE CONVERT(VARCHAR,growth/128) + 'MB' END 
	+ '; SizeGB:'
	+ CONVERT(VARCHAR,CONVERT(MONEY,FileSize/1024))
	+ '; Used:' 
	+ CONVERT(VARCHAR,100-[FreeSpace %] )
	+'%'
	)
	,(UPPER(DriveLetter)
	+' FG:'
	+ FileGroupName 
	+ CASE WHEN FileGroupName = 'LOG' THEN '(' + CONVERT(VARCHAR,VLFCount) + 'vlfs)' ELSE '' END
	--, LogicalName  
	+'; Path:'
	+ [FileName]  
	)
 

	FROM (
	SELECT
	 DatabaseName = fsi.DatabaseName
	 , FileGroupName = fsi.FileGroupName
	 , maxsize
	 , growth
	 , LogicalName = RTRIM(fsi.LogicalName)
	 , [FileName] = RTRIM(fsi.FileName)
	 , DriveLetter = LEFT(RTRIM(fsi.FileName),2)
	 , FileSize = CAST(fsi.FileSize*@PageSize/@Kb as decimal(15,2))
	 , UsedSpace = CAST(ISNULL((fs.UsedExtents*@PageSize*8.0/@Kb), fsi.FileSize*@PageSize/@Kb * ls.SpaceUsedPercent/100.0) as MONEY)
	 , FreeSpace = CAST(ISNULL(((fsi.FileSize - UsedExtents*8.0)*@PageSize/@Kb), (100.0-ls.SpaceUsedPercent)/100.0 * fsi.FileSize*@PageSize/@Kb) as MONEY)
	 ,[FreeSpace %] = CAST(ISNULL(((fsi.FileSize - UsedExtents*8.0) / fsi.FileSize * 100.0), 100-ls.SpaceUsedPercent) as MONEY) 
	 , VLFCount 
	FROM @FileSize fsi  
	LEFT JOIN @FileStats fs ON fs.FileName = fsi.FileName  
	LEFT JOIN #LogSpace ls ON ls.DatabaseName = fsi.DatabaseName  
	 ) T1
	WHERE T1.[FreeSpace %] < (CASE WHEN @ShowWarnings = 1 THEN 20 ELSE 100 END)
	ORDER BY DatabaseName ASC, FileSize DESC
	OPTION (RECOMPILE)
	RAISERROR (N'Checked free space',0,1) WITH NOWAIT;


			/*----------------------------------------
			--Look at caching plans,  size matters here
			----------------------------------------*/
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 12, 'CACHING PLANS - as % of total memory used by SQL','------','------'
	INSERT #output_man_script (SectionId, Section,Summary ,Details )
	SELECT 12, REPLICATE('|',[1 use size]/[Size MB]*100) + REPLICATE('''',100- [1 use size]/[Size MB]*100) +' '+ CONVERT(VARCHAR,CONVERT(INT,[1 use size]/[Size MB]*100)) +'% of '
	+CONVERT(VARCHAR,CONVERT(BIGINT,[Size MB])) +'MB is 1 use' 
	, objtype 
	+'; Plans:'+ CONVERT(VARCHAR,[Total Use])
	+'; Total Refs:'+ CONVERT(VARCHAR,[Total Rfs])
	+'; Avg Use:'+ CONVERT(VARCHAR,[Avg Use])
	, CONVERT(VARCHAR,[Size MB]) + 'MB'
	+'; Single use:'+ CONVERT(VARCHAR,[1 use size]*100/[Size MB]) + '%'
	+'; Single plans:'+ CONVERT(VARCHAR,[1 use count])

	FROM (
	SELECT objtype
	, SUM(refcounts)[Total Rfs]
	, AVG(refcounts) [Avg Refs]
	, SUM(usecounts) [Total Use]
	, AVG(usecounts) [Avg Use]
	, CONVERT(MONEY,SUM(size_in_bytes*0.000000953613)) [Size MB]
	, SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) [1 use count]
	, SUM(CASE WHEN usecounts = 1 THEN CONVERT(MONEY,size_in_bytes*0.000000953613) ELSE 0 END) [1 use size]
	FROM sys.dm_exec_cached_plans GROUP BY objtype
	) TCP
	OPTION (RECOMPILE)

	RAISERROR (N'Got cached plan statistics',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Get the top 10 query plan bloaters for single use queries
			----------------------------------------*/

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 13,'CACHING PLANS - TOP 10 single use plans','------','------'
	INSERT #output_man_script (SectionId, Section,Summary ,Details )
	SELECT TOP(10) 13, REPLICATE('|',cp.size_in_bytes/1024/1000) + ' ' + CONVERT(VARCHAR,CONVERT(MONEY,cp.size_in_bytes)/1024) + 'KB'
	, cp.cacheobjtype
	+ ' '+ cp.objtype
	+ '; SizeMB:' + CONVERT(VARCHAR,CONVERT(MONEY,cp.size_in_bytes)/1024/1000)
	, replace(replace(replace(replace(LEFT(CONVERT(NVARCHAR(4000),[text]),@LeftText), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), '  ',' ') AS [QueryText]
	FROM sys.dm_exec_cached_plans AS cp WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_sql_text(plan_handle) 
	WHERE cp.cacheobjtype = N'Compiled Plan' 
	AND cp.objtype IN (N'Adhoc', N'Prepared') 
	AND cp.usecounts = 1
	ORDER BY cp.size_in_bytes DESC OPTION (RECOMPILE);

	RAISERROR (N'Got cached plan statistics - Biggest single use plans',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Find cpu load, io and memory per DB
			----------------------------------------*/

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 14, 'CPU IO Memory','------','------'
	INSERT #output_man_script (SectionId, Section,Summary ,Details )

	SELECT 14,  REPLICATE('|',CONVERT(MONEY,T2.[TotalIO])/ SUM(T2.[TotalIO]) OVER()* 100.0) 
	+ REPLICATE('''',100 - CONVERT(MONEY,T2.[TotalIO])/ SUM(T2.[TotalIO]) OVER()* 100.0) + '' + CONVERT(VARCHAR, CONVERT(INT,ROUND(CONVERT(MONEY,T2.[TotalIO])/ SUM(T2.[TotalIO]) OVER()* 100.0,0))) +'% IO '
	, T1.DatabaseName
	+ '; CPU: ' + ISNULL(CONVERT(VARCHAR,CONVERT(INT,ROUND([CPU_Time(Ms)]/1000 * 1.0 /SUM([CPU_Time(Ms)]/1000) OVER()* 100.0,0))),'0') +'%'
	+ '; IO:' +  ISNULL(CONVERT(VARCHAR,CONVERT(INT,ROUND(CONVERT(MONEY,T2.[TotalIO])/ SUM(T2.[TotalIO]) OVER()* 100.0 ,0))) ,'0')+'%'
	+ '; Buffer:' +  ISNULL(CONVERT(VARCHAR,CONVERT(INT,ROUND(CONVERT(MONEY,src.db_buffer_pages )/ SUM(src.db_buffer_pages ) OVER()* 100.0 ,0))),'0')+'%'

	, ' CPU time(s):' + CONVERT(VARCHAR,[CPU_Time(Ms)]) + ' (' + CONVERT(VARCHAR,CAST([CPU_Time(Ms)]/1000 * 1.0 /SUM([CPU_Time(Ms)]/1000) OVER()* 100.0 AS DECIMAL(5, 2))) + '%)' 
	+ '; Total IO: ' + CONVERT(VARCHAR,[TotalIO]) + ' ; Reads: ' + CONVERT(VARCHAR,T2.[Number of Reads]) +' ; Writes: '+ CONVERT(VARCHAR,T2.[Number of Writes])
	+ '; Buffer Pages:' + CONVERT(VARCHAR,src.db_buffer_pages)
	+ '; Buffer MB:'+ CONVERT(VARCHAR,src.db_buffer_pages / 128) 

	FROM(
		SELECT TOP 100 PERCENT
		DatabaseID
		,DB_Name(DatabaseID)AS [DatabaseName]
		,SUM(total_worker_time)AS [CPU_Time(Ms)]
		FROM sys.dm_exec_query_stats AS qs
		CROSS APPLY
		(
			SELECT CONVERT(int, value)AS [DatabaseID]
			FROM sys.dm_exec_plan_attributes(qs.plan_handle)
			WHERE attribute =N'dbid'
		)AS epa
		GROUP BY DatabaseID
		ORDER BY SUM(total_worker_time) DESC
	) T1
	LEFT OUTER JOIN (
	SELECT
		Name AS 'DatabaseName'
		, SUM(num_of_reads) AS'Number of Reads'
		, SUM(num_of_writes) AS'Number of Writes'
		, SUM(num_of_writes) +  SUM(num_of_reads) [TotalIO]
		FROM sys.dm_io_virtual_file_stats(NULL,NULL) I
		INNER JOIN sys.databases D ON I.database_id = d.database_id
		GROUP BY Name
	) T2 ON T1.DatabaseName = T2.DatabaseName
	LEFT OUTER JOIN 
	(
		SELECT database_id,
		db_buffer_pages =COUNT_BIG(*)
		FROM sys.dm_os_buffer_descriptors
		GROUP BY database_id
	) src ON src.database_id = T1.DatabaseID
	WHERE T1.DatabaseName IS NOT NULL
	ORDER BY [TotalIO] DESC,[CPU_Time(Ms)] DESC
	OPTION (RECOMPILE) ;

	RAISERROR (N'Checked CPU, IO  and memory usage',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Get to wait types, the TOP 10 would be good for now
			----------------------------------------*/

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 15, 'TOP 10 WAIT STATS','------','------'
	/*Thanks Paul Randal http://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/ */
	--INSERT @Waits 
	INSERT #output_man_script (SectionId, Section,Summary  )
	SELECT TOP 10 15,
	REPLICATE ('|', 100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER())+ REPLICATE ('''', 100- 100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER()) + CONVERT(VARCHAR, CONVERT(INT,ROUND(100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER(),0))) + '%'
	, [wait_type]

	+'; Wait(s):'+ CONVERT(VARCHAR,CONVERT(BIGINT,[wait_time_ms] / 1000.0)) + '(s)'
	+'; Wait count:' + CONVERT(VARCHAR,[waiting_tasks_count])
	FROM sys.dm_os_wait_stats
	WHERE 
	[wait_type] NOT IN (
			N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR',
			N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
			N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
			N'CHKPT', N'CLR_AUTO_EVENT',
			N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
 
			-- Maybe uncomment these four if you have mirroring issues
	 --       N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
	 --       N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD',

			N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
			N'EXECSYNC', N'FSAGENT',
			N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
 
			-- Maybe uncomment these six if you have AG issues
			N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
			N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',
			N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
 
			N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
			N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT',
			N'ONDEMAND_TASK_QUEUE',
			N'PREEMPTIVE_XE_GETTARGETSTATE',
			N'PWAIT_ALL_COMPONENTS_INITIALIZED',
			N'PWAIT_DIRECTLOGCONSUMER_GETNEXT',
			N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE',
			N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
			N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK',
			N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE',
			N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
			N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP',
			N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
			N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
			N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
			N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT',
			N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SQLTRACE_BUFFER_FLUSH',
			N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
			N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS',
			N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
			N'WAIT_XTP_RECOVERY',
			N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
			N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
			N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT')
		AND [waiting_tasks_count] > 0
	ORDER BY [wait_time_ms] DESC
	OPTION (RECOMPILE)

	RAISERROR (N'Filtered wait stats have been prepared',0,1) WITH NOWAIT;


			/*----------------------------------------
			--Look at Plan Cache and DMV to find missing index impacts
			----------------------------------------*/

	INSERT #querystats
		SELECT
			qs.execution_count
			, qs.total_logical_reads
			,  CONVERT(MONEY,qs.total_logical_reads)/1000 [Total_MBsRead]
			, qs.total_logical_writes
			,  CONVERT(MONEY,qs.total_logical_writes)/1000 [Total_MBsWrite]
			, qs.total_worker_time,  CONVERT(MONEY,qs.total_elapsed_time)/1000000 total_elapsed_time_in_S
			, qs.total_elapsed_time
			, qs.last_execution_time
			, qs.plan_handle
			, qs.sql_handle
			FROM sys.dm_exec_query_stats qs WITH (NOLOCK)
			ORDER BY [Total_MBsRead] DESC, qs.total_elapsed_time, qs.execution_count
	INSERT #output_man_script (SectionId, Section,Summary, Details, QueryPlan) SELECT 16, 'PLAN INSIGHT - MISSING INDEX','------','------',NULL
	;WITH XMLNAMESPACES  
		   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
	INSERT #output_man_script (SectionId, Section,Summary, Details, QueryPlan)
	SELECT 16,
		REPLICATE('|',TFF.[SecondsSavedPerDay]/28800*100) + ' $' + CONVERT(VARCHAR,(TFF.[SecondsSavedPerDay]/28800) * @FTECost) + 'pa ('+CONVERT(VARCHAR,TFF.[SecondsSavedPerDay]/28800) + 'FTE)' [Section]
		,CONVERT(VARCHAR,TFF.execution_count) + ' executions'
		+ '; Cost:' + CONVERT(VARCHAR,TFF.SubTreeCost)
		+ '; GuessingCost(s):' + CONVERT(VARCHAR,(ISNULL(TFF.SubTreeCost * @secondsperoperator * TFF.execution_count * (100-TFF.impact),0)))
		+ '; Impact:' +CONVERT(VARCHAR, TFF.impact)
		+ '; EstRows:' + CONVERT(VARCHAR,TFF.estRows)
		+ '; Magic:' + CONVERT(VARCHAR,TFF.Magic)
		+ '; ' + CONVERT(VARCHAR, TFF.SecondsSavedPerDay) + '(s)'
		+ '; Total time:' + CONVERT(VARCHAR,TFF.total_elapsed_time/1000/1000) + '(s)' [Summary]
		, ';'+TFF.[statement] 
		+ ISNULL(':EQ:'+ TFF.equality_columns,'')
		+ ISNULL(':INEQ:'+ TFF.inequality_columns,'')
		+ ISNULL(':INC:'+ TFF.include_columns,'') [Details]
		, tp.query_plan
		FROM (
		SELECT 
		 SUM(TF.SubTreeCost) SubTreeCost
		, SUM(CONVERT(FLOAT,TF.estRows )) estRows
		, SUM(ISNULL([Magic],0)) [Magic]
		, SUM(TF.impact/100 * TF.total_elapsed_time )/1000000/@DaysOldestCachedQuery  [SecondsSavedPerDay]
		, TF.impact	
		, TF.execution_count	
		, TF.total_elapsed_time	
		, TF.database_id	
		, TF.OBJECT_ID	
		, TF.statement	
		, TF.equality_columns	
		, TF.inequality_columns	
		, TF.include_columns
		, TF.plan_handle
	
		FROM
		(
		SELECT 
		--, query_plan
		--, n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text
		  CONVERT(FLOAT,n.value('(@StatementSubTreeCost)', 'VARCHAR(4000)')) AS SubTreeCost
		, n.value('(@StatementEstRows)', 'VARCHAR(4000)') AS estRows
		, CONVERT(FLOAT,n.value('(//MissingIndexGroup/@Impact)[1]', 'FLOAT')) AS impact
		, tab.execution_count
		, tab.total_elapsed_time
		, tab.plan_handle
		, DB_ID(REPLACE(REPLACE(n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)'),'[',''),']','')) AS database_id
		, OBJECT_ID(n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)') + '.' + 
				   n.value('(//MissingIndex/@Schema)[1]', 'VARCHAR(128)') + '.' + 
				   n.value('(//MissingIndex/@Table)[1]', 'VARCHAR(128)')) AS OBJECT_ID, 
			   n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)') + '.' + 
				   n.value('(//MissingIndex/@Schema)[1]', 'VARCHAR(128)') + '.' + 
				   n.value('(//MissingIndex/@Table)[1]', 'VARCHAR(128)')  
			   AS statement, 
			   (   SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', ' 
				   FROM n.nodes('//ColumnGroup') AS t(cg) 
				   CROSS APPLY cg.nodes('Column') AS r(c) 
				   WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'EQUALITY' 
				   FOR  XML PATH('') 
			   ) AS equality_columns, 
				(  SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', ' 
				   FROM n.nodes('//ColumnGroup') AS t(cg) 
				   CROSS APPLY cg.nodes('Column') AS r(c) 
				   WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'INEQUALITY' 
				   FOR  XML PATH('') 
			   ) AS inequality_columns, 
			   (   SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', ' 
				   FROM n.nodes('//ColumnGroup') AS t(cg) 
				   CROSS APPLY cg.nodes('Column') AS r(c) 
				   WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'INCLUDE' 
				   FOR  XML PATH('') 
			   ) AS include_columns 

		FROM  
		( 
		   SELECT query_plan
		   , qs.*
		   FROM (    
					SELECT plan_handle
					,SUM(qs.execution_count			)execution_count
					,MAX(qs.total_elapsed_time		)total_elapsed_time
				   FROM #querystats qs WITH(NOLOCK)
				   WHERE qs.id <= @TopQueries  
				   GROUP BY  plan_handle
				   HAVING SUM(qs.total_elapsed_time ) > @MinWorkerTime
				 ) AS qs 
			OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp  
		--	WHERE tp.query_plan.exist('//MissingIndex')=1 
				--AND qs.execution_count > @MinExecutionCount   
		) AS tab 
		CROSS APPLY query_plan.nodes('//StmtSimple') AS q(n) 
		) TF
		LEFT OUTER JOIN (
		SELECT TOP 100 PERCENT (( ISNULL(user_seeks,0) + ISNULL(user_scans,0 ) * avg_total_user_cost * avg_user_impact)/1) [Magic]
		,user_seeks 
		,user_scans
		,user_seeks + user_scans AllScans
		,avg_total_user_cost
		,avg_user_impact
		, mid.object_id
		, [statement]
		, equality_columns
		, inequality_columns
		, included_columns
		FROM sys.dm_db_missing_index_group_stats AS migs 
				INNER JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle 
				INNER JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle 
				LEFT OUTER JOIN sys.objects WITH (nolock) ON mid.OBJECT_ID = sys.objects.OBJECT_ID 
				ORDER BY [Magic] DESC
		) TStats ON TStats.object_id = TF.OBJECT_ID
		AND TStats.statement = TF.statement
		AND ISNULL(TStats.equality_columns +', ',0) = ISNULL(TF.equality_columns ,0)
		AND ISNULL(TStats.inequality_columns +', ',0) = ISNULL(TF.inequality_columns,0)
		AND ISNULL(TStats.included_columns +', ',0) = ISNULL(TF.include_columns,0)

		GROUP BY  TF.impact	
		, TF.execution_count
		, TF.total_elapsed_time	
		, TF.database_id	
		, TF.OBJECT_ID	
		, TF.statement	
		, TF.equality_columns	
		, TF.inequality_columns	
		, TF.include_columns
		, TF.plan_handle
		) TFF
		OUTER APPLY sys.dm_exec_query_plan(TFF.plan_handle) tp  
		WHERE [statement] <> '[msdb].[dbo].[backupset]'
		ORDER BY  [SecondsSavedPerDay] DESC, total_elapsed_time DESC OPTION (RECOMPILE);

	INSERT #output_man_script (SectionId, Section,Summary, Details, QueryPlan) SELECT 17,'PLAN INSIGHT - EVERYTHING','------','------',NULL
	INSERT #output_man_script (SectionId, Section,Summary, Details, QueryPlan) 

	SELECT  17,
	 /*Bismillah, Find most intensive query*/
	REPLICATE ('|', CASE WHEN [Total_GBsRead]*[Impact%] = 0 THEN 0 ELSE 100.0 * [Total_GBsRead]*[Impact%]  / SUM ([Total_GBsRead]*[Impact%]) OVER() END)   
	+ CASE WHEN [Impact%] > 0 THEN CONVERT(VARCHAR,CONVERT(INT,ROUND(100.0 * [Total_GBsRead]*[Impact%]  / SUM ([Total_GBsRead]*[Impact%]) OVER(),0))) + '%' ELSE '' END [Section]

		, CONVERT(VARCHAR,[execution_count])
		+' events'
		+CASE 
			WHEN [Impact%] > 0 AND [ImpactType] = 'Missing Index'   THEN ' Impacted by: Missing Index (' + CONVERT(VARCHAR,[Impact%]) + '%)'
			WHEN [Impact%] > 0 AND [ImpactType] ='CONVERT_IMPLICIT' THEN ' Impacted by: CONVERT_IMPLICIT' 
			ELSE '' END  
		+ '; ' + CONVERT(VARCHAR,[Total_GBsRead]) +'GBs of I/O'
		+ '(' + CONVERT(VARCHAR,[total_logical_reads]) + ' pages)'
		+' took:' + CONVERT(VARCHAR,[total_elapsed_time_in_S]) +'(seconds)' [Summary]
		, ISNULL([Database] +':','')
		+ CASE WHEN [Impact%] > 0
		THEN 'Could reduce to: ' + CONVERT(VARCHAR, [Total_GBsRead] -([Impact%]/100 * [Total_GBsRead])) + 'GB'+ ' in ' + CONVERT(VARCHAR, CONVERT(INT,[total_elapsed_time_in_S] -([Impact%]/100) * [total_elapsed_time_in_S])) +'(s)'
		ELSE ''
		END
		+ '; Writes:'+ CONVERT(VARCHAR,[total_logical_writes])
		+ '(' + CONVERT(VARCHAR,[Total_GBsWrite]) + 'GB)' [Details]
		--, T1.[total_worker_time], T1.[last_execution_time]
		, [query_plan] /*This makes the query crawl, only add back when you have time or need to see the full plans, but you dont want this for 10k rows*/
		FROM (
	
		SELECT TOP 100 PERCENT
		CASE 
		WHEN PATINDEX('%MissingIndexes%',CAST(qp.query_plan AS NVARCHAR(MAX))) > 0 THEN 'Missing Index' 
		WHEN PATINDEX('%PlanAffectingConvert%',CAST(qp.query_plan AS NVARCHAR(MAX))) > 0 THEN 'CONVERT_IMPLICIT' ELSE NULL END  [ImpactType]
		, CONVERT(MONEY,CASE WHEN PATINDEX('%MissingIndexGroup Impact%',CAST(qp.query_plan AS NVARCHAR(MAX))) > 0  
		THEN CONVERT(MONEY,REPLACE(REPLACE(SUBSTRING(CONVERT(NVARCHAR(MAX),qp.query_plan),PATINDEX('%MissingIndexGroup Impact%',CAST(qp.query_plan AS NVARCHAR(MAX)))+26,6),'"><',''),'"',''))
		ELSE NULL 
		END) [Impact%]
		, T1.[execution_count], T1.[total_logical_reads], T1.[total_logical_writes]
		, [Total_MBsRead]/1000 [Total_GBsRead]
		, [Total_MBsWrite]/1000 [Total_GBsWrite]
		, T1.[total_worker_time], T1.[total_elapsed_time_in_S],  T1.[last_execution_time]
		, replace(replace(replace(qt.[Text],CHAR(10),' '), CHAR(13), ' '), '  ',' ') [QueryText]
		, qp.[query_plan]
		, DB_NAME(qp.dbid) [Database]
		, OBJECT_NAME(qp.objectid) [Object]
		FROM 
		#querystats T1
		CROSS APPLY sys.dm_exec_query_plan(T1.plan_handle) qp
		CROSS APPLY sys.dm_exec_sql_text(T1.sql_handle) qt
		WHERE T1.id <= @TopQueries
		--WHERE PATINDEX('%MissingIndex%',CAST(query_plan AS VARCHAR(MAX))) > 0
		ORDER BY CASE WHEN  PATINDEX('%MissingIndexes%',CAST(qp.query_plan AS NVARCHAR(MAX)))  > 0 THEN 1 ELSE 0 END DESC
		,CASE WHEN  PATINDEX('%MissingIndexes%',CAST(qp.query_plan AS NVARCHAR(MAX))) > 0 
		 THEN  PATINDEX('%MissingIndexes%',CAST(qp.query_plan AS NVARCHAR(MAX))) * [Total_MBsRead]  ELSE 0 END DESC 
	
		) q 
		ORDER BY CASE WHEN [Impact%] > 0 THEN 1 ELSE 0 END DESC, [Total_GBsRead]*[Impact%] DESC OPTION (RECOMPILE);


	RAISERROR	  (N'Evaluated execution plans for missing indexes',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Loop all the user databases to run database specific commands against them
			----------------------------------------*/

	SET @dynamicSQL = ''
	SET @Databasei_Count = 1; 
	WHILE @Databasei_Count <= @Databasei_Max 
	BEGIN 
			/*----------------------------------------
			--Get missing index information for each database
			----------------------------------------*/
		SELECT @DatabaseName = d.databasename, @DatabaseState = d.state FROM @Databases d WHERE id = @Databasei_Count AND d.state NOT IN (2,6) OPTION (RECOMPILE)
		IF EXISTS( SELECT @DatabaseName)
		BEGIN  
			SET @dynamicSQL = '
			USE ['+@DatabaseName +']
			SELECT '''+@DatabaseName+'''
			,  (( user_seeks + user_scans ) * avg_total_user_cost * avg_user_impact)/' + CONVERT(NVARCHAR,@DaysUptime) + ' daily_magic_benefit_number
			, [Table] = [statement]
			, [CreateIndexStatement] = ''CREATE NONCLUSTERED INDEX IX_LEXEL_'' + REPLACE(ISNULL(sys.objects.name COLLATE DATABASE_DEFAULT 	+ ''_'' ,''''),'' '',''_'')
			+ REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns,'''')+ISNULL(mid.inequality_columns,''''), ''['', ''''), '']'',''''), '', '',''_'') + REPLACE(CONVERT(VARCHAR,GETDATE(),102),''.'',''_'') + ''T''  + REPLACE(CONVERT(VARCHAR,GETDATE(),108),'':'',''_'') + '' ON '' + [statement] 
			+ REPLACE('' ( '' + IsNull(mid.equality_columns, '''')
			+ CASE WHEN mid.inequality_columns IS NULL THEN '''' ELSE CASE WHEN mid.equality_columns IS NULL THEN '''' ELSE '','' END + mid.inequality_columns END + '' ASC ) '' ,'','','' ASC ,'')	+ CASE WHEN mid.included_columns IS NULL THEN '''' ELSE ''INCLUDE ('' + mid.included_columns + '')'' END 
			+ ''WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = '+@rebuildonline+', ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON,FILLFACTOR = 90) ON [PRIMARY];''
			, mid.equality_columns
			, mid.inequality_columns
			, mid.included_columns
			FROM sys.dm_db_missing_index_group_stats AS migs 
			INNER JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle 
			INNER JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle 
			LEFT OUTER JOIN sys.objects WITH (nolock) ON mid.OBJECT_ID = sys.objects.OBJECT_ID 
			WHERE (migs.group_handle IN (SELECT TOP 100 PERCENT group_handle FROM sys.dm_db_missing_index_group_stats WITH (nolock) ORDER BY (avg_total_user_cost * avg_user_impact) * (user_seeks + user_scans) DESC))  
			AND OBJECTPROPERTY(sys.objects.OBJECT_ID, ''isusertable'') = 1 
			ORDER BY daily_magic_benefit_number DESC, [CreateIndexStatement] DESC OPTION (RECOMPILE);'
			INSERT #MissingIndex
			EXEC sp_executesql @dynamicSQL;

	
		/*13. Find idle indexes*/
			/*---------------------------------------Shows Indexes that have never been used---------------------------------------*/
			SET ANSI_WARNINGS OFF
			SET @dynamicSQL = '
			USE ['+@DatabaseName +']
			DECLARE @DaysAgo INT, @TheDate DATETIME
			SET @DaysAgo = 5
			SET @TheDate =  CONVERT(DATETIME,CONVERT(INT,DATEADD(DAY,-@DaysAgo,GETDATE())))
			DECLARE @db_id smallint, @tab_id INT 
			SET @db_id=db_id()
			SET @tab_id=object_id(''Production.Product'')
			SELECT '''+@DatabaseName+''',
			CASE WHEN b.type_desc = ''CLUSTERED'' THEN ''Consider Carefully'' ELSE ''May remove'' END Consideration
			, t.name TableName, b.type_desc TypeDesc, b.name IndexName, a.user_updates Updates, a.last_user_scan, a.last_user_seek, SUM(ISNULL(aa.page_count,0)) Pages
			FROM sys.dm_db_index_usage_stats as a
			JOIN sys.indexes AS b ON a.object_id = b.object_id AND a.index_id = b.index_id
			LEFT OUTER JOIN sys.tables AS t ON b.[object_id] = t.[object_id]
			LEFT OUTER JOIN INFORMATION_SCHEMA.TABLES isc ON isc.TABLE_NAME = t.name
			LEFT OUTER JOIN sys.dm_db_index_physical_stats (@db_id,@tab_id,NULL, NULL, NULL) AS aa ON aa.object_id = a.object_id
			WHERE (DATEDIFF(DAY,a.last_user_scan,GETDATE()) > @DaysAgo AND DATEDIFF(DAY,a.last_user_seek,GETDATE()) > @DaysAgo)
			AND t.name NOT LIKE ''sys%''
			GROUP BY t.name, b.type_desc, b.name, a.user_updates, a.last_user_scan, a.last_user_seek
			HAVING SUM(ISNULL(aa.page_count,0)) > 50
			ORDER BY Pages DESC OPTION (RECOMPILE)
			'
			INSERT @NeverUsedIndex
			EXEC sp_executesql @dynamicSQL;
			SET ANSI_WARNINGS ON
		/*14. Find heaps*/
			/*---------------------------------------Shows tables without primary key. Heaps---------------------------------------*/
			SET @dynamicSQL = '
			USE ['+@DatabaseName +']
			SELECT '''+@DatabaseName +''', SCHEMA_NAME(o.schema_id) AS [schema],object_name(i.object_id ) AS [table],p.rows,user_seeks,user_scans,user_lookups,user_updates,last_user_seek,last_user_scan,last_user_lookup
			FROM sys.indexes i 
				INNER JOIN sys.objects o ON i.object_id = o.object_id
				INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
				LEFT OUTER JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id
			WHERE i.type_desc = ''HEAP'' AND SCHEMA_NAME(o.schema_id) NOT LIKE ''sys'' AND rows > 100
			ORDER BY rows desc OPTION (RECOMPILE);'
			INSERT #HeapTable
			EXEC sp_executesql @dynamicSQL;

			SET @dynamicSQL = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			USE ['+@DatabaseName+'];
			SELECT 
				'''+@DatabaseName+''' [DbName]
				, ObjectNm
				, StatsID
				, StatsName
				, SchemaName
				, ModificationCount
				, [LastUpdated] 
			FROM (
				SELECT 
					OBJECT_NAME(p.object_id) ObjectNm
						, p.index_id StatsID
						, s.name StatsName
						, sce.name SchemaName
						, sum(pc.modified_count) ModificationCount
						, MAX(
								STATS_DATE(s.object_id, s.stats_id)
							 ) AS [LastUpdated]
				FROM sys.system_internals_partition_columns pc
				INNER JOIN sys.partitions p ON pc.partition_id = p.partition_id
				INNER JOIN sys.stats s ON s.object_id = p.object_id AND s.stats_id = p.index_id
				INNER JOIN sys.stats_columns sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id AND sc.stats_column_id = pc.partition_column_id
				INNER JOIN sys.tables t ON t.object_id = s.object_id
				INNER JOIN sys.schemas sce ON sce.schema_id = t.schema_id
				GROUP BY p.object_id, p.index_id, s.name,sce.name
			) stats
			WHERE ObjectNm NOT LIKE ''sys%'' AND ModificationCount != 0
			AND ObjectNm NOT LIKE ''ifts_comp_fragment%''
			AND ObjectNm NOT LIKE ''fulltext_%''
			AND ObjectNm NOT LIKE ''filestream_%''
			AND ObjectNm NOT LIKE ''queue_messages_%''
			AND LastUpdated < DATEADD(DAY, - 1, GETDATE())
			ORDER BY ObjectNm, StatsName OPTION (RECOMPILE);
			';
			INSERT #Action_Statistics
			EXEC sp_executesql @dynamicSQL;
	   
		   SET @dynamicSQL = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			USE ['+@DatabaseName+'];
		   -- Possible Bad NC Indexes (writes > reads)  (Query 52) (Bad NC Indexes)
			SELECT OBJECT_NAME(s.[object_id]) AS [Table Name], i.name AS [Index Name], i.index_id, 
			i.is_disabled, i.is_hypothetical, i.has_filter, i.fill_factor,
			user_updates AS [Total Writes], user_seeks + user_scans + user_lookups AS [Total Reads],
			user_updates - (user_seeks + user_scans + user_lookups) AS [Difference]
			FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
			INNER JOIN sys.indexes AS i WITH (NOLOCK)
			ON s.[object_id] = i.[object_id]
			AND i.index_id = s.index_id
			WHERE OBJECTPROPERTY(s.[object_id],''IsUserTable'') = 1
			AND s.database_id = DB_ID()
			AND user_updates > (user_seeks + user_scans + user_lookups)
			AND i.index_id > 1
			ORDER BY [Difference] DESC, [Total Writes] DESC, [Total Reads] ASC OPTION (RECOMPILE);
			'
			--EXEC sp_executesql @dynamicSQL;

					/*----------------------------------------
			--Find badly behaving constraints
			----------------------------------------*/

		/* Constraints behaving badly*/
	
		SET @dynamicSQL = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			USE ['+@DatabaseName+'];
		IF EXISTS(
		SELECT 1
		from sys.check_constraints i 
		WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0 AND i.is_disabled = 0 
		)
		INSERT  #notrust (KeyType, Tablename, KeyName, DBCCcommand, Fix)
		SELECT ''Check'' as [KeyType], ''['+@DatabaseName+'].['' + s.name + ''].['' + o.name + '']'' [tablename]
		, ''['+@DatabaseName+'].['' + s.name + ''].['' + o.name + ''].['' + i.name + '']'' AS keyname
		, ''DBCC CHECKCONSTRAINTS (['' + i.name + '']) WITH ALL_ERRORMSGS'' [DBCC]
		, ''ALTER TABLE ['+@DatabaseName+'].['' + s.name + ''].'' + ''['' + o.name + ''] WITH CHECK CHECK CONSTRAINT ['' + i.name + '']'' [Fix]
		from sys.check_constraints i
		INNER JOIN sys.objects o ON i.parent_object_id = o.object_id
		INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
		WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0 AND i.is_disabled = 0
		OPTION (RECOMPILE)
		;

		IF EXISTS(
		SELECT 1
		from sys.foreign_keys i
					INNER JOIN sys.objects o ON i.parent_object_id = o.OBJECT_ID
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
		WHERE   i.is_not_trusted = 1
				   AND i.is_not_for_replication = 0
				   AND i.is_disabled = 0 
			   
		)
		INSERT  #notrust (KeyType, Tablename, KeyName, DBCCcommand, Fix)
		SELECT ''FK'' as[ KeyType],  ''['+@DatabaseName+'].['' + s.name + ''].'' + ''['' + o.name + '']'' AS TableName
				   , ''['+@DatabaseName+'].['' + s.name + ''].['' + o.name + ''].['' + i.name + '']'' AS FKName
				   ,''DBCC CHECKCONSTRAINTS (['' + i.name + '']) WITH ALL_ERRORMSGS'' [DBCC]
				   , ''ALTER TABLE ['+@DatabaseName+'].['' + s.name + ''].'' + ''['' + o.name + ''] WITH CHECK CHECK CONSTRAINT ['' + i.name + '']'' [Fix]

		FROM    sys.foreign_keys i
					INNER JOIN sys.objects o ON i.parent_object_id = o.OBJECT_ID
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
		WHERE   i.is_not_trusted = 1
					AND i.is_not_for_replication = 0
					AND i.is_disabled = 0
	   ORDER BY o.name  
	   OPTION (RECOMPILE)
	   '
	   --PRINT @dynamicSQL
		EXEC sp_executesql @dynamicSQL;



			SET @dynamicSQL = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			USE ['+@DatabaseName+'];
			SELECT '''+@DatabaseName+''', p.name AS [SP Name], qs.total_logical_writes AS [TotalLogicalWrites], 
			qs.total_logical_writes/qs.execution_count AS [AvgLogicalWrites], qs.execution_count,
			ISNULL(qs.execution_count/DATEDIFF(Second, qs.cached_time, GETDATE()), 0) AS [Calls/Second],
			qs.total_elapsed_time, qs.total_elapsed_time/qs.execution_count AS [avg_elapsed_time], 
			qs.cached_time
			FROM sys.procedures AS p WITH (NOLOCK)
			INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
			ON p.[object_id] = qs.[object_id]
			WHERE qs.database_id = DB_ID()
			AND qs.total_logical_writes > 0
			ORDER BY qs.total_logical_writes DESC OPTION (RECOMPILE);
			'
			INSERT #db_sps
			EXEC sp_executesql @dynamicSQL;

		END 
		SET @Databasei_Count = @Databasei_Count + 1; 
	END
	RAISERROR (N'Evaluated all databases',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Output results from all databases into results table
			----------------------------------------*/
	IF EXISTS (SELECT 1 FROM #MissingIndex ) 
	BEGIN
		INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 18, 'MISSING INDEXES - !Benefit > 1mm!','------','------'
		INSERT #output_man_script (SectionId, Section,Summary ,Details )
			SELECT 18, REPLICATE('|',ROUND(T1.magic_benefit_number /100,0))
			, 'Benefit:'+  CONVERT(VARCHAR,CONVERT(BIGINT,ROUND(T1.magic_benefit_number,0)))
			+ '; ' + T1.[Table]
			+ '; Eq:' + ISNULL(T1.equality_columns,'')
			+ '; Ineq:' +  ISNULL(T1.inequality_columns,'')
			+ '; Incl:' +  ISNULL(T1.included_columns,'')
			, T1.ChangeIndexStatement
			FROM #MissingIndex T1 
			WHERE '[' + T1.DB + ']' = LEFT(T1.[Table],LEN(T1.DB)+2) 
			ORDER BY magic_benefit_number DESC OPTION (RECOMPILE)
	END
	RAISERROR (N'Completed missing index details',0,1) WITH NOWAIT;

		IF EXISTS (SELECT 1 FROM #HeapTable ) 
	BEGIN
		INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 19, 'HEAP TABLES - Bad news','------','------'
		INSERT #output_man_script (SectionId, Section,Summary ,Details )
			SELECT 19, REPLICATE('|', (ISNULL(user_scans,0)+ ISNULL(user_seeks,0) + ISNULL(user_lookups,0) + ISNULL(user_updates,0))/100) + CONVERT(VARCHAR,(ISNULL(user_scans,0)+ ISNULL(user_seeks,0) + ISNULL(user_lookups,0) + ISNULL(user_updates,0))/100) 
			, 'Rows:' + CONVERT(VARCHAR,T1.rows)
			+ ';'+ '['+T1.DB+']' + '['+T1.[schema]+']' + '['+T1.[table]+']' 
			, 'Scan:' + CONVERT(VARCHAR,ISNULL(T1.last_user_scan,0) ,120)
			+ '; Seek:' + CONVERT(VARCHAR,ISNULL(T1.last_user_seek,0) ,120)
			+ '; Lookup:' + CONVERT(VARCHAR,ISNULL(T1.last_user_lookup,0) ,120)
			FROM #HeapTable T1  
			ORDER BY (ISNULL(user_scans,0)+ ISNULL(user_seeks,0) + ISNULL(user_lookups,0) + ISNULL(user_updates,0)) DESC,  DB OPTION (RECOMPILE);
	END
	RAISERROR (N'Found heap tables',0,1) WITH NOWAIT;

		IF EXISTS (SELECT 1 FROM @NeverUsedIndex ) 
	BEGIN
		INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 20, 'STALE INDEXES - Consider removing them at some stage','------','------'
		INSERT #output_man_script (SectionId, Section,Summary ,Details )

			SELECT 20, REPLICATE('|', DATEDIFF(DAY,last_user_scan,GETDATE()))
			, 'Updates: '+  CONVERT(VARCHAR,Updates)
			+ '; ' +TypeDesc + ':' 
			+ IndexName 
			, CONVERT(VARCHAR,Pages) + ' pages'
			+ '; DB:' + DB
			+ '; Table:' + TableName
			FROM @NeverUsedIndex /*They are like little time capsules.. just sitting there.. waiting*/
			ORDER BY  DATEDIFF(DAY,last_user_scan,GETDATE()) DESC OPTION (RECOMPILE)
	END
		IF EXISTS (SELECT 1 FROM #Action_Statistics ) 
	BEGIN
		INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 21,'STALE STATS - Worst news','------','------'
		INSERT #output_man_script (SectionId, Section,Summary ,Details )
			SELECT  21,
			REPLICATE('|',DATEDIFF(DAY,s.LastUpdated,GETDATE())) + CONVERT(VARCHAR,DATEDIFF(DAY,s.LastUpdated,GETDATE())) +' days old'
			, 'Modifications:' + CONVERT(VARCHAR,s.ModificationCount) +'; '+ DBname + '.['+SchemaName+'].['+TableName+']:['+StatisticsName+']'
			,'UPDATE STATISTICS ' + DBname + '.['+SchemaName+'].['+TableName+'] ['+StatisticsName+'] WITH FULLSCAN;' [UpdateStats]
		
			 FROM #Action_Statistics s OPTION (RECOMPILE);/*They are like little time capsules.. just sitting there.. waiting*/

	END
	RAISERROR (N'Listed state stats',0,1) WITH NOWAIT;

		 /*----------------------------------------
			--Most used database stored procedures
			----------------------------------------*/
		IF EXISTS( SELECT 1 FROM #db_sps)
	BEGIN
		INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 22, 'STORED PROCEDURE WORKLOAD - TOP 10','------','------'
		INSERT #output_man_script (SectionId, Section,Summary ,Details )

		SELECT TOP 10 22, REPLICATE('|', CONVERT(MONEY,execution_count*100) / SUM (execution_count) OVER() ) + ' '+ CONVERT(VARCHAR,CONVERT(INT,ROUND(CONVERT(MONEY,execution_count*100) / SUM (execution_count) OVER(),0))) + '%'
		,  [SP Name] + '; Executions:'+ CONVERT(VARCHAR,execution_count)
		+ '; Per second:' + CONVERT(VARCHAR,[Calls/Second])
		, dbname
		+ '; Avg Time:' + CONVERT(VARCHAR, avg_elapsed_time/1000/1000 ) + '(s)'
		+ '; Total time:' + CONVERT(VARCHAR, total_elapsed_time/1000/1000 ) + '(s)'
		+ '; Overall time:' + CONVERT(VARCHAR,CONVERT(MONEY,total_elapsed_time*100) / SUM (total_elapsed_time) OVER()) +'%'
		FROM #db_sps
		ORDER BY execution_count DESC OPTION (RECOMPILE)

	END
	RAISERROR (N'Database stored procedure details',0,1) WITH NOWAIT;
			/*----------------------------------------
			--General server settings and items of note
			----------------------------------------*/

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 24, 'Server details','------','------'
	INSERT #output_man_script (SectionId, Section, Summary  )
	SELECT 24,  @@SERVERNAME AS [Server Name]
	,'Evauation date: ' + CONVERT(VARCHAR,GETDATE(),120)


	INSERT #output_man_script (SectionId,Summary  )
	SELECT 24, 'Page Life Expectancy: ' + CONVERT(VARCHAR, cntr_value)
	FROM sys.dm_os_performance_counters WITH (NOLOCK)
	WHERE [object_name] LIKE N'%Buffer Node%' -- Handles named instances
	AND counter_name = N'Page life expectancy'  OPTION (RECOMPILE)


	INSERT #output_man_script (SectionId,Summary  )
	SELECT 24, 'Memory Grants Pending:' + CONVERT(VARCHAR, cntr_value)                                                                                                    
	FROM sys.dm_os_performance_counters WITH (NOLOCK)
	WHERE [object_name] LIKE N'%Memory Manager%' -- Handles named instances
	AND counter_name = N'Memory Grants Pending' OPTION (RECOMPILE);

	RAISERROR (N'Listed general instance stats',0,1) WITH NOWAIT;


	/* The default settings have been copied from sp_Blitz from http://FirstResponderKit.org
	Believe it or not, SQL Server doesn't track the default values
	for sp_configure options! We'll make our own list here.*/

	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'access check cache bucket count', 0, 1001 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'access check cache quota', 0, 1002 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'Ad Hoc Distributed Queries', 0, 1003 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'affinity I/O mask', 0, 1004 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'affinity mask', 0, 1005 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'affinity64 mask', 0, 1066 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'affinity64 I/O mask', 0, 1067 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'Agent XPs', 0, 1071 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'allow updates', 0, 1007 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'awe enabled', 0, 1008 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'backup checksum default', 0, 1070 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'backup compression default', 0, 1073 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'blocked process threshold', 0, 1009 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'blocked process threshold (s)', 0, 1009 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'c2 audit mode', 0, 1010 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'clr enabled', 0, 1011 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'common criteria compliance enabled', 0, 1074 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'contained database authentication', 0, 1068 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'cost threshold for parallelism', 5, 1012 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'cross db ownership chaining', 0, 1013 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'cursor threshold', -1, 1014 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'Database Mail XPs', 0, 1072 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'default full-text language', 1033, 1016 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'default language', 0, 1017 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'default trace enabled', 1, 1018 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'disallow results from triggers', 0, 1019 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'EKM provider enabled', 0, 1075 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'filestream access level', 0, 1076 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'fill factor (%)', 0, 1020 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'ft crawl bandwidth (max)', 100, 1021 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'ft crawl bandwidth (min)', 0, 1022 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'ft notify bandwidth (max)', 100, 1023 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'ft notify bandwidth (min)', 0, 1024 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'index create memory (KB)', 0, 1025 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'in-doubt xact resolution', 0, 1026 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'lightweight pooling', 0, 1027 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'locks', 0, 1028 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'max degree of parallelism', 0, 1029 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'max full-text crawl range', 4, 1030 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'max server memory (MB)', 2147483647, 1031 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'max text repl size (B)', 65536, 1032 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'max worker threads', 0, 1033 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'media retention', 0, 1034 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'min memory per query (KB)', 1024, 1035 );
	/* Accepting both 0 and 16 below because both have been seen in the wild as defaults. */
	IF EXISTS ( SELECT  *
				FROM    sys.configurations
				WHERE   name = 'min server memory (MB)'
						AND value_in_use IN ( 0, 16 ) )
		INSERT  INTO #ConfigurationDefaults
				SELECT  'min server memory (MB)' ,
						CAST(value_in_use AS BIGINT), 1036
				FROM    sys.configurations
				WHERE   name = 'min server memory (MB)'
	ELSE
		INSERT  INTO #ConfigurationDefaults
		VALUES  ( 'min server memory (MB)', 0, 1036 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'nested triggers', 1, 1037 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'network packet size (B)', 4096, 1038 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'Ole Automation Procedures', 0, 1039 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'open objects', 0, 1040 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'optimize for ad hoc workloads', 0, 1041 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'PH timeout (s)', 60, 1042 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'precompute rank', 0, 1043 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'priority boost', 0, 1044 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'query governor cost limit', 0, 1045 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'query wait (s)', -1, 1046 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'recovery interval (min)', 0, 1047 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'remote access', 1, 1048 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'remote admin connections', 0, 1049 );
	/* SQL Server 2012 changes a configuration default */
	IF @@VERSION LIKE '%Microsoft SQL Server 2005%'
		OR @@VERSION LIKE '%Microsoft SQL Server 2008%'
		BEGIN
			INSERT  INTO #ConfigurationDefaults
			VALUES  ( 'remote login timeout (s)', 20, 1069 );
		END
	ELSE
		BEGIN
			INSERT  INTO #ConfigurationDefaults
			VALUES  ( 'remote login timeout (s)', 10, 1069 );
		END
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'remote proc trans', 0, 1050 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'remote query timeout (s)', 600, 1051 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'Replication XPs', 0, 1052 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'RPC parameter data validation', 0, 1053 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'scan for startup procs', 0, 1054 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'server trigger recursion', 1, 1055 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'set working set size', 0, 1056 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'show advanced options', 0, 1057 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'SMO and DMO XPs', 1, 1058 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'SQL Mail XPs', 0, 1059 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'transform noise words', 0, 1060 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'two digit year cutoff', 2049, 1061 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'user connections', 0, 1062 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'user options', 0, 1063 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'Web Assistant Procedures', 0, 1064 );
	INSERT  INTO #ConfigurationDefaults
	VALUES  ( 'xp_cmdshell', 0, 1065 );


	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 25, 'Server details - Non default settings','------','------'
	INSERT #output_man_script (SectionId, Section,Summary,Details)
	SELECT 25, [description] name
	, '['+CONVERT(VARCHAR,cd.[DefaultValue]) + '] changed to [' + CONVERT(VARCHAR,value_in_use) + ']'
	, 'Blitz CheckID:' +  CONVERT(VARCHAR,cd.CheckID)
	+ '; MIN:' + CONVERT(VARCHAR,minimum)
	+ '; MAX:' + CONVERT(VARCHAR,maximum)
	+ '; IsDynamic:' + CONVERT(VARCHAR,is_dynamic)
	+ '; IsAdvanced:' + CONVERT(VARCHAR,is_advanced)
	FROM sys.configurations cr WITH (NOLOCK)
	INNER JOIN #ConfigurationDefaults cd ON cd.name = cr.name
	LEFT OUTER JOIN #ConfigurationDefaults cdUsed ON cdUsed.name = cr.name AND cdUsed.DefaultValue = cr.value_in_use
	WHERE cdUsed.name IS NULL
	OPTION (RECOMPILE);
	RAISERROR (N'Listed non-default settings',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Current active logins on this instance
			----------------------------------------*/

	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 26,'CURRENT ACTIVE USERS - TOP 10','------','------'
	INSERT #output_man_script (SectionId, Section,Summary)
	SELECT TOP 10 26, 'User: ' + login_name
	, '[' + CONVERT(VARCHAR, COUNT(session_id) ) + '] sessions using: ' + [program_name]
	FROM sys.dm_exec_sessions WITH (NOLOCK)
	GROUP BY login_name, [program_name]
	ORDER BY COUNT(session_id) DESC OPTION (RECOMPILE);

	RAISERROR (N'Connections listed',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Insert trust issues into output table
			----------------------------------------*/
	IF EXISTS(SELECT 1 FROM #notrust )
	BEGIN
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 27,'TRUST ISSUES','------','------'
	INSERT #output_man_script (SectionId, Section,Summary, Details)

	SELECT 27, KeyType + '; Table: '+ Tablename
	+ '; KeyName: ' + KeyName
	, DBCCcommand
	, Fix
	FROM #notrust 
	OPTION (RECOMPILE)
	END

	RAISERROR (N'Included Constraint trust issues',0,1) WITH NOWAIT;

			/*----------------------------------------
			--Check for any pages marked suspect for corruption
			----------------------------------------*/
	IF EXISTS(select 1 from msdb.dbo.suspect_pages)
	INSERT #output_man_script (SectionId, Section,Summary, Details) SELECT 28, 'SUSPECT PAGES !! WARNING !!','------','------'
	INSERT #output_man_script (SectionId, Section,Summary, Details)
	SELECT 28,
	'DB: ' + db_name(database_id)
	+ '; FileID: ' + CONVERT(VARCHAR,file_id)
	+ '; PageID: ' + CONVERT(VARCHAR, page_id)
	, 'Event Type: ' + CONVERT(VARCHAR,event_type)
	+ '; Count: ' + CONVERT(VARCHAR,error_count)
	, 'Last Update: ' + CONVERT(VARCHAR,last_update_date,120)

	FROM msdb.dbo.suspect_pages
	OPTION (RECOMPILE)

	RAISERROR (N'Included Suspect Pages, if any',0,1) WITH NOWAIT;
			/*----------------------------------------
			--select output
			----------------------------------------*/
     
	SELECT T1.ID
	, CASE WHEN @PrepForExport = 1 THEN @starttime ELSE T1.evaldate END evaldate
	, T1.domain
	, T1.SQLInstance
	, T1.SectionID
	, T1.Section
	, T1.Summary
	, T1.Details
	, CASE WHEN  @ShowQueryPlan = 1 THEN QueryPlan ELSE NULL END QueryPlan
	FROM #output_man_script T1
	ORDER BY ID ASC
	OPTION (RECOMPILE)


	IF OBJECT_ID('tempdb.#output_man_script') IS NOT NULL
		DROP TABLE #output_man_script  
	IF OBJECT_ID('tempdb.#Action_Statistics') IS NOT NULL
		DROP TABLE #Action_Statistics
	IF OBJECT_ID('tempdb.#db_sps') IS NOT NULL
		DROP TABLE #db_sps
	IF OBJECT_ID('tempdb.#ConfigurationDefaults') IS NOT NULL
		DROP TABLE #ConfigurationDefaults
	IF OBJECT_ID('tempdb..#querystats') IS NOT NULL
		DROP TABLE #querystats
	IF OBJECT_ID('tempdb..#dbccloginfo') IS NOT NULL
		DROP TABLE #dbccloginfo
	IF OBJECT_ID('tempdb..#notrust') IS NOT NULL
				DROP TABLE #notrust
	IF OBJECT_ID('tempdb..#MissingIndex') IS NOT NULL
				DROP TABLE #MissingIndex;
	IF OBJECT_ID('tempdb..#HeapTable') IS NOT NULL
				DROP TABLE #HeapTable;
	/*
	SELECT TOP 10
	qs.plan_generation_num,
	qs.execution_count,
	DB_NAME(st.dbid) AS DbName,
	st.objectid,
	st.TEXT
	FROM sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
	ORDER BY plan_generation_num DESC
	OPTION (RECOMPILE)
	*/

	/* Get current connection details
	SELECT 
	T.program_name
	, T.database_id
	, CASE 
	WHEN T.client_version = 4 THEN 'SQL 2000'
	WHEN T.client_version = 5 THEN 'SQL 2005'
	WHEN T.client_version = 6 THEN 'SQL 2008'
	WHEN T.client_version = 7 THEN 'SQL 2012'
	ELSE 'SQL 2014+'
	END
	, T.client_interface_name
	, T.text_size
	, T.date_format
	, T.date_first
	, T.quoted_identifier
	, T.arithabort
	, T.ansi_null_dflt_on
	, T.ansi_defaults
	, T.ansi_warnings
	, T.ansi_nulls
	, T.concat_null_yields_null
	, T.transaction_isolation_level
	, T.lock_timeout
	, T.deadlock_priority
	, T.prev_error
	 FROM sys.dm_exec_sessions T
	 WHERE T.program_name IS NOT NULL

	 */
    SET NOCOUNT OFF;
GO


/*
--Sample execution call with the most common parameters:

EXEC [dbo].[the_management_script] @TopQueries = 50,  @FTECost  = 60000,  @ShowQueryPlan = 0, @PrepForExport = 1

*/