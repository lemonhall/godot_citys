param(
	[string]$DirectUrl = 'https://ice1.somafm.com/groovesalad-128-mp3',
	[string]$PlaylistUrl = 'https://somafm.com/groovesalad.pls',
	[string]$HlsUrl = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CurlHead {
	param(
		[string]$Url
	)
	$headers = & curl.exe --silent --show-error --location --ssl-no-revoke --max-redirs 4 --connect-timeout 20 --head $Url
	if($LASTEXITCODE -ne 0){
		throw "curl HEAD failed: $Url"
	}
	$statusLine = ($headers | Select-String -Pattern '^HTTP/' | Select-Object -Last 1).Line
	$contentTypeLine = ($headers | Select-String -Pattern '^Content-Type:' | Select-Object -Last 1).Line
	return @{
		url = $Url
		status_line = $statusLine
		content_type = if($contentTypeLine){ ($contentTypeLine -replace '^Content-Type:\s*','').Trim() } else { '' }
	}
}

function Invoke-CurlBody {
	param(
		[string]$Url
	)
	$tempHeaders = [System.IO.Path]::GetTempFileName()
	try {
		$bodyLines = & curl.exe --silent --show-error --location --ssl-no-revoke --max-redirs 4 --connect-timeout 20 --max-time 30 --dump-header $tempHeaders $Url
		if($LASTEXITCODE -ne 0){
			throw "curl GET failed: $Url"
		}
		$body = ($bodyLines -join "`n")
		$headers = Get-Content -Raw $tempHeaders
		$statusLine = (($headers -split "`r?`n") | Select-String -Pattern '^HTTP/' | Select-Object -Last 1).Line
		$contentTypeLine = (($headers -split "`r?`n") | Select-String -Pattern '^Content-Type:' | Select-Object -Last 1).Line
		return @{
			url = $Url
			status_line = $statusLine
			content_type = if($contentTypeLine){ ($contentTypeLine -replace '^Content-Type:\s*','').Trim() } else { '' }
			body = $body
		}
	}
	finally {
		if(Test-Path $tempHeaders){
			Remove-Item $tempHeaders -Force
		}
	}
}

function Get-PlaylistFirstCandidate {
	param(
		[string]$Body
	)
	foreach($line in ($Body -split "`r?`n")){
		$trimmed = $line.Trim()
		if($trimmed -match '^File\d+=(.+)$'){
			return $Matches[1].Trim()
		}
	}
	return ''
}

function Get-HlsFirstVariant {
	param(
		[string]$Body
	)
	$lines = $Body -split "`r?`n"
	for($index = 0; $index -lt $lines.Count; $index++){
		$trimmed = $lines[$index].Trim()
		if($trimmed -eq '' -or $trimmed.StartsWith('#')){
			continue
		}
		return $trimmed
	}
	return ''
}

$direct = Invoke-CurlHead -Url $DirectUrl
$playlist = Invoke-CurlBody -Url $PlaylistUrl
$hls = Invoke-CurlBody -Url $HlsUrl

$summary = [ordered]@{
	verified_at_utc = (Get-Date).ToUniversalTime().ToString('o')
	samples = [ordered]@{
		direct = [ordered]@{
			url = $direct.url
			status_line = $direct.status_line
			content_type = $direct.content_type
		}
		playlist = [ordered]@{
			url = $playlist.url
			status_line = $playlist.status_line
			content_type = $playlist.content_type
			first_candidate = Get-PlaylistFirstCandidate -Body $playlist.body
		}
		hls = [ordered]@{
			url = $hls.url
			status_line = $hls.status_line
			content_type = $hls.content_type
			first_variant = Get-HlsFirstVariant -Body $hls.body
		}
	}
}

$summary | ConvertTo-Json -Depth 6
