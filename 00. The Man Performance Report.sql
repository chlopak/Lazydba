--PRINT NCHAR(65021)

SET NOCOUNT ON
SET ANSI_WARNINGS ON
SET QUOTED_IDENTIFIER ON

IF OBJECT_ID('dbo.[the_management_performance_report]') IS NULL
  EXEC ('CREATE PROCEDURE [dbo].[the_management_performance_report] AS RETURN 0;')
GO

ALTER PROCEDURE [dbo].[the_management_performance_report]
     @MinExecutionCount TINYINT = 5 /*This can go to 0 for more details, queries with more than 10 seconds total worker time will be excluded*/
	, @PrepForExport TINYINT = 0 /*When the intent of this script is to use this for some type of hocus-pocus magic metrics, set this to 1*/

WITH RECOMPILE
AS

DECLARE @cnt INT;
DECLARE @record_count INT;
DECLARE @dbid INT;
DECLARE @objectid INT;
DECLARE @cmd nvarchar(MAX);
DECLARE @grand_total_worker_time FLOAT ; 
DECLARE @grand_total_IO FLOAT ; 

BEGIN TRY
	IF OBJECT_ID('tempdb.dbo.#LEXEL_OES_stats_sql_handle_convert_table', 'U') IS NOT NULL
	EXEC ('DROP TABLE #LEXEL_OES_stats_sql_handle_convert_table;')
	CREATE TABLE #LEXEL_OES_stats_sql_handle_convert_table (
			 row_id INT identity 
			, t_sql_handle varbinary(64)
			, t_display_option varchar(140) collate database_default
			, t_display_optionIO varchar(140) collate database_default
			, t_sql_handle_text varchar(140) collate database_default
			, t_SPRank INT
			, t_dbid INT
			, t_objectid INT
			, t_SQLStatement varchar(max) collate database_default
			, t_execution_count INT
			, t_plan_generation_num INT
			, t_last_execution_time datetime
			, t_avg_worker_time FLOAT
			, t_total_worker_time FLOAT
			, t_last_worker_time FLOAT
			, t_min_worker_time FLOAT
			, t_max_worker_time FLOAT
			, t_avg_logical_reads FLOAT
			, t_total_logical_reads BIGINT
			, t_last_logical_reads BIGINT
			, t_min_logical_reads BIGINT
			, t_max_logical_reads BIGINT
			, t_avg_logical_writes FLOAT
			, t_total_logical_writes BIGINT
			, t_last_logical_writes BIGINT
			, t_min_logical_writes BIGINT
			, t_max_logical_writes BIGINT
			, t_avg_logical_IO FLOAT
			, t_total_logical_IO BIGINT
			, t_last_logical_IO BIGINT
			, t_min_logical_IO BIGINT
			, t_max_logical_IO BIGINT 
			);
	IF OBJECT_ID('tempdb.dbo.#LEXEL_OES_stats_objects', 'U') IS NOT NULL
	 EXEC ('DROP TABLE #LEXEL_OES_stats_objects;')
	CREATE TABLE #LEXEL_OES_stats_objects (
			 obj_rank INT
			, total_cpu BIGINT
			, total_logical_reads BIGINT
			, total_logical_writes BIGINT
			, total_logical_io BIGINT
			, avg_cpu BIGINT
			, avg_reads BIGINT
			, avg_writes BIGINT
			, avg_io BIGINT
			, cpu_rank INT
			, total_cpu_rank INT
			, logical_read_rank INT
			, logical_write_rank INT
			, logical_io_rank INT
			);
	IF OBJECT_ID('tempdb.dbo.#LEXEL_OES_stats_object_name', 'U') IS NOT NULL
	 EXEC ('DROP TABLE #LEXEL_OES_stats_object_name;')
	CREATE TABLE #LEXEL_OES_stats_object_name (
			 dbId INT
			, objectId INT
			, dbName sysname collate database_default null
			, objectName sysname collate database_default null
			, objectType nvarchar(5) collate database_default null
			, schemaName sysname collate database_default null
			)

	INSERT INTO #LEXEL_OES_stats_sql_handle_convert_table 
	SELECT
	sql_handle
	, sql_handle AS chart_display_option 
	, sql_handle AS chart_display_optionIO 
	, master.dbo.fn_varbintohexstr(sql_handle)
	, dense_RANK() over (order by s2.dbid,s2.objectid) AS SPRank 
	, s2.dbid
	, s2.objectid
	, (SELECT top 1 substring(text,(s1.statement_start_offset+2)/2, (CASE WHEN s1.statement_end_offset = -1 then len(convert(nvarchar(max),text))*2 else s1.statement_end_offset end - s1.statement_start_offset) /2 ) FROM sys.dm_exec_sql_text(s1.sql_handle)) AS [SQL Statement]
	, execution_count
	, plan_generation_num
	, last_execution_time
	, ((total_worker_time+0.0)/execution_count)/1000 AS [avg_worker_time]
	, total_worker_time/1000.0
	, last_worker_time/1000.0
	, min_worker_time/1000.0
	, max_worker_time/1000.0
	, ((total_logical_reads+0.0)/execution_count) AS [avg_logical_reads]
	, total_logical_reads
	, last_logical_reads
	, min_logical_reads
	, max_logical_reads
	, ((total_logical_writes+0.0)/execution_count) AS [avg_logical_writes]
	, total_logical_writes
	, last_logical_writes
	, min_logical_writes
	, max_logical_writes
	, ((total_logical_writes+0.0)/execution_count + (total_logical_reads+0.0)/execution_count) AS [avg_logical_IO]
	, total_logical_writes + total_logical_reads
	, last_logical_writes +last_logical_reads
	, min_logical_writes +min_logical_reads
	, max_logical_writes + max_logical_reads 
	FROM sys.dm_exec_query_stats s1 
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) s2 
	WHERE s2.objectid IS NOT NULL AND db_name(s2.dbid) IS NOT NULL
	AND (execution_count >= @MinExecutionCount OR (total_worker_time/1000.0) > 10)
	ORDER BY s1.sql_handle; 

	SELECT @grand_total_worker_time = SUM(t_total_worker_time)
	, @grand_total_IO = SUM(t_total_logical_reads + t_total_logical_writes) 
	from #LEXEL_OES_stats_sql_handle_convert_table; 
	SELECT @grand_total_worker_time = CASE WHEN @grand_total_worker_time > 0 THEN @grand_total_worker_time ELSE 1.0 END ; 
	SELECT @grand_total_IO = CASE WHEN @grand_total_IO > 0 THEN @grand_total_IO ELSE 1.0 END ; 

	set @cnt = 1; 
	SELECT @record_count = count(*) FROM #LEXEL_OES_stats_sql_handle_convert_table ; 
	WHILE (@cnt <= @record_count) 
	BEGIN 
	 SELECT @dbid = t_dbid
	 , @objectid = t_objectid 
	 FROM #LEXEL_OES_stats_sql_handle_convert_table WHERE row_id = @cnt; 
	 if not exists (SELECT 1 FROM #LEXEL_OES_stats_object_name WHERE objectId = @objectid AND dbId = @dbid )
	 BEGIN
	 SET @cmd = 'SELECT '+convert(nvarchar(10),@dbid)+','+convert(nvarchar(100),@objectid)+','''+db_name(@dbid)+'''
				 , obj.name,obj.type
				 , CASE WHEN sch.name IS NULL THEN '''' ELSE sch.name END 
	 FROM ['+db_name(@dbid)+'].sys.objects obj 
				 LEFT OUTER JOIN ['+db_name(@dbid)+'].sys.schemas sch on(obj.schema_id = sch.schema_id) 
	 WHERE obj.object_id = '+convert(nvarchar(100),@objectid)+ ';'
	 INSERT INTO #LEXEL_OES_stats_object_name
	 EXEC(@cmd)
			END
	 SET @cnt = @cnt + 1 ; 
	END ; 

	INSERT INTO #LEXEL_OES_stats_objects 
	SELECT t_SPRank
	, SUM(t_total_worker_time)
	, SUM(t_total_logical_reads)
	, SUM(t_total_logical_writes)
	, SUM(t_total_logical_IO)
	, SUM(t_avg_worker_time) AS avg_cpu
	, SUM(t_avg_logical_reads)
	, SUM(t_avg_logical_writes)
	, SUM(t_avg_logical_IO)
	, RANK()OVER (ORDER BY SUM(t_avg_worker_time) DESC)
	, RANK()OVER (ORDER BY SUM(t_total_worker_time) DESC)
	, RANK()OVER (ORDER BY SUM(t_avg_logical_reads) DESC)
	, RANK()OVER (ORDER BY SUM(t_avg_logical_writes) DESC)
	, RANK()OVER (ORDER BY SUM(t_total_logical_IO) DESC)
	FROM #LEXEL_OES_stats_sql_handle_convert_table 
	GROUP BY t_SPRank ; 

	UPDATE #LEXEL_OES_stats_sql_handle_convert_table SET t_display_option = 'show_total' 
	WHERE t_SPRank IN (SELECT obj_rank FROM #LEXEL_OES_stats_objects WHERE (total_cpu+0.0)/@grand_total_worker_time < 0.05) ; 

	UPDATE #LEXEL_OES_stats_sql_handle_convert_table SET t_display_option = t_sql_handle_text 
	WHERE t_SPRank IN (SELECT obj_rank FROM #LEXEL_OES_stats_objects WHERE total_cpu_rank <= 5) ; 

	UPDATE #LEXEL_OES_stats_sql_handle_convert_table SET t_display_option = 'show_total' 
	WHERE t_SPRank IN (SELECT obj_rank FROM #LEXEL_OES_stats_objects WHERE (total_cpu+0.0)/@grand_total_worker_time < 0.005); 

	UPDATE #LEXEL_OES_stats_sql_handle_convert_table SET t_display_optionIO = 'show_total' 
	WHERE t_SPRank IN (SELECT obj_rank FROM #LEXEL_OES_stats_objects WHERE (total_logical_io+0.0)/@grand_total_IO < 0.05); 

	UPDATE #LEXEL_OES_stats_sql_handle_convert_table SET t_display_optionIO = t_sql_handle_text 
	WHERE t_SPRank IN (SELECT obj_rank FROM #LEXEL_OES_stats_objects WHERE logical_io_rank <= 5) ; 

	UPDATE #LEXEL_OES_stats_sql_handle_convert_table SET t_display_optionIO = 'show_total' 
	WHERE t_SPRank IN (SELECT obj_rank FROM #LEXEL_OES_stats_objects WHERE (total_logical_io+0.0)/@grand_total_IO < 0.005); 


END TRY
BEGIN CATCH 
	SELECT -100 AS l1
	, ERROR_NUMBER() AS l2
	, ERROR_SEVERITY() AS row_id
	, ERROR_STATE() AS t_sql_handle
	, ERROR_MESSAGE() AS t_display_option
	, 1 AS t_display_optionIO, 1 AS t_sql_handle_text,1 AS t_SPRank,1 AS t_dbid ,1 AS t_objectid ,1 AS t_SQLStatement,1 AS t_execution_count,1 AS t_plan_generation_num,1 AS t_last_execution_time, 1 AS t_avg_worker_time, 1 AS t_total_worker_time, 1 AS t_last_worker_time, 1 AS t_min_worker_time, 1 AS t_max_worker_time, 1 AS t_avg_logical_reads, 1 AS t_total_logical_reads, 1 AS t_last_logical_reads, 1 AS t_min_logical_reads, 1 AS t_max_logical_reads, 1 AS t_avg_logical_writes, 1 AS t_total_logical_writes, 1 AS t_last_logical_writes, 1 AS t_min_logical_writes, 1 AS t_max_logical_writes, 1 AS t_avg_logical_IO, 1 AS t_total_logical_IO, 1 AS t_last_logical_IO, 1 AS t_min_logical_IO, 1 AS t_max_logical_IO, 1 AS t_CPURank, 1 AS t_logical_ReadRank, 1 AS t_logical_WriteRank, 1 AS t_obj_name, 1 AS t_obj_type, 1 AS schama_name, 1 AS t_db_name 
END CATCH

BEGIN TRY
set @dbid = db_id(); 
SET @cnt = 0; 
SET @record_count = 0; 
declare @sql_handle varbinary(64); 
declare @sql_handle_string varchar(130); 
SET @grand_total_worker_time = 0 ; 
SET @grand_total_IO = 0 ; 

IF OBJECT_ID('tempdb..#sql_handle_convert_table') IS NOT NULL
			DROP TABLE #sql_handle_convert_table;
CREATE TABLE #sql_handle_convert_table (
 row_id INT identity 
, t_sql_handle varbinary(64)
, t_display_option varchar(140) collate database_default
, t_display_optionIO varchar(140) collate database_default
, t_sql_handle_text varchar(140) collate database_default
, t_SPRank INT
, t_SPRank2 INT
, t_SQLStatement varchar(max) collate database_default
, t_execution_count INT 
, t_plan_generation_num INT
, t_last_execution_time datetime
, t_avg_worker_time FLOAT
, t_total_worker_time BIGINT
, t_last_worker_time BIGINT
, t_min_worker_time BIGINT
, t_max_worker_time BIGINT 
, t_avg_logical_reads FLOAT
, t_total_logical_reads BIGINT
, t_last_logical_reads BIGINT
, t_min_logical_reads BIGINT 
, t_max_logical_reads BIGINT
, t_avg_logical_writes FLOAT
, t_total_logical_writes BIGINT
, t_last_logical_writes BIGINT
, t_min_logical_writes BIGINT
, t_max_logical_writes BIGINT
, t_avg_IO FLOAT
, t_total_IO BIGINT
, t_last_IO BIGINT
, t_min_IO BIGINT
, t_max_IO BIGINT
);

IF OBJECT_ID('tempdb..#perf_report_objects') IS NOT NULL
			DROP TABLE #perf_report_objects;
CREATE TABLE #perf_report_objects (
 obj_rank INT
, total_cpu BIGINT 
, total_reads BIGINT
, total_writes BIGINT
, total_io BIGINT
, avg_cpu BIGINT 
, avg_reads BIGINT
, avg_writes BIGINT
, avg_io BIGINT
, cpu_rank INT
, total_cpu_rank INT
, read_rank INT
, write_rank INT
, io_rank INT
); 

insert INTo #sql_handle_convert_table
SELECT sql_handle
, sql_handle AS chart_display_option 
, sql_handle AS chart_display_optionIO 
, master.dbo.fn_varbintohexstr(sql_handle)
, dense_RANK() over (order by s1.sql_handle) AS SPRank 
, dense_RANK() over (partition by s1.sql_handle order by s1.statement_start_offset) AS SPRank2
, replace(replace(replace(replace(CONVERT(NVARCHAR(MAX),(SELECT top 1 substring(text,(s1.statement_start_offset+2)/2, (CASE WHEN s1.statement_end_offset = -1 then len(convert(nvarchar(max),text))*2 else s1.statement_end_offset end - s1.statement_start_offset) /2 ) FROM sys.dm_exec_sql_text(s1.sql_handle))), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), ' ',' ') AS [SQL Statement]
, execution_count
, plan_generation_num
, last_execution_time
, ((total_worker_time+0.0)/execution_count)/1000 AS [avg_worker_time]
, total_worker_time/1000
, last_worker_time/1000
, min_worker_time/1000
, max_worker_time/1000
, ((total_logical_reads+0.0)/execution_count) AS [avg_logical_reads]
, total_logical_reads
, last_logical_reads
, min_logical_reads
, max_logical_reads
, ((total_logical_writes+0.0)/execution_count) AS [avg_logical_writes]
, total_logical_writes
, last_logical_writes
, min_logical_writes
, max_logical_writes
, ((total_logical_writes+0.0)/execution_count + (total_logical_reads+0.0)/execution_count) AS [avg_IO]
, total_logical_writes + total_logical_reads
, last_logical_writes +last_logical_reads
, min_logical_writes +min_logical_reads
, max_logical_writes + max_logical_reads 
from sys.dm_exec_query_stats s1 
cross apply sys.dm_exec_sql_text(sql_handle) AS s2 
WHERE s2.objectid is null
AND (execution_count >= @MinExecutionCount OR (total_worker_time/1000.0) > 10)
order by s1.sql_handle; 

SELECT @grand_total_worker_time = SUM(t_total_worker_time) 
, @grand_total_IO = SUM(t_total_logical_reads + t_total_logical_writes) 
from #sql_handle_convert_table; 

SELECT @grand_total_worker_time = CASE WHEN @grand_total_worker_time > 0 then @grand_total_worker_time else 1.0 end ; 
SELECT @grand_total_IO = CASE WHEN @grand_total_IO > 0 then @grand_total_IO else 1.0 end ; 

Insert INTo #perf_report_objects 
SELECT t_SPRank
, SUM(t_total_worker_time)
, SUM(t_total_logical_reads)
, SUM(t_total_logical_writes)
, SUM(t_total_IO)
, SUM(t_avg_worker_time) AS avg_cpu
, SUM(t_avg_logical_reads)
, SUM(t_avg_logical_writes)
, SUM(t_avg_IO)
, RANK() OVER(ORDER BY SUM(t_avg_worker_time) DESC)
, ROW_NUMBER() OVER(ORDER BY SUM(t_total_worker_time) DESC)
, ROW_NUMBER() OVER(ORDER BY SUM(t_avg_logical_reads) DESC)
, ROW_NUMBER() OVER(ORDER BY SUM(t_avg_logical_writes) DESC)
, ROW_NUMBER() OVER(ORDER BY SUM(t_total_IO) DESC)
from #sql_handle_convert_table
group by t_SPRank ; 

UPDATE #sql_handle_convert_table SET t_display_option = 'show_total'
WHERE t_SPRank IN (SELECT obj_rank FROM #perf_report_objects WHERE (total_cpu+0.0)/@grand_total_worker_time < 0.05) ; 

UPDATE #sql_handle_convert_table SET t_display_option = t_sql_handle_text 
WHERE t_SPRank IN (SELECT obj_rank FROM #perf_report_objects WHERE total_cpu_rank <= 5) ; 

UPDATE #sql_handle_convert_table SET t_display_option = 'show_total' 
WHERE t_SPRank IN (SELECT obj_rank FROM #perf_report_objects WHERE (total_cpu+0.0)/@grand_total_worker_time < 0.005); 

UPDATE #sql_handle_convert_table SET t_display_optionIO = 'show_total' 
WHERE t_SPRank IN (SELECT obj_rank FROM #perf_report_objects WHERE (total_io+0.0)/@grand_total_IO < 0.05); 

UPDATE #sql_handle_convert_table SET t_display_optionIO = t_sql_handle_text 
WHERE t_SPRank IN (SELECT obj_rank FROM #perf_report_objects WHERE io_rank <= 5) ; 

UPDATE #sql_handle_convert_table SET t_display_optionIO = 'show_total' 
WHERE t_SPRank IN (SELECT obj_rank FROM #perf_report_objects WHERE (total_io+0.0)/@grand_total_IO < 0.005); 


END TRY
begin catch
SELECT -100 AS l1
, ERROR_NUMBER() AS l2
, ERROR_SEVERITY() AS row_id
, ERROR_STATE() AS t_sql_handle
, ERROR_MESSAGE() AS t_display_option
, 1 AS t_display_optionIO, 1 AS t_sql_handle_text, 1 AS t_SPRank, 1 AS t_SPRank2, 1 AS t_SQLStatement, 1 AS t_execution_count , 1 AS t_plan_generation_num, 1 AS t_last_execution_time, 1 AS t_avg_worker_time, 1 AS t_total_worker_time, 1 AS t_last_worker_time, 1 AS t_min_worker_time, 1 AS t_max_worker_time, 1 AS t_avg_logical_reads 
, 1 AS t_total_logical_reads, 1 AS t_last_logical_reads, 1 AS t_min_logical_reads, 1 AS t_max_logical_reads, 1 AS t_avg_logical_writes, 1 AS t_total_logical_writes, 1 AS t_last_logical_writes, 1 AS t_min_logical_writes, 1 AS t_max_logical_writes, 1 AS t_avg_IO, 1 AS t_total_IO, 1 AS t_last_IO, 1 AS t_min_IO, 1 AS t_max_IO, 1 AS t_CPURank, 1 AS t_ReadRank, 1 AS t_WriteRank
end catch




SELECT 'OBJECT' [Type], (s.t_SPRank)%2 AS l1
, (DENSE_RANK() OVER(ORDER BY s.t_SPRank,s.row_id))%2 AS l2
, row_id
, objname.objectName AS t_obj_name
, objname.objectType AS [t_obj_type]
, objname.schemaName AS schema_name
, objname.dbName AS t_db_name
, s.t_sql_handle
--, s.t_display_option
--, s.t_display_optionIO
--,s.t_sql_handle_text
, s.t_SPRank 
, NULL t_SPRank2 
, replace(replace(replace(replace(CONVERT(NVARCHAR(MAX),s.t_SQLStatement), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), ' ',' ') t_SQLStatement 
, s.t_execution_count 
, s.t_plan_generation_num 
, s.t_last_execution_time 
, s.t_avg_worker_time 
, s.t_total_worker_time 
, s.t_last_worker_time 
, s.t_min_worker_time 
, s.t_max_worker_time 
, s.t_avg_logical_reads 
, s.t_total_logical_reads
, s.t_last_logical_reads 
, s.t_min_logical_reads 
, s.t_max_logical_reads 
, s.t_avg_logical_writes 
, s.t_total_logical_writes 
, s.t_last_logical_writes 
, s.t_min_logical_writes 
, s.t_max_logical_writes 
, t_avg_logical_IO t_avg_IO 
, t_total_logical_IO t_total_IO 
, t_last_logical_IO t_last_IO 
, t_min_logical_IO t_min_IO 
, t_max_logical_IO t_max_IO
, ob.cpu_rank AS t_CPURank 
, ob.logical_read_rank t_ReadRank 
, ob.logical_write_rank t_WriteRank 

FROM #LEXEL_OES_stats_sql_handle_convert_table s 
JOIN #LEXEL_OES_stats_objects ob on (s.t_SPRank = ob.obj_rank)
JOIN #LEXEL_OES_stats_object_name AS objname on (objname.dbId = s.t_dbid and objname.objectId = s.t_objectid )
UNION ALL
SELECT 'BATCH' [Type],(s.t_SPRank)%2 AS l1
, (dense_RANK() OVER(ORDER BY s.t_SPRank,s.row_id))%2 AS l2
, row_id
, NULL t_obj_name
, NULL [t_obj_type]
, NULL schema_name
, NULL t_db_name
, s.t_sql_handle
--, s. t_display_option
--, s.t_display_optionIO 
--, s.t_sql_handle_text 
, s.t_SPRank 
, s.t_SPRank2 
, replace(replace(replace(replace(CONVERT(NVARCHAR(MAX),s.t_SQLStatement), CHAR(9), ' '),CHAR(10),' '), CHAR(13), ' '), ' ',' ') t_SQLStatement 
, s.t_execution_count 
, s.t_plan_generation_num 
, s.t_last_execution_time 
, s.t_avg_worker_time 
, s.t_total_worker_time 
, s.t_last_worker_time 
, s.t_min_worker_time 
, s.t_max_worker_time 
, s.t_avg_logical_reads 
, s.t_total_logical_reads
, s.t_last_logical_reads 
, s.t_min_logical_reads 
, s.t_max_logical_reads 
, s.t_avg_logical_writes 
, s.t_total_logical_writes 
, s.t_last_logical_writes 
, s.t_min_logical_writes 
, s.t_max_logical_writes 
, s.t_avg_IO 
, s.t_total_IO 
, s.t_last_IO 
, s.t_min_IO 
, s.t_max_IO
, ob.cpu_rank AS t_CPURank 
, ob.read_rank AS t_ReadRank 
, ob.write_rank AS t_WriteRank 
FROM  #sql_handle_convert_table s join #perf_report_objects ob on (s.t_SPRank = ob.obj_rank)


	IF OBJECT_ID('tempdb.dbo.#LEXEL_OES_stats_sql_handle_convert_table', 'U') IS NOT NULL
			DROP TABLE #LEXEL_OES_stats_sql_handle_convert_table;
	IF OBJECT_ID('tempdb.dbo.#LEXEL_OES_stats_objects', 'U') IS NOT NULL
			DROP TABLE #LEXEL_OES_stats_objects;
	IF OBJECT_ID('tempdb.dbo.#LEXEL_OES_stats_object_name', 'U') IS NOT NULL
			DROP TABLE #LEXEL_OES_stats_object_name;
	IF OBJECT_ID('tempdb..#sql_handle_convert_table') IS NOT NULL
			DROP TABLE #sql_handle_convert_table;
	IF OBJECT_ID('tempdb..#perf_report_objects') IS NOT NULL
			DROP TABLE #perf_report_objects;
GO