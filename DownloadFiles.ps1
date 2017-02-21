$currentpath = $pwd

$urls = @("https://ola.hallengren.com/scripts/MaintenanceSolution.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_Blitz.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzCache.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzFirst.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzIndex.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzRS.sql" `
, "https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/sp_BlitzTrace.sql" `
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