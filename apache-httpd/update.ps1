Import-Module au

. "tools\helpers.ps1"

# $releases = 'https://www.apachehaus.com/cgi-bin/download.plx'
$releases = 'https://www.apachelounge.com/download/'

$versionPostfix = "0007"

$global:au_NoCheckChocoVersion = $true

function global:au_BeforeUpdate {
  Get-RemoteFiles -NoSuffix
  $Latest.ChecksumType64 = 'sha512'
  # 128 Hexa characters.
  $checkSumRegEx = "([A-Z0-9]{128})"
  $file = "tools\$($Latest.FileName64)"
  # get checksum from remote
  try {
    $downloadSha = Invoke-WebRequest -Uri "$($Latest.Url64).txt" -Headers @{ 'Accept' = '*/*'; 'User-Agent' = 'Mozilla/5.0' }
  }
  catch {
    $downloadSha = $_.Exception.Response
    write-host ("Exception: {0}" -f $_.Exception.Message)
  }
  $matching = [regex]::match($downloadSha.Content, $checkSumRegEx)
  if (!(Assert-ChecksumMatch(@{ 'shaType' = $Latest.ChecksumType64; 'checksum' = $matching.Groups[0].Value; 'file' = $file }))) {
    throw "Checksum ($($Latest.ChecksumType64)) for $($Latest.Url64) does not match $($matching.Groups[0].Value)"
  }
  else {
    Write-Host "Checksum ($($Latest.ChecksumType64)) for $($Latest.Url64) matches $($matching.Groups[0].Value)"
  }
  $Latest.Checksum64 = (Get-FileHash $file -Algorithm $Latest.ChecksumType64).Hash
}
function global:au_GetLatest {
  $versionRegEx = 'httpd\-([\d\.]+)[a-z]*\-win64\-(VS17)[a-z]*\.zip'

  try {
    $downloadPage = Invoke-WebRequest -Uri $releases -Headers @{ 'Accept' = '*/*'; 'User-Agent' = 'Mozilla/5.0' }

  }
  catch {
    $downloadPage = $_.Exception.Response
    write-host ("Exception: {0}" -f $_.Exception.Message)
  }

  $matching = [regex]::match($downloadPage.Content, $versionRegEx)
  Write-Host($matching)


  $version = [version]$matching.Groups[1].Value

  $url = "https://www.apachelounge.com/download/$($matching.Groups[2].Value)/binaries/$($matching.Groups[0].Value)"

  Write-Host($version)

  return @{

    Url64   = $url
    Version = "$($version).$($versionPostfix)"
  }

}

function global:au_SearchReplace {
  Write-Host($Latest)
  return @{
    ".\tools\chocolateyInstall.ps1" = @{
      "(?i)(^\s*file64\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.FileName64)`""
    }
    ".\legal\VERIFICATION.txt"      = @{
      "(?i)(listed on\s*)\<.*\>" = "`${1}<$releases>"
      "(?i)(64-Bit.+)\<.*\>"     = "`${1}<$($Latest.URL64)>"
      "(?i)(checksum type:).*"   = "`${1} $($Latest.ChecksumType64)"
      "(?i)(checksum:).*"        = "`${1} $($Latest.Checksum64)"
    }
  }
}

# checksum compared in au_BeforeUpdate
update -ChecksumFor none
